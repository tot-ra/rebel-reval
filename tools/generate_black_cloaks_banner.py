#!/usr/bin/env python3
"""Deterministic Black Cloaks swallow banner albedo for wall hangings.

Leonardo / image-to-3D is unavailable in this session, so the cloth is authored
as a crisp heraldic embroidery plate: white linen field, Estonian blue swallow
charge, and black stitch outlining. The silhouette follows the logo TR swallow
(forked tail, swept wings) at a resolution that stays legible on a ~0.6 m cloth.
"""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


SIZE = 1024
# Estonian national palette accents on the brand white field.
LINEN = (244, 242, 236)
LINEN_SHADOW = (228, 224, 214)
ESTONIAN_BLUE = (0, 114, 206)
ESTONIAN_BLUE_DEEP = (0, 82, 156)
BLACK_STITCH = (18, 18, 22)
THREAD_BLUE = (20, 96, 176)
THREAD_BLACK = (32, 32, 36)

DEFAULT_OUTPUT = Path("assets/heraldry/black_cloaks_banner.png")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _point_on_cubic(
    p0: tuple[float, float],
    p1: tuple[float, float],
    p2: tuple[float, float],
    p3: tuple[float, float],
    t: float,
) -> tuple[float, float]:
    u = 1.0 - t
    x = u * u * u * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t * t * t * p3[0]
    y = u * u * u * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t * t * t * p3[1]
    return (x, y)


def _sample_cubic(
    p0: tuple[float, float],
    p1: tuple[float, float],
    p2: tuple[float, float],
    p3: tuple[float, float],
    steps: int = 28,
) -> list[tuple[float, float]]:
    return [_point_on_cubic(p0, p1, p2, p3, i / steps) for i in range(steps + 1)]


def _scale_points(
    points: list[tuple[float, float]], size: int
) -> list[tuple[float, float]]:
    return [(x * size, y * size) for x, y in points]


def swallow_polygon(size: int) -> list[tuple[float, float]]:
    """Closed heraldic swallow in flight, head toward the fly (right)."""
    # Normalized UV space. Body center ~ (0.52, 0.48).
    upper_wing = _sample_cubic((0.34, 0.48), (0.28, 0.28), (0.42, 0.14), (0.58, 0.22))
    head = _sample_cubic((0.58, 0.22), (0.68, 0.28), (0.74, 0.40), (0.70, 0.48))
    beak = [(0.70, 0.48), (0.78, 0.50), (0.70, 0.52)]
    lower_head = _sample_cubic((0.70, 0.52), (0.66, 0.60), (0.58, 0.66), (0.50, 0.62))
    lower_wing = _sample_cubic((0.50, 0.62), (0.38, 0.78), (0.26, 0.70), (0.32, 0.54))
    # Forked tail toward the hoist (left).
    tail_lower = _sample_cubic((0.32, 0.54), (0.22, 0.58), (0.12, 0.66), (0.08, 0.72))
    tail_notch = [(0.08, 0.72), (0.18, 0.50), (0.08, 0.28)]
    tail_upper = _sample_cubic((0.08, 0.28), (0.14, 0.34), (0.24, 0.40), (0.34, 0.48))
    ring: list[tuple[float, float]] = []
    for part in (
        upper_wing,
        head,
        beak,
        lower_head,
        lower_wing,
        tail_lower,
        tail_notch,
        tail_upper,
    ):
        if ring and part and part[0] == ring[-1]:
            ring.extend(part[1:])
        else:
            ring.extend(part)
    return _scale_points(ring, size)


def wing_stitch_paths(size: int) -> list[list[tuple[float, float]]]:
    paths = [
        _sample_cubic((0.40, 0.40), (0.36, 0.30), (0.44, 0.22), (0.54, 0.26)),
        _sample_cubic((0.42, 0.44), (0.38, 0.34), (0.46, 0.26), (0.55, 0.30)),
        _sample_cubic((0.40, 0.56), (0.34, 0.64), (0.40, 0.72), (0.50, 0.66)),
        _sample_cubic((0.42, 0.54), (0.36, 0.60), (0.42, 0.68), (0.50, 0.62)),
        _sample_cubic((0.28, 0.44), (0.20, 0.40), (0.14, 0.36), (0.12, 0.34)),
        _sample_cubic((0.28, 0.52), (0.20, 0.56), (0.14, 0.62), (0.12, 0.66)),
    ]
    return [_scale_points(path, size) for path in paths]


def linen_field(size: int) -> Image.Image:
    img = Image.new("RGB", (size, size), LINEN)
    px = img.load()
    for y in range(size):
        for x in range(size):
            # Soft woven grain so the cloth does not read as flat plastic.
            weave = 0.0
            if (x + y * 3) % 7 == 0:
                weave = -4.0
            elif (x * 2 + y) % 11 == 0:
                weave = 3.0
            shade = 1.0 - 0.04 * ((x / size - 0.5) ** 2 + (y / size - 0.5) ** 2) * 4.0
            r = int(max(0, min(255, LINEN[0] * shade + weave)))
            g = int(max(0, min(255, LINEN[1] * shade + weave)))
            b = int(max(0, min(255, LINEN[2] * shade + weave * 0.8)))
            px[x, y] = (r, g, b)
    return img


def draw_thread_border(draw: ImageDraw.ImageDraw, size: int) -> None:
    margin = int(size * 0.055)
    # Blue outer stitch, black inner stitch - Estonian blue/black thread on white.
    for inset, color, width in (
        (0, THREAD_BLUE, max(2, size // 220)),
        (int(size * 0.012), THREAD_BLACK, max(2, size // 256)),
        (int(size * 0.024), THREAD_BLUE, max(1, size // 300)),
    ):
        box = [margin + inset, margin + inset, size - margin - inset, size - margin - inset]
        draw.rectangle(box, outline=color, width=width)


def draw_swallow(base: Image.Image) -> Image.Image:
    size = base.width
    poly = swallow_polygon(size)
    # Soft under-layer so the charge sits in the linen rather than floating.
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_poly = [(x + size * 0.008, y + size * 0.01) for x, y in poly]
    shadow_draw.polygon(shadow_poly, fill=(40, 36, 30, 48))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=size * 0.006))
    composed = Image.alpha_composite(base.convert("RGBA"), shadow)

    charge = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    charge_draw = ImageDraw.Draw(charge)
    charge_draw.polygon(poly, fill=ESTONIAN_BLUE + (255,))
    # Slight tonal depth across the body.
    overlay = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    overlay_draw = ImageDraw.Draw(overlay)
    body = [
        (size * 0.34, size * 0.46),
        (size * 0.58, size * 0.36),
        (size * 0.66, size * 0.48),
        (size * 0.52, size * 0.58),
        (size * 0.36, size * 0.54),
    ]
    overlay_draw.polygon(body, fill=ESTONIAN_BLUE_DEEP + (70,))
    charge = Image.alpha_composite(charge, overlay)

    # Black embroidery outline and wing stitches.
    outline = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    outline_draw = ImageDraw.Draw(outline)
    stroke = max(3, size // 140)
    outline_draw.line(poly + [poly[0]], fill=BLACK_STITCH + (255,), width=stroke, joint="curve")
    for path in wing_stitch_paths(size):
        outline_draw.line(path, fill=BLACK_STITCH + (220,), width=max(2, size // 220), joint="curve")
    # Eye highlight as a tiny stitch knot.
    eye_r = max(2, size // 180)
    outline_draw.ellipse(
        [
            size * 0.66 - eye_r,
            size * 0.44 - eye_r,
            size * 0.66 + eye_r,
            size * 0.44 + eye_r,
        ],
        fill=BLACK_STITCH + (255,),
    )

    composed = Image.alpha_composite(composed, charge)
    composed = Image.alpha_composite(composed, outline)
    return composed.convert("RGB")


def _charge_hatch(banner: Image.Image) -> Image.Image:
    """Fine diagonal stitch hatch clipped to the Estonian-blue swallow charge."""
    size = banner.width
    rgba = banner.convert("RGBA")
    hatch = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(hatch)
    step = max(5, size // 140)
    for i in range(-size, size * 2, step):
        draw.line([(i, 0), (i + size, size)], fill=(0, 40, 90, 30), width=1)
    for i in range(-size, size * 2, step * 2):
        draw.line([(i, size), (i + size, 0)], fill=(10, 10, 14, 24), width=1)
    mask = Image.new("L", (size, size), 0)
    mask_px = mask.load()
    banner_px = banner.load()
    for y in range(size):
        for x in range(size):
            r, g, b = banner_px[x, y]
            if b > 140 and r < 90:
                mask_px[x, y] = 255
    alpha = hatch.split()[-1]
    hatch.putalpha(Image.composite(alpha, Image.new("L", (size, size), 0), mask))
    return Image.alpha_composite(rgba, hatch).convert("RGB")


def build_banner(size: int = SIZE) -> Image.Image:
    field = linen_field(size)
    draw = ImageDraw.Draw(field)
    draw_thread_border(draw, size)
    # Corner flecks of black/blue thread to sell embroidery without clutter.
    for cx, cy in (
        (0.12, 0.12),
        (0.88, 0.12),
        (0.12, 0.88),
        (0.88, 0.88),
    ):
        x = int(cx * size)
        y = int(cy * size)
        draw.line([(x - 8, y), (x + 8, y)], fill=THREAD_BLACK, width=2)
        draw.line([(x, y - 8), (x, y + 8)], fill=THREAD_BLUE, width=2)
    banner = draw_swallow(field)
    banner = _charge_hatch(banner)
    # Soften linen nap without blurring the embroidered charge edge.
    return banner.filter(ImageFilter.SMOOTH)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--size", type=int, default=SIZE)
    args = parser.parse_args()

    banner = build_banner(args.size)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    banner.save(args.output, format="PNG", optimize=True)
    digest = sha256(args.output)
    print(f"wrote {args.output} ({args.output.stat().st_size} bytes) sha256={digest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
