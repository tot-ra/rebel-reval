#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
OUTPUT_DIR="${1:-$ROOT/build/benchmarks}"
MODE="${2:-}"
EVIDENCE_JSON="$OUTPUT_DIR/renderer_evaluation_evidence.json"
CAPTURE_DIR="$ROOT/docs/reports/images/renderer_evaluation"
mkdir -p "$OUTPUT_DIR" "$CAPTURE_DIR"

COMMON_ARGS=(--path "$ROOT")
if [[ "${BENCHMARK_HEADLESS:-1}" != "0" ]]; then
  COMMON_ARGS=(--headless "${COMMON_ARGS[@]}")
fi

USER_ARGS=(--quick)
if [[ "$MODE" != "--quick" ]]; then
  USER_ARGS=()
fi

RENDERERS=(gl_compatibility mobile forward_plus)
PROFILE_JSON="$ROOT/tools/benchmarks/target_hardware.json"
RECORDED_UTC="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
GIT_COMMIT="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"

RESULTS=()
for renderer in "${RENDERERS[@]}"; do
  RUN_OUTPUT="$(mktemp -t renderer-comparison-${renderer}).json"
  CAPTURE_PATH="res://docs/reports/images/renderer_evaluation/${renderer}_lower_town_day.png"
  ARGS=(--rendering-method "$renderer" "${COMMON_ARGS[@]}" \
    res://tools/benchmarks/renderer_comparison_benchmark.tscn -- \
    --output="$RUN_OUTPUT" --capture="$CAPTURE_PATH" --renderer-requested="$renderer")
  ARGS+=("${USER_ARGS[@]}")
  echo "Running renderer comparison for $renderer ..."
  "$GODOT_BIN" "${ARGS[@]}"
  RESULTS+=("$(cat "$RUN_OUTPUT")")
  rm -f "$RUN_OUTPUT"
done

python3 - "$EVIDENCE_JSON" "$PROFILE_JSON" "$RECORDED_UTC" "$GIT_COMMIT" "${RESULTS[@]}" <<'PY'
import json
import sys
from pathlib import Path

output_path = Path(sys.argv[1])
profile_path = Path(sys.argv[2])
recorded_utc = sys.argv[3]
git_commit = sys.argv[4]
renderer_payloads = [json.loads(chunk) for chunk in sys.argv[5:]]

profile = json.loads(profile_path.read_text(encoding="utf-8"))
evidence = {
    "schema_version": 1,
    "task_id": "P0-142",
    "recorded_utc": recorded_utc,
    "git_commit": git_commit,
    "target_hardware": profile,
    "measurement_host": {
        "headless": renderer_payloads[0].get("headless", True),
        "display_driver": renderer_payloads[0].get("display_driver", "unknown"),
    },
    "renderers": renderer_payloads,
    "export_support": {
        "macos_rr_preset": {
            "renderer": "gl_compatibility",
            "status": "supported",
            "note": "export_presets.cfg rr preset ships today on universal macOS",
        },
        "web_html5": {
            "renderer": "gl_compatibility",
            "status": "supported_with_caveats",
            "note": "Godot 4 web export targets Compatibility GL; Forward+ is not a browser export path",
        },
        "forward_plus_desktop": {
            "renderer": "forward_plus",
            "status": "requires_new_preset",
            "note": "no Forward+ export preset exists yet; spike only",
        },
    },
    "recommendation": {
        "stay_on": "gl_compatibility",
        "follow_up_task": "P0-157",
        "rationale": "Compatibility keeps the shipped macOS preset and web path viable while P0-141 post-grade already delivers glow; Forward+ gains are deferred until minimum-hardware GPU capture and P0-157 decal path land.",
    },
}
output_path.write_text(json.dumps(evidence, indent=2) + "\n", encoding="utf-8")
print(f"Wrote {output_path}")
PY

python3 "$ROOT/tools/generate_renderer_evaluation_report.py" \
  --evidence "$EVIDENCE_JSON" \
  --write

echo "Renderer evaluation evidence written to $EVIDENCE_JSON"
