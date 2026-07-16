# Flutter Stress Studio — Product and Engineering Specification

Status: implementation baseline for `agent/flutter-unified-stress-studio`  
Target SDK: Flutter 3.44.0 stable  
Initial desktop targets: Windows x64 and Linux x64

## 1. Product intent

Stress Studio is a one-stop desktop application for configuring, starting, stopping, and understanding coordinated CPU and NVIDIA GPU stress sessions. It is a new product surface, not a pixel-for-pixel migration of the existing PyQt or JUCE applications.

The application should feel like a modern workstation control plane: clear hierarchy, strong defaults, low cognitive load, responsive layouts, explicit lifecycle states, and safe recovery when one backend fails.

## 2. Product principles

1. **Flutter is the control plane, not the hot loop.** Rendering, navigation, state composition, validation, accessibility, and operator workflow belong in Flutter. Long-running GPU compute belongs behind a process boundary; CPU compute belongs in killable isolates.
2. **Progressive capability.** CPU-only operation must work everywhere Flutter desktop works. NVIDIA GPU controls activate when the bundled worker exists and starts successfully.
3. **No hidden monitoring side effects.** The app does not spawn `nvidia-smi`, does not write periodic telemetry, and does not create run logs by default. Physical telemetry remains the job of the user's external monitor.
4. **Failure isolation.** A GPU startup failure must stop any CPU workload started in the same transaction. Closing or stopping the UI must terminate child workloads.
5. **Deterministic packaging.** GitHub Actions pins Flutter 3.44.0, builds the JUCE worker, builds Flutter release bundles, injects the worker, emits checksums, and publishes immutable assets.
6. **Modern desktop UX.** Material 3, adaptive NavigationRail/NavigationBar layouts, keyboard shortcuts, animated state transitions, large-screen composition, and accessible status semantics are first-class requirements.

## 3. Scope

### 3.1 Included in v0.1

- Windows x64 and Linux x64 Flutter desktop applications.
- CPU stress using one Dart isolate per selected logical worker.
- NVIDIA GPU stress using the silent JUCE WaveMix background executable.
- Concurrent CPU+GPU sessions with a single duration and coordinated stop.
- CPU target load, isolate count, GPU duty target, VRAM budget, and device index.
- Presets: quick check, balanced, CPU validation, GPU validation, and 96-hour endurance.
- Dashboard, presets, diagnostics, and settings destinations.
- Material 3 light, dark, and system theme modes.
- Responsive desktop/mobile-width navigation.
- Ctrl+Enter start and Escape stop shortcuts.
- Unit tests, controller tests, widget tests, static analysis, and release builds.

### 3.2 Explicitly deferred

- In-app GPU temperature/power/utilization polling.
- macOS GPU stress support.
- System tray integration for the Flutter shell.
- Persistent run database and CSV export.
- Signed installers, MSIX, Snap, Flatpak, and auto-update.
- Native CPU affinity, priority, NUMA placement, or AVX-specific kernels.
- A federated native Flutter plugin replacing the executable worker boundary.

## 4. Information architecture

### Dashboard

The default workspace combines:

- a prominent session state and start/stop control;
- elapsed, remaining, CPU target, and GPU target cards;
- a workload composer with independent CPU/GPU enable switches;
- target sliders, worker count, VRAM budget, and duration chips;
- command gauges showing requested—not measured—load;
- worker readiness and current preset context.

### Presets

Preset cards explain intent before applying values. Applying a preset returns to the dashboard where every value remains editable.

### Diagnostics

Diagnostics show OS, logical processor count, bundled GPU worker path, worker availability, and the external-monitoring policy. Capability inspection must not start a stress workload.

### Settings

Settings contain theme and interaction preferences. Workload settings remain on the dashboard to avoid splitting one configuration across multiple pages.

## 5. Runtime architecture

```text
Flutter Material 3 UI
        |
StudioController (transaction + state machine)
        |
RunConfiguration / validation / presets
        |
+------------------------+-----------------------------+
| CPU adapter            | GPU adapter                 |
| Dart isolate pool      | silent JUCE Background exe |
| 50 ms duty windows     | CUDA WaveMix scheduler     |
+------------------------+-----------------------------+
```

### 5.1 Flutter layer

- `RunConfiguration` is immutable and validated before execution.
- `StudioController` is the single orchestration state owner.
- Services are injected behind interfaces so tests never create real load.
- UI widgets observe `ChangeNotifier` through `ListenableBuilder`.
- The initial implementation deliberately avoids third-party runtime packages to reduce desktop plugin and supply-chain surface.

### 5.2 CPU adapter

The CPU adapter creates one isolate per configured worker. Each isolate runs a 50 ms duty window: busy floating-point work for the active portion and sleep for the remainder. Isolates are immediately killable, preventing a busy UI event loop and bounding stop latency.

The percentage is a commanded duty target, not a guarantee of OS-reported total CPU utilization. Scheduler placement, logical/physical core topology, power policy, and competing processes influence measured utilization.

### 5.3 GPU adapter

The GPU adapter locates the existing silent JUCE worker beside the Flutter executable. It passes duration, load, VRAM budget, and device index through the established CLI contract. The worker is already a GUI-subsystem/no-window executable on Windows, avoiding recurring console flashes.

The Flutter app treats early worker exit as startup failure and rolls back CPU load. Stop sends a graceful termination signal and escalates to a forced kill after a short timeout.

### 5.4 State machine

```text
idle -> starting -> running -> stopping -> idle
                    |             |
                    +-----------> completed
starting/running ----------------> error
```

Configuration is immutable while active. Start is transactional across CPU and GPU adapters. Stop is idempotent.

## 6. UX and visual system

- Material 3 color schemes generated from a violet primary seed with a mint status accent.
- 24–30 px radii on large workstation surfaces.
- High-information cards with restrained borders rather than heavy elevation.
- Gradient hero panel for the primary action, not decorative full-screen gradients.
- NavigationRail at desktop widths, expanded rail on large displays, NavigationBar on narrow windows.
- Custom painted radial gauges avoid chart-package dependency.
- Explicit copy distinguishes target load from physical telemetry.
- Error messages remain inline and actionable.

## 7. Accessibility and interaction

- All actions use standard Material controls and semantics.
- Keyboard-only start/stop is supported.
- Layout remains usable at narrow window widths.
- State is communicated through text plus icon/color, never color alone.
- Controls disable while a run is active rather than silently accepting changes.

## 8. Packaging

### Windows

1. Generate Windows platform scaffolding with Flutter 3.44.0.
2. Build the native JUCE CUDA worker with CUDA 12.6.3 and `sm_61` support.
3. Build `flutter build windows --release`.
4. Copy `GPU-Stress-JUCE-Background.exe` beside `stress_studio.exe`.
5. Add this specification, source commit, and third-party notices.
6. Zip the complete runner directory.

### Linux

1. Install GTK and Flutter desktop dependencies.
2. Generate Linux platform scaffolding.
3. Build the JUCE CUDA worker.
4. Build `flutter build linux --release`.
5. Copy `GPU-Stress-JUCE-Background` beside the Flutter executable.
6. Emit a compressed tar archive.

The executable must not be separated from its adjacent Flutter libraries/data or GPU worker.

## 9. Test strategy

### Unit

- configuration validation;
- preset values;
- empty workload rejection;
- service rollback on GPU failure.

### Controller

- coordinated start/stop;
- state transitions;
- bounded history;
- completion timer behavior;
- no mutation while active.

### Widget

- dashboard composition;
- CPU and GPU controls are discoverable;
- responsive navigation modes;
- keyboard actions;
- inline error rendering.

### CI and packaging

- `dart format --set-exit-if-changed`;
- `flutter analyze` with strict casts/inference/raw types;
- `flutter test`;
- Windows and Linux release build;
- native JUCE tests;
- worker presence in final bundles;
- archive size and checksum validation.

Physical CUDA execution cannot be validated by GitHub-hosted runners and still requires a short real-machine smoke test.

## 10. Branch and merge policy

Development occurs on `agent/flutter-unified-stress-studio`. The branch stays separate while the specification, Flutter quality job, Windows package, and Linux package are under review. After all required checks pass, merge to `main` using a normal merge commit and retain the branch, matching the repository's established preference.

## 11. Roadmap after v0.1

1. Add a federated `stress_runtime` Flutter plugin with Windows/Linux native implementations.
2. Add optional NVML telemetry through dynamic library loading, never through recurring `nvidia-smi` child processes.
3. Add Flutter system tray and window lifecycle integration.
4. Add persistent profiles and session history.
5. Add signed MSIX and Linux package formats.
6. Add macOS CPU-only support and a capability-specific GPU message.
7. Add workload phases, ramps, and independent CPU/GPU timelines.
