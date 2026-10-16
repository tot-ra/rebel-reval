"""Men's hood with liripipe and dagged edge (EQ-26, task R-2028).

Runs inside Blender with garments.py, which imports this module at its end; `install` wraps
the `hood` entry of the wardrobe so the hood shows what a 1340s Gugel carried:

* The liripipe: the long tail of the hood's crown, hanging down the back past the cape. Every
  hood has one, tapering from a flat strap to a point (clothing dossier,
  history/dossiers/dailylife/clothing-and-status-markers.md; Bocksten hood).
* Dags: a ring of cut leaf tongues along the cape's hem, a mid-14th-c. fashion of the rich.
  Crowd bodies carry them as a separate surface (material `..._hood_dags`) that the runtime
  shows on prestige p3 only (`CitizenWardrobe.HOOD_DAGS`, docs/SYSTEMS/CITIZEN_WARDROBE.md),
  the way pewter sleeve buttons are shown on p2 and p3.

Friars' capuces (spec `hood_over`) keep the plain cape: the Dominican hood has no tail.
"""
import math
import zlib

import bmesh
import bpy
from mathutils import Vector

import garments as g

# Liripipe: length below the crown anchor (m), width and thickness at the root and the tip.
TAIL_LENGTH = 0.62
TAIL_WIDTH = (0.062, 0.018)
TAIL_THICK = (0.014, 0.007)
TAIL_STEPS = 16
# Lift off the cloth it lies on (m) so the tail never sinks into the cape.
TAIL_LIFT = 0.010
# Dags: tongues round the hem, their depth (m), count and the tongue's tip width share.
DAG_DEPTH = 0.085
DAG_COUNT = 32
DAG_FLARE = 0.006


def _mesh_object(name, bm):
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _outer_y(trees, x, z, y_from=0.7):
    """Backmost surface of `trees` at (x, z): ray in from behind (+Y) toward the front."""
    best = None
    for tree in trees:
        hit = tree.ray_cast(Vector((x, y_from, z)), Vector((0, -1, 0)))
        if hit[0] is not None and (best is None or hit[0].y > best):
            best = hit[0].y
    return best


def liripipe(ctx, hood_obj, color, key="hood"):
    """Tapering strap from the crown's back down the back; hangs on the cape and the back."""
    t, lm = ctx.t, ctx.lm
    trees = [g.trunk_bvh(ctx), g.BVHTree.FromObject(hood_obj, bpy.context.evaluated_depsgraph_get())]
    eyes_mid = Vector(((lm["eye_l"] + lm["eye_r"]) / 2).tolist())
    centre = Vector((0, t["head"].y + 0.01, eyes_mid.z + 0.01))
    # Root: the hood's back at 55 degrees up, where the cowl's point was sewn to a tail.
    direction = Vector((0, math.cos(math.radians(55)), math.sin(math.radians(55))))
    hit = None
    for tree in trees[1:]:
        hit = tree.ray_cast(centre + direction * 0.5, -direction)
        if hit[0] is not None:
            break
    if hit is None or hit[0] is None:
        return []
    root = hit[0]
    # Side it falls to: stable per body (crc32, never Python's salted hash).
    side = 1.0 if zlib.crc32(str(ctx.spec.get("fit", "")).encode()) % 2 else -1.0
    pts = []
    for k in range(TAIL_STEPS + 1):
        s = k / TAIL_STEPS
        z = root.z - TAIL_LENGTH * s
        # A slow sway to one side so the strap reads as hanging cloth, not a rod.
        x = 0.05 * math.sin(s * math.pi * 0.9) * side
        y = _outer_y(trees, x, z)
        y = (y if y is not None else root.y) + TAIL_LIFT
        if k == 0:
            y = max(y, root.y)
        pts.append(Vector((x, y, z)))
    # Cloth cannot climb: each step stays at or behind the one above on the back's slope.
    for k in range(1, len(pts)):
        pts[k].y = max(pts[k].y, pts[k - 1].y - 0.012)
    bm = bmesh.new()
    rings = []
    for k, p in enumerate(pts):
        s = k / TAIL_STEPS
        tangent = (pts[min(k + 1, len(pts) - 1)] - pts[max(k - 1, 0)]).normalized()
        across = tangent.cross(Vector((0, 1, 0))).normalized()  # strap width runs sideways
        out = across.cross(tangent).normalized()  # thickness runs away from the back
        w = (TAIL_WIDTH[0] + (TAIL_WIDTH[1] - TAIL_WIDTH[0]) * s) / 2
        d = (TAIL_THICK[0] + (TAIL_THICK[1] - TAIL_THICK[0]) * s) / 2
        ring = []
        for a in range(8):
            ang = a / 8 * 2 * math.pi
            ring.append(bm.verts.new(p + across * math.cos(ang) * w + out * math.sin(ang) * d))
        rings.append(ring)
    for r in range(len(rings) - 1):
        for a in range(8):
            b = (a + 1) % 8
            bm.faces.new((rings[r][a], rings[r][b], rings[r + 1][b], rings[r + 1][a]))
    bm.faces.new(rings[0])
    bm.faces.new(list(reversed(rings[-1])))
    obj = _mesh_object("Garment_hood_liripipe", bm)
    g.copy_nearest_weights(hood_obj, obj, [v.index for v in hood_obj.data.vertices])
    g.grain_uv(ctx, obj, "wool", override=lambda p: "torso")
    return [g.finish(ctx, obj, "wool", color, key)]


def dags(ctx, hood_obj, color):
    """Leaf tongues hanging from the cape's hem loop, each a little longer or shorter."""
    # The hood is solid (thickness and rim), so it has no open edge: read the hem as the lowest
    # outer vertex in each of 64 angular bins round the torso axis.
    axis = Vector((0, ctx.t["hips"].y, 0))
    low = min(v.co.z for v in hood_obj.data.vertices)
    bins = {}
    for v in hood_obj.data.vertices:
        if v.co.z > low + 0.02:
            continue
        a = math.atan2(v.co.x - axis.x, -(v.co.y - axis.y)) % (2 * math.pi)
        k = int(a / (2 * math.pi) * 64) % 64
        r = math.hypot(v.co.x - axis.x, v.co.y - axis.y)
        if k not in bins or r > bins[k][0]:
            bins[k] = (r, v.co.copy())
    if len(bins) < 48:
        return []
    hem = [(k, bins[k][1]) for k in sorted(bins)]
    n = len(hem)
    span = max(2, n // DAG_COUNT)
    centre = Vector((0, ctx.t["hips"].y, 0))
    bm = bmesh.new()
    for i in range(DAG_COUNT):
        base = [hem[(i * span + j) % n][1] for j in range(span + 1)]
        mid = sum(base, Vector()) / len(base)
        length = DAG_DEPTH * (0.85 + 0.3 * ((i * 7919) % 11) / 10)
        rows = [[b + Vector((0, 0, 0.004)) for b in base]]
        for share, narrow in ((0.5, 0.82), (0.82, 0.45)):
            row = []
            for b in base:
                p = mid + (b - mid) * narrow
                radial = Vector((p.x - centre.x, p.y - centre.y, 0))
                flare = radial.normalized() * DAG_FLARE * share if radial.length > 1e-5 else Vector()
                row.append(p + flare + Vector((0, 0, -length * share)))
            rows.append(row)
        tip = mid + Vector((0, 0, -length))
        radial = Vector((tip.x - centre.x, tip.y - centre.y, 0))
        if radial.length > 1e-5:
            tip += radial.normalized() * DAG_FLARE
        grid = [[bm.verts.new(p) for p in row] for row in rows]
        top = bm.verts.new(tip)
        for r in range(len(grid) - 1):
            for j in range(span):
                bm.faces.new((grid[r][j], grid[r][j + 1], grid[r + 1][j + 1], grid[r + 1][j]))
        for j in range(span):
            bm.faces.new((grid[-1][j], grid[-1][j + 1], top))
    obj = _mesh_object("Garment_hood_dags", bm)
    g.copy_nearest_weights(hood_obj, obj, [v.index for v in hood_obj.data.vertices])
    g.grain_uv(ctx, obj, "wool", override=lambda p: "torso")
    return [g.finish(ctx, obj, "wool", color, "hood_dags", 0.003)]


def _with_tail(builder):
    def build(ctx):
        parts = builder(ctx)
        if ctx.spec.get("hood_over"):
            return parts  # the friar's capuce
        color = ctx.palette("hood", (0.20, 0.27, 0.36))
        parts = parts + liripipe(ctx, parts[0], color)
        if ctx.spec.get("tier") == 2:
            parts += dags(ctx, parts[0], color)  # crowd layers; the runtime hides them below p3
        return parts
    return build


def install(wardrobe):
    slot, covered, builder = wardrobe["hood"]
    wardrobe["hood"] = (slot, covered, _with_tail(builder))
