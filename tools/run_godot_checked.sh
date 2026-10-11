#!/usr/bin/env bash
set -euo pipefail

# Keep this allowlist limited to documented shutdown-only DEF-002 diagnostics.
# Leak warnings remain visible but are not errors; every other Godot
# ERROR/SCRIPT ERROR is release-blocking.
# Matches (anchored full lines):
# - "N resources still in use at exit ..."
# - "N RID allocations of type '...' were leaked at exit."
# - "Pages in use exist at exit in PagedAllocator: ..."
readonly DEF_002_ERROR='^[[:space:]]*ERROR: ([0-9]+ resources still in use at exit \(run with --verbose for details\)\.|[0-9]+ RID allocations of type .+ were leaked at exit\.|Pages in use exist at exit in PagedAllocator: .+)$'
readonly FAILURE_PATTERN='SCRIPT ERROR|Parse Error|^[[:space:]]*ERROR:|Resource file not found|Failed loading resource|Can.t open file'
readonly CLEAN_TEST_SUMMARY='Godot headless tests: [0-9]+ file\(s\), [1-9][0-9]* test\(s\), 0 failure\(s\), 0 error\(s\)\.'

require_test_summary=false
if [[ "${1:-}" == "--require-test-summary" ]]; then
  require_test_summary=true
  shift
fi

if [[ "$#" -lt 2 ]]; then
  echo "Usage: $0 [--require-test-summary] <log-name> [--] <godot-command> [args...]" >&2
  exit 2
fi

name="$1"
shift
if [[ "${1:-}" == "--" ]]; then
  shift
fi
if [[ "$#" -eq 0 ]]; then
  echo "Godot command is required" >&2
  exit 2
fi

log_dir="${GODOT_LOG_DIR:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}}"
mkdir -p "$log_dir"
log="$log_dir/${name}.log"

set +e
"$@" 2>&1 | tee "$log"
status=${PIPESTATUS[0]}
set -e

if [[ "$status" -ne 0 ]]; then
  echo "Godot command failed with status $status: $*" >&2
  exit "$status"
fi

unexpected_log="${log}.unexpected"
grep -Ev "$DEF_002_ERROR" "$log" > "$unexpected_log" || true
if grep -Eiq "$FAILURE_PATTERN" "$unexpected_log"; then
  echo "Godot log contains an unexpected engine, script, parser, or resource error: $log" >&2
  grep -Ein "$FAILURE_PATTERN" "$unexpected_log" >&2 || true
  rm -f "$unexpected_log"
  exit 1
fi
rm -f "$unexpected_log"

if [[ "$require_test_summary" == true ]] && ! grep -Eq "$CLEAN_TEST_SUMMARY" "$log"; then
  echo "Godot test log has no clean, non-empty final summary: $log" >&2
  exit 1
fi
