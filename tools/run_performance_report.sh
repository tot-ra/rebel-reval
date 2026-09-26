#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="${1:-$ROOT/build/benchmarks/performance-report.json}"
MODE="${2:-}"

if [[ "$#" -gt 2 ]]; then
  echo "Usage: $0 [output.json] [--quick]" >&2
  exit 2
fi

if [[ -n "$MODE" && "$MODE" != "--quick" ]]; then
  echo "Usage: $0 [output.json] [--quick]" >&2
  exit 2
fi

"$ROOT/tools/benchmarks/run_large_map_benchmark.sh" "$OUTPUT" "$MODE"

# WB-07 (R-979): per-stage location-assembly timings and the staged frame trace,
# merged into the same report under "location_assembly".
GODOT_BIN="${GODOT_BIN:-godot}"
ASSEMBLY_OUTPUT="$(mktemp -t async-assembly).json"
trap 'rm -f "$ASSEMBLY_OUTPUT"' EXIT
ASSEMBLY_ARGS=(--output="$ASSEMBLY_OUTPUT")
if [[ "$MODE" == "--quick" ]]; then
  ASSEMBLY_ARGS+=(--quick)
fi
if [[ "${BENCHMARK_HEADLESS:-1}" != "0" ]]; then
  "$GODOT_BIN" --headless --path "$ROOT" --script res://tools/benchmarks/async_assembly_trace.gd -- "${ASSEMBLY_ARGS[@]}"
else
  command -v "$GODOT_BIN" >/dev/null 2>&1 && export GODOT_BIN || unset GODOT_BIN
  "$ROOT/tools/godot_render.sh" --script res://tools/benchmarks/async_assembly_trace.gd -- "${ASSEMBLY_ARGS[@]}"
fi
python3 - "$OUTPUT" "$ASSEMBLY_OUTPUT" <<'PY'
import json
import sys

report_path, assembly_path = sys.argv[1], sys.argv[2]
report = json.load(open(report_path, encoding="utf-8"))
report["location_assembly"] = json.load(open(assembly_path, encoding="utf-8"))
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
PY
