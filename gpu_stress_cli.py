#!/usr/bin/env python3
"""Adaptive NVIDIA GPU stress-test CLI.

The tool deliberately keeps its resident VRAM footprint small and controls load
with synchronized compute chunks. Optional backends are imported lazily so the
module can be tested on systems without CUDA.
"""

from __future__ import annotations

import argparse
import csv
import math
import shutil
import signal
import subprocess
import sys
import time
from dataclasses import dataclass, fields, replace
from pathlib import Path
from typing import Any, Callable, Iterable, Protocol

MIB = 1024 * 1024
DEFAULT_PERIOD_SECONDS = 0.10
DEFAULT_CHUNK_SECONDS = 0.005
BACKEND_ORDER = ("torch", "cupy", "numba")


class BackendUnavailable(RuntimeError):
    """Raised when a compute backend cannot run on the requested device."""


class StressRuntimeError(RuntimeError):
    """Raised when a stress run cannot continue safely."""


@dataclass
class GpuMetrics:
    timestamp: float
    name: str | None = None
    utilization_gpu: float | None = None
    utilization_memory: float | None = None
    memory_total_mib: float | None = None
    memory_used_mib: float | None = None
    memory_free_mib: float | None = None
    temperature_c: float | None = None
    power_w: float | None = None
    power_limit_w: float | None = None
    clock_sm_mhz: float | None = None
    clock_memory_mhz: float | None = None


class Monitor(Protocol):
    source: str

    def sample(self) -> GpuMetrics: ...

    def list_devices(self) -> list[tuple[int, str]]: ...

    def close(self) -> None: ...


class NvmlMonitor:
    """NVML monitor using NVIDIA's backwards-compatible Python binding."""

    source = "nvml"

    def __init__(self, device_index: int) -> None:
        try:
            import pynvml  # type: ignore
        except Exception as exc:  # pragma: no cover - environment dependent
            raise BackendUnavailable(f"pynvml import failed: {exc}") from exc

        self._nvml = pynvml
        try:
            pynvml.nvmlInit()
            count = int(pynvml.nvmlDeviceGetCount())
            if device_index < 0 or device_index >= count:
                raise BackendUnavailable(f"NVML device {device_index} is out of range (found {count})")
            self._handle = pynvml.nvmlDeviceGetHandleByIndex(device_index)
            self._device_index = device_index
        except Exception as exc:
            try:
                pynvml.nvmlShutdown()
            except Exception:
                pass
            if isinstance(exc, BackendUnavailable):
                raise
            raise BackendUnavailable(f"NVML initialization failed: {exc}") from exc

    @staticmethod
    def _decode(value: Any) -> str:
        return value.decode("utf-8", errors="replace") if isinstance(value, bytes) else str(value)

    @staticmethod
    def _optional(call: Callable[[], Any], scale: float = 1.0) -> float | None:
        try:
            return float(call()) / scale
        except Exception:
            return None

    def list_devices(self) -> list[tuple[int, str]]:
        devices: list[tuple[int, str]] = []
        count = int(self._nvml.nvmlDeviceGetCount())
        for index in range(count):
            handle = self._nvml.nvmlDeviceGetHandleByIndex(index)
            devices.append((index, self._decode(self._nvml.nvmlDeviceGetName(handle))))
        return devices

    def sample(self) -> GpuMetrics:
        n = self._nvml
        handle = self._handle
        metrics = GpuMetrics(timestamp=time.time())
        try:
            metrics.name = self._decode(n.nvmlDeviceGetName(handle))
        except Exception:
            pass
        try:
            util = n.nvmlDeviceGetUtilizationRates(handle)
            metrics.utilization_gpu = float(util.gpu)
            metrics.utilization_memory = float(util.memory)
        except Exception:
            pass
        try:
            memory = n.nvmlDeviceGetMemoryInfo(handle)
            metrics.memory_total_mib = float(memory.total) / MIB
            metrics.memory_used_mib = float(memory.used) / MIB
            metrics.memory_free_mib = float(memory.free) / MIB
        except Exception:
            pass
        metrics.temperature_c = self._optional(
            lambda: n.nvmlDeviceGetTemperature(handle, n.NVML_TEMPERATURE_GPU)
        )
        metrics.power_w = self._optional(lambda: n.nvmlDeviceGetPowerUsage(handle), scale=1000.0)
        metrics.power_limit_w = self._optional(
            lambda: n.nvmlDeviceGetEnforcedPowerLimit(handle), scale=1000.0
        )
        metrics.clock_sm_mhz = self._optional(lambda: n.nvmlDeviceGetClockInfo(handle, n.NVML_CLOCK_SM))
        metrics.clock_memory_mhz = self._optional(
            lambda: n.nvmlDeviceGetClockInfo(handle, n.NVML_CLOCK_MEM)
        )
        return metrics

    def close(self) -> None:
        try:
            self._nvml.nvmlShutdown()
        except Exception:
            pass


class NvidiaSmiMonitor:
    """Best-effort monitor fallback using nvidia-smi CSV output."""

    source = "nvidia-smi"
    QUERY_FIELDS = (
        "name",
        "utilization.gpu",
        "utilization.memory",
        "memory.total",
        "memory.used",
        "memory.free",
        "temperature.gpu",
        "power.draw",
        "power.limit",
        "clocks.sm",
        "clocks.mem",
    )

    def __init__(self, device_index: int) -> None:
        executable = shutil.which("nvidia-smi")
        if not executable:
            raise BackendUnavailable("nvidia-smi was not found on PATH")
        self._executable = executable
        self._device_index = device_index
        devices = self.list_devices()
        if device_index < 0 or device_index >= len(devices):
            raise BackendUnavailable(
                f"nvidia-smi device {device_index} is out of range (found {len(devices)})"
            )

    def _run(self, *args: str) -> str:
        completed = subprocess.run(
            [self._executable, *args],
            check=True,
            capture_output=True,
            text=True,
            timeout=5,
        )
        return completed.stdout.strip()

    def list_devices(self) -> list[tuple[int, str]]:
        output = self._run("--query-gpu=index,name", "--format=csv,noheader,nounits")
        devices: list[tuple[int, str]] = []
        for row in csv.reader(output.splitlines()):
            if len(row) >= 2:
                devices.append((int(row[0].strip()), row[1].strip()))
        return devices

    @staticmethod
    def _number(value: str) -> float | None:
        cleaned = value.strip()
        if not cleaned or cleaned.upper() in {"N/A", "[NOT SUPPORTED]"}:
            return None
        try:
            return float(cleaned)
        except ValueError:
            return None

    def sample(self) -> GpuMetrics:
        output = self._run(
            f"--query-gpu={','.join(self.QUERY_FIELDS)}",
            "--format=csv,noheader,nounits",
            "-i",
            str(self._device_index),
        )
        row = next(csv.reader(output.splitlines()))
        values = list(row) + [""] * (len(self.QUERY_FIELDS) - len(row))
        return GpuMetrics(
            timestamp=time.time(),
            name=values[0].strip() or None,
            utilization_gpu=self._number(values[1]),
            utilization_memory=self._number(values[2]),
            memory_total_mib=self._number(values[3]),
            memory_used_mib=self._number(values[4]),
            memory_free_mib=self._number(values[5]),
            temperature_c=self._number(values[6]),
            power_w=self._number(values[7]),
            power_limit_w=self._number(values[8]),
            clock_sm_mhz=self._number(values[9]),
            clock_memory_mhz=self._number(values[10]),
        )

    def close(self) -> None:
        return None


class NullMonitor:
    source = "none"

    def sample(self) -> GpuMetrics:
        return GpuMetrics(timestamp=time.time())

    def list_devices(self) -> list[tuple[int, str]]:
        return []

    def close(self) -> None:
        return None


def make_monitor(device_index: int, allow_none: bool = True) -> Monitor:
    errors: list[str] = []
    for monitor_type in (NvmlMonitor, NvidiaSmiMonitor):
        try:
            return monitor_type(device_index)
        except Exception as exc:
            errors.append(f"{monitor_type.__name__}: {exc}")
    if allow_none:
        print("warning: GPU monitoring unavailable; " + " | ".join(errors), file=sys.stderr)
        return NullMonitor()
    raise BackendUnavailable("GPU monitoring unavailable; " + " | ".join(errors))


def safe_sample(monitor: Monitor, previous: GpuMetrics | None = None) -> GpuMetrics:
    """Read telemetry without turning a transient monitor failure into a GPU abort."""
    try:
        return monitor.sample()
    except Exception as exc:
        print(f"warning: {monitor.source} sample failed: {exc}", file=sys.stderr)
        if previous is not None:
            return replace(previous, timestamp=time.time())
        return GpuMetrics(timestamp=time.time())


class StressBackend:
    name = "base"
    dtype_name = "unknown"
    workload_name = "unknown"
    device_name = "unknown"
    resident_memory_mib = 0.0
    problem_size = 0
    chunk_seconds = DEFAULT_CHUNK_SECONDS

    def prepare(self, memory_mib: float, dtype: str, chunk_seconds: float) -> None:
        raise NotImplementedError

    def run_chunk(self) -> float:
        raise NotImplementedError

    def close(self) -> None:
        return None

    @staticmethod
    def _calibrate(
        operation: Callable[[], None],
        synchronize: Callable[[], None],
        target_seconds: float,
        max_iterations: int = 256,
    ) -> tuple[int, float]:
        operation()
        synchronize()
        start = time.perf_counter()
        operation()
        synchronize()
        single = max(time.perf_counter() - start, 1e-6)
        iterations = max(1, min(max_iterations, int(math.ceil(target_seconds / single))))
        start = time.perf_counter()
        for _ in range(iterations):
            operation()
        synchronize()
        measured = max(time.perf_counter() - start, 1e-6)
        return iterations, measured


def _resolve_budget_mib(requested_mib: float, free_mib: float, total_mib: float) -> float:
    reserve_mib = max(128.0, total_mib * 0.05)
    available = max(0.0, free_mib - reserve_mib)
    effective = min(requested_mib, available)
    if effective < 16.0:
        raise BackendUnavailable(
            f"insufficient free VRAM: free={free_mib:.0f} MiB, reserve={reserve_mib:.0f} MiB"
        )
    return effective


def choose_matrix_size(
    memory_mib: float,
    bytes_per_element: int,
    buffers: int = 3,
    alignment: int = 256,
    minimum: int = 512,
    maximum: int = 8192,
) -> int:
    """Choose a square matrix size while leaving headroom for library workspaces."""
    usable_bytes = memory_mib * MIB * 0.70
    raw = int(math.sqrt(usable_bytes / max(buffers * bytes_per_element, 1)))
    aligned = (raw // alignment) * alignment
    return max(minimum, min(maximum, aligned))


class TorchBackend(StressBackend):
    name = "torch"
    workload_name = "cuBLAS GEMM"

    def __init__(self, device_index: int) -> None:
        try:
            import torch  # type: ignore
        except Exception as exc:
            raise BackendUnavailable(f"PyTorch import failed: {exc}") from exc
        if not torch.cuda.is_available():
            raise BackendUnavailable("PyTorch is installed without a usable CUDA runtime")
        if device_index < 0 or device_index >= torch.cuda.device_count():
            raise BackendUnavailable(
                f"CUDA device {device_index} is out of range (found {torch.cuda.device_count()})"
            )
        self.torch = torch
        self.device_index = device_index
        self.device = torch.device(f"cuda:{device_index}")
        self.device_name = str(torch.cuda.get_device_name(device_index))
        self._iterations = 1
        self._a = self._b = self._out = None

    def _sync(self) -> None:
        self.torch.cuda.synchronize(self.device)

    def prepare(self, memory_mib: float, dtype: str, chunk_seconds: float) -> None:
        t = self.torch
        with t.cuda.device(self.device):
            free_bytes, total_bytes = t.cuda.mem_get_info()
            budget = _resolve_budget_mib(memory_mib, free_bytes / MIB, total_bytes / MIB)
            selected = dtype
            if selected == "auto":
                selected = "float32"
            torch_dtype = t.float16 if selected == "float16" else t.float32
            bytes_per_element = 2 if selected == "float16" else 4
            n = choose_matrix_size(budget, bytes_per_element)
            last_error: Exception | None = None
            while n >= 512:
                try:
                    t.cuda.empty_cache()
                    self._a = t.full((n, n), 0.001, device=self.device, dtype=torch_dtype)
                    self._b = t.full((n, n), 0.002, device=self.device, dtype=torch_dtype)
                    self._out = t.empty((n, n), device=self.device, dtype=torch_dtype)
                    break
                except Exception as exc:  # pragma: no cover - requires CUDA OOM
                    last_error = exc
                    self._a = self._b = self._out = None
                    t.cuda.empty_cache()
                    n -= 256
            if self._out is None:
                raise BackendUnavailable(f"PyTorch could not allocate a safe GEMM workspace: {last_error}")

            try:
                # Portable stress defaults to real FP32 CUDA-core GEMM. Users
                # can opt into Tensor Core work explicitly with --dtype float16.
                t.backends.cuda.matmul.allow_tf32 = False
            except Exception:
                pass
            self.dtype_name = selected
            self.problem_size = n
            self.resident_memory_mib = (3 * n * n * bytes_per_element) / MIB

            def operation() -> None:
                t.mm(self._a, self._b, out=self._out)

            self._operation = operation
            self._iterations, measured = self._calibrate(operation, self._sync, chunk_seconds)
            self.chunk_seconds = measured

    def run_chunk(self) -> float:
        start = time.perf_counter()
        for _ in range(self._iterations):
            self._operation()
        self._sync()
        self.chunk_seconds = max(time.perf_counter() - start, 1e-6)
        return self.chunk_seconds

    def close(self) -> None:
        try:
            self._a = self._b = self._out = None
            self.torch.cuda.empty_cache()
        except Exception:
            pass


class CupyBackend(StressBackend):
    name = "cupy"
    workload_name = "cuBLAS GEMM"

    def __init__(self, device_index: int) -> None:
        try:
            import cupy as cp  # type: ignore
        except Exception as exc:
            raise BackendUnavailable(f"CuPy import failed: {exc}") from exc
        try:
            count = int(cp.cuda.runtime.getDeviceCount())
        except Exception as exc:
            raise BackendUnavailable(f"CuPy cannot access the CUDA driver: {exc}") from exc
        if device_index < 0 or device_index >= count:
            raise BackendUnavailable(f"CUDA device {device_index} is out of range (found {count})")
        self.cp = cp
        self.device_index = device_index
        self.device = cp.cuda.Device(device_index)
        props = cp.cuda.runtime.getDeviceProperties(device_index)
        raw_name = props.get("name", f"CUDA device {device_index}")
        self.device_name = raw_name.decode() if isinstance(raw_name, bytes) else str(raw_name)
        self._major = int(props.get("major", 0))
        self._iterations = 1
        self._a = self._b = self._out = None

    def _sync(self) -> None:
        self.cp.cuda.get_current_stream().synchronize()

    def prepare(self, memory_mib: float, dtype: str, chunk_seconds: float) -> None:
        cp = self.cp
        with self.device:
            free_bytes, total_bytes = self.device.mem_info
            budget = _resolve_budget_mib(memory_mib, free_bytes / MIB, total_bytes / MIB)
            selected = dtype
            if selected == "auto":
                selected = "float32"
            cupy_dtype = cp.float16 if selected == "float16" else cp.float32
            bytes_per_element = 2 if selected == "float16" else 4
            n = choose_matrix_size(budget, bytes_per_element)
            last_error: Exception | None = None
            while n >= 512:
                try:
                    cp.get_default_memory_pool().free_all_blocks()
                    self._a = cp.full((n, n), 0.001, dtype=cupy_dtype)
                    self._b = cp.full((n, n), 0.002, dtype=cupy_dtype)
                    self._out = cp.empty((n, n), dtype=cupy_dtype)
                    break
                except Exception as exc:  # pragma: no cover - requires CUDA OOM
                    last_error = exc
                    self._a = self._b = self._out = None
                    cp.get_default_memory_pool().free_all_blocks()
                    n -= 256
            if self._out is None:
                raise BackendUnavailable(f"CuPy could not allocate a safe GEMM workspace: {last_error}")

            self.dtype_name = selected
            self.problem_size = n
            self.resident_memory_mib = (3 * n * n * bytes_per_element) / MIB

            def operation() -> None:
                cp.matmul(self._a, self._b, out=self._out)

            self._operation = operation
            self._iterations, measured = self._calibrate(operation, self._sync, chunk_seconds)
            self.chunk_seconds = measured

    def run_chunk(self) -> float:
        start = time.perf_counter()
        for _ in range(self._iterations):
            self._operation()
        self._sync()
        self.chunk_seconds = max(time.perf_counter() - start, 1e-6)
        return self.chunk_seconds

    def close(self) -> None:
        try:
            self._a = self._b = self._out = None
            self.cp.get_default_memory_pool().free_all_blocks()
        except Exception:
            pass


class NumbaBackend(StressBackend):
    name = "numba"
    dtype_name = "float32"
    workload_name = "compute-heavy CUDA kernel"

    def __init__(self, device_index: int) -> None:
        try:
            import numpy as np  # type: ignore
            from numba import cuda  # type: ignore
        except Exception as exc:
            raise BackendUnavailable(f"Numba CUDA import failed: {exc}") from exc
        if not cuda.is_available():
            raise BackendUnavailable("Numba CUDA is not available")
        try:
            cuda.select_device(device_index)
            device = cuda.get_current_device()
        except Exception as exc:
            raise BackendUnavailable(f"Numba cannot select CUDA device {device_index}: {exc}") from exc
        self.np = np
        self.cuda = cuda
        self.device = device
        raw_name = getattr(device, "name", f"CUDA device {device_index}")
        self.device_name = raw_name.decode() if isinstance(raw_name, bytes) else str(raw_name)
        self._iterations = 1
        self._rounds = 4096
        self._data = None

    def _sync(self) -> None:
        self.cuda.synchronize()

    def prepare(self, memory_mib: float, dtype: str, chunk_seconds: float) -> None:
        del memory_mib
        if dtype == "float16":
            raise BackendUnavailable("Numba fallback currently supports float32 only")
        cuda = self.cuda
        np = self.np
        multiprocessors = int(getattr(self.device, "MULTIPROCESSOR_COUNT", 16))
        threads = 256
        blocks = max(32, multiprocessors * 8)
        count = blocks * threads

        @cuda.jit
        def compute_kernel(data, rounds):
            index = cuda.grid(1)
            if index < data.size:
                x = data[index]
                y = x + 0.125
                z = x + 0.25
                w = x + 0.5
                for step in range(rounds):
                    x = x * 1.000000119 + y * 0.0000031 + 0.0000007
                    y = y * 0.999999881 + z * 0.0000029 + 0.0000009
                    z = z * 1.000000071 + w * 0.0000027 + 0.0000011
                    w = w * 0.999999929 + x * 0.0000025 + 0.0000013
                    if step % 256 == 255:
                        x *= 0.999
                        y *= 0.999
                        z *= 0.999
                        w *= 0.999
                data[index] = x + y + z + w

        host = np.full(count, 0.25, dtype=np.float32)
        self._data = cuda.to_device(host)
        self._kernel = compute_kernel
        self._blocks = blocks
        self._threads = threads
        self.problem_size = count
        self.resident_memory_mib = host.nbytes / MIB

        def operation() -> None:
            self._kernel[self._blocks, self._threads](self._data, self._rounds)

        self._operation = operation
        operation()  # includes JIT compilation
        self._sync()
        self._iterations, measured = self._calibrate(operation, self._sync, chunk_seconds, 64)
        self.chunk_seconds = measured

    def run_chunk(self) -> float:
        start = time.perf_counter()
        for _ in range(self._iterations):
            self._operation()
        self._sync()
        self.chunk_seconds = max(time.perf_counter() - start, 1e-6)
        return self.chunk_seconds

    def close(self) -> None:
        self._data = None


def make_backend(
    backend_name: str,
    device_index: int,
    memory_mib: float,
    dtype: str,
    chunk_seconds: float,
) -> tuple[StressBackend, list[str]]:
    classes = {"torch": TorchBackend, "cupy": CupyBackend, "numba": NumbaBackend}
    candidates: Iterable[str] = BACKEND_ORDER if backend_name == "auto" else (backend_name,)
    errors: list[str] = []
    for candidate in candidates:
        backend: StressBackend | None = None
        try:
            backend = classes[candidate](device_index)
            backend.prepare(memory_mib, dtype, chunk_seconds)
            return backend, errors
        except Exception as exc:
            errors.append(f"{candidate}: {exc}")
            if backend is not None:
                backend.close()
    raise BackendUnavailable("no GPU stress backend could start; " + " | ".join(errors))


class UtilizationController:
    """PI controller that turns target utilization into a synchronized duty cycle."""

    def __init__(self, mode: str, kp: float = 0.35, ki: float = 0.08) -> None:
        self.requested_mode = mode
        self.mode = mode
        self.kp = kp
        self.ki = ki
        self.integral = 0.0
        self.duty = 0.0
        self._ema: float | None = None
        self._last_target: float | None = None

    def reset(self, target_percent: float) -> None:
        self.integral = 0.0
        self.duty = max(0.0, min(target_percent / 100.0, 1.0))
        self._ema = None
        self._last_target = target_percent

    def retarget(self, target_percent: float) -> float:
        """Move to a new profile target without reusing one sample repeatedly."""
        target_percent = max(0.0, min(target_percent, 100.0))
        if self._last_target is None:
            self.reset(target_percent)
            return self.duty
        delta = target_percent - self._last_target
        if abs(delta) >= 10.0:
            self.reset(target_percent)
        else:
            self.duty = max(0.0, min(1.0, self.duty + delta / 100.0))
            self._last_target = target_percent
        return self.duty

    def update(
        self,
        target_percent: float,
        measured_percent: float | None,
        elapsed_seconds: float,
    ) -> float:
        self.retarget(target_percent)
        base = max(0.0, min(target_percent / 100.0, 1.0))

        if self.mode == "duty" or measured_percent is None:
            self.duty = base
            return self.duty

        alpha = 0.35
        self._ema = measured_percent if self._ema is None else alpha * measured_percent + (1 - alpha) * self._ema
        error = (target_percent - self._ema) / 100.0
        self.integral = max(-1.5, min(1.5, self.integral + error * elapsed_seconds))
        self.duty = max(0.0, min(1.0, self.duty + self.kp * error + self.ki * self.integral))
        if target_percent <= 0.0:
            self.duty = 0.0
        return self.duty


class CsvLogger:
    FIELDNAMES = [
        "timestamp",
        "elapsed_s",
        "profile_target_percent",
        "commanded_duty_percent",
        "thermal_paused",
        "backend",
        "workload",
        "dtype",
        "problem_size",
        "resident_memory_mib",
        "chunk_ms",
        *[f.name for f in fields(GpuMetrics) if f.name != "timestamp"],
    ]

    def __init__(self, path: str | None) -> None:
        self._file = None
        self._writer = None
        if path:
            output = Path(path).expanduser()
            output.parent.mkdir(parents=True, exist_ok=True)
            self._file = output.open("w", newline="", encoding="utf-8")
            self._writer = csv.DictWriter(self._file, fieldnames=self.FIELDNAMES)
            self._writer.writeheader()

    def write(
        self,
        elapsed: float,
        target: float,
        duty: float,
        thermal_paused: bool,
        backend: StressBackend,
        metrics: GpuMetrics,
    ) -> None:
        if self._writer is None:
            return
        row: dict[str, Any] = {
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S%z", time.localtime(metrics.timestamp)),
            "elapsed_s": round(elapsed, 3),
            "profile_target_percent": round(target, 3),
            "commanded_duty_percent": round(duty * 100.0, 3),
            "thermal_paused": thermal_paused,
            "backend": backend.name,
            "workload": backend.workload_name,
            "dtype": backend.dtype_name,
            "problem_size": backend.problem_size,
            "resident_memory_mib": round(backend.resident_memory_mib, 3),
            "chunk_ms": round(backend.chunk_seconds * 1000.0, 3),
        }
        for metric_field in fields(GpuMetrics):
            if metric_field.name != "timestamp":
                row[metric_field.name] = getattr(metrics, metric_field.name)
        self._writer.writerow(row)
        self._file.flush()

    def close(self) -> None:
        if self._file is not None:
            self._file.close()


def _positive_float(value: str) -> float:
    parsed = float(value)
    if parsed <= 0:
        raise argparse.ArgumentTypeError("must be greater than 0")
    return parsed


def _nonnegative_float(value: str) -> float:
    parsed = float(value)
    if parsed < 0:
        raise argparse.ArgumentTypeError("must be zero or greater")
    return parsed


def _nonnegative_int(value: str) -> int:
    parsed = int(value)
    if parsed < 0:
        raise argparse.ArgumentTypeError("must be zero or greater")
    return parsed


def _percent(value: str) -> float:
    parsed = float(value)
    if parsed < 0 or parsed > 100:
        raise argparse.ArgumentTypeError("must be between 0 and 100")
    return parsed


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Adaptive low-VRAM NVIDIA GPU stress test with multiple CUDA backends."
    )
    parser.add_argument("--duration", type=_positive_float, metavar="SECONDS")
    parser.add_argument("--load", type=_percent, default=100.0, metavar="PERCENT")
    parser.add_argument("--profile", choices=("constant", "pulsed", "ramp"), default="constant")
    parser.add_argument("--high-load", type=_percent, default=100.0, metavar="PERCENT")
    parser.add_argument("--low-load", type=_percent, default=0.0, metavar="PERCENT")
    parser.add_argument("--on-time", type=_positive_float, default=1.0, metavar="SECONDS")
    parser.add_argument("--off-time", type=_positive_float, default=1.0, metavar="SECONDS")
    parser.add_argument("--start-load", type=_percent, default=0.0, metavar="PERCENT")
    parser.add_argument("--end-load", type=_percent, default=100.0, metavar="PERCENT")
    parser.add_argument("--device", type=_nonnegative_int, default=0, metavar="INDEX")
    parser.add_argument(
        "--monitor-device",
        type=_nonnegative_int,
        metavar="INDEX",
        help="physical NVML/nvidia-smi index when CUDA_VISIBLE_DEVICES remaps --device",
    )
    parser.add_argument("--backend", choices=("auto", *BACKEND_ORDER), default="auto")
    parser.add_argument("--dtype", choices=("auto", "float16", "float32"), default="auto")
    parser.add_argument(
        "--memory-mib",
        type=_positive_float,
        default=256.0,
        metavar="MIB",
        help="upper bound for resident workload buffers; actual use is normally lower",
    )
    parser.add_argument(
        "--control",
        choices=("auto", "feedback", "duty"),
        default="auto",
        help="feedback targets measured GPU utilization; duty is open-loop",
    )
    parser.add_argument("--period-ms", type=_positive_float, default=DEFAULT_PERIOD_SECONDS * 1000.0, metavar="MS")
    parser.add_argument("--chunk-ms", type=_positive_float, default=5.0, metavar="MS")
    parser.add_argument("--status-interval", type=_positive_float, default=1.0, metavar="SECONDS")
    parser.add_argument(
        "--temp-limit",
        type=_nonnegative_float,
        default=90.0,
        metavar="C",
        help="pause at this temperature; 0 disables the guard",
    )
    parser.add_argument("--temp-hysteresis", type=_nonnegative_float, default=5.0, metavar="C")
    parser.add_argument("--csv", metavar="PATH", help="write monitoring samples to CSV")
    parser.add_argument("--list-gpus", action="store_true")
    parser.add_argument("--diagnose", action="store_true", help="probe monitor and backend selection, then exit")
    return parser


def profile_target(args: argparse.Namespace, elapsed: float) -> float:
    if args.profile == "constant":
        return float(args.load)
    if args.profile == "pulsed":
        cycle = args.on_time + args.off_time
        return float(args.high_load if elapsed % cycle < args.on_time else args.low_load)
    if args.duration is None:
        return float(args.start_load)
    progress = min(max(elapsed / args.duration, 0.0), 1.0)
    return float(args.start_load + (args.end_load - args.start_load) * progress)


def _fmt(value: float | None, suffix: str = "", width: int = 5) -> str:
    return f"{value:{width}.1f}{suffix}" if value is not None else f"{'N/A':>{width}}{suffix}"


def format_status(
    elapsed: float,
    target: float,
    duty: float,
    paused: bool,
    backend: StressBackend,
    metrics: GpuMetrics,
) -> str:
    state = "THERMAL-PAUSE" if paused else "RUN"
    return (
        f"elapsed={elapsed:7.1f}s state={state:<13} target={target:5.1f}% duty={duty * 100:5.1f}% "
        f"gpu={_fmt(metrics.utilization_gpu, '%')} temp={_fmt(metrics.temperature_c, 'C')} "
        f"power={_fmt(metrics.power_w, 'W', 6)} vram={backend.resident_memory_mib:.0f}MiB "
        f"chunk={backend.chunk_seconds * 1000:.1f}ms"
    )


def list_gpus() -> int:
    monitor = make_monitor(0, allow_none=False)
    try:
        for index, name in monitor.list_devices():
            print(f"{index}: {name}")
        return 0
    finally:
        monitor.close()


def run(args: argparse.Namespace) -> int:
    if args.list_gpus:
        return list_gpus()
    if args.duration is None and not args.diagnose:
        raise StressRuntimeError("--duration is required unless --list-gpus or --diagnose is used")

    monitor_index = args.device if args.monitor_device is None else args.monitor_device
    monitor = make_monitor(monitor_index, allow_none=True)
    backend: StressBackend | None = None
    logger = CsvLogger(args.csv)
    previous_sigterm = signal.getsignal(signal.SIGTERM)

    def handle_signal(_signum, _frame):
        raise KeyboardInterrupt

    signal.signal(signal.SIGTERM, handle_signal)
    try:
        backend, failed_candidates = make_backend(
            args.backend,
            args.device,
            args.memory_mib,
            args.dtype,
            args.chunk_ms / 1000.0,
        )
        for failure in failed_candidates:
            print(f"backend fallback: {failure}", file=sys.stderr)

        first_metrics = safe_sample(monitor)
        requested_control = args.control
        if requested_control == "auto":
            control_mode = "feedback" if first_metrics.utilization_gpu is not None else "duty"
        elif requested_control == "feedback" and first_metrics.utilization_gpu is None:
            print("warning: utilization feedback unavailable; falling back to duty control", file=sys.stderr)
            control_mode = "duty"
        else:
            control_mode = requested_control

        controller = UtilizationController(control_mode)
        initial_target = profile_target(args, 0.0)
        controller.reset(initial_target)
        print(
            f"started backend={backend.name} workload={backend.workload_name} device={args.device} "
            f"gpu={backend.device_name!r} dtype={backend.dtype_name} problem={backend.problem_size} "
            f"resident_vram={backend.resident_memory_mib:.1f}MiB control={control_mode} "
            f"monitor={monitor.source}:{monitor_index}",
            flush=True,
        )
        if args.diagnose:
            print(format_status(0.0, initial_target, controller.duty, False, backend, first_metrics))
            print("diagnosis successful")
            return 0

        duration = float(args.duration)
        period = max(args.period_ms / 1000.0, 0.01)
        start = time.monotonic()
        next_status = start
        last_control_time = start
        work_credit = 0.0
        paused = False
        metrics = first_metrics
        previous_target = initial_target

        while True:
            now = time.monotonic()
            elapsed = now - start
            if elapsed >= duration:
                break
            target = profile_target(args, elapsed)

            if now >= next_status:
                metrics = safe_sample(monitor, metrics)
                control_dt = max(now - last_control_time, 1e-3)
                last_control_time = now
                if args.temp_limit > 0 and metrics.temperature_c is not None:
                    if not paused and metrics.temperature_c >= args.temp_limit:
                        paused = True
                        work_credit = 0.0
                    elif paused and metrics.temperature_c <= args.temp_limit - args.temp_hysteresis:
                        paused = False
                        controller.reset(target)
                duty = 0.0 if paused else controller.update(
                    target, metrics.utilization_gpu, control_dt
                )
                print(format_status(elapsed, target, duty, paused, backend, metrics), flush=True)
                logger.write(elapsed, target, duty, paused, backend, metrics)
                while next_status <= now:
                    next_status += args.status_interval
            else:
                duty = 0.0 if paused else controller.duty

            cycle_start = time.monotonic()
            cycle_end = min(cycle_start + period, start + duration)
            target = profile_target(args, cycle_start - start)
            if target <= 0.0 or target < previous_target - 10.0:
                work_credit = 0.0
            previous_target = target
            if not paused:
                duty = controller.retarget(target)
                if controller.mode == "duty":
                    duty = target / 100.0
                    controller.duty = duty
            work_credit = min(period * 2.0, work_credit + duty * max(cycle_end - cycle_start, 0.0))

            while not paused and time.monotonic() < cycle_end:
                estimated = max(backend.chunk_seconds, 0.0001)
                if work_credit + estimated * 0.25 < estimated:
                    break
                try:
                    actual = backend.run_chunk()
                except Exception as exc:
                    raise StressRuntimeError(
                        f"{backend.name} workload failed during execution: {exc}"
                    ) from exc
                work_credit -= actual
                if work_credit < -period:
                    work_credit = -period

            remaining = cycle_end - time.monotonic()
            if remaining > 0:
                time.sleep(remaining)

        final_metrics = safe_sample(monitor, metrics)
        final_target = profile_target(args, duration)
        final_duty = 0.0 if paused else controller.duty
        print(format_status(duration, final_target, final_duty, paused, backend, final_metrics), flush=True)
        logger.write(duration, final_target, final_duty, paused, backend, final_metrics)
        print("stopped", flush=True)
        return 0
    except KeyboardInterrupt:
        print("interrupted; synchronizing and releasing GPU resources", file=sys.stderr, flush=True)
        return 130
    finally:
        if backend is not None:
            backend.close()
        logger.close()
        monitor.close()
        signal.signal(signal.SIGTERM, previous_sigterm)


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return run(args)
    except (BackendUnavailable, StressRuntimeError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
