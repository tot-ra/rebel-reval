"""Historically grounded garments fitted to a realistic human (ADR 0022).

Runs inside Blender from build_human.py. Every garment is generated against
the character's own rest body, so it is fitted to that body only
(CharacterWearable.fitted_body). Construction follows the Spring-1343 Reval
brief in history/dossiers/dailylife/clothing-and-status-markers.md:
linen shirt, gored wool tunic with belt, separate wool hose, turned ankle
boots, forge apron, hood with shoulder cape (Gugel), quilted aketon, riveted
mail haubergeon and a kettle hat.

Method:
* Fitted parts (bodice, sleeves, hose) are shells lifted off the body along
  its normals, then relaxed: Laplacian smoothing removes anatomy, a
  closest-point push keeps the ease, so cloth spans hollows instead of
  following every muscle.
* Skirts are lofted from the bodice's cut edge, flared as gored panels, with
  folds deepening toward the hem.
* UVs follow the cloth grain on cylinders (torso, each sleeve, each leg) with
  the wrap seam where a tailor puts it: centre back, under the arm, inside
  the leg. Tiling textile maps give a constant world-scale weave.
* Weights: shells inherit the body's; skirts blend hips and both thighs by
  side and depth so the hem follows the stride without splitting.
"""
from dataclasses import dataclass, field
from pathlib import Path
import math

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

import surfaces
import textiles

LEG_BONES = ("upperleg", "lowerleg", "foot", "toes")


@dataclass
class Ctx:
    spec: dict
    body: bpy.types.Object          # unsplit rest body with shared weights
    rig: bpy.types.Object
    t: dict                         # joint targets (Vector) in rest space
    lm: dict                        # face landmarks (numpy)
    collar: callable                # z of the neckline plane for a given y
    out: Path
    bvh: BVHTree = None
    materials: dict = field(default_factory=dict)
    # Worn layers other garments must sit over (garment id -> BVHTree).
    layers: dict = field(default_factory=dict)

    def palette(self, key, default):
        return tuple(self.spec.get("palette", {}).get(key, default))


# --------------------------------------------------------------------------
# Geometry helpers
# --------------------------------------------------------------------------

def dominant_bone(obj, vertex):
    best, weight = None, -1.0
    for g in vertex.groups:
        name = obj.vertex_groups[g.group].name
        if g.weight > weight and name in BONE_NAMES:
            best, weight = name, g.weight
    return best or "hips"


BONE_NAMES = {"hips", "spine", "chest", "head"} | {
    f"{b}.{s}" for s in ("l", "r") for b in
    ("upperarm", "lowerarm", "wrist", "hand", "upperleg", "lowerleg", "foot", "toes")}
# Finger weights fold into the hand for garments (no gloves are generated yet).
FINGER_BONES = {f"{f}_0{i}.{s}" for s in ("l", "r") for f in ("thumb", "index", "middle", "ring", "pinky")
                for i in (1, 2, 3)}


NIPPLE_GROUPS = ("nipple", "nippleTip")


def extract_shell(ctx, name, keep):
    """Copy the body faces whose vertices all satisfy keep(vertex, bone)."""
    body = ctx.body
    flags = [keep(v, dominant_bone(body, v)) for v in body.data.vertices]
    obj = body.copy()
    obj.data = body.data.copy()
    obj.name = name
    obj.data.name = name
    obj.modifiers.clear()
    bpy.context.scene.collection.objects.link(obj)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    doomed = [f for f in bm.faces if not all(flags[v.index] for v in f.verts)]
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()
    for group in list(obj.vertex_groups):
        if group.name not in BONE_NAMES and group.name not in NIPPLE_GROUPS:
            obj.vertex_groups.remove(group)
    obj.data.materials.clear()
    return obj


def bisect(obj, point, normal):
    """Cut along a plane and discard the side the normal points to."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=Vector(point), plane_no=Vector(normal),
                           clear_outer=True, dist=1e-5)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()


def inflate(obj, offset):
    """Move every vertex along its normal by offset(position) metres."""
    mesh = obj.data
    mesh.update()
    for v in mesh.vertices:
        v.co = v.co + v.normal * offset(v.co)


def relax(ctx, obj, iterations, clearance, strength=0.5, pin_boundary=True, drape=0):
    """Smooth anatomy away while staying `clearance(p)` off the skin.

    `drape` runs that many iterations of Blender's (C) smooth first, with the
    open edges pinned, so muscle relief washes out over the whole garment;
    the Python pass then restores the ease wherever smoothing sank the cloth.
    """
    if drape:
        pin = obj.vertex_groups.new(name="_drape")
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        interior = [v.index for v in bm.verts if not v.is_boundary]
        bm.free()
        pin.add(interior, 1.0, "REPLACE")
        mod = obj.modifiers.new("Drape", "SMOOTH")
        mod.factor = 0.8
        mod.iterations = drape
        mod.vertex_group = pin.name
        activate(obj)
        bpy.ops.object.modifier_apply(modifier=mod.name)
        obj.vertex_groups.remove(obj.vertex_groups["_drape"])
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    boundary = {v.index for v in bm.verts if v.is_boundary} if pin_boundary else set()
    neighbours = [[e.other_vert(v).index for e in v.link_edges] for v in bm.verts]
    co = np.array([v.co[:] for v in bm.verts])
    for _ in range(iterations):
        avg = np.array([co[n].mean(axis=0) if n else co[i] for i, n in enumerate(neighbours)])
        new = co + (avg - co) * strength
        for i in boundary:
            new[i] = co[i] * 0.7 + avg[i] * 0.3
        for i in range(len(new)):
            p = Vector(new[i])
            hit, normal, _, dist = ctx.bvh.find_nearest(p)
            if hit is None:
                continue
            need = clearance(p)
            side = (p - hit).dot(normal)
            if side < need:
                # Clamp: a vertex that slipped behind the skin near a crease is
                # eased back gradually, never flung across the body.
                p = p + normal * min(need - side, 0.01)
            new[i] = p[:]
        co = new
    for v, c in zip(bm.verts, co):
        v.co = Vector(c)
    bm.to_mesh(obj.data)
    bm.free()


def _hull_2d(points):
    """Monotone-chain convex hull of (N, 2) points, counter-clockwise."""
    pts = sorted(map(tuple, points))
    if len(pts) < 3:
        return np.array(pts)
    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return np.array(lower[:-1] + upper[:-1])


def _hull_radius(hull, angles):
    """Distance from the origin to a convex polygon along each angle."""
    out = np.zeros(len(angles))
    n = len(hull)
    for k, a in enumerate(angles):
        d = np.array([math.cos(a), math.sin(a)])
        best = 0.0
        for i in range(n):
            p, q = hull[i], hull[(i + 1) % n]
            e = q - p
            denom = d[0] * (-e[1]) - d[1] * (-e[0])
            if abs(denom) < 1e-12:
                continue
            t = (p[0] * (-e[1]) - p[1] * (-e[0])) / denom
            u = (d[0] * p[1] - d[1] * p[0]) / denom
            if t > 0 and -1e-6 <= u <= 1 + 1e-6:
                best = max(best, t)
        out[k] = best
    return out


class SectionHull:
    """Per-slice convex hull of the body around one cylinder frame.

    Cloth under tension spans concavities: in any cross-section it lies on
    (roughly) the convex hull of the body section, not on the skin.
    """
    ANGLES = 96

    def __init__(self, ctx, frame, step=0.012):
        origin, axis, seam = cylinder_frames(ctx)[frame]
        self.origin, self.axis = origin, axis
        self.ref = (seam - axis * seam.dot(axis)).normalized()
        self.side = axis.cross(self.ref)
        body = ctx.body
        # Nipples are skin detail, not tailoring points: cloth never tents on them.
        skip = {body.vertex_groups[n].index for n in ("nipple", "nippleTip") if n in body.vertex_groups}
        pts = []
        for v in body.data.vertices:
            if frame_of_bone(dominant_bone(body, v)) != frame:
                continue
            if skip and any(g.group in skip and g.weight > 0.05 for g in v.groups):
                continue
            p = v.co - origin
            along = p.dot(axis)
            pts.append((along, p.dot(self.ref), p.dot(self.side)))
        pts = np.array(pts)
        self.lo, self.hi = pts[:, 0].min(), pts[:, 0].max()
        self.step = step
        count = int((self.hi - self.lo) / step) + 1
        angles = np.linspace(0, 2 * math.pi, self.ANGLES, endpoint=False)
        radii = np.zeros((count, self.ANGLES))
        centres = np.zeros((count, 2))
        valid = np.zeros(count, dtype=bool)
        for i in range(count):
            a0 = self.lo + (i - 0.8) * step
            a1 = self.lo + (i + 1.8) * step
            sel = pts[(pts[:, 0] >= a0) & (pts[:, 0] < a1)][:, 1:]
            if len(sel) >= 3:
                hull = _hull_2d(sel)
                # Polar coordinates about the slice's own centre, which is
                # always inside its hull (the frame axis need not be).
                centre = hull.mean(axis=0)
                centres[i] = centre
                radii[i] = _hull_radius(hull - centre, angles)
                valid[i] = True
        for i in range(count):
            if not valid[i]:
                j = min(np.flatnonzero(valid), key=lambda k: abs(k - i))
                radii[i], centres[i] = radii[j], centres[j]
        for _ in range(2):
            radii[1:-1] = (radii[:-2] + 2 * radii[1:-1] + radii[2:]) / 4
            centres[1:-1] = (centres[:-2] + 2 * centres[1:-1] + centres[2:]) / 4
        self.radii, self.centres = radii, centres

    def radius(self, p):
        """(hull radius, own radius, radial unit vector, slice centre) at p."""
        q = p - self.origin
        along = q.dot(self.axis)
        fi = min(max((along - self.lo) / self.step, 0), len(self.radii) - 1)
        i0 = int(fi)
        i1 = min(i0 + 1, len(self.radii) - 1)
        ti = fi - i0
        cx, cy = self.centres[i0] * (1 - ti) + self.centres[i1] * ti
        x, y = q.dot(self.ref) - cx, q.dot(self.side) - cy
        angle = math.atan2(y, x) % (2 * math.pi)
        fa = angle / (2 * math.pi) * self.ANGLES
        a0 = int(fa) % self.ANGLES
        a1 = (a0 + 1) % self.ANGLES
        ta = fa - int(fa)
        r0 = self.radii[i0, a0] * (1 - ta) + self.radii[i0, a1] * ta
        r1 = self.radii[i1, a0] * (1 - ta) + self.radii[i1, a1] * ta
        own = math.hypot(x, y)
        centre = self.origin + self.axis * along + self.ref * cx + self.side * cy
        direction = (self.ref * x + self.side * y) / own if own > 1e-6 else self.ref
        return r0 * (1 - ti) + r1 * ti, own, direction, centre


def hull_fit(ctx, obj, ease, frames=("torso", "arm.l", "arm.r", "leg.l", "leg.r")):
    """Lift a body shell onto section hulls plus ease (cloth under tension)."""
    hulls = {f: SectionHull(ctx, f) for f in frames}
    mesh = obj.data
    nipple = {obj.vertex_groups[n].index for n in NIPPLE_GROUPS if n in obj.vertex_groups}
    for v in mesh.vertices:
        frame = frame_of_bone(dominant_bone(obj, v))
        if frame not in hulls:
            v.co = v.co + v.normal * ease(v.co)
            continue
        hull_r, own_r, direction, centre = hulls[frame].radius(v.co)
        if own_r < 1e-5:
            continue
        on_nipple = any(g.group in nipple and g.weight > 0.05 for g in v.groups)
        radius = hull_r if on_nipple else max(own_r, hull_r)
        target = centre + direction * (radius + ease(v.co))
        if (target - v.co).length < 0.08:
            v.co = target


def boundary_loops(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    edges = [e for e in bm.edges if e.is_boundary]
    loops, seen = [], set()
    for start in edges:
        if start.index in seen:
            continue
        loop, edge, vert = [], start, start.verts[0]
        while edge and edge.index not in seen:
            seen.add(edge.index)
            loop.append(vert.index)
            vert = edge.other_vert(vert)
            edge = next((e for e in vert.link_edges if e.is_boundary and e.index not in seen), None)
        loops.append(loop)
    bm.verts.ensure_lookup_table()
    result = [[(i, bm.verts[i].co.copy()) for i in loop] for loop in loops]
    bm.free()
    return result


def set_weights(obj, vertex_index, weights):
    for bone, w in weights.items():
        group = obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone)
        group.add([vertex_index], w, "REPLACE")


def skirt_weights(ctx, p, top_z, hem_z):
    depth = min(1.0, max(0.0, (top_z - p.z) / max(1e-4, top_z - hem_z)))
    legs = 0.22 + 0.5 * depth
    side = surfaces.smoothstep(-0.07, 0.07, p.x)
    return {"hips": 1.0 - legs, "upperleg.l": legs * float(side), "upperleg.r": legs * float(1 - side)}


def loft_skirt(ctx, obj, hem_z, flare, fold_depth, folds=14, rings=10, seed=0):
    """Extend the lowest open edge loop down to hem_z as a flared, folded skirt."""
    loops = boundary_loops(obj)
    loop = min(loops, key=lambda l: sum(c.z for _, c in l) / len(l))
    centre = sum((c for _, c in loop), Vector()) / len(loop)
    top_z = centre.z
    # Order the loop by angle so rings stay consistent.
    loop.sort(key=lambda ic: math.atan2(ic[1].x - centre.x, -(ic[1].y - centre.y)))
    rng = np.random.default_rng(seed)
    phases = rng.uniform(0, 2 * math.pi, 3)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    deform = bm.verts.layers.deform.verify()
    groups = {g.name: g.index for g in obj.vertex_groups}
    for bone in ("hips", "upperleg.l", "upperleg.r"):
        if bone not in groups:
            groups[bone] = obj.vertex_groups.new(name=bone).index
    previous = [bm.verts[i] for i, _ in loop]
    for r in range(1, rings + 1):
        s = r / rings
        z = top_z + (hem_z - top_z) * s
        ring = []
        for (i, c) in loop:
            radial = Vector((c.x - centre.x, c.y - centre.y, 0))
            angle = math.atan2(radial.x, -radial.y)
            base = radial.length
            flare_r = base * (1.0 + (flare - 1.0) * s ** 1.3)
            wave = (math.sin(angle * folds + phases[0]) * 0.6 + math.sin(angle * folds * 0.5 + phases[1]) * 0.4)
            radius = flare_r + fold_depth * (s ** 1.2) * wave
            pos = Vector((centre.x, centre.y, z)) + radial.normalized() * radius
            v = bm.verts.new(pos)
            for bone, w in skirt_weights(ctx, pos, top_z, hem_z).items():
                v[deform][groups[bone]] = w
            ring.append(v)
        for k in range(len(ring)):
            a, b = previous[k], previous[(k + 1) % len(ring)]
            c, d = ring[(k + 1) % len(ring)], ring[k]
            try:
                bm.faces.new((a, b, c, d))
            except ValueError:
                pass
        previous = ring
    bm.normal_update()
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(obj.data)
    bm.free()
    return top_z


def hem_rolls(ctx, obj, radius, key, family, color, min_loop=12):
    """Turned hems: a small tube along every open edge (neckline, cuffs, hem)."""
    parts = []
    for i, loop in enumerate(boundary_loops(obj)):
        if len(loop) < min_loop:
            continue
        steps = [(loop[k][1] - loop[k - 1][1]).length for k in range(len(loop))]
        if max(steps) > 0.04:
            continue  # not a clean opening (non-manifold junction)
        pts = [c for _, c in loop]
        # Smooth the cut line so the binding reads as sewn, not sliced.
        for _ in range(3):
            pts = [(pts[k - 1] + pts[k] * 2 + pts[(k + 1) % len(pts)]) / 4 for k in range(len(pts))]
        indices = [vi for vi, _ in loop]
        tube = strap_tube(ctx, f"{obj.name}_hem{i}", pts + [pts[0]], radius * 2, None, closed=True,
                          family=family, color=color, key=key)
        # Hems take the weights of the edge they bind.
        copy_nearest_weights(obj, tube, indices)
        parts.append(tube)
    return parts


def copy_nearest_weights(source, target, candidate_indices):
    src = source.data.vertices
    names = {g.index: g.name for g in source.vertex_groups}
    for v in target.data.vertices:
        nearest = min(candidate_indices, key=lambda i: (src[i].co - v.co).length_squared)
        for g in src[nearest].groups:
            name = names[g.group]
            if name not in BONE_NAMES:
                continue
            group = target.vertex_groups.get(name) or target.vertex_groups.new(name=name)
            group.add([v.index], g.weight, "REPLACE")


def solidify(obj, thickness):
    mod = obj.modifiers.new("Thickness", "SOLIDIFY")
    mod.thickness = thickness
    mod.offset = -1.0
    mod.use_rim = True
    # Even offset turns folded or tiny faces into metre-long spikes.
    mod.use_even_offset = False
    mod.use_quality_normals = True
    activate(obj)
    bpy.ops.object.modifier_apply(modifier=mod.name)


def activate(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def normalize_weights(obj, limit=4):
    names = {g.index: g.name for g in obj.vertex_groups}
    for v in obj.data.vertices:
        ws = sorted(((g.group, g.weight) for g in v.groups if names[g.group] in BONE_NAMES),
                    key=lambda gw: gw[1], reverse=True)
        keep = ws[:limit]
        total = sum(w for _, w in keep) or 1.0
        for g in list(v.groups):
            if names[g.group] in BONE_NAMES:
                obj.vertex_groups[g.group].remove([v.index])
        for gi, w in keep:
            obj.vertex_groups[gi].add([v.index], w / total, "REPLACE")


# --------------------------------------------------------------------------
# Grain UVs
# --------------------------------------------------------------------------

def cylinder_frames(ctx):
    t = ctx.t
    frames = {"torso": (Vector((0, t["hips"].y, 0)), Vector((0, 0, 1)), Vector((0, 1, 0)))}
    for s, sign in (("l", 1), ("r", -1)):
        frames[f"arm.{s}"] = (t[f"upperarm.{s}"], Vector((sign, 0, 0)), Vector((0, 0, -1)))
        leg_axis = (t[f"lowerleg.{s}"] - t[f"upperleg.{s}"]).normalized()
        frames[f"leg.{s}"] = (t[f"upperleg.{s}"], -leg_axis, Vector((-sign, 0, 0)))
        frames[f"foot.{s}"] = (t[f"foot.{s}"], Vector((0, -1, 0)), Vector((0, 0, 1)))
    frames["head"] = (Vector((0, t["head"].y, 0)), Vector((0, 0, 1)), Vector((0, 1, 0)))
    return frames


def frame_of_bone(bone):
    if bone in ("hips", "spine", "chest"):
        return "torso"
    if bone == "head":
        return "head"
    side = bone[-1]
    if bone.startswith(("upperarm", "lowerarm", "wrist", "hand")):
        return f"arm.{side}"
    if bone.startswith(("upperleg", "lowerleg")):
        return f"leg.{side}"
    return f"foot.{side}"


def grain_uv(ctx, obj, family, override=None):
    """Cylindrical cloth-grain UVs, wrap seam at `seam` direction per frame."""
    tile = textiles.TILE_METRES[family]
    frames = cylinder_frames(ctx)
    mesh = obj.data
    if not mesh.uv_layers:
        mesh.uv_layers.new(name="UVMap")
    for layer in list(mesh.uv_layers)[1:]:
        mesh.uv_layers.remove(layer)
    uv = mesh.uv_layers[0].data
    bone_of = [dominant_bone(obj, v) for v in mesh.vertices]
    for poly in mesh.polygons:
        votes = {}
        for vi in poly.vertices:
            f = override(mesh.vertices[vi].co) if override else None
            f = f or frame_of_bone(bone_of[vi])
            votes[f] = votes.get(f, 0) + 1
        frame = max(votes.items(), key=lambda kv: kv[1])[0]
        origin, axis, seam = frames[frame]
        ref = (seam - axis * seam.dot(axis)).normalized()
        side = axis.cross(ref)
        coords = []
        for li in poly.loop_indices:
            p = mesh.vertices[mesh.loops[li].vertex_index].co - origin
            along = p.dot(axis)
            radial = p - axis * along
            angle = math.atan2(radial.dot(side), radial.dot(ref))  # 0 at the seam
            angle = angle % (2 * math.pi)
            coords.append([angle, radial.length, along])
        angles = [c[0] for c in coords]
        if max(angles) - min(angles) > math.pi:
            for c in coords:
                if c[0] < math.pi:
                    c[0] += 2 * math.pi
        for li, (angle, radius, along) in zip(poly.loop_indices, coords):
            circumference_radius = 0.16 if frame == "torso" else 0.06 if frame.startswith("arm") else 0.08
            uv[li].uv = (angle * circumference_radius / tile, along / tile)


# --------------------------------------------------------------------------
# Materials and export
# --------------------------------------------------------------------------

def textile_material(ctx, family, color, key):
    name = f"{ctx.spec['fit']}_{key}"
    if name in ctx.materials:
        return ctx.materials[name]
    paths = textiles.texture_paths(family, 512 if ctx.spec.get("tier") == 2 else textiles.SIZE)
    mat = surfaces.pbr_material(name, paths["albedo"], paths["normal"], paths["orm"], color=color,
                                roughness=0.85)
    if family in ("mail", "iron"):
        # Metallic lives in the ORM blue channel.
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        sep = next(n for n in nodes if n.type == "SEPARATE_COLOR")
        links.new(sep.outputs["Blue"], nodes.get("Principled BSDF").inputs["Metallic"])
    ctx.materials[name] = mat
    return mat


def finish(ctx, obj, family, color, key, thickness=0.0):
    # glTF ignores node transforms on skinned meshes: bake them into vertices.
    obj.data.transform(obj.matrix_world)
    obj.matrix_world = Matrix.Identity(4)
    if thickness > 0:
        solidify(obj, thickness)
    normalize_weights(obj)
    obj.data.shade_smooth()
    surfaces.assign(obj, textile_material(ctx, family, color, key))
    return obj


# --------------------------------------------------------------------------
# Clearance / ease
# --------------------------------------------------------------------------

def constant(value):
    return lambda p: value


def fold_offset(base, amplitude, frequency, axis=2):
    return lambda p: base + amplitude * math.sin(p[axis] * frequency + p.x * 17.0)


# --------------------------------------------------------------------------
# Garment builders
# --------------------------------------------------------------------------

def _torso_or_arm(bone):
    return bone in ("hips", "spine", "chest") or bone.startswith(("upperarm", "lowerarm", "wrist", "hand"))


def bodice(ctx, name, ease, sleeve_end, hem_cut_z, neck_raise=0.012, iterations=6, drape=30):
    """Torso + sleeves shell down to hem_cut_z, sleeves cut at |x| = sleeve_end."""
    t = ctx.t
    obj = extract_shell(ctx, name, lambda v, b: _torso_or_arm(b) and v.co.z > hem_cut_z - 0.05)
    # Neckline follows the collar plane, slightly above the skin region seam.
    bisect_neck(ctx, obj, neck_raise)
    bisect(obj, (0, 0, hem_cut_z), (0, 0, -1))
    for s, sign in (("l", 1), ("r", -1)):
        bisect(obj, (sign * sleeve_end, 0, 0), (sign, 0, 0))
    # Necklines hug the neck: fade the ease out over the last few centimetres,
    # otherwise the gap exposes the hidden torso region underneath.
    def fitted(p, ease=ease):
        near_neck = surfaces.smoothstep(ctx.collar(p.y) - 0.07, ctx.collar(p.y) + neck_raise, p.z)
        return ease(p) * (1.0 - 0.85 * float(near_neck))
    hull_fit(ctx, obj, fitted)
    relax(ctx, obj, iterations, lambda p: fitted(p) * 0.8, strength=0.5, drape=drape)
    return obj


def bisect_neck(ctx, obj, raise_by):
    """Cut the neckline on a plane tilted like the collar (lower at the front)."""
    front_y, back_y = ctx.lm["chin"][1] + 0.02, ctx.t["head"].y + 0.06
    z_front, z_back = ctx.collar(front_y) + raise_by, ctx.collar(back_y) + raise_by
    point = Vector((0, front_y, z_front))
    slope = Vector((0, back_y - front_y, z_back - z_front)).normalized()
    normal = Vector((1, 0, 0)).cross(slope)
    if normal.z < 0:
        normal = -normal
    bisect(obj, point, normal)


def hem_height(ctx, hem):
    t = ctx.t
    knee = t["lowerleg.l"].z
    return {"thigh": knee + 0.14, "knee": knee + 0.03, "calf": knee - 0.17,
            "ankle": t["foot.l"].z + 0.035}[hem]


def tunic(ctx, key, sleeve="full", hem="knee", extra_ease=0.0, belted=True, color_key="wool_tunic",
          flare=1.55, folds=16, family="wool"):
    """Gored wool tunic (Rock) or gown (Kleid).

    `sleeve`: full (to wrist), rolled (pushed up for work) or none; `hem`: thigh,
    knee, calf or ankle (status by length, per the clothing dossier)."""
    t = ctx.t
    color = ctx.palette(color_key, textiles_color("undyed"))
    wrist = t["wrist.l"].x + 0.012
    elbow = t["lowerarm.l"].x
    sleeve_end = {"full": wrist, "rolled": elbow + 0.06, "none": t["upperarm.l"].x + 0.035}[sleeve]
    waist_z = t["spine"].z - 0.02
    hip_cut = t["hips"].z + 0.02
    shoulder, wrist_x = t["upperarm.l"].x + 0.02, t["wrist.l"].x

    def ease(p):
        if abs(p.x) > shoulder:
            # Period sleeves: roomy at the upper arm, fitted at the forearm.
            along = min(1.0, (abs(p.x) - shoulder) / max(wrist_x - shoulder, 0.1))
            return 0.03 * (1 - along) + 0.01 * along + extra_ease * 0.5
        return 0.018 + extra_ease + 0.012 * surfaces.smoothstep(t["chest"].z, waist_z, p.z)
    obj = bodice(ctx, f"Garment_{key}", ease, sleeve_end, hip_cut)
    loft_skirt(ctx, obj, hem_height(ctx, hem), flare=flare, fold_depth=0.018 * flare / 1.55,
               folds=folds, seed=3, rings=10 if hem in ("thigh", "knee") else 16)
    # Blouse slightly over the belt.
    for v in obj.data.vertices:
        bump = math.exp(-((v.co.z - (waist_z + 0.03)) / 0.03) ** 2)
        if abs(v.co.x) < t["upperarm.l"].x:
            radial = Vector((v.co.x, v.co.y - t["hips"].y, 0))
            if radial.length > 1e-4:
                v.co += radial.normalized() * 0.008 * bump
    grain_uv(ctx, obj, family)
    hems = hem_rolls(ctx, obj, 0.0035, color_key, family, color)
    parts = [finish(ctx, obj, family, color, color_key, thickness=0.003)]
    parts += [finish_hem(ctx, h, family, color, color_key) for h in hems]
    if sleeve == "rolled":
        for s, sign in (("l", 1), ("r", -1)):
            parts.append(sleeve_roll(ctx, s, sign, sleeve_end, color))
    if belted:
        parts += belt(ctx, waist_z, knife=belted != "plain", ease=ctx.spec.get("belt_ease", 0.0),
                      knife_at=ctx.spec.get("knife_at", 8))
    return parts


def sleeve_roll(ctx, s, sign, x, color):
    """A thick rolled cuff where the sleeve is pushed up for forge work."""
    t = ctx.t
    centre = Vector((sign * x, t[f"upperarm.{s}"].y, t[f"upperarm.{s}"].z))
    samples = []
    for k in range(24):
        a = k / 24 * 2 * math.pi
        direction = Vector((0, math.cos(a), math.sin(a)))
        hit = ctx.bvh.ray_cast(centre + direction * 0.2, -direction)
        r = (hit[0] - centre).length if hit[0] else 0.05
        samples.append(r)
    radius = sum(samples) / len(samples)
    obj = torus(f"Garment_sleeve_roll_{s}", centre, Vector((sign, 0, 0)), radius + 0.014, 0.015)
    group = obj.vertex_groups.new(name=f"lowerarm.{s}")
    group.add([v.index for v in obj.data.vertices], 1.0, "REPLACE")
    grain_uv(ctx, obj, "wool")
    return finish(ctx, obj, "wool", color, "wool_tunic")


def torus(name, centre, axis, major, minor, segments=32, sides=10):
    axis = axis.normalized()
    ref = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))
    u = axis.cross(ref).normalized()
    w = axis.cross(u)
    bm = bmesh.new()
    rings = []
    for i in range(segments):
        a = i / segments * 2 * math.pi
        radial = u * math.cos(a) + w * math.sin(a)
        # A roll of cloth is lumpy, not a perfect ring.
        wobble = 1.0 + 0.12 * math.sin(a * 3 + 0.7) + 0.06 * math.sin(a * 7)
        ring = []
        for j in range(sides):
            b = j / sides * 2 * math.pi
            p = centre + radial * (major + minor * wobble * math.cos(b)) + axis * (minor * 1.3 * math.sin(b))
            ring.append(bm.verts.new(p))
        rings.append(ring)
    for i in range(segments):
        for j in range(sides):
            a0, a1 = rings[i], rings[(i + 1) % segments]
            bm.faces.new((a0[j], a1[j], a1[(j + 1) % sides], a0[(j + 1) % sides]))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def belt(ctx, waist_z, knife=True, ease=0.0, knife_at=8):
    """Leather belt with its knife (plausible composite).

    Buckle, strap-end, mounts, purse, keys and beads are rigid scanned parts hung on
    this band at runtime by prestige (scripts/city/belt_gear.gd, task R-2033), which
    finds it by the `belt_leather` material; the knife moves to R-2008.

    `ease` (spec `belt_ease`) moves it out over a roomy tunic;
    `knife_at` is the sheath's index of 48 round the waist (8 = left front)."""
    t = ctx.t
    leather = ctx.palette("belt", (0.20, 0.12, 0.07))
    points = []
    for k in range(48):
        a = k / 48 * 2 * math.pi
        direction = Vector((math.sin(a), -math.cos(a), 0))
        origin = Vector((0, t["hips"].y, waist_z))
        hit = ctx.bvh.ray_cast(origin + direction * 0.4, -direction)
        r = ((hit[0] - origin).length if hit[0] else 0.16) + 0.024 + ease
        points.append(origin + direction * r)
    obj = band(f"Garment_belt", points, width=0.036, thickness=0.005)
    group = obj.vertex_groups.new(name="hips")
    group.add([v.index for v in obj.data.vertices], 1.0, "REPLACE")
    grain_uv(ctx, obj, "leather")
    parts = [finish(ctx, obj, "leather", leather, "belt_leather")]
    # Knife sheath on the left front (the purse is a BeltGear part on the right hip).
    if knife:
        sheath_at = points[knife_at] + Vector((0.0, 0, -0.10))
        parts.append(rigid_box(ctx, "Garment_knife_sheath", sheath_at, (0.018, 0.035, 0.2), "hips",
                               "leather", (0.12, 0.07, 0.04), "sheath_leather"))
    return parts


def band(name, points, width, thickness):
    bm = bmesh.new()
    rings = []
    n = len(points)
    for i, p in enumerate(points):
        tangent = (points[(i + 1) % n] - points[i - 1]).normalized()
        outward = Vector((p.x, p.y, 0)).normalized() if Vector((p.x, p.y, 0)).length > 1e-4 else Vector((1, 0, 0))
        up = Vector((0, 0, 1))
        ring = [bm.verts.new(p + up * width / 2), bm.verts.new(p + outward * thickness + up * width / 2),
                bm.verts.new(p + outward * thickness - up * width / 2), bm.verts.new(p - up * width / 2)]
        rings.append(ring)
    for i in range(n):
        a, b = rings[i], rings[(i + 1) % n]
        for k in range(4):
            bm.faces.new((a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k]))
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def rigid_box(ctx, name, centre, size, bone, family, color, key):
    bpy.ops.mesh.primitive_cube_add(size=1, location=centre)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bevel = obj.modifiers.new("Soft", "BEVEL")
    bevel.width = min(size) * 0.3
    bevel.segments = 3
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    group = obj.vertex_groups.new(name=bone)
    group.add([v.index for v in obj.data.vertices], 1.0, "REPLACE")
    grain_uv(ctx, obj, family)
    return finish(ctx, obj, family, color, key)


def finish_hem(ctx, obj, family, color, key):
    grain_uv(ctx, obj, family, override=lambda p: "torso")
    return finish(ctx, obj, family, color, key)


def textiles_color(name):
    import specs
    return {"undyed": specs.UNDYED_GREY_BROWN, "linen": specs.LINEN_UNBLEACHED}[name]


def linen_shirt(ctx):
    t = ctx.t
    obj = bodice(ctx, "Garment_linen_shirt", lambda p: 0.006, t["wrist.l"].x + 0.01, t["hips"].z + 0.02,
                 neck_raise=0.016, iterations=12)
    loft_skirt(ctx, obj, t["hips"].z - 0.2, flare=1.25, fold_depth=0.01, folds=12, seed=5)
    grain_uv(ctx, obj, "linen")
    color = ctx.palette("linen_shirt", textiles_color("linen"))
    hems = hem_rolls(ctx, obj, 0.0025, "linen", "linen", color)
    return [finish(ctx, obj, "linen", color, "linen", 0.002)] + [finish_hem(ctx, h, "linen", color, "linen") for h in hems]


def surcoat(ctx):
    """Sleeveless wool surcoat over mail (crown retainer colours, no invented heraldry)."""
    if layer_ease(ctx) <= 0:
        return tunic(ctx, "surcoat", sleeve="none", hem="knee", extra_ease=0.05, belted="plain",
                     color_key="surcoat", flare=1.45)
    # Citizen layer: no belt of its own (it would sit under the mail), and every
    # vertex pushed out of the aketon and mail it is always worn over.
    parts = tunic(ctx, "surcoat", sleeve="none", hem="knee", extra_ease=0.05 + layer_ease(ctx), belted=False,
                  color_key="surcoat", flare=2.2)
    trees = [ctx.layers[k] for k in ("gambeson", "mail_haubergeon", "mail_coif") if k in ctx.layers]
    trees += [ctx.layers[k] for k in ("coat_of_plates", "aventail") if k in ctx.layers]
    for part in parts:
        for v in part.data.vertices:
            v.co = clear_of(trees, ctx.t["hips"].y, v.co, 0.012)
    # The Order's mantle hangs over the surcoat (order_mantle() clears this tree).
    ctx.layers["surcoat"] = BVHTree.FromObject(parts[0], bpy.context.evaluated_depsgraph_get())
    return parts


def gambeson(ctx):
    """Quilted linen aketon: high collar, fitted sleeves, skirt to mid-thigh."""
    t = ctx.t
    extra = layer_ease(ctx)
    ease = lambda p: 0.022 + extra + (0.004 if abs(p.x) > t["upperarm.l"].x else 0.0)
    obj = bodice(ctx, "Garment_gambeson", ease, t["wrist.l"].x + 0.012, t["hips"].z + 0.02,
                 neck_raise=0.03, iterations=24)
    # Over a baked crowd tunic the skirt hangs lower and wider, or the tunic hem pokes through.
    layered = extra > 0
    loft_skirt(ctx, obj, t["lowerleg.l"].z + (0.08 if layered else 0.18), flare=1.75 if layered else 1.3,
               fold_depth=0.012, folds=10, seed=7)
    grain_uv(ctx, obj, "quilted")
    color = ctx.palette("gambeson", (0.62, 0.56, 0.44))
    hems = hem_rolls(ctx, obj, 0.007, "gambeson", "linen", color)
    return [finish(ctx, obj, "quilted", color, "gambeson", 0.008)] + \
        [finish_hem(ctx, h, "linen", color, "gambeson_binding") for h in hems]


def mail_haubergeon(ctx):
    """Riveted mail shirt, elbow sleeves, hem above the aketon's."""
    t = ctx.t
    extra = layer_ease(ctx)
    ease = lambda p: 0.034 + extra
    obj = bodice(ctx, "Garment_mail_haubergeon", ease, t["lowerarm.l"].x + 0.04, t["hips"].z + 0.02,
                 neck_raise=0.02, iterations=24)
    # Layered (crowd): wider than the layered aketon skirt it covers.
    loft_skirt(ctx, obj, t["lowerleg.l"].z + (0.14 if extra > 0 else 0.24), flare=1.95 if extra > 0 else 1.28,
               fold_depth=0.006, folds=8, seed=9)
    grain_uv(ctx, obj, "mail")
    mail = finish(ctx, obj, "mail", (0.42, 0.42, 0.44), "mail", 0.004)
    # Worn layers the surcoat must clear (citizen layers stack aketon -> mail -> surcoat).
    ctx.layers["mail_haubergeon"] = BVHTree.FromObject(mail, bpy.context.evaluated_depsgraph_get())
    return [mail]


def hose(ctx):
    """Separate wool hose, footed, pointed to the braies girdle."""
    t = ctx.t
    top = t["hips"].z - 0.02
    obj = extract_shell(ctx, "Garment_hose",
                        lambda v, b: b.startswith(LEG_BONES) or (b == "hips" and v.co.z < top))
    hull_fit(ctx, obj, constant(0.003), frames=("leg.l", "leg.r", "foot.l", "foot.r"))
    relax(ctx, obj, 4, constant(0.0025), strength=0.35, drape=6)
    grain_uv(ctx, obj, "wool")
    color = ctx.palette("hose", (0.22, 0.20, 0.17))
    right = ctx.spec.get("palette", {}).get("hose_right")
    if not right:
        return [finish(ctx, obj, "wool", color, "hose")]
    # Parti-coloured hose (wealthy burghers): each leg its own dye.
    mesh = obj.data
    finish(ctx, obj, "wool", color, "hose")
    mesh.materials.append(textile_material(ctx, "wool", tuple(right), "hose_right"))
    for poly in mesh.polygons:
        poly.material_index = 1 if poly.center.x < 0 else 0
    return [obj]


def boots(ctx, name="Garment_boots", key="boot_leather", height=0.10, palette_key="boots"):
    """Turned-leather ankle boots (or, with a low `height`, turnshoes).

    A closed form: convex hull of each foot and ankle, voxel-remeshed, then
    every vertex projected onto the section hull (+ leather clearance) of the
    foot below the ankle or of the leg above it. The toes are spanned by one
    rounded toe box, as a stiff upper would, and the sole is flat.
    """
    t = ctx.t
    ankle = t["foot.l"].z
    top = ankle + height
    source = extract_shell(ctx, "_boot_source",
                           lambda v, b: b.startswith(("foot", "toes")) or (b.startswith("lowerleg") and v.co.z < top + 0.03))
    bm = bmesh.new()
    bm.from_mesh(source.data)
    hull_faces = []
    for sign in (1, -1):
        pts = [v for v in bm.verts if v.co.x * sign > 0]
        result = bmesh.ops.convex_hull(bm, input=pts)
        hull_faces.extend(g for g in result["geom"] if isinstance(g, bmesh.types.BMFace))
    keep = set(hull_faces)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f not in keep], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    obj = bpy.data.objects.new(name, bpy.data.meshes.new(name))
    bpy.context.scene.collection.objects.link(obj)
    bm.to_mesh(obj.data)
    bm.free()
    bpy.data.objects.remove(source, do_unlink=True)
    activate(obj)
    mod = obj.modifiers.new("Remesh", "REMESH")
    mod.mode = "VOXEL"
    mod.voxel_size = 0.007
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bisect(obj, (0, 0, top), (0, 0, 1))
    hulls = {f: SectionHull(ctx, f) for f in ("foot.l", "foot.r", "leg.l", "leg.r")}
    for v in obj.data.vertices:
        side = "l" if v.co.x > 0 else "r"
        blend = surfaces.smoothstep(ankle - 0.01, ankle + 0.03, v.co.z)
        targets = []
        toe = surfaces.smoothstep(t[f"toes.{side}"].y + 0.02, t[f"toes.{side}"].y - 0.05, v.co.y)
        for frame in (f"foot.{side}", f"leg.{side}"):
            hull_r, own_r, direction, centre = hulls[frame].radius(v.co)
            targets.append(centre + direction * (hull_r + 0.008 + 0.006 * float(toe)))
        target = targets[0].lerp(targets[1], float(blend))
        # A projection this far means a degenerate slice; leave it to relax.
        if (target - v.co).length < 0.05:
            v.co = target
    relax(ctx, obj, 4, constant(0.007), strength=0.4, drape=12)
    for v in obj.data.vertices:
        if v.co.z < 0.014:
            v.co.z = max(0.0, v.co.z - 0.006)
    transfer_weights(ctx, obj)
    grain_uv(ctx, obj, "leather")
    color = ctx.palette(palette_key, (0.23, 0.15, 0.09))
    hems = hem_rolls(ctx, obj, 0.004, key, "leather", color)
    return [finish(ctx, obj, "leather", color, key, 0.004)] + \
        [finish_hem(ctx, h, "leather", color, key) for h in hems]


def turnshoes(ctx):
    """Low turned shoes (turnshoes) closed just over the ankle: the everyday 14th-century shoe."""
    return boots(ctx, name="Garment_turnshoes", key="turnshoe_leather", height=0.04, palette_key="turnshoes")


def transfer_weights(ctx, obj):
    """Nearest-surface weights from the body (for remeshed or rebuilt parts)."""
    for group in list(obj.vertex_groups):
        obj.vertex_groups.remove(group)
    body = ctx.body
    for g in body.vertex_groups:
        if g.name in BONE_NAMES:
            obj.vertex_groups.new(name=g.name)
    mod = obj.modifiers.new("Weights", "DATA_TRANSFER")
    mod.object = body
    mod.use_vert_data = True
    mod.data_types_verts = {"VGROUP_WEIGHTS"}
    mod.vert_mapping = "POLYINTERP_NEAREST"
    mod.layers_vgroup_select_src = "ALL"
    mod.layers_vgroup_select_dst = "NAME"
    activate(obj)
    bpy.ops.object.modifier_apply(modifier=mod.name)


def smith_apron(ctx):
    """Heavy leather forge apron from chest to below the knee (Schurz)."""
    return apron(ctx, "Garment_smith_apron", "apron_leather", "leather",
                 ctx.palette("smith_apron", (0.26, 0.15, 0.08)), bib=True,
                 over=ctx.spec.get("apron_over", "work_tunic"))


def waist_apron(ctx):
    """Linen work apron from the waist to below the knee (alewife, innkeeper)."""
    return apron(ctx, "Garment_waist_apron", "waist_apron", "linen",
                 ctx.palette("waist_apron", (0.80, 0.76, 0.66)), bib=False,
                 over=ctx.spec.get("apron_over", "wool_tunic"))


def short_apron(ctx):
    """Short linen apron of a healer's boy: waist to above the knee, narrower than a work
    apron, tied just under the belt (the belt and its pouch stay in view)."""
    t = ctx.t
    waist_z = t["spine"].z - 0.02
    return apron(ctx, "Garment_short_apron", "short_apron", "linen",
                 ctx.palette("short_apron", (0.78, 0.76, 0.66)), bib=False,
                 over=ctx.spec.get("apron_over", "wool_tunic"), hem_z=t["lowerleg.l"].z + 0.11,
                 half=0.16, top_z=waist_z - 0.03, tie_rise=0.006, standoff=0.016, wrap_depth=0.012)


def apron(ctx, name, key, family, color, bib, over, hem_z=None, half=0.2, top_z=None, tie_rise=0.01,
          standoff=0.012, wrap_depth=0.05):
    t = ctx.t
    if top_z is None:
        top_z = t["chest"].z + 0.10 if bib else t["spine"].z - 0.03
    if hem_z is None:
        hem_z = t["lowerleg.l"].z - 0.08
    ctx.apron_layer = over
    cols, rows = 16, 30
    bm = bmesh.new()
    deform = bm.verts.layers.deform.verify()
    verts = []
    obj_groups = ["chest", "spine", "hips", "upperleg.l", "upperleg.r"]
    for r in range(rows + 1):
        z = top_z + (hem_z - top_z) * r / rows
        width = half * (0.72 if z > t["spine"].z + 0.05 else 1.0)
        row = []
        for c in range(cols + 1):
            x = -width + 2 * width * c / cols
            front = front_surface_y(ctx, z, x, width)
            wrap = (abs(x) / width) ** 2 * wrap_depth
            v = bm.verts.new((x, front - standoff + wrap, z))
            row.append(v)
        verts.append(row)
    for r in range(rows):
        for c in range(cols):
            bm.faces.new((verts[r][c], verts[r][c + 1], verts[r + 1][c + 1], verts[r + 1][c]))
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    groups = {b: obj.vertex_groups.new(name=b) for b in obj_groups}
    for v in obj.data.vertices:
        p = v.co
        if p.z > t["spine"].z:
            groups["chest"].add([v.index], 0.7, "REPLACE")
            groups["spine"].add([v.index], 0.3, "REPLACE")
        elif p.z > t["hips"].z:
            groups["spine"].add([v.index], 0.5, "REPLACE")
            groups["hips"].add([v.index], 0.5, "REPLACE")
        else:
            for bone, w in skirt_weights(ctx, p, t["hips"].z, hem_z).items():
                groups[bone].add([v.index], w, "REPLACE")
    grain_uv(ctx, obj, family, override=lambda p: "torso")
    parts = [finish(ctx, obj, family, color, key, 0.005 if family == "leather" else 0.002)]
    if not bib:
        tie = []
        for k in range(49):
            a = k / 48 * 2 * math.pi
            direction = Vector((math.sin(a), -math.cos(a), 0))
            origin = Vector((0, t["hips"].y, top_z + tie_rise))
            layer = ctx.layers.get(over, ctx.bvh)
            hit = layer.ray_cast(origin + direction * 0.4, -direction)
            r = ((hit[0] - origin).length if hit[0] else 0.16) + 0.006
            tie.append(origin + direction * r)
        parts.append(strap_tube(ctx, f"{name}_tie", tie, 0.014, {"spine": 0.5, "hips": 0.5},
                                closed=True, family=family, color=color, key=key))
        return parts
    # Neck strap and waist tie.
    neck = [Vector((0.55 * half * side, front_surface_y(ctx, top_z, 0.55 * half * side, half) - 0.012, top_z))
            for side in (-1,)]
    base = t["neck_base"] if "neck_base" in t else t["head"]
    layer = ctx.layers.get("work_tunic", ctx.bvh)
    for k in range(13):
        a = math.radians(-120 + 240 * k / 12)  # around the back of the neck
        direction = Vector((math.sin(a), math.cos(a), 0))
        z = ctx.collar(base.y + direction.y * 0.07) + 0.012
        origin = Vector((0, base.y, z))
        hit = layer.ray_cast(origin + direction * 0.3, -direction)
        r = ((hit[0] - origin).length if hit[0] else 0.07) + 0.008
        neck.append(origin + direction * r)
    neck.append(Vector((0.55 * half, front_surface_y(ctx, top_z, 0.55 * half, half) - 0.012, top_z)))
    strap = strap_tube(ctx, "Garment_apron_strap", neck, 0.012, {"chest": 1.0})
    parts.append(strap)
    return parts


def front_surface_y(ctx, z, x, width):
    """Most forward point of body or worn layers at height z across the apron."""
    # An apron is worn over one named torso layer (forge: the work tunic).
    over = getattr(ctx, "apron_layer", "work_tunic")
    trees = [ctx.bvh] + [ctx.layers[k] for k in (over,) if k in ctx.layers]
    best, local_best = None, None
    for tree in trees:
        for dx in np.linspace(-width, width, 9):
            hit = tree.ray_cast(Vector((dx, -1.0, z)), Vector((0, 1, 0)))
            if hit[0] is not None:
                best = hit[0].y if best is None else min(best, hit[0].y)
        hit = tree.ray_cast(Vector((x, -1.0, z)), Vector((0, 1, 0)))
        if hit[0] is not None:
            local_best = hit[0].y if local_best is None else min(local_best, hit[0].y)
    if local_best is not None and best is not None:
        return best * 0.6 + local_best * 0.4
    return best if best is not None else -0.15


def strap_tube(ctx, name, points, width, weights, closed=False, family="leather",
               color=(0.22, 0.13, 0.07), key="apron_leather"):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    spline = curve.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for p, pt in zip(spline.points, points):
        p.co = (*pt, 1)
    spline.use_cyclic_u = closed
    curve.bevel_depth = width / 2
    curve.bevel_resolution = 1
    obj = bpy.data.objects.new(name, curve)
    bpy.context.scene.collection.objects.link(obj)
    activate(obj)
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.active_object
    for bone, w in (weights or {}).items():
        obj.vertex_groups.new(name=bone).add([v.index for v in obj.data.vertices], w, "REPLACE")
    if weights is None:
        return obj
    grain_uv(ctx, obj, family, override=lambda p: "torso")
    return finish(ctx, obj, family, color, key)


def trunk_bvh(ctx):
    """BVH of torso, neck and head only (T-posed arms excluded)."""
    if getattr(ctx, "_trunk", None) is None:
        obj = extract_shell(ctx, "_trunk", lambda v, b: b in ("hips", "spine", "chest", "head"))
        ctx._trunk = BVHTree.FromObject(obj, bpy.context.evaluated_depsgraph_get())
        bpy.data.objects.remove(obj, do_unlink=True)
    return ctx._trunk


def hood(ctx):
    # `hood_over`: worn layers (e.g. a friar's cappa) the shoulder cape must lie over.
    return head_wrap(ctx, "Garment_hood", "hood_wool", "wool", ctx.palette("hood", (0.20, 0.27, 0.36)),
                     hem_below_neck=0.25, cape_layers=ctx.spec.get("hood_over", ()),
                     cape_ease=ctx.spec.get("hood_cape_ease", 0.03))


def capuce(ctx):
    """Dominican white capuce worn down: the shoulder cape and a collar round the neck,
    over the scapular, so the tonsure shows (indoors, at work in the infirmary)."""
    return head_wrap(ctx, "Garment_capuce", "capuce", "wool", ctx.palette("capuce", (0.86, 0.85, 0.80)),
                     hem_below_neck=0.15, cape_ease=ctx.spec.get("hood_cape_ease", 0.025), hood_down=True,
                     cape_layers=ctx.spec.get("capuce_over", ("scapular",)))


def headscarf(ctx):
    """Linen headscarf (Estonian women: always covered): brow to jaw, short drape."""
    return head_wrap(ctx, "Garment_headscarf", "headscarf", "linen",
                     ctx.palette("headscarf", (0.74, 0.70, 0.60)), head_ease=0.011, hem_below_neck=0.05,
                     face=(46, 5, -56), cape_ease=0.016, hair=False, open_front=105, folds=0.006)


def veil(ctx):
    """Burgher wife's linen coif and veil falling to the shoulders."""
    return head_wrap(ctx, "Garment_veil", "veil", "linen", ctx.palette("veil", (0.86, 0.84, 0.78)),
                     head_ease=0.012, hem_below_neck=0.22, face=(54, 10, -85), cape_ease=0.03, hair=False,
                     open_front=80, folds=0.01)


def head_wrap(ctx, name, key, family, color, head_ease=0.028, hem_below_neck=0.25, face=(50, 24, -50),
              cape_ease=0.03, hair=True, open_front=0, folds=0.004, cape_layers=(), hood_down=False,
              max_flare=None, cape=True):
    """Wool hood with shoulder cape (Gugel), worn up, face opening framed.

    Parametric: a (theta, v) grid wraps the head (rays from the skull centre)
    and continues as a cape (horizontal rays from the torso axis). Radii are
    the outermost hit on body or hair plus ease; the cape radius never shrinks
    downward, so it hangs like cloth from the shoulders.

    `cape_layers`: ids in ctx.layers the cape rows must also clear (worn over them).
    `hood_down`: keep only the collar and cape (the hood lies back; the head is bare).
    `cape`: False stops the cloth at the throat (the wimple), no shoulder cape.
    `max_flare`: radial growth allowed per metre of drop below the neck, at the front half only; thin
    linen drapes down the chest instead of standing out at the shoulders' edge (veil; None = as
    the body). At the back the cloth keeps clear of the shoulder blades.
    """
    t, lm = ctx.t, ctx.lm
    targets = [trunk_bvh(ctx)]
    cape_targets = targets + [ctx.layers[k] for k in cape_layers if k in ctx.layers]
    hair = bpy.data.objects.get("Hair_Scalp") if hair else None
    if hair is not None:
        targets.append(BVHTree.FromObject(hair, bpy.context.evaluated_depsgraph_get()))
    eyes_mid = Vector(((lm["eye_l"] + lm["eye_r"]) / 2).tolist())
    centre = Vector((0, t["head"].y + 0.01, eyes_mid.z + 0.01))
    neck_z = ctx.collar(t["head"].y)
    hem_z = neck_z - hem_below_neck
    columns = 64
    head_rows, cape_rows = 22, 12

    def outer(origin, direction, trees=targets):
        far = origin + direction * 0.6
        best = 0.0
        for tree in trees:
            hit = tree.ray_cast(far, -direction)
            if hit[0] is not None:
                best = max(best, (hit[0] - origin).dot(direction))
        return best

    grid = []
    for r in range(head_rows + cape_rows + 1):
        row = []
        for c in range(columns):
            theta = c / columns * 2 * math.pi  # 0 = front (-Y)
            horizontal = Vector((math.sin(theta), -math.cos(theta), 0))
            if r <= head_rows:
                elevation = math.radians(88 - (88 + 62) * r / head_rows)
                direction = horizontal * math.cos(elevation) + Vector((0, 0, math.sin(elevation)))
                radius = outer(centre, direction) + head_ease
                row.append(centre + direction * radius)
            else:
                s = (r - head_rows) / cape_rows
                z = neck_z + (hem_z - neck_z) * s
                origin = Vector((0, t["hips"].y, z))
                # Worn layers lift the cape, capped so a stray edge never throws a fin.
                own = outer(origin, horizontal)
                radius = min(outer(origin, horizontal, cape_targets), own + 0.05) + cape_ease
                row.append(origin + horizontal * radius)
        grid.append(row)
    # Cloth hangs: below the chin every column's radius only grows downward.
    for r in range(head_rows + 1, len(grid)):
        for c in range(columns):
            above, here = grid[r - 1][c], grid[r][c]
            ra = Vector((above.x, above.y - t["hips"].y, 0)).length
            rh = Vector((here.x, here.y - t["hips"].y, 0)).length
            if rh < ra:
                flat = Vector((here.x, here.y - t["hips"].y, 0)).normalized()
                grid[r][c] = Vector((0, t["hips"].y, here.z)) + flat * (ra + 0.004)
            elif (max_flare is not None and rh > ra + max_flare * (above.z - here.z)
                  and abs(((c / columns + 0.5) % 1.0) - 0.5) < 0.3):  # within ~110 degrees of the front
                flat = Vector((here.x, here.y - t["hips"].y, 0)).normalized()
                grid[r][c] = Vector((0, t["hips"].y, here.z)) + flat * (ra + max_flare * (above.z - here.z))
    # Soft folds: shallow at the crown, deepening toward the hem as cloth hangs.
    rng = np.random.default_rng(len(name))
    phase = rng.uniform(0, 2 * math.pi, 2)
    for r in range(len(grid)):
        depth = folds * surfaces.smoothstep(head_rows * 0.35, len(grid) - 1, r)
        for c in range(columns):
            theta = c / columns * 2 * math.pi
            wave = 0.65 * math.sin(theta * 11 + phase[0]) + 0.35 * math.sin(theta * 23 + phase[1] + r * 0.3)
            p = grid[r][c]
            radial = Vector((p.x, p.y - t["hips"].y, 0)) if r > head_rows else (p - centre)
            if radial.length > 1e-5:
                grid[r][c] = p + radial.normalized() * depth * wave
    floor = [[(p - centre).length if r <= head_rows else None for p in row] for r, row in enumerate(grid)]
    # Smooth the grid in parameter space to read as felted wool.
    for _ in range(6):
        smoothed = []
        for r in range(len(grid)):
            row = []
            for c in range(columns):
                acc, n = grid[r][c] * 2, 2
                for dr, dc in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    rr = r + dr
                    if 0 < rr < len(grid):
                        acc += grid[rr][(c + dc) % columns]
                        n += 1
                row.append(acc / n if 0 < r < len(grid) - 1 else grid[r][c])
            smoothed.append(row)
        grid = smoothed
        # Smoothing may never pull the cloth back under an ear or the skull.
        for r in range(head_rows + 1):
            for c in range(columns):
                d = grid[r][c] - centre
                if d.length < floor[r][c]:
                    grid[r][c] = centre + d.normalized() * floor[r][c]
    bm = bmesh.new()
    verts = [[bm.verts.new(p) for p in row] for row in grid]
    for r in range(len(grid) - 1):
        for c in range(columns):
            theta = (c + 0.5) / columns * 2 * math.pi
            front = min(theta, 2 * math.pi - theta)
            elevation = 88 - (88 + 62) * (r + 0.5) / head_rows
            if hood_down and r < head_rows:
                continue  # hood thrown back: collar and cape only
            if not cape and r >= head_rows:
                continue
            if r < head_rows and front < math.radians(face[0]) and face[2] < elevation < face[1]:
                continue  # face opening
            if r >= head_rows - 2 and front < math.radians(open_front):
                continue  # scarves and veils fall at the sides and back, not over the chest
            bm.faces.new((verts[r][c], verts[r][(c + 1) % columns],
                          verts[r + 1][(c + 1) % columns], verts[r + 1][c]))
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    head = obj.vertex_groups.new(name="head")
    chest = obj.vertex_groups.new(name="chest")
    for v in obj.data.vertices:
        w = surfaces.smoothstep(neck_z - 0.04, lm["chin"][2] + 0.01, v.co.z)
        head.add([v.index], float(w), "REPLACE")
        chest.add([v.index], float(1 - w), "REPLACE")
    grain_uv(ctx, obj, family, override=lambda p: "torso")
    hems = hem_rolls(ctx, obj, 0.003, key, family, color)
    return [finish(ctx, obj, family, color, key, 0.003)] + [finish_hem(ctx, h, family, color, key) for h in hems]


def kettle_hat(ctx):
    """Iron kettle hat (Eisenhut): deep skull to the brow, broad sloping brim."""
    lm, t = ctx.lm, ctx.t
    hair = bpy.data.objects.get("Hair_Scalp")
    tops = [max(v.co.z for v in ctx.body.data.vertices)]
    if hair is not None:
        tops.append(max(v.co.z for v in hair.data.vertices))
    top_z = max(tops) + 0.012
    rim_z = float(lm["eye_l"][2]) + 0.045
    head_pts = [v.co for v in ctx.body.data.vertices if abs(v.co.z - (rim_z + 0.02)) < 0.01]
    cx = 0.0
    cy = sum(p.y for p in head_pts) / len(head_pts)
    rx = max(abs(p.x) for p in head_pts) + 0.03
    ry = (max(p.y for p in head_pts) - min(p.y for p in head_pts)) / 2 + 0.03
    segments = 48
    profile = []
    for k in range(10):  # skull from apex to rim (ellipsoidal)
        a = (k / 9) * (math.pi / 2)
        profile.append((math.sin(a), rim_z + (top_z - rim_z) * math.cos(a)))
    profile.append((1.0, rim_z - 0.004))
    profile.append((1.0 + 0.07 / rx, rim_z - 0.035))
    profile.append((1.0 + 0.075 / rx, rim_z - 0.041))
    bm = bmesh.new()
    rings = []
    for scale, z in profile:
        ring = [bm.verts.new((cx + math.cos(i / segments * 2 * math.pi) * rx * max(scale, 1e-3),
                              cy + math.sin(i / segments * 2 * math.pi) * ry * max(scale, 1e-3), z))
                for i in range(segments)]
        rings.append(ring)
    for a_ring, b_ring in zip(rings, rings[1:]):
        for i in range(segments):
            bm.faces.new((a_ring[i], a_ring[(i + 1) % segments], b_ring[(i + 1) % segments], b_ring[i]))
    bmesh.ops.remove_doubles(bm, verts=rings[0], dist=1e-4)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    mesh = bpy.data.meshes.new("Garment_kettle_hat")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("Garment_kettle_hat", mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.vertex_groups.new(name="head").add([v.index for v in obj.data.vertices], 1.0, "REPLACE")
    grain_uv(ctx, obj, "iron", override=lambda p: "head")
    return [finish(ctx, obj, "iron", (0.78, 0.77, 0.75), "iron", 0.0025)]


def braies(ctx):
    """Linen braies, part of the body so no character is ever unclothed."""
    t = ctx.t
    waist = t["spine"].z - 0.03
    thigh = t["hips"].z - 0.16
    obj = extract_shell(ctx, "Clothing_Braies",
                        lambda v, b: (b in ("hips", "spine") or b.startswith("upperleg")) and thigh - 0.02 < v.co.z < waist + 0.03)
    bisect(obj, (0, 0, waist), (0, 0, 1))
    bisect(obj, (0, 0, thigh), (0, 0, -1))
    inflate(obj, constant(0.007))
    relax(ctx, obj, 14, constant(0.006), strength=0.5)
    grain_uv(ctx, obj, "linen")
    return finish(ctx, obj, "linen", textiles_color("linen"), "braies", 0.002)


# --------------------------------------------------------------------------
# Citizen layers (docs/SYSTEMS/CITIZEN_WARDROBE.md)
#
# Crowd bodies bake one base outfit (tunic or gown, hose, boots, belt). These
# garments and accessories are fitted to the same body in the same run but
# exported as separate skinned GLBs, and the census wardrobe rules pick which
# ones a resident wears (KCD2-style layering). They clear the baked base, not
# each other, except where a kit always stacks them (mail over the aketon, the
# bascinet over the mail coif).
# --------------------------------------------------------------------------

def layer_ease(ctx):
    """Extra clearance for torso layers worn over a baked tunic and belt (0 for heroes)."""
    return float(ctx.spec.get("layer_ease", 0.0))


def base_trees(ctx):
    """The skin plus the baked base torso garment (tunic or gown), when there is one."""
    trees = [ctx.bvh]
    base = ctx.layers.get(ctx.spec.get("apron_over", ""))
    if base is not None:
        trees.append(base)
    return trees


def outer_radius(trees, origin, direction, fallback=0.16):
    """Distance from a point inside the body to the outermost worn surface along `direction`.

    Rays start inside, so the first hit is the trunk (or the garment over it),
    never a hanging arm."""
    best = None
    for tree in trees:
        hit = tree.ray_cast(origin, direction, 1.0)
        if hit[0] is not None:
            d = (hit[0] - origin).length
            best = d if best is None else max(best, d)
    return best if best is not None else fallback


def horizontal(angle):
    """Unit direction around the body: 0 = front (-Y), +90 degrees = the wearer's left (+X)."""
    return Vector((math.sin(angle), -math.cos(angle), 0))


def belt_anchor(ctx, angle, drop=0.0):
    """Point just outside the baked belt at `angle`, and the outward direction there."""
    t = ctx.t
    origin = Vector((0, t["hips"].y, t["spine"].z - 0.02))
    out = horizontal(angle)
    skin = outer_radius([ctx.bvh], origin, out) + 0.03  # the belt sits 0.024 + 0.005 off the skin
    worn = outer_radius(base_trees(ctx), origin, out) + 0.006
    return origin + out * max(skin, worn) - Vector((0, 0, drop)), out


def clear_of_body(ctx, p, pad):
    """Push `p` horizontally out of the body and base garment by at least `pad`."""
    origin = Vector((0, ctx.t["hips"].y, p.z))
    flat = Vector((p.x, p.y - origin.y, 0))
    if flat.length < 1e-5:
        return p
    out = flat.normalized()
    r = outer_radius(base_trees(ctx), origin, out, fallback=0.0) + pad
    return p if flat.length >= r else origin + out * r


def clear_of(trees, axis_y, p, pad):
    """Push `p` horizontally (from the body axis) outside every tree by `pad`."""
    origin = Vector((0, axis_y, p.z))
    flat = Vector((p.x, p.y - axis_y, 0))
    if flat.length < 1e-5 or not trees:
        return p
    out = flat.normalized()
    r = outer_radius(trees, origin, out, fallback=0.0) + pad
    return p if flat.length >= r else origin + out * r


def rigid_part(ctx, obj, weights, family, color, key):
    """Weight a loose accessory mesh to bones, give it grain UVs and the textile material."""
    for bone, w in weights.items():
        obj.vertex_groups.new(name=bone).add([v.index for v in obj.data.vertices], w, "REPLACE")
    grain_uv(ctx, obj, family, override=lambda p: "torso")
    return finish(ctx, obj, family, color, key)


def lathe(name, profile, place, segments=12):
    """Closed surface of revolution; `profile` is [(radius, z)] top to bottom in the
    item's frame and `place(Vector)` maps that frame onto the body."""
    bm = bmesh.new()
    rings = []
    for radius, z in profile:
        if radius <= 1e-5:
            rings.append([bm.verts.new(place(Vector((0, 0, z))))])
            continue
        rings.append([bm.verts.new(place(Vector((radius * math.cos(2 * math.pi * i / segments),
                                                  radius * math.sin(2 * math.pi * i / segments), z))))
                      for i in range(segments)])
    for a, b in zip(rings, rings[1:]):
        for i in range(segments):
            if len(a) == 1 and len(b) == 1:
                break
            if len(a) == 1:
                bm.faces.new((a[0], b[(i + 1) % segments], b[i]))
            elif len(b) == 1:
                bm.faces.new((a[i], a[(i + 1) % segments], b[0]))
            else:
                bm.faces.new((a[i], a[(i + 1) % segments], b[(i + 1) % segments], b[i]))
    for ring in (rings[0], rings[-1]):
        if len(ring) > 2:
            bm.faces.new(ring)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def frame_placer(origin, out, up=Vector((0, 0, 1)), squash=1.0):
    """Item frame -> body: local X along the body surface, local Y outward
    (flattened by `squash`), local Z along `up`."""
    up = up.normalized()
    out = (out - up * out.dot(up)).normalized()
    side = up.cross(out).normalized()
    return lambda v: origin + side * v.x + out * (v.y * squash) + up * v.z


def keys(ctx):
    """Iron key ring at the girdle: the housewife's authority (dossier: keys at belt)."""
    anchor, out = belt_anchor(ctx, math.radians(58))
    iron = ctx.palette("keys", (0.30, 0.29, 0.28))
    hang = anchor + out * 0.005 - Vector((0, 0, 0.035))
    parts = [rigid_part(ctx, torus("Garment_keys_ring", hang, out, 0.02, 0.0022, 14, 5),
                        {"hips": 1.0}, "iron", iron, "keys")]
    side = Vector((0, 0, 1)).cross(out).normalized()
    for i, (dx, length) in enumerate(((-0.012, 0.075), (0.0, 0.095), (0.013, 0.065))):
        top = hang + side * dx - Vector((0, 0, 0.02))
        bow = torus(f"Garment_keys_bow{i}", top - Vector((0, 0, 0.008)), out, 0.008, 0.0018, 10, 4)
        parts.append(rigid_part(ctx, bow, {"hips": 1.0}, "iron", iron, "keys"))
        shank = top - Vector((0, 0, 0.016 + length / 2))
        parts.append(rigid_box(ctx, f"Garment_keys_shank{i}", shank, (0.0045, 0.0045, length), "hips",
                               "iron", iron, "keys"))
        bit = shank - Vector((0, 0, length / 2 - 0.008)) + side * 0.006
        parts.append(rigid_box(ctx, f"Garment_keys_bit{i}", bit, (0.012, 0.004, 0.014), "hips",
                               "iron", iron, "keys"))
    return parts


def paternoster(ctx):
    """Prayer beads hanging in a loop from the girdle (clergy, pious burghers)."""
    a, out = belt_anchor(ctx, math.radians(-32))
    b, _ = belt_anchor(ctx, math.radians(-14))
    beads = bmesh.new()
    count = 24
    for i in range(count):
        s = i / (count - 1)
        p = a.lerp(b, s) - Vector((0, 0, 0.17 * math.sin(math.pi * s) ** 0.7))
        p = clear_of_body(ctx, p, 0.012)
        bmesh.ops.create_uvsphere(beads, u_segments=6, v_segments=4,
                                  radius=0.0085 if i % 6 == 0 else 0.0062,
                                  matrix=Matrix.Translation(p))
    low = clear_of_body(ctx, a.lerp(b, 0.5) - Vector((0, 0, 0.2)), 0.012)
    bmesh.ops.create_cone(beads, cap_ends=True, segments=6, radius1=0.012, radius2=0.002, depth=0.04,
                          matrix=Matrix.Translation(low - Vector((0, 0, 0.012))))
    mesh = bpy.data.meshes.new("Garment_paternoster")
    beads.to_mesh(mesh)
    beads.free()
    obj = bpy.data.objects.new("Garment_paternoster", mesh)
    bpy.context.scene.collection.objects.link(obj)
    return [rigid_part(ctx, obj, {"hips": 1.0}, "leather", ctx.palette("paternoster", (0.36, 0.22, 0.10)),
                       "paternoster")]


def _strap_path(ctx, keypoints, pad, samples=40):
    """A strap laid over the worn body through keypoints (Catmull-Rom), each sample
    pushed out of the body: horizontally on the trunk, from the chest centre at
    the shoulder."""
    t = ctx.t
    pts = [keypoints[0]] + keypoints + [keypoints[-1]]
    path = []
    for seg in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[seg - 1], pts[seg], pts[seg + 1], pts[seg + 2]
        steps = max(2, samples // (len(keypoints) - 1))
        for k in range(steps):
            u = k / steps
            path.append(0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u
                               + (-p0 + 3 * p1 - 3 * p2 + p3) * u * u * u))
    path.append(keypoints[-1])
    shoulder_z = t["chest"].z + 0.06
    centre = Vector((0, t["hips"].y, t["chest"].z))
    trees = base_trees(ctx)
    out = []
    for p in path:
        if p.z > shoulder_z:
            d = (p - centre).normalized()
            r = 0.0
            for tree in trees:
                hit = tree.ray_cast(centre + d * 0.6, -d, 0.6)
                if hit[0] is not None:
                    r = max(r, (hit[0] - centre).length)
            out.append(centre + d * (max(r, (p - centre).length * 0.6) + pad))
        else:
            out.append(clear_of_body(ctx, p, pad))
    return out


def _chest_hips_weights(ctx, obj):
    t = ctx.t
    chest = obj.vertex_groups.new(name="chest")
    hips = obj.vertex_groups.new(name="hips")
    for v in obj.data.vertices:
        w = float(surfaces.smoothstep(t["spine"].z, t["chest"].z, v.co.z))
        chest.add([v.index], w, "REPLACE")
        hips.add([v.index], 1.0 - w, "REPLACE")


def _shoulder_top(ctx, x):
    """Highest worn point over the shoulder at lateral offset x."""
    t = ctx.t
    best = t["chest"].z + 0.1
    for tree in base_trees(ctx):
        hit = tree.ray_cast(Vector((x, t["upperarm.l"].y, t["head"].z + 0.3)), Vector((0, 0, -1)), 1.0)
        if hit[0] is not None:
            best = max(best, hit[0].z)
    return Vector((x, t["upperarm.l"].y, best))


# Scrip proportions in the bag's frame (x along the body, y outward, z up), metres.
# Profile (radius, z) of the pouch before it is pressed flat to SCRIP_DEPTH of its width.
SCRIP_PROFILE = [(0.0, 0.105), (0.115, 0.105), (0.122, 0.08), (0.125, 0.0), (0.12, -0.06),
                 (0.1, -0.095), (0.06, -0.112), (0.0, -0.115)]
SCRIP_DEPTH = 0.26
PEWTER = (0.62, 0.62, 0.58)


def _profile_radius(profile, z):
    """Radius of a top-to-bottom lathe profile at height z (0 above or below it)."""
    for (r0, z0), (r1, z1) in zip(profile, profile[1:]):
        if z1 <= z <= z0:
            return r0 + (r1 - r0) * (z0 - z) / max(z0 - z1, 1e-6)
    return 0.0


def _scrip_front(x, z):
    """Outward depth of the pressed scrip's front face at (x, z) in the bag frame."""
    r = _profile_radius(SCRIP_PROFILE, min(z, SCRIP_PROFILE[1][1] - 1e-4))
    return SCRIP_DEPTH * math.sqrt(max(r * r - x * x, 0.0))


def _sheet(name, rows, place, out):
    """Open quad sheet from a grid of bag-frame points, faces wound to look along `out`."""
    bm = bmesh.new()
    verts = [[bm.verts.new(place(p)) for p in row] for row in rows]
    for a, b in zip(verts, verts[1:]):
        for i in range(len(a) - 1):
            bm.faces.new((a[i], a[i + 1], b[i + 1], b[i]))
    bm.normal_update()
    if sum(f.normal.dot(out) for f in bm.faces) < 0:
        bmesh.ops.reverse_faces(bm, faces=list(bm.faces))
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _scallop(name, place, out, centre, radius):
    """Pewter pilgrim badge: a ribbed scallop fan (hinge down) with its two ears, in relief.

    Scallop shells and their pewter copies are the Compostela sign; Baltic towns have them in
    finds (task R-2034). One small plate, 0.0015 m thick, on the scrip flap."""
    rows = []
    for i in range(4):
        rho = radius * i / 3.0 if i else radius * 0.08
        row = []
        for j in range(17):
            theta = math.radians(-78 + 156 * j / 16)
            rib = 0.0011 * math.cos(theta * 9.0) ** 2 * (rho / radius)
            dome = 0.0028 * math.sqrt(max(1.0 - rho / radius, 0.0))
            row.append(centre + Vector((rho * math.sin(theta), dome + rib, rho * math.cos(theta))))
        rows.append(row)
    shell = _sheet(name, rows, place, out)
    ears = [[centre + Vector((x, 0.0012, z)) for x in (-0.009, 0.0, 0.009)] for z in (-0.002, 0.004)]
    ear = _sheet(name + "_ears", ears, place, out)
    activate(shell)
    ear.select_set(True)
    bpy.ops.object.join()
    obj = bpy.context.active_object
    solidify(obj, 0.0015)
    return obj


def satchel(ctx):
    """Scrip on the left hip, strap over the right shoulder (clerks, merchants, pilgrims, pedlars).

    A pressed pouch under a rounded flap closed by a toggle through a leather tab, and a
    pewter scallop on the flap that only pilgrims show (task R-2034). Each part has its own
    material key so the runtime can give them different cloth: `satchel` (pouch and flap,
    dyed), `satchel_strap` (strap and tab), `satchel_toggle` (wood or horn), `satchel_badge`
    (pewter; CitizenBags hides it on everyone but pilgrims)."""
    t = ctx.t
    leather = ctx.palette("satchel", (0.30, 0.19, 0.10))
    shoulder = _shoulder_top(ctx, -t["upperarm.l"].x * 0.55)
    hip_front, _ = belt_anchor(ctx, math.radians(78), drop=0.05)
    hip_back, _ = belt_anchor(ctx, math.radians(112), drop=0.05)
    # Keypoints inside the trunk: _strap_path pushes them out onto the worn surface
    # (points 0.3 m out stayed there and the strap hung off the body as a hoop).
    chest_front = Vector((0.0, t["hips"].y - 0.02, t["chest"].z - 0.06))
    chest_back = Vector((0.0, t["hips"].y + 0.02, t["chest"].z - 0.06))
    path = _strap_path(ctx, [hip_front, chest_front, shoulder, chest_back, hip_back], 0.005)
    strap = strap_tube(ctx, "Garment_satchel_strap", path, 0.03, None)
    _chest_hips_weights(ctx, strap)
    grain_uv(ctx, strap, "leather", override=lambda p: "torso")
    parts = [finish(ctx, strap, "leather", leather, "satchel_strap")]
    anchor, out = belt_anchor(ctx, math.radians(95), drop=0.15)
    centre = anchor + out * 0.035
    place = frame_placer(centre, out)
    bag = lathe("Garment_satchel_bag", SCRIP_PROFILE, place, segments=16)
    # Press the lathe into a pouch: thin outward, wide along the body.
    for v in bag.data.vertices:
        local = v.co - centre
        along_out = out * local.dot(out)
        v.co = centre + (local - along_out) + along_out * SCRIP_DEPTH
    parts.append(rigid_part(ctx, bag, {"hips": 1.0}, "leather", leather, "satchel"))
    # Flap: from the top seam over the front down to a rounded point, 5 mm off the pouch.
    half, top = 0.118, SCRIP_PROFILE[1][1]
    rows = []
    for i in range(9):
        s = i / 8.0
        row = []
        for j in range(11):
            x = -half + 2 * half * j / 10
            tip = -0.012 - 0.05 * math.cos(0.5 * math.pi * x / half)
            z = top + 0.004 - s * (top + 0.004 - tip)
            y = _scrip_front(x, z) + 0.005
            row.append(Vector((x, y * (0.45 if i == 0 else 1.0), z)))
        rows.append(row)
    flap = _sheet("Garment_satchel_flap", rows, place, out)
    solidify(flap, 0.003)
    parts.append(rigid_part(ctx, flap, {"hips": 1.0}, "leather", leather, "satchel"))
    # Toggle (a turned peg) through a tab sewn to the pouch just under the flap's point.
    tip_z = -0.062
    tab_y = _scrip_front(0.0, tip_z - 0.012) + 0.003
    parts.append(rigid_box(ctx, "Garment_satchel_tab", place(Vector((0.0, tab_y, tip_z - 0.012))),
                           (0.016, 0.016, 0.03), "hips", "leather", leather, "satchel_strap"))
    peg = bmesh.new()
    bmesh.ops.create_cone(peg, cap_ends=True, segments=6, radius1=0.0055, radius2=0.0055, depth=0.038)
    mesh = bpy.data.meshes.new("Garment_satchel_toggle")
    peg.to_mesh(mesh)
    peg.free()
    toggle = bpy.data.objects.new("Garment_satchel_toggle", mesh)
    bpy.context.scene.collection.objects.link(toggle)
    peg_at = Vector((0.0, tab_y + 0.012, tip_z - 0.008))
    for v in toggle.data.vertices:
        # Cone axis (z) laid along the body (bag x).
        v.co = place(peg_at + Vector((v.co.z, v.co.y, v.co.x)))
    parts.append(rigid_part(ctx, toggle, {"hips": 1.0}, "leather",
                            ctx.palette("satchel_toggle", (0.20, 0.13, 0.07)), "satchel_toggle"))
    badge_z = 0.035
    badge = _scallop("Garment_satchel_badge", place, out,
                     Vector((0.0, _scrip_front(0.0, badge_z) + 0.009, badge_z - 0.012)), 0.022)
    parts.append(rigid_part(ctx, badge, {"hips": 1.0}, "iron", PEWTER, "satchel_badge"))
    return parts


def _sack_gather(v):
    """Bag-frame point of the back sack with gathers under the tie and a ruffled mouth."""
    r = math.hypot(v.x, v.y)
    if r < 1e-5:
        return v
    angle = math.atan2(v.y, v.x)
    pleat = 0.0
    if v.z > 0.29:
        pleat = 0.009 * math.sin(angle * 9.0)  # loose mouth above the tie
    elif v.z > 0.12:
        pleat = 0.006 * math.sin(angle * 11.0) * float(surfaces.smoothstep(0.12, 0.27, v.z))
    k = (r + pleat) / r
    return Vector((v.x * k, v.y * k, v.z))


def back_sack(ctx):
    """Grain or wool sack on the back, its neck gathered and tied with a cord that runs on
    over the right shoulder as the carrying rope (porters, carters, millers; task R-2034)."""
    t = ctx.t
    sacking = ctx.palette("back_sack", (0.62, 0.55, 0.42))
    back = horizontal(math.pi)
    origin = Vector((0, t["hips"].y, t["chest"].z - 0.1))
    r = outer_radius(base_trees(ctx), origin, back)
    centre = origin + back * (r + 0.1)
    up = Vector((-0.28, 0.0, 1.0))
    place = frame_placer(centre, back, up=up, squash=0.62)
    profile = [(0.0, 0.335), (0.04, 0.34), (0.056, 0.322), (0.042, 0.298), (0.031, 0.282), (0.036, 0.266),
               (0.065, 0.245), (0.125, 0.195), (0.157, 0.09), (0.17, -0.05), (0.158, -0.165), (0.112, -0.228),
               (0.0, -0.25)]
    sack = lathe("Garment_back_sack", profile, lambda v: place(_sack_gather(v)), segments=16)
    # Lumpy grain: a little low-frequency noise so the sack is not a turned vase.
    for v in sack.data.vertices:
        d = v.co - centre
        bump = 0.012 * math.sin(d.x * 41 + d.z * 23) + 0.008 * math.sin(d.y * 37 - d.z * 29)
        if d.length > 1e-4:
            v.co += d.normalized() * bump
    parts = [rigid_part(ctx, sack, {"chest": 1.0}, "linen", sacking, "back_sack")]
    rope_colour = (0.55, 0.47, 0.33)
    tie = [place(Vector((0.037 * math.cos(2 * math.pi * i / 12), 0.037 * math.sin(2 * math.pi * i / 12), 0.283)))
           for i in range(12)]
    parts.append(strap_tube(ctx, "Garment_back_sack_tie", tie, 0.011, {"chest": 1.0}, closed=True,
                            family="linen", color=rope_colour, key="back_sack_rope"))
    neck = place(Vector((0, 0, 0.283)))
    shoulder = _shoulder_top(ctx, -t["upperarm.l"].x * 0.5)
    front = Vector((-t["upperarm.l"].x * 0.35, t["hips"].y - 0.02, t["chest"].z - 0.02))
    rope = strap_tube(ctx, "Garment_back_sack_rope", _strap_path(ctx, [neck, shoulder, front], 0.006), 0.014,
                      None)
    rope.vertex_groups.new(name="chest").add([v.index for v in rope.data.vertices], 1.0, "REPLACE")
    grain_uv(ctx, rope, "linen", override=lambda p: "torso")
    parts.append(finish(ctx, rope, "linen", rope_colour, "back_sack_rope"))
    return parts


def head_shell(ctx, name, key, family, color, ease, rim, apex=0.0, rows=12, columns=40, thickness=0.003,
               roll=0.0):
    """Close cap or helmet: crown down to rim(theta) degrees of elevation round the head
    (0 = front). Radii are the outermost hit on head or hair plus ease, like head_wrap."""
    t, lm = ctx.t, ctx.lm
    targets = [trunk_bvh(ctx)]
    hair = bpy.data.objects.get("Hair_Scalp")
    if hair is not None:
        targets.append(BVHTree.FromObject(hair, bpy.context.evaluated_depsgraph_get()))
    eyes_mid = Vector(((lm["eye_l"] + lm["eye_r"]) / 2).tolist())
    centre = Vector((0, t["head"].y + 0.01, eyes_mid.z + 0.01))

    def outer(direction):
        best = 0.0
        for tree in targets:
            hit = tree.ray_cast(centre + direction * 0.6, -direction)
            if hit[0] is not None:
                best = max(best, (hit[0] - centre).dot(direction))
        return best

    grid = []
    for r in range(rows + 1):
        s = r / rows
        row = []
        for c in range(columns):
            theta = c / columns * 2 * math.pi
            elevation = math.radians(86 - (86 - rim(theta)) * s)
            d = horizontal(theta) * math.cos(elevation) + Vector((0, 0, math.sin(elevation)))
            p = centre + d * (outer(d) + ease)
            if apex:
                # Pointed skull (bascinet): raise the crown, lean the point back.
                p += Vector((0, 0.25 * apex, apex)) * max(0.0, 1.0 - s / 0.45) ** 2
            row.append(p)
        grid.append(row)
    floor = [[(p - centre).length for p in row] for row in grid]
    for _ in range(3):
        grid = [[(grid[r][c] * 2 + grid[r][(c + 1) % columns] + grid[r][c - 1]
                  + (grid[r - 1][c] if r > 0 else grid[r][c]) + (grid[r + 1][c] if r < rows else grid[r][c])) / 6
                 for c in range(columns)] for r in range(rows + 1)]
        grid = [[centre + (p - centre).normalized() * max((p - centre).length, floor[r][c])
                 for c, p in enumerate(row)] for r, row in enumerate(grid)]
    bm = bmesh.new()
    verts = [[bm.verts.new(p) for p in row] for row in grid]
    top = bm.verts.new(sum(grid[0], Vector()) / columns + Vector((0, 0, 0.004)))
    for c in range(columns):
        bm.faces.new((top, verts[0][(c + 1) % columns], verts[0][c]))
    for r in range(rows):
        for c in range(columns):
            bm.faces.new((verts[r][c], verts[r][(c + 1) % columns], verts[r + 1][(c + 1) % columns],
                          verts[r + 1][c]))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.vertex_groups.new(name="head").add([v.index for v in obj.data.vertices], 1.0, "REPLACE")
    grain_uv(ctx, obj, family, override=lambda p: "head")
    parts = [finish(ctx, obj, family, color, key, thickness)]
    if roll:
        parts += [finish_hem(ctx, h, family, color, key) for h in hem_rolls(ctx, obj, roll, key, family, color)]
    return parts


def _front_rim(front_deg, side_deg, start=35.0, end=115.0):
    """Rim elevation: `front_deg` over the brow easing to `side_deg` at the sides and back."""
    def rim(theta):
        front = math.degrees(min(theta, 2 * math.pi - theta))
        return front_deg + (side_deg - front_deg) * float(surfaces.smoothstep(start, end, front))
    return rim


def wool_cap(ctx):
    """Close wool cap with a rolled brim (labourers, boys, Estonian townsmen)."""
    return head_shell(ctx, "Garment_wool_cap", "wool_cap", "wool", ctx.palette("wool_cap", (0.36, 0.29, 0.21)),
                      ease=0.008, rim=_front_rim(24, 12), roll=0.009)


def coif(ctx):
    """Linen coif tied under the chin: the everyday working man's head covering."""
    # A close cap over the brow, down over the ears to the jaw at the sides and nape:
    # a head shell, not a hood, so nothing spreads over the shoulders.
    return head_shell(ctx, "Garment_coif", "coif", "linen", ctx.palette("coif", (0.80, 0.77, 0.68)),
                      ease=0.006, rim=_front_rim(30, -42, start=35, end=80), thickness=0.002, roll=0.004)


def veil_over(ctx):
    """Linen veil over the baked headscarf: married burgher women; black for nuns and widows."""
    return head_wrap(ctx, "Garment_veil_over", "veil_over", "linen", ctx.palette("veil_over", (0.86, 0.84, 0.78)),
                     head_ease=0.026, hem_below_neck=0.24, face=(56, 12, -85), cape_ease=0.045, hair=False,
                     open_front=80, folds=0.01, max_flare=0.6,
                     # Lies over the baked gown's shoulders (the surcoat's are wider than the skin's).
                     cape_layers=tuple(k for k in (ctx.spec.get("apron_over"),) if k in ctx.layers))


def mail_coif(ctx):
    """Mail coif with a short cape over the shoulders (men-at-arms, sergeants, knights)."""
    parts = head_wrap(ctx, "Garment_mail_coif", "mail_coif", "mail", (0.42, 0.42, 0.44), head_ease=0.012,
                      hem_below_neck=0.15, face=(44, 26, -60), cape_ease=0.05 + layer_ease(ctx), hair=True,
                      folds=0.003)
    # The knight's surcoat goes over the coif's cape (surcoat() clears this tree).
    ctx.layers["mail_coif"] = BVHTree.FromObject(parts[0], bpy.context.evaluated_depsgraph_get())
    return parts


def bascinet(ctx):
    """Open-faced pointed bascinet (1330s-40s), worn over the mail coif."""
    return head_shell(ctx, "Garment_bascinet", "bascinet", "iron", (0.74, 0.73, 0.71), ease=0.032,
                      rim=_front_rim(26, -18, start=40, end=100), apex=0.05, thickness=0.0025)


# --------------------------------------------------------------------------
# Armour range of the 1340s (WD-4, docs/SYSTEMS/CITIZEN_WARDROBE.md)
#
# Sources: history/dossiers/military/arms-and-armour-livonia-1340s.md (Order
# knight: mail hauberk, surcoat with black cross, heater shield). The stack is
# aketon -> mail -> coat of plates -> mail coif or aventail -> surcoat -> mantle,
# each layer clearing the trees registered in ctx.layers by the layers under it.
# --------------------------------------------------------------------------

MAIL_GREY = (0.42, 0.42, 0.44)


def _armour_trees(ctx, keys=("gambeson", "mail_haubergeon", "coat_of_plates", "mail_coif", "aventail",
                              "surcoat")):
    return [ctx.layers[k] for k in keys if k in ctx.layers]


def _register(ctx, key, obj):
    ctx.layers[key] = BVHTree.FromObject(obj, bpy.context.evaluated_depsgraph_get())


def _rivet_studs(ctx, name, tree, rows, columns):
    """Small iron rivet heads in rows on the front and back of the coat of plates."""
    t = ctx.t
    bm = bmesh.new()
    for z in rows:
        for x in columns:
            for side in (-1, 1):  # front (-Y) and back (+Y)
                hit = tree.ray_cast(Vector((x, t["hips"].y + side * -0.8, z)), Vector((0, side, 0)), 2.0)
                if hit[0] is None:
                    continue
                normal = hit[1] if hit[1].dot(Vector((0, -side, 0))) > 0 else -hit[1]
                # A cover over riveted plates shows the heads, not the plates.
                m = normal.to_track_quat("Z", "Y").to_matrix().to_4x4()
                m.translation = hit[0] + normal * 0.0035
                bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=4, radius1=0.0075,
                                      radius2=0.004, depth=0.004, matrix=m)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    _chest_hips_weights(ctx, obj)
    grain_uv(ctx, obj, "iron", override=lambda p: "torso")
    return finish(ctx, obj, "iron", (0.78, 0.77, 0.75), "plate_rivets")


def coat_of_plates(ctx):
    """Coat of plates (1340s): riveted plates behind a dyed cloth cover, sleeveless, over the mail."""
    t = ctx.t
    parts = tunic(ctx, "coat_of_plates", sleeve="none", hem="thigh", extra_ease=0.05 + layer_ease(ctx),
                  belted=False, color_key="coat_of_plates", flare=1.35, folds=8)
    trees = _armour_trees(ctx, ("gambeson", "mail_haubergeon", "mail_coif", "aventail"))
    for part in parts:
        for v in part.data.vertices:
            v.co = clear_of(trees, t["hips"].y, v.co, 0.012)
    _register(ctx, "coat_of_plates", parts[0])
    rows = [t["chest"].z - 0.03 - 0.05 * i for i in range(5)]
    parts.append(_rivet_studs(ctx, "Garment_coat_of_plates_rivets", ctx.layers["coat_of_plates"], rows,
                              (-0.09, -0.03, 0.03, 0.09)))
    return parts


def aventail(ctx):
    """Mail aventail hung from the bascinet: a wide shoulder tippet, the open face left bare."""
    parts = head_wrap(ctx, "Garment_aventail", "aventail", "mail", MAIL_GREY, head_ease=0.012,
                      hem_below_neck=0.21, face=(66, 30, -66), cape_ease=0.065 + layer_ease(ctx), hair=True,
                      folds=0.003)
    _register(ctx, "aventail", parts[0])
    return parts


def great_helm(ctx):
    """Flat-topped great helm (Topfhelm) with an eye slit and breaths: knights, ceremony."""
    ease = 0.05
    parts = head_shell(ctx, "Garment_great_helm", "great_helm", "iron", (0.70, 0.69, 0.67), ease=ease,
                       rim=lambda theta: -50.0, thickness=0.003)
    helm = parts[0]
    top = max(v.co.z for v in helm.data.vertices)
    flat = top - 0.035
    for v in helm.data.vertices:
        if v.co.z > flat:
            v.co.z = flat + (v.co.z - flat) * 0.12  # the crown is nearly flat
    # Eye slit and the vertical bar of the cross-shaped sights, proud of the face plate.
    lm = ctx.lm
    eyes = Vector(((lm["eye_l"] + lm["eye_r"]) / 2).tolist())
    hit = trunk_bvh(ctx).ray_cast(Vector((0, -1.0, eyes.z)), Vector((0, 1, 0)), 2.0)
    face_y = (hit[0].y if hit[0] is not None else eyes.y) - ease - 0.001
    dark = (0.04, 0.04, 0.04)
    parts.append(rigid_box(ctx, "Garment_great_helm_slit", Vector((0, face_y, eyes.z)), (0.12, 0.004, 0.012),
                           "head", "iron", dark, "great_helm_slit"))
    parts.append(rigid_box(ctx, "Garment_great_helm_bar", Vector((0, face_y, eyes.z - 0.03)),
                           (0.012, 0.004, 0.12), "head", "iron", dark, "great_helm_slit"))
    return parts


def mail_chausses(ctx):
    """Mail chausses over the baked hose, from the hip down over the top of the boots."""
    t = ctx.t
    obj = extract_shell(ctx, "Garment_mail_chausses", lambda v, b: b.startswith(("upperleg", "lowerleg")))
    bisect(obj, (0, 0, t["foot.l"].z + 0.07), (0, 0, -1))
    bisect(obj, (0, 0, t["hips"].z - 0.02), (0, 0, 1))
    hull_fit(ctx, obj, constant(0.016), frames=("leg.l", "leg.r"))
    relax(ctx, obj, 4, constant(0.012), strength=0.35, drape=6)
    grain_uv(ctx, obj, "mail")
    return [finish(ctx, obj, "mail", MAIL_GREY, "chausses_mail", 0.003)]


def _open_tube(name, centre, axis, profile, segments=18):
    """Open tube round `axis` through `centre`; profile is [(radius, distance along axis)]."""
    axis = axis.normalized()
    ref = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))
    u = axis.cross(ref).normalized()
    w = axis.cross(u)
    bm = bmesh.new()
    rings = []
    for radius, along in profile:
        rings.append([bm.verts.new(centre + axis * along + (u * math.cos(2 * math.pi * i / segments)
                                                            + w * math.sin(2 * math.pi * i / segments)) * radius)
                      for i in range(segments)])
    for a, b in zip(rings, rings[1:]):
        for i in range(segments):
            bm.faces.new((a[i], a[(i + 1) % segments], b[(i + 1) % segments], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def gauntlets(ctx):
    """Plate gauntlets: hand shells with a flared cuff over the end of the sleeve."""
    t = ctx.t
    hands = extract_shell(ctx, "Garment_gauntlets", lambda v, b: b.startswith(("hand", "wrist")))
    inflate(hands, constant(0.004))
    relax(ctx, hands, 3, constant(0.004), strength=0.3)
    grain_uv(ctx, hands, "iron")
    iron = (0.74, 0.73, 0.71)
    parts = [finish(ctx, hands, "iron", iron, "gauntlet_iron", 0.002)]
    sleeves = [ctx.bvh] + _armour_trees(ctx, ("gambeson", "mail_haubergeon"))
    for s, sign in (("l", 1), ("r", -1)):
        wrist = t[f"wrist.{s}"]
        axis = Vector((sign, 0, 0))
        probe = wrist - axis * 0.02
        r = max(outer_radius(sleeves, probe, d, fallback=0.04)
                for d in (Vector((0, 1, 0)), Vector((0, -1, 0)), Vector((0, 0, 1)), Vector((0, 0, -1))))
        cuff = _open_tube(f"Garment_gauntlet_cuff_{s}", wrist, axis,
                          [(r + 0.022, -0.1), (r + 0.012, -0.07), (r + 0.006, -0.03), (r * 0.6, 0.015)])
        for v in cuff.data.vertices:
            pass
        cuff.vertex_groups.new(name=f"lowerarm.{s}").add([v.index for v in cuff.data.vertices], 1.0, "REPLACE")
        grain_uv(ctx, cuff, "iron")
        parts.append(finish(ctx, cuff, "iron", iron, "gauntlet_iron", 0.002))
    return parts


def _mantle_weights(ctx, obj, top_z, hem_z):
    t = ctx.t
    for v in obj.data.vertices:
        chest = float(surfaces.smoothstep(t["spine"].z, t["chest"].z, v.co.z))
        legs = skirt_weights(ctx, v.co, top_z, hem_z)
        weights = {k: w * (1 - chest) * 0.6 for k, w in legs.items()}  # hang from the trunk, swing a little
        weights["chest"] = chest + (1 - chest) * 0.4
        set_weights(obj, v.index, weights)


def _cross_patch(ctx, name, tree, centre_deg, z, size, top_z, hem_z):
    """Black Order cross (arms with widened ends) laid on the mantle surface at `centre_deg`
    round the body and height `z`. Disjoint rectangles meshed finely and projected onto `tree`
    along horizontal rays, so the cross follows the cloth and never overlaps itself."""
    t = ctx.t
    a, e = size * 0.2, size * 0.14
    h = size / 2
    rects = [(-a / 2, a / 2, -a / 2, a / 2),
             (a / 2, h - e, -a / 2, a / 2), (-(h - e), -a / 2, -a / 2, a / 2),
             (-a / 2, a / 2, a / 2, h - e), (-a / 2, a / 2, -(h - e), -a / 2),
             (h - e, h, -a * 0.85, a * 0.85), (-h, -(h - e), -a * 0.85, a * 0.85),
             (-a * 0.85, a * 0.85, h - e, h), (-a * 0.85, a * 0.85, -h, -(h - e))]
    axis_y = t["hips"].y
    phi0 = math.radians(centre_deg)
    probe = Vector((0, axis_y, z)) + horizontal(phi0) * 1.0
    hit0 = tree.ray_cast(probe, -horizontal(phi0), 2.0)
    radius = max(0.1, 1.0 - hit0[3]) if hit0[0] is not None else 0.2

    def project(u, v):
        phi = phi0 + u / radius
        d = horizontal(phi)
        hit = tree.ray_cast(Vector((0, axis_y, z + v)) + d * 1.0, -d, 2.0)
        if hit[0] is None:
            return None
        normal = hit[1] if hit[1].dot(d) > 0 else -hit[1]
        return hit[0] + normal * 0.0025

    bm = bmesh.new()
    step = 0.018
    for u0, u1, v0, v1 in rects:
        nu, nv = max(1, round((u1 - u0) / step)), max(1, round((v1 - v0) / step))
        grid = [[project(u0 + (u1 - u0) * i / nu, v0 + (v1 - v0) * j / nv) for i in range(nu + 1)]
                for j in range(nv + 1)]
        verts = [[bm.verts.new(p) if p is not None else None for p in row] for row in grid]
        for j in range(nv):
            for i in range(nu):
                quad = (verts[j][i], verts[j][i + 1], verts[j + 1][i + 1], verts[j + 1][i])
                if all(q is not None for q in quad):
                    face = bm.faces.new(quad)
                    outward = face.calc_center_median() - Vector((0, axis_y, face.calc_center_median().z))
                    face.normal_update()
                    if face.normal.dot(outward) < 0:
                        face.normal_flip()
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    _mantle_weights(ctx, obj, top_z, hem_z)
    grain_uv(ctx, obj, "wool", override=lambda p: "torso")
    return finish(ctx, obj, "wool", (0.05, 0.05, 0.05), "order_cross")


def order_mantle(ctx):
    """Livonian Order mantle: white wool cloak on the shoulders, open at the front, with the black
    cross at the left breast and large on the back (arms-and-armour dossier: surcoat with black
    cross). The cross is a separate black patch, so only the white wool takes the wear_dye."""
    t = ctx.t
    top_z = ctx.collar(t["head"].y) - 0.02
    hem_z = t["lowerleg.l"].z - 0.1
    color = ctx.palette("order_mantle", (0.86, 0.85, 0.80))
    mantle = _cloak(ctx, "Garment_order_mantle", "order_mantle", color, top_z, hem_z,
                    _armour_trees(ctx) + base_trees(ctx))
    tree = BVHTree.FromObject(mantle, bpy.context.evaluated_depsgraph_get())
    return [mantle,
            _cross_patch(ctx, "Garment_order_cross_back", tree, 180.0, top_z - 0.22, 0.26, top_z, hem_z),
            _cross_patch(ctx, "Garment_order_cross_breast", tree, 34.0, top_z - 0.2, 0.11, top_z, hem_z)]


def cappa(ctx):
    """Dominican cappa: black wool cloak on the shoulders, open down the front over the white
    habit and scapular, to mid-calf (its black capuce is the `hood`, worn over it)."""
    t = ctx.t
    top_z = ctx.collar(t["head"].y) - 0.02
    hem_z = t["lowerleg.l"].z - 0.14
    # The habit without its T-posed sleeves (the arms hang inside the cloak in play), so the
    # cloak may be pushed fully clear of the flared skirt instead of being clamped into it.
    trees = [trunk_bvh(ctx)] + [ctx.layers[k] for k in ("scapular",) if k in ctx.layers]
    over = bpy.data.objects.get("Garment_" + ctx.spec.get("apron_over", "habit"))
    if over is not None:
        reach = t["upperarm.l"].x + 0.02
        verts = [v.co.copy() for v in over.data.vertices]
        polys = [list(f.vertices) for f in over.data.polygons
                 if abs(f.center.x) < reach or f.center.z < t["hips"].z]
        trees.append(BVHTree.FromPolygons(verts, polys))
    color = ctx.palette("cappa", (0.07, 0.065, 0.06))
    cloak = _cloak(ctx, "Garment_cappa", "cappa", color, top_z, hem_z, trees, open_deg=30.0, max_push=0.15,
                   side=0.09, pad=0.055)
    # The black capuce's cape lies over the cappa (spec `hood_over`).
    ctx.layers["cappa"] = BVHTree.FromObject(cloak, bpy.context.evaluated_depsgraph_get())
    return [cloak]


def _cloak(ctx, name, key, color, top_z, hem_z, trees, open_deg=20.0, max_push=0.06, side=0.035, pad=0.03):
    """Cloak hung from the shoulders, open at the front by `open_deg` each side, clearing `trees`
    (but never pushed more than `max_push` past its own radius)."""
    t = ctx.t
    axis_y = t["hips"].y
    trunk = trunk_bvh(ctx)
    half = t["upperarm.l"].x + side  # outside the hanging arm
    rows, columns = 18, 56
    phase = 1.7
    grid = []
    for r in range(rows + 1):
        s = (r / rows) ** 1.35
        z = top_z + (hem_z - top_z) * s
        origin = Vector((0, axis_y, z))
        row = []
        for c in range(columns):
            theta = c / columns * 2 * math.pi
            d = horizontal(theta)
            # Capped: a stray arm-weighted vertex in the trunk tree must not throw a spike.
            depth = min(outer_radius([trunk], origin, d, fallback=0.12), 0.2) + pad
            wide = math.sin(theta) ** 2 * float(surfaces.smoothstep(0.0, 0.16, s))
            radius = max(depth, depth + (half - depth) * wide) * (1.0 + 0.2 * s * s)
            radius += 0.012 * s * math.sin(theta * 8 + phase) + 0.006 * s * math.sin(theta * 17)
            # Clear the armour, but never chase the T-posed sleeves (the arms hang down in play).
            pushed = clear_of(trees, axis_y, origin + d * radius, 0.02)
            reach = Vector((pushed.x, pushed.y - axis_y, 0)).length
            # Above the armpit the trees still hold the T-posed shoulders: keep the push short there.
            limit = max_push if z < t["upperarm.l"].z - 0.12 else min(max_push, 0.06)
            row.append(pushed if reach <= radius + limit else origin + d * (radius + limit))
        grid.append(row)
    bm = bmesh.new()
    verts = [[bm.verts.new(p) for p in row] for row in grid]
    for r in range(rows):
        for c in range(columns):
            theta = (c + 0.5) / columns * 2 * math.pi
            if r >= 1 and min(theta, 2 * math.pi - theta) < math.radians(open_deg):
                continue  # open front
            bm.faces.new((verts[r][c], verts[r][(c + 1) % columns], verts[r + 1][(c + 1) % columns],
                          verts[r + 1][c]))
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    _mantle_weights(ctx, obj, top_z, hem_z)
    grain_uv(ctx, obj, "wool", override=lambda p: "torso")
    return finish(ctx, obj, "wool", color, key, 0.004)


def scapular(ctx):
    """Dominican scapular: a straight white wool panel hanging front and back to a hand above the
    habit's hem, over the belt. Its shoulder yoke is always under a capuce cape (white indoors,
    black over the cappa), so only the hanging panels are built, from mid-chest down."""
    t = ctx.t
    over = ctx.spec.get("apron_over", "habit")
    trees = [ctx.bvh] + [ctx.layers[k] for k in (over,) if k in ctx.layers]
    # The belt with its purse and knife is worn under the scapular.
    depsgraph = bpy.context.evaluated_depsgraph_get()
    trees += [BVHTree.FromObject(bpy.data.objects[n], depsgraph)
              for n in ("Garment_belt", "Garment_purse", "Garment_knife_sheath") if n in bpy.data.objects]
    color = ctx.palette("scapular", ctx.palette(over, (0.86, 0.85, 0.80)))
    half = float(ctx.spec.get("scapular_half", 0.125))
    top_z = ctx.collar(t["head"].y) - 0.13
    hem_z = hem_height(ctx, "ankle") + 0.11
    rows, cols = 34, 10
    parts = []
    for name, sign in (("front", -1.0), ("back", 1.0)):
        def surface(x, z):
            """Outermost worn point along y on this side (front: most negative y)."""
            best = None
            for tree in trees:
                hit = tree.ray_cast(Vector((x, sign * 1.0, z)), Vector((0, -sign, 0)))
                if hit[0] is not None:
                    best = hit[0].y if best is None else (min(best, hit[0].y) if sign < 0 else max(best, hit[0].y))
            return best
        bm = bmesh.new()
        grid, previous = [], None
        for r in range(rows + 1):
            z = top_z + (hem_z - top_z) * r / rows
            hits = [surface(-half + 2 * half * c / cols, z) for c in range(cols + 1)]
            known = [h for h in hits if h is not None]
            fallback = (min(known) if sign < 0 else max(known)) if known else t["hips"].y + sign * 0.15
            hits = [fallback if h is None else h for h in hits]
            # A flat strip: mostly the outermost point of the row, a little of the local one.
            extreme = min(hits) if sign < 0 else max(hits)
            row = []
            for c, h in enumerate(hits):
                y = 0.65 * extreme + 0.35 * h + sign * 0.018  # clears the belt too
                if previous is not None:
                    # Cloth hangs: it may fall back toward the body only slowly.
                    limit = previous[c] - sign * 0.004
                    y = min(y, limit) if sign < 0 else max(y, limit)
                row.append(y)
            previous = row
            verts = []
            for c, y in enumerate(row):
                x = -half + 2 * half * c / cols
                curve = sign * (abs(x) / half) ** 2 * 0.02  # edges curve round the body
                verts.append(bm.verts.new((x, y - curve, z)))
            grid.append(verts)
        for r in range(rows):
            for c in range(cols):
                bm.faces.new((grid[r][c], grid[r][c + 1], grid[r + 1][c + 1], grid[r + 1][c]))
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        mesh = bpy.data.meshes.new(f"Garment_scapular_{name}")
        bm.to_mesh(mesh)
        bm.free()
        obj = bpy.data.objects.new(mesh.name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        groups = {b: obj.vertex_groups.new(name=b) for b in ("chest", "spine", "hips", "upperleg.l", "upperleg.r")}
        for v in obj.data.vertices:
            if v.co.z > t["spine"].z:
                groups["chest"].add([v.index], 0.7, "REPLACE")
                groups["spine"].add([v.index], 0.3, "REPLACE")
            elif v.co.z > t["hips"].z:
                groups["spine"].add([v.index], 0.5, "REPLACE")
                groups["hips"].add([v.index], 0.5, "REPLACE")
            else:
                for bone, w in skirt_weights(ctx, v.co, t["hips"].z, hem_z).items():
                    groups[bone].add([v.index], w, "REPLACE")
        grain_uv(ctx, obj, "wool", override=lambda p: "torso")
        parts.append(finish(ctx, obj, "wool", color, "scapular", 0.003))
    # The capuce cape and the cappa lie over it.
    joined = [BVHTree.FromObject(o, bpy.context.evaluated_depsgraph_get()) for o in parts]
    ctx.layers["scapular"] = _UnionTree(joined)
    return parts


class _UnionTree:
    """Ray casts against several BVH trees as one (nearest hit), for layer clearance."""

    def __init__(self, trees):
        self.trees = trees

    def ray_cast(self, origin, direction, distance=1.0e9):
        best = (None, None, None, None)
        for tree in self.trees:
            hit = tree.ray_cast(origin, direction, distance)
            if hit[0] is not None and (best[0] is None or hit[3] < best[3]):
                best = hit
        return best


def under_shirt(ctx):
    """Linen shirt worn under a tunic: built a little higher at the neck and longer at the wrist
    than the wool, so its collar and cuffs show; the body stops short of the tunic hem."""
    t = ctx.t
    obj = bodice(ctx, "Garment_under_shirt", lambda p: 0.004, t["wrist.l"].x + 0.026, t["hips"].z + 0.02,
                 neck_raise=0.028, iterations=12)
    loft_skirt(ctx, obj, t["hips"].z - 0.1, flare=1.15, fold_depth=0.006, folds=12, seed=5)
    grain_uv(ctx, obj, "linen")
    color = ctx.palette("linen_shirt", textiles_color("linen"))
    hems = hem_rolls(ctx, obj, 0.0025, "linen", "linen", color)
    return [finish(ctx, obj, "linen", color, "linen", 0.002)] + \
        [finish_hem(ctx, h, "linen", color, "linen") for h in hems] + [shirt_collar(ctx, color)]


def shirt_collar(ctx, color):
    """The shirt's neck band standing just above the tunic's neckline. The shell itself cannot
    reach that high (the neck skin is weighted to the head), so the band is built round the neck."""
    t, lm = ctx.t, ctx.lm
    front_y, back_y = lm["chin"][1] + 0.02, t["head"].y + 0.06
    axis_y = (front_y + back_y) / 2
    points = []
    for k in range(48):
        a = k / 48 * 2 * math.pi
        direction = horizontal(a)
        y_edge = axis_y + direction.y * (back_y - front_y) / 2
        origin = Vector((0, axis_y, ctx.collar(y_edge) + 0.017))
        hit = ctx.bvh.ray_cast(origin + direction * 0.3, -direction)
        r = ((hit[0] - origin).length if hit[0] else 0.06) + 0.004
        points.append(origin + direction * r)
    obj = band("Garment_shirt_collar", points, width=0.011, thickness=0.003)
    chest = obj.vertex_groups.new(name="chest")
    head = obj.vertex_groups.new(name="head")
    chest.add([v.index for v in obj.data.vertices], 0.75, "REPLACE")
    head.add([v.index for v in obj.data.vertices], 0.25, "REPLACE")
    grain_uv(ctx, obj, "linen", override=lambda p: "torso")
    return finish(ctx, obj, "linen", color, "linen")


def shirt_tunic(ctx):
    """Knee-length wool tunic, belted with a pouch and no knife, over a linen shirt whose collar
    and cuffs show (one torso-slot wearable; the tunic comes first so later layers clear it)."""
    extra = ctx.spec.get("tunic_ease", 0.0) + 0.006
    return tunic(ctx, "shirt_tunic", hem="knee", color_key="shirt_tunic", extra_ease=extra,
                 belted=ctx.spec.get("belted", "plain")) + under_shirt(ctx)


def habit(ctx):
    """Friar's habit: ankle-length white wool tunic with full sleeves, leather belt with knife and purse."""
    return tunic(ctx, "habit", hem="ankle", color_key="habit", extra_ease=0.008, flare=2.0, folds=22,
                 belted=True)


# Wardrobe definitions: slot, hidden body regions, builder.
WARDROBE = {
    "linen_shirt": ("torso", ["Anatomy_Torso", "Anatomy_Arms", "Anatomy_Forearms"], linen_shirt),
    "wool_tunic": ("torso", ["Anatomy_Torso", "Anatomy_Arms", "Anatomy_Forearms"], lambda c: tunic(c, "wool_tunic")),
    "work_tunic": ("torso", ["Anatomy_Torso", "Anatomy_Arms"], lambda c: tunic(c, "work_tunic", sleeve="rolled")),
    "gambeson": ("torso", ["Anatomy_Torso", "Anatomy_Arms", "Anatomy_Forearms"], gambeson),
    "mail_haubergeon": ("outerwear", [], mail_haubergeon),
    "smith_apron": ("outerwear", [], smith_apron),
    "hose": ("legs", ["Anatomy_Legs", "Anatomy_Calves", "Anatomy_Feet"], hose),
    "boots": ("feet", ["Anatomy_Feet"], boots),
    "hood": ("head", ["Hair_Scalp"], hood),
    "kettle_hat": ("head", [], kettle_hat),
    "headscarf": ("head", ["Hair_Scalp"], headscarf),
    "veil": ("head", ["Hair_Scalp"], veil),
    "waist_apron": ("outerwear", [], waist_apron),
    # Worn over mail (outerwear), so it takes the otherwise unused "back" slot.
    "surcoat": ("back", [], surcoat),
    # Tunic variants by rank: length signals status (dossier "Male dress by status tier").
    "long_tunic": ("torso", ["Anatomy_Torso", "Anatomy_Arms", "Anatomy_Forearms"],
                   lambda c: tunic(c, "long_tunic", hem="calf", color_key="long_tunic", flare=1.7, folds=18)),
    "short_tunic": ("torso", ["Anatomy_Torso", "Anatomy_Arms", "Anatomy_Forearms"],
                    lambda c: tunic(c, "short_tunic", hem="thigh", color_key="short_tunic",
                                    extra_ease=c.spec.get("tunic_ease", 0.0), belted=c.spec.get("belted", True))),
    "gown": ("torso", ["Anatomy_Torso", "Anatomy_Arms", "Anatomy_Forearms", "Anatomy_Legs", "Anatomy_Calves"],
             lambda c: tunic(c, "gown", hem="ankle", color_key="gown", flare=2.2, folds=22,
                             belted=c.spec.get("belted", "plain"))),
    "work_gown": ("torso", ["Anatomy_Torso", "Anatomy_Arms", "Anatomy_Forearms", "Anatomy_Legs"],
                  lambda c: tunic(c, "work_gown", hem="calf", color_key="work_gown", flare=1.9, folds=20,
                                  belted=c.spec.get("belted", "plain"))),
    # Citizen layers: exported separately per crowd body (citizen_bodies.LAYERS).
    "coif": ("head", [], coif),
    "wool_cap": ("head", [], wool_cap),
    "veil_over": ("head", [], veil_over),
    "mail_coif": ("head", [], mail_coif),
    "bascinet": ("head", [], bascinet),
    # Armour range (WD-4): men's adult bodies only.
    "coat_of_plates": ("back", [], coat_of_plates),
    "aventail": ("head", [], aventail),
    "great_helm": ("head", [], great_helm),
    "mail_chausses": ("legs", [], mail_chausses),
    "gauntlets": ("accessory", [], gauntlets),
    "order_mantle": ("back", [], order_mantle),
    "keys": ("accessory", [], keys),
    "paternoster": ("accessory", [], paternoster),
    "satchel": ("accessory", [], satchel),
    "back_sack": ("accessory", [], back_sack),
    # Healer's boy (ADR 0052): shirt under a knee tunic, short linen apron, low shoes.
    "shirt_tunic": ("torso", ["Anatomy_Torso", "Anatomy_Arms", "Anatomy_Forearms"], shirt_tunic),
    "short_apron": ("outerwear", [], short_apron),
    "turnshoes": ("feet", ["Anatomy_Feet"], turnshoes),
    # Dominican friar: white habit, scapular and capuce; black cappa with its black capuce (`hood`).
    "habit": ("torso", ["Anatomy_Torso", "Anatomy_Arms", "Anatomy_Forearms", "Anatomy_Legs", "Anatomy_Calves"],
              habit),
    "scapular": ("outerwear", [], scapular),
    "capuce": ("head", [], capuce),
    "cappa": ("back", [], cappa),
    # EQ-27 (women_headwear.py, imported below: it needs this module first).
    "wimple": ("head", [], lambda ctx: women_headwear.wimple(ctx)),
    "barbette": ("head", [], lambda ctx: women_headwear.barbette(ctx)),
}

# Linen that shows (EQ-22, R-2024): shirt collar and cuffs, the chemise at the neck, on the
# base outfits; replaces under_shirt and shirt_collar. Imported last: it wraps the tunic
# and gown entries above.
import underlinen  # noqa: E402

underlinen.install(WARDROBE)

# Hood with liripipe and dagged hem (EQ-26, R-2028): wraps the hood entry above.
import headwear  # noqa: E402

headwear.install(WARDROBE)

# Women's wimple and barbette (EQ-27, R-2029): builders of the two head layers in WARDROBE.
import women_headwear  # noqa: E402
