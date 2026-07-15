#!/usr/bin/env bash
set -euo pipefail

LOAD="${1:-80}"
DURATION="${2:-300}"
DEVICE="${3:-0}"
IMAGE="${GPU_STRESS_IMAGE:-ghcr.io/pme26elvis/cpu-monitor-stress-tool-gpu:latest}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
RESULTS_DIR="$REPO_ROOT/results"
mkdir -p "$RESULTS_DIR"

echo "Running GPU stress image $IMAGE on physical GPU $DEVICE"
docker run --rm \
  --gpus "device=$DEVICE" \
  --volume "$RESULTS_DIR:/results" \
  "$IMAGE" \
  --device 0 \
  --monitor-device 0 \
  --duration "$DURATION" \
  --load "$LOAD" \
  --csv /results/gpu-stress.csv
