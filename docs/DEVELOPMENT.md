# Development Notes

## Repository components

- `main.py`, `main_window.py`, `stress_test.py`: original PyQt CPU monitor/stress application.
- `cpu_stress_cli.py`: standalone CPU duty-cycle stress CLI.
- `gpu_stress_cli.py`: standalone adaptive NVIDIA GPU stress CLI.
- `gpu_stress_portable.py`: frozen-app entry point that configures bundled CUDA component libraries and forces the CuPy backend.
- `packaging/gpu_stress_portable.spec`: PyInstaller one-folder definition.
- `Dockerfile.gpu`: CUDA 12 runtime container using the CuPy backend.
- `docker-compose.gpu.yml`: local Compose launcher with GPU reservation and CSV volume.
- `tests/test_gpu_stress_cli.py`: CPU-only tests for parser, profile, memory sizing, and feedback-controller logic.
- `tests/test_gpu_stress_portable.py`: CPU-only tests for portable-backend argument handling.
- `requirements.txt`: original GUI/CPU dependencies.
- `requirements-gpu.txt`: recommended full source GPU CLI dependencies.
- `docs/PACKAGING.md`: user and maintainer packaging guide.

The GPU modules intentionally do not import PyQt or a CUDA framework at module import time. This keeps `--help`, static checks, and CPU-only unit tests usable without a GPU.

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

## Portable application architecture

### Why one-folder

PyInstaller one-file mode extracts its Python interpreter, extension modules, and CUDA libraries to a temporary directory every time it starts. CUDA bundles are large, so that design causes unnecessary startup writes and is especially undesirable when the package is stored on an HDD. The release therefore ships a zipped one-folder application.

### Why CuPy-only

The source CLI keeps all three fallback backends. The frozen package intentionally carries one backend:

- CuPy gives direct access to cuBLAS GEMM;
- CuPy wheels exist for Windows and Linux;
- CUDA component wheels can be included beside the application;
- excluding PyTorch and Numba avoids duplicated runtimes and JIT/compiler complexity.

`gpu_stress_portable.py` replaces any supplied backend value with `cupy`. This behavior is covered by CPU-only tests.

### Bundled CUDA discovery

CUDA component wheels install under the `nvidia` Python namespace. The spec copies that namespace into the application. Before importing CuPy, the portable entry point:

1. searches the frozen application roots for `nvidia/*/bin`, `lib`, `lib64`, and `lib/x64` directories;
2. prepends them to `PATH` and `LD_LIBRARY_PATH` as appropriate;
3. registers Windows DLL directories with `os.add_dll_directory()`;
4. points `CUDA_PATH` at the bundled runtime when the user did not set one;
5. puts the CuPy cache in the user's normal cache directory.

The display driver remains a host requirement and is never bundled.

## Container architecture

`Dockerfile.gpu` starts from an NVIDIA CUDA 12 runtime image and installs only CuPy plus NVML Python bindings. NVIDIA Container Toolkit injects the host driver-facing libraries and selected devices when the image is started with `--gpus`.

The image entry point forces `--backend cupy`; all other CLI arguments remain available. `/results` is declared as a volume for CSV output.

The GHCR image name is:

```text
ghcr.io/pme26elvis/cpu-monitor-stress-tool-gpu
```

## Release workflow

`.github/workflows/release-gpu-packages.yml` has four stages:

1. resolve an automatic or manually supplied release tag;
2. build Windows and Linux native PyInstaller packages;
3. build, smoke-check, push, and export the Docker image;
4. download all build artifacts, generate SHA256 checksums, and create/update the GitHub Release.

The native packages are built on their target operating systems because PyInstaller does not cross-build Windows and Linux executables from one host.

The Docker image is exported with `docker save` and zstd compression. The workflow enforces GitHub's 2 GB per-asset ceiling before uploading.

## Local validation

CPU-only validation:

```bash
python -m py_compile cpu_stress_cli.py gpu_stress_cli.py gpu_stress_portable.py
python -m unittest discover -s tests -v
python gpu_stress_cli.py --help
python gpu_stress_portable.py --help
```

GPU smoke validation:

```bash
python gpu_stress_cli.py --list-gpus
python gpu_stress_cli.py --diagnose
python gpu_stress_cli.py --duration 15 --load 25
python gpu_stress_cli.py --duration 30 --load 100 --csv /tmp/gpu-smoke.csv
```

Portable build validation:

```bash
python -m PyInstaller --noconfirm --clean packaging/gpu_stress_portable.spec
./dist/GPU-Stress-Portable/GPU-Stress-Portable --help
```

Container validation:

```bash
docker build -f Dockerfile.gpu -t gpu-stress:local .
docker run --rm gpu-stress:local --help
docker run --rm --gpus all gpu-stress:local --diagnose
```

For a new GPU generation, compare `--dtype auto`, `--dtype float16`, and `--dtype float32`. The workload that reports the highest utilization is not always the one that reaches the highest board power.

## Testing without CUDA

Unit tests must not import torch, cupy, numba, or pynvml. Keep optional imports inside constructors or runtime functions. Pure functions, controllers, and portable argument rewriting should remain independently testable.

The release runners do not need GPUs to build packages or verify `--help`; actual CUDA execution remains a hardware smoke-test requirement.

## Known limitations

- NVML utilization is device-wide, so the feedback loop also sees unrelated graphics or compute work.
- MIG device utilization queries may be unsupported by NVML; open-loop duty control remains available.
- WDDM, laptop power sharing, power caps, and thermal throttling can make target utilization and board power diverge.
- The portable app is x86-64 and CuPy-only.
- PyInstaller Linux bundles can still encounter host glibc compatibility differences; Docker is the reproducible fallback.
- Docker image layers are stored in Docker's data root after import, even when the downloaded archive lives on an HDD.
- This is a stress/load tool, not an error-detection suite like a dedicated memory checker.
