# CPU Monitor & Stress Tool

A small performance-testing repository with independent CPU and NVIDIA GPU paths:

- a Linux PyQt GUI for controllable CPU load and live CPU monitoring;
- a standalone CPU stress CLI;
- an adaptive, low-VRAM NVIDIA GPU stress CLI;
- no-pip Windows/Linux portable GPU packages;
- a CUDA 12 Docker image published to GHCR and GitHub Releases.

The existing repository name is retained even though GPU support is now included.

![screenshot](demo.png)

---

## Features

### CPU GUI

- **Load profiles**
  - **Constant**: maintain a fixed load percentage.
  - **Pulsed**: alternate between high and low load.
  - **Ramp**: linearly increase load to observe dynamic response.
- **Real-time monitoring**
  - CPU load
  - CPU temperature
  - CPU power through Intel RAPL (`/sys/class/powercap/...`)
- CSV export and event markers
- CPU model and core/thread information

### CPU CLI

`cpu_stress_cli.py` provides constant, pulsed, and ramp CPU loading without importing the Qt application.

### NVIDIA GPU CLI

`gpu_stress_cli.py` is an adaptive, low-VRAM NVIDIA stress runner:

- `--load 0..100` with NVML utilization feedback when available;
- synchronized duty-cycle fallback when utilization telemetry is unavailable;
- backend fallback: PyTorch/cuBLAS → CuPy/cuBLAS → Numba CUDA kernel;
- reusable compute-heavy buffers instead of continuously allocating VRAM;
- automatic matrix downsizing after allocation failure;
- constant, pulsed, and ramp profiles;
- temperature pause/resume guard;
- live utilization, temperature, power, clocks, and VRAM status;
- optional CSV telemetry export;
- Linux and Windows support wherever the selected CUDA Python backend works.

### Portable app and Docker delivery

GPU releases provide:

- `GPU-Stress-Portable-Windows-x64.zip`;
- `GPU-Stress-Portable-Linux-x64.tar.gz`;
- `GPU-Stress-Docker-CUDA12-x86_64.tar.zst`;
- a versioned and `latest` GHCR image;
- `SHA256SUMS.txt`.

The portable app bundles Python, CuPy, NVML bindings, and the CUDA 12 user-mode libraries used by its cuBLAS workload. It only requires a compatible NVIDIA display driver—no Python, pip packages, or system-wide CUDA Toolkit.

The portable application uses PyInstaller one-folder mode. The entire extracted folder can live on an HDD: drive speed affects extraction and startup, but not steady-state GPU loading because matrices remain in RAM/VRAM. See [docs/PACKAGING.md](docs/PACKAGING.md).

Full guides:

- [GPU stress usage](docs/GPU_STRESS.md)
- [Portable app and Docker packaging](docs/PACKAGING.md)
- [Development architecture](docs/DEVELOPMENT.md)

---

## Fastest GPU setup: download a release

### Windows portable app

1. Download `GPU-Stress-Portable-Windows-x64.zip` from Releases.
2. Extract the complete folder to any drive, including an HDD.
3. Run:

```powershell
.\GPU-Stress-Portable.exe --list-gpus
.\GPU-Stress-Portable.exe --diagnose
.\GPU-Stress-Portable.exe --duration 300 --load 80
.\GPU-Stress-Portable.exe --duration 900 --load 100 --csv gpu-full.csv
```

Do not move only the executable; the adjacent `_internal` folder is part of the app.

### Linux portable app

```bash
tar -xzf GPU-Stress-Portable-Linux-x64.tar.gz
cd GPU-Stress-Portable
chmod +x GPU-Stress-Portable
./GPU-Stress-Portable --diagnose
./GPU-Stress-Portable --duration 300 --load 80
```

### Docker / GHCR

```bash
docker pull ghcr.io/pme26elvis/cpu-monitor-stress-tool-gpu:latest
mkdir -p results

docker run --rm --gpus all \
  -v "$PWD/results:/results" \
  ghcr.io/pme26elvis/cpu-monitor-stress-tool-gpu:latest \
  --duration 300 \
  --load 80 \
  --csv /results/gpu-80.csv
```

Convenience launchers:

```powershell
.\scripts\run_gpu_docker.ps1 -Load 80 -Duration 300 -Device 0
```

```bash
./scripts/run_gpu_docker.sh 80 300 0
```

Docker still requires host GPU support. Linux hosts need NVIDIA Container Toolkit; Windows uses Docker Desktop with WSL2 GPU support. The downloaded Docker `.tar.zst` may be stored on an HDD, but imported layers use Docker's configured data root.

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

CPU GUI dependencies:

- PyQt5
- psutil >= 5.8.0
- pyqtgraph
- py-cpuinfo
- numpy

### CPU CLI

```bash
python cpu_stress_cli.py --duration 60 --load 75
python cpu_stress_cli.py --duration 120 --profile ramp --start-load 10 --end-load 100
```

### NVIDIA GPU CLI

```bash
python -m venv .venv
source .venv/bin/activate  # Windows PowerShell: .venv\Scripts\Activate.ps1
pip install -r requirements-gpu.txt

python gpu_stress_cli.py --list-gpus
python gpu_stress_cli.py --diagnose
python gpu_stress_cli.py --duration 600 --load 80
python gpu_stress_cli.py --duration 900 --load 100 --csv results/gpu-full.csv
```

The default `--memory-mib 256` is an upper budget. The actual GEMM allocation is smaller and retains driver/cuBLAS workspace headroom.

For a Quadro P2200 5 GB, the default FP32 path and memory budget are appropriate. Run `--diagnose`, then a short 25% test before a longer full-load run.

---

## How the GPU path works

- monitoring: NVML Python binding, then `nvidia-smi` CSV fallback;
- primary workload: cuBLAS GEMM through PyTorch or CuPy;
- final compute fallback: custom Numba CUDA arithmetic kernel;
- load shaping: calibrated synchronous chunks plus a long-term work-credit scheduler;
- adaptive mode: EMA-filtered PI correction from measured GPU utilization;
- memory protection: reserved free VRAM, preallocated output buffers, and OOM downsizing.

A GPU utilization target is not the same as a board-power target. Instruction mix, display activity, power caps, cooling, and thermal throttling can change power draw at the same utilization reading.

---

## Intel RAPL permissions

By default, reading `/sys/class/powercap/intel-rapl:*` may require root. To allow a normal user to read CPU power:

```bash
echo 'SUBSYSTEM=="powercap", KERNEL=="intel-rapl:*", MODE="0644", GROUP="power"' | \
sudo tee /etc/udev/rules.d/90-intel-rapl.rules
sudo groupadd -f power
sudo usermod -aG power $USER
sudo udevadm control --reload
sudo udevadm trigger
```

Re-login or reboot after changing group membership.

---

## Build and release automation

### CPU GUI binary

```bash
pip install pyinstaller
pyi-makespec --onefile --name CPU-Monitor-Stress-Tool --paths . main.py
pyinstaller CPU-Monitor-Stress-Tool.spec --clean
```

### GPU portable packages

`.github/workflows/release-gpu-packages.yml` builds Windows and Linux one-folder apps on their native runners, builds and pushes the CUDA 12 container, exports the Docker image, generates checksums, and creates a GitHub Release.

A relevant push to `main` creates an automatic `gpu-v0.2.<run-number>` release. The workflow may also be run manually with an explicit tag.

PyInstaller outputs are OS-specific, so Windows and Linux packages are built separately rather than cross-compiled.

---

## Validation

CPU-only checks:

```bash
python -m py_compile cpu_stress_cli.py gpu_stress_cli.py gpu_stress_portable.py
python -m unittest discover -s tests -v
python gpu_stress_cli.py --help
python gpu_stress_portable.py --help
```

GPU smoke test:

```bash
python gpu_stress_cli.py --diagnose
python gpu_stress_cli.py --duration 15 --load 25
python gpu_stress_cli.py --duration 30 --load 100 --csv gpu-smoke.csv
```

---

## Troubleshooting

### GPU CLI says no backend could start

Run `--diagnose`. The source version lists every attempted backend and failure. The portable app contains only the CuPy backend and still requires a working NVIDIA driver.

### GPU utilization does not match `--load` exactly

Use a run longer than several driver sampling windows. Keep `--control auto` or use `--control feedback`. Other display/compute processes affect device-wide utilization.

### Temperature repeatedly enters THERMAL-PAUSE

Improve cooling, lower `--load`, or reduce the run duration. Do not disable the guard for unattended testing.

### Docker cannot see the GPU

Verify `nvidia-smi` on the host, then verify Docker GPU support with an NVIDIA CUDA container. On Linux, configure NVIDIA Container Toolkit for Docker. Docker does not bundle the host driver.

### CPU power shows N/A

RAPL counters are unavailable or unreadable. Apply the udev rule above and re-login.

---

## Contributing

- Keep optional CUDA imports lazy so CPU-only tests remain usable.
- Add unit coverage for scheduling, parsing, profile, controller, and portable-entry changes.
- Test GPU changes with `--diagnose`, a low-load run, and a full-load run.
- Packaging changes should update `docs/PACKAGING.md` and the release workflow.
- Large behavioral changes should update `docs/GPU_STRESS.md` and `docs/DEVELOPMENT.md`.

---

## License

MIT
