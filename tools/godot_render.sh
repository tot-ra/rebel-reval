#!/usr/bin/env bash
# Run a Godot command that needs a real GPU renderer (captures, render probes,
# benchmarks) without a window popping up or stealing focus.
#
# Why: `--headless` uses the dummy renderer, so viewport textures are empty and
# captures cannot run headless. Godot 4.7 has no CLI flag for a hidden or
# minimized window, and hiding/minimizing from a script still flashes the
# window. The only flash-free option is the project setting
# `display/window/size/mode=1` (minimized) applied at startup via override.cfg.
#
# What: we never write override.cfg into the real project (an open editor or a
# concurrent game run would pick it up). Instead we build a throwaway shadow
# project dir whose top-level entries are symlinks to the repo, add
# override.cfg there, and run Godot with `--path <shadow>`. res:// reads and
# writes go through the symlinks into the real repo. New top-level entries
# created during the run are moved back into the repo afterwards.
#
# Usage: tools/godot_render.sh [godot args...]   (do not pass --path)
#   tools/godot_render.sh --script tools/capture_door_preview.gd
#   GODOT_RENDER_VISIBLE=1 tools/godot_render.sh ...   # debug with a visible window
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Scratch class_name backups must live under build/scratch/. Do not add
# build/.gdignore at the root: capture tools read and write res://build/,
# and `godot_render.sh --script res://build/...` must keep resolving.
mkdir -p "$ROOT/build/scratch"
if [[ ! -e "$ROOT/build/scratch/.gdignore" ]]; then
  : > "$ROOT/build/scratch/.gdignore"
fi

if [[ -n "${GODOT_BIN:-}" ]]; then
  godot="$GODOT_BIN"
elif command -v godot >/dev/null 2>&1; then
  godot="$(command -v godot)"
else
  godot="/Applications/Godot.app/Contents/MacOS/Godot"
fi

for arg in "$@"; do
  if [[ "$arg" == "--path" || "$arg" == --path=* ]]; then
    echo "godot_render.sh: do not pass --path; the wrapper sets it" >&2
    exit 2
  fi
done

if [[ "${GODOT_RENDER_VISIBLE:-}" == "1" ]]; then
  exec "$godot" --path "$ROOT" "$@"
fi

shadow="$(mktemp -d "${TMPDIR:-/tmp}/godot-render.XXXXXX")"

restore_and_cleanup() {
  local entry
  for entry in "$shadow"/* "$shadow"/.[!.]*; do
    [[ -e "$entry" || -L "$entry" ]] || continue
    [[ -L "$entry" || "$(basename "$entry")" == "override.cfg" ]] && continue
    # Top-level file or dir created by the run (for example build/): keep it.
    if [[ ! -e "$ROOT/$(basename "$entry")" ]]; then
      mv "$entry" "$ROOT/"
    fi
  done
  rm -rf "$shadow"
}
trap restore_and_cleanup EXIT

for entry in "$ROOT"/* "$ROOT"/.[!.]*; do
  [[ -e "$entry" || -L "$entry" ]] || continue
  [[ "$(basename "$entry")" == "override.cfg" ]] && continue
  ln -s "$entry" "$shadow/$(basename "$entry")"
done

cat > "$shadow/override.cfg" <<'EOF'
[display]

window/size/mode=1
window/size/no_focus=true
EOF

set +e
"$godot" --path "$shadow" "$@"
status=$?
set -e
exit "$status"
