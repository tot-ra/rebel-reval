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
"$BLENDER" --background --python-exit-code 1 --python tools/generate_hero_body.py -- \
  --character="$CHARACTER"
"$BLENDER" --background --python-exit-code 1 --python tools/generate_character_lods.py
python3 tools/share_character_textures.py --apply
"$GODOT" --headless --path . --import
python3 tools/register_character_texture_sources.py
python3 tools/share_character_textures.py --verify
python3 tools/verify_asset_lint.py
echo "Character '$CHARACTER' rebuilt, LODs refreshed and reimported."
