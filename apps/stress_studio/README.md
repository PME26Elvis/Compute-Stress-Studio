# Compute Stress Studio Flutter application

`apps/stress_studio` is the flagship Material 3 desktop control plane for coordinated CPU and NVIDIA GPU stress.

## Current status

- Windows x64 and Linux x64 release bundles;
- current preview: `compute-stress-studio-v0.2.0`;
- CPU and GPU hot loops both run outside the Flutter process;
- application-close lifecycle stops both child processes;
- physical NVIDIA execution still requires target-machine validation.

## Architecture

```text
OwnedStressStudioApp
        |
Compute Stress Studio / Material 3
        |
StudioController
    /            \
ProcessCpuStress  JuceGpuWorker
Service           Service
    |                 |
Compute-Stress-   GPU-Stress-JUCE-
CPU-Worker        Background
```

Flutter owns rendering, navigation, validation, presets, lifecycle state, history, rollback, and error presentation. It does not execute a stress hot loop.

The native CPU worker uses a 50 ms duty window and lowers its process priority. This v0.2 boundary replaces the first preview's in-process Dart isolate pool after a Windows UI responsiveness report.

## Product behavior

- responsive NavigationRail/NavigationBar layouts;
- light, dark, and system themes;
- Dashboard, Presets, Diagnostics, and Settings;
- independent CPU/GPU enable switches and targets;
- coordinated start, idempotent stop, timeout completion, and rollback;
- **Ctrl+Enter** starts and **Escape** stops;
- configuration locks while a session is active;
- displayed percentages are requested targets, not telemetry;
- Diagnostics shows both worker paths and readiness.

## Source bootstrap

```bash
cd apps/stress_studio
flutter create --platforms=windows,linux --org com.pme26elvis --project-name stress_studio .
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --coverage
```

A locally built Flutter app also needs the native workers beside the executable. The repository workflow builds and injects them automatically.

## Worker contracts

### CPU

```text
Windows: Compute-Stress-CPU-Worker.exe
Linux:   Compute-Stress-CPU-Worker
```

Arguments:

```text
--duration <seconds> --load <0..100> --threads <1..64>
```

Windows uses the GUI subsystem and Below Normal process priority. Linux applies a positive nice value.

### GPU

```text
Windows: GPU-Stress-JUCE-Background.exe
Linux:   GPU-Stress-JUCE-Background
```

Arguments:

```text
--duration <seconds> --load <0..100> --memory-mib <MiB> --device <index>
```

Early process exit is startup failure. Stop terminates the child and escalates after a timeout. A failure during transactional startup rolls back the other worker.

## Monitoring policy

The Flutter/JUCE path does not repeatedly launch `nvidia-smi`, write telemetry files, or label targets as physical readings. Use an external monitor for measured utilization, temperature, fan, clocks, and board power.

## Related documents

- [Repository documentation hub](../../docs/README.md)
- [Product and engineering specification](../../docs/FLUTTER_STRESS_STUDIO_SPEC.md)
- [Release channels](../../docs/RELEASES.md)
- [JUCE WaveMix worker](../../docs/JUCE_WAVEMIX_BACKUP_GUIDE.md)
