# CPU Monitor & Stress Tool

A small performance-testing repository with independent CPU and NVIDIA GPU paths:

- a Linux PyQt GUI for controllable CPU load and live CPU monitoring;
- a standalone CPU stress CLI;
- an adaptive, low-VRAM NVIDIA GPU stress CLI;
- no-pip Windows/Linux portable GPU packages;
- a hidden Windows background launcher tailored to the user's Quadro P2200;
- a Linux x86-64 AppImage;
- a CUDA 12 Docker image published to GHCR and GitHub Releases;
- an independent native C++/JUCE CUDA WaveMix backup application with GUI, CLI, and no-window mode.

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

## Independent JUCE WaveMix backup

`native-juce/` contains a second NVIDIA stress implementation written in C++20 with a JUCE 8 GUI. It is intentionally independent from the Python/CuPy portable application.

| Area | Python portable implementation | JUCE WaveMix backup |
| --- | --- | --- |
| GPU workload | cuBLAS matrix multiplication | Custom CUDA WaveMix kernel |
| Compute mix | GEMM-heavy FP32/FP16 | FP32 FMA, integer scrambling, shared/global-memory traffic |
| Load control | NVML utilization PI feedback with duty fallback | Measured active-time duty windows |
| Interface | CLI plus Windows background launcher | JUCE GUI, CLI, and no-window background mode |
| Main purpose | Primary adaptive workload | Independent fallback and cross-validation workload |

The WaveMix backend calibrates short CUDA launches to approximately 8 ms, then controls long-term load inside a 200 ms scheduling window. For the personal 87% preset, it requests approximately 174 ms of measured active execution per window. Telemetry is used for status and thermal protection rather than PI load control.

Release builds explicitly include CUDA `sm_61` support for the Quadro P2200 and retain the same personal defaults:

```text
Duration: 345600 seconds (96 hours)
Target duty load: 87%
VRAM budget: 192 MiB
Thermal pause: 85 C; resume at 80 C or below
```

### JUCE Windows entry points

```text
GPU-Stress-JUCE.exe                 JUCE GUI
GPU-Stress-JUCE-Background.exe      No-window background mode
GPU-Stress-JUCE-CLI.exe             Console and automation mode
```

Start the hidden backup by double-clicking `GPU-Stress-JUCE-Background.exe` or `START-JUCE-BACKUP-BACKGROUND.cmd`.

Stop it from Windows CMD:

```cmd
taskkill /F /T /IM GPU-Stress-JUCE-Background.exe
```

The background application uses an inter-process lock so a second double-click does not create a duplicate 96-hour run. Logs, telemetry CSV, and the active PID are stored under `JUCE-Backup-Runs`.

The complete guide is available at [docs/JUCE_WAVEMIX_BACKUP_GUIDE.md](docs/JUCE_WAVEMIX_BACKUP_GUIDE.md). Build architecture and source notes are under [native-juce/README.md](native-juce/README.md).

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

Primary Python/CuPy GPU releases provide:

- `GPU-Stress-Portable-Windows-x64.zip`;
- `GPU-Stress-Portable-Linux-x64.tar.gz`;
- `GPU-Stress-Portable-x86_64.AppImage`;
- `GPU-Stress-Docker-CUDA12-x86_64.tar.zst`;
- a versioned and `latest` GHCR image;
- `SHA256SUMS.txt`.

JUCE WaveMix backup releases provide:

- `GPU-Stress-JUCE-Backup-Windows-x64.zip`;
- `GPU-Stress-JUCE-Backup-Linux-x64.tar.gz`;
- `GPU-Stress-JUCE-Backup-x86_64.AppImage`;
- `SHA256SUMS.txt`.

The Python portable packages bundle Python, CuPy, NVML bindings, and the CUDA 12 user-mode libraries used by the cuBLAS workload. They require a compatible NVIDIA display driver, but not Python, pip packages, or a system-wide CUDA Toolkit.

The Windows and Linux Python folder packages use PyInstaller one-folder mode. The complete extracted folder can live on an HDD: drive speed affects extraction and startup, but not steady-state GPU loading because the matrices remain in RAM/VRAM.

Full guides:

- [Quadro P2200 personal preset](docs/QUADRO_P2200_PERSONAL_PRESET.md)
- [JUCE WaveMix P2200 backup](docs/JUCE_WAVEMIX_BACKUP_GUIDE.md)
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

### Fastest JUCE backup setup

1. Download and extract `GPU-Stress-JUCE-Backup-Windows-x64.zip`.
2. Run the package-level synthetic self-test:

```cmd
GPU-Stress-JUCE-CLI.exe --self-test
```

3. Run a short real-GPU test:

```cmd
GPU-Stress-JUCE-CLI.exe --duration 30 --load 25
```

4. Open `GPU-Stress-JUCE.exe` for the dashboard, or double-click `GPU-Stress-JUCE-Background.exe` for the hidden 96-hour/87% backup run.

Stop the hidden backup:

```cmd
taskkill /F /T /IM GPU-Stress-JUCE-Background.exe
```

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

JUCE backup AppImage:

```bash
chmod +x GPU-Stress-JUCE-Backup-x86_64.AppImage
./GPU-Stress-JUCE-Backup-x86_64.AppImage
./GPU-Stress-JUCE-Backup-x86_64.AppImage --background
```

---

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

### Native JUCE WaveMix source

Host-only tests without CUDA or JUCE GUI compilation:

```bash
cmake -S native-juce -B build/juce-core \
  -DGPU_STRESS_ENABLE_CUDA=OFF \
  -DGPU_STRESS_BUILD_GUI=OFF \
  -DGPU_STRESS_BUILD_TESTS=ON
cmake --build build/juce-core
ctest --test-dir build/juce-core --output-on-failure
```

Full CUDA/JUCE build:

```bash
cmake -S native-juce -B build/juce-native \
  -DGPU_STRESS_ENABLE_CUDA=ON \
  -DGPU_STRESS_BUILD_GUI=ON \
  -DGPU_STRESS_BUILD_TESTS=ON
cmake --build build/juce-native --config Release
ctest --test-dir build/juce-native -C Release --output-on-failure
```

JUCE is fetched at the pinned version declared in `native-juce/CMakeLists.txt`. CUDA release builds include `sm_61` for the Quadro P2200.

A target utilization or duty percentage is not the same as a fixed board-power percentage. Display work, instruction mix, clocks, cooling, power caps, and thermal throttling can change power draw at the same utilization reading.

---

## Build and release automation

`.github/workflows/release-gpu-packages.yml` builds the primary Python implementation:

1. a Windows one-folder worker plus a one-file no-console background launcher;
2. a Linux one-folder package;
3. a Linux x86-64 AppImage;
4. a CUDA 12 Docker image and compressed image archive;
5. SHA256 checksums and a GitHub Release.

A relevant push to `main` creates an automatic `gpu-v0.3.<run-number>` release. The workflow can also be run manually with an explicit tag.

`.github/workflows/release-juce-backup.yml` independently builds the C++/JUCE WaveMix backup:

1. host-only C++ unit and integration tests;
2. Windows Visual Studio + CUDA + JUCE GUI/CLI/background binaries;
3. Linux CUDA + JUCE binaries, Xvfb GUI/background smoke tests, tar archive, and AppImage;
4. JUCE license and third-party notices in every bundle;
5. SHA256 checksums and a `juce-backup-v1.0.<run-number>` GitHub Release.

Neither release workflow overwrites or substitutes the other implementation.

---

## Validation

Python CPU-only checks:

```bash
python -m py_compile cpu_stress_cli.py gpu_stress_cli.py gpu_stress_portable.py gpu_stress_background.py
python -m unittest discover -s tests -v
python gpu_stress_cli.py --help
python gpu_stress_portable.py --help
```

Primary GPU smoke test on the Quadro P2200 machine:

```cmd
GPU-Stress-P2200-Worker.exe --diagnose
GPU-Stress-P2200-Worker.exe --duration 30 --load 25
GPU-Stress-P2200-Worker.exe --duration 1800 --load 87
```

JUCE package checks:

```cmd
GPU-Stress-JUCE-CLI.exe --self-test
GPU-Stress-JUCE-CLI.exe --dry-run --duration 5 --load 87
GPU-Stress-JUCE-CLI.exe --duration 30 --load 25
GPU-Stress-JUCE-CLI.exe --duration 1800 --load 87
```

The JUCE CI suite covers configuration parsing, duty-window math, engine completion and early stop, backend errors, thermal pause/hysteresis, log/CSV/PID lifecycle, CUDA compilation, GUI startup, no-window background dry-runs, and AppImage startup. Physical Quadro P2200 kernel execution remains a target-machine hardware smoke test because GitHub-hosted runners do not expose that GPU.

---

## Troubleshooting

### Stop the hidden Windows run

Primary Python implementation:

```cmd
taskkill /F /T /IM GPU-Stress-P2200-Worker.exe
```

JUCE WaveMix backup:

```cmd
taskkill /F /T /IM GPU-Stress-JUCE-Background.exe
```

### A second double-click does not start another worker

This is intentional. The Python launcher checks `P2200-Runs\gpu-stress-p2200.pid`; the JUCE backup uses an inter-process lock. Stop the existing worker before starting a new run.

### GPU CLI says no backend could start

Run `--diagnose` on the Python build. The source version lists every attempted backend and failure. The Python portable packages contain only the CuPy backend and still require a working NVIDIA driver.

For the JUCE backup, run the synthetic package test first:

```cmd
GPU-Stress-JUCE-CLI.exe --self-test
```

Then try a short real-GPU run. CUDA initialization failures are written to the console and `JUCE-Backup-Runs` log.

### GPU utilization does not match the target exactly

The Python implementation uses utilization feedback when available. The JUCE backup uses measured active-time duty windows instead, so an 87% duty target does not guarantee that every `nvidia-smi` sample reads exactly 87%. Other display and compute processes also affect device-wide utilization.

### Temperature repeatedly enters thermal pause

Improve cooling, lower `--load`, or reduce the run duration. Do not disable the guard for unattended testing.

### AppImage cannot start normally

Try extract-and-run mode:

```bash
APPIMAGE_EXTRACT_AND_RUN=1 ./GPU-Stress-Portable-x86_64.AppImage --diagnose
APPIMAGE_EXTRACT_AND_RUN=1 ./GPU-Stress-JUCE-Backup-x86_64.AppImage
```

### Docker cannot see the GPU

Verify `nvidia-smi` on the host, then verify Docker GPU support with an NVIDIA CUDA container. Docker does not bundle the host display driver.

---

## Contributing

- Keep optional Python CUDA imports lazy so CPU-only tests remain usable.
- Keep `native-juce` core logic independent from JUCE widgets so host-only C++ tests remain fast.
- Add unit coverage for scheduling, parsing, controller, portable defaults, background-launcher, and engine-state changes.
- Test packaging changes on both native operating systems.
- Test both AppImages with extract-and-run mode in CI.
- Keep JUCE licensing notices and the pinned JUCE version synchronized with release bundles.
- Large behavioral changes should update the relevant guides and release notes.

---

## License

The repository's original source is MIT-licensed. The JUCE-based application includes JUCE under JUCE's separate dual-license terms; see `native-juce/THIRD_PARTY_NOTICES.md` and the bundled `JUCE-LICENSE.md` in JUCE releases.
