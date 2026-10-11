#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
DMG_PATH="$BUILD_DIR/rr.dmg"
APP_PATH="$BUILD_DIR/Reval Rebel.app"
MOUNT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/reval-rebel-release.XXXXXX")"

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

mkdir -p "$BUILD_DIR"
"$GODOT" --headless --path "$ROOT_DIR" --export-release "rr" "$DMG_PATH"

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

open "$APP_PATH"
echo "Started release build: $APP_PATH"
