#!/usr/bin/env bash
# P3-016: verify the vertical-slice end-to-end traversal and save compatibility suite.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

GODOT_BIN="${GODOT_BIN:-godot}"

python3 tools/report_slice_traversal.py --check
python3 tools/report_slice_release.py --check
python3 tools/report_slice_platform.py --check
python3 tools/report_slice_e2e.py --check
python3 -m unittest tests.python.test_report_slice_e2e -v

for filter_name in \
	test_vertical_slice_traversal \
	test_vertical_slice_flow \
	test_vertical_slice_save_matrix \
	test_vertical_slice_release \
	test_save_envelope \
	test_vertical_slice_e2e; do
	"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- "--filter=${filter_name}"
done
