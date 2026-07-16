# CPU Monitor & Stress Tool

A performance-testing repository with independent CPU and NVIDIA GPU implementations:

- Linux PyQt CPU monitor and stress GUI;
- standalone CPU stress CLI;
- adaptive low-VRAM NVIDIA GPU stress CLI;
- no-pip Windows and Linux portable GPU packages;
- Windows background launchers tailored to a Quadro P2200;
- Linux AppImage and CUDA Docker delivery;
- an independent native C++20/JUCE CUDA **WaveMix** backup with GUI, notification-area controls, CLI, and no-window mode.

The existing repository name is retained even though GPU support is now included.

![screenshot](demo.png)

---

## Personal Quadro P2200 preset

Packaged GPU applications use these values when run arguments are omitted:

```text
--duration 345600 --load 87
```

That is a **96-hour run** targeting approximately **87% load**. Explicit arguments override the preset. Informational commands such as `--help`, `--diagnose`, and `--list-gpus` do not start it.

Guides:

- [Python/CuPy P2200 personal preset](docs/QUADRO_P2200_PERSONAL_PRESET.md)
- [JUCE WaveMix silent tray backup](docs/JUCE_WAVEMIX_BACKUP_GUIDE.md)

---

## Two independent NVIDIA stress strategies

| Area | Python portable implementation | Native JUCE WaveMix backup |
| --- | --- | --- |
| Runtime | Python packaged with PyInstaller | Native C++20/JUCE |
| GPU workload | cuBLAS matrix multiplication | Custom CUDA WaveMix kernel |
| Compute mix | GEMM-heavy FP32/FP16 | FP32 FMA, integer scrambling, shared/global-memory traffic |
| Load control | NVML utilization PI feedback with duty fallback | Measured active-time duty windows |
| Interfaces | CLI and Windows background launcher | JUCE GUI/tray, silent CLI, no-window background |
| Monitoring | Built-in utilization/temperature/power telemetry | Intentionally none; use an external monitor |
| Main purpose | Primary adaptive workload | Independent fallback and cross-validation workload |

The WaveMix backend calibrates short CUDA launches to approximately 8 ms and controls long-term load inside a 200 ms scheduling window. At the personal 87% preset it requests approximately 174 ms of measured active execution per window.

Release builds explicitly include CUDA `sm_61` for the Quadro P2200, plus common newer architectures.

---

## Native JUCE WaveMix silent tray app

Source is under [`native-juce/`](native-juce/).

### Personal defaults

```text
Duration: 345600 seconds (96 hours)
Target duty load: 87%
VRAM budget: 192 MiB
Duty window: 200 ms
Kernel target: approximately 8 ms
```

### Silent compute-only design

Normal JUCE stress runs:

- do not launch `nvidia-smi` or another monitoring subprocess;
- do not print periodic terminal progress;
- do not create logs, CSV telemetry, startup-error logs, or PID files;
- do not implement an application-level temperature guard;
- only maintain in-memory engine state needed by the GUI and scheduler.

`--help` still intentionally displays help, and GUI startup/backend errors still use an error dialog. Those are user-requested or necessary messages rather than recurring background output.

NVIDIA drivers, firmware, clock throttling, and hardware protection normally provide device-level thermal behavior, but they are not a substitute for noticing a broken fan or other cooling fault. Use your preferred external monitoring tool during long runs.

### Windows entry points

```text
GPU-Stress-JUCE.exe                 JUCE GUI and notification-area app
GPU-Stress-JUCE-Background.exe      Completely hidden no-window mode
GPU-Stress-JUCE-CLI.exe             Silent console/automation mode
```

### Notification-area behavior

The Windows notification area is the icon area behind the arrow on the right side of the taskbar, often called the **system tray**.

In the JUCE GUI:

- press **Hide to background** to remove the window from the taskbar while keeping the run active;
- closing or minimizing the window also hides it to the notification area;
- double-click or left-click the tray icon to restore the window;
- right-click the tray icon for **Show window**, **Hide to background**, **Stop stress**, and **Exit**;
- **Stop stress** stops the workload but keeps the app/tray icon available;
- **Exit** stops the workload and terminates the application.

### Manual stop

The extracted Windows ZIP includes:

```text
STOP-JUCE-BACKUP.cmd
CHECK-JUCE-BACKUP.cmd
START-JUCE-BACKUP-GUI.cmd
START-JUCE-BACKUP-BACKGROUND.cmd
```

`STOP-JUCE-BACKUP.cmd` terminates the GUI/tray, no-window background, and CLI entry points.

Equivalent CMD commands:

```cmd
taskkill /F /T /IM GPU-Stress-JUCE.exe
taskkill /F /T /IM GPU-Stress-JUCE-Background.exe
taskkill /F /T /IM GPU-Stress-JUCE-CLI.exe
```

### Fastest JUCE setup

1. Download and extract `GPU-Stress-JUCE-Backup-Windows-x64.zip`.
2. Run the silent package self-test:

```cmd
GPU-Stress-JUCE-CLI.exe --self-test
```

Success is exit code `0`; no text is printed.

3. Run a short real-GPU test:

```cmd
GPU-Stress-JUCE-CLI.exe --duration 30 --load 25
```

4. Open `GPU-Stress-JUCE.exe` for the GUI/tray version, or double-click `GPU-Stress-JUCE-Background.exe` for the completely hidden 96-hour/87% run.

The no-window background application uses an inter-process lock so a second double-click does not create a duplicate run.

---

## Primary Python/CuPy GPU application

[`gpu_stress_cli.py`](gpu_stress_cli.py) provides:

- `--load 0..100` with NVML utilization feedback when available;
- synchronized duty-cycle fallback when telemetry is unavailable;
- backend fallback: PyTorch/cuBLAS → CuPy/cuBLAS → Numba CUDA kernel;
- reusable low-VRAM buffers and automatic downsizing after allocation failure;
- constant, pulsed, and ramp profiles;
- temperature pause/resume guard;
- utilization, temperature, power, clocks, and VRAM status;
- optional CSV telemetry export.

The Python implementation remains unchanged by the JUCE silent-mode work.

### Windows personalized entry points

```text
GPU-Stress-P2200-Background.exe     Detached no-console launcher
GPU-Stress-P2200-Worker.exe         Foreground worker
GPU-Stress-Portable.exe             Compatibility alias
```

Stop the Python worker:

```cmd
taskkill /F /T /IM GPU-Stress-P2200-Worker.exe
```

The Python portable package may be stored and extracted on an HDD. Disk speed affects extraction and startup, but not steady-state GPU loading because working data stays in RAM/VRAM.

---

## Release formats

Primary Python/CuPy releases provide:

- `GPU-Stress-Portable-Windows-x64.zip`
- `GPU-Stress-Portable-Linux-x64.tar.gz`
- `GPU-Stress-Portable-x86_64.AppImage`
- `GPU-Stress-Docker-CUDA12-x86_64.tar.zst`
- versioned and `latest` GHCR images
- `SHA256SUMS.txt`

JUCE WaveMix releases provide:

- `GPU-Stress-JUCE-Backup-Windows-x64.zip`
- `GPU-Stress-JUCE-Backup-Linux-x64.tar.gz`
- `GPU-Stress-JUCE-Backup-x86_64.AppImage`
- `SHA256SUMS.txt`

All GPU packages require a compatible NVIDIA display driver. Portable packages do not require the user to install Python or pip dependencies.

---

## Linux JUCE package

Folder archive:

```bash
tar -xzf GPU-Stress-JUCE-Backup-Linux-x64.tar.gz
cd GPU-Stress-JUCE-Backup-Linux-x64
./GPU-Stress-JUCE-CLI --self-test
./GPU-Stress-JUCE-CLI --duration 30 --load 25
./GPU-Stress-JUCE
```

AppImage:

```bash
chmod +x GPU-Stress-JUCE-Backup-x86_64.AppImage
./GPU-Stress-JUCE-Backup-x86_64.AppImage
./GPU-Stress-JUCE-Backup-x86_64.AppImage --background
```

System-tray behavior on Linux depends on the desktop environment providing a tray host.

---

## Docker / GHCR for the Python implementation

```bash
docker pull ghcr.io/pme26elvis/cpu-monitor-stress-tool-gpu:latest
mkdir -p results

docker run --rm --gpus all \
  -v "$PWD/results:/results" \
  ghcr.io/pme26elvis/cpu-monitor-stress-tool-gpu:latest
```

Custom run:

```bash
docker run --rm --gpus all \
  -v "$PWD/results:/results" \
  ghcr.io/pme26elvis/cpu-monitor-stress-tool-gpu:latest \
  --duration 300 --load 80 --csv /results/gpu-80.csv
```

Linux hosts need NVIDIA Container Toolkit. Windows Docker Desktop uses WSL2 GPU support.

---

## Build from source

### CPU GUI

```bash
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

### Python NVIDIA GPU CLI

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements-gpu.txt
python gpu_stress_cli.py --list-gpus
python gpu_stress_cli.py --diagnose
python gpu_stress_cli.py --duration 600 --load 80
```

### Native JUCE core tests without CUDA or JUCE GUI

```bash
cmake -S native-juce -B build/juce-core \
  -DGPU_STRESS_ENABLE_CUDA=OFF \
  -DGPU_STRESS_BUILD_GUI=OFF \
  -DGPU_STRESS_BUILD_TESTS=ON
cmake --build build/juce-core
ctest --test-dir build/juce-core --output-on-failure
```

### Full CUDA/JUCE build

```bash
cmake -S native-juce -B build/juce-native \
  -DGPU_STRESS_ENABLE_CUDA=ON \
  -DGPU_STRESS_BUILD_GUI=ON \
  -DGPU_STRESS_BUILD_TESTS=ON
cmake --build build/juce-native --config Release
ctest --test-dir build/juce-native -C Release --output-on-failure
```

JUCE is pinned in `native-juce/CMakeLists.txt`. CUDA release builds include `sm_61`, `sm_75`, `sm_86`, and `sm_89`.

---

## Test policy

The JUCE release workflow validates:

- parser defaults and removed-option rejection;
- duty scheduler math and overshoot handling;
- engine completion, early stop, duplicate start, initialization failure, and runtime failure;
- silent self-test and dry-run with empty stdout/stderr;
- zero files created by normal CLI/background runs;
- actual GUI notification-area icon creation and hide → restore lifecycle;
- Windows GUI, hidden background, CLI, CUDA/JUCE build, and ZIP packaging;
- Linux CUDA/JUCE build, GUI/background tests under Xvfb, tar packaging, and AppImage startup;
- AppImage executable integrity.

GitHub-hosted runners do not expose a physical Quadro P2200. Real CUDA execution, temperature, fan, power, and clock behavior must still be verified on the target machine.

---

## Documentation

- [P2200 Python portable preset](docs/QUADRO_P2200_PERSONAL_PRESET.md)
- [JUCE WaveMix silent tray guide](docs/JUCE_WAVEMIX_BACKUP_GUIDE.md)
- [GPU stress usage](docs/GPU_STRESS.md)
- [Portable app, AppImage, and Docker packaging](docs/PACKAGING.md)
- [Development architecture](docs/DEVELOPMENT.md)
- [Native JUCE implementation](native-juce/README.md)

## License

Repository-authored code is licensed under the MIT License unless otherwise stated. JUCE has its own licensing terms; release bundles include JUCE's license and the repository's third-party notice.
