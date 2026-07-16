# Python GPU packaging and distribution

This document covers the **adaptive Python/CuPy GPU release family only**. For the Flutter desktop app, native JUCE packages, tag policy, and the complete artifact matrix, use [RELEASES.md](RELEASES.md).

## Delivery forms

The Python NVIDIA GPU tool is shipped as:

1. source `gpu_stress_cli.py` with PyTorch, CuPy, and Numba fallback backends;
2. Windows and Linux one-folder portable packages using CuPy/cuBLAS;
3. a Linux x86-64 AppImage built from the validated portable folder;
4. a CUDA 12 Docker/GHCR image and compressed Docker image archive.

The portable distribution requires a compatible NVIDIA display driver but does not require the user to install Python, pip, or a system-wide CUDA Toolkit.

## Personal packaged defaults

When duration and load are omitted, packaged entry points apply:

```text
--duration 345600 --load 87
```

That is a 96-hour run with an 87% target. Explicit `--duration`, `--load`, and `--profile` values take precedence. Informational commands such as `--help`, `--diagnose`, and `--list-gpus` never receive long-run defaults.

The source CLI still requires an explicit duration. Personal behavior lives in `gpu_stress_portable.py`, the Windows hidden launcher, Docker defaults, Compose, and convenience launchers.

## Package selection

| Package | Host setup | Advantage | Tradeoff |
| --- | --- | --- | --- |
| Windows personal ZIP | NVIDIA driver | hidden launcher, no Python/pip | large extracted folder |
| Linux folder archive | NVIDIA driver | transparent layout | host glibc compatibility matters |
| Linux AppImage | NVIDIA driver | one application file | some hosts need extract-and-run mode |
| Docker/GHCR | NVIDIA driver plus Docker GPU support | reproducible userspace | Docker storage/runtime required |
| Source CLI | Python plus a supported CUDA backend | full backend fallback chain | manual environment setup |

## Why one-folder mode

The CUDA worker uses PyInstaller one-folder mode because one-file mode would unpack hundreds of megabytes of Python and CUDA libraries on every start. Only the small Windows background launcher uses one-file mode.

The workload is compute-bound:

- matrices are allocated once and reused in VRAM;
- controller state remains in RAM;
- no test dataset is streamed from disk;
- CSV writes are small and periodic;
- CuPy may create a small first-run cache.

Portable folders may be stored and run from an HDD. Startup and extraction are slower, but steady-state loading is not disk-bound.

## Windows personal package

Published archive:

```text
GPU-Stress-Portable-Windows-x64.zip
```

Important contents:

```text
GPU-Stress-P2200-Background.exe
GPU-Stress-P2200-Worker.exe
GPU-Stress-Portable.exe
START-P2200-96H-87.cmd
STOP-P2200-GPU-STRESS.cmd
QUADRO_P2200_PERSONAL_PRESET.md
_internal/...
```

### Hidden launcher

`GPU-Stress-P2200-Background.exe` is a Windows GUI-subsystem executable. It:

1. checks the PID state under `P2200-Runs`;
2. rejects a duplicate active worker;
3. starts `GPU-Stress-P2200-Worker.exe` detached with no console window;
4. redirects worker output to the personal run directory;
5. applies packaged defaults only when omitted;
6. exits while the worker continues.

Manual stop remains available:

```cmd
taskkill /F /T /IM GPU-Stress-P2200-Worker.exe
```

`GPU-Stress-Portable.exe` is a compatibility alias of the same console worker.

## Bundled CUDA userspace

The one-folder worker includes:

- Python runtime;
- NumPy and CuPy;
- NVML Python bindings;
- CUDA 12 runtime, NVRTC, cuBLAS, and nvJitLink component libraries;
- adaptive utilization controller, duty fallback, thermal guard, telemetry, and CSV logging.

The host NVIDIA display driver remains external. The portable build intentionally does not bundle PyTorch and Numba because three complete GPU stacks would duplicate runtimes and increase platform-specific failure modes.

## Linux folder package

```bash
tar -xzf GPU-Stress-Portable-Linux-x64.tar.gz
cd GPU-Stress-Portable
chmod +x GPU-Stress-Portable
./GPU-Stress-Portable --diagnose
./GPU-Stress-Portable --duration 30 --load 25
```

Running without explicit duration/load uses the packaged personal defaults.

## Linux AppImage

```bash
chmod +x GPU-Stress-Portable-x86_64.AppImage
./GPU-Stress-Portable-x86_64.AppImage --diagnose
```

Where FUSE integration is unavailable:

```bash
APPIMAGE_EXTRACT_AND_RUN=1 ./GPU-Stress-Portable-x86_64.AppImage --diagnose
```

CI builds the AppImage from the already validated PyInstaller folder and smoke-checks it in extract-and-run mode.

## Docker and GHCR

The image default command is:

```text
--duration 345600 --load 87 --csv /results/gpu-stress.csv
```

Current legacy image path:

```bash
docker pull ghcr.io/pme26elvis/cpu-monitor-stress-tool-gpu:latest
```

Example:

```bash
mkdir -p results
docker run --rm --gpus all \
  -v "$PWD/results:/results" \
  ghcr.io/pme26elvis/cpu-monitor-stress-tool-gpu:latest
```

The workflow derives future image names from `GITHUB_REPOSITORY`. After the owner renames the repository to `Compute-Stress-Studio`, future pushes will use the new repository-derived GHCR path. Keep the old image available during migration.

Linux needs NVIDIA Container Toolkit. Windows uses Docker Desktop with WSL2 GPU support. The image never bundles the host display driver.

## Release workflow

`.github/workflows/release-gpu-packages.yml` owns this family. It:

1. resolves the tag and prerelease state;
2. builds the Windows worker and hidden launcher;
3. assembles the Windows personal ZIP;
4. builds and validates the Linux one-folder package;
5. builds and validates the AppImage;
6. builds, validates, pushes, and exports the CUDA container;
7. checks the GitHub 2 GB per-asset ceiling;
8. generates SHA256 checksums;
9. creates or updates the Python GPU GitHub Release.

Pull requests build assets without publishing releases or GHCR tags.

## Local build

```bash
python -m pip install \
  "pyinstaller==6.21.0" \
  "cupy-cuda12x>=13,<15" \
  "nvidia-ml-py>=12,<14" \
  "nvidia-cuda-runtime-cu12>=12,<13" \
  "nvidia-cuda-nvrtc-cu12>=12,<13" \
  "nvidia-cublas-cu12>=12,<13" \
  "nvidia-nvjitlink-cu12>=12,<13"
python -m PyInstaller --noconfirm --clean packaging/gpu_stress_portable.spec
```

Windows background launcher:

```powershell
python -m PyInstaller --noconfirm packaging/gpu_stress_background.spec
```

Container:

```bash
docker build -f Dockerfile.gpu -t gpu-stress:local .
docker run --rm gpu-stress:local --help
docker run --rm --gpus all gpu-stress:local --diagnose
```

## Hardware validation

The portable packages are built on hosted runners without a physical NVIDIA GPU. Before using the 96-hour preset, verify device discovery, a short low-load run, cooling, and external telemetry on the target machine.
