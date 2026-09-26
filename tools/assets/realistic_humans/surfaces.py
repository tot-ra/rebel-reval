"""Skin and proxy surfaces for realistic humans (ADR 0022).

Runs inside Blender (numpy only). The MakeHuman CC0 skin albedo is the base
layer. Everything else is computed from the posed body itself: each texel of
the body UV atlas gets its rest-space position (a rasterised position map),
and complexion, pores and age wrinkles are 3D procedural fields sampled at
that position. Patterns therefore keep a constant world scale across UV
islands and never show atlas seams.

Maps written per character: albedo (sRGB), tangent-space normal, roughness.
"""
from pathlib import Path
import math

import bpy
import numpy as np
from mathutils import Vector


# --------------------------------------------------------------------------
# Rasterisation
# --------------------------------------------------------------------------

def _triangles(mesh):
    mesh.calc_loop_triangles()
    uv = mesh.uv_layers.active.data
    tris = mesh.loop_triangles
    loops = np.array([t.loops[:] for t in tris], dtype=np.int64)
    verts = np.array([t.vertices[:] for t in tris], dtype=np.int64)
    uvs = np.zeros((len(mesh.loops), 2), dtype=np.float64)
    uv.foreach_get("uv", uvs.ravel())
    return uvs[loops], verts


def rasterize(mesh, vertex_values, size):
    """Barycentric raster of per-vertex values (V, C) into the UV atlas."""
    tri_uv, tri_v = _triangles(mesh)
    channels = vertex_values.shape[1]
    image = np.zeros((size, size, channels), dtype=np.float32)
    covered = np.zeros((size, size), dtype=bool)
    px = tri_uv * size - 0.5
    for t in range(len(tri_v)):
        a, b, c = px[t]
        x0 = max(int(math.floor(min(a[0], b[0], c[0]))), 0)
        x1 = min(int(math.ceil(max(a[0], b[0], c[0]))), size - 1)
        y0 = max(int(math.floor(min(a[1], b[1], c[1]))), 0)
        y1 = min(int(math.ceil(max(a[1], b[1], c[1]))), size - 1)
        if x1 < x0 or y1 < y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
        det = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(det) < 1e-12:
            continue
        w0 = ((b[1] - c[1]) * (xs - c[0]) + (c[0] - b[0]) * (ys - c[1])) / det
        w1 = ((c[1] - a[1]) * (xs - c[0]) + (a[0] - c[0]) * (ys - c[1])) / det
        w2 = 1.0 - w0 - w1
        inside = (w0 >= -0.02) & (w1 >= -0.02) & (w2 >= -0.02)
        if not inside.any():
            continue
        va, vb, vc = vertex_values[tri_v[t]]
        values = w0[..., None] * va + w1[..., None] * vb + w2[..., None] * vc
        rows, cols = ys[inside], xs[inside]
        image[rows, cols] = values[inside]
        covered[rows, cols] = True
    # Image row 0 is the bottom of the UV square in Blender's convention.
    return image, covered


def dilate(image, covered, rounds=12):
    image = image.copy()
    covered = covered.copy()
    for _ in range(rounds):
        acc = np.zeros_like(image)
        count = np.zeros(covered.shape, dtype=np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            shifted = np.roll(np.roll(image, dy, 0), dx, 1)
            mask = np.roll(np.roll(covered, dy, 0), dx, 1)
            acc += shifted * mask[..., None]
            count += mask
        grow = (~covered) & (count > 0)
        image[grow] = acc[grow] / count[grow][:, None]
        covered = covered | grow
    return image


# --------------------------------------------------------------------------
# 3D procedural fields
# --------------------------------------------------------------------------

def _hash(ix, iy, iz, seed):
    h = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791) ^ (seed * 2654435761)
    h = (h ^ (h >> 13)) * 1274126177
    return ((h ^ (h >> 16)) & 0xFFFF).astype(np.float32) / 65535.0


def value_noise(p, frequency, seed=0):
    q = p * frequency
    i = np.floor(q).astype(np.int64)
    f = q - i
    f = f * f * (3 - 2 * f)
    out = 0.0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = ((f[..., 0] if dx else 1 - f[..., 0]) *
                     (f[..., 1] if dy else 1 - f[..., 1]) *
                     (f[..., 2] if dz else 1 - f[..., 2]))
                out = out + w * _hash(i[..., 0] + dx, i[..., 1] + dy, i[..., 2] + dz, seed)
    return out


def fbm(p, frequency, octaves=4, seed=0):
    total, amp, norm = 0.0, 1.0, 0.0
    for o in range(octaves):
        total = total + amp * value_noise(p, frequency * (2 ** o), seed + o)
        norm += amp
        amp *= 0.5
    return total / norm


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def segment_distance(p, a, b):
    a, b = np.asarray(a), np.asarray(b)
    ab = b - a
    t = np.clip(((p - a) @ ab) / (ab @ ab), 0, 1)
    return np.linalg.norm(p - (a + t[..., None] * ab), axis=-1)


# --------------------------------------------------------------------------
# Landmarks and masks
# --------------------------------------------------------------------------

def landmarks(body, eyes, targets):
    """Face landmarks measured on the fitted rest mesh."""
    co = np.array([v.co[:] for v in body.data.vertices])
    def group_centroid(name):
        g = body.vertex_groups.get(name)
        if g is None:
            return None
        idx = [v.index for v in body.data.vertices if any(x.group == g.index and x.weight > 0.5 for x in v.groups)]
        return co[idx].mean(axis=0) if idx else None
    eco = np.array([v.co[:] for v in eyes.data.vertices])
    eye_l = eco[eco[:, 0] > 0].mean(axis=0)
    eye_r = eco[eco[:, 0] < 0].mean(axis=0)
    mouth = group_centroid("lips")
    head_z = np.array(targets["head"][:])
    centre = co[(np.abs(co[:, 0]) < 0.004) & (co[:, 2] > mouth[2] - 0.08) & (co[:, 2] < eye_l[2] + 0.02)]
    nose_tip = centre[np.argmin(centre[:, 1])]
    chin_band = co[(np.abs(co[:, 0]) < 0.01) & (co[:, 2] < mouth[2]) & (co[:, 2] > mouth[2] - 0.09)]
    chin = chin_band[np.argmin(chin_band[:, 1])]
    ears = []
    g = body.vertex_groups.get("ears")
    if g is not None:
        idx = [v.index for v in body.data.vertices if any(x.group == g.index and x.weight > 0.5 for x in v.groups)]
        ear_pts = co[idx]
        ears = [ear_pts[ear_pts[:, 0] > 0].mean(axis=0), ear_pts[ear_pts[:, 0] < 0].mean(axis=0)]
    return {"eye_l": eye_l, "eye_r": eye_r, "mouth": mouth, "nose_tip": nose_tip, "chin": chin,
            "ears": ears, "head": head_z, "neck": np.array(targets["chest"][:])}


def group_weights(body, name):
    g = body.vertex_groups.get(name)
    out = np.zeros(len(body.data.vertices), dtype=np.float32)
    if g is None:
        return out
    for v in body.data.vertices:
        for x in v.groups:
            if x.group == g.index:
                out[v.index] = x.weight
    return out


def beard_mask(p, lm, spec_beard):
    """Soft beard/moustache region on the face, in rest space."""
    eyes_mid = (lm["eye_l"] + lm["eye_r"]) / 2
    front_y = lm["nose_tip"][1]
    axis_y = eyes_mid[1] + 0.07  # approximate head vertical axis (behind the face)
    rel = p - np.array([0, axis_y, 0])
    theta = np.degrees(np.arctan2(np.abs(rel[..., 0]), -(rel[..., 1])))
    nose_base = lm["nose_tip"][2] - 0.012
    ear_top = eyes_mid[2] + 0.005
    upper = nose_base + (ear_top - nose_base) * smoothstep(40, 92, theta)
    # Clean cheek line: moustache meets the cheek diagonally, not horizontally.
    upper = upper - 0.016 * smoothstep(8, 28, theta) * (1 - smoothstep(55, 88, theta))
    lower = lm["chin"][2] - 0.034 + 0.024 * smoothstep(40, 95, theta)
    m = smoothstep(upper + 0.004, upper - 0.008, p[..., 2]) * smoothstep(lower - 0.01, lower + 0.012, p[..., 2])
    m = m * (1 - smoothstep(95, 118, theta))
    # Stop at the neck's front: only surface in front of the ear line.
    m = m * smoothstep(lm["eye_l"][1] + 0.105, lm["eye_l"][1] + 0.06, p[..., 1])
    # Keep lips clear.
    lip_d = np.linalg.norm((p - lm["mouth"]) * np.array([0.55, 1.0, 1.35]), axis=-1)
    m = m * smoothstep(0.013, 0.02, lip_d)
    return np.clip(m, 0, 1)


def complexion_fields(body, lm, spec, regions_of_vertex):
    co = np.array([v.co[:] for v in body.data.vertices], dtype=np.float64)
    n = len(co)
    comp = spec.get("complexion", {})
    head = regions_of_vertex == 0
    exposed = np.where(head | (regions_of_vertex == 3), 1.0, 0.0)
    forearm = regions_of_vertex == 2
    elbow_x = np.abs(co[:, 0])
    exposed = np.maximum(exposed, forearm * smoothstep(0.45, 0.55, elbow_x))
    tan = exposed * comp.get("tan", 0.3) + (1 - exposed) * comp.get("tan", 0.3) * 0.25
    flush = np.zeros(n)
    flush += np.exp(-np.sum((co - lm["nose_tip"]) ** 2, axis=1) / (0.018 ** 2))
    for s in (1, -1):
        cheek = np.array([s * 0.042, lm["nose_tip"][1] + 0.028, lm["nose_tip"][2] + 0.008])
        flush += 0.7 * np.exp(-np.sum((co - cheek) ** 2, axis=1) / (0.022 ** 2))
    for ear in lm["ears"]:
        flush += 0.8 * np.exp(-np.sum((co - ear) ** 2, axis=1) / (0.025 ** 2))
    flush = np.clip(flush, 0, 1) * comp.get("flush", 0.3)
    soot = (forearm * smoothstep(0.5, 0.7, elbow_x) + (regions_of_vertex == 3)) * comp.get("soot_forearms", 0.0)
    beard = beard_mask(co, lm, spec.get("beard")) if spec.get("beard") else np.zeros(n)
    beard = beard * head
    scalp = group_weights(body, "scalp")
    oily = np.exp(-np.sum((co - lm["nose_tip"]) ** 2, axis=1) / (0.03 ** 2))
    forehead = head * smoothstep(lm["eye_l"][2] + 0.02, lm["eye_l"][2] + 0.035, co[:, 2]) * \
        smoothstep(lm["eye_l"][2] + 0.095, lm["eye_l"][2] + 0.07, co[:, 2]) * \
        smoothstep(lm["eye_l"][1] + 0.05, lm["eye_l"][1] + 0.01, co[:, 1])
    oily = np.clip(oily + forehead * 0.6, 0, 1)
    lips = group_weights(body, "lips")
    nails = np.clip(group_weights(body, "fingernails") + group_weights(body, "toenails"), 0, 1)
    return np.stack([co[:, 0], co[:, 1], co[:, 2], tan, flush, soot, beard, scalp, oily,
                     forehead, lips, nails, head.astype(np.float64)], axis=1).astype(np.float32)


# --------------------------------------------------------------------------
# Map synthesis
# --------------------------------------------------------------------------

def _load_image(path, size):
    img = bpy.data.images.load(str(path), check_existing=True)
    if img.size[0] != size:
        img.scale(size, size)
    px = np.array(img.pixels[:], dtype=np.float32).reshape(size, size, 4)
    return px


def _save(path, rgb, colorspace="sRGB"):
    size = rgb.shape[0]
    img = bpy.data.images.new(path.stem, size, size, alpha=False, float_buffer=False)
    img.colorspace_settings.name = colorspace
    rgba = np.ones((size, size, 4), dtype=np.float32)
    rgba[..., :3] = np.clip(rgb, 0, 1)
    img.pixels.foreach_set(rgba.ravel())
    img.filepath_raw = str(path)
    img.file_format = "PNG"
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save()
    return img


def recolor_hair(path, color, out_path, size=1024):
    """Card texture with its strands remapped by luminance onto `color` (sRGB)."""
    img = bpy.data.images.load(str(path), check_existing=True)
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    lum = px[..., :3] @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
    opaque = px[..., 3] > 0.9
    ref = float(np.median(lum[opaque])) if opaque.any() else 0.2
    target = srgb_to_linear(np.array(color, dtype=np.float64))
    # Keep the strand contrast but centre it on the target colour.
    rel = np.clip(lum / max(ref, 1e-4), 0.0, 2.5) ** 0.8
    rgb = np.clip(rel[..., None] * target, 0, 1)
    out = np.concatenate([linear_to_srgb(rgb), px[..., 3:4]], axis=-1)
    if w != size:
        step = w // size
        out = out.reshape(size, step, size, step, 4).mean(axis=(1, 3))
    return _save_rgba(out_path, out)


def opaque_median(path):
    """Median sRGB colour of the opaque texels of a hair card texture."""
    img = bpy.data.images.load(str(path), check_existing=True)
    px = np.array(img.pixels[:], dtype=np.float32).reshape(-1, 4)
    # Blender stores sRGB images linearised; convert back for a palette value.
    rgb = linear_to_srgb(px[px[:, 3] > 0.9, :3]) if img.colorspace_settings.name == "Linear Rec.709" else px[px[:, 3] > 0.9, :3]
    return [float(c) for c in np.median(rgb, axis=0)]


def srgb_to_linear(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def bake_skin(body, spec, lm, regions_of_vertex, base_albedo_path, out_dir, size=2048):
    fields = complexion_fields(body, lm, spec, regions_of_vertex)
    raster, covered = rasterize(body.data, fields, size)
    raster = dilate(raster, covered, rounds=16)
    p = raster[..., 0:3].astype(np.float64)
    tan, flush, soot, beard, scalp, oily, forehead, lips, nails, head = [raster[..., i] for i in range(3, 13)]
    comp = spec.get("complexion", {})
    age = spec["macros"]["age"]
    age_amount = float(np.clip((age - 0.5) / 0.35, 0, 1))

    base = _load_image(base_albedo_path, size)[..., :3]
    lin = srgb_to_linear(base)
    # MakeHuman skins are studio-pale; outdoor 14th-century skin is weathered.
    # Measured target: median sRGB ~(0.64, 0.50, 0.42) on a weathered
    # light-skinned adult, from 0.78/0.60/0.47 raw.
    lin *= np.array(comp.get("grade", (0.56, 0.54, 0.56)))
    lin *= 1 - tan[..., None] * (1 - np.array([0.93, 0.80, 0.68]))
    lin = lin * (1 - flush[..., None]) + lin * np.array([1.10, 0.80, 0.74]) * flush[..., None]
    mottle = fbm(p, 60.0, 3, seed=3)
    lin *= (0.94 + 0.12 * mottle)[..., None]
    freckle = smoothstep(0.78, 0.9, value_noise(p, 900.0, seed=11)) * (tan * 0.6 + 0.1)
    lin *= (1 - 0.18 * freckle)[..., None]
    beard_spec = spec.get("beard") or {}
    hair_lin = srgb_to_linear(np.array(beard_spec.get("color", spec.get("hair_color", (0.2, 0.15, 0.1)))))
    follicle = smoothstep(0.35, 0.75, value_noise(p, 2600.0, seed=5))
    shadow = np.clip(beard * (0.55 + 0.45 * follicle), 0, 1) * 0.75
    lin = lin * (1 - shadow[..., None]) + hair_lin * 0.55 * shadow[..., None]
    # Under the hair cards the scalp is painted as hair (streaked along the
    # combing direction), so gaps between cards never show pale skin.
    scalp_hair = srgb_to_linear(np.array(spec.get("hair_color", (0.2, 0.15, 0.1))))
    streak = 0.7 + 0.6 * value_noise(p * np.array([1.0, 1.0, 0.15]), 900.0, seed=9)
    cover = smoothstep(0.15, 0.6, scalp)
    lin = lin * (1 - cover[..., None]) + scalp_hair * streak[..., None] * cover[..., None]
    grime = smoothstep(0.35, 0.8, fbm(p, 28.0, 4, seed=7)) * soot
    lin = lin * (1 - 0.75 * grime[..., None]) + np.array([0.035, 0.03, 0.028]) * 0.75 * grime[..., None]
    albedo = linear_to_srgb(lin)

    # Height field in metres-equivalent units; converted to tangent normals.
    pores = (value_noise(p, 1400.0, seed=21) - 0.5) * (0.6 + 0.8 * oily) * head + \
        (value_noise(p, 900.0, seed=22) - 0.5) * 0.5 * (1 - head)
    fine = (fbm(p, 380.0, 3, seed=23) - 0.5) * 0.6
    lines = np.zeros_like(tan)
    if age_amount > 0:
        # Horizontal forehead lines, broken by noise so they read as skin.
        wobble = fbm(p, 25.0, 2, seed=30) * 0.004
        ridge = np.cos((p[..., 2] + wobble) * 2 * math.pi / 0.0085)
        lines += -forehead * smoothstep(0.55, 1.0, ridge) * 1.6 * age_amount
        for eye in (lm["eye_l"], lm["eye_r"]):
            corner = eye + np.array([np.sign(eye[0]) * 0.022, 0.012, 0.0])
            d = np.linalg.norm(p - corner, axis=-1)
            ang = np.arctan2(p[..., 2] - corner[2], np.abs(p[..., 1] - corner[1]) + 1e-4)
            crow = smoothstep(0.03, 0.006, d) * smoothstep(0.0, 0.004, d)
            lines += -crow * smoothstep(0.5, 1.0, np.cos(ang * 9.0)) * 1.4 * age_amount
        for s in (1, -1):
            wing = lm["nose_tip"] + np.array([s * 0.017, 0.012, 0.0])
            corner = lm["mouth"] + np.array([s * 0.026, 0.004, -0.004])
            d = segment_distance(p, wing, corner)
            lines += -np.exp(-(d / 0.0028) ** 2) * head * 2.2 * (0.4 + age_amount)
    height = pores * 0.35 + fine * 0.5 + lines
    height = np.where(lips > 0.3, fine * 0.8 + np.cos(p[..., 0] * 2 * math.pi / 0.0016) * 0.25, height)

    # Texel size in metres from the position map, for scale-correct slopes.
    dpx = np.linalg.norm(np.gradient(p, axis=1), axis=-1)
    dpy = np.linalg.norm(np.gradient(p, axis=0), axis=-1)
    texel = np.clip((dpx + dpy) / 2, 1e-5, 0.01)
    gy, gx = np.gradient(height)
    strength = 0.00022
    nx = -gx * strength / texel
    ny = -gy * strength / texel
    nz = np.ones_like(nx)
    norm = np.sqrt(nx * nx + ny * ny + nz * nz)
    normal = np.stack([nx / norm, ny / norm, nz / norm], axis=-1) * 0.5 + 0.5

    rough = 0.56 - 0.14 * oily + 0.08 * beard + 0.12 * grime - 0.18 * lips * 0.5 + (fine * 0.06)
    rough = np.where(nails > 0.4, 0.35, rough)
    roughness = np.stack([np.zeros_like(rough), np.clip(rough, 0.25, 0.9), np.zeros_like(rough)], axis=-1)

    name = spec["fit"]
    paths = {
        "albedo": out_dir / f"{name}_skin_albedo.png",
        "normal": out_dir / f"{name}_skin_normal.png",
        "roughness": out_dir / f"{name}_skin_orm.png",
    }
    images = {
        "albedo": _save(paths["albedo"], albedo),
        "normal": _save(paths["normal"], normal, "Non-Color"),
        "roughness": _save(paths["roughness"], roughness, "Non-Color"),
    }
    return images


# --------------------------------------------------------------------------
# Materials
# --------------------------------------------------------------------------

# glTF export drops Blender multiply nodes; build_human patches these linear
# factors into baseColorFactor after export.
MATERIAL_FACTORS = {}


def pbr_material(name, albedo=None, normal=None, orm=None, color=(1, 1, 1), roughness=0.6,
                 metallic=0.0, alpha_clip=False, normal_strength=1.0, specular=0.5):
    mat = bpy.data.materials.new(name)
    if tuple(color) != (1, 1, 1):
        MATERIAL_FACTORS[mat.name] = [float(c) for c in srgb_to_linear(np.array(color, dtype=np.float64))]
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Specular IOR Level"].default_value = specular
    if albedo is not None:
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = albedo if isinstance(albedo, bpy.types.Image) else bpy.data.images.load(str(albedo), check_existing=True)
        if tuple(color) != (1, 1, 1):
            mix = nodes.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            mix.blend_type = "MULTIPLY"
            mix.inputs["Factor"].default_value = 1.0
            links.new(tex.outputs["Color"], mix.inputs[6])
            mix.inputs[7].default_value = (*color, 1)
            links.new(mix.outputs[2], bsdf.inputs["Base Color"])
        else:
            links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        if alpha_clip:
            links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
            mat.surface_render_method = "DITHERED"
    if normal is not None:
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = normal if isinstance(normal, bpy.types.Image) else bpy.data.images.load(str(normal), check_existing=True)
        tex.image.colorspace_settings.name = "Non-Color"
        nm = nodes.new("ShaderNodeNormalMap")
        nm.inputs["Strength"].default_value = normal_strength
        links.new(tex.outputs["Color"], nm.inputs["Color"])
        links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    if orm is not None:
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = orm if isinstance(orm, bpy.types.Image) else bpy.data.images.load(str(orm), check_existing=True)
        tex.image.colorspace_settings.name = "Non-Color"
        sep = nodes.new("ShaderNodeSeparateColor")
        links.new(tex.outputs["Color"], sep.inputs["Color"])
        links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
    return mat


def assign(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)


# --------------------------------------------------------------------------
# Beard fur shells
# --------------------------------------------------------------------------

def _save_rgba(path, rgba):
    size = rgba.shape[0]
    img = bpy.data.images.new(path.stem, size, size, alpha=True, float_buffer=False)
    img.alpha_mode = "STRAIGHT"
    img.pixels.foreach_set(np.clip(rgba, 0, 1).astype(np.float32).ravel())
    img.filepath_raw = str(path)
    img.file_format = "PNG"
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save()
    return img


def beard_shells(body, lm, spec, out_dir, size=2048):
    beard = spec["beard"]
    co = np.array([v.co[:] for v in body.data.vertices])
    head = np.array([v.co.z > lm["neck"][2] for v in body.data.vertices])
    mask = beard_mask(co, lm, beard) * head
    return fur_shells(body, mask, beard, spec, "beard", out_dir, size,
                      comb=Vector((0, 0.25, -1)), comb_amount=0.55)


def scalp_shells(body, lm, spec, out_dir, size=2048):
    """Short hair base under the hair cards: fills the crown, draws a hairline."""
    groom = dict(spec.get("scalp_fur", {}))
    groom.setdefault("color", spec.get("hair_color", (0.2, 0.15, 0.1)))
    groom.setdefault("length", 0.008)
    groom.setdefault("coverage", 0.85)
    groom.setdefault("shells", 5)
    scalp = group_weights(body, "scalp").astype(np.float64)
    # Soften the MakeHuman scalp group into a hairline instead of a hard cap.
    mask = smoothstep(0.2, 0.8, scalp)
    return fur_shells(body, mask, groom, spec, "scalp", out_dir, size,
                      comb=Vector((0, 1.0, -0.6)), comb_amount=groom.get("comb", 1.4))


def fur_shells(body, mask, groom, spec, key, out_dir, size, comb, comb_amount):
    """Alpha-tested shells over a masked region of the body.

    glTF has no per-shell alpha threshold, so it is encoded: texture alpha
    stores 0.5 + 0.5 * strand_length (0 where no strand grows) and each
    shell's vertex colour alpha is 1 / (1 + h) for shell height h. With the
    0.5 alpha cutoff (patched into the GLB for `*_fur_cutout`) a strand shows
    exactly on shells where length > h. Vertex RGB darkens toward the roots.
    """
    import bmesh
    shells = int(groom.get("shells", 8))
    length = float(groom["length"])
    co = np.array([v.co[:] for v in body.data.vertices])

    # Strand texture in the body atlas.
    fields = np.concatenate([co, mask[:, None]], axis=1).astype(np.float32)
    raster, covered = rasterize(body.data, fields, size)
    raster = dilate(raster, covered, rounds=8)
    p = raster[..., :3].astype(np.float64)
    density = raster[..., 3]
    # One strand per texel: per-texel hashes, never interpolated noise,
    # otherwise neighbouring texels agree and the shells read as felt.
    ys, xs = np.mgrid[0:size, 0:size]
    strand = _hash(xs, ys, np.zeros_like(xs), 41)
    clump = fbm(p, 420.0, 2, seed=42)
    grows = strand < np.clip(density * groom.get("coverage", 0.6), 0, 1) * (0.6 + 0.6 * clump)
    strand_len = np.clip((0.25 + 0.75 * _hash(xs, ys, np.ones_like(xs), 43)) * (0.55 + 0.6 * clump)
                         * smoothstep(0.05, 0.7, density), 0, 1)
    alpha = np.where(grows, 0.5 + 0.5 * strand_len, 0.0)
    base = np.array(groom["color"], dtype=np.float64)
    grey = (_hash(xs, ys, np.full_like(xs, 2), 44) < groom.get("grey", 0.0)).astype(np.float64)
    rgb = base * (0.75 + 0.5 * _hash(xs, ys, np.full_like(xs, 3), 45))[..., None]
    rgb = rgb * (1 - grey[..., None]) + np.array([0.62, 0.6, 0.57]) * grey[..., None]
    # Texels without a strand are cut away; a flat colour there keeps mips
    # clean and lets the PNG compress (random colour cost ~7 MB).
    rgb = np.where(grows[..., None], rgb, base)
    tex = _save_rgba(out_dir / f"{spec['fit']}_{key}_fur.png", np.concatenate([rgb, alpha[..., None]], axis=-1))

    # Shell geometry from the beard faces, keeping body weights and UVs.
    shell_obj = body.copy()
    shell_obj.data = body.data.copy()
    shell_obj.name = f"Hair_{key.capitalize()}Fur" if key != "beard" else "Hair_Beard"
    shell_obj.data.name = shell_obj.name
    bpy.context.scene.collection.objects.link(shell_obj)
    bm = bmesh.new()
    bm.from_mesh(shell_obj.data)
    bm.faces.ensure_lookup_table()
    keep = [f for f in bm.faces if max(mask[v.index] for v in f.verts) > 0.15]
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f not in set(keep)], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.normal_update()
    base_geom = [f for f in bm.faces]
    color_layer = bm.loops.layers.color.new("Color")
    down = comb.normalized()
    source_verts = {v: (v.co.copy(), v.normal.copy()) for v in bm.verts}
    for k in range(1, shells + 1):
        h = k / shells
        dup = bmesh.ops.duplicate(bm, geom=base_geom)
        vmap = dup["vert_map"]
        for src, (pos, nrm) in source_verts.items():
            new = vmap[src]
            comb = (down - nrm * down.dot(nrm))
            new.co = pos + nrm * (0.0008 + length * h) + comb * (length * comb_amount * h * h)
        for f in dup["geom"]:
            if isinstance(f, bmesh.types.BMFace):
                for loop in f.loops:
                    shade = 0.55 + 0.45 * h
                    loop[color_layer] = (shade, shade, shade, 1.0 / (1.0 + h))
    bmesh.ops.delete(bm, geom=base_geom, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(shell_obj.data)
    bm.free()
    shell_obj.data.shade_smooth()
    mat = pbr_material(f"{spec['fit']}_{key}_fur_cutout", tex, roughness=0.65, alpha_clip=True, specular=0.3)
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    vc = nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Color"
    tex_node = next(n for n in nodes if n.type == "TEX_IMAGE")
    bsdf = nodes.get("Principled BSDF")
    mul = nodes.new("ShaderNodeMix")
    mul.data_type = "RGBA"
    mul.blend_type = "MULTIPLY"
    mul.inputs["Factor"].default_value = 1.0
    links.new(tex_node.outputs["Color"], mul.inputs[6])
    links.new(vc.outputs["Color"], mul.inputs[7])
    links.new(mul.outputs[2], bsdf.inputs["Base Color"])
    amul = nodes.new("ShaderNodeMath")
    amul.operation = "MULTIPLY"
    links.new(tex_node.outputs["Alpha"], amul.inputs[0])
    links.new(vc.outputs["Alpha"], amul.inputs[1])
    links.new(amul.outputs[0], bsdf.inputs["Alpha"])
    assign(shell_obj, mat)
    return shell_obj
