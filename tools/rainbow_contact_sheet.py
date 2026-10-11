#!/usr/bin/env python3
"""R-1518: label and tile the rainbow scenario plates into one contact sheet.

Run after tools/capture_rainbow_scenarios.gd:
    python3 tools/rainbow_contact_sheet.py [plates_dir] [out.png]
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

LABELS = {
    "a_low_sun_full_double": "A. Sun 8 deg: full double bow, red outside primary, reversed secondary",
    "b_sun_25": "B. Sun 25 deg: bow top only 17 deg high, legs into the sea",
    "c_sun_38_top_only": "C. Sun 38 deg: primary is a 4 deg sliver on the horizon",
    "d_sun_48_secondary_only": "D. Sun 48 deg: primary below horizon, only the secondary",
    "e_camera_turned_45": "E. Camera turned 45 deg: bow stays fixed to the antisolar point",
    "f_departed_shower_east": "F. Shower drifted east: only the east leg has lit drops",
    "g_medium_drops_supernumerary": "G. Medium drops: paler bands, supernumerary fringes inside",
    "h_fog_droplets_fogbow": "H. Fog/mist droplets: broad white fogbow, no secondary",
    "i_gameplay_high_camera": "I. High gameplay camera: bow seen only reflected in water",
    "j_fair_cumulus": "J. Fair cumulus: clouds in front of the drops hide the bow",
}
TILE = (640, 360)


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    plates_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else root / "docs/reports/images/rainbow"
    out = Path(sys.argv[2]) if len(sys.argv) > 2 else plates_dir / "rainbow_contact_sheet.png"
    plates = [p for p in sorted(plates_dir.glob("rainbow_*.png")) if p.stem != "rainbow_contact_sheet"]
    if not plates:
        print(f"no plates in {plates_dir}", file=sys.stderr)
        return 1
    columns = 2
    rows = (len(plates) + columns - 1) // columns
    sheet = Image.new("RGB", (TILE[0] * columns, TILE[1] * rows), (16, 16, 16))
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 17)
    except OSError:
        font = ImageFont.load_default()
    for index, path in enumerate(plates):
        tile = Image.open(path).convert("RGB").resize(TILE, Image.LANCZOS)
        draw = ImageDraw.Draw(tile)
        label = LABELS.get(path.stem.removeprefix("rainbow_"), path.stem)
        draw.rectangle((0, 0, TILE[0], 26), fill=(0, 0, 0))
        draw.text((8, 4), label, fill=(240, 240, 240), font=font)
        sheet.paste(tile, ((index % columns) * TILE[0], (index // columns) * TILE[1]))
    sheet.save(out)
    print(f"wrote {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
