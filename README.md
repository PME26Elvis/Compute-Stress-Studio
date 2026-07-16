# Compute Stress Studio

A multi-engine CPU and NVIDIA GPU stress-testing workspace with a modern Flutter desktop control plane, portable command-line tools, and an independent native CUDA fallback.

> Recommended future repository name: **`Compute-Stress-Studio`**. The current GitHub repository name remains unchanged until the owner performs the rename. Existing tags, executable names, and container image paths are preserved where changing them would break published artifacts or user automation.

## What should I use?

| Goal | Recommended entry point | Platforms | Notes |
| --- | --- | --- | --- |
| One desktop app for CPU + GPU | **Stress Studio** (`apps/stress_studio`) | Windows x64, Linux x64 | Flutter Material 3 UI; CPU isolates plus bundled JUCE CUDA worker |
| Adaptive NVIDIA GPU stress with telemetry | `gpu_stress_cli.py` | Windows, Linux | NVML feedback, duty fallback, thermal guard, CSV output |
| Portable NVIDIA package without Python/pip | GPU portable release assets | Windows x64, Linux x64 | CuPy/cuBLAS worker, AppImage, Docker/GHCR options |
| Independent native GPU fallback | `native-juce/` | Windows x64, Linux x64 | C++20/JUCE CUDA WaveMix; GUI, tray, CLI, and hidden mode |
| Original Linux CPU monitor | `main.py` | Linux | PyQt5 charts, CPU load, temperature, power, markers, CSV |
| Scriptable CPU-only stress | `cpu_stress_cli.py` | Python-supported hosts | Constant, pulsed, and ramp profiles |

## Flagship desktop app: Stress Studio

Stress Studio is the primary one-stop interface. Flutter owns the adaptive UI, validation, presets, session state, and lifecycle; workload execution stays outside the UI thread.

- responsive Material 3 desktop layouts with light, dark, and system themes;
- independent CPU and GPU enable switches, targets, duration, worker count, VRAM budget, and device index;
- coordinated start/stop with rollback if the GPU worker fails to start;
- CPU work in killable Dart isolates;
- NVIDIA GPU work in a bundled silent JUCE CUDA WaveMix process;
- quick, balanced, CPU, GPU, and 96-hour endurance presets;
- keyboard controls: **Ctrl+Enter** to start and **Escape** to stop;
- explicit application ownership so closing the desktop app stops active CPU and GPU workers.

The current preview release is [`stress-studio-v0.1.14`](https://github.com/PME26Elvis/CPU-Monitor-Stress-Tool/releases/tag/stress-studio-v0.1.14). Its published asset names remain:

```text
Stress-Studio-Windows-x64.zip
Stress-Studio-Linux-x64.tar.gz
SHA256SUMS.txt
```

Future releases use the product-facing `Compute-Stress-Studio-*` archive prefix while retaining the internal Flutter executable name `stress_studio` for compatibility.

## Load semantics and safety

This project creates sustained compute load. Start with a short, low-load run and monitor the machine before using long presets.

- A requested percentage is a **workload target**, not a guarantee of OS-reported utilization or board-power percentage.
- GPU utilization can include unrelated processes and varies with drivers, clocks, power limits, cooling, WDDM, and desktop activity.
- The Flutter/JUCE path intentionally does not poll physical telemetry. Use an external monitor for temperature, fan, power, clocks, and measured utilization.
- GitHub-hosted CI can compile CUDA code and validate packages, but cannot execute the real workload on the target NVIDIA GPU. A physical-machine smoke test remains required.
- Stop immediately if cooling, fan behavior, temperature, power delivery, or system stability looks abnormal.

## Repository map

```text
apps/stress_studio/      Flutter CPU+GPU desktop application
native-juce/             Native C++20/JUCE CUDA WaveMix implementation
packaging/               PyInstaller, AppImage, and launch-script assets
docs/                    Product, architecture, operation, and release docs
tests/                   Python GPU/packaging tests
cpu_stress_cli.py        Standalone CPU CLI
gpu_stress_cli.py        Adaptive multi-backend NVIDIA GPU CLI
main.py                  Original PyQt CPU monitor/stress GUI
```

## Build and test

### Flutter desktop app

```bash
cd apps/stress_studio
flutter create --platforms=windows,linux --org com.pme26elvis --project-name stress_studio .
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Build on the matching host OS:

```bash
flutter build windows --release
flutter build linux --release
```

The final distributable must also contain `GPU-Stress-JUCE-Background.exe` on Windows or `GPU-Stress-JUCE-Background` on Linux beside the Flutter executable. GitHub Actions performs that native build and bundle assembly.

### Python CLIs

```bash
python -m py_compile cpu_stress_cli.py gpu_stress_cli.py
python -m unittest discover -s tests -v
python cpu_stress_cli.py --duration 60 --load 75
python gpu_stress_cli.py --help
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

## Documentation

Start with the [documentation hub](docs/README.md).

- [Architecture and development](docs/DEVELOPMENT.md)
- [Release channels and artifact matrix](docs/RELEASES.md)
- [Flutter product and engineering specification](docs/FLUTTER_STRESS_STUDIO_SPEC.md)
- [Adaptive GPU CLI](docs/GPU_STRESS.md)
- [Python portable packaging](docs/PACKAGING.md)
- [JUCE WaveMix guide](docs/JUCE_WAVEMIX_BACKUP_GUIDE.md)
- [Quadro P2200 personal preset](docs/QUADRO_P2200_PERSONAL_PRESET.md)
- [Native JUCE implementation](native-juce/README.md)

## Release policy

Pull requests and relevant pushes run formatting, analysis, tests, native builds, Flutter builds, and bundle assembly. GitHub Releases are created or replaced only by an explicit workflow dispatch with a chosen tag, title, notes file, and prerelease setting. This prevents documentation-only commits from publishing accidental releases.

The Python portable and native JUCE subsystems keep their own release workflows and legacy artifact names. See [docs/RELEASES.md](docs/RELEASES.md) for the canonical matrix.

## License

Repository-authored code is licensed under the MIT License unless otherwise stated. Flutter dependencies, JUCE, CUDA components, and other third-party software retain their respective licenses; release bundles include the applicable notices.
