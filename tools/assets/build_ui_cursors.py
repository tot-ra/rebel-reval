#!/usr/bin/env python3
"""Build the gameplay hover cursors in assets/UI/cursors/.

Both cursors are drawn as vector shapes at 8x and downsampled to 32x32, so
small sizes stay crisp. Each glyph has a tip in the top-left corner
or top that is the click hotspot (tail of the speech bubble, middle fingertip);
keep HOTSPOT_* in scripts/ui/cursor_service.gd in sync with the printed values.

Style: cream fill and gold accents from the overlay skin
(scripts/ui/pause_menu_style.gd) with a dark outline, so the cursor reads on
both bright plaster and night streets.

Usage: python3 tools/assets/build_ui_cursors.py [--out assets/UI/cursors]
"""
from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

SIZE = 32
SS = 8  # supersampling factor
BIG = SIZE * SS

INK = (26, 22, 18, 255)
CREAM = (255, 240, 203, 255)
GOLD = (182, 154, 104, 255)
GOLD_DARK = (128, 100, 58, 255)
OUTLINE_PX = 2  # outline thickness in final pixels


def _capsule(draw: ImageDraw.ImageDraw, a, b, width: float, fill) -> None:
	"""Rounded segment from a to b."""
	draw.line([a, b], fill=fill, width=int(width))
	r = width / 2
	for x, y in (a, b):
		draw.ellipse([x - r, y - r, x + r, y + r], fill=fill)


def _finish(fill_layer: Image.Image, detail_layer: Image.Image | None) -> Image.Image:
	"""Add the dark outline around the filled glyph and downsample."""
	mask = fill_layer.getchannel("A").point(lambda v: 255 if v > 0 else 0)
	grown = mask.filter(ImageFilter.MaxFilter(OUTLINE_PX * SS * 2 + 1))
	out = Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))
	out.paste(Image.new("RGBA", (BIG, BIG), INK), (0, 0), grown)
	out.alpha_composite(fill_layer)
	if detail_layer is not None:
		# Clip interior detail to the glyph so it never touches the outline.
		detail_layer.putalpha(ImageChops.multiply(detail_layer.getchannel("A"), mask))
		out.alpha_composite(detail_layer)
	return out.resize((SIZE, SIZE), Image.LANCZOS)


def build_talk() -> tuple[Image.Image, tuple[int, int]]:
	s = SS
	fill = Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))
	d = ImageDraw.Draw(fill)
	tip = (3 * s, 3 * s)
	# Tail runs from the hotspot into the bubble's upper-left edge.
	d.polygon([tip, (14 * s, 9 * s), (9 * s, 14 * s)], fill=CREAM)
	d.rounded_rectangle([7 * s, 8 * s, 29.5 * s, 25 * s], radius=7 * s, fill=CREAM)
	detail = Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))
	dd = ImageDraw.Draw(detail)
	# Gold underside gives the bubble volume without extra outline noise.
	dd.rounded_rectangle([7 * s, 20.5 * s, 29.5 * s, 25 * s], radius=4 * s, fill=GOLD)
	dd.rounded_rectangle([7 * s, 8 * s, 29.5 * s, 22 * s], radius=7 * s, fill=CREAM)
	for cx in (12.6, 18.25, 23.9):
		r = 2.1 * s
		cy = 16 * s
		dd.ellipse([cx * s - r, cy - r, cx * s + r, cy + r], fill=INK)
	return _finish(fill, detail), (2, 2)


def _shift(layer: Image.Image, dx: int, dy: int) -> Image.Image:
	# Plain translate; ImageChops.offset would wrap clipped pixels around.
	moved = Image.new("RGBA", layer.size, (0, 0, 0, 0))
	moved.paste(layer, (dx, dy))
	return moved


def build_grab() -> tuple[Image.Image, tuple[int, int]]:
	"""Open upright hand; the middle fingertip is the hotspot."""
	s = SS
	fill = Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))
	d = ImageDraw.Draw(fill)
	# Upright hand in final-pixel units, rotated afterwards.
	fw = 3.6 * s
	fingers = [  # (x, top y)
		(12.2, 5.0),
		(16.0, 3.4),
		(19.8, 4.6),
		(23.3, 7.6),
	]
	for x, top in fingers:
		_capsule(d, (x * s, top * s + fw / 2), (x * s, 16 * s), fw, CREAM)
	d.rounded_rectangle([10.3 * s, 13 * s, 25.1 * s, 25 * s], radius=4.5 * s, fill=CREAM)
	_capsule(d, (12 * s, 21 * s), (6.2 * s, 14.6 * s), 3.8 * s, CREAM)
	# Gold cuff so the hand reads as a hand, not a blob.
	d.rounded_rectangle([11 * s, 24 * s, 24.4 * s, 30 * s], radius=1.5 * s, fill=GOLD)

	detail = Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))
	dd = ImageDraw.Draw(detail)
	for x in (14.1, 17.9, 21.55):
		dd.line([(x * s, 6.5 * s), (x * s, 14.5 * s)], fill=INK, width=int(1.0 * s))
	dd.line([(11 * s, 26.6 * s), (24.4 * s, 26.6 * s)], fill=GOLD_DARK, width=int(0.9 * s))

	# Centre the glyph (thumb to little finger) in the canvas. The hand stays
	# upright: tilting it pushes the thumb out of a 32 px canvas.
	dx, dy = int(1.3 * s), int(-0.6 * s)
	fill = _shift(fill, dx, dy)
	detail = _shift(detail, dx, dy)
	# Hotspot is the middle fingertip.
	return _finish(fill, detail), (17, 3)


def main() -> None:
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("--out", default="assets/UI/cursors")
	args = parser.parse_args()
	out = Path(args.out)
	out.mkdir(parents=True, exist_ok=True)
	for name, builder in (("cursor_talk", build_talk), ("cursor_grab", build_grab)):
		image, hotspot = builder()
		image.save(out / f"{name}.png")
		print(f"{name}.png {image.size} hotspot={hotspot}")


if __name__ == "__main__":
	main()
