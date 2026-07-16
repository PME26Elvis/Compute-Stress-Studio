# Release channels and artifact matrix

This is the canonical map of what the repository publishes. Subsystem guides explain implementation details; this file defines ownership, names, and publication policy.

## Release families

| Family | Primary audience | Tag convention | Main artifacts | Workflow |
| --- | --- | --- | --- | --- |
| Compute Stress Studio preview | one CPU+GPU desktop app | `compute-stress-studio-v*` | Windows ZIP, Linux tar, checksums | `flutter-stress-studio.yml` |
| Python GPU portable | adaptive telemetry-aware GPU stress without Python installation | `gpu-v*` | Windows ZIP, Linux tar, AppImage, Docker archive, GHCR image, checksums | `release-gpu-packages.yml` |
| Native JUCE WaveMix | independent native CUDA implementation | `juce-backup-v*` | Windows ZIP, Linux tar, AppImage, checksums | `release-juce-backup.yml` |
| Original CPU application | legacy Linux PyQt users | historical releases | original Linux CPU binary | historical/manual |

## Compute Stress Studio

### Current preview

Tag: `compute-stress-studio-v0.2.0`

```text
Compute-Stress-Studio-Windows-x64.zip
Compute-Stress-Studio-Linux-x64.tar.gz
SHA256SUMS.txt
```

Each extracted bundle contains:

```text
stress_studio[.exe]                  Flutter Material 3 control plane
Compute-Stress-CPU-Worker[.exe]      silent low-priority CPU process
GPU-Stress-JUCE-Background[.exe]     silent CUDA WaveMix GPU process
Flutter runtime libraries/data
README and architecture/release documents
SOURCE-COMMIT.txt
```

Do not move only `stress_studio.exe`. The Flutter runtime and both adjacent workers are required.

### Windows responsiveness fix

Preview 0.1 ran CPU hot loops in Dart isolates inside the Flutter process. Preview 0.2 moves CPU load into `Compute-Stress-CPU-Worker.exe`, a Windows GUI-subsystem process that lowers itself to Below Normal priority. The Flutter message pump and Stop action therefore do not share the stressed process.

### Legacy preview

`stress-studio-v0.1.14` remains available for provenance with the old archive names:

```text
Stress-Studio-Windows-x64.zip
Stress-Studio-Linux-x64.tar.gz
```

Users should prefer v0.2.0 or newer because v0.1 can become unresponsive under combined CPU+GPU load on some Windows systems.

### Publication policy

- pull requests: format, analyze, test both native workers, build Flutter, assemble archives; no Release;
- relevant pushes to `main`: repeat validation and archive assembly;
- explicit workflow dispatch: create or update a chosen release;
- versioned manifest under `release/compute-stress-studio/`: request one audited release together with a merged change;
- release-note corrections: use `release-notes-maintenance.yml` and a versioned file under `docs/releases/`.

A normal documentation-only commit does not publish a version.

## Python GPU portable family

Published names remain intentionally stable:

```text
GPU-Stress-Portable-Windows-x64.zip
GPU-Stress-Portable-Linux-x64.tar.gz
GPU-Stress-Portable-x86_64.AppImage
GPU-Stress-Docker-CUDA12-x86_64.tar.zst
GPU-Stress-Docker-IMAGE.txt
SHA256SUMS.txt
```

Future GHCR builds derive their image path from `PME26Elvis/Compute-Stress-Studio`. Images under the former `cpu-monitor-stress-tool-gpu` package path are a legacy channel and should not be removed until users have migrated.

## Native JUCE family

The JUCE implementation is both an independent fallback and the GPU worker embedded in Compute Stress Studio. Standalone package names retain the `GPU-Stress-JUCE-*` prefix because they identify a backend and entry point rather than the repository brand.

## Versioning guidance

- Use explicit semantic-like product tags.
- Put version-specific notes in `docs/releases/<tag>.md`.
- Name actual assets, requirements, important changes, limitations, and provenance.
- Replacing assets under an existing tag is exceptional and must be stated in the notes.
- Add a release-request JSON only when the same merge is intentionally meant to publish.

## Checksums and provenance

Every release family generates `SHA256SUMS.txt`. Compute Stress Studio bundles include `SOURCE-COMMIT.txt`. CI verifies the Flutter executable and both worker executables before archive creation and runs the CPU worker's silent self-test from the assembled bundle.

## Hardware validation boundary

GitHub-hosted runners validate source formatting, static analysis, Flutter tests, native tests, compilation, linking, archive composition, and non-GPU startup paths. They do not prove sustained utilization, temperature, fan, board power, clocks, or stability on the target NVIDIA GPU.
