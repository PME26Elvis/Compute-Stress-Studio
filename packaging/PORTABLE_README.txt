GPU Stress Portable (CUDA 12 / CuPy backend)
================================================

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

Windows examples
----------------
GPU-Stress-Portable.exe --list-gpus
GPU-Stress-Portable.exe --diagnose
GPU-Stress-Portable.exe --duration 300 --load 80
GPU-Stress-Portable.exe --duration 900 --load 100 --csv gpu-full.csv

Linux examples
--------------
chmod +x GPU-Stress-Portable
./GPU-Stress-Portable --list-gpus
./GPU-Stress-Portable --diagnose
./GPU-Stress-Portable --duration 300 --load 80

Notes
-----
- The portable build always uses the CuPy/cuBLAS backend even if another
  --backend value is supplied.
- The regular source version still supports PyTorch, CuPy, and Numba fallback.
- The default workload uses a bounded VRAM budget and retries smaller matrices
  after allocation failure.
- Quadro P2200-class Pascal cards are expected to work with a compatible driver.
  Use --diagnose first, then a short 25% run before a full-load test.
- GPU utilization and board-power percentage are different metrics. A 100%
  utilization target does not promise exactly 100% of the card's power limit.
