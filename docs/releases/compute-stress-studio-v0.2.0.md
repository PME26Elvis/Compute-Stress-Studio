# Compute Stress Studio preview 0.2.0

This release fixes the Windows UI responsiveness problem reported in the first Flutter preview and completes the repository rename to **Compute Stress Studio**. It supersedes `stress-studio-v0.1.14` for normal Windows use.

## Most important fix

The CPU workload no longer runs inside the Flutter process.

The first preview created one busy Dart isolate per selected CPU worker. Although isolates do not execute on Flutter's UI isolate, starting and sustaining a worker on every logical processor could starve the Windows message pump enough for the window to be marked **Not responding**.

Preview 0.2 introduces a dedicated native CPU worker:

- `Compute-Stress-CPU-Worker.exe` on Windows;
- `Compute-Stress-CPU-Worker` on Linux;
- a separate process from the Flutter window;
- Windows GUI subsystem, so it does not open a console window;
- Below Normal process priority on Windows;
- positive nice value on Linux;
- 50 ms duty windows with configurable load and thread count;
- immediate process termination through the existing Stop and application-close paths.

The bundled JUCE CUDA WaveMix worker remains a separate process. Flutter now acts strictly as the control plane for both workers, so the window and Stop button remain schedulable while stress is active.

## Safer defaults

Balanced, validation, quick-check, and endurance presets now reserve one logical processor by default when the machine has more than one. Users may still intentionally select the full logical processor count in the workload composer.

## Interface and diagnostics

- Product copy now consistently uses **Compute Stress Studio**.
- CPU controls describe worker threads rather than Dart isolates.
- Diagnostics show both bundled worker paths and readiness states.
- Settings explain the two-process execution boundary.

## Downloads

- `Compute-Stress-Studio-Windows-x64.zip`
- `Compute-Stress-Studio-Linux-x64.tar.gz`
- `SHA256SUMS.txt`

Extract the complete archive. Do not separate the Flutter executable from its `data`/library files or from the two adjacent worker executables.

## Requirements

### Windows

- Windows 10 or 11 x64
- compatible NVIDIA display driver for GPU sessions
- no Python, pip, Flutter SDK, JUCE SDK, or CUDA Toolkit installation required

### Linux

- x86-64 desktop with the Flutter/GTK runtime dependencies expected by the bundle
- compatible NVIDIA display driver for GPU sessions
- CPU-only sessions do not require an NVIDIA GPU

## Validation

GitHub Actions validates:

- native CPU parser, scheduling, early-stop latency, and silent package self-test;
- Flutter formatting, strict analysis, unit/controller/widget/lifecycle tests;
- Windows and Linux native CPU builds;
- Windows and Linux JUCE/CUDA builds and native tests;
- Windows and Linux Flutter release builds;
- presence and startup of both worker executables in the final bundles;
- coordinated cleanup when the Flutter application is removed.

GitHub-hosted runners do not provide the target Quadro P2200. Real GPU execution, power, clocks, cooling, and long-duration stability still require a short target-machine smoke test before an endurance run.

## Suggested first run

1. Extract the Windows ZIP completely.
2. Open `stress_studio.exe`.
3. Apply **Quick check**.
4. Start the session and confirm that the window remains interactive.
5. Press **Stop** and verify that CPU and GPU load return to idle.
6. Only then move to Balanced or 96-hour endurance presets.

Source commit provenance is included in each archive as `SOURCE-COMMIT.txt`.
