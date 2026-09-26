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
        if group.name not in BONE_NAMES:
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
        pts = []
        for v in body.data.vertices:
            if frame_of_bone(dominant_bone(body, v)) != frame:
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
    for v in mesh.vertices:
        frame = frame_of_bone(dominant_bone(obj, v))
        if frame not in hulls:
            v.co = v.co + v.normal * ease(v.co)
            continue
        hull_r, own_r, direction, centre = hulls[frame].radius(v.co)
        if own_r < 1e-5:
            continue
        target = centre + direction * (max(own_r, hull_r) + ease(v.co))
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
    paths = textiles.texture_paths(family)
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
    ease = lambda p: 0.018 + extra_ease + 0.012 * surfaces.smoothstep(t["chest"].z, waist_z, p.z) + \
        (0.008 + extra_ease * 0.5 if abs(p.x) > t["upperarm.l"].x + 0.02 else 0.0)
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
        parts += belt(ctx, waist_z, knife=belted != "plain")
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


def belt(ctx, waist_z, knife=True):
    """Leather belt with iron buckle, purse and knife (plausible composite)."""
    t = ctx.t
    leather = ctx.palette("belt", (0.20, 0.12, 0.07))
    points = []
    for k in range(48):
        a = k / 48 * 2 * math.pi
        direction = Vector((math.sin(a), -math.cos(a), 0))
        origin = Vector((0, t["hips"].y, waist_z))
        hit = ctx.bvh.ray_cast(origin + direction * 0.4, -direction)
        r = ((hit[0] - origin).length if hit[0] else 0.16) + 0.024
        points.append(origin + direction * r)
    obj = band(f"Garment_belt", points, width=0.036, thickness=0.005)
    group = obj.vertex_groups.new(name="hips")
    group.add([v.index for v in obj.data.vertices], 1.0, "REPLACE")
    grain_uv(ctx, obj, "leather")
    parts = [finish(ctx, obj, "leather", leather, "belt_leather")]
    # Purse on the right hip, knife sheath on the left front.
    purse_at = points[36] + Vector((0, 0, -0.07))
    parts.append(rigid_box(ctx, "Garment_purse", purse_at, (0.03, 0.11, 0.12), "hips", "leather", leather,
                           "belt_leather"))
    if knife:
        knife_at = points[8] + Vector((0.0, 0, -0.10))
        parts.append(rigid_box(ctx, "Garment_knife_sheath", knife_at, (0.018, 0.035, 0.2), "hips",
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
    return tunic(ctx, "surcoat", sleeve="none", hem="knee", extra_ease=0.05, belted="plain",
                 color_key="surcoat", flare=1.45)


def gambeson(ctx):
    """Quilted linen aketon: high collar, fitted sleeves, skirt to mid-thigh."""
    t = ctx.t
    ease = lambda p: 0.022 + (0.004 if abs(p.x) > t["upperarm.l"].x else 0.0)
    obj = bodice(ctx, "Garment_gambeson", ease, t["wrist.l"].x + 0.012, t["hips"].z + 0.02,
                 neck_raise=0.03, iterations=24)
    loft_skirt(ctx, obj, t["lowerleg.l"].z + 0.18, flare=1.3, fold_depth=0.012, folds=10, seed=7)
    grain_uv(ctx, obj, "quilted")
    color = ctx.palette("gambeson", (0.62, 0.56, 0.44))
    hems = hem_rolls(ctx, obj, 0.007, "gambeson", "linen", color)
    return [finish(ctx, obj, "quilted", color, "gambeson", 0.008)] + \
        [finish_hem(ctx, h, "linen", color, "gambeson_binding") for h in hems]


def mail_haubergeon(ctx):
    """Riveted mail shirt, elbow sleeves, hem above the aketon's."""
    t = ctx.t
    ease = lambda p: 0.034
    obj = bodice(ctx, "Garment_mail_haubergeon", ease, t["lowerarm.l"].x + 0.04, t["hips"].z + 0.02,
                 neck_raise=0.02, iterations=24)
    loft_skirt(ctx, obj, t["lowerleg.l"].z + 0.24, flare=1.28, fold_depth=0.006, folds=8, seed=9)
    grain_uv(ctx, obj, "mail")
    return [finish(ctx, obj, "mail", (0.42, 0.42, 0.44), "mail", 0.004)]


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


def boots(ctx):
    """Turned-leather ankle boots.

    A closed form: convex hull of each foot and ankle, voxel-remeshed, then
    every vertex projected onto the section hull (+ leather clearance) of the
    foot below the ankle or of the leg above it. The toes are spanned by one
    rounded toe box, as a stiff upper would, and the sole is flat.
    """
    t = ctx.t
    ankle = t["foot.l"].z
    top = ankle + 0.10
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
    obj = bpy.data.objects.new("Garment_boots", bpy.data.meshes.new("Garment_boots"))
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
    color = ctx.palette("boots", (0.23, 0.15, 0.09))
    hems = hem_rolls(ctx, obj, 0.004, "boot_leather", "leather", color)
    return [finish(ctx, obj, "leather", color, "boot_leather", 0.004)] + \
        [finish_hem(ctx, h, "leather", color, "boot_leather") for h in hems]


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
                 ctx.palette("smith_apron", (0.26, 0.15, 0.08)), bib=True, over="work_tunic")


def waist_apron(ctx):
    """Linen work apron from the waist to below the knee (alewife, innkeeper)."""
    return apron(ctx, "Garment_waist_apron", "waist_apron", "linen",
                 ctx.palette("waist_apron", (0.80, 0.76, 0.66)), bib=False,
                 over=ctx.spec.get("apron_over", "wool_tunic"))


def apron(ctx, name, key, family, color, bib, over):
    t = ctx.t
    top_z = t["chest"].z + 0.10 if bib else t["spine"].z - 0.03
    hem_z = t["lowerleg.l"].z - 0.08
    half = 0.2
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
            wrap = (abs(x) / width) ** 2 * 0.05
            v = bm.verts.new((x, front - 0.012 + wrap, z))
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
            origin = Vector((0, t["hips"].y, top_z + 0.01))
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
    return head_wrap(ctx, "Garment_hood", "hood_wool", "wool", ctx.palette("hood", (0.20, 0.27, 0.36)),
                     hem_below_neck=0.25)


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
              cape_ease=0.03, hair=True, open_front=0, folds=0.004):
    """Wool hood with shoulder cape (Gugel), worn up, face opening framed.

    Parametric: a (theta, v) grid wraps the head (rays from the skull centre)
    and continues as a cape (horizontal rays from the torso axis). Radii are
    the outermost hit on body or hair plus ease; the cape radius never shrinks
    downward, so it hangs like cloth from the shoulders.
    """
    t, lm = ctx.t, ctx.lm
    targets = [trunk_bvh(ctx)]
    hair = bpy.data.objects.get("Hair_Scalp") if hair else None
    if hair is not None:
        targets.append(BVHTree.FromObject(hair, bpy.context.evaluated_depsgraph_get()))
    eyes_mid = Vector(((lm["eye_l"] + lm["eye_r"]) / 2).tolist())
    centre = Vector((0, t["head"].y + 0.01, eyes_mid.z + 0.01))
    neck_z = ctx.collar(t["head"].y)
    hem_z = neck_z - hem_below_neck
    columns = 64
    head_rows, cape_rows = 22, 12

    def outer(origin, direction):
        far = origin + direction * 0.6
        best = 0.0
        for tree in targets:
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
                radius = outer(origin, horizontal) + cape_ease
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
}
