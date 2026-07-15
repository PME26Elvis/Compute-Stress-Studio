GPU Stress Portable (CUDA 12 / CuPy backend)
================================================

Personal preset in this release
-------------------------------
When no run arguments are supplied, the portable worker and Linux packages use:

- duration: 345600 seconds (96 hours)
- target GPU utilization: 87 percent

Explicit --duration, --load, or --profile arguments override these defaults.
Informational commands such as --help, --diagnose, and --list-gpus do not start
the long-running preset.

What this package contains
--------------------------
This is a PyInstaller one-folder build of gpu_stress_cli.py. It bundles Python,
CuPy, NVML bindings, and the minimal CUDA 12 user-mode component libraries used
by the GEMM workload. You do not need to install Python or pip packages.

What is still required
----------------------
- A 64-bit Windows or Linux system matching the downloaded package.
- A compatible NVIDIA display driver.
- An NVIDIA CUDA-capable GPU.

A full system-wide CUDA Toolkit is not required by this portable build.

Running from an HDD
-------------------
The extracted folder may live on an HDD. Startup and the first CuPy cache build
can be slower than on an SSD, but the steady-state stress loop reuses data in
RAM and VRAM and does not depend on disk throughput. CSV logging is tiny.
Do not run directly from inside the ZIP; extract the whole folder first.

Windows personal preset
-----------------------
Double-click GPU-Stress-P2200-Background.exe for a hidden background run.
It starts GPU-Stress-P2200-Worker.exe with the 96-hour/87-percent preset and
writes logs under P2200-Runs.

Stop command to paste into Windows CMD:

taskkill /F /T /IM GPU-Stress-P2200-Worker.exe

The ZIP also contains START-P2200-96H-87.cmd and STOP-P2200-GPU-STRESS.cmd.
See QUADRO_P2200_PERSONAL_PRESET.md for the complete guide.

Windows foreground examples
---------------------------
GPU-Stress-P2200-Worker.exe --list-gpus
GPU-Stress-P2200-Worker.exe --diagnose
GPU-Stress-P2200-Worker.exe --duration 300 --load 80
GPU-Stress-P2200-Worker.exe --duration 900 --load 100 --csv gpu-full.csv
GPU-Stress-P2200-Worker.exe

Linux examples
--------------
chmod +x GPU-Stress-Portable
./GPU-Stress-Portable --list-gpus
./GPU-Stress-Portable --diagnose
./GPU-Stress-Portable --duration 300 --load 80
./GPU-Stress-Portable

AppImage example
----------------
chmod +x GPU-Stress-Portable-x86_64.AppImage
./GPU-Stress-Portable-x86_64.AppImage

Notes
-----
- The portable build always uses the CuPy/cuBLAS backend even if another
  --backend value is supplied.
- The regular source version still supports PyTorch, CuPy, and Numba fallback.
- The default workload uses a bounded VRAM budget and retries smaller matrices
  after allocation failure.
- The personal machine target is the Quadro P2200 5 GB. Use --diagnose first,
  then a short 25-percent run before the 96-hour background preset.
- GPU utilization and board-power percentage are different metrics. An 87-
  percent utilization target does not promise exactly 87 percent of the card's
  power limit.
