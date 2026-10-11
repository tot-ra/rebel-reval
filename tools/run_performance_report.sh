#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="${1:-$ROOT/build/benchmarks/performance-report.json}"
MODE="${2:-}"

if [[ "$#" -gt 2 ]]; then
  echo "Usage: $0 [output.json] [--quick|--vegetation]" >&2
  exit 2
fi

if [[ -n "$MODE" && "$MODE" != "--quick" && "$MODE" != "--vegetation" ]]; then
  echo "Usage: $0 [output.json] [--quick|--vegetation]" >&2
  exit 2
fi
# shellcheck source=tools/benchmarks/benchmark_guard.sh
source "$ROOT/tools/benchmarks/benchmark_guard.sh"

# R-1320 (VEGR-0): per-layer vegetation benchmark over the fixed camera set. It
# needs a real renderer (the dummy renderer drops MultiMesh transforms), so it
# always runs through godot_render.sh (minimized window). A separate report:
# the default and --quick contracts above are unchanged.
# VEGETATION_LAYER_TIMING=0 skips the per-layer frame-time pass (counts only).
if [[ "$MODE" == "--vegetation" ]]; then
  benchmark_preflight res://tools/capture_vegetation_benchmark.gd
  mkdir -p "$(dirname "$OUTPUT")"
  OUTPUT_ABS="$(cd "$(dirname "$OUTPUT")" && pwd)/$(basename "$OUTPUT")"
  # A stale report from an earlier run must not pass for this one.
  rm -f "$OUTPUT_ABS"
  VEGETATION_ARGS=(--output="$OUTPUT_ABS")
  if [[ "${VEGETATION_LAYER_TIMING:-1}" != "0" ]]; then
    VEGETATION_ARGS+=(--layer-timing)
  fi
  benchmark_run "$ROOT/tools/godot_render.sh" --resolution 1920x1080 --disable-vsync \
    --script res://tools/capture_vegetation_benchmark.gd -- "${VEGETATION_ARGS[@]}"
  if [[ ! -s "$OUTPUT_ABS" ]]; then
    echo "Vegetation benchmark wrote no report: $OUTPUT_ABS" >&2
    exit 1
  fi
  python3 "$ROOT/tools/vegetation_performance.py" summary "$OUTPUT_ABS"
  exit 0
fi

benchmark_preflight res://tools/benchmarks/async_assembly_trace.gd res://tools/benchmarks/renderer_frame_time.gd

"$ROOT/tools/benchmarks/run_large_map_benchmark.sh" "$OUTPUT" "$MODE"

# WB-07 (R-979): per-stage location-assembly timings and the staged frame trace,
# merged into the same report under "location_assembly".
GODOT_BIN="${GODOT_BIN:-godot}"
ASSEMBLY_OUTPUT="$(mktemp -t async-assembly).json"
FRAME_TIME_OUTPUT="$(mktemp -t renderer-frame-time).json"
trap 'rm -f "$ASSEMBLY_OUTPUT" "$FRAME_TIME_OUTPUT"' EXIT
# mktemp creates the files; an empty file means the phase did not run.
: > "$FRAME_TIME_OUTPUT"
ASSEMBLY_ARGS=(--output="$ASSEMBLY_OUTPUT")
if [[ "$MODE" == "--quick" ]]; then
  ASSEMBLY_ARGS+=(--quick)
fi
if [[ "${BENCHMARK_HEADLESS:-1}" != "0" ]]; then
  benchmark_run "$GODOT_BIN" --headless --path "$ROOT" --script res://tools/benchmarks/async_assembly_trace.gd -- "${ASSEMBLY_ARGS[@]}"
else
  command -v "$GODOT_BIN" >/dev/null 2>&1 && export GODOT_BIN || unset GODOT_BIN
  RENDER_ARGS=()
  # P0-142: same renderer override as tools/benchmarks/run_large_map_benchmark.sh.
  if [[ -n "${BENCHMARK_RENDERING_METHOD:-}" ]]; then
    RENDER_ARGS=(--rendering-method "$BENCHMARK_RENDERING_METHOD" --rendering-driver)
    [[ "$BENCHMARK_RENDERING_METHOD" == "gl_compatibility" ]] && RENDER_ARGS+=(opengl3) || RENDER_ARGS+=(metal)
  fi
  benchmark_run "$ROOT/tools/godot_render.sh" ${RENDER_ARGS[@]+"${RENDER_ARGS[@]}"} --script res://tools/benchmarks/async_assembly_trace.gd -- "${ASSEMBLY_ARGS[@]}"
  # R-1536 / P0-142: rendered frame time on fixed city and Kalev smithy shots
  # (vsync off, 1920x1080), merged under "renderer_frame_time". Windowed only:
  # headless frames are dummy-renderer instrumentation, not rendered cost.
  FRAME_ARGS=(--output="$FRAME_TIME_OUTPUT")
  if [[ "$MODE" == "--quick" ]]; then
    FRAME_ARGS+=(--frames=30)
  fi
  benchmark_run "$ROOT/tools/godot_render.sh" ${RENDER_ARGS[@]+"${RENDER_ARGS[@]}"} \
    --resolution 1920x1080 --disable-vsync \
    --script res://tools/benchmarks/renderer_frame_time.gd -- "${FRAME_ARGS[@]}"
  if [[ ! -s "$FRAME_TIME_OUTPUT" ]]; then
    echo "Renderer frame-time phase wrote no report: $FRAME_TIME_OUTPUT" >&2
    exit 1
  fi
fi
python3 - "$OUTPUT" "$ASSEMBLY_OUTPUT" "$FRAME_TIME_OUTPUT" <<'PY'
import json
import os
import sys

report_path, assembly_path, frame_time_path = sys.argv[1], sys.argv[2], sys.argv[3]
report = json.load(open(report_path, encoding="utf-8"))
report["location_assembly"] = json.load(open(assembly_path, encoding="utf-8"))
if os.path.getsize(frame_time_path) > 0:
    report["renderer_frame_time"] = json.load(open(frame_time_path, encoding="utf-8"))
with open(report_path, "w", encoding="utf-8") as handle:
    json.dump(report, handle, indent=2)
    handle.write("\n")
for entry in report["location_assembly"]["maps"]:
    staged = entry["staged"]
    print(
        "Assembly {map_id}: sync {sync:.1f} ms; staged {frames} frames, max frame {max_frame:.1f} ms, "
        "{over} unit(s) over the {budget} ms budget".format(
            map_id=entry["map_id"],
            sync=entry["synchronous"]["total_ms"],
            frames=staged["frames"],
            max_frame=staged["max_frame_ms"],
            over=len(staged["units_over_budget"]),
            budget=report["location_assembly"]["budget_ms"],
        )
    )
frame_time = report.get("renderer_frame_time")
if frame_time:
    print(
        "Rendered frame time ({method}, {driver}): median shot {median:.2f} ms "
        "({fps:.0f} FPS), worst shot {worst:.2f} ms".format(
            method=frame_time["rendering_method"],
            driver=frame_time["rendering_driver"],
            median=frame_time["frame_ms_median_of_shots"],
            fps=frame_time["fps_median_of_shots"],
            worst=frame_time["frame_ms_worst_shot"],
        )
    )
PY
