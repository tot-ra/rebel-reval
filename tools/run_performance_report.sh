#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="${1:-$ROOT/build/benchmarks/performance-report.json}"
MODE="${2:-}"

if [[ -n "$MODE" && "$MODE" != "--quick" ]]; then
  echo "Usage: $0 [output.json] [--quick]" >&2
  exit 2
fi

"$ROOT/tools/benchmarks/run_large_map_benchmark.sh" "$OUTPUT" "$MODE"
