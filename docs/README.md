# Compute Stress Studio documentation

This directory is organized by reader intent. Start here instead of treating every historical guide as an equal entry point.

## Start here

| I need to… | Read |
| --- | --- |
| understand the whole repository | [Architecture and development](DEVELOPMENT.md) |
| choose a downloadable build | [Release channels and artifact matrix](RELEASES.md) |
| understand the Flutter desktop product | [Flutter Stress Studio specification](FLUTTER_STRESS_STUDIO_SPEC.md) |
| use the adaptive Python NVIDIA CLI | [GPU stress usage](GPU_STRESS.md) |
| understand Python portable/AppImage/Docker packaging | [Python GPU packaging](PACKAGING.md) |
| use the independent native CUDA fallback | [JUCE WaveMix guide](JUCE_WAVEMIX_BACKUP_GUIDE.md) |
| run the personal Quadro P2200 preset | [Quadro P2200 guide](QUADRO_P2200_PERSONAL_PRESET.md) |
| work directly on the native source | [Native JUCE README](../native-juce/README.md) |

## Product layers

### 1. Stress Studio desktop app

`apps/stress_studio/` is the flagship Flutter control plane for coordinated CPU and NVIDIA GPU sessions. It owns configuration, validation, session state, presets, responsive UI, and shutdown cleanup. It delegates CPU work to Dart isolates and GPU work to a bundled native process.

### 2. Adaptive Python GPU stack

`gpu_stress_cli.py` is the telemetry-aware source CLI with PyTorch, CuPy, and Numba fallback backends. The portable distribution deliberately narrows this to CuPy/cuBLAS to reduce bundle size and runtime ambiguity.

### 3. Native JUCE WaveMix stack

`native-juce/` is an independent C++20/JUCE CUDA implementation. It provides GUI/tray, CLI, and hidden background entry points and is also the GPU worker bundled with Stress Studio.

### 4. CPU-only tools

The original PyQt monitor and `cpu_stress_cli.py` remain useful independent tools. They are not compatibility shims for the Flutter app; each has a separate role and runtime model.

## Document status

- **Canonical:** this index, `DEVELOPMENT.md`, and `RELEASES.md` describe the current repository as a whole.
- **Product specification:** `FLUTTER_STRESS_STUDIO_SPEC.md` records the v0.1 baseline plus current implementation status and roadmap.
- **Subsystem guides:** GPU, packaging, JUCE, and P2200 files intentionally document one implementation in detail.
- **Release notes:** version-specific notes live under `docs/releases/` and can be applied to GitHub Releases by the maintenance workflow.

## Naming

The recommended repository name is **`Compute-Stress-Studio`** and the repository-facing product name is **Compute Stress Studio**. The Flutter application may still display the shorter **Stress Studio** name, while legacy executable, tag, and container identifiers remain documented where changing them would break existing downloads or automation.
