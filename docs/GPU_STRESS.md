# NVIDIA GPU Stress CLI

`gpu_stress_cli.py` is a Python-only command-line stress runner designed for NVIDIA GPUs. Its primary goal is to make `--load` useful across a broad range of GeForce, Quadro/RTX, and datacenter cards without filling VRAM before compute power reaches a high level.

## Why this design

A large tensor does not automatically create a high-power workload. The default workload therefore reuses three modest square matrices and repeatedly runs GEMM through cuBLAS. GEMM has high arithmetic intensity, so the same resident buffers can keep CUDA or Tensor cores busy without continuously allocating memory.

GPU work is asynchronous. The runner synchronizes after each calibrated chunk before applying its sleep interval. This prevents queued kernels from continuing to execute during an intended low-load period.

When NVML utilization data is available, `--control auto` selects a PI feedback controller. It starts with `load / 100` as the duty cycle and corrects it from measured GPU utilization. If NVML is unavailable or unsupported, the tool falls back to open-loop duty-cycle control.

## Install

Recommended backend:

```bash
python -m venv .venv
# Linux/macOS shell
source .venv/bin/activate
# Windows PowerShell: .venv\Scripts\Activate.ps1
pip install -r requirements-gpu.txt
```

Alternative backends can be installed instead of PyTorch:

```bash
# Choose the CuPy wheel matching the installed CUDA major version.
pip install nvidia-ml-py cupy-cuda12x

# Numba custom-kernel fallback. Availability depends on its CUDA runtime/toolchain support.
pip install nvidia-ml-py numpy numba-cuda
```

The script imports all backends lazily. Installing more than one enables automatic fallback in this order:

1. PyTorch + cuBLAS GEMM
2. CuPy + cuBLAS GEMM
3. Numba compute-heavy CUDA kernel

## Examples

List physical NVIDIA devices:

```bash
python gpu_stress_cli.py --list-gpus
```

Run a 10-minute adaptive 80% utilization target:

```bash
python gpu_stress_cli.py --duration 600 --load 80
```

Run full load while logging telemetry:

```bash
python gpu_stress_cli.py --duration 900 --load 100 --csv results/gpu-full.csv
```

Run a burst profile:

```bash
python gpu_stress_cli.py \
  --duration 300 \
  --profile pulsed \
  --high-load 100 \
  --low-load 20 \
  --on-time 5 \
  --off-time 3
```

Run a thermal ramp:

```bash
python gpu_stress_cli.py \
  --duration 600 \
  --profile ramp \
  --start-load 10 \
  --end-load 100
```

Run explicit FP32 CUDA-core work (also the portable `auto` default):

```bash
python gpu_stress_cli.py --duration 300 --load 100 --dtype float32
```

Target FP16/Tensor Core work on supported GPUs:

```bash
python gpu_stress_cli.py --duration 300 --load 100 --dtype float16
```

Probe backend selection and allocation without a sustained run:

```bash
python gpu_stress_cli.py --diagnose --backend auto
```

## How `--load` works

`--load` is a best-effort target for total GPU utilization, not a direct electrical-power percentage.

- `--control feedback`: uses NVML/nvidia-smi utilization samples to adjust compute duty cycle.
- `--control duty`: uses `load / 100` directly as the compute duty cycle.
- `--control auto`: selects feedback when utilization telemetry exists, otherwise duty.

The scheduler uses short synchronized chunks plus a credit accumulator. That accumulator lets low percentages remain meaningful even when one kernel takes longer than the instantaneous work budget: a chunk is executed less frequently rather than being queued asynchronously.

GPU utilization counters are sampled by the driver and can be coarse. Short runs, display activity, another CUDA process, MIG mode, power caps, thermal throttling, and laptop dynamic-power sharing can all affect the measured result.

## VRAM policy

The default `--memory-mib 256` is an upper budget, not a reservation target.

- The runner leaves at least 128 MiB or 5% of total VRAM free, whichever is larger.
- Only 70% of the effective budget is used to size resident matrices, leaving room for CUDA/cuBLAS workspaces.
- Allocation automatically retries with a smaller aligned matrix after an out-of-memory error.
- Three buffers are reused; the stress loop does not allocate a new output per iteration.
- The default matrix dimension is capped at 8192 because larger matrices add VRAM pressure without being necessary for sustained compute load.

Override the budget only when needed:

```bash
python gpu_stress_cli.py --duration 300 --load 100 --memory-mib 128
```

## Thermal guard

The default guard pauses workload submission at 90 °C and resumes after temperature falls by 5 °C:

```bash
python gpu_stress_cli.py --duration 600 --load 100 --temp-limit 85 --temp-hysteresis 5
```

Set `--temp-limit 0` to disable the software guard. Hardware thermal and power protections still belong to the GPU/driver, but disabling the software guard is not recommended for unattended runs.

## Multi-GPU and CUDA_VISIBLE_DEVICES

`--device` selects the CUDA-visible compute device. Normally the same integer is also used for NVML monitoring. `CUDA_VISIBLE_DEVICES` can remap CUDA indices while NVML still exposes physical indices, so use `--monitor-device` when they differ:

```bash
CUDA_VISIBLE_DEVICES=2 python gpu_stress_cli.py \
  --device 0 \
  --monitor-device 2 \
  --duration 300 \
  --load 100
```

Run one process per GPU for concurrent multi-GPU stress.

## Backend notes

### PyTorch

The recommended backend. It uses `torch.mm(..., out=...)`, synchronizes each chunk, and disables TF32 so FP32 mode remains a conventional CUDA-core stress workload. `auto` dtype selects portable FP32. Use `--dtype float16` explicitly to target Tensor Cores on supported GPUs.

### CuPy

Uses the same three-buffer GEMM pattern through `cupy.matmul(..., out=...)`. Install a CuPy wheel matching the CUDA major version available on the machine.

### Numba

Uses a tiny resident float32 array and an arithmetic-heavy custom CUDA kernel. This is a functional fallback when cuBLAS-backed Python frameworks are unavailable, but its exact power behavior varies more by architecture and compiler.

## Exit codes

- `0`: completed successfully
- `2`: configuration, backend, driver, or allocation failure
- `130`: interrupted with Ctrl+C/SIGTERM

## Safety and interpretation

A stress tool can expose unstable overclocks, inadequate power delivery, cooling problems, driver resets, and hardware faults. Start with a short run, watch temperature and power, and do not leave a new configuration unattended. A 100% utilization reading does not guarantee the absolute board power limit; different instruction mixes load different GPU subsystems.
