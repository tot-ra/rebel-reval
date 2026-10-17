"""Men's tunic range (EQ-21, task R-2023): gored wool tunics and the buttoned cotehardie.

Runs inside Blender with garments.py, which imports this module at its end so the
entries below replace the plain tunic builders in garments.WARDROBE (wool, short,
long, work and shirt tunic) and add `cotehardie`. Cut, after the clothing dossier
(history/dossiers/dailylife/clothing-and-status-markers.md) and the Herjolfsnes and
Bocksten tunics:

* Gores: the skirt's fullness sits in triangular gores let in at centre front, centre
  back and the sides (eight for the calf-length tunic), so the hem hangs in deep cones
  at the gores and flat over the panels instead of one even bell.
* Side slits from the hem, longer on longer tunics, bound like every other edge.
* Sleeves fitted to the wrist; crowd bodies carry a short row of pewter buttons above
  the wrist that the runtime shows on prestige p2 and p3 only
  (`CitizenWardrobe.BUTTONS`), named heroes when their spec says `sleeve_buttons`.
* The cotehardie of rich young men (1340s fashion): fitted body with a padded chest,
  short skirt at mid-thigh, buttoned from neck to hem and elbow to wrist, belt slung on
  the hips, the linen shirt's band at the neck.

Wear is a second UV map, `Wear` (glTF TEXCOORD_1, Godot UV2): U is rub (elbows, cuffs,
seat), V is nearness to a free edge (hems, cuffs, slits, neckline). The census cloth
shader turns them into elbow shine and frayed hems by the garment's wear cell
(scripts/city/citizen_cloth.gdshader, docs/SYSTEMS/CITIZEN_WARDROBE.md).
"""
import math

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

import garments as g
import surfaces

# Gore centres, degrees from centre front (+ is the body's left), and the angular
# half-width of each gore's fullness.
GORES_FOUR = (0.0, 90.0, 180.0, -90.0)
GORES_EIGHT = GORES_FOUR + (45.0, 135.0, -135.0, -45.0)
GORE_WIDTH_DEG = 13.0
# Side slit length (m) up from the hem, by hem length.
SLIT = {"thigh": 0.09, "knee": 0.15, "calf": 0.24}
# Wear UV falloffs (m): rub round the elbow joint, fray in from a free edge.
ELBOW_RUB = 0.07
EDGE_FRAY = 0.025
# Buttons: pewter on tunic sleeves, latten (brass) on the cotehardie; radius in metres.
PEWTER = (0.56, 0.55, 0.51)
LATTEN = (0.66, 0.52, 0.30)
BUTTON_RADIUS = 0.0045
# The crowd bake decimates any part over 64 faces; a chunk of 4 low spheres stays under it.
BUTTONS_PER_PART = 4


def gored_tunic(ctx, key, hem="knee", sleeve="full", extra_ease=0.0, belted=True, flare=1.55, folds=16,
                gores=GORES_FOUR, gore_depth=0.022, slit=True):
    """Gored wool tunic (Rock): fitted bodice, gored skirt, side slits, wear UVs.

    `hem`: thigh, knee or calf (length shows status and age); `sleeve`: full or rolled."""
    t = ctx.t
    color = ctx.palette(key, g.textiles_color("undyed"))
    wrist_x = t["wrist.l"].x
    sleeve_end = {"full": wrist_x + 0.012, "rolled": t["lowerarm.l"].x + 0.06}[sleeve]
    waist_z = t["spine"].z - 0.02
    shoulder = t["upperarm.l"].x + 0.02

    def ease(p):
        if abs(p.x) > shoulder:
            # Roomy at the upper arm, close at the forearm and wrist.
            along = min(1.0, (abs(p.x) - shoulder) / max(wrist_x - shoulder, 0.1))
            return 0.03 * (1 - along) + 0.007 * along + extra_ease * 0.5
        return 0.018 + extra_ease + 0.012 * surfaces.smoothstep(t["chest"].z, waist_z, p.z)
    obj = g.bodice(ctx, f"Garment_{key}", ease, sleeve_end, t["hips"].z + 0.02)
    hem_z = g.hem_height(ctx, hem)
    top_z = g.loft_skirt(ctx, obj, hem_z, flare=flare, fold_depth=0.012 * flare / 1.55, folds=folds, seed=3,
                         rings=10 if hem in ("thigh", "knee") else 16)
    add_gores(ctx, obj, top_z, hem_z, gores, gore_depth)
    # Blouse slightly over the belt.
    for v in obj.data.vertices:
        bump = math.exp(-((v.co.z - (waist_z + 0.03)) / 0.03) ** 2)
        if abs(v.co.x) < t["upperarm.l"].x:
            radial = Vector((v.co.x, v.co.y - t["hips"].y, 0))
            if radial.length > 1e-4:
                v.co += radial.normalized() * 0.008 * bump
    if slit:
        cut_slits(ctx, obj, hem_z + SLIT[hem], (90.0, -90.0))
    parts = finish_cloth(ctx, obj, key, color)
    if sleeve == "rolled":
        for s, sign in (("l", 1), ("r", -1)):
            parts.append(g.sleeve_roll(ctx, s, sign, sleeve_end, color))
    elif ctx.spec.get("sleeve_buttons"):
        tree = surface_tree(parts[0])
        for s in ("l", "r"):
            parts += sleeve_buttons(ctx, tree, s, 5, 0.0, 0.32, PEWTER, "tunic_buttons")
    if belted:
        parts += belt_over(ctx, parts[0], waist_z, knife=belted != "plain")
    return parts


def cotehardie(ctx):
    """Buttoned cotehardie (Kotte) of a rich young man, 1340s: close-fitting, padded at the
    chest, skirt to mid-thigh, buttons from neck to hem and elbow to wrist, belt on the hips."""
    t = ctx.t
    color = ctx.palette("cotehardie", g.textiles_color("undyed"))
    wrist_x = t["wrist.l"].x
    chest_z, waist_z, hips_z = t["chest"].z, t["spine"].z, t["hips"].z
    shoulder = t["upperarm.l"].x + 0.02

    def ease(p):
        if abs(p.x) > shoulder:
            along = min(1.0, (abs(p.x) - shoulder) / max(wrist_x - shoulder, 0.1))
            return 0.012 * (1 - along) + 0.004 * along
        # Padded, rounded chest in front; tight at the waist.
        front = surfaces.smoothstep(t["hips"].y + 0.02, t["hips"].y - 0.06, p.y)
        chest = math.exp(-((p.z - (chest_z + 0.04)) / 0.09) ** 2)
        # Below the waist it must still clear the braies' waistband and the hips in the stride.
        return 0.006 + 0.014 * chest * front + 0.02 * surfaces.smoothstep(waist_z, hips_z, p.z)
    # The sleeve runs a little over the back of the hand, as in the 1340s.
    obj = g.bodice(ctx, "Garment_cotehardie", ease, wrist_x + 0.03, hips_z + 0.02, iterations=8)
    hem_z = hips_z - 0.17
    top_z = g.loft_skirt(ctx, obj, hem_z, flare=1.35, fold_depth=0.007, folds=12, seed=7, rings=8)
    add_gores(ctx, obj, top_z, hem_z, GORES_FOUR, 0.012)
    parts = finish_cloth(ctx, obj, "cotehardie", color)
    tree = surface_tree(parts[0])
    parts += front_buttons(ctx, tree, obj, hem_z + 0.015, LATTEN, "cotehardie_buttons")
    for s in ("l", "r"):
        parts += sleeve_buttons(ctx, tree, s, 8, 0.05, 0.92, LATTEN, "cotehardie_buttons")
    # A belt slung low on the hips, not at the waist: the fashion of the young.
    parts += belt_over(ctx, parts[0], hips_z - 0.03, knife=True)
    parts.append(g.shirt_collar(ctx, ctx.palette("linen_shirt", g.textiles_color("linen"))))
    return parts


def shirt_tunic(ctx):
    """Knee tunic, belted with a pouch and no knife, over a linen shirt whose collar and cuffs show."""
    extra = ctx.spec.get("tunic_ease", 0.0) + 0.006
    return gored_tunic(ctx, "shirt_tunic", extra_ease=extra, belted=ctx.spec.get("belted", "plain")) + \
        g.under_shirt(ctx)


# Belt clearance over the cloth surface (m): garments.belt adds 2.4 cm to what it hits.
BELT_OVER_CLOTH = 0.005


def belt_over(ctx, cloth, z, knife):
    """garments.belt laid on the tunic's own surface, not the skin, so the blousing and the
    gores never swallow it; spec `belt_ease` still adds room (a roomy hand-me-down)."""
    skin = ctx.bvh
    ctx.bvh = surface_tree(cloth)
    try:
        return g.belt(ctx, z, knife=knife, ease=BELT_OVER_CLOTH - 0.024 + ctx.spec.get("belt_ease", 0.0) * 0.3,
                      knife_at=ctx.spec.get("knife_at", 8))
    finally:
        ctx.bvh = skin


# --------------------------------------------------------------------------
# Cut
# --------------------------------------------------------------------------

def _angle(co, axis_y):
    """Degrees round the body from centre front, + toward the body's left (loft_skirt's convention)."""
    return math.degrees(math.atan2(co.x, -(co.y - axis_y)))


def _wrap(a):
    return (a + 180.0) % 360.0 - 180.0


def add_gores(ctx, obj, top_z, hem_z, centres, depth):
    """Gather the skirt's fullness into gores: more flare at each gore centre, deepest at the hem.

    Radial only, so the loft's columns keep their angle (cut_slits finds them by angle)."""
    axis_y = ctx.t["hips"].y
    span = max(1e-3, top_z - hem_z)
    for v in obj.data.vertices:
        if v.co.z >= top_z - 1e-4:
            continue
        s = min(1.0, (top_z - v.co.z) / span)
        a = _angle(v.co, axis_y)
        fullness = sum(math.exp(-(_wrap(a - c) / GORE_WIDTH_DEG) ** 2) for c in centres)
        radial = Vector((v.co.x, v.co.y - axis_y, 0))
        if radial.length > 1e-4:
            v.co += radial.normalized() * depth * fullness * s ** 1.5


def cut_slits(ctx, obj, top_z, angles):
    """Slit the skirt open from the hem to `top_z` on the loft column nearest each angle.

    The column's edges are subdivided first so the bound edge keeps steps under the 4 cm
    hem_rolls accepts, then split and opened a few millimetres."""
    axis_y = ctx.t["hips"].y
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    skirt = [v for v in bm.verts if v.co.z < top_z]
    columns = []
    for target in angles:
        nearest = min(skirt, key=lambda v: abs(_wrap(_angle(v.co, axis_y) - target)))
        columns.append(_angle(nearest.co, axis_y))

    def on_column(v):
        return v.co.z < top_z + 1e-4 and any(abs(_wrap(_angle(v.co, axis_y) - c)) < 0.05 for c in columns)

    def seam():
        return [e for e in bm.edges if all(on_column(v) for v in e.verts)
                and abs(e.verts[0].co.z - e.verts[1].co.z) > 1e-3]
    bmesh.ops.subdivide_edges(bm, edges=seam(), cuts=2, use_grid_fill=False)
    bmesh.ops.split_edges(bm, edges=seam())
    for v in bm.verts:
        if v.is_boundary and v.link_faces and on_column(v) and v.co.z < top_z - 0.01:
            centre = sum((f.calc_center_median() for f in v.link_faces), Vector()) / len(v.link_faces)
            step = Vector((centre.x - v.co.x, centre.y - v.co.y, 0))
            if step.length > 1e-5:
                v.co += step.normalized() * 0.004
    bm.to_mesh(obj.data)
    bm.free()


def finish_cloth(ctx, obj, key, color):
    """Grain UVs, wear UVs, bound edges and the textile material of a wool garment shell."""
    edges = edge_tree(obj)
    g.grain_uv(ctx, obj, "wool")
    wear_uv(ctx, obj, edges)
    hems = g.hem_rolls(ctx, obj, 0.0035, key, "wool", color)
    parts = [g.finish(ctx, obj, "wool", color, key, thickness=0.003)]
    for hem in hems:
        parts.append(g.finish_hem(ctx, hem, "wool", color, key))
        wear_uv(ctx, hem, None)
    return parts


# --------------------------------------------------------------------------
# Wear UVs
# --------------------------------------------------------------------------

def edge_tree(obj):
    """KD tree of the free-edge vertices of a shell (hem, cuffs, slits, neckline)."""
    loops = g.boundary_loops(obj)
    points = [co for loop in loops for _, co in loop]
    tree = KDTree(max(1, len(points)))
    for i, co in enumerate(points):
        tree.insert(co, i)
    tree.balance()
    return tree if points else None


def rub_of(ctx, p):
    """0..1 rubbing of the cloth at rest position p: elbows, cuffs and the seat."""
    t = ctx.t
    rub = 0.0
    for s in ("l", "r"):
        rub = max(rub, math.exp(-((p - t[f"lowerarm.{s}"]).length / ELBOW_RUB) ** 2))
        if abs(p.x) > abs(t[f"wrist.{s}"].x) - 0.05 and p.x * t[f"wrist.{s}"].x > 0:
            rub = max(rub, 0.6)
    seat = surfaces.smoothstep(t["hips"].y + 0.02, t["hips"].y + 0.08, p.y) * \
        math.exp(-((p.z - (t["hips"].z - 0.06)) / 0.08) ** 2) * (1.0 - surfaces.smoothstep(0.1, 0.16, abs(p.x)))
    return max(rub, 0.8 * float(seat))


def wear_uv(ctx, obj, edges):
    """Second UV map `Wear`: U rub, V nearness to a free edge (1 on a bound edge itself)."""
    mesh = obj.data
    if not mesh.uv_layers:
        return
    layer = mesh.uv_layers.get("Wear") or mesh.uv_layers.new(name="Wear")
    values = []
    for v in mesh.vertices:
        p = obj.matrix_world @ v.co
        if edges is None:
            fray = 1.0
        else:
            _, _, distance = edges.find(p)
            fray = math.exp(-distance / EDGE_FRAY) if distance is not None else 0.0
        values.append((rub_of(ctx, p), fray))
    for loop in mesh.loops:
        layer.data[loop.index].uv = values[loop.vertex_index]


# --------------------------------------------------------------------------
# Buttons
# --------------------------------------------------------------------------

def surface_tree(obj):
    return BVHTree.FromObject(obj, bpy.context.evaluated_depsgraph_get())


def _button_parts(ctx, name, points, weights_of, color, key):
    """Low spheres at `points`, chunked so the crowd bake leaves them alone; each chunk's
    vertices take the bone weights `weights_of(point)` of the button they belong to."""
    parts = []
    for c in range(0, len(points), BUTTONS_PER_PART):
        bm = bmesh.new()
        owners = []
        for p in points[c:c + BUTTONS_PER_PART]:
            before = len(bm.verts)
            bmesh.ops.create_uvsphere(bm, u_segments=5, v_segments=3, radius=BUTTON_RADIUS,
                                      matrix=Matrix.Translation(p))
            owners += [p] * (len(bm.verts) - before)
        mesh = bpy.data.meshes.new(f"{name}_{c // BUTTONS_PER_PART}")
        bm.to_mesh(mesh)
        bm.free()
        obj = bpy.data.objects.new(mesh.name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        for v, owner in zip(obj.data.vertices, owners):
            for bone, w in weights_of(owner).items():
                group = obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone)
                group.add([v.index], w, "REPLACE")
        g.grain_uv(ctx, obj, "iron", override=lambda p: "torso")
        parts.append(g.finish(ctx, obj, "iron", color, key))
    return parts


def sleeve_buttons(ctx, tree, s, count, start, end, color, key):
    """A row along the top of the T-posed forearm (the outer seam once the arm hangs),
    from `start` to `end` of the way from the wrist to the elbow."""
    t = ctx.t
    wrist, elbow = t[f"wrist.{s}"], t[f"lowerarm.{s}"]
    points = []
    for k in range(count):
        p = wrist.lerp(elbow, start + (end - start) * k / max(1, count - 1))
        hit = tree.ray_cast(p + Vector((0, 0, 0.15)), Vector((0, 0, -1)), 0.3)
        top = hit[0] if hit[0] is not None else p + Vector((0, 0, 0.04))
        points.append(top + Vector((0, 0, BUTTON_RADIUS * 0.6)))
    return _button_parts(ctx, f"Garment_{key}_{s}", points, lambda p: {f"lowerarm.{s}": 1.0}, color, key)


def front_buttons(ctx, tree, shell, low_z, color, key):
    """Close-set buttons down the centre front, neckline to hem, about 3 cm apart."""
    t = ctx.t
    top_z = ctx.collar(t["hips"].y - 0.1) - 0.02
    count = max(2, int((top_z - low_z) / 0.03) + 1)
    points = []
    for k in range(count):
        z = top_z + (low_z - top_z) * k / (count - 1)
        hit = tree.ray_cast(Vector((0, t["hips"].y - 0.5, z)), Vector((0, 1, 0)), 1.0)
        if hit[0] is not None:
            points.append(hit[0] + Vector((0, -BUTTON_RADIUS * 0.6, 0)))
    near = KDTree(len(shell.data.vertices))
    for v in shell.data.vertices:
        near.insert(v.co, v.index)
    near.balance()
    names = {grp.index: grp.name for grp in shell.vertex_groups}

    def weights_of(p):
        _, index, _ = near.find(p)
        return {names[w.group]: w.weight for w in shell.data.vertices[index].groups
                if names[w.group] in g.BONE_NAMES}
    return _button_parts(ctx, f"Garment_{key}_front", points, weights_of, color, key)


# Replaces the plain tunic builders of garments.py (imported at its end).
WARDROBE = {
    "wool_tunic": ("torso", ["Anatomy_Torso", "Anatomy_Arms", "Anatomy_Forearms"],
                   lambda c: gored_tunic(c, "wool_tunic")),
    "work_tunic": ("torso", ["Anatomy_Torso", "Anatomy_Arms"],
                   lambda c: gored_tunic(c, "work_tunic", sleeve="rolled")),
    "long_tunic": ("torso", ["Anatomy_Torso", "Anatomy_Arms", "Anatomy_Forearms"],
                   lambda c: gored_tunic(c, "long_tunic", hem="calf", flare=1.7, folds=18, gores=GORES_EIGHT,
                                         gore_depth=0.026, belted=c.spec.get("belted", True))),
    "short_tunic": ("torso", ["Anatomy_Torso", "Anatomy_Arms", "Anatomy_Forearms"],
                    lambda c: gored_tunic(c, "short_tunic", hem="thigh", extra_ease=c.spec.get("tunic_ease", 0.0),
                                          belted=c.spec.get("belted", True), gore_depth=0.016)),
    "shirt_tunic": ("torso", ["Anatomy_Torso", "Anatomy_Arms", "Anatomy_Forearms"], shirt_tunic),
    "cotehardie": ("torso", ["Anatomy_Torso", "Anatomy_Arms", "Anatomy_Forearms"], cotehardie),
}
