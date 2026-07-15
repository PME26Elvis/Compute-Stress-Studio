param(
    [ValidateRange(0, 100)][double]$Load = 87,
    [ValidateRange(1, 864000)][int]$Duration = 345600,
    [ValidateRange(0, 64)][int]$Device = 0,
    [string]$Image = "ghcr.io/pme26elvis/cpu-monitor-stress-tool-gpu:latest",
    [string]$CsvName = "gpu-stress.csv"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$results = Join-Path $repoRoot "results"
New-Item -ItemType Directory -Force -Path $results | Out-Null

Write-Host "Running GPU stress image $Image on physical GPU $Device"
Write-Host "Personal defaults: duration=$Duration seconds, load=$Load percent"
docker run --rm `
    --gpus "device=$Device" `
    --volume "${results}:/results" `
    $Image `
    --device 0 `
    --monitor-device 0 `
    --duration $Duration `
    --load $Load `
    --csv "/results/$CsvName"
