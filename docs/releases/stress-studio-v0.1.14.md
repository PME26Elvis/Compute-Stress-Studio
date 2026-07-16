# Compute Stress Studio preview 0.1.14

This is the first lifecycle-hardened preview of the Flutter **Stress Studio** desktop application inside the Compute Stress Studio repository.

## What is included

- a modern Material 3 desktop interface for coordinated CPU and NVIDIA GPU stress sessions;
- responsive NavigationRail, expanded rail, and NavigationBar layouts;
- light, dark, and system themes;
- independent CPU/GPU enable switches, target controls, duration, CPU worker count, GPU VRAM budget, and device index;
- quick, balanced, CPU validation, GPU validation, and 96-hour endurance presets;
- CPU stress in killable Dart isolates, away from Flutter's UI isolate;
- NVIDIA GPU stress through the bundled silent JUCE CUDA WaveMix worker;
- transactional startup: GPU startup failure rolls back CPU work started in the same session;
- coordinated manual stop, timeout completion, and bounded in-memory session history;
- **application-close cleanup:** the production Flutter root now owns and disposes `StudioController`, stopping active CPU isolates and the GPU child process when the app closes;
- strict Dart formatting, Flutter analysis, unit/controller/widget/lifecycle tests, native JUCE tests, and Windows/Linux release builds.

## Downloads

### Windows x64

```text
Stress-Studio-Windows-x64.zip
```

Extract the complete ZIP and run `stress_studio.exe`. Keep the executable, `data` directory, Flutter runtime files, and `GPU-Stress-JUCE-Background.exe` together.

### Linux x64

```text
Stress-Studio-Linux-x64.tar.gz
```

Extract the complete archive and run `stress_studio`. Keep `lib/`, `data/`, and `GPU-Stress-JUCE-Background` beside it.

### Integrity

```text
SHA256SUMS.txt
```

Use this file to verify the downloaded archive before extraction.

## Requirements

- Windows x64 or Linux x64;
- a compatible NVIDIA display driver for GPU sessions;
- the complete extracted application bundle;
- an external hardware monitor for measured utilization, temperature, fan, power, and clocks during sustained runs.

CPU-only sessions can run without the bundled GPU worker. GPU sessions require the worker and a compatible NVIDIA environment.

## Important load semantics

The percentages displayed by Stress Studio are **requested workload targets**. They are not measured utilization, TDP percentage, or a guarantee of OS-reported load. Results vary with CPU topology, OS scheduling, NVIDIA driver behavior, WDDM/display activity, clocks, power limits, cooling, and other processes.

The Flutter/JUCE path intentionally does not poll physical GPU telemetry or write periodic monitoring logs. Use an external monitoring tool, especially before using the endurance preset.

## Validation boundary

GitHub Actions validated formatting, static analysis, Flutter tests, application-close lifecycle cleanup, native tests, Windows and Linux compilation, final bundle composition, and archive creation. GitHub-hosted runners do not expose the target physical NVIDIA GPU, so a short low-load hardware smoke test is still required before a long run.

## Source provenance

- lifecycle hardening: PR #8;
- release source commit: `8733cdf45245b52057c9beb74103a81bebed5d52`;
- Flutter SDK: 3.44.0 stable;
- CUDA Toolkit used for the bundled native worker: 12.6.3.

## Known preview limitations

- no in-app physical CPU/GPU telemetry;
- no persistent run database or CSV export from the Flutter shell;
- no Flutter system-tray integration;
- no signed installer or auto-update;
- no macOS GPU support;
- physical CUDA stability and cooling remain machine-specific.
