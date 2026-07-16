# Release channels and artifact matrix

This is the canonical map of what the repository publishes. Subsystem guides may explain how an artifact is built, but this file defines which release family owns it.

## Release families

| Family | Primary audience | Tag convention | Main artifacts | Workflow |
| --- | --- | --- | --- | --- |
| Compute Stress Studio preview | users wanting one CPU+GPU desktop app | `stress-studio-v*` | Windows ZIP, Linux tar, checksums | `flutter-stress-studio.yml` |
| Python GPU portable | users wanting adaptive telemetry-aware GPU stress without installing Python | `gpu-v*` | Windows ZIP, Linux tar, AppImage, Docker archive, GHCR image, checksums | `release-gpu-packages.yml` |
| Native JUCE WaveMix | users wanting an independent native CUDA implementation | native JUCE release tags | Windows/Linux native packages and checksums | native JUCE release workflow |
| Original CPU application | legacy Linux PyQt users | historical releases | original Linux CPU binary | historical workflow/manual release |

## Compute Stress Studio

### Current published preview

Tag: `stress-studio-v0.1.14`

```text
Stress-Studio-Windows-x64.zip
Stress-Studio-Linux-x64.tar.gz
SHA256SUMS.txt
```

This release contains the Flutter desktop shell and the silent JUCE CUDA GPU worker in the same extracted directory. Do not copy only the Flutter executable; the adjacent Flutter runtime files, data directory, and GPU worker are part of the application.

### Future artifact names

New manually published releases use:

```text
Compute-Stress-Studio-Windows-x64.zip
Compute-Stress-Studio-Linux-x64.tar.gz
SHA256SUMS.txt
```

The internal Flutter executable remains `stress_studio.exe` on Windows and `stress_studio` on Linux for compatibility. The bundled GPU worker remains `GPU-Stress-JUCE-Background[.exe]`.

### Publication policy

- pull requests: format, analyze, test, build native worker, build Flutter, assemble artifacts; no GitHub Release;
- pushes to `main`: repeat validation and artifact assembly; no automatic GitHub Release;
- workflow dispatch: choose tag, title, notes file, and prerelease flag; create or update the release idempotently;
- release-note corrections: use `release-notes-maintenance.yml` with a versioned file under `docs/releases/`.

This policy prevents a README or workflow-only change from silently publishing a new prerelease.

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

The GHCR image name is derived from `GITHUB_REPOSITORY`. After the repository is renamed, future images will use the new repository-derived path. Existing images under the old `cpu-monitor-stress-tool-gpu` path should be treated as a legacy distribution channel and not deleted until users have migrated.

## Native JUCE family

The JUCE implementation is both:

1. an independently downloadable native fallback; and
2. the GPU worker embedded in Compute Stress Studio.

Standalone native package names may keep the `GPU-Stress-JUCE-*` prefix because they identify a backend/entry point rather than the repository brand. Compute Stress Studio archives wrap that worker with the Flutter application.

## Versioning guidance

- Product releases should use explicit semantic-like tags chosen by workflow dispatch rather than GitHub Actions run numbers as the only version signal.
- Version-specific release notes belong in `docs/releases/<tag>.md`.
- A release note must name the actual assets, requirements, important behavior changes, known limitations, and source commit or PR when relevant.
- Rebuilding an existing tag should be exceptional. The workflow supports updating a release for note corrections or intentionally replaced preview assets, but the release notes must say when assets were replaced.

## Checksums and provenance

Each release family generates `SHA256SUMS.txt`. Compute Stress Studio bundles also include `SOURCE-COMMIT.txt`, the product specification, the JUCE guide, and third-party notices. CI validates that both the Flutter executable and GPU worker are present before archive creation.

## Hardware validation boundary

GitHub-hosted runners do not expose the target NVIDIA GPU. CI proves source formatting, static analysis, unit/widget/native tests, compilation, linking, archive composition, and startup paths that do not require physical CUDA execution. It does not prove sustained utilization, temperature, fan, board power, clocks, or stability on a user's machine.
