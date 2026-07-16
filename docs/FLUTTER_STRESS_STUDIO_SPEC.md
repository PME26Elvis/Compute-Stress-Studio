# Stress Studio — product and engineering specification

**Repository product:** Compute Stress Studio  
**Application:** Stress Studio (`apps/stress_studio`)  
**Status:** v0.1 implementation merged and lifecycle-hardened  
**Current preview:** `stress-studio-v0.1.14`  
**Pinned SDK:** Flutter 3.44.0 stable  
**Desktop targets:** Windows x64 and Linux x64

## 1. Product intent

Stress Studio is a one-stop desktop application for configuring, starting, stopping, and understanding coordinated CPU and NVIDIA GPU stress sessions. It is a purpose-built Flutter product surface, not a pixel-for-pixel migration of the original PyQt or JUCE windows.

The application should feel like a workstation control plane: clear hierarchy, strong defaults, low cognitive load, responsive layouts, explicit lifecycle states, and safe recovery when one backend fails.

## 2. Product principles

1. **Flutter is the control plane, not the hot loop.** Rendering, navigation, validation, accessibility, presets, and operator workflow belong in Flutter. Long-running GPU compute stays behind a process boundary; CPU compute stays in killable isolates.
2. **Progressive capability.** CPU-only operation remains possible when the bundled NVIDIA worker is unavailable. GPU startup errors must be visible and actionable.
3. **No hidden monitoring side effects.** The app does not repeatedly spawn `nvidia-smi`, write periodic telemetry, or present target values as measured utilization.
4. **Failure isolation.** A GPU startup failure stops CPU work started in the same transaction. Manual stop, timeout completion, controller disposal, and normal application shutdown terminate child workloads.
5. **Deterministic packaging.** GitHub Actions pins Flutter and CUDA versions, builds the JUCE worker, builds Flutter bundles, injects the worker, verifies the final layout, emits checksums, and publishes explicit releases.
6. **Modern desktop UX.** Material 3, adaptive navigation, keyboard shortcuts, animated transitions, large-screen composition, narrow-window usability, and accessible status semantics are first-class requirements.

## 3. Implemented v0.1 scope

- Windows x64 and Linux x64 Flutter desktop applications.
- CPU stress using one Dart isolate per selected logical worker.
- NVIDIA GPU stress using the silent JUCE CUDA WaveMix executable.
- Concurrent CPU+GPU sessions with one duration and coordinated stop.
- CPU target load, isolate count, GPU duty target, VRAM budget, and device index.
- Presets: quick check, balanced, CPU validation, GPU validation, and 96-hour endurance.
- Dashboard, presets, diagnostics, and settings destinations.
- Material 3 light, dark, and system theme modes.
- NavigationRail, expanded NavigationRail, and NavigationBar layouts.
- **Ctrl+Enter** start and **Escape** stop shortcuts.
- Transactional start/rollback and idempotent stop.
- Bounded in-memory session history.
- Production root ownership that disposes the controller and stops workers when the app closes.
- Strict analysis, unit tests, controller tests, widget tests, native tests, and Windows/Linux bundle builds.

## 4. Explicitly deferred

- In-app GPU temperature, power, fan, clock, and measured-utilization polling.
- macOS GPU stress support.
- Flutter system-tray integration.
- Persistent profiles, run database, and CSV export from the Flutter shell.
- Signed installers, MSIX, Flatpak, Snap, and auto-update.
- Native CPU affinity, priority, NUMA placement, and architecture-specific kernels.
- A federated native Flutter plugin replacing the executable worker boundary.
- Independent CPU/GPU timelines and phased/ramp workloads inside the Flutter app.

## 5. Information architecture

### Dashboard

The default workspace combines:

- session state and primary start/stop actions;
- elapsed, remaining, CPU target, and GPU target cards;
- independent CPU/GPU switches;
- target sliders, isolate count, VRAM budget, device index, and duration controls;
- command gauges showing requested—not measured—load;
- worker readiness, current preset, inline validation, and runtime errors.

### Presets

Preset cards explain purpose before applying values. Applying a preset returns to the dashboard, where all values remain editable until a session starts.

### Diagnostics

Diagnostics show OS, logical processor count, bundled worker path, worker availability, and the external-monitoring policy. Capability inspection does not start load.

### Settings

Settings contain theme and interaction preferences. Workload configuration remains on the dashboard so one run is not split across multiple pages.

## 6. Runtime architecture

```text
OwnedStressStudioApp (lifecycle owner)
        |
StressStudioApp / Material 3 UI
        |
StudioController (state machine + transaction coordinator)
        |
RunConfiguration / validation / presets / history
        |
+---------------------------+------------------------------+
| CPU adapter               | GPU adapter                  |
| Dart isolate pool         | silent JUCE background exe   |
| 50 ms duty windows        | CUDA WaveMix scheduler       |
+---------------------------+------------------------------+
```

### Flutter layer

- `RunConfiguration` is immutable and validated before execution.
- `StudioController` is the single orchestration state owner.
- services are injected behind interfaces so tests never create real load;
- widgets observe state through `ChangeNotifier` and `ListenableBuilder`;
- the implementation avoids unnecessary runtime packages to reduce desktop plugin and supply-chain surface;
- `OwnedStressStudioApp` owns controller disposal in production, while the presentational app remains independently testable.

### CPU adapter

The CPU adapter creates one isolate per configured worker. Each isolate runs a 50 ms duty window: floating-point busy work for the active portion and sleep for the remainder. Isolates are immediately killable, keeping compute away from the UI isolate and bounding stop latency.

The percentage is a commanded duty target, not a guarantee of OS-reported total CPU utilization. Scheduler placement, SMT topology, power policy, and competing processes affect measured results.

### GPU adapter

The GPU adapter locates `GPU-Stress-JUCE-Background.exe` on Windows or `GPU-Stress-JUCE-Background` on Linux beside the Flutter executable. It passes duration, load, VRAM budget, and device index through the established CLI contract.

Early worker exit is startup failure and rolls back CPU load. Stop requests graceful termination and escalates to forced termination after a short timeout. Controller disposal begins the same cleanup path during normal app shutdown.

### State machine

```text
idle -> starting -> running -> stopping -> idle
                     |             |
                     +-----------> completed
starting/running ----------------> error
```

Configuration is locked while active. Start is transactional across enabled adapters. Stop is idempotent.

## 7. UX and accessibility

- Material 3 color schemes with high-information cards and restrained elevation.
- Gradient treatment is limited to the primary hero surface.
- Navigation adapts by window width rather than assuming one desktop size.
- Standard Material controls preserve keyboard and semantic behavior.
- State is communicated with text and iconography, not color alone.
- Controls disable while active instead of silently accepting changes.
- Copy explicitly distinguishes target values from physical telemetry.
- Errors remain inline and actionable.

## 8. Packaging contract

### Windows

1. Generate Windows scaffolding with Flutter 3.44.0.
2. Build the JUCE CUDA worker with CUDA 12.6.3 and `sm_61` support.
3. Run `flutter build windows --release`.
4. Copy `GPU-Stress-JUCE-Background.exe` beside `stress_studio.exe`.
5. Add specification, source commit, JUCE guide, and third-party notices.
6. Verify both executables and archive the complete runner directory.

### Linux

1. Install GTK and Flutter desktop dependencies.
2. Generate Linux scaffolding.
3. Build and test the JUCE CUDA worker.
4. Run `flutter build linux --release`.
5. Copy `GPU-Stress-JUCE-Background` beside `stress_studio`.
6. Verify both executables and emit a compressed tar archive.

The executable must not be separated from adjacent Flutter libraries, data, or the GPU worker.

## 9. Validation strategy

### Pure and controller tests

- configuration defaults and validation;
- preset values and empty-workload rejection;
- coordinated start/stop;
- GPU failure rollback;
- lifecycle state transitions and bounded history.

### Widget and lifecycle tests

- dashboard and workload-control discoverability;
- responsive app composition;
- production owner disposal;
- active fake CPU and GPU services stop when the app root is removed.

### CI and packaging

- canonical Dart formatting;
- strict Flutter analysis;
- Flutter tests with coverage;
- Windows and Linux Flutter release builds;
- native JUCE/CUDA builds and tests;
- worker presence in both bundles;
- archive creation and SHA256 checksums.

GitHub-hosted runners cannot execute the real CUDA workload on the target GPU. Sustained utilization, cooling, temperature, fan, clocks, power, and machine stability require a physical smoke test.

## 10. Release policy

Pull requests and relevant pushes validate source and assemble artifacts. GitHub Releases are published only by an explicit workflow dispatch with a chosen tag, title, notes file, and prerelease flag. Version-specific notes live under `docs/releases/`; note-only corrections use the release-maintenance workflow.

See [RELEASES.md](RELEASES.md) for artifact names and compatibility policy.

## 11. Roadmap

1. Add optional NVML telemetry through dynamic library loading without recurring `nvidia-smi` child processes.
2. Add persistent profiles and session history.
3. Add phased workloads, ramps, and independent CPU/GPU timelines.
4. Add native system-tray and window-close confirmation for active sessions.
5. Add signed Windows packaging and additional Linux package formats.
6. Evaluate a federated native runtime plugin once the executable contract is proven stable.
7. Add macOS CPU-only support with capability-aware GPU messaging.
