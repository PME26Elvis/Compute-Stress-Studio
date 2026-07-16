# Compute Stress Studio

A multi-engine CPU and NVIDIA GPU stress-testing workspace built around a modern Flutter desktop control plane, two isolated native worker processes, portable command-line tools, and independent fallback implementations.

## Recommended download

The primary app is **Compute Stress Studio** for Windows x64 and Linux x64.

Latest Flutter preview:

- [`compute-stress-studio-v0.2.0`](https://github.com/PME26Elvis/Compute-Stress-Studio/releases/tag/compute-stress-studio-v0.2.0)
- `Compute-Stress-Studio-Windows-x64.zip`
- `Compute-Stress-Studio-Linux-x64.tar.gz`
- `SHA256SUMS.txt`

Extract the complete archive and keep the Flutter executable, its libraries/data, and both worker executables together.

## What should I use?

| Goal | Recommended entry point | Platforms | Notes |
| --- | --- | --- | --- |
| One desktop app for CPU + GPU | **Compute Stress Studio** (`apps/stress_studio`) | Windows x64, Linux x64 | Flutter Material 3 UI controlling isolated CPU and JUCE CUDA workers |
| Adaptive NVIDIA GPU stress with telemetry | `gpu_stress_cli.py` | Windows, Linux | NVML feedback, duty fallback, thermal guard, CSV output |
| Portable NVIDIA package without Python/pip | Python GPU portable assets | Windows x64, Linux x64 | CuPy/cuBLAS worker, AppImage, Docker/GHCR options |
| Independent native GPU fallback | `native-juce/` | Windows x64, Linux x64 | C++20/JUCE CUDA WaveMix; GUI, tray, CLI, and hidden mode |
| Original Linux CPU monitor | `main.py` | Linux | PyQt5 charts, CPU load, temperature, power, markers, CSV |
| Scriptable CPU-only stress | `cpu_stress_cli.py` | Python-supported hosts | Constant, pulsed, and ramp profiles |

## Flagship architecture

Flutter is intentionally only the control plane. It owns adaptive layout, presets, validation, session state, rollback, history, keyboard actions, and lifecycle cleanup. Hot loops stay outside the Flutter process:

```text
Compute Stress Studio (Flutter / Material 3)
             |
       StudioController
        /           \
Compute-Stress-   GPU-Stress-JUCE-
CPU-Worker        Background
(low priority)    (CUDA WaveMix)
```

- CPU work runs in `Compute-Stress-CPU-Worker.exe` on Windows or `Compute-Stress-CPU-Worker` on Linux.
- The Windows CPU worker uses the GUI subsystem and opens no console window.
- The CPU worker lowers its own process priority so the window and Stop action remain responsive.
- Presets reserve one logical processor by default on machines with more than one processor.
- GPU work remains in the silent JUCE CUDA WaveMix worker.
- Starting CPU and GPU is transactional: a worker startup failure rolls back the other workload.
- Closing the Flutter application stops both child processes.

The v0.2 architecture replaces the first preview's in-process Dart isolate pool after a Windows responsiveness report.

## Desktop experience

- responsive Material 3 layouts with light, dark, and system themes;
- independent CPU and GPU enable switches;
- duration, load target, CPU thread count, VRAM budget, and GPU device controls;
- Quick check, Balanced, CPU validation, GPU validation, and 96-hour endurance presets;
- **Ctrl+Enter** to start and **Escape** to stop;
- Diagnostics page showing both bundled worker paths and readiness;
- bounded in-memory session history;
- no recurring `nvidia-smi` polling or telemetry-file output in the Flutter/JUCE path.

## First-run checklist

1. Extract the complete Windows ZIP.
2. Start `stress_studio.exe`.
3. Open **Diagnostics** and confirm both worker entries are ready.
4. Apply **Quick check**.
5. Start and verify that the window remains interactive.
6. Press **Stop** and confirm the external monitoring tool returns to idle.
7. Only then use heavier or longer presets.

## Load semantics and safety

This project creates sustained compute load. Start short and low, then increase gradually.

- A requested percentage is a workload target, not a guarantee of OS-reported utilization or board-power percentage.
- GPU utilization can include unrelated processes and varies with drivers, clocks, power limits, cooling, WDDM, and desktop activity.
- The Flutter/JUCE path intentionally does not poll physical telemetry. Use an external monitor for temperature, fan, power, clocks, and measured utilization.
- GitHub-hosted CI compiles CUDA and validates packages but cannot execute the real workload on the target NVIDIA GPU.
- Stop immediately if cooling, fan behavior, temperature, power delivery, or system stability looks abnormal.

## Repository map

```text
apps/stress_studio/      Flutter CPU+GPU desktop application
native-cpu/              Silent low-priority CPU worker and native tests
native-juce/             C++20/JUCE CUDA WaveMix implementation
packaging/               Python portable, AppImage, and launch-script assets
docs/                    Product, architecture, operation, and release docs
release/                  Explicit release-request manifests
tests/                   Python GPU/packaging tests
cpu_stress_cli.py        Standalone CPU CLI
gpu_stress_cli.py        Adaptive multi-backend NVIDIA GPU CLI
main.py                  Original PyQt CPU monitor/stress GUI
```

## Build and test

### Flutter quality

```bash
cd apps/stress_studio
flutter create --platforms=windows,linux --org com.pme26elvis --project-name stress_studio .
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

### Native CPU worker

```bash
cmake -S native-cpu -B build/cpu-worker -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build/cpu-worker
ctest --test-dir build/cpu-worker --output-on-failure
```

### Native JUCE core tests

```bash
cmake -S native-juce -B build/juce-core \
  -DGPU_STRESS_ENABLE_CUDA=OFF \
  -DGPU_STRESS_BUILD_GUI=OFF \
  -DGPU_STRESS_BUILD_TESTS=ON
cmake --build build/juce-core
ctest --test-dir build/juce-core --output-on-failure
```

GitHub Actions performs the complete Windows/Linux Flutter builds, native CPU builds, JUCE/CUDA builds, tests, worker injection, archive assembly, and checksums.

## Documentation

Start with the [documentation hub](docs/README.md).

- [Architecture and development](docs/DEVELOPMENT.md)
- [Release channels and artifact matrix](docs/RELEASES.md)
- [Flutter product and engineering specification](docs/FLUTTER_STRESS_STUDIO_SPEC.md)
- [Adaptive GPU CLI](docs/GPU_STRESS.md)
- [Python portable packaging](docs/PACKAGING.md)
- [JUCE WaveMix guide](docs/JUCE_WAVEMIX_BACKUP_GUIDE.md)
- [Quadro P2200 personal preset](docs/QUADRO_P2200_PERSONAL_PRESET.md)

## Release policy

Relevant pushes and pull requests run validation and package assembly. A GitHub Release is created only by an explicit workflow dispatch or by adding a versioned manifest under `release/compute-stress-studio/`. This keeps documentation-only changes from publishing accidental versions while allowing an auditable release request to ship together with a fix.

Python portable and native JUCE subsystems retain their own release families and compatibility asset names. See [docs/RELEASES.md](docs/RELEASES.md).

## License

Repository-authored code is licensed under the MIT License unless otherwise stated. Flutter dependencies, JUCE, CUDA components, and other third-party software retain their respective licenses; release bundles include the applicable notices.
