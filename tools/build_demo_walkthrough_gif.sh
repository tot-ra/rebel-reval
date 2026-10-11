#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRAME_DIR="$ROOT_DIR/docs/reports/images/demo_walkthrough"
OUTPUT_PATH="$FRAME_DIR/demo_walkthrough.gif"

if ! command -v magick >/dev/null 2>&1; then
  echo "ImageMagick is required to rebuild the demo walkthrough GIF (brew install imagemagick)." >&2
  exit 1
fi

font_path="${DEMO_WALKTHROUGH_FONT:-}"
if [[ -z "$font_path" ]]; then
  for candidate in \
    /System/Library/Fonts/Helvetica.ttc \
    /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf; do
    if [[ -f "$candidate" ]]; then
      font_path="$candidate"
      break
    fi
  done
fi
if [[ -z "$font_path" || ! -f "$font_path" ]]; then
  echo "No caption font found. Set DEMO_WALKTHROUGH_FONT to a readable TTF/TTC file." >&2
  exit 1
fi

frames=(
  "00_main_menu.png"
  "01_forge_start.png"
  "02_forge_move.png"
  "03_lower_town_arrive.png"
  "04_mart_talk.png"
  "05_mart_done.png"
  "06_spearhead_pickup.png"
)
labels=(
  "START - packaged main menu"
  "START - Kalev enters the forge"
  "MOVE - the forge is playable"
  "TRAVEL - enter Lower Town"
  "TALK - Mart dialogue"
  "TALK - conversation complete"
  "PICK UP - spearhead in the bag"
)
delays=(180 100 100 120 180 100 240)

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/reval-demo-gif.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT

animated_args=()
for index in "${!frames[@]}"; do
  source_path="$FRAME_DIR/${frames[$index]}"
  rendered_path="$work_dir/$(printf '%02d' "$index").png"
  if [[ ! -f "$source_path" ]]; then
    echo "Missing walkthrough frame: $source_path" >&2
    exit 1
  fi

  # Keep captions inside the image so the README animation remains legible
  # outside the surrounding report and on Git hosting previews.
  magick "$source_path" \
    -resize '960x540^' \
    -gravity center \
    -extent 960x540 \
    -gravity south \
    -fill '#fff4d6' \
    -undercolor '#17130fd9' \
    -font "$font_path" \
    -pointsize 30 \
    -annotate +0+18 "  ${labels[$index]}  " \
    -strip \
    "$rendered_path"
  animated_args+=( -delay "${delays[$index]}" "$rendered_path" )
done

magick "${animated_args[@]}" -loop 0 -layers Optimize "$OUTPUT_PATH"

echo "Wrote ${OUTPUT_PATH#$ROOT_DIR/}"
