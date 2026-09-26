"""Tileable textile and material maps for realistic garments (ADR 0022).

Pure numpy (runs inside or outside Blender). Every map tiles: weave terms use
integer thread counts per tile and noise is synthesised in the frequency
domain, which is periodic by construction. Albedo is near-neutral so one set
serves every palette colour (the garment material multiplies it).

    python3 tools/assets/realistic_humans/textiles.py   # writes assets/characters/realistic/textiles/

Each family writes `<family>_albedo.png` (sRGB), `<family>_normal.png`
(tangent space, OpenGL +Y) and `<family>_orm.png` (R occlusion, G roughness,
B metallic), plus the tile's world size in metres in TILE_METRES.
"""
from pathlib import Path
import math
import zlib
import struct

import numpy as np

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets/characters/realistic/textiles"
SIZE = 1024

# World size of one texture tile; garment UVs are metres / tile.
TILE_METRES = {
    "wool": 0.09,
    "linen": 0.07,
    "leather": 0.22,
    "mail": 0.096,
    "quilted": 0.20,
    "iron": 0.30,
}


def periodic_noise(size, cutoff, seed, power=1.0):
    """Band-limited tileable noise in [-1, 1] (random phase spectrum)."""
    rng = np.random.default_rng(seed)
    fy = np.fft.fftfreq(size)[:, None] * size
    fx = np.fft.fftfreq(size)[None, :] * size
    radius = np.sqrt(fx * fx + fy * fy)
    amplitude = np.where(radius > 0, 1.0 / np.maximum(radius, 1.0) ** power, 0.0)
    amplitude *= np.exp(-(radius / cutoff) ** 2)
    phase = rng.uniform(0, 2 * np.pi, (size, size))
    field = np.real(np.fft.ifft2(amplitude * np.exp(1j * phase)))
    field -= field.mean()
    return field / (np.abs(field).max() + 1e-9)


def grid(size=SIZE):
    v, u = np.mgrid[0:size, 0:size].astype(np.float64) / size
    return u, v


def height_to_normal(height, strength):
    gx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * 0.5
    gy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * 0.5
    nx, ny = -gx * strength, gy * strength
    nz = np.ones_like(nx)
    n = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / n, ny / n, nz / n], -1) * 0.5 + 0.5


def cavity(height, radius=6):
    blur = height.copy()
    for _ in range(radius):
        blur = (blur + np.roll(blur, 1, 0) + np.roll(blur, -1, 0) + np.roll(blur, 1, 1) + np.roll(blur, -1, 1)) / 5
    return np.clip(1.0 + (height - blur) * 2.5, 0.0, 1.0)


def weave(u, v, threads_u, threads_v, twill):
    """Thread-level height for tabby (twill=0) or 2/2 twill (twill=2)."""
    tu = u * threads_u
    tv = v * threads_v
    iu, iv = np.floor(tu).astype(int), np.floor(tv).astype(int)
    fu, fv = tu - iu, tv - iv
    if twill:
        warp_up = ((iu + iv) % 4) < 2
    else:
        warp_up = ((iu + iv) % 2) == 0
    warp = np.sin(np.pi * fu) ** 0.7 * (0.55 + 0.45 * np.sin(np.pi * fv))
    weft = np.sin(np.pi * fv) ** 0.7 * (0.55 + 0.45 * np.sin(np.pi * fu))
    return np.where(warp_up, 0.6 + 0.4 * warp, 0.6 + 0.4 * weft) * np.where(warp_up, warp > 0.05, weft > 0.05)


def wool():
    u, v = grid()
    h = weave(u, v, 96, 96, twill=2) * 0.55
    slub = periodic_noise(SIZE, 40, 1) * 0.25
    fuzz = periodic_noise(SIZE, 380, 2, power=0.3) * 0.2
    felt = periodic_noise(SIZE, 12, 3)
    height = h * (0.75 + 0.25 * felt) + slub * 0.4 + fuzz
    tone = 0.62 + 0.10 * felt + 0.06 * slub + 0.05 * fuzz + 0.08 * (h - 0.5)
    albedo = np.stack([tone * 1.0, tone * 0.98, tone * 0.95], -1)
    rough = np.clip(0.9 + 0.05 * fuzz, 0, 1)
    return albedo, height_to_normal(height, 2.2), orm(cavity(height), rough, 0.0)


def linen():
    u, v = grid()
    irregular_u = u + periodic_noise(SIZE, 18, 4) * 0.004
    h = weave(irregular_u, v, 110, 104, twill=0)
    slub_warp = np.cos(2 * np.pi * np.floor(u * 110) / 7.3) * 0.15 + periodic_noise(SIZE, 60, 5) * 0.2
    height = h * 0.6 + slub_warp * 0.3
    crease = periodic_noise(SIZE, 9, 6)
    tone = 0.80 + 0.06 * slub_warp + 0.04 * crease + 0.05 * (h - 0.5)
    albedo = np.stack([tone, tone * 0.985, tone * 0.955], -1)
    rough = np.clip(0.82 + 0.06 * periodic_noise(SIZE, 30, 7), 0, 1)
    return albedo, height_to_normal(height, 1.8), orm(cavity(height), rough, 0.0)


def leather():
    grain = periodic_noise(SIZE, 260, 8, power=0.6)
    pores = np.clip(periodic_noise(SIZE, 420, 9, power=0.2), -1, -0.55) + 0.55
    creases = np.abs(periodic_noise(SIZE, 70, 10, power=0.8))
    creases = np.clip(1.0 - creases * 14.0, 0, 1) ** 2 * 0.6
    blotch = periodic_noise(SIZE, 8, 11)
    scuff = np.clip(periodic_noise(SIZE, 30, 12) * 2.0 - 0.9, 0, 1)
    height = grain * 0.35 + pores * 1.5 - creases * 0.8
    tone = 0.55 + 0.12 * blotch - 0.12 * creases + 0.18 * scuff + 0.05 * grain
    albedo = np.stack([tone, tone * 0.93, tone * 0.86], -1)
    rough = np.clip(0.62 - 0.12 * blotch + 0.2 * scuff + 0.08 * creases, 0.3, 0.95)
    return albedo, height_to_normal(height, 2.6), orm(cavity(height), rough, 0.0)


def mail():
    """Riveted 4-in-1 mail: staggered rows of overlapping, tilted rings."""
    u, v = grid()
    cols = 12                      # rings across one tile
    row_step = 0.5                 # rows every half ring spacing
    rows = int(round(cols / row_step))
    height = np.full((SIZE, SIZE), -1.0)
    ring_r, wire = 0.56, 0.085
    x = u * cols
    y = v * cols
    for j_off in (-2, -1, 0, 1, 2):
        j = np.floor(y / row_step) + j_off
        stagger = np.mod(j, 2) * 0.5
        for i_off in (-1, 0, 1):
            i = np.floor(x - stagger) + i_off
            cx = i + stagger + 0.5
            cy = j * row_step + 0.25
            px, py = x - cx, (y - cy) * 1.25
            d = np.sqrt(px * px + py * py)
            ring = np.clip(1.0 - np.abs(d - ring_r) / wire, 0, 1)
            # Each ring leans on the row above: its upper arc sits lower.
            lean = 0.5 - 0.35 * np.clip(py / ring_r, -1, 1)
            h = np.where(ring > 0, np.sqrt(ring) * 0.6 + lean * 0.4, -1.0)
            height = np.maximum(height, h)
    gap = height < 0.0
    height = np.clip(height, 0, None)
    occlusion = np.where(gap, 0.1, 0.45 + 0.55 * height)
    rust = np.clip(periodic_noise(SIZE, 25, 13) * 1.6 - 0.8, 0, 1)
    tone = np.where(gap, 0.04, 0.5 + 0.25 * height)
    albedo = np.stack([tone * (1 + 0.25 * rust), tone * (1 + 0.02 * rust), tone * (1 - 0.2 * rust)], -1)
    # Rings are sub-pixel at gameplay distance; a rougher lobe stands in for
    # the scattered highlights of thousands of small tori.
    rough = np.where(gap, 0.9, np.clip(0.5 + 0.3 * rust, 0, 1))
    metal = np.where(gap, 0.0, 1.0 - 0.6 * rust)
    return albedo, height_to_normal(height, 6.0), orm(occlusion, rough, metal)


def quilted():
    u, v = grid()
    canvas = weave(u, v, 150, 150, twill=0) * 0.25
    channels = 4  # quilting every 5 cm on a 20 cm tile, running along V
    phase = u * channels
    stitch = np.abs(phase - np.round(phase))
    puff = np.sin(np.clip(stitch * 2.0, 0, 1) * np.pi / 2) ** 0.6
    stitch_line = np.exp(-(stitch / 0.012) ** 2) * (np.mod(v * 90, 1.0) < 0.6)
    pucker = periodic_noise(SIZE, 30, 14) * 0.15 * puff
    height = puff * 4.0 + canvas + pucker - stitch_line * 0.6
    tone = 0.80 + 0.05 * periodic_noise(SIZE, 10, 15) - 0.22 * (1 - puff) - 0.25 * stitch_line
    albedo = np.stack([tone, tone * 0.97, tone * 0.9], -1)
    rough = np.full((SIZE, SIZE), 0.86)
    return albedo, height_to_normal(height, 3.5), orm(cavity(height, 10), rough, 0.0)


def iron():
    hammer = periodic_noise(SIZE, 55, 16, power=0.8)
    dents = -np.abs(periodic_noise(SIZE, 25, 17))
    rust = np.clip(periodic_noise(SIZE, 18, 18) * 1.8 - 0.7, 0, 1)
    height = hammer * 0.5 + dents * 0.8
    tone = 0.52 + 0.08 * hammer
    albedo = np.stack([tone * (1 + 0.35 * rust), tone * (1 - 0.05 * rust), tone * (1 - 0.3 * rust)], -1)
    # Forged, oiled iron: satin rather than mirror.
    rough = np.clip(0.48 + 0.35 * rust + 0.06 * hammer, 0, 1)
    metal = 1.0 - 0.7 * rust
    return albedo, height_to_normal(height, 1.8), orm(cavity(height), rough, metal)


def orm(occlusion, roughness, metallic):
    metallic = np.broadcast_to(np.asarray(metallic, dtype=np.float64), occlusion.shape)
    return np.stack([occlusion, roughness, metallic], -1)


def _png(path, rgb, srgb):
    rgb = np.clip(rgb, 0, 1)
    if srgb:
        rgb = np.where(rgb <= 0.0031308, rgb * 12.92, 1.055 * rgb ** (1 / 2.4) - 0.055)
    data = (rgb * 255 + 0.5).astype(np.uint8)[::-1]  # row 0 = top of the image
    raw = b"".join(b"\x00" + row.tobytes() for row in data)
    def chunk(tag, payload):
        return struct.pack(">I", len(payload)) + tag + payload + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)
    h, w = data.shape[:2]
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    path.write_bytes(png)


FAMILIES = {"wool": wool, "linen": linen, "leather": leather, "mail": mail, "quilted": quilted, "iron": iron}


def texture_paths(family):
    return {kind: OUT / f"{family}_{kind}.png" for kind in ("albedo", "normal", "orm")}


def write_all():
    OUT.mkdir(parents=True, exist_ok=True)
    for family, make in FAMILIES.items():
        albedo, normal, orm_map = make()
        paths = texture_paths(family)
        _png(paths["albedo"], albedo, srgb=True)
        _png(paths["normal"], normal, srgb=False)
        _png(paths["orm"], orm_map, srgb=False)
        print("wrote", family)


if __name__ == "__main__":
    write_all()
