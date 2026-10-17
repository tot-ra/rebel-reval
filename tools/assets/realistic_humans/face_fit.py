"""Fit a character's MPFB face shape to its generated portrait (hero polish).

Build-time only (Blender 5.2 headless + MPFB). The portrait from
generate_portraits.py is otherwise only projected as skin colour onto the
stock MPFB sculpt, so the face keeps the generic MakeHuman shape. This tool
moves the basemesh face itself towards the portrait while keeping MPFB
topology, UVs, weights, proxies and expression units intact:

With --meshy=<glb> (a Meshy image-to-3D bust of the same portrait, e.g.
build/face_fit/<name>/meshy_head.glb; it is over the asset budget, so only
its preview and task id are kept under reference/) step 3 takes full 3D targets from the sculpt:
the bust is shot as a clay plate too, its landmarks are ray-cast onto it and
aligned onto the MPFB head by a 3D similarity fit (worst fifth dropped).

1. Build the spec's MPFB body (no portrait fit), render an orthographic,
   frontal grey-clay plate of the head.
2. MediaPipe Face Landmarker (Apache-2.0, 478 points with relative depth)
   runs on the plate and on the portrait (face_landmarks_detect.py, in a
   separate Python that has `mediapipe`).
3. Plate points are ray-cast onto the head; portrait points are mapped into
   the same frame by a 2D similarity fit, so only shape differences remain
   (head size and placement stay). In-plane offsets come from the portrait,
   depth offsets from the difference of the two MediaPipe depth maps.
4. A regularised Gaussian RBF spreads the point offsets over the face and
   fades to zero towards ears, scalp and neck, so seams and garments keep
   fitting. The result is accumulated over a few render-detect rounds.

Writes assets/characters/realistic/<name>/reference/face_fit.json (per
basemesh vertex offsets, metres); build_human.create_mpfb_body applies it as
a shape key before the proxies are fitted. Usage:

    blender -b --python-exit-code 1 --python tools/assets/realistic_humans/face_fit.py -- \
        --character=kalev [--meshy=build/face_fit/kalev/meshy_head.glb] \
        [--python=<venv>/bin/python] [--model=<face_landmarker.task>]
"""
from pathlib import Path
import argparse
import json
import subprocess
import sys

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(HERE))
import numpy as np  # noqa: E402
import build_human  # noqa: E402
import specs as spec_module  # noqa: E402

WORK = ROOT / "build/face_fit"
PLATE_PX = 1024
# MediaPipe points kept as anchors: everything except the irises (468+, they
# belong to the eyeball proxy) and the inner lip contour (mouth interior).
INNER_LIPS = {78, 191, 80, 81, 82, 13, 312, 311, 310, 415, 308, 324, 318, 402, 317, 14, 87, 178, 88, 95}
# The face silhouette (MediaPipe FACE_OVAL). On a bearded portrait the oval
# follows the beard, not the jaw, so it is dropped when the spec has a beard.
FACE_OVAL = {10, 338, 297, 332, 284, 251, 389, 356, 454, 323, 361, 288, 397, 365, 379, 378, 400, 377, 152, 148,
             176, 149, 150, 136, 172, 58, 132, 93, 234, 127, 162, 21, 54, 103, 67, 109}
# Under a beard the lower face (chin, jaw, lower cheeks) is hidden by hair in
# the portrait; only points above this fraction of the eye-to-chin span count.
BEARD_CUTOFF = 0.62


def build_body(spec, delta):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    spec = dict(spec, face_fit=False, face_fit_delta=delta)
    body, rig, _data, proxies = build_human.create_mpfb_body(spec)
    for name, proxy in proxies.items():
        proxy.hide_render = name not in ("Anatomy_Head_Eyes",)
    rig.hide_render = True
    return body, proxies


def clay(obj, color):
    mat = bpy.data.materials.new(f"clay_{obj.name}")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = 0.55
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def render_plate(body, proxies, path):
    """Orthographic frontal plate centred between the eyes; returns the camera frame."""
    eyes = proxies["Anatomy_Head_Eyes"]
    co = np.array([eyes.matrix_world @ v.co for v in eyes.data.vertices])
    centre = (co.min(0) + co.max(0)) / 2
    span = co[:, 0].max() - co[:, 0].min()
    ortho = span * 3.2
    look = Vector((centre[0], centre[1] - 1.0, centre[2] - span * 0.35))
    clay(body, (0.62, 0.52, 0.46))
    shoot(look, ortho, path)
    # Pixel (x right, y down) -> world (x, z).
    sides = [co[co[:, 0] > 0], co[co[:, 0] < 0]]
    return {"origin": np.array([look.x - ortho / 2, look.z + ortho / 2]), "m_per_px": ortho / PLATE_PX,
            "front_y": float(look.y), "span": float(span), "centre": centre,
            "eye_centres": [(s.min(0) + s.max(0)) / 2 for s in sides],
            "eye_radius": float(np.mean([(s[:, 2].max() - s[:, 2].min()) / 2 for s in sides]))}


def shoot(look, ortho, path):
    """Grey-clay EEVEE render through an orthographic camera looking along +Y."""
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = scene.render.resolution_y = PLATE_PX
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "AgX"
    world = bpy.data.worlds.new("plate")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.45, 0.45, 0.46, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    cam = bpy.data.objects.new("plate_cam", bpy.data.cameras.new("plate_cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = ortho
    cam.location = look
    cam.rotation_euler = (np.pi / 2, 0, 0)  # looks along +Y at the -Y facing body
    scene.collection.objects.link(cam)
    scene.camera = cam
    for energy, rot in ((2.5, (1.2, 0, -0.5)), (1.4, (1.2, 0, 0.6))):
        sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
        sun.data.energy = energy
        sun.rotation_euler = rot
        scene.collection.objects.link(sun)
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def plate_points_3d(bvh, frame, pts):
    """Ray-cast plate landmarks (px) along +Y onto the shot mesh; None where they miss."""
    m = frame["m_per_px"]
    out = []
    for x, y, _z in pts:
        hit = bvh.ray_cast(Vector((frame["origin"][0] + x * m, frame["front_y"], frame["origin"][1] - y * m)),
                           Vector((0, 1, 0)))
        out.append(np.array(hit[0]) if hit[0] is not None else None)
    return out


def meshy_landmarks(python, model, path, out_dir):
    """3D MediaPipe landmarks on a Meshy image-to-3D head (its own frame).

    Meshy sculpts the portrait as a textured bust: unlike MediaPipe's relative
    depth guess it has a real nose bridge, brow ridge and cheekbone depth. The
    bust is shot in grey clay like the MPFB plate (same detector conditions),
    so both landmark sets come from the same kind of image."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(path))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for obj in meshes:
        clay(obj, (0.62, 0.52, 0.46))
    co = np.concatenate([[o.matrix_world @ v.co for v in o.data.vertices] for o in meshes])
    lo, hi = co.min(0), co.max(0)
    # A bust: the head is the top ~45 % of the height, centred in x.
    ortho = (hi[2] - lo[2]) * 0.5
    look = Vector(((lo[0] + hi[0]) / 2, lo[1] - 1.0, hi[2] - ortho * 0.5))
    plate = out_dir / "meshy_plate.png"
    shoot(look, ortho, plate)
    pts = detect(python, model, [plate])[0]
    if pts is None:
        raise SystemExit(f"no face found on {plate}")
    frame = {"origin": np.array([look.x - ortho / 2, look.z + ortho / 2]), "m_per_px": ortho / PLATE_PX,
             "front_y": float(look.y)}
    polys, base = [], 0
    for obj in meshes:
        polys += [[base + i for i in poly.vertices] for poly in obj.data.polygons]
        base += len(obj.data.vertices)
    return pts, plate_points_3d(BVHTree.FromPolygons(co.tolist(), polys), frame, pts)


def similarity3(src, dst):
    """Umeyama least-squares uniform scale + rotation + translation, src -> dst (3D)."""
    ms, md = src.mean(0), dst.mean(0)
    a, b = src - ms, dst - md
    u, s, vt = np.linalg.svd(b.T @ a)
    d = np.ones(3)
    if np.linalg.det(u @ vt) < 0:
        d[-1] = -1
    rot = u @ np.diag(d) @ vt
    scale = (s * d).sum() / (a ** 2).sum()
    return lambda p: (p - ms) @ (scale * rot).T + md


def kept_indices(spec, plate_pts, photo_pts):
    keep = [i for i in range(468) if i not in INNER_LIPS and not (spec.get("beard") and i in FACE_OVAL)]
    if spec.get("beard"):
        eyes_y = (plate_pts[33, 1] + plate_pts[263, 1]) / 2
        cut = eyes_y + (plate_pts[152, 1] - eyes_y) * BEARD_CUTOFF
        keep = [i for i in keep if plate_pts[i, 1] < cut and photo_pts[i, 1] < photo_pts[152, 1]]
    return keep


def meshy_offsets(spec, body_bvh, frame, plate_pts, meshy_pts, meshy_3d):
    """Full 3D anchor offsets: Meshy landmarks aligned onto the MPFB head."""
    body_3d = plate_points_3d(body_bvh, frame, plate_pts)
    keep = [i for i in kept_indices(spec, plate_pts, meshy_pts)
            if body_3d[i] is not None and meshy_3d[i] is not None]
    src = np.array([meshy_3d[i] for i in keep])
    dst = np.array([body_3d[i] for i in keep])
    # Align twice: the worst fifth (beard or hair hits on the bust) is dropped
    # from the final alignment and does not become a deformation target.
    to_body = similarity3(src, dst)
    err = np.linalg.norm(to_body(src) - dst, axis=1)
    good = err <= np.quantile(err, 0.8)
    to_body = similarity3(src[good], dst[good])
    return dst[good], to_body(src[good]) - dst[good]


def detect(python, model, images):
    out = WORK / "landmarks.json"
    subprocess.run([python, "-I", str(HERE / "face_landmarks_detect.py"), model, str(out), *map(str, images)],
                   check=True, stderr=subprocess.DEVNULL)
    found = json.loads(out.read_text())
    return [np.array(found[str(i)]["points"]) if found[str(i)] else None for i in images]


def similarity(src, dst):
    """Least-squares uniform scale + rotation + translation mapping src -> dst (2D)."""
    ms, md = src.mean(0), dst.mean(0)
    a, b = src - ms, dst - md
    u, s, vt = np.linalg.svd(a.T @ b)
    rot = (u @ vt).T
    if np.linalg.det(rot) < 0:
        vt[-1] *= -1
        rot = (u @ vt).T
    scale = s.sum() / (a ** 2).sum()
    return lambda p: (p - ms) @ (scale * rot).T + md, scale


def anchor_offsets(spec, body_bvh, frame, plate_pts, photo_pts):
    keep = kept_indices(spec, plate_pts, photo_pts)
    keep = np.array(keep)
    m = frame["m_per_px"]
    plate_xz = np.stack([frame["origin"][0] + plate_pts[:, 0] * m, frame["origin"][1] - plate_pts[:, 1] * m], 1)
    photo_xy = np.stack([photo_pts[:, 0], -photo_pts[:, 1]], 1)
    to_world, scale = similarity(photo_xy[keep], plate_xz[keep])
    photo_xz = to_world(photo_xy)
    # MediaPipe depth is relative and noisy; centre both maps on the kept points.
    plate_depth = plate_pts[:, 2] * m
    photo_depth = photo_pts[:, 2] * scale
    plate_depth -= plate_depth[keep].mean()
    photo_depth -= photo_depth[keep].mean()
    anchors, offsets = [], []
    for i in keep:
        hit = body_bvh.ray_cast(Vector((plate_xz[i, 0], frame["front_y"], plate_xz[i, 1])), Vector((0, 1, 0)))
        if hit[0] is None:
            continue
        dxz = photo_xz[i] - plate_xz[i]
        anchors.append(np.array(hit[0]))
        offsets.append([dxz[0], photo_depth[i] - plate_depth[i], dxz[1]])
    return np.array(anchors), np.array(offsets)


def rbf_field(anchors, offsets, points, sigma, reg):
    def kernel(a, b):
        d2 = ((a[:, None, :] - b[None, :, :]) ** 2).sum(-1)
        return np.exp(-d2 / (2 * sigma ** 2))
    weights = np.linalg.solve(kernel(anchors, anchors) + reg * np.eye(len(anchors)), offsets)
    return kernel(points, anchors) @ weights


def head_mask(body, frame, anchors):
    """1 on the face, fading to 0 off it (ears, scalp, back of head, neck)."""
    co = np.array([v.co for v in body.data.vertices])
    groups = {g.name: g.index for g in body.vertex_groups}
    member = np.zeros(len(co))
    ears = np.zeros(len(co))
    for v in body.data.vertices:
        for g in v.groups:
            if g.group == groups["body"]:
                member[v.index] = 1.0
            elif g.group == groups["ears"]:
                ears[v.index] = g.weight
    span = frame["span"]
    nearest = np.full(len(co), np.inf)
    for chunk in range(0, len(co), 4000):
        part = co[chunk:chunk + 4000]
        nearest[chunk:chunk + 4000] = np.sqrt(((part[:, None, :] - anchors[None]) ** 2).sum(-1)).min(1)
    falloff = np.clip(1 - (nearest - span * 0.08) / (span * 0.45), 0, 1)
    falloff = falloff * falloff * (3 - 2 * falloff)
    # The eyeballs are fitted to MPFB helper geometry, which this fit does not
    # move: eyelids that drift off them tear open. Keep the lids where MPFB put
    # them and let the fit start around the orbit.
    for centre in frame["eye_centres"]:
        d = np.linalg.norm(co - centre, axis=1)
        t = np.clip((d - frame["eye_radius"] * 1.4) / (frame["eye_radius"] * 1.4), 0, 1)
        falloff *= t * t * (3 - 2 * t)
    return co, member * falloff * (1 - ears)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--character", default="kalev")
    parser.add_argument("--python", default=str(WORK / "venv/bin/python"))
    parser.add_argument("--model", default=str(WORK / "tools/face_landmarker.task"))
    parser.add_argument("--rounds", type=int, default=3)
    parser.add_argument("--depth-gain", type=float, default=0.6,
                        help="MediaPipe depth is a weak estimate; scale its offsets down")
    parser.add_argument("--strength", type=float, default=1.0)
    parser.add_argument("--meshy", help="Meshy image-to-3D GLB of the portrait: take 3D anchor targets from its "
                                        "sculpt instead of the portrait plane + MediaPipe depth")
    args = parser.parse_args(argv)
    spec = spec_module.SPECS[args.character]
    portrait = build_human.OUT_ROOT / spec["fit"] / "reference" / "portrait.png"
    out_dir = WORK / args.character
    out_dir.mkdir(parents=True, exist_ok=True)
    if args.meshy:
        meshy_pts, meshy_3d = meshy_landmarks(args.python, args.model, Path(args.meshy).resolve(), out_dir)
    else:
        photo_pts = detect(args.python, args.model, [portrait])[0]
        if photo_pts is None:
            raise SystemExit("no face found in the portrait")
    delta = None
    history = []
    for round_index in range(args.rounds + 1):
        body, proxies = build_body(spec, delta)
        plate = out_dir / f"plate_{round_index}.png"
        frame = render_plate(body, proxies, plate)
        plate_pts = detect(args.python, args.model, [plate])[0]
        if plate_pts is None:
            raise SystemExit(f"no face found on {plate}")
        depsgraph = bpy.context.evaluated_depsgraph_get()
        bvh = BVHTree.FromObject(body, depsgraph)
        if args.meshy:
            anchors, offsets = meshy_offsets(spec, bvh, frame, plate_pts, meshy_pts, meshy_3d)
        else:
            anchors, offsets = anchor_offsets(spec, bvh, frame, plate_pts, photo_pts)
            offsets[:, 1] *= args.depth_gain
        residual = float(np.sqrt((offsets[:, [0, 2]] ** 2).sum(1)).mean())
        history.append({"round": round_index, "anchors": len(anchors), "mean_xz_residual_mm": residual * 1000,
                        "mean_3d_residual_mm": float(np.linalg.norm(offsets, axis=1).mean()) * 1000})
        build_human.log(f"face fit round {round_index}: {len(anchors)} anchors, residual {residual * 1000:.2f} mm")
        if round_index == args.rounds:
            break
        co, mask = head_mask(body, frame, anchors)
        live = mask > 0
        step = np.zeros_like(co)
        step[live] = rbf_field(anchors, offsets, co[live], sigma=frame["span"] * 0.12, reg=0.05)
        step *= (mask * args.strength)[:, None]
        # Gross fit errors must not tear the face: clamp each vertex step.
        limit = frame["span"] * 0.1
        length = np.linalg.norm(step, axis=1, keepdims=True)
        step *= np.minimum(1, limit / np.maximum(length, 1e-9))
        delta = step if delta is None else delta + step
    moved = np.nonzero(np.linalg.norm(delta, axis=1) > 1e-5)[0]
    out = build_human.OUT_ROOT / spec["fit"] / "reference" / "face_fit.json"
    source = "reference/portrait.png"
    method = "MediaPipe Face Landmarker + RBF (tools/assets/realistic_humans/face_fit.py)"
    if args.meshy:
        source = f"Meshy image-to-3D bust of reference/portrait.png ({Path(args.meshy).name})"
        method = "Meshy image-to-3D of the portrait + MediaPipe landmarks + RBF (tools/assets/realistic_humans/face_fit.py)"
    out.write_text(json.dumps({
        "source": source, "method": method,
        "rounds": history, "depth_gain": args.depth_gain, "strength": args.strength,
        "offsets": {str(int(i)): [round(float(c), 6) for c in delta[i]] for i in moved},
    }) + "\n")
    build_human.log(f"face fit: {len(moved)} vertices moved, max {np.linalg.norm(delta, axis=1).max() * 1000:.1f} mm "
                    f"-> {out.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
