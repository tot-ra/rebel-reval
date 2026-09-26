#!/usr/bin/env bash
# Rebuild realistic humans (ADR 0022) from specs: textiles, bodies and
# wardrobes (Blender + MPFB, build-time only), Godot import, provenance, lint.
#
#   tools/assets/realistic_humans/rebuild.sh [character ...]   # default: all specs
#
# One-time setup: tools/assets/realistic_humans/install_mpfb.sh
set -euo pipefail
cd "$(dirname "$0")/../../.."

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
BLENDER="${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}"
if [[ $# -eq 0 ]]; then
  set -- $(python3 -c 'import sys; sys.path.insert(0, "tools/assets/realistic_humans"); import specs; print(" ".join(specs.SPECS))')
fi

python3 tools/assets/realistic_humans/textiles.py
for character in "$@"; do
  "$BLENDER" --background --python-exit-code 1 --python tools/assets/realistic_humans/build_human.py -- \
    --character="$character"
done
python3 tools/assets/realistic_humans/write_scenes.py
"$GODOT" --headless --path . --import
python3 tools/assets/realistic_humans/register_sources.py
python3 tools/validate_asset_sources.py
python3 tools/verify_asset_lint.py
echo "Realistic humans rebuilt: $*"
