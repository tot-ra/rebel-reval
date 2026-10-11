#!/usr/bin/env bash
# Install the pinned MPFB Blender extension and the CC0 MakeHuman system asset
# pack that tools/assets/realistic_humans/build_human.py builds humans from.
# Build-time only: the game never loads MPFB or MakeHuman data at runtime.
#
#   tools/assets/realistic_humans/install_mpfb.sh
set -euo pipefail
cd "$(dirname "$0")/../../.."

BLENDER="${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}"
CACHE=build/mpfb
MPFB_URL="https://extensions.blender.org/download/sha256:4f0a879d64a39bf646fbf5f53601ac678855da329d650617dca5737548239a87/add-on-mpfb-v2.0.17.zip"
MPFB_SHA=4f0a879d64a39bf646fbf5f53601ac678855da329d650617dca5737548239a87
ASSETS_URL="https://files2.makehumancommunity.org/asset_packs/makehuman_system_assets/makehuman_system_assets_cc0.zip"
ASSETS_SHA=b542127a8e25547c7c29c19f2d1d2adb9a664c80396ecd694095dbc8028a0107

mkdir -p "$CACHE"
fetch() {
  local url=$1 file=$2 sha=$3
  if [[ ! -f $file ]] || ! echo "$sha  $file" | shasum -a 256 -c --status; then
    curl -fL -o "$file" "$url"
  fi
  echo "$sha  $file" | shasum -a 256 -c
}
fetch "$MPFB_URL" "$CACHE/mpfb.zip" "$MPFB_SHA"
fetch "$ASSETS_URL" "$CACHE/sys.zip" "$ASSETS_SHA"

"$BLENDER" --command extension install-file -r user_default -e "$CACHE/mpfb.zip"
USER_DATA=$("$BLENDER" -b --python-expr 'import bpy;print("USERDIR="+bpy.utils.extension_path_user("bl_ext.user_default.mpfb",create=True))' 2>/dev/null | sed -n 's/^USERDIR=//p')
mkdir -p "$USER_DATA/data"
unzip -q -o "$CACHE/sys.zip" -d "$USER_DATA/data"
echo "MPFB 2.0.17 and MakeHuman CC0 system assets installed in $USER_DATA"
