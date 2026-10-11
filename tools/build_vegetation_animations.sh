#!/usr/bin/env bash
# Turn the frames from tools/capture_vegetation_animations.gd (build/veg_anim/)
# into the looping GIFs embedded in docs/SYSTEMS/LIVING_VEGETATION.md.
# Palette per sequence (palettegen/paletteuse) keeps each GIF small enough for
# standard Git (see docs/ASSET_STORAGE_POLICY.md).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FRAMES="$ROOT/build/veg_anim"
OUT="$ROOT/docs/reports/images/vegetation"

# sequence output fps width [crop]
build() {
  local sequence="$1" name="$2" fps="$3" width="$4" crop="${5:-}"
  local filters="fps=$fps,${crop:+$crop,}scale=$width:-1:flags=lanczos"
  ffmpeg -loglevel error -y -framerate "$fps" -i "$FRAMES/$sequence/%03d.png" \
    -filter_complex "$filters,split[a][b];[a]palettegen=max_colors=96:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" \
    -loop 0 "$OUT/$name.gif"
  echo "$OUT/$name.gif $(wc -c < "$OUT/$name.gif") bytes"
}

build storm anim_tree_storm 12 600
# The empty sky above the birches carries no wind: crop it.
build meadow anim_meadow_wind 8 480 "crop=in_w:in_h*0.8:0:in_h*0.2"
# One date per 0.6 s so each half-month can be read.
ffmpeg -loglevel error -y -framerate 1.6 -i "$FRAMES/seasons/%03d.png" \
  -filter_complex "scale=960:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=bayer:bayer_scale=4" \
  -loop 0 "$OUT/anim_tree_seasons.gif"
echo "$OUT/anim_tree_seasons.gif $(wc -c < "$OUT/anim_tree_seasons.gif") bytes"
