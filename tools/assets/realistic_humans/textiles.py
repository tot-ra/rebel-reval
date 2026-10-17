"""Tileable textile and material maps for realistic garments (ADR 0022).

Pure numpy (runs inside or outside Blender). Every map tiles: weave terms use
integer thread counts per tile and noise is synthesised in the frequency
domain, which is periodic by construction. Albedo is near-neutral so one set
serves every palette colour (the garment material multiplies it).

    python3 tools/assets/realistic_humans/textiles.py   # writes assets/characters/realistic/textiles/

Each family writes `<family>_albedo.png` (sRGB), `<family>_normal.png`
(tangent space, OpenGL +Y) and `<family>_orm.png` (R occlusion, G roughness,
B metallic), plus the tile's world size in metres in TILE_METRES.

Cloth grades (R-1667, docs/SYSTEMS/CITIZEN_WARDROBE.md) are the crowd's quality
of cloth, independent of its dye: `<grade>_{albedo,normal,orm}_512.png` with
tiles in GRADE_TILE_METRES, plus one shared RGBA wear mask (`wear_mask_512.png`:
R mud spatter, G soot smudge, B flour dust, A stain blotches) that the runtime
cloth shader scales per resident. Only the crowd (Tier 2) uses them, so they are
synthesised at SIZE for clean thread aliasing and written at 512 px.

    python3 tools/assets/realistic_humans/textiles.py --grades   # grades and mask only
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

# Grade -> tile metres. Leather and quilted grades are their family sets above;
# the runtime mirror is CitizenWardrobe.GRADE_TILE (scripts/city/citizen_wardrobe.gd).
GRADE_TILE_METRES = {
    "homespun": 0.12,
    "broadcloth": 0.08,
    "scarlet": 0.06,
    "linen_fine": 0.05,
    "linen_coarse": 0.09,
    "linen_coarse_w1": 0.09,
    "linen_coarse_w2": 0.09,
    "fur": 0.12,
    "quilted_silk": 0.20,
}
GRADE_SIZE = 512
WEAR_TILE_METRES = 0.6


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


# Quilting channels per 20 cm tile (TILE_METRES["quilted"]): one every 4 cm, inside
# the 3-5 cm of surviving 14th-c. padded jacks (arms dossier item 4). Garment UVs put
# the channels along V: down the body, round the arms (garments.gambeson).
QUILT_CHANNELS = 5
# Running stitches per tile along a channel line (~6 mm a stitch, ~4 mm of it on the face).
QUILT_STITCHES = 34


def quilt_relief(seed, channels=QUILT_CHANNELS, stitches=QUILT_STITCHES, wobble=0.0035, lumps=0.22):
    """Height terms of a quilted padded garment: (puff, groove, stitch thread, height).

    Each channel is a padded tube between two hand-sewn stitch lines. The lines
    wander a little (sewn by eye), each channel is stuffed a little fuller or
    thinner, and the stuffing lies in lumps along it. All terms tile: integer
    channel and stitch counts, periodic noise."""
    u, v = grid()
    phase = (u + periodic_noise(SIZE, 6, seed) * wobble) * channels
    index = np.floor(phase).astype(int) % channels
    across = phase - np.floor(phase)                       # 0..1 across one channel
    fullness = np.random.default_rng(seed + 1).uniform(0.8, 1.15, channels)[index]
    lump = 1.0 + lumps * periodic_noise(SIZE, 14, seed + 2)
    tube = np.sqrt(np.clip(1.0 - (2.0 * across - 1.0) ** 2, 0, 1)) ** 0.75
    puff = tube * fullness * lump
    edge = np.minimum(across, 1.0 - across)                # 0 on a stitch line
    groove = np.exp(-(edge / 0.035) ** 2)
    dash = np.mod(v * stitches, 1.0)
    thread = np.exp(-(edge / 0.012) ** 2) * np.clip((0.68 - dash) * 12.0, 0, 1) * np.clip(dash * 12.0, 0, 1)
    # Wearing creases the padding across the channels (the jack bends at waist and elbow).
    # Smeared across the channels (U is image axis 1), so they read as bends, not worms.
    creases = streaks(periodic_noise(SIZE, 16, seed + 3, power=0.6), 40, 1)
    height = puff * 10.0 - groove * 2.5 + thread * 0.5 + creases * 0.5 * puff
    return puff, groove, thread, height


def quilted():
    """Undyed linen-canvas aketon face (the garment palette or dye tints it)."""
    u, v = grid()
    # 128 threads (1.6 mm) a tile: a whole number of pixels each, so no beat lines.
    canvas = weave(u + periodic_noise(SIZE, 20, 30) * 0.002, v, 128, 128, twill=0)
    slub = np.cos(2 * np.pi * np.floor(u * 128) / 6.7) * 0.12 + periodic_noise(SIZE, 50, 31) * 0.15
    puff, groove, thread, relief = quilt_relief(32)
    height = relief + canvas * 0.22 + slub * 0.12
    mottle = periodic_noise(SIZE, 9, 33)
    # Dirt settles in the stitch grooves; the crowns of the channels rub pale.
    tone = 0.82 + 0.04 * mottle + 0.04 * slub + 0.03 * (puff - 0.7) - 0.16 * groove
    albedo = np.stack([tone, tone * 0.975, tone * 0.93], -1)
    # Linen thread: a little lighter and less yellow than the canvas.
    albedo = albedo * (1 - thread[..., None] * 0.6) + thread[..., None] * 0.6 * np.array([0.86, 0.85, 0.82])
    rough = np.clip(0.84 + 0.06 * groove + 0.03 * mottle, 0, 1)
    return albedo, height_to_normal(height, 3.0), orm(cavity(height, 8), rough, 0.0)


def quilted_silk():
    """Silk-covered aketon of a knight (p3): smooth taffeta face, fuller channels, a sheen."""
    u, v = grid()
    taffeta = weave(u, v, 256, 256, twill=0)
    puff, groove, thread, relief = quilt_relief(36, wobble=0.0015, lumps=0.1)
    height = relief * 0.8 + taffeta * 0.05
    sheen = periodic_noise(SIZE, 7, 37)
    tone = 0.80 + 0.05 * sheen + 0.05 * (puff - 0.7) - 0.12 * groove
    albedo = np.stack([tone, tone * 0.98, tone * 0.96], -1)
    albedo = albedo * (1 - thread[..., None] * 0.5) + thread[..., None] * 0.5 * np.array([0.9, 0.86, 0.72])
    # Silk catches light on the crowns of the channels and dulls in the grooves.
    rough = np.clip(0.58 + 0.2 * groove - 0.04 * puff + 0.03 * sheen, 0, 1)
    return albedo, height_to_normal(height, 3.0), orm(cavity(height, 8), rough, 0.0)


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


# --------------------------------------------------------------------------
# Cloth grades (R-1667)
# --------------------------------------------------------------------------

def thread_values(u, count, seed, low, high):
    """One value per thread (periodic: `count` threads per tile)."""
    values = np.random.default_rng(seed).uniform(low, high, count)
    return values[np.floor(u * count).astype(int) % count]


def streaks(field, length, axis):
    """Box blur along one axis: nap and fur flow (periodic roll keeps it tiling)."""
    out = np.zeros_like(field)
    for k in range(-length, length + 1):
        out += np.roll(field, k, axis)
    out /= 2 * length + 1
    return out / (np.abs(out).max() + 1e-9)


def homespun():
    """Hand-spun, hand-woven tabby: lumpy uneven yarn, felted fuzz, pills, fleece flecks."""
    u, v = grid()
    wu = u + periodic_noise(SIZE, 24, 20) * 0.006
    wv = v + periodic_noise(SIZE, 24, 21) * 0.006
    thick = thread_values(wu, 40, 22, 0.55, 1.0) * thread_values(wv, 36, 23, 0.7, 1.0)
    h = weave(wu, wv, 40, 36, twill=0) * thick
    felt = periodic_noise(SIZE, 10, 24)
    fuzz = periodic_noise(SIZE, 300, 25, power=0.3)
    pills = np.clip(periodic_noise(SIZE, 140, 26, power=0.4) * 3.0 - 2.2, 0, 1)
    flecks = np.clip(periodic_noise(SIZE, 420, 27, power=0.2) * 4.0 - 3.0, 0, 1)
    mottle = periodic_noise(SIZE, 4, 28)  # uneven fulling and fleece colour, 3 cm blotches
    height = h * 0.7 + fuzz * 0.25 + pills * 0.8 + felt * 0.15
    tone = 0.56 + 0.08 * mottle + 0.12 * felt + 0.03 * (thick - 0.75) + 0.05 * (h - 0.5) - 0.25 * flecks + 0.06 * pills
    albedo = np.stack([tone, tone * 0.97, tone * 0.92], -1)
    rough = np.clip(0.94 + 0.04 * fuzz, 0, 1)
    return albedo, height_to_normal(height, 2.8), orm(cavity(height), rough, 0.0)


def broadcloth():
    """Fulled and napped twill: the felted face hides most of the weave."""
    u, v = grid()
    h = weave(u, v, 120, 120, twill=2) * 0.2
    nap = periodic_noise(SIZE, 220, 30, power=0.5)
    felt = periodic_noise(SIZE, 16, 31)
    height = h + nap * 0.35 + felt * 0.1
    tone = 0.66 + 0.05 * felt + 0.03 * nap
    albedo = np.stack([tone, tone * 0.985, tone * 0.96], -1)
    rough = np.clip(0.88 + 0.03 * nap, 0, 1)
    return albedo, height_to_normal(height, 1.4), orm(cavity(height), rough, 0.0)


def scarlet():
    """The costliest cloth: fulled, napped and sheared smooth; a combed nap gives a soft sheen."""
    u, v = grid()
    nap = streaks(periodic_noise(SIZE, 300, 32, power=0.3), 8, 0)
    h = weave(u, v, 160, 160, twill=2) * 0.06
    felt = periodic_noise(SIZE, 14, 33)
    height = nap * 0.3 + h + felt * 0.05
    tone = 0.72 + 0.03 * nap + 0.02 * felt
    albedo = np.stack([tone, tone * 0.99, tone * 0.97], -1)
    rough = np.clip(0.72 + 0.04 * nap, 0, 1)
    return albedo, height_to_normal(height, 1.0), orm(cavity(height), rough, 0.0)


def linen_fine():
    """Bleached fine tabby for shirts, veils and coifs of the well-off."""
    u, v = grid()
    h = weave(u + periodic_noise(SIZE, 18, 34) * 0.002, v, 150, 144, twill=0)
    slub = periodic_noise(SIZE, 60, 35) * 0.1
    height = h * 0.5 + slub * 0.3
    tone = 0.86 + 0.03 * slub + 0.03 * (h - 0.5)
    albedo = np.stack([tone, tone * 0.99, tone * 0.97], -1)
    rough = np.clip(0.78 + 0.04 * periodic_noise(SIZE, 30, 36), 0, 1)
    return albedo, height_to_normal(height, 1.5), orm(cavity(height), rough, 0.0)


def linen_coarse():
    """Unbleached tow linen: thick uneven threads, slubs and dark shive flecks."""
    u, v = grid()
    wu = u + periodic_noise(SIZE, 20, 37) * 0.005
    thick = thread_values(wu, 56, 38, 0.5, 1.0)
    h = weave(wu, v, 56, 52, twill=0) * thick
    slub = periodic_noise(SIZE, 50, 39) * 0.3
    shives = np.clip(periodic_noise(SIZE, 380, 40, power=0.2) * 4.0 - 3.1, 0, 1)
    height = h * 0.7 + slub * 0.3
    tone = 0.70 + 0.08 * slub + 0.03 * (thick - 0.75) + 0.04 * (h - 0.5) - 0.3 * shives
    albedo = np.stack([tone, tone * 0.96, tone * 0.88], -1)
    rough = np.clip(0.9 + 0.04 * slub, 0, 1)
    return albedo, height_to_normal(height, 2.4), orm(cavity(height), rough, 0.0)


def fur():
    """Pelt: strands flowing along V in clumps, darker at the roots."""
    strands = streaks(periodic_noise(SIZE, 420, 41, power=0.1), 10, 0)
    clumps = periodic_noise(SIZE, 20, 42)
    height = strands * 0.6 + clumps * 0.4
    tone = 0.5 + 0.16 * strands + 0.12 * clumps
    albedo = np.stack([tone, tone * 0.92, tone * 0.82], -1)
    rough = np.clip(0.68 + 0.08 * strands, 0, 1)
    return albedo, height_to_normal(height, 2.0), orm(cavity(height, 4), rough, 0.0)


# Worn coarse linen (task R-2024, EQ-22): the poor's tow shirt, braies and chemise. Variant
# wear after docs/SYSTEMS/EQUIPMENT_VARIANTS.md: w1 yellowed (unbleached tow greys and yellows
# with lye washing and smoke), w2 sweat-stained (tide-lined blotches where it lies on the
# skin). Fine bleached linen is the w0 of the well-off (`linen_fine`). Only the albedo
# changes: the weave (normal, ORM) stays the plain linen_coarse set, which the runtime
# reuses (CitizenWardrobe.GRADE_BASE).
LINEN_WEAR = {"linen_coarse_w1": 1, "linen_coarse_w2": 2}


def linen_coarse_worn(level):
    """Albedo of coarse linen at wear `level` 1 (yellowed) or 2 (sweat-stained)."""
    albedo = linen_coarse()[0]
    # Yellowing is uneven: folds and the parts washed less often stay darker.
    mottle = periodic_noise(SIZE, 4, 60 + level)
    yellow = np.array([0.97, 0.93, 0.80]) if level == 1 else np.array([0.93, 0.87, 0.72])
    albedo = albedo * yellow * (1.0 + 0.05 * mottle[..., None])
    if level == 2:
        # Broad soft blotches with a darker dried salt line at their edge; low frequency, so
        # on a 9 cm tile they read as stains, not a pattern.
        blot = periodic_noise(SIZE, 7, 62, power=1.0) + 0.35 * periodic_noise(SIZE, 30, 63)
        sweat = np.clip((blot - 0.05) / 0.5, 0, 1) ** 1.5
        rim = np.exp(-((blot - 0.08) / 0.05) ** 2) * (0.5 + 0.5 * periodic_noise(SIZE, 12, 64))
        albedo = albedo * (1 - sweat[..., None] * np.array([0.05, 0.08, 0.18])) \
            * (1 - np.clip(rim, 0, 1)[..., None] * np.array([0.03, 0.05, 0.10]))
    return np.clip(albedo, 0, 1)


def write_linen_wear():
    """Writes `<grade>_albedo_512.png` for each worn coarse linen grade."""
    half = int(round(math.log2(SIZE // GRADE_SIZE)))
    for grade, level in LINEN_WEAR.items():
        albedo = linen_coarse_worn(level)
        for _ in range(half):
            albedo = _half(albedo)
        _png(texture_paths(grade, GRADE_SIZE)["albedo"], albedo, srgb=True)
        print("wrote linen wear", grade)


def wear_mask():
    """Shared RGBA wear mask, linear: R mud spatter, G soot smudge, B flour dust, A stains."""
    splash = np.clip(periodic_noise(SIZE, 45, 43, power=0.3) * 3.0 - 0.9, 0, 1)
    mud = np.clip(splash * (0.4 + 0.6 * np.clip(periodic_noise(SIZE, 8, 44) + 0.4, 0, 1))
                  + 0.25 * np.clip(periodic_noise(SIZE, 12, 45) + 0.2, 0, 1), 0, 1)
    soot = np.clip(periodic_noise(SIZE, 6, 46) * 1.5 + 0.4, 0, 1) * (0.7 + 0.3 * periodic_noise(SIZE, 60, 47))
    dust = np.clip(periodic_noise(SIZE, 5, 48) + 0.5, 0, 1) * 0.6
    flour = np.clip(dust + np.clip(periodic_noise(SIZE, 350, 49, power=0.2) * 3.0 - 1.5, 0, 1) * 0.4, 0, 1)
    blot = periodic_noise(SIZE, 12, 50)
    stain = np.clip((blot - 0.25) / 0.2, 0, 1)
    rim = np.exp(-((blot - 0.27) / 0.03) ** 2)  # tide line where a stain dried
    stain = np.clip(stain * 0.7 + rim * 0.6, 0, 1)
    return np.stack([mud, np.clip(soot, 0, 1), flour, stain], -1)


GRADES = {
    "homespun": homespun,
    "broadcloth": broadcloth,
    "scarlet": scarlet,
    "linen_fine": linen_fine,
    "linen_coarse": linen_coarse,
    "fur": fur,
    "quilted_silk": quilted_silk,
}


def orm(occlusion, roughness, metallic):
    metallic = np.broadcast_to(np.asarray(metallic, dtype=np.float64), occlusion.shape)
    return np.stack([occlusion, roughness, metallic], -1)


def _png(path, rgb, srgb):
    rgb = np.clip(rgb, 0, 1)
    if srgb:
        assert rgb.shape[2] == 3, "only colour maps are sRGB"
        rgb = np.where(rgb <= 0.0031308, rgb * 12.92, 1.055 * rgb ** (1 / 2.4) - 0.055)
    data = (rgb * 255 + 0.5).astype(np.uint8)[::-1]  # row 0 = top of the image
    colour_type = 6 if data.shape[2] == 4 else 2  # RGBA or RGB
    raw = b"".join(b"\x00" + row.tobytes() for row in data)
    def chunk(tag, payload):
        return struct.pack(">I", len(payload)) + tag + payload + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)
    h, w = data.shape[:2]
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, colour_type, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    path.write_bytes(png)


FAMILIES = {"wool": wool, "linen": linen, "leather": leather, "mail": mail, "quilted": quilted, "iron": iron}


def texture_paths(family, size=SIZE):
    """Maps for a family; `size` 512 selects the crowd (Tier 2) copies."""
    suffix = "" if size >= SIZE else f"_{size}"
    return {kind: OUT / f"{family}_{kind}{suffix}.png" for kind in ("albedo", "normal", "orm")}


def _half(img):
    return img.reshape(img.shape[0] // 2, 2, img.shape[1] // 2, 2, img.shape[2]).mean(axis=(1, 3))


def _write_set(paths, albedo, normal, orm_map, half):
    """Writes one albedo/normal/orm set, box-filtered `half` times (normals renormalised)."""
    for _ in range(half):
        albedo, orm_map = _half(albedo), _half(orm_map)
        normal = _half(normal * 2 - 1)
        normal = normal / np.linalg.norm(normal, axis=-1, keepdims=True) * 0.5 + 0.5
    _png(paths["albedo"], albedo, srgb=True)
    _png(paths["normal"], normal, srgb=False)
    _png(paths["orm"], orm_map, srgb=False)


def write_grades():
    OUT.mkdir(parents=True, exist_ok=True)
    half = int(round(math.log2(SIZE // GRADE_SIZE)))
    for grade, make in GRADES.items():
        _write_set(texture_paths(grade, GRADE_SIZE), *make(), half)
        print("wrote grade", grade)
    mask = wear_mask()
    for _ in range(half):
        mask = _half(mask)
    _png(OUT / f"wear_mask_{GRADE_SIZE}.png", mask, srgb=False)
    print("wrote wear mask")
    write_linen_wear()


def write_all():
    OUT.mkdir(parents=True, exist_ok=True)
    for family, make in FAMILIES.items():
        albedo, normal, orm_map = make()
        paths = texture_paths(family)
        _png(paths["albedo"], albedo, srgb=True)
        _png(paths["normal"], normal, srgb=False)
        _png(paths["orm"], orm_map, srgb=False)
        small = texture_paths(family, SIZE // 2)
        _png(small["albedo"], _half(albedo), srgb=True)
        normal_small = _half(normal * 2 - 1)
        normal_small /= np.linalg.norm(normal_small, axis=-1, keepdims=True)
        _png(small["normal"], normal_small * 0.5 + 0.5, srgb=False)
        _png(small["orm"], _half(orm_map), srgb=False)
        print("wrote", family)


if __name__ == "__main__":
    import sys
    if "--grades" not in sys.argv:
        write_all()
    write_grades()
