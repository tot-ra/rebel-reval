#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
OUTPUT="${1:-$ROOT/build/benchmarks/performance-report.json}"
MODE="${2:-}"
TARGET_HARDWARE="${TARGET_HARDWARE:-$ROOT/tools/benchmarks/target_hardware.json}"
SCENE_OUTPUT="$(mktemp -t lower-town-scene-baseline).json"
trap 'rm -f "$SCENE_OUTPUT"' EXIT
mkdir -p "$(dirname "$OUTPUT")"

# Windowed runs need a real GPU renderer; tools/godot_render.sh keeps the window minimized and
# unfocused so nothing pops up. Headless runs use the dummy renderer and open no window.
if [[ "${BENCHMARK_HEADLESS:-1}" != "0" ]]; then
  GODOT_RUN=("$GODOT_BIN" --headless --path "$ROOT")
else
  # The wrapper resolves GODOT_BIN, then `godot` on PATH, then Godot.app.
  command -v "$GODOT_BIN" >/dev/null 2>&1 && export GODOT_BIN || unset GODOT_BIN
  GODOT_RUN=("$ROOT/tools/godot_render.sh")
fi
USER_ARGS=(--output="$SCENE_OUTPUT")
if [[ "$MODE" == "--quick" ]]; then
  USER_ARGS+=(--quick)
fi

# Both phases use ordinary scenes so project autoloads match production startup.
"${GODOT_RUN[@]}" \
  res://tools/benchmarks/lower_town_scene_benchmark.tscn \
  -- "${USER_ARGS[@]}"

RUNNER_ARGS=(--output="$OUTPUT" --scene-baseline="$SCENE_OUTPUT" --target-hardware="$TARGET_HARDWARE")
if [[ "$MODE" == "--quick" ]]; then
  RUNNER_ARGS+=(--quick)
fi
"${GODOT_RUN[@]}" \
  res://tools/benchmarks/large_map_benchmark.tscn \
  -- "${RUNNER_ARGS[@]}"

echo "Performance report written to $OUTPUT"
python3 - "$OUTPUT" <<'PY'
import json
import sys

report = json.load(open(sys.argv[1], encoding="utf-8"))
target = report["target_hardware"]
headline = report["headline"]
print(
    "Target: {profile_id} ({status}); frame p95: {frame:.3f} ms; "
    "static memory: {memory} bytes; actor count: {actors}; "
    "bird audio peak: {bird_audio}; bird flight peak: {bird_flight}".format(
        profile_id=target["profile_id"],
        status=target["status"],
        frame=headline["frame_time_ms_p95"],
        memory=headline["memory_static_bytes"],
        actors=headline["actor_count"],
        bird_audio=headline.get("bird_audio_peak", 0),
        bird_flight=headline.get("bird_flight_peak", 0),
    )
)
PY
