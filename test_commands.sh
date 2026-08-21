#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLAYABLE_SCENE="$ROOT_DIR/scenes/reval_east/reval_east.tscn"
cd "$ROOT_DIR"

if [[ -n "${GODOT_BIN:-}" ]]; then
  if [[ ! -x "$GODOT_BIN" ]]; then
    echo "GODOT_BIN is not an executable Godot binary: $GODOT_BIN" >&2
    exit 1
  fi
  GODOT="$GODOT_BIN"
elif command -v godot >/dev/null 2>&1; then
  GODOT="$(command -v godot)"
elif [[ -x /Applications/Godot.app/Contents/MacOS/Godot ]]; then
  GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
else
  echo "Godot 4.7 was not found. Set GODOT_BIN to the Godot executable." >&2
  exit 1
fi

if [[ ! -f "$PLAYABLE_SCENE" ]]; then
  echo "Playable-room smoke scene was not found: $PLAYABLE_SCENE" >&2
  exit 1
fi

"$GODOT" --headless --path "$ROOT_DIR" --editor --quit
# `--check-only` is non-terminating for this project (DEF-001); use the documented playable-room smoke instead.
"$GODOT" --headless --path "$ROOT_DIR" --quit-after 5 "$PLAYABLE_SCENE"
mkdir -p build && "$GODOT" --headless --path "$ROOT_DIR" --export-release "rr" build/rr.dmg
python3 tools/generate_active_docs_report.py
python3 tools/generate_active_docs_report.py --check
"$GODOT" --headless --path "$ROOT_DIR" -s tools/verify_transitions.gd
"$GODOT" --headless --path "$ROOT_DIR" --script tools/validate_map_blueprints.gd

# Compact/chunked map production gates (run individually or use `all`).
tools/run_map_pipeline_ci.sh parser
tools/run_map_pipeline_ci.sh compiler
tools/run_map_pipeline_ci.sh audit
tools/run_map_pipeline_ci.sh persistence
tools/run_map_pipeline_ci.sh parity
tools/run_map_pipeline_ci.sh routes
tools/run_map_pipeline_ci.sh benchmark-smoke
tools/run_performance_report.sh build/benchmarks/performance-report.json
