"""Contact-sheet renders of a rigged human GLB (rest pose, clip frames, eye turn).

  blender -b --factory-startup --python tools/assets/meshy_human/render_rigged_preview.py -- \
      --glb build/<char>/rig/<char>_meshy_rigged.glb --out build/<char>/rig/preview \
      [--clips Idle,Walking_A] [--eye-yaw 25] [--arms-up-clip Cheer] [--face-keys blink,smile,jaw_open]

Writes rest_front.png, rest_34.png, <clip>.png (mid-clip frame), head_eyes.png and
head_back.png. --arms-up-clip adds <clip>.png and armpit_<clip>.png at the frame with
the highest hands (armpit stretch check); --face-keys adds face_rest.png and
face_<key>.png with that shape key at 1.0 on every mesh that has it.
Loading the exported GLB (not the Blender scene) also proves the export round-trips.
"""

import argparse
import math
import os
import sys

import bpy
from mathutils import Euler, Vector


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--glb", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--clips", default="Idle,Walking_A,1H_Melee_Attack_Chop")
    p.add_argument("--eye-yaw", type=float, default=25.0)
    p.add_argument("--res", type=int, default=900)
    p.add_argument("--arms-up-clip", default="")
    p.add_argument("--face-keys", default="")
    return p.parse_args(argv)


def main():
    a = parse_args()
    os.makedirs(a.out, exist_ok=True)
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(a.glb))
    rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    for o in [o for o in bpy.data.objects if o.type == "MESH" and not o.vertex_groups]:
        bpy.data.objects.remove(o, do_unlink=True)  # glTF importer's phantom Icosphere

    s = bpy.context.scene
    s.render.engine = "BLENDER_EEVEE"
    s.render.resolution_x, s.render.resolution_y = int(a.res * 0.75), a.res
    s.view_settings.view_transform = "AgX"
    w = bpy.data.worlds.new("w")
    s.world = w
    w.color = (0.55, 0.56, 0.58)
    for name, energy, rot in (("key", 3.5, (50, 0, 25)), ("fill", 1.2, (60, 0, -120)), ("rim", 2.0, (110, 0, 180))):
        light = bpy.data.lights.new(name, "SUN")
        light.energy = energy
        lo = bpy.data.objects.new(name, light)
        s.collection.objects.link(lo)
        lo.rotation_euler = Euler([math.radians(r) for r in rot])
    cam_data = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_data)
    s.collection.objects.link(cam)
    s.camera = cam

    def shot(name, yaw, target, dist, lens):
        cam_data.lens = lens
        cam.location = target + Vector((math.sin(math.radians(yaw)) * dist, -math.cos(math.radians(yaw)) * dist, 0))
        cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
        s.render.filepath = os.path.join(a.out, name)
        bpy.ops.render.render(write_still=True)

    def rest():
        if rig.animation_data:
            rig.animation_data.action = None
        for pb in rig.pose.bones:
            pb.matrix_basis.identity()
        s.frame_set(1)

    body_c = Vector((0, 0, 0.85))
    head = rig.matrix_world @ rig.data.bones["head"].head_local + Vector((0, 0, 0.13))
    rest()
    shot("rest_front.png", 0, body_c, 4.2, 50)
    shot("rest_34.png", 35, body_c, 4.2, 50)
    rig.animation_data_create()
    for clip in [c for c in a.clips.split(",") if c]:
        act = bpy.data.actions.get(clip)
        if not act:
            print("missing clip", clip)
            continue
        rig.animation_data.action = act
        f0, f1 = act.frame_range
        s.frame_set(int((f0 + f1) / 2))
        shot(f"{clip}.png", 30, body_c, 4.2, 50)
    rest()
    for sfx in ("l", "r"):
        pb = rig.pose.bones.get(f"eye.{sfx}")
        if pb:
            pb.rotation_mode = "XYZ"
            pb.rotation_euler = (0, 0, math.radians(a.eye_yaw))  # bone Y points forward; Z = yaw
    s.frame_set(1)
    shot("head_eyes.png", 20, head, 0.75, 85)
    rest()
    shot("head_back.png", 160, head, 0.75, 85)

    act = bpy.data.actions.get(a.arms_up_clip) if a.arms_up_clip else None
    if act:
        rig.animation_data.action = act
        f0, f1 = (int(f) for f in act.frame_range)

        def hands_z(f):
            s.frame_set(f)
            return sum((rig.matrix_world @ rig.pose.bones[f"hand.{x}"].head).z for x in "lr")

        best = max(range(f0, f1 + 1), key=hands_z)
        s.frame_set(best)
        shot(f"{act.name}.png", 15, body_c + Vector((0, 0, 0.25)), 4.6, 50)
        pit = rig.matrix_world @ rig.pose.bones["upperarm.l"].head - Vector((0, 0, 0.08))
        shot(f"armpit_{act.name}.png", 55, pit, 1.1, 85)
        rest()

    keys = [k for k in a.face_keys.split(",") if k]
    if keys:
        meshes = [o for o in bpy.data.objects if o.type == "MESH" and o.data.shape_keys]
        face_c = head - Vector((0, 0, 0.06))
        shot("face_rest.png", 0, face_c, 0.6, 85)
        for k in keys:
            for o in meshes:
                for kb in o.data.shape_keys.key_blocks[1:]:
                    kb.value = 1.0 if kb.name == k else 0.0
            shot(f"face_{k}.png", 0, face_c, 0.6, 85)
        for o in meshes:
            for kb in o.data.shape_keys.key_blocks[1:]:
                kb.value = 0.0


main()
