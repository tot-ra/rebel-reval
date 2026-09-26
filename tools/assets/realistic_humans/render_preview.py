"""Offline EEVEE review plates for a built realistic human.

    blender -b build/realistic_humans/kalev.blend --python tools/assets/realistic_humans/render_preview.py -- \
        --out=build/realistic_humans/preview/kalev [--shots=rest,portrait,Walking_A:0.4]

A shot is `rest`, `portrait`, `portrait_side`, `back` or `<clip>:<fraction>`.
Engine captures remain the acceptance evidence; these plates are for fast
iteration on sculpt, weights and garments.
"""
import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def setup(scene):
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 900, 1100
    scene.view_settings.view_transform = "AgX"
    world = bpy.data.worlds.new("preview")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.42, 0.44, 0.47, 1)
    bg.inputs[1].default_value = 0.7
    key = bpy.data.objects.new("key", bpy.data.lights.new("key", "SUN"))
    key.data.energy = 3.2
    key.data.angle = math.radians(8)
    key.rotation_euler = (math.radians(50), 0, math.radians(-40))
    rim = bpy.data.objects.new("rim", bpy.data.lights.new("rim", "SUN"))
    rim.data.energy = 1.4
    rim.rotation_euler = (math.radians(60), 0, math.radians(150))
    for light in (key, rim):
        scene.collection.objects.link(light)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    return cam


def aim(cam, target, distance, lens, yaw_degrees, lift=0.05):
    cam.data.lens = lens
    yaw = math.radians(yaw_degrees)
    target = Vector(target)
    cam.location = target + Vector((-math.sin(yaw) * distance, -math.cos(yaw) * distance, lift))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True)
    parser.add_argument("--shots", default="rest,portrait,portrait_side,back,Idle:0.3,Walking_A:0.25,Running_B:0.3,1H_Melee_Attack_Chop:0.45")
    parser.add_argument("--hide", default="")
    parser.add_argument("--wear", default="", help="comma list of garment ids; others are hidden")
    args = parser.parse_args(argv)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    cam = setup(scene)
    rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    hidden = [h for h in args.hide.split(",") if h]
    wear = [w for w in args.wear.split(",") if w]
    for obj in bpy.data.objects:
        if "garment" in obj:
            obj.hide_render = obj["garment"] not in wear
            if not obj.hide_render:
                hidden += [c for c in obj["covers"].split(",") if c]
    for obj in bpy.data.objects:
        if obj.type == "MESH" and "garment" not in obj and any(obj.name.startswith(h) for h in hidden):
            obj.hide_render = True
    head = rig.data.bones["head"].head_local
    for shot in args.shots.split(","):
        rig.animation_data.action = None
        for pb in rig.pose.bones:
            pb.matrix_basis.identity()
        scene.frame_set(0)
        if ":" in shot:
            clip, fraction = shot.split(":")
            action = bpy.data.actions[clip]
            rig.animation_data.action = action
            if hasattr(rig.animation_data, "action_slot") and action.slots:
                rig.animation_data.action_slot = action.slots[0]
            start, end = action.frame_range
            scene.frame_set(int(start + (end - start) * float(fraction)))
            aim(cam, (0, 0, 1.0), 4.4, 50, 30)
        elif shot == "portrait":
            aim(cam, head + Vector((0, 0, 0.12)), 0.95, 85, 20)
        elif shot == "portrait_side":
            aim(cam, head + Vector((0, 0, 0.12)), 0.95, 85, 80)
        elif shot == "feet":
            aim(cam, (0.0, -0.05, 0.08), 1.0, 50, 30, lift=0.25)
        elif shot == "back":
            aim(cam, (0, 0, 1.0), 4.4, 50, 180)
        else:
            aim(cam, (0, 0, 1.0), 4.4, 50, 25)
        scene.render.filepath = str(out / f"{shot.replace(':', '_')}.png")
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    main()
