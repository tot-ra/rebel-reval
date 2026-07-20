#!/usr/bin/env bash
# D-004: export the macOS release build, prove it launches, and run the
# automated move-talk-pickup checks plus optional frame capture.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
DMG_PATH="$BUILD_DIR/rr.dmg"
APP_PATH="$BUILD_DIR/Reval Rebel.app"
MOUNT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/reval-rebel-d004.XXXXXX")"
SKIP_CAPTURE="${SKIP_CAPTURE:-0}"
SKIP_EXPORT="${SKIP_EXPORT:-0}"

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
  hdiutil detach "$MOUNT_DIR" -quiet 2>/dev/null || true
  rmdir "$MOUNT_DIR" 2>/dev/null || true
}
trap cleanup EXIT

cd "$ROOT_DIR"
mkdir -p "$BUILD_DIR"

echo "==> D-004 headless move-talk-pickup proof"
tools/run_godot_checked.sh --require-test-summary d004-walkthrough \
  "$GODOT" --headless --path "$ROOT_DIR" --script tools/run_godot_tests.gd -- \
  --filter=test_demo_walkthrough

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
cleanup
trap - EXIT

BINARY="$APP_PATH/Contents/MacOS/Reval Rebel"
if [[ ! -x "$BINARY" ]]; then
  echo "Packaged binary missing: $BINARY" >&2
  exit 1
fi

echo "==> Launching packaged binary briefly (no debug inspector in release builds)"
"$BINARY" --path "$ROOT_DIR" --quit-after 4 >/tmp/reval-rebel-d004-launch.log 2>&1 || true
if ! grep -q "Godot Engine" /tmp/reval-rebel-d004-launch.log && ! grep -qi "Reval" /tmp/reval-rebel-d004-launch.log; then
  # Packaged apps often write little to stdout; accept a live process launch instead.
  open "$APP_PATH"
  sleep 4
  if ! pgrep -f "Reval Rebel.app/Contents/MacOS/Reval Rebel" >/dev/null; then
    echo "Packaged app failed to stay running after open." >&2
    exit 1
  fi
  pkill -f "Reval Rebel.app/Contents/MacOS/Reval Rebel" >/dev/null 2>&1 || true
fi
echo "Packaged app launch ok: $APP_PATH"

if [[ "$SKIP_CAPTURE" != "1" ]]; then
  echo "==> Capturing walkthrough frames (rendering run)"
  "$GODOT" --path "$ROOT_DIR" res://tools/capture_demo_walkthrough_host.tscn
fi

echo "D-004 packaged demo verification passed."
echo "Walkthrough report: docs/reports/demo_walkthrough_d004.md"
