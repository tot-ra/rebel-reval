"""Render rest + clip frames of a rigged animal GLB from side and front (Eevee, flat light).
blender -b --factory-startup --python render_preview.py -- --glb in.glb --out dir --clips Fly,Walk,Peck,Idle"""
import argparse, math, os, sys
import bpy
from mathutils import Vector
argv = sys.argv[sys.argv.index("--") + 1:]
ap = argparse.ArgumentParser(); ap.add_argument("--glb"); ap.add_argument("--out")
ap.add_argument("--clips", default="Fly,Walk,Peck,Idle"); ap.add_argument("--size", type=int, default=640)
a = ap.parse_args(argv)
os.makedirs(a.out, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a.glb)
rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
sc.render.resolution_x = sc.render.resolution_y = a.size
w = bpy.data.worlds.new("w"); w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.8, 0.82, 0.85, 1); w.node_tree.nodes["Background"].inputs[1].default_value = 1.4
sc.world = w
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); sun.rotation_euler = (0.9, 0.2, 0.6); sun.data.energy = 2.5
sc.collection.objects.link(sun)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.type = "ORTHO"; cam.data.ortho_scale = 1.3
def shot(name, view):
    pos = {"front": (0, -4, 0.5), "side": (4, 0, 0.5), "back": (0, 4, 0.5)}[view]
    cam.location = pos
    d = Vector((0, 0, 0.5)) - Vector(pos)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(a.out, f"{name}_{view}.png"); bpy.ops.render.render(write_still=True)
for clip in a.clips.split(","):
    act = bpy.data.actions[clip]
    rig.animation_data_create().action = act
    f0, f1 = act.frame_range
    for tag, f in (("a", f0), ("b", (f0 + f1) / 2)):
        sc.frame_set(int(f))
        for v in ("front", "side", "back"):
            shot(f"{clip}_{tag}", v)
