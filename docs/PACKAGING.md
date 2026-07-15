# GPU Packaging and Distribution

The repository ships the NVIDIA GPU stress tool in three forms:

1. the full Python source CLI with three backend fallbacks;
2. a Windows/Linux portable app using the CuPy/cuBLAS backend;
3. a CUDA 12 Docker image published to GHCR and attached to a GitHub Release as a compressed image archive.

## Which package should I use?

| Package | Host setup | Main advantage | Main tradeoff |
| --- | --- | --- | --- |
| Source CLI | Python plus one or more CUDA Python backends | All backend fallbacks and easiest development | Requires pip packages |
| Portable app | NVIDIA driver only | Extract and run; no Python, pip, or CUDA Toolkit | Large folder and CuPy-only backend |
| Docker/GHCR | Docker GPU support plus NVIDIA driver | Reproducible environment and simple updates | Docker itself must be installed and image layers consume disk space |

## HDD and disk-I/O behavior

The stress workload is compute-bound, not storage-bound.

- Matrices are allocated once and then reused in VRAM.
- The scheduler and controller remain in normal system memory.
- No test data is streamed from disk.
- CSV logging writes roughly one short row per status interval.
- CuPy can write a small kernel cache on first use.

The portable app can therefore be extracted to and run from an HDD. An HDD mainly affects extraction, startup, and the first cache creation. Once the test is running, drive speed should not affect GPU utilization or power draw.

The release uses PyInstaller **one-folder** mode instead of one-file mode. One-file applications unpack their bundled libraries to a temporary directory on every launch, creating unnecessary startup I/O and temporary-disk usage. One-folder mode is more suitable for a large CUDA application stored on an HDD.

Docker behaves differently: the downloaded `.tar.zst` release asset may be stored on an HDD, but after `docker load`, the image layers are copied into Docker's configured data root. To keep those layers off the system SSD, configure Docker Desktop/WSL storage or Docker Engine's data root to use the HDD.

## Portable app

### Contents

The portable bundles contain:

- the Python interpreter;
- `gpu_stress_cli.py` and the portable entry point;
- CuPy and NumPy;
- NVML Python bindings;
- CUDA 12 runtime, NVRTC, cuBLAS, and nvJitLink component libraries.

The host still needs a compatible NVIDIA display driver. It does not need Python, pip, or a system-wide CUDA Toolkit.

### Why the portable build is CuPy-only

The full source CLI tries PyTorch, then CuPy, then Numba. Bundling all three would duplicate large CUDA runtimes, increase the release size substantially, and create more platform-specific failure points. The portable entry point forces `--backend cupy`, which still uses cuBLAS GEMM, the adaptive utilization controller, bounded VRAM allocation, thermal protection, telemetry, and CSV logging.

### Windows usage

1. Download `GPU-Stress-Portable-Windows-x64.zip` from Releases.
2. Extract the complete folder to any drive, including an HDD.
3. Open PowerShell or Command Prompt inside the extracted folder.
4. Run:

```powershell
.\GPU-Stress-Portable.exe --list-gpus
.\GPU-Stress-Portable.exe --diagnose
.\GPU-Stress-Portable.exe --duration 30 --load 25
.\GPU-Stress-Portable.exe --duration 300 --load 100 --csv gpu-full.csv
```

Do not move only the `.exe`; the `_internal` folder beside it contains the bundled runtime.

### Linux usage

```bash
tar -xzf GPU-Stress-Portable-Linux-x64.tar.gz
cd GPU-Stress-Portable
chmod +x GPU-Stress-Portable
./GPU-Stress-Portable --diagnose
./GPU-Stress-Portable --duration 300 --load 80 --csv gpu-80.csv
```

PyInstaller Linux bundles target broadly similar glibc-based x86-64 distributions. The Docker image is the more reproducible Linux option when a portable binary encounters host-library compatibility issues.

## Docker image

### Host requirements

Linux requires:

- an NVIDIA driver;
- Docker Engine or another supported container engine;
- NVIDIA Container Toolkit configured for Docker.

Windows uses Docker Desktop with WSL2 GPU support and an appropriate NVIDIA Windows driver.

The container does not install or replace the host display driver. NVIDIA Container Toolkit exposes the host GPU and driver libraries to the container.

### Pull from GHCR

```bash
docker pull ghcr.io/pme26elvis/cpu-monitor-stress-tool-gpu:latest

docker run --rm --gpus all \
  -v "$PWD/results:/results" \
  ghcr.io/pme26elvis/cpu-monitor-stress-tool-gpu:latest \
  --duration 300 \
  --load 80 \
  --csv /results/gpu-80.csv
```

On PowerShell:

```powershell
New-Item -ItemType Directory -Force results | Out-Null

docker run --rm --gpus all `
  --volume "${PWD}/results:/results" `
  ghcr.io/pme26elvis/cpu-monitor-stress-tool-gpu:latest `
  --duration 300 `
  --load 80 `
  --csv /results/gpu-80.csv
```

### Select one physical GPU

Container runtimes normally remap a selected physical GPU to CUDA device zero inside the container:

```bash
docker run --rm \
  --gpus 'device=1' \
  ghcr.io/pme26elvis/cpu-monitor-stress-tool-gpu:latest \
  --device 0 \
  --monitor-device 0 \
  --duration 300 \
  --load 100
```

The repository includes convenience launchers:

```powershell
.\scripts\run_gpu_docker.ps1 -Load 80 -Duration 300 -Device 0
```

```bash
./scripts/run_gpu_docker.sh 80 300 0
```

### Docker Compose

Edit the command in `docker-compose.gpu.yml` if necessary, then run:

```bash
docker compose -f docker-compose.gpu.yml up --abort-on-container-exit
```

CSV output is written to the local `results` directory.

### Load the release asset without pulling GHCR

Linux:

```bash
zstd -dc GPU-Stress-Docker-CUDA12-x86_64.tar.zst | docker load
```

Windows can decompress the `.zst` file with 7-Zip or `zstd.exe`, then load the resulting tar archive:

```powershell
docker load --input GPU-Stress-Docker-CUDA12-x86_64.tar
```

## Quadro P2200 compatibility

The user's Quadro P2200 is a CUDA-capable Pascal GPU with 5 GB VRAM, so the FP32 CuPy/cuBLAS workload is an appropriate path. It has no Tensor Cores, so `--dtype float32` is the expected choice; the default `auto` mode already selects FP32.

The default `--memory-mib 256` budget is small relative to 5 GB, and the allocator also reserves free VRAM and retries with smaller matrices after allocation failure. Start with:

```powershell
GPU-Stress-Portable.exe --diagnose
GPU-Stress-Portable.exe --duration 30 --load 25
GPU-Stress-Portable.exe --duration 120 --load 100 --temp-limit 85
```

If "Quadro P220" was intended literally rather than P2200, verify the exact model with `nvidia-smi`. The known machine configuration is Quadro P2200 5 GB.

## Release workflow

`.github/workflows/release-gpu-packages.yml` performs the following:

1. builds Windows x64 and Linux x64 PyInstaller one-folder applications;
2. validates that each frozen CLI starts and renders `--help`;
3. builds and smoke-checks the CUDA 12 container;
4. pushes versioned and `latest` tags to GHCR;
5. exports the image to `GPU-Stress-Docker-CUDA12-x86_64.tar.zst`;
6. creates SHA256 checksums;
7. creates or updates a GitHub Release with all assets.

A relevant push to `main` creates an automatic tag such as `gpu-v0.2.<run-number>`. Maintainers can also run the workflow manually and provide an explicit tag.

## Build locally

Portable app:

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

PyInstaller must build separately on Windows and Linux; its output is specific to the operating system and Python architecture used during the build.

Docker:

```bash
docker build -f Dockerfile.gpu -t gpu-stress:local .
docker run --rm --gpus all gpu-stress:local --diagnose
```
