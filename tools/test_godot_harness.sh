#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
CHECKED_RUNNER="$ROOT/tools/run_godot_checked.sh"
FIXTURE="tests/godot/test_seeded_harness_error.gd"
FIXTURE_PATH="$ROOT/$FIXTURE"
FIXTURE_UID_PATH="${FIXTURE_PATH}.uid"
TMP_ROOT="$(mktemp -d -t godot-harness-self-test)"

cleanup() {
  rm -f "$FIXTURE_PATH" "$FIXTURE_UID_PATH"
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

run_expected_failure() {
  local name="$1"
  local expected="$2"
  shift 2
  local log_dir="$TMP_ROOT/$name"
  mkdir -p "$log_dir"

  if GODOT_LOG_DIR="$log_dir" "$CHECKED_RUNNER" "$name" "$@"; then
    echo "Seeded $name unexpectedly passed" >&2
    return 1
  fi
  if ! grep -Eiq "$expected" "$log_dir/$name.log"; then
    cat "$log_dir/$name.log" >&2
    echo "Seeded $name did not produce expected diagnostic: $expected" >&2
    return 1
  fi
}

cat > "$FIXTURE_PATH" <<'GDSCRIPT'
extends "res://tests/godot/test_case.gd"

func test_seeded_runtime_error() -> void:
	var value: Variant = null
	value.missing_method()
	fail("The runtime exception must interrupt this method before this line")
GDSCRIPT

run_expected_failure runtime-error 'SCRIPT ERROR|engine/script diagnostic' \
  "$GODOT_BIN" --headless --path "$ROOT" --script res://tools/run_godot_tests.gd -- --filter=test_seeded_harness_error
rm -f "$FIXTURE_PATH" "$FIXTURE_UID_PATH"

cat > "$FIXTURE_PATH" <<'GDSCRIPT'
extends "res://tests/godot/test_case.gd"

func test_seeded_parser_error() -> void:
	this is not valid gdscript
GDSCRIPT

run_expected_failure parser-error 'Parse Error|could not load script cleanly' \
  "$GODOT_BIN" --headless --path "$ROOT" --script res://tools/run_godot_tests.gd -- --filter=test_seeded_harness_error

echo "Godot harness self-test: runtime and parser diagnostics both fail as expected."
