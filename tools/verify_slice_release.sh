#!/usr/bin/env bash
# P3-015: verify the tagged vertical-slice release contract and published save fixture.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

GODOT_BIN="${GODOT_BIN:-godot}"

python3 tools/build_slice_release_fixture.py >/dev/null
python3 tools/report_slice_release.py --check
python3 -m unittest tests.python.test_report_slice_release -v
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_vertical_slice_release
