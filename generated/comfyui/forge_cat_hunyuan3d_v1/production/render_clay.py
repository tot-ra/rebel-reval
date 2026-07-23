"""Clay-render a GLB from orbit views to review silhouette + paws.

Usage: blender -b --python render_clay.py -- <glb> <out_prefix>
"""
import bpy, sys, os, math
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
GLB, PREFIX = argv[0], argv[1]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(GLB))
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
corners = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
mn = Vector((min(v.x for v in corners), min(v.y for v in corners), min(v.z for v in corners)))
mx = Vector((max(v.x for v in corners), max(v.y for v in corners), max(v.z for v in corners)))
center = (mn + mx) * 0.5
size = mx - mn
radius = max(size) * 0.5

clay = bpy.data.materials.new("clay")
clay.use_nodes = True
bsdf = clay.node_tree.nodes.get("Principled BSDF")
bsdf.inputs["Base Color"].default_value = (0.32, 0.30, 0.29, 1.0)
bsdf.inputs["Roughness"].default_value = 0.7
for o in meshes:
    o.data.materials.clear()
    o.data.materials.append(clay)
    for p in o.data.polygons:
        p.use_smooth = True

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = scene.render.resolution_y = 720
if scene.world is None:
    scene.world = bpy.data.worlds.new("World")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.6, 0.6, 0.62, 1)
scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0

cam_data = bpy.data.cameras.new("cam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = max(size) * 1.25
cam = bpy.data.objects.new("cam", cam_data)
bpy.context.collection.objects.link(cam)
scene.camera = cam

for nm, ang in [("front", 0), ("threeq", 35), ("side", 90), ("back", 180)]:
    a = math.radians(ang)
    # In glTF/Godot frame: +Y up, -Z forward. Camera orbits in XZ plane of glTF.
    d = max(size) * 3.0
    cam.location = center + Vector((math.sin(a) * d, size.y * 0.05, math.cos(a) * d))
    cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
    key = bpy.data.lights.new("key", "SUN"); key.energy = 4.0
    ko = bpy.data.objects.new("key", key); bpy.context.collection.objects.link(ko)
    ko.rotation_euler = (math.radians(55), 0, math.radians(30 + ang))
    scene.render.filepath = f"{PREFIX}_{nm}.png"
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(ko)
print("CLAY_DONE", mn[:], mx[:])
