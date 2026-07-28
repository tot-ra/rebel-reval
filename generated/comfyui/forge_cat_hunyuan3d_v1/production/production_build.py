"""Game-ready production build for the forge cat, from the approved Hunyuan3D
base shape. Single reproducible pipeline:

  retopo (voxel quad) -> feline paw rework + flat ground contact -> light
  de-blocking smooth -> single UV set -> 1024 AO + short-fur normal bake ->
  charcoal-gray fur material -> quadruped rig + auto weights -> five canonical
  ambient clips -> production GLB + LOD1/LOD2 + report.

Run: blender -b --python production_build.py

WHY a fresh clean mesh instead of decimating the raw 187k candidate: the source
has 2169 non-manifold + 6 boundary edges and no UV/rig. Voxel remesh over the
approved silhouette yields a manifold, all-quad, single-component base that we
can UV, bake, rig and animate. The runtime `CatRig` adapter instances the final
GLB while keeping forge collision and navigation logic unchanged.
"""

import bpy, bmesh, json, math, os
from mathutils import Vector

ASSET = os.path.abspath("generated/comfyui/forge_cat_hunyuan3d_v1")
SRC = os.path.join(ASSET, "forge_cat_hunyuan3d_v1.glb")
OUT = os.path.join(ASSET, "production")
TEX = os.path.join(OUT, "tex")
COATS_DIR = os.path.join(TEX, "coats")
LOD = os.path.join(OUT, "lod")
REP = os.path.join(OUT, "reports")
PROD_GLB = os.path.join(OUT, "forge_cat_production_v1.glb")
METRIC = 0.52 / 1.97
TEX_SIZE = 1024


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def topo(obj):
    me = obj.data
    bm = bmesh.new(); bm.from_mesh(me)
    quads = sum(1 for f in bm.faces if len(f.verts) == 4)
    tris3 = sum(max(0, len(f.verts) - 2) for f in bm.faces)
    boundary = sum(1 for e in bm.edges if e.is_boundary)
    nm = sum(1 for e in bm.edges if not e.is_manifold)
    unseen = set(bm.verts); comps = 0
    while unseen:
        comps += 1; st = [unseen.pop()]
        while st:
            v = st.pop()
            for e in v.link_edges:
                n = e.other_vert(v)
                if n in unseen:
                    unseen.remove(n); st.append(n)
    bm.free()
    return {"faces": len(me.polygons), "quads": quads, "quad_ratio": round(quads / max(1, len(me.polygons)), 3),
            "triangles": tris3, "vertices": len(me.vertices), "boundary_edges": boundary,
            "non_manifold_edges": nm, "components": comps}


def orient_body(obj):
    """Lay the body along -Y (head) / +Y (tail), which is what build_rig assumes.

    WHY this is its own reported step: the first production pass assigned
    `obj.rotation_euler` on a freshly imported glTF object. The importer leaves
    objects in QUATERNION rotation mode, so the assignment was silently ignored,
    the body stayed along X, and the whole skeleton was authored across the
    cat's width - the "walking sideways" defect. Rotation mode is forced here
    and the resulting axis is asserted, so a silent no-op cannot come back.

    Head detection uses two independent signals instead of upper-band mass
    alone, because a raised tail tip also occupies the upper band:
      - skull/ear mass in the upper band near each end;
      - end thickness - the tail end is a thin protrusion, the head end is not.
    """
    obj.rotation_mode = "XYZ"
    vs = [obj.matrix_world @ v.co for v in obj.data.vertices]
    dims = [max(v[i] for v in vs) - min(v[i] for v in vs) for i in range(3)]
    long_axis = 0 if dims[0] >= dims[1] else 1
    if long_axis == 0:
        obj.rotation_euler = (0, 0, math.radians(90))
        bpy.ops.object.transform_apply(rotation=True)
        vs = [obj.matrix_world @ v.co for v in obj.data.vertices]

    y0 = min(v.y for v in vs); y1 = max(v.y for v in vs); span = y1 - y0
    zmin = min(v.z for v in vs); zmax = max(v.z for v in vs)
    upper = zmin + (zmax - zmin) * 0.72

    def end_stats(low, high):
        sub = [v for v in vs if low <= v.y <= high]
        thick = 0.0
        if sub:
            thick = max(v.x for v in sub) - min(v.x for v in sub)
        return {"upper_mass": sum(1 for v in sub if v.z > upper), "thickness": round(thick, 4)}

    neg_end = end_stats(y0, y0 + span * 0.16)
    pos_end = end_stats(y1 - span * 0.16, y1)
    # Head end: more skull/ear mass up top AND a thicker cross-section than the
    # tail. Each signal votes; a tie keeps the -Y end as the head.
    votes = 0
    votes += 1 if neg_end["upper_mass"] >= pos_end["upper_mass"] else -1
    votes += 1 if neg_end["thickness"] >= pos_end["thickness"] else -1
    if votes < 0:
        obj.rotation_euler = (0, 0, math.pi)
        bpy.ops.object.transform_apply(rotation=True)
        vs = [obj.matrix_world @ v.co for v in obj.data.vertices]
        neg_end, pos_end = pos_end, neg_end

    dims = [max(v[i] for v in vs) - min(v[i] for v in vs) for i in range(3)]
    assert dims[1] > dims[0], "body must run along Y after orientation, got %s" % dims
    return {"rotated_long_axis": "X" if long_axis == 0 else "Y",
            "head_end": "-Y", "head_stats": neg_end, "tail_stats": pos_end,
            "dims_source_units": [round(d, 4) for d in dims]}


def build_lod0():
    """Voxel quad retopo of the approved silhouette, metric + feet on Z=0."""
    bpy.ops.import_scene.gltf(filepath=SRC)
    obj = next(o for o in bpy.context.scene.objects if o.type == "MESH")
    obj.name = "ForgeCatMesh"
    bpy.ops.object.select_all(action="DESELECT"); obj.select_set(True)
    bpy.context.view_layer.objects.active = obj

    orientation = orient_body(obj)

    obj.data.remesh_voxel_size = 0.038
    obj.data.remesh_voxel_adaptivity = 0.0
    bpy.ops.object.voxel_remesh()
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")

    obj.scale = (METRIC, METRIC, METRIC)
    bpy.ops.object.transform_apply(scale=True)
    vs = [obj.matrix_world @ v.co for v in obj.data.vertices]
    obj.location = (-(max(v.x for v in vs) + min(v.x for v in vs)) * 0.5,
                    -(max(v.y for v in vs) + min(v.y for v in vs)) * 0.5,
                    -min(v.z for v in vs))
    bpy.ops.object.transform_apply(location=True)
    return obj, orientation


def rework_paws(obj):
    """Turn the four rounded cuff ends into low feline paws with one flat
    ground plane. Cluster the lowest verts into 4 paws (by XY sign), then per
    paw: snap the sole flat, compress the tall cuff vertically into a low foot,
    and push toes forward so the contact reads as a paw, not a cylinder."""
    me = obj.data
    zs = [v.co.z for v in me.vertices]
    gz = min(zs); span = max(zs) - gz
    ankle = gz + span * 0.22          # everything under this belongs to a foot
    ground = gz + span * 0.05         # sole band snapped flat
    # forward (head) sign along Y: head is toward -Y after build_lod0
    for v in me.vertices:
        if v.co.z <= ankle:
            side_x = 1.0 if v.co.x >= 0 else -1.0
            fwd_y = 1.0 if v.co.y >= 0 else -1.0
            # 1) compress the vertical cuff into a lower foot (keep sole at gz)
            v.co.z = gz + (v.co.z - gz) * 0.72
            # 2) snap sole band dead flat for consistent ground contact
            if v.co.z <= ground:
                v.co.z = gz
                # 3) extend the toe box toward the head on all four feet
                v.co.y -= span * 0.012
    me.update()


def deblock(obj):
    """Light smoothing to remove voxel stair-stepping while keeping quads."""
    m = obj.modifiers.new("smooth", "SMOOTH")
    m.factor = 0.5; m.iterations = 4
    bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.ops.object.shade_smooth()


def make_uv(obj):
    bpy.ops.object.select_all(action="DESELECT"); obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=1.05, island_margin=0.02, area_weight=0.0)
    bpy.ops.object.mode_set(mode="OBJECT")


def new_image(name, color, non_color=False):
    img = bpy.data.images.new(name, TEX_SIZE, TEX_SIZE, alpha=False, float_buffer=False)
    if non_color:
        img.colorspace_settings.name = "Non-Color"
    img.generated_color = color
    return img


def bake_maps(obj):
    """Bake AO (self) and a short-fur tangent normal at 1024 in Cycles."""
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 48
    scene.cycles.device = "CPU"
    scene.render.bake.margin = 8
    scene.render.bake.use_selected_to_active = False

    ao_img = new_image("forge_cat_ao", (1, 1, 1, 1), non_color=True)
    nrm_img = new_image("forge_cat_normal", (0.5, 0.5, 1, 1), non_color=True)

    mat = bpy.data.materials.new("forge_cat_bake"); mat.use_nodes = True
    nt = mat.node_tree; nodes = nt.nodes; links = nt.links
    bsdf = nodes.get("Principled BSDF")
    # short-fur micro normal: noise -> bump -> normal input
    tex = nodes.new("ShaderNodeTexNoise"); tex.inputs["Scale"].default_value = 120.0
    tex.inputs["Detail"].default_value = 4.0
    bump = nodes.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.28
    links.new(tex.outputs["Fac"], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    obj.data.materials.clear(); obj.data.materials.append(mat)

    img_node = nodes.new("ShaderNodeTexImage"); nodes.active = img_node
    bpy.ops.object.select_all(action="DESELECT"); obj.select_set(True)
    bpy.context.view_layer.objects.active = obj

    # normal bake (captures the bump-perturbed shading normal -> fur)
    img_node.image = nrm_img
    bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", margin=8)
    # AO bake (self-occlusion: ears, leg gaps, under chin)
    img_node.image = ao_img
    bpy.ops.object.bake(type="AO", margin=8)

    nrm_img.filepath_raw = os.path.join(TEX, "forge_cat_normal.png")
    nrm_img.file_format = "PNG"; nrm_img.save()
    ao_img.filepath_raw = os.path.join(TEX, "forge_cat_ao.png")
    ao_img.file_format = "PNG"; ao_img.save()
    return ao_img, nrm_img


# Coat set for the town cats. The forge coat is the one embedded in the GLB and
# worn by Kalev's cat; the rest are baked beside it so ambient placements can be
# the same animal in different fur instead of four clones. Colours describe
# unimproved medieval European domestic cats: mackerel tabby dominant, with
# self-black, red and bicolour as the common variations. No modern breed points.
COATS = [
    {"id": "forge", "base": (0.055, 0.052, 0.058), "belly": (0.078, 0.074, 0.078),
     "accent": (0.16, 0.10, 0.055), "accent_mix": 1.0, "stripes": 0.0, "bib": 0.0},
    {"id": "tabby_brown", "base": (0.115, 0.075, 0.038), "belly": (0.225, 0.170, 0.105),
     "accent": (0.045, 0.028, 0.016), "accent_mix": 0.0, "stripes": 1.0, "bib": 0.16},
    {"id": "tabby_grey", "base": (0.100, 0.100, 0.096), "belly": (0.195, 0.195, 0.185),
     "accent": (0.034, 0.034, 0.036), "accent_mix": 0.0, "stripes": 1.0, "bib": 0.12},
    {"id": "black", "base": (0.030, 0.029, 0.032), "belly": (0.046, 0.044, 0.047),
     "accent": (0.022, 0.021, 0.024), "accent_mix": 0.0, "stripes": 0.25, "bib": 0.0},
    {"id": "ginger", "base": (0.240, 0.115, 0.040), "belly": (0.340, 0.220, 0.110),
     "accent": (0.150, 0.060, 0.020), "accent_mix": 0.0, "stripes": 0.75, "bib": 0.22},
    {"id": "white_black", "base": (0.042, 0.040, 0.044), "belly": (0.070, 0.068, 0.072),
     "accent": (0.030, 0.029, 0.032), "accent_mix": 0.0, "stripes": 0.0, "bib": 0.70},
]


def author_albedo(obj, ao_img, coat, back_z):
    """Bake one short-fur albedo: countershaded base, optional mackerel tabby
    banding and white bib, fur value noise, and AO multiplied in."""
    scene = bpy.context.scene
    alb = new_image("forge_cat_albedo_" + coat["id"], (0.09, 0.09, 0.1, 1), non_color=False)
    mat = obj.data.materials[0]
    nt = mat.node_tree; nodes = nt.nodes; links = nt.links
    bsdf = nodes.get("Principled BSDF")

    base = nodes.new("ShaderNodeRGB"); base.outputs[0].default_value = tuple(coat["base"]) + (1,)
    belly = nodes.new("ShaderNodeRGB"); belly.outputs[0].default_value = tuple(coat["belly"]) + (1,)
    accent = nodes.new("ShaderNodeRGB"); accent.outputs[0].default_value = tuple(coat["accent"]) + (1,)
    geo = nodes.new("ShaderNodeNewGeometry")
    sep = nodes.new("ShaderNodeSeparateXYZ")
    links.new(geo.outputs["Position"], sep.inputs["Vector"])

    # Countershading: pale underside darkening toward the spine.
    shade = nodes.new("ShaderNodeMapRange")
    shade.inputs["From Min"].default_value = back_z * 0.20
    shade.inputs["From Max"].default_value = back_z * 0.85
    links.new(sep.outputs["Z"], shade.inputs["Value"])
    body = nodes.new("ShaderNodeMixRGB"); body.blend_type = "MIX"
    links.new(shade.outputs["Result"], body.inputs["Fac"])
    links.new(belly.outputs[0], body.inputs["Color1"])
    links.new(base.outputs[0], body.inputs["Color2"])
    current = body

    if coat["accent_mix"] > 0.0:
        # Warm forge-lit highlight along the back, kept for Kalev's cat only.
        warm_ramp = nodes.new("ShaderNodeMapRange")
        warm_ramp.inputs["From Min"].default_value = back_z * 0.55
        warm_ramp.inputs["From Max"].default_value = back_z * 1.10
        links.new(sep.outputs["Z"], warm_ramp.inputs["Value"])
        warm_mix = nodes.new("ShaderNodeMixRGB"); warm_mix.blend_type = "MIX"
        links.new(warm_ramp.outputs["Result"], warm_mix.inputs["Fac"])
        links.new(current.outputs["Color"], warm_mix.inputs["Color1"])
        links.new(accent.outputs[0], warm_mix.inputs["Color2"])
        current = warm_mix

    if coat["stripes"] > 0.0:
        # Mackerel banding: rings around the body along its length, broken up by
        # noise so the stripes are not mechanical.
        wave = nodes.new("ShaderNodeTexWave")
        wave.bands_direction = "Y"
        wave.inputs["Scale"].default_value = 9.0
        wave.inputs["Distortion"].default_value = 2.4
        wave.inputs["Detail"].default_value = 2.0
        links.new(geo.outputs["Position"], wave.inputs["Vector"])
        band = nodes.new("ShaderNodeMapRange")
        band.inputs["From Min"].default_value = 0.42
        band.inputs["From Max"].default_value = 0.62
        band.inputs["To Max"].default_value = coat["stripes"] * 0.85
        band.clamp = True
        links.new(wave.outputs["Fac"], band.inputs["Value"])
        stripe_mix = nodes.new("ShaderNodeMixRGB"); stripe_mix.blend_type = "MIX"
        links.new(band.outputs["Result"], stripe_mix.inputs["Fac"])
        links.new(current.outputs["Color"], stripe_mix.inputs["Color1"])
        links.new(accent.outputs[0], stripe_mix.inputs["Color2"])
        current = stripe_mix

    if coat["bib"] > 0.0:
        # White chest/paw patching: strongest low and toward the chin.
        bib_ramp = nodes.new("ShaderNodeMapRange")
        bib_ramp.inputs["From Min"].default_value = back_z * 0.42
        bib_ramp.inputs["From Max"].default_value = back_z * 0.08
        bib_ramp.inputs["To Max"].default_value = coat["bib"]
        bib_ramp.clamp = True
        links.new(sep.outputs["Z"], bib_ramp.inputs["Value"])
        white = nodes.new("ShaderNodeRGB"); white.outputs[0].default_value = (0.62, 0.60, 0.57, 1)
        bib_mix = nodes.new("ShaderNodeMixRGB"); bib_mix.blend_type = "MIX"
        links.new(bib_ramp.outputs["Result"], bib_mix.inputs["Fac"])
        links.new(current.outputs["Color"], bib_mix.inputs["Color1"])
        links.new(white.outputs[0], bib_mix.inputs["Color2"])
        current = bib_mix

    # subtle fur value noise
    noise = nodes.new("ShaderNodeTexNoise"); noise.inputs["Scale"].default_value = 45.0
    fur_mix = nodes.new("ShaderNodeMixRGB"); fur_mix.blend_type = "MULTIPLY"
    fur_mix.inputs["Fac"].default_value = 0.18
    links.new(current.outputs["Color"], fur_mix.inputs["Color1"])
    links.new(noise.outputs["Color"], fur_mix.inputs["Color2"])
    # multiply AO in
    ao_node = nodes.new("ShaderNodeTexImage"); ao_node.image = ao_img
    ao_mix = nodes.new("ShaderNodeMixRGB"); ao_mix.blend_type = "MULTIPLY"
    ao_mix.inputs["Fac"].default_value = 0.6
    links.new(fur_mix.outputs["Color"], ao_mix.inputs["Color1"])
    links.new(ao_node.outputs["Color"], ao_mix.inputs["Color2"])
    links.new(ao_mix.outputs["Color"], bsdf.inputs["Base Color"])

    img_node = nodes.new("ShaderNodeTexImage"); img_node.image = alb; nodes.active = img_node
    scene.render.engine = "CYCLES"; scene.cycles.samples = 4
    bpy.ops.object.select_all(action="DESELECT"); obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, margin=8)
    name = "forge_cat_albedo.png" if coat["id"] == "forge" else "forge_cat_albedo_%s.png" % coat["id"]
    directory = TEX if coat["id"] == "forge" else COATS_DIR
    alb.filepath_raw = os.path.join(directory, name)
    alb.file_format = "PNG"; alb.save()
    # Leave the bake graph as we found it so the next coat starts clean.
    for node in list(nodes):
        if node not in (bsdf, nodes.get("Material Output")) and node.type != "TEX_IMAGE":
            nodes.remove(node)
    for node in list(nodes):
        if node.type == "TEX_IMAGE":
            nodes.remove(node)
    return alb


def author_roughness(obj, ao_img):
    """Bake a fur roughness map: broadly matte coat, tighter sheen where the fur
    lies flat, damped in occluded creases. Baked rather than left scalar so the
    cat carries the same normal+roughness contract as the other fauna GLBs."""
    scene = bpy.context.scene
    rough = new_image("forge_cat_roughness", (0.82, 0.82, 0.82, 1), non_color=True)
    mat = obj.data.materials[0]
    nt = mat.node_tree; nodes = nt.nodes; links = nt.links
    bsdf = nodes.get("Principled BSDF")

    noise = nodes.new("ShaderNodeTexNoise"); noise.inputs["Scale"].default_value = 22.0
    noise.inputs["Detail"].default_value = 3.0
    spread = nodes.new("ShaderNodeMapRange")
    spread.inputs["From Min"].default_value = 0.35
    spread.inputs["From Max"].default_value = 0.65
    spread.inputs["To Min"].default_value = 0.74
    spread.inputs["To Max"].default_value = 0.88
    spread.clamp = True
    links.new(noise.outputs["Fac"], spread.inputs["Value"])
    ao_node = nodes.new("ShaderNodeTexImage"); ao_node.image = ao_img
    crease = nodes.new("ShaderNodeMixRGB"); crease.blend_type = "MIX"
    crease.inputs["Fac"].default_value = 0.25
    crease.inputs["Color2"].default_value = (0.92, 0.92, 0.92, 1)
    links.new(spread.outputs["Result"], crease.inputs["Color1"])
    invert = nodes.new("ShaderNodeInvert")
    links.new(ao_node.outputs["Color"], invert.inputs["Color"])
    links.new(invert.outputs["Color"], crease.inputs["Fac"])
    links.new(crease.outputs["Color"], bsdf.inputs["Base Color"])

    img_node = nodes.new("ShaderNodeTexImage"); img_node.image = rough; nodes.active = img_node
    scene.render.engine = "CYCLES"; scene.cycles.samples = 4
    bpy.ops.object.select_all(action="DESELECT"); obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, margin=8)
    rough.filepath_raw = os.path.join(TEX, "forge_cat_roughness.png")
    rough.file_format = "PNG"; rough.save()
    for node in list(nodes):
        if node.type in {"TEX_IMAGE", "TEX_NOISE", "MAP_RANGE", "MIX_RGB", "INVERT"}:
            nodes.remove(node)
    return rough


def final_material(obj, alb, nrm, rgh):
    obj.data.materials.clear()
    mat = bpy.data.materials.new("forge_cat"); mat.use_nodes = True
    nt = mat.node_tree; nodes = nt.nodes; links = nt.links
    for n in list(nodes):
        if n.type != "OUTPUT_MATERIAL":
            nodes.remove(n)
    out = nodes.get("Material Output")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    an = nodes.new("ShaderNodeTexImage"); an.image = alb
    links.new(an.outputs["Color"], bsdf.inputs["Base Color"])
    nn = nodes.new("ShaderNodeTexImage"); nn.image = nrm
    nmap = nodes.new("ShaderNodeNormalMap"); nmap.inputs["Strength"].default_value = 0.8
    links.new(nn.outputs["Color"], nmap.inputs["Color"])
    links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    rn = nodes.new("ShaderNodeTexImage"); rn.image = rgh
    links.new(rn.outputs["Color"], bsdf.inputs["Roughness"])
    bsdf.inputs["Metallic"].default_value = 0.0
    obj.data.materials.append(mat)
    return mat


def measure_body(obj):
    """Locate the real legs, back line, head and tail on the retopologised mesh.

    Bone placement used to be bounding-box fractions, which only works if the
    body happens to fill its box evenly. Measuring instead means each leg chain
    sits inside the leg it deforms, the tail chain follows the modelled tail
    curve, and the walk solver can trust its own limb lengths.
    """
    vs = [v.co.copy() for v in obj.data.vertices]
    y0 = min(v.y for v in vs); y1 = max(v.y for v in vs)
    z1 = max(v.z for v in vs)
    length = y1 - y0

    # Foot clusters: the lowest slab, split front/back by the belly midline and
    # left/right by the body midline.
    foot_band = [v for v in vs if v.z <= z1 * 0.16]
    ymid = (y0 + y1) * 0.5
    feet = {}
    for name, fore, side in (("legFL", True, -1), ("legFR", True, 1),
                             ("legBL", False, -1), ("legBR", False, 1)):
        sub = [v for v in foot_band
               if (v.y < ymid) == fore and (1 if v.x >= 0 else -1) == side]
        assert sub, "no foot vertices for %s" % name
        feet[name] = {
            "x": sum(v.x for v in sub) / len(sub),
            "y": sum(v.y for v in sub) / len(sub),
            "fore": fore,
            "side": side,
        }

    # Withers/back line: top of the torso between the shoulder and the hip,
    # ignoring head and tail, so leg joints scale off the real body, not the
    # bounding box (which the raised tail owns).
    fore_y = (feet["legFL"]["y"] + feet["legFR"]["y"]) * 0.5
    hind_y = (feet["legBL"]["y"] + feet["legBR"]["y"]) * 0.5
    torso = [v for v in vs if fore_y <= v.y <= hind_y]
    back_z = max(v.z for v in torso) if torso else z1 * 0.72

    # Head centre: the mass forward of the shoulders, above the elbow line.
    head_band = [v for v in vs if v.y < fore_y - length * 0.02 and v.z > back_z * 0.45]
    if not head_band:
        head_band = [v for v in vs if v.y < fore_y]
    head_c = [sum(v[i] for v in head_band) / len(head_band) for i in range(3)]
    nose_y = min(v.y for v in head_band)

    # Tail: sample centroids of thin slices behind the hips so the chain follows
    # the modelled curve instead of a straight diagonal.
    tail_root_y = hind_y + length * 0.04
    tail_nodes = []
    steps = 5
    for i in range(steps + 1):
        lo = tail_root_y + (y1 - tail_root_y) * (i / (steps + 1.0))
        hi = tail_root_y + (y1 - tail_root_y) * ((i + 1) / (steps + 1.0))
        sub = [v for v in vs if lo <= v.y <= hi and v.z > back_z * 0.5]
        if not sub:
            continue
        tail_nodes.append((sum(v.x for v in sub) / len(sub),
                           (lo + hi) * 0.5,
                           sum(v.z for v in sub) / len(sub)))
    return {"feet": feet, "back_z": back_z, "head_center": head_c, "nose_y": nose_y,
            "fore_y": fore_y, "hind_y": hind_y, "y0": y0, "y1": y1, "z1": z1,
            "tail_nodes": tail_nodes}


def clean_leg_weights(obj, body, hip_z):
    """Strip cross-limb weight bleed left by bone heat.

    The four legs are only a few centimetres apart on a cat, so automatic
    weights give each leg some hold on its neighbours. On a standing rest pose
    that is invisible; in a walk it drags the planted legs around with whichever
    leg is swinging and tears the mesh at the elbow. Below the hips a vertex is
    only allowed to belong to its own leg.
    """
    names = list(body["feet"].keys())
    groups = {}
    for name in names:
        groups[name] = [obj.vertex_groups.get(name + s) for s in ("_upper", "_lower", "_paw")]
    removed = 0
    for v in obj.data.vertices:
        if v.co.z > hip_z:
            continue
        distances = {n: math.hypot(v.co.x - body["feet"][n]["x"], v.co.y - body["feet"][n]["y"])
                     for n in names}
        own = min(distances, key=distances.get)
        for name in names:
            if name == own:
                continue
            for group in groups[name]:
                if group is None:
                    continue
                try:
                    group.weight(v.index)
                except RuntimeError:
                    continue
                group.remove([v.index])
                removed += 1
    return removed


def build_rig(obj):
    """Quadruped skeleton, Z-up, head toward -Y, origin between paws on ground.

    Joint heights follow feline proportions relative to the measured back line:
    scapula/hip at 0.62, elbow/stifle at 0.33, wrist/hock at 0.13. The cat is
    digitigrade, so the paw bone carries the last stretch down to the toe pads.
    """
    body = measure_body(obj)
    back_z = body["back_z"]
    hip_z = back_z * 0.62
    knee_z = back_z * 0.33
    ankle_z = back_z * 0.13
    toe_z = 0.001

    amt = bpy.data.armatures.new("forge_cat_arm")
    arm = bpy.data.objects.new("ForgeCatArmature", amt)
    bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = amt.edit_bones

    def bone(name, head, tail, parent=None):
        b = eb.new(name); b.head = head; b.tail = tail
        if parent: b.parent = parent; b.use_connect = False
        return b

    fore_y, hind_y = body["fore_y"], body["hind_y"]
    head_c = body["head_center"]
    spine_z = back_z * 0.86

    root = bone("root", (0, hind_y, 0.001), (0, hind_y, hip_z))
    pelvis = bone("pelvis", (0, hind_y - 0.01, spine_z), (0, hind_y * 0.55, spine_z), root)
    spine = bone("spine", pelvis.tail, (0, (fore_y + hind_y) * 0.28, spine_z * 1.02), pelvis)
    chest = bone("chest", spine.tail, (0, fore_y + 0.005, spine_z * 1.02), spine)
    neck = bone("neck", chest.tail, (0, (fore_y + head_c[1]) * 0.5, head_c[2] * 0.98), chest)
    head = bone("head", neck.tail, (0, body["nose_y"] + 0.01, head_c[2]), neck)

    # tail chain: follow the measured tail centroids
    nodes = body["tail_nodes"]
    parent = pelvis
    for i in range(4):
        a = nodes[min(i, len(nodes) - 2)]
        b = nodes[min(i + 1, len(nodes) - 1)]
        if a == b:
            b = (a[0], a[1] + 0.01, a[2])
        parent = bone(f"tail_{i+1}", a, b, parent)

    # four legs: upper, lower, paw - anchored on the measured foot centroids
    for name, foot in body["feet"].items():
        sx, ly = foot["x"], foot["y"]
        parent_bone = chest if foot["fore"] else pelvis
        # Toe pads sit a little ahead of the ankle: digitigrade contact.
        toe_y = ly - (body["y1"] - body["y0"]) * 0.035
        u = bone(name + "_upper", (sx, ly, hip_z), (sx, ly, knee_z), parent_bone)
        l = bone(name + "_lower", (sx, ly, knee_z), (sx, ly, ankle_z), u)
        bone(name + "_paw", (sx, ly, ankle_z), (sx, toe_y, toe_z), l)

    bpy.ops.object.mode_set(mode="OBJECT")

    # bind with automatic weights (mesh is manifold -> bone heat works)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True); arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    try:
        bpy.ops.object.parent_set(type="ARMATURE_AUTO")
        wmode = "auto_bone_heat"
    except RuntimeError:
        bpy.ops.object.parent_set(type="ARMATURE_ENVELOPE")
        wmode = "envelope_fallback"
    bleed = clean_leg_weights(obj, body, hip_z)

    rig = {
        "back_z": round(back_z, 4),
        "hip_z": hip_z,
        "knee_z": knee_z,
        "ankle_z": ankle_z,
        "toe_z": toe_z,
        "cross_limb_weights_removed": bleed,
        "upper_length": hip_z - knee_z,
        "lower_length": knee_z - ankle_z,
        "legs": {},
    }
    for name, foot in body["feet"].items():
        toe_y = foot["y"] - (body["y1"] - body["y0"]) * 0.035
        rig["legs"][name] = {
            "fore": foot["fore"],
            "side": foot["side"],
            # Forelimb elbows fold caudally, hind stifles cranially.
            "bend": -1 if foot["fore"] else 1,
            "x": round(foot["x"], 4),
            "y": round(foot["y"], 4),
            # Rest angle of the paw segment measured from straight down, so the
            # walk can hold the sole flat while the leg above it swings.
            "paw_rest": math.atan2(toe_y - foot["y"], ankle_z - toe_z),
            "paw_len": math.hypot(toe_y - foot["y"], ankle_z - toe_z),
        }
    return arm, wmode, rig


def _begin_action(arm, name, frame_end):
    """Create an armature action with a complete neutral-pose baseline.

    WHY every clip keys every bone at its boundaries: Godot blends directly
    between imported clips. Complete tracks prevent an unkeyed leg or tail from
    inheriting the previous state when the cat changes routine.
    """
    scene = bpy.context.scene
    scene.render.fps = 30
    scene.frame_start = 1; scene.frame_end = frame_end
    bpy.context.view_layer.objects.active = arm
    if arm.mode != "POSE":
        bpy.ops.object.mode_set(mode="POSE")
    act = bpy.data.actions.new(name)
    arm.animation_data_create(); arm.animation_data.action = act
    act.use_fake_user = True
    pb = arm.pose.bones

    for b in pb:
        b.rotation_mode = "XYZ"
        b.rotation_euler = (0, 0, 0)
        b.location = (0, 0, 0)
        b.scale = (1, 1, 1)
        for frame in (1, frame_end):
            b.keyframe_insert("rotation_euler", frame=frame)
            b.keyframe_insert("location", frame=frame)

    def key(bone, frame, rot=None, loc=None):
        b = pb.get(bone)
        if not b:
            return
        if rot is not None:
            b.rotation_mode = "XYZ"; b.rotation_euler = rot
            b.keyframe_insert("rotation_euler", frame=frame)
        if loc is not None:
            b.location = loc; b.keyframe_insert("location", frame=frame)

    return act, key


FPS = 30
WALK_FRAMES = 18                 # 0.6 s cycle -> ~1.7 Hz feline walking cadence
WALK_DUTY = 0.66                 # share of the cycle each foot spends planted
WALK_CROUCH = 0.020              # walking cats carry the body lower than standing
# Lateral-sequence walk: left hind, left fore, right hind, right fore. This is
# the gait a cat actually uses at walking pace; the first pass moved diagonal
# pairs together, which is a trot and reads as a stiff bounce when it plays at
# ambient speed.
WALK_PHASE = {"legBL": 0.0, "legFL": 0.25, "legBR": 0.5, "legFR": 0.75}
WALK_LIFT = {True: 0.018, False: 0.024}    # keyed by "is a foreleg"


def _smootherstep(s):
    s = max(0.0, min(1.0, s))
    return s * s * s * (s * (s * 6 - 15) + 10)


def leg_solve(rig, ty, tz, bend):
    """Two-link solve for one leg in the sagittal plane.

    ty is the ankle's fore/aft offset from the hip (+Y = behind the cat, since
    the head faces -Y), tz its vertical offset (negative = below the hip).
    Returns pose rotations for the upper and lower bones about their local X.
    `bend` selects the elbow/stifle fold direction. Also returns how far short
    of the target the chain had to stop, so the gait audit can catch a pose that
    silently over-reaches instead of planting the foot.
    """
    l1 = rig["upper_length"]; l2 = rig["lower_length"]
    want = math.hypot(ty, tz)
    d = max(abs(l1 - l2) + 1e-4, min(l1 + l2 - 1e-4, want))
    gamma = math.atan2(ty, -tz)
    beta = math.acos(max(-1.0, min(1.0, (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d))))
    knee = math.acos(max(-1.0, min(1.0, (l1 * l1 + l2 * l2 - d * d) / (2 * l1 * l2))))
    a1 = gamma - bend * beta
    a2 = a1 + bend * (math.pi - knee)
    return a1, a2 - a1, abs(want - d)


def walk_amplitude(rig):
    """Half-stride the legs can reach without lifting the foot off the ground."""
    reach = rig["upper_length"] + rig["lower_length"]
    drop = rig["hip_z"] - WALK_CROUCH - rig["ankle_z"]
    room = max(reach * reach - drop * drop, 0.0) ** 0.5
    return min(0.09, room * 0.92)


def _pose_leg(key, rig, name, frame, ty, lift, body_up, paw_flex=0.0):
    """Place one foot relative to the body and keep its sole flat on the floor.

    The paw bone counter-rotates the whole chain above it, so a planted paw
    stays parallel to the ground instead of pivoting through it - the single
    biggest reason the first walk read as scrabbling rather than stepping.
    """
    leg = rig["legs"][name]
    tz = (rig["ankle_z"] + lift) - (rig["hip_z"] + body_up)
    upper, lower, miss = leg_solve(rig, ty, tz, leg["bend"])
    key(name + "_upper", frame, rot=(upper, 0, 0))
    key(name + "_lower", frame, rot=(lower, 0, 0))
    key(name + "_paw", frame, rot=(-(upper + lower) + paw_flex, 0, 0))
    return miss


def walk_foot(rig, name, phase, amplitude):
    """Fore/aft target, lift and toe angle for one leg at one cycle phase."""
    leg = rig["legs"][name]
    if phase < WALK_DUTY:
        # Stance: the foot is planted, so relative to the hip it tracks straight
        # backwards at constant speed. Constant speed is what stops the skating.
        s = phase / WALK_DUTY
        ty = -amplitude + 2.0 * amplitude * s
        lift = 0.0
        flex = 0.30 * max(0.0, (s - 0.78) / 0.22)          # toe-off push
        # Cats are digitigrade: the push-off pivots over the toe pads, so the
        # ankle rides forward and up over a toe that stays put. Without this the
        # paw rotates about the ankle and drags the contact point backwards.
        rest = leg["paw_rest"]
        reach = leg["paw_len"]
        ty -= reach * (math.sin(rest + flex) - math.sin(rest))
        lift += reach * (math.cos(rest + flex) - math.cos(rest))
    else:
        s = (phase - WALK_DUTY) / (1.0 - WALK_DUTY)
        ty = amplitude - 2.0 * amplitude * _smootherstep(s)
        lift = WALK_LIFT[leg["fore"]] * math.sin(math.pi * s) ** 0.85
        # Carry the toe-off angle out of the ground, tuck the toes up for
        # clearance, then level the paw again before touchdown.
        flex = 0.30 * max(0.0, 1.0 - s / 0.3) - 0.24 * math.sin(math.pi * s)
    return ty, lift, flex


def make_animations(arm, rig):
    """Author the five canonical clips used by ForgeCat's ambient routine.

    Motion stays restrained because this cat is normally seen from an isometric
    game camera, but every clip now places its feet through the same solver, so
    paws meet the floor in rest poses as well as in the walk.
    """
    animations = {}
    amplitude = walk_amplitude(rig)
    misses = []

    idle, key = _begin_action(arm, "idle", 150)
    # A standing cat is not a table: hold a little flexion in every joint.
    for frame in (1, 40, 75, 110, 150):
        breath = {1: 0.0, 40: 0.006, 75: 0.009, 110: 0.004, 150: 0.0}[frame]
        for name in rig["legs"]:
            _pose_leg(key, rig, name, frame, 0.0, 0.0, -0.010 + breath * 0.5)
        key("root", frame, loc=(0, -0.010 + breath * 0.5, 0))
        key("spine", frame, rot=(breath * 2.4, 0, 0))
        key("chest", frame, rot=(breath * 1.5, 0, 0))
    for f, rx, ry in [(1, 0, 0), (60, 0.05, 0.03), (120, 0.02, -0.03), (150, 0, 0)]:
        key("head", f, rot=(rx, ry, 0))
        key("neck", f, rot=(rx * 0.4, ry * 0.5, 0))
    for i in range(4):
        amp = 0.06 + 0.02 * i
        for f, s in [(1, 0), (50, amp), (100, -amp), (150, 0)]:
            key(f"tail_{i+1}", f, rot=(0, 0, s))
    animations[idle.name] = {"frames": [1, 150], "seconds": 150.0 / FPS, "loop": True}

    walk, key = _begin_action(arm, "walk", WALK_FRAMES + 1)
    for frame in range(1, WALK_FRAMES + 2):
        t = (frame - 1) / float(WALK_FRAMES)          # frame WALK_FRAMES+1 == frame 1
        # Two body dips per cycle (one per lateral pair) plus a gentle weight
        # shift from side to side; both are small because cats walk smoothly.
        body_up = -WALK_CROUCH + 0.0035 * math.sin(2.0 * math.pi * (2.0 * t) + 0.6)
        sway = 0.0030 * math.sin(2.0 * math.pi * t)
        key("root", frame, loc=(sway, body_up, 0))
        # Shoulder and hip girdles counter-rotate around the spine as the
        # diagonal support pattern changes.
        yaw_pelvis = 0.030 * math.sin(2.0 * math.pi * t)
        yaw_chest = -0.024 * math.sin(2.0 * math.pi * t + 0.5)
        for name in rig["legs"]:
            leg = rig["legs"][name]
            phase = (t - WALK_PHASE[name]) % 1.0
            ty, lift, flex = walk_foot(rig, name, phase, amplitude)
            # A yawing girdle carries its hip fore/aft; take that out of the
            # target so the planted foot does not inherit the body's rotation.
            yaw = yaw_pelvis + (yaw_chest if leg["fore"] else 0.0)
            ty += leg["x"] * yaw
            misses.append(_pose_leg(key, rig, name, frame, ty, lift, body_up, flex))
        key("pelvis", frame, rot=(0, 0, yaw_pelvis))
        # No pitch on the spine during the walk: it sits above the forelegs in
        # the hierarchy, so any pitch swings the planted forefeet with it. The
        # body's vertical motion comes from the root instead, which the leg
        # solver already accounts for.
        key("spine", frame, rot=(0, 0, 0))
        key("chest", frame, rot=(0, 0, yaw_chest))
        key("neck", frame, rot=(0.018 * math.sin(2.0 * math.pi * (2.0 * t) + 1.2), 0, 0))
        key("head", frame, rot=(0.022 * math.sin(2.0 * math.pi * (2.0 * t) + 0.9),
                                0.020 * math.sin(2.0 * math.pi * t), 0))
        for i in range(4):
            lag = 0.30 * (i + 1)
            key(f"tail_{i+1}", frame,
                rot=(-0.05 if i == 0 else 0.02,
                     0,
                     0.055 * (i + 1) / 4.0 * math.sin(2.0 * math.pi * t - lag)))
    animations[walk.name] = {
        "frames": [1, WALK_FRAMES + 1],
        "seconds": WALK_FRAMES / float(FPS),
        "loop": True,
        "stride_m": round(2.0 * amplitude, 4),
        "duty_factor": WALK_DUTY,
        "ground_speed_m_s": round(2.0 * amplitude / (WALK_DUTY * WALK_FRAMES / float(FPS)), 4),
        "footfall_order": ["legBL", "legFL", "legBR", "legFR"],
    }

    sleep, key = _begin_action(arm, "sleep", 90)
    # Loafed: body settled on folded legs, paws tucked slightly forward, head
    # low and turned onto the shoulder. Root translation is along the bone's
    # local Y, which is world up - the first pass used local Z and shunted the
    # sleeping cat backwards instead of lowering it.
    for f, breath in [(1, 0.0), (45, 0.010), (90, 0.0)]:
        drop = -0.050 + breath
        key("root", f, loc=(0, drop, 0))
        for name in rig["legs"]:
            tuck = -0.018 if rig["legs"][name]["fore"] else 0.012
            _pose_leg(key, rig, name, f, tuck, 0.0, drop)
        key("spine", f, rot=(0.10, 0, 0.03))
        key("chest", f, rot=(0.16, 0, -0.04))
        key("neck", f, rot=(0.26, 0.10, 0.12))
        key("head", f, rot=(0.34, 0.12, 0.16))
    for i in range(4):
        curl = 0.26 + i * 0.10
        for f in (1, 90):
            key(f"tail_{i+1}", f, rot=(0.10, 0, curl))
    animations[sleep.name] = {"frames": [1, 90], "seconds": 3.0, "loop": True}

    lick, key = _begin_action(arm, "lick", 48)
    # Sitting back on the hind legs, grooming the chest and shoulder.
    for f in (1, 48):
        key("root", f, loc=(0, -0.028, 0))
        key("pelvis", f, rot=(-0.12, 0, 0))
        for name in rig["legs"]:
            fore = rig["legs"][name]["fore"]
            _pose_leg(key, rig, name, f, -0.012 if fore else 0.030, 0.0, -0.028)
    for f, rx, rz in [(1, 0.38, 0.10), (9, 0.58, 0.18), (17, 0.42, 0.04),
                      (25, 0.60, -0.12), (33, 0.43, 0.04), (41, 0.57, 0.16), (48, 0.38, 0.10)]:
        key("head", f, rot=(rx, 0.08, rz))
        key("neck", f, rot=(rx * 0.55, 0.05, rz * 0.4))
    for i in range(4):
        for f, s in [(1, 0), (16, 0.05), (32, -0.05), (48, 0)]:
            key(f"tail_{i+1}", f, rot=(0, 0, s * (i + 1) / 4.0))
    animations[lick.name] = {"frames": [1, 48], "seconds": 1.6, "loop": False}

    stretch, key = _begin_action(arm, "stretch", 60)
    # Forepaws reach ahead along the floor while the hips rise behind - the
    # classic feline bow - then the cat walks its feet back under itself.
    for f, amount in [(1, 0.0), (15, 1.0), (42, 1.0), (60, 0.0)]:
        drop = -0.055 * amount
        key("root", f, loc=(0, drop, 0))
        for name in rig["legs"]:
            leg = rig["legs"][name]
            if leg["fore"]:
                _pose_leg(key, rig, name, f, -0.055 * amount, 0.0, drop)
            else:
                _pose_leg(key, rig, name, f, 0.030 * amount, 0.0, drop + 0.055 * amount)
        key("pelvis", f, rot=(-0.26 * amount, 0, 0))
        key("spine", f, rot=(0.24 * amount, 0, 0))
        key("chest", f, rot=(0.20 * amount, 0, 0))
        key("neck", f, rot=(-0.18 * amount, 0, 0))
        key("head", f, rot=(-0.20 * amount, 0, 0))
    for i in range(4):
        for f, s in [(1, 0), (15, -0.10), (42, 0.10), (60, 0)]:
            key(f"tail_{i+1}", f, rot=(-0.12 if i == 0 else 0.0, 0, s * (i + 1) / 4.0))
    animations[stretch.name] = {"frames": [1, 60], "seconds": 2.0, "loop": False}

    bpy.ops.object.mode_set(mode="OBJECT")
    arm.animation_data.action = idle
    animations["_solver"] = {"max_reach_shortfall_m": round(max(misses), 5),
                             "walk_amplitude_m": round(amplitude, 4)}
    return animations


def audit_gait(arm, rig, seconds):
    """Replay the walk and measure what the feet actually do in world space.

    Checks the three defects that make a quadruped walk read as wrong: feet that
    slide while planted, feet that sink through the floor, and a swing that
    never leaves it.
    """
    action = bpy.data.actions.get("walk")
    arm.animation_data.action = action
    scene = bpy.context.scene
    scene.frame_start = 1; scene.frame_end = WALK_FRAMES + 1
    dt = seconds / float(WALK_FRAMES)

    tracks = {name: [] for name in rig["legs"]}
    for frame in range(1, WALK_FRAMES + 2):
        scene.frame_set(frame)
        bpy.context.view_layer.update()
        for name in rig["legs"]:
            tip = arm.matrix_world @ arm.pose.bones[name + "_paw"].tail
            tracks[name].append((tip.x, tip.y, tip.z))

    report = {"legs": {}, "support_counts": []}
    worst_slip = 0.0
    worst_sink = 0.0
    worst_contact = 0.0
    min_clearance = 9.9
    # Stance comes from the authored phase, not from a height threshold: a
    # threshold silently absorbs the fast first swing frame and hides slip.
    stance = {name: [((i / float(WALK_FRAMES)) - WALK_PHASE[name]) % 1.0 < WALK_DUTY
                     for i in range(WALK_FRAMES)] for name in tracks}
    for name, pts in tracks.items():
        planted = [i for i in range(WALK_FRAMES) if stance[name][i]]
        speeds = [(pts[i + 1][1] - pts[i][1]) / dt for i in planted if stance[name][(i + 1) % WALK_FRAMES]]
        mean = sum(speeds) / len(speeds) if speeds else 0.0
        slip = max((abs(v - mean) for v in speeds), default=0.0)
        contact = max((abs(pts[i][2] - rig["toe_z"]) for i in planted), default=0.0)
        sink = max(0.0, -min(p[2] for p in pts))
        clearance = max(p[2] for p in pts) - rig["toe_z"]
        worst_slip = max(worst_slip, slip)
        worst_sink = max(worst_sink, sink)
        worst_contact = max(worst_contact, contact)
        min_clearance = min(min_clearance, clearance)
        report["legs"][name] = {
            "stance_frames": len(planted),
            "stance_speed_m_s": round(mean, 4),
            "max_speed_deviation_m_s": round(slip, 4),
            "max_contact_height_error_m": round(contact, 5),
            "swing_clearance_m": round(clearance, 4),
            "floor_penetration_m": round(sink, 5),
        }
    for i in range(WALK_FRAMES):
        report["support_counts"].append(sum(1 for name in tracks if stance[name][i]))

    report["worst_slip_m_s"] = round(worst_slip, 4)
    report["worst_floor_penetration_m"] = round(worst_sink, 5)
    report["worst_contact_height_error_m"] = round(worst_contact, 5)
    report["min_swing_clearance_m"] = round(min_clearance, 4)
    report["always_supported"] = min(report["support_counts"]) >= 2
    report["pass"] = (worst_slip <= 0.05 and worst_sink <= 0.004 and worst_contact <= 0.005
                      and min_clearance >= 0.012 and report["always_supported"])
    return report


def export_glb(arm, obj):
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True); obj.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(
        filepath=PROD_GLB, export_format="GLB", use_selection=True,
        export_yup=True, export_apply=False, export_animations=True,
        export_animation_mode="ACTIONS", export_frame_range=False,
        export_action_filter=True, export_extra_animations=True,
        export_texcoords=True, export_normals=True, export_tangents=True,
        export_materials="EXPORT", export_skins=True)


def make_lod(obj, tris, path):
    """Decimated LOD (mesh only) exported as a separate GLB."""
    dup = obj.copy(); dup.data = obj.data.copy()
    bpy.context.collection.objects.link(dup)
    ratio = min(1.0, tris / max(1, topo(dup)["triangles"]))
    d = dup.modifiers.new("dec", "DECIMATE"); d.ratio = ratio
    bpy.context.view_layer.objects.active = dup
    bpy.ops.object.select_all(action="DESELECT"); dup.select_set(True)
    bpy.ops.object.modifier_apply(modifier=d.name)
    stats = topo(dup)
    # LODs share LOD0's UV set + forge_cat material; export the material slot as
    # a placeholder (no embedded 1024 textures) so each LOD stays lightweight and
    # the runtime assigns the shared material.
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB",
                              use_selection=True, export_yup=True, export_materials="PLACEHOLDER")
    bpy.data.objects.remove(dup)
    return stats


def main():
    for d in (TEX, COATS_DIR, LOD, REP):
        os.makedirs(d, exist_ok=True)
    clear()
    obj, orientation = build_lod0()
    rework_paws(obj)
    deblock(obj)
    lod0 = topo(obj)
    make_uv(obj)
    ao_img, nrm_img = bake_maps(obj)
    body = measure_body(obj)
    coat_images = {}
    for coat in COATS:
        coat_images[coat["id"]] = author_albedo(obj, ao_img, coat, body["back_z"])
    rgh_img = author_roughness(obj, ao_img)
    final_material(obj, coat_images["forge"], nrm_img, rgh_img)
    arm, wmode, rig = build_rig(obj)
    animations = make_animations(arm, rig)
    gait = audit_gait(arm, rig, animations["walk"]["seconds"])
    # Guard against any stray/floating geometry leaking into the export so the
    # GLB carries exactly one character mesh + its armature.
    for s in [o for o in bpy.data.objects if o.type == "MESH" and o is not obj]:
        bpy.data.objects.remove(s, do_unlink=True)
    export_glb(arm, obj)
    lod1 = make_lod(obj, 3500, os.path.join(LOD, "forge_cat_lod1.glb"))
    lod2 = make_lod(obj, 1000, os.path.join(LOD, "forge_cat_lod2.glb"))

    dims = obj.dimensions
    report = {
        "lod0": lod0,
        "lod1": lod1,
        "lod2": lod2,
        "metric_dimensions_m": [round(dims.x, 4), round(dims.y, 4), round(dims.z, 4)],
        "ground_min_z": round(min(v.co.z for v in obj.data.vertices), 5),
        "uv_layers": [x.name for x in obj.data.uv_layers],
        "material": obj.data.materials[0].name,
        "textures": ["forge_cat_albedo.png", "forge_cat_normal.png",
                     "forge_cat_roughness.png", "forge_cat_ao.png"],
        "coats": [c["id"] for c in COATS],
        "texture_size": TEX_SIZE,
        "weight_mode": wmode,
        "cross_limb_weights_removed": rig["cross_limb_weights_removed"],
        "bones": len(arm.data.bones),
        "orientation": orientation,
        "rig": {k: (round(v, 4) if isinstance(v, float) else v)
                for k, v in rig.items() if k != "legs"},
        "animations": animations,
        "gait": gait,
        "budget_ok": {"lod0_within_cap": lod0["triangles"] <= 12000,
                      "lod1_in_range": 3000 <= lod1["triangles"] <= 4200,
                      "lod2_in_range": 700 <= lod2["triangles"] <= 1300,
                      "gait_pass": gait["pass"]},
    }
    with open(os.path.join(REP, "production_report.json"), "w") as f:
        json.dump(report, f, indent=2)
    print("PROD_REPORT=" + json.dumps(report))


if __name__ == "__main__":
    main()
