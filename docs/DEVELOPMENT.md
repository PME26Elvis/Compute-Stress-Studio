# Development Notes

## Repository components

- `main.py`, `main_window.py`, `stress_test.py`: original PyQt CPU monitor/stress application.
- `cpu_stress_cli.py`: standalone CPU duty-cycle stress CLI.
- `gpu_stress_cli.py`: standalone adaptive NVIDIA GPU stress CLI.
- `tests/test_gpu_stress_cli.py`: CPU-only tests for parser, profile, memory sizing, and feedback-controller logic.
- `requirements.txt`: original GUI/CPU dependencies.
- `requirements-gpu.txt`: recommended GPU CLI dependencies.

The GPU module intentionally does not import PyQt or any CUDA framework at module import time. This keeps `--help`, static checks, and CPU-only unit tests usable without a GPU.

## GPU architecture

### Monitoring layer

`make_monitor()` attempts:

1. `NvmlMonitor` through `nvidia-ml-py`
2. `NvidiaSmiMonitor` through the driver CLI
3. `NullMonitor` for open-loop duty control

NVML is preferred because its API and Python binding are intended for programmatic monitoring across driver versions. The `nvidia-smi` parser is a fallback only.

### Compute layer

`make_backend()` attempts backends in a fixed order unless the user forces one:

1. `TorchBackend`
2. `CupyBackend`
3. `NumbaBackend`

Torch and CuPy reuse three matrices and write into a preallocated output buffer. Numba uses a custom arithmetic kernel with enough blocks to cover the device's multiprocessors.

### Load-control layer

GPU APIs enqueue work asynchronously, so sleeping immediately after a launch does not create a reliable idle interval. Each backend's `run_chunk()` synchronizes before returning. The scheduler then uses a work-credit accumulator over fixed periods. This produces a long-term duty cycle even when the requested work slice is shorter than a single calibrated chunk.

When utilization telemetry exists, `UtilizationController` applies an EMA-filtered PI correction. The controller is deliberately conservative to avoid oscillation from coarse NVML samples. Large profile changes reset the integral state.

### Memory policy

`_resolve_budget_mib()` preserves a driver/display reserve. `choose_matrix_size()` dedicates at most 70% of the effective budget to three resident tensors and aligns dimensions to 256. Backend allocation retries downward after OOM.

## Local validation

CPU-only validation:

```bash
python -m py_compile gpu_stress_cli.py
python -m unittest discover -s tests -v
python gpu_stress_cli.py --help
```

GPU smoke validation:

```bash
python gpu_stress_cli.py --list-gpus
python gpu_stress_cli.py --diagnose
python gpu_stress_cli.py --duration 15 --load 25
python gpu_stress_cli.py --duration 30 --load 100 --csv /tmp/gpu-smoke.csv
```

For a new GPU generation, compare `--dtype auto`, `--dtype float16`, and `--dtype float32`. The workload that reports the highest utilization is not always the one that reaches the highest board power.

## Testing without CUDA

Unit tests must not import torch, cupy, numba, or pynvml. Keep optional imports inside constructors or runtime functions. Pure functions and controllers should remain independently testable.

## Known limitations

- NVML utilization is device-wide, so the feedback loop also sees unrelated graphics or compute work.
- MIG device utilization queries may be unsupported by NVML; open-loop duty control remains available.
- WDDM, laptop power sharing, power caps, and thermal throttling can make target utilization and board power diverge.
- This is a stress/load tool, not an error-detection suite like a dedicated memory checker.
