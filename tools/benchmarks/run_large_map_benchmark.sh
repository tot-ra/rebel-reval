#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
OUTPUT="${1:-$ROOT/build/benchmarks/large-map-baseline.json}"
MODE="${2:-}"
SCENE_OUTPUT="$(mktemp -t lower-town-scene-baseline).json"
trap 'rm -f "$SCENE_OUTPUT"' EXIT
mkdir -p "$(dirname "$OUTPUT")"

COMMON_ARGS=(--headless --path "$ROOT")
USER_ARGS=(--output="$SCENE_OUTPUT")
if [[ "$MODE" == "--quick" ]]; then
  USER_ARGS+=(--quick)
fi

# Both phases use ordinary scenes so project autoloads match production startup.
"$GODOT_BIN" "${COMMON_ARGS[@]}" \
  res://tools/benchmarks/lower_town_scene_benchmark.tscn \
  -- "${USER_ARGS[@]}"

RUNNER_ARGS=(--output="$OUTPUT" --scene-baseline="$SCENE_OUTPUT")
if [[ "$MODE" == "--quick" ]]; then
  RUNNER_ARGS+=(--quick)
fi
"$GODOT_BIN" "${COMMON_ARGS[@]}" \
  res://tools/benchmarks/large_map_benchmark.tscn \
  -- "${RUNNER_ARGS[@]}"

echo "Large-map benchmark written to $OUTPUT"
