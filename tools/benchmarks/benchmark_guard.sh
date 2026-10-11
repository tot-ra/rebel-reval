# shellcheck shell=bash
# Shared fail-fast guards for the benchmark wrappers (R-1536). Source it:
#   source "$ROOT/tools/benchmarks/benchmark_guard.sh"
#
# Why: a benchmark whose scene or preload target was retired never calls quit()
# and the headless Godot process idles forever (orphaned processes piled up
# after tools/run_performance_report.sh runs). benchmark_preflight rejects a
# missing res:// dependency before Godot starts; benchmark_run kills any phase
# that outlives BENCHMARK_TIMEOUT_SEC (default 900 s) and fails the run.

benchmark_preflight() {
  python3 "$ROOT/tools/benchmarks/benchmark_preflight.py" "$@"
}

# benchmark_run <command...>: runs the command with a wall-clock limit. Returns
# the command's exit code, or 124 after a timeout. The command's direct children
# are killed too: tools/godot_render.sh runs Godot as a child process.
benchmark_run() {
  local limit="${BENCHMARK_TIMEOUT_SEC:-900}"
  local waited=0 pid status
  "$@" &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    if (( waited >= limit )); then
      echo "benchmark: timed out after ${limit}s: $*" >&2
      pkill -TERM -P "$pid" 2>/dev/null || true
      kill -TERM "$pid" 2>/dev/null || true
      sleep 3
      pkill -KILL -P "$pid" 2>/dev/null || true
      kill -KILL "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      return 124
    fi
    sleep 1
    waited=$((waited + 1))
  done
  status=0
  wait "$pid" || status=$?
  return "$status"
}
