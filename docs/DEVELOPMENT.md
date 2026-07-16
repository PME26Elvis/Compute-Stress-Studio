# Architecture and development

This document describes the repository-wide boundaries, contracts, and validation policy.

## Repository architecture

```text
Compute Stress Studio
|
+-- apps/stress_studio/       Flutter Material 3 control plane
|   +-- ProcessCpuStressService
|   +-- JuceGpuWorkerService
|
+-- native-cpu/               silent low-priority C++20 CPU worker
|
+-- native-juce/              C++20/JUCE CUDA WaveMix engine
|   +-- standalone GUI/tray, CLI, and hidden modes
|   +-- embedded Flutter GPU worker
|
+-- gpu_stress_cli.py         adaptive Python NVIDIA CLI
+-- packaging/                Python portable/AppImage delivery
+-- main.py + PyQt modules    original Linux CPU monitor
+-- cpu_stress_cli.py         standalone Python CPU CLI
+-- docs/                     product, operation, architecture, release notes
+-- release/                  audited product release requests
```

The engines are deliberately independent:

- Flutter is the flagship orchestration and UX layer.
- `native-cpu` protects Flutter responsiveness by owning CPU hot loops in a child process.
- JUCE WaveMix is the native GPU worker and standalone fallback.
- The Python GPU CLI is telemetry-aware and adaptive.
- Original CPU tools remain standalone utilities.

## Flutter control plane

### Ownership and lifecycle

`OwnedStressStudioApp` owns `StudioController`. Removing the root disposes the controller and immediately begins stopping both child processes. `StressStudioApp` remains independently testable with fake services.

### State and transactions

`StudioController` owns immutable configuration, idle/starting/running/stopping/completed/error states, elapsed time, bounded history, rollback, theme, and navigation state.

Start validates configuration and launches enabled services together. Any startup failure stops both. Stop is idempotent. Configuration is locked while active.

### CPU service

`ProcessCpuStressService` expects `Compute-Stress-CPU-Worker[.exe]` beside the Flutter executable and passes:

```text
--duration <seconds>
--load <percent>
--threads <1..64>
```

The child process boundary fixes the first preview's Windows responsiveness issue. The first implementation used one busy Dart isolate per selected processor. Work stayed off the UI isolate but still shared the Flutter process and could starve Windows message handling when every logical processor was active.

The v0.2 CPU worker:

- uses a Windows GUI-subsystem executable, so no console appears;
- lowers itself to Below Normal priority on Windows;
- uses a positive nice value on Linux;
- creates native worker threads only inside the child process;
- applies 50 ms duty windows;
- exits silently and writes no files;
- can be killed immediately by the controller;
- has parser, scheduling, self-test, and early-stop native tests.

Presets use `recommendedCpuThreadCount()`, which reserves one logical processor when possible. Users may still select the full processor count intentionally.

### GPU service

`JuceGpuWorkerService` expects `GPU-Stress-JUCE-Background[.exe]` beside Flutter and passes duration, load, VRAM budget, and device index. It drains output, detects early exit, terminates on Stop, and escalates after timeout.

### Diagnostics

`CapabilitySnapshot` exposes operating system, logical processor count, CPU worker path/readiness, and GPU worker path/readiness. Capability inspection never starts load.

## Native CPU worker

`native-cpu/` contains:

```text
CMakeLists.txt
include/ComputeStressCpu/Config.h
include/ComputeStressCpu/Engine.h
src/Config.cpp
src/Engine.cpp
src/MainWindows.cpp
src/MainPosix.cpp
tests/CpuStressTests.cpp
```

The worker uses C++20 `std::jthread`. Each thread performs floating-point work during the active portion of a 50 ms window and sleeps until the next window boundary. A process-wide stop flag bounds shutdown latency.

Windows builds use `WIN32` subsystem and link the static MSVC runtime in release bundles. POSIX builds handle SIGINT/SIGTERM.

## Native JUCE WaveMix engine

WaveMix uses calibrated CUDA launches combining FP32 arithmetic, integer scrambling, shared memory, and global memory traffic. Duty is based on active execution time rather than NVML PI feedback.

Release builds include `sm_61` for the Quadro P2200 and selected newer architectures. Normal JUCE runs avoid recurring telemetry, log files, and `nvidia-smi` subprocesses.

## Adaptive Python GPU engine

The Python CLI retains three monitoring levels (NVML, `nvidia-smi`, open-loop) and three compute backends (PyTorch/cuBLAS, CuPy/cuBLAS, Numba kernel). Optional imports remain lazy so non-GPU tests and help work without CUDA frameworks.

Its portable release forces CuPy to avoid carrying multiple CUDA runtimes. This remains separate from the Flutter product release family.

## Release workflows

### Compute Stress Studio

`.github/workflows/flutter-stress-studio.yml` performs:

1. release-request metadata validation;
2. fast native CPU build and CTest;
3. Flutter format/analyze/tests;
4. Windows/Linux native CPU build and self-test;
5. Windows/Linux JUCE CUDA build and tests;
6. Windows/Linux Flutter release builds;
7. worker injection and final bundle validation;
8. checksums and optional release publication.

A normal push validates but does not publish. Publication requires either workflow dispatch or a changed JSON manifest under `release/compute-stress-studio/`.

### Other release families

- `release-gpu-packages.yml`: Python/CuPy portable, AppImage, Docker/GHCR.
- `release-juce-backup.yml`: standalone JUCE Windows/Linux/AppImage.
- `release-notes-maintenance.yml`: note-only edits to an existing release.

See [RELEASES.md](RELEASES.md).

## Local validation

### Native CPU

```bash
cmake -S native-cpu -B build/cpu-worker -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build/cpu-worker
ctest --test-dir build/cpu-worker --output-on-failure
```

### Flutter

```bash
cd apps/stress_studio
flutter create --platforms=windows,linux --org com.pme26elvis --project-name stress_studio .
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --coverage
```

### JUCE core without CUDA/GUI

```bash
cmake -S native-juce -B build/juce-core \
  -DGPU_STRESS_ENABLE_CUDA=OFF \
  -DGPU_STRESS_BUILD_GUI=OFF \
  -DGPU_STRESS_BUILD_TESTS=ON
cmake --build build/juce-core
ctest --test-dir build/juce-core --output-on-failure
```

### Python

```bash
python -m py_compile cpu_stress_cli.py gpu_stress_cli.py gpu_stress_portable.py gpu_stress_background.py
python -m unittest discover -s tests -v
```

## Engineering rules

- Never execute a stress hot loop in Flutter.
- Keep CPU and GPU worker contracts explicit and replaceable.
- Reserve scheduling capacity by default; full saturation must be an intentional user choice.
- Do not call a requested target measured utilization.
- Preserve manual and lifecycle stop paths for every workload.
- Add regression tests for lifecycle, parser, process, and packaging bugs.
- Keep version-specific release prose under `docs/releases/`.
- Do not make ordinary documentation pushes publish releases.

## Validation boundary

CI validates source, tests, native builds, Flutter builds, archive composition, and worker startup paths that do not require a physical GPU. It does not prove sustained GPU utilization, thermals, fan behavior, power, clocks, or target-machine stability.
