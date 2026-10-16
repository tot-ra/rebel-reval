"""Women's wimple and barbette (EQ-27, task R-2029).

Runs inside Blender with garments.py, which imports this module at its end (its `wimple` and
`barbette` wardrobe entries call the builders here); the headscarf, head cloth, veil and braids stay in garments.py.

* `wimple`: the linen cloth that covers chin, throat and the hair's edge, pinned at the temples
  and falling to the collarbones; widows, elders and nuns (clothing dossier,
  history/dossiers/dailylife/clothing-and-status-markers.md). Only the brow-to-chin oval of
  the face is left open. A nun's black veil and a widow's linen veil go over it (`veil_over`).
* `barbette`: the linen band of a rich wife that runs under the chin and up before the ears
  to the crown (c. 1300-1350), worn under the veil so only the band across chin and cheeks
  shows. Burgher wives and noblewomen only; the Estonian wrap-skirt body never carries it.
"""
import math

import bmesh
import bpy
from mathutils import Vector

import garments as g

# Barbette: band width (m), how far before the head's centre the loop's plane lies (m, in
# front of the ears), the forward lean of the ray under the chin and the band's lift off the
# skin (m).
BAND_WIDTH = 0.024
BAND_FORWARD = 0.03
BAND_CHIN_LEAN = 0.6
BAND_LIFT = 0.006
BAND_STEPS = 48


def _centre(ctx):
    eyes_mid = Vector(((ctx.lm["eye_l"] + ctx.lm["eye_r"]) / 2).tolist())
    return Vector((0, ctx.t["head"].y + 0.01, eyes_mid.z + 0.01))


def _skin_radius(trees, origin, direction):
    """Outermost surface of `trees` along `direction` from a point inside the head."""
    far = origin + direction * 0.6
    best = 0.0
    for tree in trees:
        hit = tree.ray_cast(far, -direction)
        if hit[0] is not None:
            best = max(best, (hit[0] - origin).dot(direction))
    return best


def wimple(ctx):
    """Linen wimple: chin, throat and the hair's edge covered, face open from brow to lip."""
    return g.head_wrap(ctx, "Garment_wimple", "wimple", "linen", ctx.palette("wimple", (0.88, 0.86, 0.80)),
                       head_ease=0.012, hem_below_neck=0.03, face=(40, 20, -28), cape_ease=0.012,
                       hair=False, open_front=0, folds=0.004, cape=False)


def _band_path(ctx, trees):
    """Centre line of the barbette: a loop in the coronal plane before the ears, over the crown
    and under the chin, as points hugging the skin. `phi` runs from the crown (0) down the
    wearer's left side to the chin (180 degrees) and up the right; the ray leans forward
    toward the chin as it passes under it."""
    origin = _centre(ctx) + Vector((0, -BAND_FORWARD, 0))
    out = []
    for k in range(BAND_STEPS):
        phi = 2 * math.pi * k / BAND_STEPS
        lean = BAND_CHIN_LEAN * (1 - math.cos(phi)) / 2
        direction = Vector((math.sin(phi), -lean, math.cos(phi))).normalized()
        out.append(origin + direction * (_skin_radius(trees, origin, direction) + BAND_LIFT))
    return out


def barbette(ctx):
    """Band under the chin and up before the ears to the crown."""
    trees = [g.trunk_bvh(ctx)]
    path = _band_path(ctx, trees)
    centre = _centre(ctx)
    bm = bmesh.new()
    rows = []
    for k, p in enumerate(path):
        tangent = (path[min(k + 1, len(path) - 1)] - path[max(k - 1, 0)]).normalized()
        radial = (p - centre).normalized()
        across = tangent.cross(radial).normalized()  # band width lies on the skin
        half = BAND_WIDTH / 2
        rows.append((bm.verts.new(p - across * half), bm.verts.new(p + across * half)))
    for (a0, b0), (a1, b1) in zip(rows, rows[1:] + rows[:1]):
        bm.faces.new((a0, b0, b1, a1))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    mesh = bpy.data.meshes.new("Garment_barbette")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("Garment_barbette", mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.vertex_groups.new(name="head").add([v.index for v in obj.data.vertices], 1.0, "REPLACE")
    g.grain_uv(ctx, obj, "linen", override=lambda p: "head")
    return [g.finish(ctx, obj, "linen", ctx.palette("barbette", (0.90, 0.88, 0.82)), "barbette", 0.002)]

