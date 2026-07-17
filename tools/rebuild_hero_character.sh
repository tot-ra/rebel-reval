#!/usr/bin/env bash
# Rebuild a generated character from source: adult skeleton retarget
# (Python), body generation (Blender, build-time only), Godot reimport.
#
#   tools/rebuild_hero_character.sh [spec_name]   # default: hero
#
# Spec names come from tools/character_specs.py; see
# docs/CHARACTER_GENERATION.md for the full procedure.
set -euo pipefail
cd "$(dirname "$0")/.."

CHARACTER="${1:-hero}"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
BLENDER="${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}"

python3 tools/build_heroic_humanoid_glb.py "$CHARACTER"
"$BLENDER" --background --python tools/generate_hero_body.py -- \
  --character="$CHARACTER" 2>&1 \
  | grep -E "BODY_|Wrote|Traceback|Error" || true
"$GODOT" --headless --path . --import >/dev/null 2>&1
echo "Character '$CHARACTER' rebuilt and reimported."
