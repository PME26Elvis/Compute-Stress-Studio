# Development Notes

## Repository components

- `main.py`, `main_window.py`, `stress_test.py`: original PyQt CPU monitor/stress application.
- `cpu_stress_cli.py`: standalone CPU duty-cycle stress CLI.
- `gpu_stress_cli.py`: full adaptive NVIDIA GPU stress CLI.
- `gpu_stress_portable.py`: frozen-app entry point that configures bundled CUDA libraries, applies personal defaults, and forces CuPy.
- `gpu_stress_background.py`: Windows-only hidden launcher for the Quadro P2200 personal workflow.
- `packaging/gpu_stress_portable.spec`: PyInstaller one-folder worker definition.
- `packaging/gpu_stress_background.spec`: PyInstaller one-file Windows GUI-subsystem launcher definition.
- `packaging/appimage/*`: AppDir launcher, desktop metadata, and icon.
- `Dockerfile.gpu`: CUDA 12 runtime container using the CuPy backend.
- `docker-compose.gpu.yml`: Compose launcher with GPU reservation and personal defaults.
- `tests/test_gpu_stress_cli.py`: parser, profile, sizing, and controller tests.
- `tests/test_gpu_stress_portable.py`: portable backend and 96-hour/87-percent default tests.
- `tests/test_gpu_stress_background.py`: hidden launcher argument tests.
- `docs/QUADRO_P2200_PERSONAL_PRESET.md`: user-specific Traditional Chinese operation guide.

GPU modules do not import a CUDA framework at module import time. This keeps static checks, `--help`, and CPU-only tests usable on runners without NVIDIA hardware.

## GPU architecture

### Monitoring layer

`make_monitor()` attempts:

1. `NvmlMonitor` through `nvidia-ml-py`;
2. `NvidiaSmiMonitor` through the driver CLI;
3. `NullMonitor` for open-loop duty control.

### Compute layer

`make_backend()` attempts:

1. `TorchBackend`;
2. `CupyBackend`;
3. `NumbaBackend`.

The portable packages force CuPy. Torch and CuPy reuse three matrices and a preallocated output buffer. Numba uses a compute-heavy custom CUDA kernel.

### Load-control layer

Each `run_chunk()` synchronizes before returning. The scheduler uses a work-credit accumulator over fixed periods so the long-term duty cycle remains meaningful even when a requested work slice is shorter than a calibrated kernel chunk.

When utilization telemetry exists, `UtilizationController` uses an EMA-filtered PI correction. Large target changes reset controller state.

### Memory policy

`_resolve_budget_mib()` preserves driver/display headroom. `choose_matrix_size()` uses at most 70% of the effective budget for three resident tensors, aligns dimensions to 256, and retries smaller allocations after OOM.

## Personal default layer

`gpu_stress_portable.py` defines:

```text
DEFAULT_DURATION_SECONDS = 345600
DEFAULT_LOAD_PERCENT = 87.0
```

`_apply_personal_defaults()`:

- adds duration only when `--duration` is absent;
- adds load only when both `--load` and `--profile` are absent;
- preserves split and equals-style options;
- leaves `--help`, `--diagnose`, and `--list-gpus` untouched.

`build_portable_arguments()` then forces `--backend cupy`.

The source `gpu_stress_cli.py` is intentionally unchanged and still requires an explicit duration. This prevents a source checkout from unexpectedly starting a 96-hour run while making packaged delivery convenient for the user's machine.

## Windows hidden launcher

`gpu_stress_background.py` is frozen with `console=False`, so Windows does not allocate a console window when it is double-clicked or launched from CMD.

The launcher locates `GPU-Stress-P2200-Worker.exe` beside itself and starts it with:

- `CREATE_NO_WINDOW`;
- `DETACHED_PROCESS`;
- `CREATE_NEW_PROCESS_GROUP`;
- stdin redirected from `DEVNULL`;
- stdout/stderr appended to `P2200-Runs/gpu-stress-p2200-console.log`.

It writes the worker PID to `P2200-Runs/gpu-stress-p2200.pid`. Before launching, it uses `OpenProcess` and `GetExitCodeProcess` to reject a duplicate active PID.

The stable worker image name enables a simple stop command:

```cmd
taskkill /F /T /IM GPU-Stress-P2200-Worker.exe
```

The release workflow also copies the worker to `GPU-Stress-Portable.exe` as a compatibility alias. The background launcher always uses the P2200-specific worker name.

## Portable CUDA discovery

CUDA component wheels install under the `nvidia` Python namespace. The spec copies the namespace into the one-folder application. Before importing CuPy, the portable entry point:

1. finds component `bin`, `lib`, `lib64`, and `lib/x64` directories;
2. prepends them to process search paths;
3. registers Windows DLL directories;
4. explicitly preloads Linux CUDA shared objects globally;
5. sets `CUDA_PATH` when needed;
6. places the CuPy cache in the user's normal cache directory.

The host display driver remains external.

## AppImage architecture

The Linux job first builds and validates the PyInstaller one-folder package. It then creates:

```text
AppDir/
  AppRun
  gpu-stress.desktop
  gpu-stress.svg
  .DirIcon
  usr/bin/GPU-Stress-Portable/
  usr/share/applications/
  usr/share/icons/hicolor/scalable/apps/
```

`AppRun` resolves its own directory and executes the bundled portable CLI while forwarding all arguments. The official AppImageKit `appimagetool` continuous build creates `GPU-Stress-Portable-x86_64.AppImage`.

CI runs the resulting AppImage with `APPIMAGE_EXTRACT_AND_RUN=1 --help`, avoiding a dependency on FUSE in the hosted runner.

## Container architecture

`Dockerfile.gpu` starts from an NVIDIA CUDA 12 runtime image and installs CuPy plus NVML bindings. The entry point forces CuPy and the default CMD supplies 345600 seconds, 87%, and CSV output under `/results`.

NVIDIA Container Toolkit injects the host driver-facing libraries and selected GPU devices. The image never includes the host display driver.

## Release workflow

`.github/workflows/release-gpu-packages.yml`:

1. resolves a manual tag or automatic `gpu-v0.3.<run-number>` tag;
2. builds the Windows worker;
3. builds the no-console Windows background launcher;
4. assembles the scripts and P2200 guide into the Windows ZIP;
5. builds the Linux folder package;
6. builds and validates the AppImage;
7. builds, validates, pushes, and exports the Docker image;
8. enforces the 2 GB per-asset ceiling;
9. generates SHA256 checksums;
10. creates or updates the GitHub Release.

PR runs build all assets but skip GHCR pushes and GitHub Release creation.

## Local validation

CPU-only validation:

```bash
python -m py_compile cpu_stress_cli.py gpu_stress_cli.py gpu_stress_portable.py gpu_stress_background.py
python -m unittest discover -s tests -v
python gpu_stress_cli.py --help
python gpu_stress_portable.py --help
```

Portable worker build:

```bash
python -m PyInstaller --noconfirm --clean packaging/gpu_stress_portable.spec
```

Windows background launcher build:

```powershell
python -m PyInstaller --noconfirm packaging/gpu_stress_background.spec
```

GPU hardware smoke validation on the Quadro P2200:

```cmd
GPU-Stress-P2200-Worker.exe --diagnose
GPU-Stress-P2200-Worker.exe --duration 30 --load 25
GPU-Stress-P2200-Worker.exe --duration 1800 --load 87
```

Container validation:

```bash
docker build -f Dockerfile.gpu -t gpu-stress:local .
docker run --rm gpu-stress:local --help
docker run --rm --gpus all gpu-stress:local --diagnose
```

## Testing without CUDA

Unit tests must not import torch, cupy, numba, or pynvml. Keep optional imports inside constructors or runtime functions. Pure controllers and argument-rewriting helpers must remain independently testable.

Release runners can build packages and validate `--help` without a GPU. Actual CUDA GEMM execution remains a hardware smoke-test requirement.

## Known limitations

- NVML utilization is device-wide and includes unrelated GPU work.
- Target utilization is not a board-power target.
- WDDM, power caps, cooling, and throttling can change behavior.
- The portable and AppImage builds are x86-64 and CuPy-only.
- PyInstaller Linux output can still encounter host glibc compatibility differences.
- AppImage may require `APPIMAGE_EXTRACT_AND_RUN=1` on systems without functional FUSE integration.
- Docker layers use Docker's data root after import.
- The Windows launcher tracks one PID file; forcibly terminating the worker can leave a stale file, which is ignored after the PID is no longer active.
- This is a load/stress tool, not a dedicated GPU memory error detector.
