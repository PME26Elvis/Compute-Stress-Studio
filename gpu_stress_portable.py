#!/usr/bin/env python3
"""Portable CuPy-only entry point for the NVIDIA GPU stress CLI.

The regular source CLI keeps three optional compute backends. Release bundles
use this wrapper so PyInstaller only needs to carry CuPy and the minimal CUDA 12
runtime components needed by the GEMM workload.

The user's personal portable preset is applied only when the corresponding
arguments are omitted: 96 hours and 87 percent target GPU utilization.
"""

from __future__ import annotations

import ctypes
import os
import sys
from pathlib import Path
from typing import Iterable

DEFAULT_DURATION_SECONDS = 96 * 60 * 60
DEFAULT_LOAD_PERCENT = 87.0
_DLL_DIRECTORY_HANDLES: list[object] = []
_PRELOADED_CUDA_LIBRARIES: list[object] = []


def _candidate_roots() -> Iterable[Path]:
    seen: set[Path] = set()
    raw_roots = [
        Path(getattr(sys, "_MEIPASS", Path(sys.executable).resolve().parent)),
        Path(sys.executable).resolve().parent,
        Path(__file__).resolve().parent,
    ]
    for root in raw_roots:
        try:
            resolved = root.resolve()
        except OSError:
            continue
        if resolved not in seen:
            seen.add(resolved)
            yield resolved


def _preload_linux_cuda(search_dirs: list[Path]) -> None:
    """Load CUDA wheel libraries globally before CuPy imports them.

    Changing LD_LIBRARY_PATH after process startup is not consistently honored
    by every ELF loader path. Explicit preloading makes the frozen Linux bundle
    independent of a system-wide CUDA Toolkit.
    """
    if os.name == "nt" or sys.platform == "darwin":
        return

    prefixes = (
        "libnvJitLink.so",
        "libcudart.so",
        "libnvrtc-builtins.so",
        "libnvrtc.so",
        "libcublasLt.so",
        "libcublas.so",
    )
    mode = getattr(ctypes, "RTLD_GLOBAL", 0)
    loaded_paths: set[Path] = set()

    for prefix in prefixes:
        candidates: list[Path] = []
        for directory in search_dirs:
            candidates.extend(path for path in directory.glob(f"{prefix}*") if path.is_file())
        for candidate in sorted(candidates, key=lambda path: (len(path.name), path.name)):
            resolved = candidate.resolve()
            if resolved in loaded_paths:
                continue
            try:
                _PRELOADED_CUDA_LIBRARIES.append(ctypes.CDLL(str(resolved), mode=mode))
                loaded_paths.add(resolved)
                break
            except OSError:
                continue


def _configure_bundled_cuda() -> None:
    """Expose CUDA component wheels copied into a frozen application."""
    search_dirs: list[Path] = []
    cuda_runtime_roots: list[Path] = []

    for root in _candidate_roots():
        nvidia_root = root / "nvidia"
        if not nvidia_root.exists():
            continue
        runtime_root = nvidia_root / "cuda_runtime"
        if runtime_root.exists():
            cuda_runtime_roots.append(runtime_root)
        for pattern in ("*/bin", "*/lib", "*/lib/x64", "*/lib64"):
            search_dirs.extend(path for path in nvidia_root.glob(pattern) if path.is_dir())

    search_dirs = list(dict.fromkeys(path.resolve() for path in search_dirs))

    if search_dirs:
        current_path = os.environ.get("PATH", "")
        prefixes = [str(path) for path in search_dirs]
        os.environ["PATH"] = os.pathsep.join(prefixes + ([current_path] if current_path else []))

        if os.name == "nt" and hasattr(os, "add_dll_directory"):
            for directory in search_dirs:
                try:
                    _DLL_DIRECTORY_HANDLES.append(os.add_dll_directory(str(directory)))
                except OSError:
                    pass
        else:
            current_ld = os.environ.get("LD_LIBRARY_PATH", "")
            os.environ["LD_LIBRARY_PATH"] = os.pathsep.join(
                prefixes + ([current_ld] if current_ld else [])
            )
            _preload_linux_cuda(search_dirs)

    if cuda_runtime_roots and "CUDA_PATH" not in os.environ:
        os.environ["CUDA_PATH"] = str(cuda_runtime_roots[0])

    if "CUPY_CACHE_DIR" not in os.environ:
        if os.name == "nt":
            cache_base = Path(os.environ.get("LOCALAPPDATA", Path.home() / "AppData" / "Local"))
        else:
            cache_base = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
        cache_dir = cache_base / "GPU-Stress-Portable" / "cupy-cache"
        cache_dir.mkdir(parents=True, exist_ok=True)
        os.environ["CUPY_CACHE_DIR"] = str(cache_dir)


def _has_option(argv: list[str], option: str) -> bool:
    return any(value == option or value.startswith(f"{option}=") for value in argv)


def _apply_personal_defaults(argv: list[str]) -> list[str]:
    """Apply 96-hour/87-percent defaults without overriding explicit options."""
    output = list(argv)
    informational = any(
        value in {"-h", "--help", "--diagnose", "--list-gpus"} for value in output
    )
    if informational:
        return output
    if not _has_option(output, "--duration"):
        output.extend(["--duration", str(DEFAULT_DURATION_SECONDS)])
    if not _has_option(output, "--load") and not _has_option(output, "--profile"):
        output.extend(["--load", str(DEFAULT_LOAD_PERCENT)])
    return output


def _force_cupy_backend(argv: list[str]) -> list[str]:
    """Force the backend bundled in the portable distribution."""
    output = list(argv)
    for index, value in enumerate(output):
        if value == "--backend" and index + 1 < len(output):
            output[index + 1] = "cupy"
            return output
        if value.startswith("--backend="):
            output[index] = "--backend=cupy"
            return output
    output.extend(["--backend", "cupy"])
    return output


def build_portable_arguments(argv: list[str]) -> list[str]:
    """Return the final CLI arguments used by every portable package."""
    return _force_cupy_backend(_apply_personal_defaults(argv))


def main() -> int:
    _configure_bundled_cuda()
    from gpu_stress_cli import main as cli_main

    return cli_main(build_portable_arguments(sys.argv[1:]))


if __name__ == "__main__":
    raise SystemExit(main())
