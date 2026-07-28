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


def build_lod0():
    """Voxel quad retopo of the approved silhouette, metric + feet on Z=0."""
    bpy.ops.import_scene.gltf(filepath=SRC)
    obj = next(o for o in bpy.context.scene.objects if o.type == "MESH")
    obj.name = "ForgeCatMesh"
    bpy.ops.object.select_all(action="DESELECT"); obj.select_set(True)
    bpy.context.view_layer.objects.active = obj

    # detect head end (ears = upper-band mass) and face head toward -Y in Blender
    vs = [obj.matrix_world @ v.co for v in obj.data.vertices]
    zmin = min(v.z for v in vs); zmax = max(v.z for v in vs)
    hi = zmin + (zmax - zmin) * 0.72
    xmid = (max(v.x for v in vs) + min(v.x for v in vs)) * 0.5
    neg = sum(1 for v in vs if v.x < xmid and v.z > hi)
    pos = sum(1 for v in vs if v.x > xmid and v.z > hi)
    head_neg_x = neg >= pos
    obj.rotation_euler = (0, 0, math.radians(90 if head_neg_x else -90))
    bpy.ops.object.transform_apply(rotation=True)

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
    return obj


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
                # 3) widen sole slightly + extend toe box toward the head
                v.co.y -= fwd_y * span * 0.012 if fwd_y < 0 else 0.0
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


def author_albedo(obj, ao_img):
    """Charcoal-gray short-fur albedo with restrained warm forge highlight on
    the back/top, AO multiplied in; baked to a 1024 baseColor texture."""
    scene = bpy.context.scene
    alb = new_image("forge_cat_albedo", (0.09, 0.09, 0.1, 1), non_color=False)
    mat = obj.data.materials[0]
    nt = mat.node_tree; nodes = nt.nodes; links = nt.links
    bsdf = nodes.get("Principled BSDF")

    charcoal = nodes.new("ShaderNodeRGB"); charcoal.outputs[0].default_value = (0.055, 0.052, 0.058, 1)
    warm = nodes.new("ShaderNodeRGB"); warm.outputs[0].default_value = (0.16, 0.10, 0.055, 1)
    # top/back warm highlight from world-Z gradient
    grad_geo = nodes.new("ShaderNodeNewGeometry")
    sep = nodes.new("ShaderNodeSeparateXYZ")
    links.new(grad_geo.outputs["Position"], sep.inputs["Vector"])
    ramp = nodes.new("ShaderNodeMapRange"); ramp.inputs["From Min"].default_value = 0.16
    ramp.inputs["From Max"].default_value = 0.33
    links.new(sep.outputs["Z"], ramp.inputs["Value"])
    mix_warm = nodes.new("ShaderNodeMixRGB"); mix_warm.blend_type = "MIX"
    links.new(ramp.outputs["Result"], mix_warm.inputs["Fac"])
    links.new(charcoal.outputs[0], mix_warm.inputs["Color1"])
    links.new(warm.outputs[0], mix_warm.inputs["Color2"])
    # subtle fur value noise
    noise = nodes.new("ShaderNodeTexNoise"); noise.inputs["Scale"].default_value = 45.0
    fur_mix = nodes.new("ShaderNodeMixRGB"); fur_mix.blend_type = "MULTIPLY"
    fur_mix.inputs["Fac"].default_value = 0.18
    links.new(mix_warm.outputs["Color"], fur_mix.inputs["Color1"])
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
    alb.filepath_raw = os.path.join(TEX, "forge_cat_albedo.png")
    alb.file_format = "PNG"; alb.save()
    return alb


def final_material(obj, alb, nrm):
    for m in list(obj.data.materials):
        pass
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
    bsdf.inputs["Roughness"].default_value = 0.82
    bsdf.inputs["Metallic"].default_value = 0.0
    obj.data.materials.append(mat)
    return mat


def build_rig(obj):
    """Quadruped skeleton, Z-up, head toward -Y, origin between paws on ground."""
    me = obj.data
    xs = [v.co.x for v in me.vertices]; ys = [v.co.y for v in me.vertices]; zs = [v.co.z for v in me.vertices]
    x0, x1 = min(xs), max(xs); y0, y1 = min(ys), max(ys); z0, z1 = min(zs), max(zs)
    back_z = z0 + (z1 - z0) * 0.62
    hx = (x1 - x0) * 0.22            # leg lateral offset
    head_y = y0 + (y1 - y0) * 0.10
    tail_y = y1 - (y1 - y0) * 0.06

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

    root = bone("root", (0, tail_y, 0.001), (0, tail_y, back_z * 0.5))
    pelvis = bone("pelvis", (0, tail_y * 0.7, back_z), (0, tail_y * 0.35, back_z), root)
    spine = bone("spine", pelvis.tail, (0, (head_y + tail_y) * 0.15, back_z * 1.03), pelvis)
    chest = bone("chest", spine.tail, (0, head_y * 0.6, back_z * 1.03), spine)
    neck = bone("neck", chest.tail, (0, head_y * 0.35, back_z * 1.12), chest)
    head = bone("head", neck.tail, (0, head_y, back_z * 1.18), neck)

    # tail chain
    parent = pelvis; ty0 = tail_y
    for i in range(4):
        seg = bone(f"tail_{i+1}", (0, ty0 + (y1 - ty0) * (i / 4.0), back_z + (z1 - back_z) * (0.2 + 0.15 * i)),
                   (0, ty0 + (y1 - ty0) * ((i + 1) / 4.0), back_z + (z1 - back_z) * (0.2 + 0.15 * (i + 1))), parent)
        parent = seg

    # four legs: upper, lower, paw
    def leg(prefix, sx, ly, parent_bone):
        top = (sx, ly, back_z * 0.92)
        knee = (sx, ly, back_z * 0.5)
        ankle = (sx, ly, back_z * 0.18)
        toe = (sx, ly - (y1 - y0) * 0.05, 0.001)
        u = bone(prefix + "_upper", top, knee, parent_bone)
        l = bone(prefix + "_lower", knee, ankle, u)
        bone(prefix + "_paw", ankle, toe, l)

    leg("legFL", -hx, head_y + (y1 - y0) * 0.10, chest)
    leg("legFR", hx, head_y + (y1 - y0) * 0.10, chest)
    leg("legBL", -hx, tail_y - (y1 - y0) * 0.06, pelvis)
    leg("legBR", hx, tail_y - (y1 - y0) * 0.06, pelvis)

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
    return arm, wmode


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


def make_animations(arm):
    """Author the five canonical clips used by ForgeCat's ambient routine.

    The motion stays intentionally restrained because this cat is normally seen
    from an isometric game camera. The walk uses diagonal quadruped pairs; rest
    clips keep the root stationary except for small pose offsets.
    """
    animations = {}

    idle, key = _begin_action(arm, "idle", 150)
    for f, a in [(1, 0.0), (45, 0.02), (75, 0.028), (110, 0.015), (150, 0.0)]:
        key("spine", f, rot=(a, 0, 0))
        key("chest", f, rot=(a * 0.6, 0, 0))
    for f, rx, ry in [(1, 0, 0), (60, 0.05, 0.03), (120, 0.02, -0.03), (150, 0, 0)]:
        key("head", f, rot=(rx, ry, 0))
        key("neck", f, rot=(rx * 0.4, ry * 0.5, 0))
    for i in range(4):
        amp = 0.06 + 0.02 * i
        for f, s in [(1, 0), (50, amp), (100, -amp), (150, 0)]:
            key(f"tail_{i+1}", f, rot=(0, 0, s))
    animations[idle.name] = {"frames": [1, 150], "seconds": 5.0, "loop": True}

    walk, key = _begin_action(arm, "walk", 24)
    # Natural diagonal gait: front-left/rear-right oppose front-right/rear-left.
    gait = [(1, 0.0), (7, -0.34), (13, 0.0), (19, 0.34), (24, 0.0)]
    for f, swing in gait:
        for prefix in ("legFL", "legBR"):
            key(prefix + "_upper", f, rot=(swing, 0, 0))
            key(prefix + "_lower", f, rot=(-swing * 0.42, 0, 0))
        for prefix in ("legFR", "legBL"):
            key(prefix + "_upper", f, rot=(-swing, 0, 0))
            key(prefix + "_lower", f, rot=(swing * 0.42, 0, 0))
        key("pelvis", f, rot=(0, 0, swing * 0.035))
        key("chest", f, rot=(0, 0, -swing * 0.025))
    for f, lift in [(1, 0), (7, 0.006), (13, 0), (19, 0.006), (24, 0)]:
        key("root", f, loc=(0, 0, lift))
    for i in range(4):
        for f, s in [(1, 0), (7, 0.05), (13, 0), (19, -0.05), (24, 0)]:
            key(f"tail_{i+1}", f, rot=(0, 0, s * (i + 1) / 4.0))
    animations[walk.name] = {"frames": [1, 24], "seconds": 0.8, "loop": True}

    sleep, key = _begin_action(arm, "sleep", 90)
    for f, breath in [(1, 0.0), (45, 0.012), (90, 0.0)]:
        key("root", f, loc=(0, 0, -0.055 + breath))
        key("spine", f, rot=(0.14, 0, 0.04))
        key("chest", f, rot=(0.22, 0, -0.05))
        key("neck", f, rot=(0.30, 0.10, 0.12))
        key("head", f, rot=(0.42, 0.12, 0.16))
    for prefix, bend in (("legFL", 0.38), ("legFR", 0.30), ("legBL", -0.42), ("legBR", -0.34)):
        for f in (1, 90):
            key(prefix + "_upper", f, rot=(bend, 0, 0))
            key(prefix + "_lower", f, rot=(-bend * 0.8, 0, 0))
    for i in range(4):
        curl = 0.22 + i * 0.08
        for f in (1, 90):
            key(f"tail_{i+1}", f, rot=(0.12, 0, curl))
    animations[sleep.name] = {"frames": [1, 90], "seconds": 3.0, "loop": True}

    lick, key = _begin_action(arm, "lick", 48)
    for f in (1, 48):
        key("root", f, loc=(0, 0, -0.025))
        key("pelvis", f, rot=(-0.12, 0, 0))
        key("neck", f, rot=(0.30, 0.05, 0))
    for f, rx, rz in [(1, 0.38, 0.10), (9, 0.58, 0.18), (17, 0.42, 0.04),
                      (25, 0.60, -0.12), (33, 0.43, 0.04), (41, 0.57, 0.16), (48, 0.38, 0.10)]:
        key("head", f, rot=(rx, 0.08, rz))
    for prefix, bend in (("legBL", -0.24), ("legBR", -0.24)):
        for f in (1, 48):
            key(prefix + "_upper", f, rot=(bend, 0, 0))
            key(prefix + "_lower", f, rot=(-bend * 0.7, 0, 0))
    for i in range(4):
        for f, s in [(1, 0), (16, 0.05), (32, -0.05), (48, 0)]:
            key(f"tail_{i+1}", f, rot=(0, 0, s * (i + 1) / 4.0))
    animations[lick.name] = {"frames": [1, 48], "seconds": 1.6, "loop": True}

    stretch, key = _begin_action(arm, "stretch", 60)
    # Forelegs reach toward the head while the hips rise, then return cleanly.
    for f, amount in [(1, 0.0), (15, 0.55), (42, 0.55), (60, 0.0)]:
        key("root", f, loc=(0, 0, amount * 0.025))
        key("pelvis", f, rot=(-amount * 0.20, 0, 0))
        key("spine", f, rot=(amount * 0.22, 0, 0))
        key("chest", f, rot=(amount * 0.18, 0, 0))
        key("neck", f, rot=(-amount * 0.12, 0, 0))
        key("head", f, rot=(-amount * 0.16, 0, 0))
        for prefix in ("legFL", "legFR"):
            key(prefix + "_upper", f, rot=(-amount * 0.58, 0, 0))
            key(prefix + "_lower", f, rot=(amount * 0.32, 0, 0))
        for prefix in ("legBL", "legBR"):
            key(prefix + "_upper", f, rot=(amount * 0.16, 0, 0))
    for i in range(4):
        for f, s in [(1, 0), (15, -0.10), (42, 0.10), (60, 0)]:
            key(f"tail_{i+1}", f, rot=(0, 0, s * (i + 1) / 4.0))
    animations[stretch.name] = {"frames": [1, 60], "seconds": 2.0, "loop": False}

    bpy.ops.object.mode_set(mode="OBJECT")
    arm.animation_data.action = idle
    return animations


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
    for d in (TEX, LOD, REP):
        os.makedirs(d, exist_ok=True)
    clear()
    obj = build_lod0()
    rework_paws(obj)
    deblock(obj)
    lod0 = topo(obj)
    make_uv(obj)
    ao_img, nrm_img = bake_maps(obj)
    alb = author_albedo(obj, ao_img)
    final_material(obj, alb, nrm_img)
    arm, wmode = build_rig(obj)
    animations = make_animations(arm)
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
        "textures": ["forge_cat_albedo.png", "forge_cat_normal.png", "forge_cat_ao.png"],
        "texture_size": TEX_SIZE,
        "weight_mode": wmode,
        "bones": len(arm.data.bones),
        "animations": animations,
        "budget_ok": {"lod0_within_cap": lod0["triangles"] <= 12000,
                      "lod1_in_range": 3000 <= lod1["triangles"] <= 4200,
                      "lod2_in_range": 700 <= lod2["triangles"] <= 1300},
    }
    with open(os.path.join(REP, "production_report.json"), "w") as f:
        json.dump(report, f, indent=2)
    print("PROD_REPORT=" + json.dumps(report))


if __name__ == "__main__":
    main()
