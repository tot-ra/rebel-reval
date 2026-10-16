"""Linen that shows (EQ-22, task R-2024): the shirt's collar and cuffs, the chemise at the neck.

Runs inside Blender with garments.py, which imports this module at its end; `install`
replaces `garments.under_shirt` and `garments.shirt_collar` and wraps the base outfits of
the crowd bodies (citizen_bodies.py) so the linen worn under the wool shows where it did:

* Men wore a linen shirt (Hemd) under the tunic and linen braies under the hose
  (clothing dossier, history/dossiers/dailylife/clothing-and-status-markers.md). The shirt
  shows as a narrow band above the tunic's neckline and at the wrist past the wool sleeve.
* Women wore the chemise (smock, särk) under the gown and kirtle; its edge shows just above
  the gown's round neckline and, under the loose sleeves of the work gown and the gown, at
  the wrist. The fitted, buttoned kirtle sleeve covers the wrist, so it shows the neck only.

Only those edges are built: the shirt body under the wool is never seen on a crowd body and
would cost faces and clipping. The grade of the linen (coarse tow for the poor, yellowed or
sweat-stained, bleached fine linen for the rest) is picked at runtime by
`CitizenWardrobe.linen_grade` (scripts/city/citizen_wardrobe.gd); this module only cuts the
cloth and gives it linen-grain UVs, so the textile family stays `linen`.
"""
import math

import bmesh
import bpy
from mathutils import Vector

import garments as g

# Neck band rise above the collar plane and height (m). The man's shirt band stands above
# the tunic's neckline (garments.bodice cuts it 1.2 cm above the plane); the chemise edge
# is a lower, narrower line just over the gown's.
SHIRT_NECK = (0.019, 0.013)
CHEMISE_NECK = (0.019, 0.010)
# Ease over the skin (m) at the hidden edge (tucked under the wool, close to the skin so the
# wool's own neckline and sleeve end never poke through it) and at the open edge.
TUCKED_EASE = 0.001
OPEN_EASE = 0.0045
# Cuff span along the arm, measured from the wrist joint outward (m): it starts under the
# wool sleeve (which ends 1.2 cm past the wrist) and shows about 1 cm beyond it, flared
# so the wrist skin does not cut through it when the hand bends.
CUFF_SPAN = (-0.006, 0.022)
CUFF_SEGMENTS = 24


def _loft(name, rings):
    """Open tube through closed rings of equal length (first ring = tucked edge)."""
    bm = bmesh.new()
    grid = [[bm.verts.new(p) for p in ring] for ring in rings]
    n = len(rings[0])
    for r in range(len(grid) - 1):
        for a in range(n):
            b = (a + 1) % n
            bm.faces.new((grid[r][a], grid[r][b], grid[r + 1][b], grid[r + 1][a]))
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _open_hem(ctx, obj, color, is_open):
    """Rolled hem on the open edge only (`is_open(tube)`); the tucked edge is hidden."""
    hems = g.hem_rolls(ctx, obj, 0.002, "linen", "linen", color)
    keep = [is_open(h) for h in hems]
    for h, k in zip(hems, keep):
        if not k:
            bpy.data.objects.remove(h)
    return [g.finish_hem(ctx, h, "linen", color, "linen") for h, k in zip(hems, keep) if k]


def _join(target, parts):
    """Join `parts` into `target` (same linen material) and return it."""
    if not parts:
        return target
    bpy.ops.object.select_all(action="DESELECT")
    for o in [target, *parts]:
        o.select_set(True)
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.join()
    return target


def _mean(obj, axis):
    return sum(v.co[axis] for v in obj.data.vertices) / max(len(obj.data.vertices), 1)


def neck_band(ctx, name, color, rise, width, rings=4):
    """A linen band round the neck, its top edge `rise + width / 2` above the collar plane,
    tapering in to the skin at its tucked lower edge. The garment shells cannot reach that
    high (the neck skin is weighted to the head), so it is built round the neck by casting
    from the neck axis to the skin."""
    t, lm = ctx.t, ctx.lm
    front_y, back_y = lm["chin"][1] + 0.02, t["head"].y + 0.06
    axis_y = (front_y + back_y) / 2
    loops = []
    for r in range(rings):
        k = r / (rings - 1)
        dz = rise - width / 2 + width * k
        ease = TUCKED_EASE + (OPEN_EASE - TUCKED_EASE) * k ** 0.5
        ring = []
        for a in range(48):
            direction = g.horizontal(a / 48 * 2 * math.pi)
            y_edge = axis_y + direction.y * (back_y - front_y) / 2
            origin = Vector((0, axis_y, ctx.collar(y_edge) + dz))
            hit = ctx.bvh.ray_cast(origin + direction * 0.3, -direction)
            radius = (hit[0] - origin).length if hit[0] else 0.06
            ring.append(origin + direction * (radius + ease))
        loops.append(ring)
    obj = _loft(name, loops)
    chest = obj.vertex_groups.new(name="chest")
    head = obj.vertex_groups.new(name="head")
    chest.add([v.index for v in obj.data.vertices], 0.75, "REPLACE")
    head.add([v.index for v in obj.data.vertices], 0.25, "REPLACE")
    g.grain_uv(ctx, obj, "linen", override=lambda p: "torso")
    top = _mean(obj, 2)
    hems = _open_hem(ctx, obj, color, lambda h: _mean(h, 2) > top)
    band = g.finish(ctx, obj, "linen", color, "linen", 0.001)
    # One object (callers such as mens_dress.cotehardie append it as a single part).
    return _join(band, hems)


def shirt_collar(ctx, color):
    """The shirt's neck band above a man's tunic or cotehardie (replaces garments.shirt_collar)."""
    return neck_band(ctx, "Garment_shirt_collar", color, *SHIRT_NECK)


def _ring_radius(ctx, centre, direction, fallback=0.03):
    # Cast from inside the arm outward: only the arm's own skin can be hit.
    hit = ctx.bvh.ray_cast(centre, direction, 0.12)
    return (hit[0] - centre).length if hit[0] else fallback


def cuff(ctx, s, sign, color, span=CUFF_SPAN, rings=4):
    """A short open linen tube round one wrist, from under the wool sleeve (tucked close to
    the skin) to past its end, flared a little at the open edge, with a rolled hem there."""
    t = ctx.t
    elbow, wrist = t[f"lowerarm.{s}"], t[f"wrist.{s}"]
    axis = (wrist - elbow).normalized()
    side = axis.cross(Vector((0, 0, 1)))
    if side.length < 1e-4:
        side = axis.cross(Vector((0, 1, 0)))
    side.normalize()
    up = side.cross(axis).normalized()
    loops = []
    for r in range(rings):
        k = r / (rings - 1)
        centre = wrist + axis * (span[0] + (span[1] - span[0]) * k)
        # Tight while under the wool, opening only past the sleeve end.
        ease = TUCKED_EASE + (OPEN_EASE - TUCKED_EASE) * k ** 1.5 + 0.0035 * k ** 3
        ring = []
        for a in range(CUFF_SEGMENTS):
            angle = a / CUFF_SEGMENTS * 2 * math.pi
            d = side * math.cos(angle) + up * math.sin(angle)
            ring.append(centre + d * (_ring_radius(ctx, centre, d) + ease))
        loops.append(ring)
    obj = _loft(f"Garment_shirt_cuff_{s}", loops)
    # Skin weights under it: forearm at the tucked edge, wrist and hand at the open one.
    g.transfer_weights(ctx, obj)
    g.grain_uv(ctx, obj, "linen")
    hems = _open_hem(ctx, obj, color, lambda h: sign * _mean(h, 0) > abs(wrist.x) + 0.01)
    return [g.finish(ctx, obj, "linen", color, "linen", 0.001)] + hems


def cuffs(ctx, color):
    return cuff(ctx, "l", 1, color) + cuff(ctx, "r", -1, color)


def linen_color(ctx):
    return ctx.palette("linen_shirt", g.textiles_color("linen"))


def shirt_shows(ctx, wrists=True):
    """Collar and (when the wool sleeve is full) cuffs of the man's shirt."""
    color = linen_color(ctx)
    return [shirt_collar(ctx, color)] + (cuffs(ctx, color) if wrists else [])


def chemise_shows(ctx, wrists=True):
    """Neck edge and (under a loose sleeve) cuffs of the woman's chemise."""
    color = linen_color(ctx)
    parts = [neck_band(ctx, "Garment_chemise_neck", color, *CHEMISE_NECK)]
    return parts + (cuffs(ctx, color) if wrists else [])


def under_shirt(ctx):
    """Linen shirt under a tunic (replaces garments.under_shirt): the body stops inside the wool
    sleeve and short of the tunic hem; the collar and cuffs that show are built apart."""
    t = ctx.t
    obj = g.bodice(ctx, "Garment_under_shirt", lambda p: 0.004, t["wrist.l"].x + CUFF_SPAN[0] + 0.004,
                   t["hips"].z + 0.02, neck_raise=0.028, iterations=12)
    g.loft_skirt(ctx, obj, t["hips"].z - 0.1, flare=1.15, fold_depth=0.006, folds=12, seed=5)
    g.grain_uv(ctx, obj, "linen")
    return [g.finish(ctx, obj, "linen", linen_color(ctx), "linen", 0.002)] + shirt_shows(ctx)


# Base outfit garment -> what of the linen under it shows (citizen_bodies._spec).
SHOWS = {
    "short_tunic": lambda c: shirt_shows(c),
    "long_tunic": lambda c: shirt_shows(c),
    "work_gown": lambda c: chemise_shows(c),
    "gown": lambda c: chemise_shows(c),
    "kirtle": lambda c: chemise_shows(c, wrists=False),
}


def _with_linen(builder, shows):
    # The wool comes first: build_human registers parts[0] as the torso surface later layers clear.
    return lambda ctx: builder(ctx) + shows(ctx)


def install(wardrobe):
    """Patch garments (and through it mens_dress, which calls g.under_shirt / g.shirt_collar)."""
    g.under_shirt = under_shirt
    g.shirt_collar = shirt_collar
    for key, shows in SHOWS.items():
        if key not in wardrobe:
            continue  # a range not built yet (the kirtle ships with the women's dress range)
        slot, covered, builder = wardrobe[key]
        wardrobe[key] = (slot, covered, _with_linen(builder, shows))
