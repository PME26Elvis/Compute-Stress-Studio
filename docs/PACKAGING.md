# GPU Packaging and Distribution

The repository ships the NVIDIA GPU stress tool in four delivery forms:

1. the full Python source CLI with three backend fallbacks;
2. Windows/Linux portable folder packages using the CuPy/cuBLAS backend;
3. a Linux x86-64 AppImage built from the same portable folder;
4. a CUDA 12 Docker image published to GHCR and attached to Releases as a compressed image archive.

## Personal preset

The packaged applications use these defaults when duration/load are omitted:

```text
--duration 345600 --load 87
```

That is 96 hours and an 87% target GPU utilization. Explicit `--duration`, `--load`, or `--profile` values are preserved. `--help`, `--diagnose`, and `--list-gpus` remain informational and never receive the long-run defaults.

The full source `gpu_stress_cli.py` still requires an explicit duration. The personal behavior is implemented in `gpu_stress_portable.py`, the Windows background launcher, Docker defaults, Compose, and convenience launchers.

## Which package should I use?

| Package | Host setup | Main advantage | Main tradeoff |
| --- | --- | --- | --- |
| Windows personal ZIP | NVIDIA driver only | Double-click hidden P2200 run, no Python/pip | Large one-folder bundle |
| Linux folder archive | NVIDIA driver only | Transparent extracted layout | Host glibc compatibility matters |
| Linux AppImage | NVIDIA driver only | One executable file | Large file; some hosts need extract-and-run mode |
| Docker/GHCR | Docker GPU support plus NVIDIA driver | Reproducible environment | Docker and image-layer storage are required |
| Source CLI | Python plus CUDA Python backend | All three backend fallbacks | Requires environment setup |

## HDD and disk-I/O behavior

The stress workload is compute-bound, not storage-bound:

- matrices are allocated once and reused in VRAM;
- scheduler/controller state stays in RAM;
- no test data is streamed from disk;
- CSV writes are small and periodic;
- CuPy may create a small cache on first use.

The Windows/Linux folder packages can live entirely on an HDD. The Windows hidden launcher intentionally writes its PID, console log, and CSV under `P2200-Runs` inside the extracted folder, so those files remain on the same HDD.

PyInstaller one-folder mode is retained for the CUDA worker because one-file mode would unpack hundreds of megabytes of runtime libraries on every launch. Only the tiny Windows background launcher uses PyInstaller one-file mode.

Docker differs: after `docker load`, layers are copied into Docker's configured data root even when the downloaded `.tar.zst` lives on an HDD.

## Windows personal package

The Windows ZIP contains:

```text
GPU-Stress-P2200-Background.exe
GPU-Stress-P2200-Worker.exe
GPU-Stress-Portable.exe
START-P2200-96H-87.cmd
STOP-P2200-GPU-STRESS.cmd
QUADRO_P2200_PERSONAL_PRESET.md
_internal\...
```

### Background launcher architecture

`GPU-Stress-P2200-Background.exe` is built with the Windows GUI subsystem (`console=False`). It:

1. checks `P2200-Runs\gpu-stress-p2200.pid`;
2. refuses to create a duplicate active worker;
3. starts `GPU-Stress-P2200-Worker.exe` with `CREATE_NO_WINDOW`, `DETACHED_PROCESS`, and `CREATE_NEW_PROCESS_GROUP`;
4. redirects stdout/stderr to `P2200-Runs\gpu-stress-p2200-console.log`;
5. adds the 96-hour/87% defaults and CSV path only when omitted;
6. exits immediately while the worker remains active.

The worker has a stable executable name so users can stop it without resolving a PID:

```cmd
taskkill /F /T /IM GPU-Stress-P2200-Worker.exe
```

`GPU-Stress-Portable.exe` is copied as a compatibility alias of the same console worker.

## Portable CUDA contents

The worker bundles:

- Python interpreter;
- CuPy and NumPy;
- NVML Python bindings;
- CUDA 12 runtime, NVRTC, cuBLAS, and nvJitLink component libraries;
- the adaptive controller, thermal guard, telemetry, and CSV logger.

A compatible NVIDIA display driver remains required. Python, pip, and a system-wide CUDA Toolkit are not required.

The portable worker is CuPy-only. Bundling PyTorch, CuPy, and Numba together would duplicate large runtimes and create more platform-specific DLL/JIT failure modes. The source CLI keeps the full fallback chain.

## Linux folder package

```bash
tar -xzf GPU-Stress-Portable-Linux-x64.tar.gz
cd GPU-Stress-Portable
chmod +x GPU-Stress-Portable
./GPU-Stress-Portable --diagnose
./GPU-Stress-Portable
```

The final command uses the personal defaults.

## Linux AppImage

The workflow builds `GPU-Stress-Portable-x86_64.AppImage` by placing the validated PyInstaller folder under:

```text
AppDir/usr/bin/GPU-Stress-Portable/
```

`AppRun` executes the bundled CLI and forwards all arguments. Desktop metadata and an SVG icon are included at the AppDir root and under standard `usr/share` locations.

Usage:

```bash
chmod +x GPU-Stress-Portable-x86_64.AppImage
./GPU-Stress-Portable-x86_64.AppImage --diagnose
./GPU-Stress-Portable-x86_64.AppImage
```

For hosts without working FUSE integration:

```bash
APPIMAGE_EXTRACT_AND_RUN=1 ./GPU-Stress-Portable-x86_64.AppImage --diagnose
```

The AppImage is produced with the official AppImageKit `appimagetool` continuous release. CI validates it using extract-and-run mode so hosted runners do not require FUSE.

## Docker image

The image default command is:

```text
--duration 345600 --load 87 --csv /results/gpu-stress.csv
```

Pull and use the personal default:

```bash
docker pull ghcr.io/pme26elvis/cpu-monitor-stress-tool-gpu:latest
mkdir -p results
docker run --rm --gpus all \
  -v "$PWD/results:/results" \
  ghcr.io/pme26elvis/cpu-monitor-stress-tool-gpu:latest
```

Custom parameters replace the Docker CMD:

```bash
docker run --rm --gpus all \
  ghcr.io/pme26elvis/cpu-monitor-stress-tool-gpu:latest \
  --duration 300 --load 80
```

Linux hosts need an NVIDIA driver, Docker Engine, and NVIDIA Container Toolkit. Windows uses Docker Desktop/WSL2 GPU support. The container never bundles or replaces the host display driver.

## Quadro P2200 target

The personal Windows workflow targets the user's Quadro P2200 5 GB machine. The default portable workload remains FP32 CuPy/cuBLAS with a 256 MiB upper VRAM budget. The goal is sustained compute loading without intentionally filling the 5 GB framebuffer.

Recommended first-run sequence:

```cmd
GPU-Stress-P2200-Worker.exe --diagnose
GPU-Stress-P2200-Worker.exe --duration 30 --load 25
GPU-Stress-P2200-Worker.exe --duration 1800 --load 87
```

Only after those checks should the hidden 96-hour run be started.

## Release workflow

`.github/workflows/release-gpu-packages.yml`:

1. builds the Windows worker and hidden launcher;
2. assembles the personal ZIP with scripts and guide;
3. builds and validates the Linux one-folder package;
4. builds and validates the AppImage;
5. builds and smoke-checks the CUDA 12 container;
6. pushes versioned and `latest` GHCR tags on non-PR runs;
7. exports the Docker image to `.tar.zst`;
8. generates SHA256 checksums;
9. creates or updates a GitHub Release.

Relevant pushes to `main` create an automatic `gpu-v0.3.<run-number>` release.

## Build locally

Portable worker:

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

Windows hidden launcher:

```powershell
python -m PyInstaller --noconfirm packaging/gpu_stress_background.spec
```

Docker:

```bash
docker build -f Dockerfile.gpu -t gpu-stress:local .
docker run --rm --gpus all gpu-stress:local --diagnose
```
