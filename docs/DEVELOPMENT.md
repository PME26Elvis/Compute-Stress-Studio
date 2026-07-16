# Architecture and development

This document describes the current repository as a whole. Subsystem guides cover operator details; this file explains boundaries, contracts, and validation.

## Repository architecture

```text
Compute Stress Studio repository
|
+-- apps/stress_studio/       Flutter CPU+GPU control plane
|   +-- Dart isolate CPU adapter
|   +-- external JUCE GPU adapter
|
+-- native-juce/              C++20/JUCE CUDA WaveMix engine
|   +-- GUI/tray application
|   +-- silent CLI
|   +-- hidden background executable
|
+-- gpu_stress_cli.py         adaptive Python NVIDIA CLI
|   +-- NVML / nvidia-smi / open-loop monitoring
|   +-- PyTorch / CuPy / Numba compute backends
|
+-- packaging/                PyInstaller and AppImage delivery
+-- main.py + PyQt modules    original Linux CPU monitor
+-- cpu_stress_cli.py         standalone CPU CLI
+-- tests/                    Python and packaging tests
```

The repository intentionally keeps multiple independent engines. They are not duplicate ports:

- Flutter is the modern orchestration and UX layer.
- JUCE WaveMix is the native GPU worker and an independent fallback application.
- The Python GPU CLI is the adaptive, telemetry-aware implementation.
- The original CPU tools remain useful standalone utilities.

## Flutter control plane

### Ownership and lifecycle

`OwnedStressStudioApp` owns `StudioController` in production. Removing the root widget disposes the controller, which begins stopping CPU isolates and the GPU child process. The presentational `StressStudioApp` accepts an injected controller so widget tests can remain deterministic.

### State and transaction model

`StudioController` owns:

- immutable `RunConfiguration`;
- idle, starting, running, stopping, completed, and error states;
- one coordinated duration and elapsed timer;
- bounded in-memory history;
- start rollback and idempotent stop;
- theme and selected-page state.

Start validates first, then starts enabled services together. Any startup failure stops both services before exposing the error. Configuration changes are rejected while active.

### CPU service

`IsolateCpuStressService` creates one Dart isolate per selected worker. Each isolate uses a short duty window with compute followed by sleep. The UI isolate never performs the hot loop, and `Isolate.kill(priority: Isolate.immediate)` provides bounded stop behavior.

The target is a duty request, not a promise of total system utilization. OS scheduling, SMT topology, processor power policy, and other work affect measured results.

### GPU service

`JuceGpuWorkerService` expects the silent native worker beside the Flutter executable and passes:

```text
--duration <seconds>
--load <percent>
--memory-mib <budget>
--device <index>
```

The service drains child output, checks for early exit, requests graceful termination, and escalates to forced termination after timeout. The process boundary keeps CUDA failures and future backend replacement separate from the Flutter UI architecture.

## Native JUCE WaveMix engine

The native implementation uses a calibrated CUDA WaveMix kernel with FP32 arithmetic, integer scrambling, and memory traffic. A measured active-time scheduler applies duty control over a fixed window.

Release builds include `sm_61` for the Quadro P2200 and selected newer architectures. The native application deliberately avoids recurring telemetry, log files, and `nvidia-smi` subprocesses during normal runs.

Entry points:

```text
GPU-Stress-JUCE.exe                 GUI and notification-area app
GPU-Stress-JUCE-Background.exe      hidden no-window application
GPU-Stress-JUCE-CLI.exe             silent command-line application
```

On Linux the same roles are provided without the `.exe` suffix, subject to desktop tray support.

## Adaptive Python GPU engine

### Monitoring fallback

`make_monitor()` attempts:

1. NVML through `nvidia-ml-py`;
2. `nvidia-smi` CSV output;
3. `NullMonitor` for open-loop duty control.

### Compute fallback

`make_backend()` attempts:

1. PyTorch/cuBLAS;
2. CuPy/cuBLAS;
3. a Numba CUDA kernel.

Optional CUDA frameworks are imported lazily so help, parsing, static checks, and CPU-only tests work on non-GPU runners.

### Load control

Each backend synchronizes before returning from a chunk. A work-credit accumulator preserves long-term duty behavior when one calibrated chunk is longer than an instantaneous budget. With utilization telemetry, an EMA-filtered PI controller corrects duty toward the device-wide target.

### Memory policy

The CLI preserves driver/display headroom, uses only a fraction of the requested budget for resident tensors, aligns matrix dimensions, reuses buffers, and retries smaller allocations after out-of-memory errors.

## Portable Python distribution

The portable worker intentionally forces CuPy rather than bundling all three Python GPU frameworks. This avoids duplicated CUDA runtimes and reduces platform-specific DLL/JIT failure modes.

`gpu_stress_portable.py` applies packaged defaults only when the user omitted explicit values. Source `gpu_stress_cli.py` still requires an explicit duration so a source checkout never starts the 96-hour personal run unexpectedly.

The Windows hidden launcher is a small GUI-subsystem executable that starts the larger one-folder worker detached and tracks one PID file. It uses stable executable names so a manual `taskkill` remains possible.

## Original CPU applications

- `main.py`, `main_window.py`, and `stress_test.py` implement the original Linux PyQt monitor/stress GUI.
- `cpu_stress_cli.py` implements constant, pulsed, and ramp CPU load from the command line.

These tools do not depend on Flutter or the NVIDIA GPU stack.

## Release workflows

### Flutter desktop

`.github/workflows/flutter-stress-studio.yml` validates pull requests and pushes, builds both platform bundles, and uploads workflow artifacts. GitHub Release publication is manual and idempotent: an explicit dispatch chooses tag, title, notes file, and prerelease state.

### Release-note maintenance

`.github/workflows/release-notes-maintenance.yml` edits an existing GitHub Release from a versioned Markdown file without rebuilding assets. It is used for the corrected `stress-studio-v0.1.14` notes and can be dispatched for future note-only fixes.

### Python GPU portable

`.github/workflows/release-gpu-packages.yml` builds Windows/Linux portable packages, AppImage, Docker/GHCR delivery, checksums, and release assets. It remains a separate channel because the runtime and artifact set differ from the Flutter desktop app.

### Native JUCE

The native workflow builds Windows and Linux entry points, exercises core/native tests, validates silent behavior and GUI/tray lifecycle where supported, and packages independent fallback releases.

See [RELEASES.md](RELEASES.md) for the canonical artifact matrix.

## Local validation

### Python

```bash
python -m py_compile cpu_stress_cli.py gpu_stress_cli.py gpu_stress_portable.py gpu_stress_background.py
python -m unittest discover -s tests -v
python gpu_stress_cli.py --help
python gpu_stress_portable.py --help
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

Build Windows on Windows and Linux on Linux:

```bash
flutter build windows --release
flutter build linux --release
```

### Native core without CUDA/GUI

```bash
cmake -S native-juce -B build/juce-core \
  -DGPU_STRESS_ENABLE_CUDA=OFF \
  -DGPU_STRESS_BUILD_GUI=OFF \
  -DGPU_STRESS_BUILD_TESTS=ON
cmake --build build/juce-core
ctest --test-dir build/juce-core --output-on-failure
```

### Physical GPU smoke test

CI cannot replace a target-machine test. On the intended NVIDIA system, validate discovery and low-load behavior before a long run. Monitor cooling and physical telemetry externally.

## Engineering rules

- Keep CUDA imports lazy in Python modules used by CPU-only CI.
- Never perform stress work on Flutter's UI isolate.
- Keep the Flutter/native boundary explicit and replaceable.
- Do not call requested load “measured utilization.”
- Do not add recurring monitoring or file writes to the silent JUCE worker without changing its documented contract.
- Preserve a manual stop path for every background workload.
- Add a regression test for every lifecycle, rollback, parser, or packaging bug.
- Version-specific release prose belongs in `docs/releases/`, not inline heredocs duplicated across workflows.

## Known limitations

- NVML utilization is device-wide and includes unrelated GPU work.
- A utilization target is not a board-power target.
- WDDM, clocks, power caps, cooling, and throttling change observed behavior.
- Flutter v0.1 does not expose physical telemetry or persistent history.
- Portable Linux binaries can encounter host glibc compatibility differences.
- AppImage may need extract-and-run mode where FUSE is unavailable.
- Existing GHCR images and release artifacts keep legacy names until users migrate.
- This repository creates load; it is not a dedicated CPU/GPU memory error detector or hardware certification suite.
