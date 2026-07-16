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
Thermal pause limit: 85 C
Duty window: 200 ms
Kernel target: 8 ms
```

## Delivered applications

Windows releases contain:

- `GPU-Stress-JUCE.exe` — JUCE GUI;
- `GPU-Stress-JUCE-Background.exe` — no-window background alias;
- `GPU-Stress-JUCE-CLI.exe` — console/automation interface;
- start, stop, and status CMD files.

Linux releases contain the corresponding GUI/CLI folder and an AppImage.

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

## Licensing

The repository's original code is MIT-licensed. JUCE has its own dual-license terms. The public release workflow builds this open-source application using JUCE under the AGPLv3 option and includes JUCE's license text and a third-party notice in release bundles. A commercial JUCE license would be required for incompatible closed-source distribution.
