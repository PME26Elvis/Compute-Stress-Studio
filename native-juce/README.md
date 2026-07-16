# GPU Stress JUCE Backup

This directory contains an independent native backup implementation of the NVIDIA GPU stress tool.

It deliberately does **not** reuse the Python/CuPy/cuBLAS GEMM workload. Instead it uses a custom CUDA **WaveMix** kernel that combines:

- FP32 fused multiply-add operations;
- integer xorshift/scrambling operations;
- shared-memory permutations and synchronization;
- periodic pseudo-random global-memory reads and writes;
- short calibrated launches, normally around 8 ms;
- measured active-time duty windows rather than an NVML PI utilization controller.

The defaults remain personalized for the Quadro P2200 machine:

```text
Duration: 345600 seconds (96 hours)
Target duty load: 87%
VRAM budget: 192 MiB
Duty window: 200 ms
Kernel target: 8 ms
```

## Silent design

The native JUCE version now focuses only on generating the workload. Normal runs:

- do not launch `nvidia-smi` or any other monitoring subprocess;
- do not print periodic terminal progress;
- do not create logs, CSV telemetry, startup-error logs, or PID files;
- do not implement an application-level temperature guard.

The GPU driver, firmware, clock throttling, and hardware protection remain responsible for the device's own thermal behavior. Use a separate monitoring tool if you want temperature, power, clock, or utilization visibility.

## Delivered applications

Windows releases contain:

- `GPU-Stress-JUCE.exe` — JUCE GUI and notification-area application;
- `GPU-Stress-JUCE-Background.exe` — no-window background alias;
- `GPU-Stress-JUCE-CLI.exe` — silent console/automation interface;
- start, stop, and status CMD files.

The GUI creates a notification-area icon, commonly called the system tray icon on Windows. Closing or minimising the GUI hides it to the tray instead of terminating the workload. Double-click the icon to restore the window. Right-click it to show the window, hide it, stop the stress run, or exit the application.

Linux releases contain the corresponding GUI/CLI folder and an AppImage. Tray behavior depends on the desktop environment's system-tray implementation.

## Build

JUCE is fetched and pinned by CMake. CUDA release builds include `sm_61`, which is the architecture required by the Quadro P2200.

```bash
cmake -S native-juce -B build/native-juce -DGPU_STRESS_ENABLE_CUDA=ON
cmake --build build/native-juce --config Release
ctest --test-dir build/native-juce -C Release --output-on-failure
```

Host-only tests do not require CUDA or JUCE:

```bash
cmake -S native-juce -B build/native-core \
  -DGPU_STRESS_ENABLE_CUDA=OFF \
  -DGPU_STRESS_BUILD_GUI=OFF \
  -DGPU_STRESS_BUILD_TESTS=ON
cmake --build build/native-core
ctest --test-dir build/native-core --output-on-failure
```

The release workflow additionally verifies that a normal CLI or background dry-run produces no stdout/stderr output and creates no run files, and that the GUI can hide to and restore from the tray lifecycle.

## Licensing

The repository's original code is MIT-licensed. JUCE has its own dual-license terms. The public release workflow builds this open-source application using JUCE under the AGPLv3 option and includes JUCE's license text and a third-party notice in release bundles. A commercial JUCE license would be required for incompatible closed-source distribution.
