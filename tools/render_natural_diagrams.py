#!/usr/bin/env python3
"""Render the explanatory diagrams for docs/SYSTEMS/NATURAL.md.

Usage: python3 tools/render_natural_diagrams.py [--out docs/reports/images/natural]

Diagrams, not game art: they restate the tables in NATURAL.md and SPIRIT_SIGHT.md
as pictures. The numbers below mirror GameState / SpiritAuraProfile; if those
change, update the constants here and rerun. Needs Pillow and the macOS
Supplemental Arial fonts (falls back to Pillow's default font elsewhere).
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

BG = (13, 15, 24)
INK = (225, 228, 238)
DIM = (140, 146, 165)
LINE = (70, 76, 96)

# Light order root -> sky, same as SpiritAuraProfile.LIGHT_IDS.
ASPECTS = [
    # slug, tree tier, body anchor, duel element, magic elements, sample physical verbs, colour
    ("nature", "roots", "pelvis", "fear", "earth, metal", "vitality, stability, endurance", (226, 70, 62)),
    ("affection", "base of trunk", "lower spine", "coin", "water, air", "agility, dexterity, reaction", (240, 140, 50)),
    ("tenacity", "main trunk", "mid spine", "duty", "fire, beast", "strength, raw power, intimidation", (236, 210, 70)),
    ("unity", "large branch", "chest", "love", "life, hope", "charisma, empathy, healing", (80, 196, 96)),
    ("resonance", "high windy branch", "neck", "shame", "deception, dominion", "persuasion, deception, leadership", (70, 140, 230)),
    ("awareness", "treetop perch", "head, front", "sight (none)", "mind, time", "perception, wisdom, cooldown", (110, 90, 220)),
    ("light", "sky above tree", "over the head", "faith", "faith, spirit", "faith, willpower, elemental link", (186, 110, 226)),
]

# SpiritAuraProfile.RANK_BANDS: each threshold reached adds one light level.
RANK_BANDS = [5, 10, 15, 25, 40]
CAP = 50
APPRENTICE = {"nature": 10, "affection": 5, "tenacity": 5, "unity": 10, "resonance": 5, "awareness": 15, "light": 5}


def font(size: int, bold: bool = False) -> ImageFont.ImageFont:
    name = "Arial Bold.ttf" if bold else "Arial.ttf"
    try:
        return ImageFont.truetype(f"/System/Library/Fonts/Supplemental/{name}", size)
    except OSError:
        return ImageFont.load_default(size)


def level_for_rank(rank: int) -> int:
    return sum(1 for threshold in RANK_BANDS if rank >= threshold)


def glow_dot(image: Image.Image, center: tuple[float, float], radius: float, colour: tuple[int, int, int], level: int) -> None:
    """A soft halo plus a solid ball, whiter with level, like the in-game light."""
    x, y = center
    halo = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(halo)
    spread = radius * (1.6 + 0.35 * level)
    draw.ellipse((x - spread, y - spread, x + spread, y + spread), fill=colour + (110,))
    halo = halo.filter(ImageFilter.GaussianBlur(radius * 0.8))
    image.alpha_composite(halo)
    draw = ImageDraw.Draw(image)
    if level == 0:
        # Black hole: dark centre, coloured rim.
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=(5, 5, 8), outline=colour, width=3)
        return
    white = min(0.12 * level, 0.6)
    core = tuple(int(c + (255 - c) * white) for c in colour)
    draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=core)


def hingepuu_map(out: Path) -> None:
    """Tree tier -> body anchor -> aspect -> what it powers, one row per light."""
    width, height = 1600, 980
    image = Image.new("RGBA", (width, height), BG + (255,))
    draw = ImageDraw.Draw(image)
    draw.text((40, 28), "Seven aspects = seven hearths of the Hingepuu = seven soul lights", font=font(34, True), fill=INK)
    draw.text((40, 74), "Each row is one aspect: where it grows on the soul tree, where it shines on the body in spirit sight, and what it powers.", font=font(20), fill=DIM)

    top, step = 190, 112
    rows = [top + (6 - i) * step for i in range(7)]  # root at the bottom

    # Column headers.
    headers = [(290, "Hingepuu tier"), (470, "Soul light on the body"), (704, "Aspect"), (930, "Guards in a duel"), (1110, "Magic elements"), (1320, "Physical verbs (examples)")]
    for x, text in headers:
        draw.text((x, 136), text, font=font(19, True), fill=DIM)
    draw.line((40, 166, width - 40, 166), fill=LINE, width=2)

    # Row separators first, so the tree and body draw over them.
    for y in rows:
        draw.line((280, y + 56, width - 40, y + 56), fill=(28, 31, 44), width=1)

    # Soul tree, stylised: roots, trunk, branches, crown, sky.
    trunk_x = 160
    bark = (120, 96, 72)
    leaf = (60, 110, 70)
    draw.polygon([(trunk_x - 22, rows[0] - 20), (trunk_x + 22, rows[0] - 20), (trunk_x + 12, rows[4]), (trunk_x - 12, rows[4])], fill=bark)
    for dx in (-90, -50, 0, 50, 90):
        draw.line((trunk_x, rows[0] - 20, trunk_x + dx, rows[0] + 34), fill=bark, width=7)
    draw.line((trunk_x, rows[3] + 10, trunk_x + 95, rows[3] - 35), fill=bark, width=10)
    draw.line((trunk_x, rows[3] + 10, trunk_x - 85, rows[3] - 30), fill=bark, width=9)
    draw.line((trunk_x, rows[4] + 10, trunk_x + 75, rows[4] - 40), fill=bark, width=6)
    draw.line((trunk_x, rows[4] + 10, trunk_x - 70, rows[4] - 35), fill=bark, width=6)
    draw.ellipse((trunk_x - 105, rows[5] - 70, trunk_x + 105, rows[4] + 10), fill=leaf)
    draw.ellipse((trunk_x - 60, rows[5] - 90, trunk_x + 60, rows[5] + 25), fill=(74, 132, 84))
    for sx, sy in ((-80, -10), (-20, -25), (40, 0), (95, -20), (-110, 15)):
        draw.text((trunk_x + sx, rows[6] + sy), "*", font=font(26, True), fill=(220, 210, 255))

    # Body silhouette with the lights on it.
    body_x = 520
    shade = (46, 50, 66)
    draw.ellipse((body_x - 40, rows[5] - 46, body_x + 40, rows[5] + 40), fill=shade)
    draw.rectangle((body_x - 16, rows[5] + 34, body_x + 16, rows[4] + 22), fill=shade)
    draw.rounded_rectangle((body_x - 56, rows[4] + 14, body_x + 56, rows[0] + 26), radius=34, fill=shade)
    draw.rectangle((body_x - 50, rows[0] + 10, body_x - 10, height - 40), fill=shade)
    draw.rectangle((body_x + 10, rows[0] + 10, body_x + 50, height - 40), fill=shade)
    draw.line((body_x, rows[6], body_x, 160), fill=(235, 235, 255), width=3)  # sky beam from the crown

    for i, (slug, tier, anchor, duel, magic, verbs, colour) in enumerate(ASPECTS):
        y = rows[i]
        glow_dot(image, (body_x, y), 15, colour, 3)
        draw = ImageDraw.Draw(image)
        draw.text((704, y - 14), str(i + 1), font=font(22, True), fill=colour)
        draw.text((598, y - 12), anchor, font=font(17), fill=DIM)
        draw.text((730, y - 18), slug.capitalize(), font=font(28, True), fill=colour)
        draw.text((730, y + 14), f"aspect.{slug}", font=font(15), fill=DIM)
        draw.text((930, y - 12), duel, font=font(22), fill=INK)
        draw.text((1110, y - 12), magic, font=font(22), fill=INK)
        draw.text((1320, y - 10), verbs, font=font(15), fill=DIM)
        draw.text((290, y - 12), tier, font=font(18), fill=(170, 176, 196))

    draw.text((40, height - 34), "Brightness shows strength or a weak point, never goodness. Source: NATURAL.md sections 2, 3.5, 4; SPIRIT_SIGHT.md.", font=font(16), fill=DIM)
    image.convert("RGB").save(out / "hingepuu_map.png", optimize=True)


def rank_ladder(out: Path) -> None:
    """Stored rank 0..50 -> light level, magic multiplier, apprentice baseline."""
    width, height = 1600, 820
    image = Image.new("RGBA", (width, height), BG + (255,))
    draw = ImageDraw.Draw(image)
    draw.text((40, 28), "One number drives the light and the magic: the aspect rank", font=font(34, True), fill=INK)
    draw.text((40, 74), "The rank is the only thing saved. The soul light level and the magic multiplier are read from it.", font=font(20), fill=DIM)

    left, right = 120, width - 80

    def x_of(rank: float) -> float:
        return left + (right - left) * rank / CAP

    # Light-level bands with a sample light above each.
    bands = [0] + RANK_BANDS + [CAP + 1]
    names = ["closed", "ember", "glow", "bright", "radiant", "blazing"]
    band_top, band_bottom = 300, 360
    colour = (110, 90, 220)
    for level in range(6):
        start, end = bands[level], min(bands[level + 1], CAP + 1) - 1
        x0, x1 = x_of(start), x_of(end + 1 if end < CAP else CAP)
        shade = tuple(int(BG[k] + (colour[k] - BG[k]) * (0.15 + 0.15 * level)) for k in range(3))
        draw.rectangle((x0, band_top, x1, band_bottom), fill=shade, outline=BG, width=2)
        label = f"{start}-{end}" if level else "0-4"
        draw.text(((x0 + x1) / 2, band_top + 30), label, font=font(18, True), fill=INK, anchor="mm")
        cx = (x0 + x1) / 2
        glow_dot(image, (cx, 200), 10 + 3 * level, colour, level)
        draw = ImageDraw.Draw(image)
        draw.text((cx, 262), f"level {level} - {names[level]}", font=font(18), fill=INK, anchor="mm")
    draw.text((40, band_top + 18), "light", font=font(18, True), fill=DIM)

    # Rank axis.
    axis_y = band_bottom + 30
    draw.line((left, axis_y, right, axis_y), fill=LINE, width=2)
    for rank in range(0, CAP + 1, 5):
        draw.line((x_of(rank), axis_y - 6, x_of(rank), axis_y + 6), fill=LINE, width=2)
        draw.text((x_of(rank), axis_y + 20), str(rank), font=font(16), fill=DIM, anchor="mm")
    draw.text((40, axis_y + 10), "rank", font=font(18, True), fill=DIM)
    draw.text((x_of(CAP), axis_y + 44), "hard cap 50", font=font(16), fill=DIM, anchor="mm")

    # Apprentice New Game baseline markers.
    marker_y = axis_y + 90
    draw.text((40, marker_y - 10), "New Game", font=font(18, True), fill=DIM)
    by_rank: dict[int, list[str]] = {}
    for slug, rank in APPRENTICE.items():
        by_rank.setdefault(rank, []).append(slug)
    for rank, slugs in sorted(by_rank.items()):
        x = x_of(rank)
        draw.polygon([(x, marker_y - 22), (x - 8, marker_y - 8), (x + 8, marker_y - 8)], fill=INK)
        for j, slug in enumerate(slugs):
            aspect_colour = next(a[6] for a in ASPECTS if a[0] == slug)
            draw.text((x, marker_y + 6 + j * 22), slug, font=font(17), fill=aspect_colour, anchor="mt")

    # Magic multiplier line: 1.0 + 0.02 * rank.
    mult_top, mult_bottom = 620, 750
    draw.text((40, mult_top - 8), "magic", font=font(18, True), fill=DIM)
    draw.line((left, mult_bottom, right, mult_bottom), fill=LINE, width=1)
    draw.line((x_of(0), mult_bottom, x_of(CAP), mult_top), fill=(236, 210, 70), width=4)
    for rank in (0, 10, 25, 50):
        y = mult_bottom - (mult_bottom - mult_top) * rank / CAP
        draw.ellipse((x_of(rank) - 5, y - 5, x_of(rank) + 5, y + 5), fill=(236, 210, 70))
        draw.text((x_of(rank) + 10, y - 26), f"x{1 + 0.02 * rank:.2f}", font=font(17), fill=INK)
    draw.text((left, mult_bottom + 14), "element multiplier = 1.0 + 0.02 x effective rank (spells only; duel words use the light level)", font=font(17), fill=DIM)
    image.convert("RGB").save(out / "rank_ladder.png", optimize=True)


def box(draw: ImageDraw.ImageDraw, xy: tuple[int, int, int, int], title: str, lines: list[str], accent: tuple[int, int, int]) -> None:
    draw.rounded_rectangle(xy, radius=14, fill=(24, 27, 40), outline=accent, width=3)
    x0, y0 = xy[0] + 16, xy[1] + 14
    draw.text((x0, y0), title, font=font(21, True), fill=INK)
    for i, text in enumerate(lines):
        draw.text((x0, y0 + 34 + i * 24), text, font=font(16), fill=DIM)


def arrow(draw: ImageDraw.ImageDraw, start: tuple[int, int], end: tuple[int, int], label: str = "") -> None:
    draw.line((*start, *end), fill=INK, width=3)
    (x0, y0), (x1, y1) = start, end
    length = max(((x1 - x0) ** 2 + (y1 - y0) ** 2) ** 0.5, 1.0)
    ux, uy = (x1 - x0) / length, (y1 - y0) / length
    draw.polygon([(x1, y1), (x1 - 14 * ux + 7 * uy, y1 - 14 * uy - 7 * ux), (x1 - 14 * ux - 7 * uy, y1 - 14 * uy + 7 * ux)], fill=INK)
    if label:
        draw.text(((x0 + x1) / 2, (y0 + y1) / 2 - 16), label, font=font(15), fill=(236, 210, 70), anchor="mm")


def point_flow(out: Path) -> None:
    """How a point travels: authored grant -> unspent pool -> Hingepuu spend -> rank -> effects."""
    width, height = 1600, 820
    image = Image.new("RGBA", (width, height), BG + (255,))
    draw = ImageDraw.Draw(image)
    draw.text((40, 28), "How the apprentice grows: from a story beat to a brighter light", font=font(34, True), fill=INK)
    draw.text((40, 74), "Points are authored, never ground out. Visiting the Hingepuu spends points; visits alone mint none.", font=font(20), fill=DIM)

    box(draw, (40, 160, 360, 330), "Story beat", ["quest aftermath", "morning reflection", "forge milestone"], (120, 96, 72))
    box(draw, (460, 160, 760, 330), "Unspent points", ["natural.unspent_points", "10 at the first", "Hingepuu allocation"], (236, 210, 70))
    box(draw, (860, 160, 1200, 330), "At the Hingepuu", ["pick one of seven hearths", "spend 1 point per click", "the first Confirm sets", "flag.natural.initial_allocation"], (80, 196, 96))
    box(draw, (1290, 160, 1560, 330), "Aspect rank", ["natural.aspects.<slug>", "capped at 50, saved", "no other save field"], (110, 90, 220))
    arrow(draw, (360, 245), (460, 245), "grant_points")
    arrow(draw, (760, 245), (860, 245))
    arrow(draw, (1200, 245), (1290, 245), "spend_point")

    # Effects fan out from the rank.
    effects = [
        ((40, 470, 500, 640), "Soul light level 0..5", ["seen on the body in spirit sight", "duel words and replies use it", "see SPIRIT_SIGHT.md"], (186, 110, 226)),
        ((570, 470, 1030, 640), "Magic multiplier", ["1.0 + 0.02 x effective rank", "for the two elements of", "that aspect (section 4)"], (236, 210, 70)),
        ((1100, 470, 1560, 640), "Special riders", ["awareness: sight radius", "12 m + 4 m per level above 2", "light: resource.willpower pool"], (110, 90, 220)),
    ]
    hub = (1425, 330)
    for xy, title, lines, accent in effects:
        box(draw, xy, title, lines, accent)
        arrow(draw, hub, ((xy[0] + xy[2]) // 2, xy[1]))

    draw.text((40, 680), "Psyche states add temporary deltas at read time: effective rank = clamp(stored + deltas, 1, 50). They never rewrite the stored rank.", font=font(17), fill=DIM)
    draw.text((40, 712), "Spending fails closed: natural.fail.no_points, natural.fail.at_cap, natural.fail.unknown_aspect (nothing is applied).", font=font(17), fill=DIM)
    draw.text((40, 744), "NPCs have no ranks: their lights are authored (aura block) or derived deterministically from their id.", font=font(17), fill=DIM)
    image.convert("RGB").save(out / "point_flow.png", optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", default="docs/reports/images/natural")
    out = Path(parser.parse_args().out)
    out.mkdir(parents=True, exist_ok=True)
    hingepuu_map(out)
    rank_ladder(out)
    point_flow(out)
    print(f"wrote {out}/hingepuu_map.png, rank_ladder.png, point_flow.png")


if __name__ == "__main__":
    main()
