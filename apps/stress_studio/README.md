# Stress Studio

`apps/stress_studio` is the Flutter 3.44 desktop control plane for coordinated CPU and NVIDIA GPU stress sessions.

## Why this is a separate app

The Flutter client is intentionally not a direct port of the PyQt or JUCE windows. It introduces:

- Material 3 light/dark design tokens;
- responsive NavigationRail/NavigationBar layouts;
- keyboard actions and explicit run state transitions;
- presets, diagnostics, configuration validation, and bounded history;
- a process boundary between UI and the silent JUCE GPU worker;
- killable Dart isolates for CPU stress;
- testable service interfaces with fake implementations.

## Bootstrap

Flutter platform scaffolding is generated from the pinned SDK rather than checked in:

```bash
cd apps/stress_studio
flutter create --platforms=windows,linux --org com.pme26elvis --project-name stress_studio .
flutter pub get
flutter run -d windows
```

For Linux use `flutter run -d linux`.

## GPU worker contract

The packaged app expects `GPU-Stress-JUCE-Background.exe` on Windows or `GPU-Stress-JUCE-Background` on Linux beside the Flutter executable. The release workflow builds the existing CUDA/JUCE worker and copies it into the final Flutter bundle.

## Validation

```bash
flutter analyze
flutter test
flutter build windows --release
flutter build linux --release
```
