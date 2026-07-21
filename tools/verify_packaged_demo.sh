#!/usr/bin/env bash
# D-004 / D-004a / D-004c: export the macOS release build, run the real
# move-talk-pickup flow inside that app, and optionally refresh walkthrough frames.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
DMG_PATH="$BUILD_DIR/rr.dmg"
APP_PATH="$BUILD_DIR/Reval Rebel.app"
MOUNT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/reval-rebel-d004.XXXXXX")"
LAUNCH_LOG="$(mktemp "${TMPDIR:-/tmp}/reval-rebel-d004-launch.XXXXXX")"
PRESERVE_LOG=0
TIMEOUT_SENTINEL="$(mktemp "${TMPDIR:-/tmp}/reval-rebel-d004-timeout.XXXXXX")"
SKIP_CAPTURE="${SKIP_CAPTURE:-0}"
SKIP_EXPORT="${SKIP_EXPORT:-0}"
APP_PID=""
WATCHDOG_PID=""
readonly PASS_MARKER="D-004C_PACKAGED_WALKTHROUGH_PASS"
readonly FAIL_MARKER="D-004C_PACKAGED_WALKTHROUGH_FAIL"
readonly WALKTHROUGH_TIMEOUT_SECONDS=120
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
    echo "Packaged walkthrough log preserved at: $LAUNCH_LOG" >&2
  else
    rm -f "$LAUNCH_LOG" "$LAUNCH_LOG.unexpected"
  fi
  rm -f "$TIMEOUT_SENTINEL"
}
trap cleanup EXIT

cd "$ROOT_DIR"
mkdir -p "$BUILD_DIR"
rm -f "$TIMEOUT_SENTINEL"

echo "==> D-004 headless move-talk-pickup regression proof"
tools/run_godot_checked.sh --require-test-summary d004-walkthrough \
  "$GODOT" --headless --path "$ROOT_DIR" --script tools/run_godot_tests.gd -- \
  --filter=test_demo_walkthrough

echo "==> D-004c packaged-entrypoint contract"
tools/run_godot_checked.sh --require-test-summary d004c-entrypoint \
  "$GODOT" --headless --path "$ROOT_DIR" --script tools/run_godot_tests.gd -- \
  --filter=test_packaged_demo_walkthrough

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
# Detach early so the app under test is exactly the extracted build artifact.
hdiutil detach "$MOUNT_DIR" -quiet 2>/dev/null || true
rmdir "$MOUNT_DIR" 2>/dev/null || true

BINARY="$APP_PATH/Contents/MacOS/Reval Rebel"
if [[ ! -x "$BINARY" ]]; then
  echo "Packaged binary missing: $BINARY" >&2
  exit 1
fi

# WHY: release templates reject --path and scene overrides. `--` starts Godot's
# user-argument segment, allowing the normal main scene to opt into its shipped
# verifier without an editor binary selecting or driving any gameplay scene.
echo "==> Running packaged Start-Mart-pickup walkthrough (no --path / scene args)"
"$BINARY" -- --verify-packaged-demo >"$LAUNCH_LOG" 2>&1 &
APP_PID=$!
(
  sleep "$WALKTHROUGH_TIMEOUT_SECONDS"
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
  echo "Packaged walkthrough exceeded ${WALKTHROUGH_TIMEOUT_SECONDS}s." >&2
  exit 1
fi
if grep -q "compiled without support for path overrides" "$LAUNCH_LOG"; then
  echo "Packaged walkthrough incorrectly used a path override." >&2
  exit 1
fi
if [[ "$LAUNCH_EXIT" -ne 0 ]]; then
  echo "Packaged walkthrough failed with exit $LAUNCH_EXIT." >&2
  exit "$LAUNCH_EXIT"
fi
if grep -q "$FAIL_MARKER" "$LAUNCH_LOG"; then
  echo "Packaged walkthrough printed its failure marker." >&2
  exit 1
fi
if ! grep -q "$PASS_MARKER" "$LAUNCH_LOG"; then
  echo "Packaged walkthrough exited without the required pass marker." >&2
  exit 1
fi
UNEXPECTED_LOG="${LAUNCH_LOG}.unexpected"
grep -Ev "$DEF_002_ERROR" "$LAUNCH_LOG" > "$UNEXPECTED_LOG" || true
if grep -Eiq "$FAILURE_PATTERN" "$UNEXPECTED_LOG"; then
  echo "Packaged walkthrough emitted an unexpected engine or script error." >&2
  grep -Ein "$FAILURE_PATTERN" "$UNEXPECTED_LOG" >&2 || true
  rm -f "$UNEXPECTED_LOG"
  exit 1
fi
rm -f "$UNEXPECTED_LOG"

echo "Packaged in-binary walkthrough passed: $APP_PATH"

if [[ "$SKIP_CAPTURE" != "1" ]]; then
  echo "==> Capturing walkthrough frames (rendering run via editor binary)"
  "$GODOT" --path "$ROOT_DIR" res://tools/capture_demo_walkthrough_host.tscn
fi

echo "D-004c packaged demo verification passed."
echo "Walkthrough report: docs/reports/demo_walkthrough_d004.md"
echo "Release-only triage: docs/reports/d004a_release_only_triage.md"
