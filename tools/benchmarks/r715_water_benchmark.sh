#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
TIER="${1:-recommended}"
CONFIG="${R715_WATER_CONFIG:-$ROOT/tools/benchmarks/r715_water_benchmark_config.json}"
SAMPLES="${R715_WATER_SAMPLES:-120}"
OUTPUT="${2:-}"

case "$TIER" in
  minimum|recommended) ;;
  *)
    echo "Usage: $0 <minimum|recommended> [output.json]" >&2
    exit 2
    ;;
esac

if (( SAMPLES < 120 )); then
  echo "R715_WATER_SAMPLES must be at least 120" >&2
  exit 2
fi

if [[ -z "$OUTPUT" ]]; then
  OUTPUT="$ROOT/build/benchmarks/r715-water-$TIER.json"
fi
mkdir -p "$(dirname "$OUTPUT")"

ARGS=(--path "$ROOT")
if [[ "${R715_WATER_HEADLESS:-0}" == "1" ]]; then
  ARGS=(--headless "${ARGS[@]}")
fi

# A profile ID is asserted separately from detected architecture/GPU. The
# runner still compares all fields and marks mismatched/headless runs as
# supplementary, never as target acceptance.
"$GODOT_BIN" "${ARGS[@]}" \
  --script res://tools/benchmarks/r715_water_benchmark.gd -- \
  --config="$CONFIG" --tier="$TIER" --samples="$SAMPLES" --output="$OUTPUT"

python3 - "$OUTPUT" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    report = json.load(handle)
print(
    "R-715 {tier}: {status}; eligible={eligible}; samples={samples}; p95 delta={p95:.3f} ms".format(
        tier=report["tier"],
        status=report["status"],
        eligible=report["acceptance"]["eligible"],
        samples=report["samples"],
        p95=report["metrics"]["frame_time_ms_p95"],
    )
)
PY
