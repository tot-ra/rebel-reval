#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
MODE="${1:-all}"

run_godot() {
  local name="$1"
  shift
  local log
  log="$(mktemp -t "map-pipeline-${name}").log"
  set +e
  "$@" 2>&1 | tee "$log"
  local status=${PIPESTATUS[0]}
  set -e
  if [[ "$status" -ne 0 ]] || grep -Eiq 'SCRIPT ERROR|Parse Error|Resource file not found|Failed loading resource|Can.t open file' "$log"; then
    echo "Map pipeline command failed: $name" >&2
    rm -f "$log"
    return 1
  fi
  rm -f "$log"
}

run_tests() {
  local filter="$1"
  run_godot "test-${filter}" "$GODOT_BIN" --headless --path "$ROOT" --script res://tools/run_godot_tests.gd -- --filter="$filter"
}

case "$MODE" in
  parser)
    run_tests map_rrmap_parser
    ;;
  compiler)
    run_tests map_blueprint_compiler
    run_tests map_blueprint_semantic_validation
    ;;
  audit)
    run_godot audit "$GODOT_BIN" --headless --path "$ROOT" --script res://tools/audit_map_blueprints.gd
    ;;
  parity)
    run_tests lower_town_slice_map
    run_tests map_pipeline_hardening
    ;;
  routes)
    run_tests lower_town_slice_map
    ;;
  persistence)
    run_tests map_stable_state_store
    ;;
  benchmark-smoke)
    "$ROOT/tools/benchmarks/run_large_map_benchmark.sh" \
      "$ROOT/build/benchmarks/large-map-ci-smoke.json" --quick
    ;;
  all)
    "$0" parser
    "$0" compiler
    "$0" audit
    "$0" persistence
    "$0" parity
    "$0" benchmark-smoke
    ;;
  *)
    echo "Usage: $0 {parser|compiler|audit|persistence|parity|routes|benchmark-smoke|all}" >&2
    exit 2
    ;;
esac
