"""Textured front/side/back/threeq previews of the production GLB under warm
forge-like light, plus a GLB integrity dump. blender -b --python this -- <glb> <prefix>"""
import bpy, sys, os, math, json
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
GLB, PREFIX = argv[0], argv[1]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(GLB))
# Blender's glTF importer fabricates a phantom "Icosphere" placeholder that is
# NOT in the GLB (verified via raw JSON); drop it so previews frame only the cat.
for o in [o for o in bpy.data.objects if o.type == "MESH" and o.name.startswith("Icosphere")]:
    bpy.data.objects.remove(o, do_unlink=True)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
arms = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
imgs = [i.name for i in bpy.data.images]
acts = [a.name for a in bpy.data.actions]
mats = [m.name for m in bpy.data.materials]

corners = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
mn = Vector((min(v.x for v in corners), min(v.y for v in corners), min(v.z for v in corners)))
mx = Vector((max(v.x for v in corners), max(v.y for v in corners), max(v.z for v in corners)))
center = (mn + mx) * 0.5
size = mx - mn

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = scene.render.resolution_y = 900
if scene.world is None:
    scene.world = bpy.data.worlds.new("World")
scene.world.use_nodes = True
bg = scene.world.node_tree.nodes["Background"]
bg.inputs["Color"].default_value = (0.20, 0.18, 0.17, 1)   # dim forge ambient
bg.inputs["Strength"].default_value = 0.6

# warm forge key + cool fill (calibrated so charcoal reads as charcoal, not blown out)
key = bpy.data.lights.new("key", "AREA"); key.energy = 22; key.color = (1.0, 0.74, 0.46)
key.size = 1.2
ko = bpy.data.objects.new("key", key); scene.collection.objects.link(ko)
ko.location = center + Vector((0.5, -0.6, 0.8)); ko.rotation_euler = (center - ko.location).to_track_quat("-Z", "Y").to_euler()
fill = bpy.data.lights.new("fill", "AREA"); fill.energy = 8; fill.color = (0.5, 0.6, 0.8); fill.size = 1.5
fo = bpy.data.objects.new("fill", fill); scene.collection.objects.link(fo)
fo.location = center + Vector((-0.7, 0.5, 0.5)); fo.rotation_euler = (center - fo.location).to_track_quat("-Z", "Y").to_euler()

cam_data = bpy.data.cameras.new("cam"); cam_data.type = "ORTHO"; cam_data.ortho_scale = max(size) * 1.3
cam = bpy.data.objects.new("cam", cam_data); scene.collection.objects.link(cam); scene.camera = cam
D = max(size) * 3.0
h = center.z
# Re-imported frame: length runs along X with the head toward -X, up is Z.
views = {
    "front": Vector((-D, 0, h)),                                  # face-on
    "side": Vector((0, -D, h)),                                   # profile
    "back": Vector((D, 0, h)),                                    # rear
    "threeq": Vector((-D * 0.72, -D * 0.72, h + size.z * 0.15)),  # hero 3/4
}
for nm, loc in views.items():
    cam.location = Vector((center.x, center.y, 0)) + loc
    cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = f"{PREFIX}_{nm}.png"
    bpy.ops.render.render(write_still=True)

info = {"meshes": [o.name for o in meshes], "armatures": [o.name for o in arms],
        "images": imgs, "actions": acts, "materials": mats,
        "bounds_min": [round(x, 4) for x in mn], "bounds_max": [round(x, 4) for x in mx],
        "dims": [round(size.x, 4), round(size.y, 4), round(size.z, 4)]}
print("GLB_INFO=" + json.dumps(info))
