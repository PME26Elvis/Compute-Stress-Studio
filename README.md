# CPU Monitor & Stress Tool

A small performance-testing repository with independent CPU and NVIDIA GPU paths:

- a Linux PyQt GUI for controllable CPU load and live CPU monitoring;
- a standalone CPU stress CLI;
- an adaptive, low-VRAM NVIDIA GPU stress CLI;
- no-pip Windows/Linux portable GPU packages;
- a hidden Windows background launcher tailored to the user's Quadro P2200;
- a Linux x86-64 AppImage;
- a CUDA 12 Docker image published to GHCR and GitHub Releases.

The existing repository name is retained even though GPU support is now included.

![screenshot](demo.png)

---

## Personal Quadro P2200 preset

The portable packages now use these values when run arguments are omitted:

```text
--duration 345600 --load 87
```

That is a **96-hour run** targeting approximately **87% GPU utilization**.

Explicit `--duration`, `--load`, or `--profile` arguments still override the personal defaults. Informational commands such as `--help`, `--diagnose`, and `--list-gpus` never start the long-running preset.

The dedicated Traditional Chinese guide is available at [docs/QUADRO_P2200_PERSONAL_PRESET.md](docs/QUADRO_P2200_PERSONAL_PRESET.md).

### Windows hidden background mode

After extracting the Windows ZIP, double-click:

```text
GPU-Stress-P2200-Background.exe
```

It starts `GPU-Stress-P2200-Worker.exe` as a detached process with no console window, writes logs under `P2200-Runs`, and returns immediately. It refuses to start a duplicate worker while the previous PID is still active.

Stop command for Windows CMD:

```cmd
taskkill /F /T /IM GPU-Stress-P2200-Worker.exe
```

The ZIP also includes:

```text
START-P2200-96H-87.cmd
STOP-P2200-GPU-STRESS.cmd
QUADRO_P2200_PERSONAL_PRESET.md
```

---

## Features

### CPU GUI

- constant, pulsed, and ramp load profiles;
- CPU load, temperature, and Intel RAPL power monitoring;
- CSV export and event markers;
- CPU model and core/thread information.

### CPU CLI

`cpu_stress_cli.py` provides constant, pulsed, and ramp CPU loading without importing the Qt application.

### NVIDIA GPU CLI

`gpu_stress_cli.py` provides:

- `--load 0..100` with NVML utilization feedback when available;
- synchronized duty-cycle fallback when utilization telemetry is unavailable;
- backend fallback: PyTorch/cuBLAS → CuPy/cuBLAS → Numba CUDA kernel;
- reusable compute-heavy buffers instead of continuously allocating VRAM;
- automatic matrix downsizing after allocation failure;
- constant, pulsed, and ramp profiles;
- temperature pause/resume guard;
- live utilization, temperature, power, clocks, and VRAM status;
- optional CSV telemetry export.

### Release formats

GPU releases provide:

- `GPU-Stress-Portable-Windows-x64.zip`;
- `GPU-Stress-Portable-Linux-x64.tar.gz`;
- `GPU-Stress-Portable-x86_64.AppImage`;
- `GPU-Stress-Docker-CUDA12-x86_64.tar.zst`;
- a versioned and `latest` GHCR image;
- `SHA256SUMS.txt`.

The portable packages bundle Python, CuPy, NVML bindings, and the CUDA 12 user-mode libraries used by the cuBLAS workload. They require a compatible NVIDIA display driver, but not Python, pip packages, or a system-wide CUDA Toolkit.

The Windows and Linux folder packages use PyInstaller one-folder mode. The complete extracted folder can live on an HDD: drive speed affects extraction and startup, but not steady-state GPU loading because the matrices remain in RAM/VRAM.

Full guides:

- [Quadro P2200 personal preset](docs/QUADRO_P2200_PERSONAL_PRESET.md)
- [GPU stress usage](docs/GPU_STRESS.md)
- [Portable app, AppImage, and Docker packaging](docs/PACKAGING.md)
- [Development architecture](docs/DEVELOPMENT.md)

---

## Fastest Windows setup

1. Download `GPU-Stress-Portable-Windows-x64.zip` from Releases.
2. Extract the entire folder to an SSD or HDD.
3. Run a diagnostic once:

```cmd
GPU-Stress-P2200-Worker.exe --diagnose
```

4. Run a short low-load test:

```cmd
GPU-Stress-P2200-Worker.exe --duration 30 --load 25
```

5. Double-click `GPU-Stress-P2200-Background.exe` for the hidden 96-hour/87% run.

Confirm the process:

```cmd
tasklist /FI "IMAGENAME eq GPU-Stress-P2200-Worker.exe"
```

Stop it:

```cmd
taskkill /F /T /IM GPU-Stress-P2200-Worker.exe
```

Foreground and custom examples:

```cmd
GPU-Stress-P2200-Worker.exe
GPU-Stress-P2200-Worker.exe --duration 7200 --load 75
GPU-Stress-Portable.exe --duration 300 --load 80
```

`GPU-Stress-Portable.exe` is an alias of the same foreground worker for compatibility with previous release instructions.

Do not move only an EXE out of the extracted folder; the adjacent `_internal` directory contains the bundled runtime.

---

## Linux folder package

```bash
tar -xzf GPU-Stress-Portable-Linux-x64.tar.gz
cd GPU-Stress-Portable
chmod +x GPU-Stress-Portable
./GPU-Stress-Portable --diagnose
./GPU-Stress-Portable --duration 30 --load 25
./GPU-Stress-Portable
```

The final command uses the 96-hour/87% personal defaults.

## Linux AppImage

```bash
chmod +x GPU-Stress-Portable-x86_64.AppImage
./GPU-Stress-Portable-x86_64.AppImage --diagnose
./GPU-Stress-Portable-x86_64.AppImage
```

The AppImage contains the same PyInstaller/CuPy application and uses the same personal defaults when no run arguments are supplied.

## Docker / GHCR

```bash
docker pull ghcr.io/pme26elvis/cpu-monitor-stress-tool-gpu:latest
mkdir -p results

docker run --rm --gpus all \
  -v "$PWD/results:/results" \
  ghcr.io/pme26elvis/cpu-monitor-stress-tool-gpu:latest
```

The image default command is also 345600 seconds at 87%, with CSV output under `/results`.

Custom run:

```bash
docker run --rm --gpus all \
  -v "$PWD/results:/results" \
  ghcr.io/pme26elvis/cpu-monitor-stress-tool-gpu:latest \
  --duration 300 \
  --load 80 \
  --csv /results/gpu-80.csv
```

Convenience launchers now use the personal defaults when values are omitted:

```powershell
.\scripts\run_gpu_docker.ps1
```

```bash
./scripts/run_gpu_docker.sh
```

Docker still requires host GPU support. Linux hosts need NVIDIA Container Toolkit; Windows uses Docker Desktop with WSL2 GPU support. A downloaded Docker `.tar.zst` may be stored on an HDD, but imported image layers use Docker's configured data root.

---

## Run from source

### CPU GUI

```bash
git clone https://github.com/PME26Elvis/CPU-Monitor-Stress-Tool.git
cd CPU-Monitor-Stress-Tool
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python main.py
```

### CPU CLI

```bash
python cpu_stress_cli.py --duration 60 --load 75
python cpu_stress_cli.py --duration 120 --profile ramp --start-load 10 --end-load 100
```

### Full NVIDIA GPU source CLI

```bash
python -m venv .venv
source .venv/bin/activate  # Windows PowerShell: .venv\Scripts\Activate.ps1
pip install -r requirements-gpu.txt

python gpu_stress_cli.py --list-gpus
python gpu_stress_cli.py --diagnose
python gpu_stress_cli.py --duration 600 --load 80
```

The full source CLI retains the PyTorch → CuPy → Numba fallback chain and still requires an explicit duration. The 96-hour/87% behavior belongs to the portable wrapper and packaged launchers.

The default `--memory-mib 256` remains a conservative upper workload budget. For the Quadro P2200 5 GB, the FP32 CuPy/cuBLAS path and this bounded budget are appropriate for compute loading without intentionally filling VRAM.

A target utilization percentage is not the same as a fixed board-power percentage. Display work, instruction mix, clocks, cooling, power caps, and thermal throttling can change power draw at the same utilization reading.

---

## Build and release automation

`.github/workflows/release-gpu-packages.yml` builds:

1. a Windows one-folder worker plus a one-file no-console background launcher;
2. a Linux one-folder package;
3. a Linux x86-64 AppImage;
4. a CUDA 12 Docker image and compressed image archive;
5. SHA256 checksums and a GitHub Release.

A relevant push to `main` creates an automatic `gpu-v0.3.<run-number>` release. The workflow can also be run manually with an explicit tag.

PyInstaller outputs are OS-specific, so Windows and Linux packages are built separately rather than cross-compiled.

---

## Validation

CPU-only checks:

```bash
python -m py_compile cpu_stress_cli.py gpu_stress_cli.py gpu_stress_portable.py gpu_stress_background.py
python -m unittest discover -s tests -v
python gpu_stress_cli.py --help
python gpu_stress_portable.py --help
```

GPU smoke test on the Quadro P2200 machine:

```cmd
GPU-Stress-P2200-Worker.exe --diagnose
GPU-Stress-P2200-Worker.exe --duration 30 --load 25
GPU-Stress-P2200-Worker.exe --duration 1800 --load 87
```

---

## Troubleshooting

### Stop the hidden Windows run

```cmd
taskkill /F /T /IM GPU-Stress-P2200-Worker.exe
```

### A second double-click does not start another worker

This is intentional. Check `P2200-Runs\gpu-stress-p2200.pid` and the console log. Stop the existing worker before starting a new run.

### GPU CLI says no backend could start

Run `--diagnose`. The source version lists every attempted backend and failure. The portable packages contain only the CuPy backend and still require a working NVIDIA driver.

### GPU utilization does not match `--load` exactly

Use a run longer than several driver sampling windows. Keep `--control auto` or use `--control feedback`. Other display and compute processes affect device-wide utilization.

### Temperature repeatedly enters THERMAL-PAUSE

Improve cooling, lower `--load`, or reduce the run duration. Do not disable the guard for unattended testing.

### AppImage cannot start normally

Try:

```bash
APPIMAGE_EXTRACT_AND_RUN=1 ./GPU-Stress-Portable-x86_64.AppImage --diagnose
```

### Docker cannot see the GPU

Verify `nvidia-smi` on the host, then verify Docker GPU support with an NVIDIA CUDA container. Docker does not bundle the host display driver.

---

## Contributing

- Keep optional CUDA imports lazy so CPU-only tests remain usable.
- Add unit coverage for scheduling, parsing, controller, portable defaults, and background-launcher changes.
- Test packaging changes on both native operating systems.
- Test the AppImage with `APPIMAGE_EXTRACT_AND_RUN=1` in CI.
- Large behavioral changes should update the relevant guides and release notes.

---

## License

MIT
