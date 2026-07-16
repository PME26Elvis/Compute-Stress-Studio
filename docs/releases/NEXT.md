# Compute Stress Studio preview

Replace this template before dispatching the Flutter release workflow.

## Highlights

- Describe user-visible changes.
- Describe lifecycle, safety, or compatibility changes.
- Name new or changed presets and controls.

## Downloads

```text
Compute-Stress-Studio-Windows-x64.zip
Compute-Stress-Studio-Linux-x64.tar.gz
SHA256SUMS.txt
```

## Requirements

- Windows x64 or Linux x64.
- Compatible NVIDIA display driver for GPU sessions.
- Complete extracted bundle; do not separate the Flutter executable from its runtime files or bundled GPU worker.

## Load semantics and safety

State clearly that displayed percentages are requested workload targets rather than measured utilization or board-power percentage. Name any telemetry limitations and remind users to perform a short low-load hardware smoke test before sustained runs.

## Validation

List formatting, analysis, Flutter tests, lifecycle tests, native tests, platform builds, final bundle checks, and any physical hardware validation actually performed.

## Known limitations

- List limitations specific to this version.

## Source provenance

- Tag: replace before release.
- Source commit: supplied by the workflow bundle in `SOURCE-COMMIT.txt`.
