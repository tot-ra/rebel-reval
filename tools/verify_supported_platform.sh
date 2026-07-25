#!/usr/bin/env bash
# P3-012: export the macOS release build and prove install/start/save/load/exit
# inside the packaged app without editor path overrides.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
DMG_PATH="$BUILD_DIR/rr.dmg"
APP_PATH="$BUILD_DIR/Reval Rebel.app"
MOUNT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/reval-rebel-p3-012.XXXXXX")"
LAUNCH_LOG="$(mktemp "${TMPDIR:-/tmp}/reval-rebel-p3-012-launch.XXXXXX")"
PRESERVE_LOG=0
TIMEOUT_SENTINEL="$(mktemp "${TMPDIR:-/tmp}/reval-rebel-p3-012-timeout.XXXXXX")"
SKIP_EXPORT="${SKIP_EXPORT:-0}"
APP_PID=""
WATCHDOG_PID=""
readonly PASS_MARKER="P3-012_PACKAGED_PLATFORM_PASS"
readonly FAIL_MARKER="P3-012_PACKAGED_PLATFORM_FAIL"
readonly SMOKE_TIMEOUT_SECONDS=90
readonly DEF_002_ERROR='^[[:space:]]*ERROR: ([0-9]+ resources still in use at exit \(run with --verbose for details\)\.|[0-9]+ RID allocations of type .+ were leaked at exit\.|Pages in use exist at exit in PagedAllocator: .+)$'
readonly FAILURE_PATTERN='SCRIPT ERROR|Parse Error|^[[:space:]]*ERROR:|Resource file not found|Failed loading resource|Can.t open file'

if [[ -n "${GODOT_BIN:-}" ]]; then
  GODOT="$GODOT_BIN"
elif command -v godot >/dev/null 2>&1; then
  GODOT="$(command -v godot)"
elif [[ -x /Applications/Godot.app/Contents/MacOS/Godot ]]; then
  GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
else
  echo "Godot 4.7 was not found. Set GODOT_BIN to the Godot executable." >&2
  exit 1
fi

cleanup() {
  if [[ -n "$WATCHDOG_PID" ]]; then
    kill "$WATCHDOG_PID" 2>/dev/null || true
  fi
  if [[ -n "$APP_PID" ]]; then
    kill "$APP_PID" 2>/dev/null || true
  fi
  hdiutil detach "$MOUNT_DIR" -quiet 2>/dev/null || true
  rmdir "$MOUNT_DIR" 2>/dev/null || true
  if [[ "$PRESERVE_LOG" == "1" ]]; then
    echo "Packaged platform smoke log preserved at: $LAUNCH_LOG" >&2
  else
    rm -f "$LAUNCH_LOG" "$LAUNCH_LOG.unexpected"
  fi
  rm -f "$TIMEOUT_SENTINEL"
}
trap cleanup EXIT

cd "$ROOT_DIR"
mkdir -p "$BUILD_DIR"
rm -f "$TIMEOUT_SENTINEL"

echo "==> P3-012 repository-side platform contract"
python3 tools/report_slice_platform.py --check
python3 -m unittest tests.python.test_report_slice_platform -v

echo "==> P3-012 packaged platform smoke entrypoint contract"
tools/run_godot_checked.sh --require-test-summary p3-012-entrypoint \
  "$GODOT" --headless --path "$ROOT_DIR" --script tools/run_godot_tests.gd -- \
  --filter=test_packaged_platform_smoke

if [[ "$SKIP_EXPORT" != "1" ]]; then
  echo "==> Exporting macOS release preset rr -> $DMG_PATH"
  "$GODOT" --headless --path "$ROOT_DIR" --export-release "rr" "$DMG_PATH"
fi

if [[ ! -s "$DMG_PATH" ]]; then
  echo "Missing or empty export: $DMG_PATH" >&2
  exit 1
fi

echo "==> Mounting DMG and extracting Reval Rebel.app"
hdiutil attach "$DMG_PATH" -nobrowse -readonly -mountpoint "$MOUNT_DIR" -quiet
SOURCE_APP="$MOUNT_DIR/Reval Rebel.app"
if [[ ! -d "$SOURCE_APP" ]]; then
  echo "Release export did not contain Reval Rebel.app." >&2
  exit 1
fi
rm -rf "$APP_PATH"
ditto "$SOURCE_APP" "$APP_PATH"
hdiutil detach "$MOUNT_DIR" -quiet 2>/dev/null || true
rmdir "$MOUNT_DIR" 2>/dev/null || true

BINARY="$APP_PATH/Contents/MacOS/Reval Rebel"
if [[ ! -x "$BINARY" ]]; then
  echo "Packaged binary missing: $BINARY" >&2
  exit 1
fi

echo "==> Running packaged install/start/save/load/exit smoke"
"$BINARY" -- --verify-packaged-platform >"$LAUNCH_LOG" 2>&1 &
APP_PID=$!
(
  sleep "$SMOKE_TIMEOUT_SECONDS"
  if kill -0 "$APP_PID" 2>/dev/null; then
    touch "$TIMEOUT_SENTINEL"
    kill "$APP_PID" 2>/dev/null || true
  fi
) &
WATCHDOG_PID=$!

set +e
wait "$APP_PID"
LAUNCH_EXIT=$?
set -e
APP_PID=""
kill "$WATCHDOG_PID" 2>/dev/null || true
wait "$WATCHDOG_PID" 2>/dev/null || true
WATCHDOG_PID=""
cat "$LAUNCH_LOG"

if [[ -e "$TIMEOUT_SENTINEL" ]]; then
  PRESERVE_LOG=1
  echo "Packaged platform smoke exceeded ${SMOKE_TIMEOUT_SECONDS}s." >&2
  exit 1
fi
if grep -q "compiled without support for path overrides" "$LAUNCH_LOG"; then
  echo "Packaged platform smoke incorrectly used a path override." >&2
  exit 1
fi
if [[ "$LAUNCH_EXIT" -ne 0 ]]; then
  echo "Packaged platform smoke failed with exit $LAUNCH_EXIT." >&2
  exit "$LAUNCH_EXIT"
fi
if grep -q "$FAIL_MARKER" "$LAUNCH_LOG"; then
  echo "Packaged platform smoke printed its failure marker." >&2
  exit 1
fi
if ! grep -q "$PASS_MARKER" "$LAUNCH_LOG"; then
  echo "Packaged platform smoke exited without the required pass marker." >&2
  exit 1
fi
UNEXPECTED_LOG="${LAUNCH_LOG}.unexpected"
grep -Ev "$DEF_002_ERROR" "$LAUNCH_LOG" > "$UNEXPECTED_LOG" || true
if grep -Eiq "$FAILURE_PATTERN" "$UNEXPECTED_LOG"; then
  echo "Packaged platform smoke emitted an unexpected engine or script error." >&2
  grep -Ein "$FAILURE_PATTERN" "$UNEXPECTED_LOG" >&2 || true
  rm -f "$UNEXPECTED_LOG"
  exit 1
fi
rm -f "$UNEXPECTED_LOG"

echo "P3-012 supported-platform smoke passed: $APP_PATH"
echo "Maintainer report: docs/reports/p3_012_supported_platforms.md"
