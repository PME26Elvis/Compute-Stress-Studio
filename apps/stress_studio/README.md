# Stress Studio Flutter application

`apps/stress_studio` is the flagship desktop application inside **Compute Stress Studio**. It coordinates CPU and NVIDIA GPU stress from one Material 3 interface without placing long-running compute loops on Flutter's UI isolate.

## Current status

- implemented and merged to `main`;
- Windows x64 and Linux x64 release builds validated in GitHub Actions;
- current preview tag: `stress-studio-v0.1.14`;
- application-close lifecycle owns and disposes `StudioController`, stopping active CPU isolates and the bundled GPU worker;
- physical NVIDIA execution still requires a target-machine smoke test.

## Architecture

```text
OwnedStressStudioApp
        |
StressStudioApp / Material 3 UI
        |
StudioController
        |
+----------------------+-------------------------------+
| IsolateCpuStressService | JuceGpuWorkerService       |
| Dart isolate pool       | external silent executable |
+----------------------+-------------------------------+
```

Flutter owns rendering, navigation, validation, presets, lifecycle state, history, and error presentation. CPU work runs in killable isolates. GPU work runs behind a process boundary using the existing native JUCE CUDA WaveMix worker.

## Product behavior

- responsive NavigationRail, expanded NavigationRail, and NavigationBar layouts;
- light, dark, and system themes;
- dashboard, presets, diagnostics, and settings destinations;
- independent CPU/GPU enable switches and targets;
- coordinated start, idempotent stop, timeout completion, and rollback on GPU startup failure;
- **Ctrl+Enter** starts and **Escape** stops;
- configuration locks while a session is active;
- displayed percentages are requested workload targets, not measured telemetry.

## Bootstrap from source

Platform scaffolding is generated from the pinned Flutter SDK rather than checked into the repository:

```bash
cd apps/stress_studio
flutter create --platforms=windows,linux --org com.pme26elvis --project-name stress_studio .
flutter pub get
```

Run on the matching host:

```bash
flutter run -d windows
flutter run -d linux
```

## Validation

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --coverage
flutter build windows --release
flutter build linux --release
```

The repository workflow additionally compiles and tests the JUCE CUDA worker, copies it beside the Flutter executable, verifies both files, and archives the complete runner directory.

## GPU worker contract

The packaged application expects one of these files beside the Flutter executable:

```text
Windows: GPU-Stress-JUCE-Background.exe
Linux:   GPU-Stress-JUCE-Background
```

Stress Studio passes `--duration`, `--load`, `--memory-mib`, and `--device`. Early process exit is treated as startup failure and rolls back the CPU workload. Stop first sends a graceful termination request and escalates to forced termination after a short timeout.

The app intentionally does not launch `nvidia-smi` or label target values as physical readings. Use an external monitor for utilization, temperature, fan, clocks, and board power.

## Related documents

- [Repository documentation hub](../../docs/README.md)
- [Product and engineering specification](../../docs/FLUTTER_STRESS_STUDIO_SPEC.md)
- [Release channels](../../docs/RELEASES.md)
- [JUCE WaveMix worker](../../docs/JUCE_WAVEMIX_BACKUP_GUIDE.md)
