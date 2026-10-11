#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
OUTPUT="${1:-$ROOT/build/benchmarks/performance-report.json}"
MODE="${2:-}"
TARGET_HARDWARE="${TARGET_HARDWARE:-$ROOT/tools/benchmarks/target_hardware.json}"
SCENE_DIR="$(mktemp -d -t scene-baseline)"
trap 'rm -rf "$SCENE_DIR"' EXIT
mkdir -p "$(dirname "$OUTPUT")"
# shellcheck source=tools/benchmarks/benchmark_guard.sh
source "$ROOT/tools/benchmarks/benchmark_guard.sh"

# R-1536: production scenes measured with project autoloads, as "<profile id>=<scene>".
# The continuous Reval city (ADR 0031) is the headline; Kalev's smithy is the
# forge interior New Game hands over from.
SCENES=(
  "reval_city_scene=res://scenes/world/reval_city/reval_city.tscn"
  "kalev_smithy_scene=res://scenes/reval_east/forge/forge.tscn"
)
PREFLIGHT=(res://tools/benchmarks/scene_benchmark.tscn res://tools/benchmarks/large_map_benchmark.tscn)
for entry in "${SCENES[@]}"; do
  PREFLIGHT+=("${entry#*=}")
done
benchmark_preflight "${PREFLIGHT[@]}"

# Windowed runs need a real GPU renderer; tools/godot_render.sh keeps the window minimized and
# unfocused so nothing pops up. Headless runs use the dummy renderer and open no window.
if [[ "${BENCHMARK_HEADLESS:-1}" != "0" ]]; then
  GODOT_RUN=("$GODOT_BIN" --headless --path "$ROOT")
else
  # The wrapper resolves GODOT_BIN, then `godot` on PATH, then Godot.app.
  command -v "$GODOT_BIN" >/dev/null 2>&1 && export GODOT_BIN || unset GODOT_BIN
  GODOT_RUN=("$ROOT/tools/godot_render.sh")
fi
# P0-142: compare renderers without editing project.godot. Only meaningful with
# BENCHMARK_HEADLESS=0 (headless always uses the dummy renderer).
if [[ -n "${BENCHMARK_RENDERING_METHOD:-}" ]]; then
  GODOT_RUN+=(--rendering-method "$BENCHMARK_RENDERING_METHOD")
  if [[ "$BENCHMARK_RENDERING_METHOD" == "gl_compatibility" ]]; then
    GODOT_RUN+=(--rendering-driver opengl3)
  else
    GODOT_RUN+=(--rendering-driver metal)
  fi
fi
QUICK_ARGS=()
if [[ "$MODE" == "--quick" ]]; then
  QUICK_ARGS=(--quick)
fi

# Both phases use ordinary scenes so project autoloads match production startup.
RUNNER_ARGS=(--output="$OUTPUT" --target-hardware="$TARGET_HARDWARE")
for entry in "${SCENES[@]}"; do
  profile="${entry%%=*}"
  scene_output="$SCENE_DIR/$profile.json"
  echo "Scene phase: $profile (${entry#*=})"
  benchmark_run "${GODOT_RUN[@]}" \
    res://tools/benchmarks/scene_benchmark.tscn \
    -- --scene="${entry#*=}" --profile-id="$profile" --output="$scene_output" \
    ${QUICK_ARGS[@]+"${QUICK_ARGS[@]}"}
  if [[ ! -s "$scene_output" ]]; then
    echo "Scene phase $profile wrote no baseline: $scene_output" >&2
    exit 1
  fi
  RUNNER_ARGS+=(--scene-baseline="$scene_output")
done
if [[ "$MODE" == "--quick" ]]; then
  RUNNER_ARGS+=(--quick)
fi
benchmark_run "${GODOT_RUN[@]}" \
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
    "Target: {profile_id} ({status}); renderer: {renderer}; {scene} frame p95: {frame:.3f} ms; "
    "static memory: {memory} bytes; actor count: {actors}; "
    "bird audio peak: {bird_audio}; bird flight peak: {bird_flight}".format(
        profile_id=target["profile_id"],
        status=target["status"],
        renderer=report["measurement_host"].get("rendering_method", "?"),
        scene=headline["profile_id"],
        frame=headline["frame_time_ms_p95"],
        memory=headline["memory_static_bytes"],
        actors=headline["actor_count"],
        bird_audio=headline.get("bird_audio_peak", 0),
        bird_flight=headline.get("bird_flight_peak", 0),
    )
)
PY
