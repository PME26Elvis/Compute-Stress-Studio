# Compute Stress Studio — product and engineering specification

**Application:** `apps/stress_studio`  
**Current preview:** `compute-stress-studio-v0.2.0`  
**Pinned SDK:** Flutter 3.44.0 stable  
**Desktop targets:** Windows x64 and Linux x64

## 1. Product intent

Compute Stress Studio is a one-stop desktop application for configuring and controlling coordinated CPU and NVIDIA GPU stress sessions. It is a purpose-built Flutter workstation UI, not a direct port of the original PyQt or JUCE interfaces.

The app must remain responsive enough to stop a workload even while the selected CPU and GPU targets are active. UI responsiveness is an architectural requirement, not a visual polish item.

## 2. Product principles

1. **Flutter is only the control plane.** Rendering, validation, presets, accessibility, state, rollback, history, and lifecycle belong in Flutter. Compute hot loops belong in child processes.
2. **The window must remain schedulable.** CPU stress may not share the Flutter process. The CPU child lowers its OS scheduling priority and presets reserve one logical processor by default.
3. **Progressive capability.** CPU-only sessions work without an NVIDIA GPU. GPU controls depend on the bundled JUCE CUDA worker and a compatible driver.
4. **No hidden monitoring side effects.** The app does not repeatedly spawn `nvidia-smi`, write telemetry logs, or present target values as measurements.
5. **Transactional lifecycle.** Startup failure in either enabled worker rolls back the other. Stop, timeout, app disposal, and normal shutdown terminate both child processes.
6. **Deterministic packaging.** CI pins toolchains, builds and tests both native workers, builds Flutter, injects workers, validates the final directory, emits checksums, and publishes only explicit releases.
7. **Modern desktop UX.** Material 3, adaptive navigation, keyboard actions, responsive composition, direct diagnostics, and clear state language are first-class requirements.

## 3. Implemented v0.2 scope

- Windows x64 and Linux x64 Flutter desktop apps.
- CPU stress in the bundled `Compute-Stress-CPU-Worker` process.
- NVIDIA GPU stress in the bundled silent JUCE CUDA WaveMix process.
- Concurrent CPU+GPU sessions with one duration and coordinated stop.
- CPU target load and worker-thread count.
- GPU duty target, VRAM budget, and device index.
- Quick check, Balanced, CPU validation, GPU validation, and 96-hour endurance presets.
- Presets reserve one logical processor by default when more than one is available.
- Dashboard, presets, diagnostics, settings, light/dark/system theme, and adaptive navigation.
- **Ctrl+Enter** start and **Escape** stop.
- Transactional start/rollback, idempotent stop, bounded in-memory history, and application-close cleanup.
- Diagnostics for both packaged workers.
- Strict Flutter tests plus native CPU and JUCE tests.

## 4. Deferred scope

- In-app GPU temperature, power, fan, clocks, and measured utilization.
- macOS GPU stress.
- Flutter system tray integration.
- Persistent profiles, databases, and CSV export from the Flutter shell.
- Signed installers, MSIX, Flatpak, Snap, and automatic updates.
- CPU affinity, NUMA placement, architecture-specific SIMD modes, and per-core topology controls.
- Independent CPU/GPU timelines and phased/ramp sessions.
- A federated native Flutter plugin replacing the proven process contract.

## 5. Information architecture

### Dashboard

- session state and primary start/stop actions;
- elapsed, remaining, CPU target, and GPU target cards;
- independent CPU/GPU enable switches;
- CPU load/thread controls and GPU load/VRAM/device controls;
- requested-load gauges, not telemetry gauges;
- inline validation, worker errors, and active preset context.

### Presets

Preset cards explain their purpose. Values remain editable until the session starts.

### Diagnostics

Diagnostics show the operating system, logical processor count, CPU worker path/readiness, GPU worker path/readiness, and external-monitoring policy. Diagnostics do not create load.

### Settings

Settings contain presentation and interaction preferences. Workload configuration stays on the dashboard.

## 6. Runtime architecture

```text
OwnedStressStudioApp
        |
Flutter Material 3 UI
        |
StudioController
   /             \
CPU service       GPU service
   |                  |
Compute-Stress-   GPU-Stress-JUCE-
CPU-Worker        Background
   |                  |
CPU duty threads  CUDA WaveMix scheduler
```

### Flutter layer

- `RunConfiguration` is immutable and validated before execution.
- `StudioController` owns the session state machine and transaction.
- services are injected so tests use fake workers;
- `OwnedStressStudioApp` owns controller disposal;
- Flutter never executes a compute hot loop;
- target percentages are commands, not physical telemetry.

### CPU worker

The CPU worker is a small native C++20 executable built from `native-cpu/`.

- Windows uses a GUI-subsystem executable, so no terminal window appears.
- Windows calls `SetPriorityClass(..., BELOW_NORMAL_PRIORITY_CLASS)`.
- Linux applies a positive nice value.
- one native thread is created per selected worker thread;
- each thread uses a 50 ms window with floating-point busy work for the active portion and sleep for the remainder;
- Stop terminates the worker process, bounding Flutter-side stop latency;
- parser, recommended worker count, self-test, and early-stop behavior are covered by CTest.

The first preview used Dart isolates in the Flutter process. That kept work off the UI isolate but could still saturate the process and Windows scheduler enough for the window to be marked Not responding. v0.2 replaces that implementation.

### GPU worker

The GPU service locates `GPU-Stress-JUCE-Background.exe` or `GPU-Stress-JUCE-Background` beside Flutter. It passes duration, duty target, VRAM budget, and device index through the established CLI contract. Early exit is startup failure.

### State machine

```text
idle -> starting -> running -> stopping -> idle
                     |             |
                     +-----------> completed
starting/running ----------------> error
```

Configuration is locked while active. Start is transactional. Stop is idempotent.

## 7. UX and accessibility

- Material 3 color schemes and restrained elevation.
- NavigationRail on desktop widths and NavigationBar on narrow windows.
- Keyboard and standard Material semantics.
- Text and iconography accompany state colors.
- Controls disable while active.
- Errors remain inline and actionable.
- Product copy consistently uses Compute Stress Studio.
- Diagnostics make the two-process boundary visible rather than hiding it.

## 8. Packaging contract

### Windows

1. Build/test `native-cpu` with MSVC and static runtime.
2. Build/test the JUCE CUDA worker with CUDA 12.6.3 and `sm_61` support.
3. Build Flutter Windows release.
4. Place `Compute-Stress-CPU-Worker.exe` and `GPU-Stress-JUCE-Background.exe` beside `stress_studio.exe`.
5. Run the CPU worker self-test from the assembled directory.
6. Verify all three executables and archive the entire runner directory.

### Linux

1. Build/test `native-cpu` with C++20.
2. Build/test the JUCE CUDA worker.
3. Build Flutter Linux release.
4. Place both worker executables beside `stress_studio`.
5. Run the CPU worker self-test from the assembled directory.
6. Emit a compressed tar archive.

The Flutter executable must not be separated from adjacent libraries, data, or workers.

## 9. Validation strategy

### Flutter tests

- configuration and reserved-core defaults;
- CPU/GPU command contracts;
- empty-workload rejection;
- coordinated start/stop and rollback;
- production owner cleanup;
- dashboard controls, product branding, and both diagnostic worker entries.

### Native CPU tests

- argument parsing and validation;
- recommended worker count;
- invalid input rejection;
- early-stop latency;
- silent packaged `--self-test`.

### CI and packaging

- canonical Dart formatting and strict analysis;
- Flutter tests with coverage;
- Windows/Linux native CPU builds and CTest;
- Windows/Linux JUCE/CUDA builds and native tests;
- Windows/Linux Flutter release builds;
- both workers present in final bundles;
- CPU self-test from final bundles;
- archive creation and SHA256 checksums.

Physical CUDA behavior still requires a target-machine smoke test.

## 10. Release policy

Pull requests and relevant pushes validate and assemble artifacts. Releases are created by explicit workflow dispatch or a versioned JSON manifest under `release/compute-stress-studio/`. The release job runs only after every quality and package job succeeds.

See [RELEASES.md](RELEASES.md) for tags, assets, legacy compatibility, and provenance.

## 11. Roadmap

1. Add optional NVML telemetry through dynamic loading without recurring child-process polling.
2. Add persistent profiles and session history.
3. Add workload phases, ramps, and independent timelines.
4. Add system-tray and active-session close confirmation to Flutter.
5. Add signed Windows packaging and more Linux formats.
6. Evaluate a federated native runtime plugin once process behavior is stable across more hardware.
7. Add macOS CPU-only support with capability-aware GPU messaging.
