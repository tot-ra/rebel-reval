#!/usr/bin/env python3
"""Turn raw white-on-black emblem renders into assets/ui/factions/<slug>.png (R-1565).

Output is a 128 px white glyph whose alpha is the shape (luminance), so the game
tints it with the faction primary colour (chip) without a second asset. The
Livonian cross (the image models refuse that prompt) and the Danish
Nordic cross (the render came back inside a shield) are drawn here as geometry.

Usage: import_faction_emblems.py RAW_DIR OUT_DIR   (RAW_DIR holds <slug>.png files)
Raw files are the model renders; the slug -> render mapping is the file name.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

SIZE = 128
PAD = 8


def glyph_from_render(path: Path) -> Image.Image:
    lum = Image.open(path).convert("L")
    lum = lum.point(lambda v: 0 if v < 40 else 255 if v > 200 else v)  # crush noise, keep AA
    box = lum.getbbox()
    if box is None:
        raise SystemExit(f"{path}: empty render")
    lum = lum.crop(box)
    side = SIZE - 2 * PAD
    scale = side / max(lum.size)
    lum = lum.resize((max(1, round(lum.width * scale)), max(1, round(lum.height * scale))), Image.LANCZOS)
    out = Image.new("LA", (SIZE, SIZE), (255, 0))
    out.paste(Image.merge("LA", (Image.new("L", lum.size, 255), lum)),
              ((SIZE - lum.width) // 2, (SIZE - lum.height) // 2))
    return out.convert("RGBA")


def livonian_cross() -> Image.Image:
    # 4x supersampled cross pattee: arms widen toward the ends.
    s = SIZE * 4
    mask = Image.new("L", (s, s), 0)
    d = ImageDraw.Draw(mask)
    c, inner, outer = s // 2, int(s * 0.11), int(s * 0.2)
    r = s // 2 - PAD * 4
    for sx, sy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        tip = (c + sx * r, c + sy * r)
        if sx:
            pts = [(c, c - inner), (tip[0], c - outer), (tip[0], c + outer), (c, c + inner)]
        else:
            pts = [(c - inner, c), (c - outer, tip[1]), (c + outer, tip[1]), (c + inner, c)]
        d.polygon(pts, fill=255)
    d.rectangle([c - inner, c - inner, c + inner, c + inner], fill=255)
    mask = mask.resize((SIZE, SIZE), Image.LANCZOS)
    out = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
    out.putalpha(mask)
    return out


def nordic_cross() -> Image.Image:
    # Offset vertical bar (Dannebrog proportions): bar centre at 3/8 of the width.
    s = SIZE * 4
    mask = Image.new("L", (s, s), 0)
    d = ImageDraw.Draw(mask)
    lo, hi, w = PAD * 4, s - PAD * 4, int(s * 0.14)
    cx, cy = int(lo + (hi - lo) * 0.38), s // 2
    d.rectangle([lo, cy - w // 2, hi, cy + w // 2], fill=255)
    d.rectangle([cx - w // 2, lo + int(s * 0.08), cx + w // 2, hi - int(s * 0.08)], fill=255)
    out = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
    out.putalpha(mask.resize((SIZE, SIZE), Image.LANCZOS))
    return out


def main() -> int:
    raw, out_dir = Path(sys.argv[1]), Path(sys.argv[2])
    out_dir.mkdir(parents=True, exist_ok=True)
    for src in sorted(raw.glob("*.png")):
        glyph_from_render(src).save(out_dir / src.name, optimize=True)
        print("wrote", out_dir / src.name)
    for slug, draw in (("livonian_order", livonian_cross), ("danish_crown", nordic_cross)):
        draw().save(out_dir / f"{slug}.png", optimize=True)
        print("wrote", out_dir / f"{slug}.png")
    return 0


if __name__ == "__main__":
    sys.exit(main())
