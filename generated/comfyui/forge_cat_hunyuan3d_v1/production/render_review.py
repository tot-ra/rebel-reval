"""Review sheets for the forge cat: walk cycle, rest poses, and coat variants.

These are the images the animation and coat work is judged on, so they are built
by script rather than by hand:

  previews/walk_cycle.png  - six phases of the walk in profile
  previews/pose_sheet.png  - idle / sleep / lick / stretch three-quarter frames
  previews/coat_sheet.png  - the six town coats on the same standing cat

Run: blender -b --python render_review.py
"""

import bpy, os, math
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
GLB = os.path.join(HERE, "forge_cat_production_v1.glb")
COATS = os.path.join(HERE, "tex", "coats")
OUT = os.path.join(HERE, "previews")
TILE = 480


def load_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=GLB)
    for o in [o for o in bpy.data.objects if o.type == "MESH" and o.name.startswith("Icosphere")]:
        bpy.data.objects.remove(o, do_unlink=True)
    mesh = next(o for o in bpy.context.scene.objects if o.type == "MESH")
    arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")

    corners = [mesh.matrix_world @ Vector(c) for c in mesh.bound_box]
    mn = Vector((min(v.x for v in corners), min(v.y for v in corners), min(v.z for v in corners)))
    mx = Vector((max(v.x for v in corners), max(v.y for v in corners), max(v.z for v in corners)))
    center = (mn + mx) * 0.5
    size = mx - mn

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = scene.render.resolution_y = TILE
    scene.render.film_transparent = False
    if scene.world is None:
        scene.world = bpy.data.worlds.new("World")
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.22, 0.21, 0.20, 1)
    bg.inputs["Strength"].default_value = 0.75

    key = bpy.data.lights.new("key", "AREA"); key.energy = 26; key.color = (1.0, 0.80, 0.58); key.size = 1.4
    ko = bpy.data.objects.new("key", key); scene.collection.objects.link(ko)
    ko.location = center + Vector((0.6, -0.7, 0.9))
    ko.rotation_euler = (center - ko.location).to_track_quat("-Z", "Y").to_euler()
    fill = bpy.data.lights.new("fill", "AREA"); fill.energy = 9; fill.color = (0.55, 0.65, 0.85); fill.size = 1.8
    fo = bpy.data.objects.new("fill", fill); scene.collection.objects.link(fo)
    fo.location = center + Vector((-0.8, 0.6, 0.5))
    fo.rotation_euler = (center - fo.location).to_track_quat("-Z", "Y").to_euler()

    # Floor plane: a walk is judged on whether the paws meet the ground.
    bpy.ops.mesh.primitive_plane_add(size=max(size) * 6.0, location=(center.x, center.y, 0.0))
    floor = bpy.context.active_object
    floor_mat = bpy.data.materials.new("floor"); floor_mat.use_nodes = True
    floor_mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.18, 0.16, 0.15, 1)
    floor_mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.95
    floor.data.materials.append(floor_mat)

    cam_data = bpy.data.cameras.new("cam"); cam_data.type = "ORTHO"
    cam_data.ortho_scale = max(size) * 1.35
    cam = bpy.data.objects.new("cam", cam_data); scene.collection.objects.link(cam); scene.camera = cam
    return mesh, arm, center, size, cam


def aim(cam, center, offset):
    cam.location = Vector((center.x, center.y, 0)) + offset
    cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()


def render_tile(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def sheet(tiles, columns, out_path):
    """Compose rendered tiles into one grid image."""
    rows = (len(tiles) + columns - 1) // columns
    canvas = np.zeros((rows * TILE, columns * TILE, 4), dtype=np.float32)
    canvas[:, :, 3] = 1.0
    for index, path in enumerate(tiles):
        img = bpy.data.images.load(path)
        buf = np.empty(len(img.pixels), dtype=np.float32)
        img.pixels.foreach_get(buf)
        buf = buf.reshape((img.size[1], img.size[0], 4))
        r = rows - 1 - index // columns          # image origin is bottom-left
        c = index % columns
        canvas[r * TILE:(r + 1) * TILE, c * TILE:(c + 1) * TILE] = buf
        bpy.data.images.remove(img)
    out = bpy.data.images.new("sheet", columns * TILE, rows * TILE, alpha=False)
    out.pixels.foreach_set(canvas.reshape(-1))
    out.filepath_raw = out_path
    out.file_format = "PNG"
    out.save()
    bpy.data.images.remove(out)
    for path in tiles:
        os.remove(path)


def main():
    os.makedirs(OUT, exist_ok=True)
    mesh, arm, center, size, cam = load_scene()
    scene = bpy.context.scene
    tmp = os.path.join(OUT, "_tile")

    # 1. Walk cycle in profile, six evenly spaced phases.
    walk = bpy.data.actions.get("walk")
    arm.animation_data.action = walk
    aim(cam, center, Vector((-max(size) * 3.0, 0, center.z)))
    tiles = []
    for i, frame in enumerate([1, 4, 7, 10, 13, 16]):
        scene.frame_set(frame)
        path = "%s_walk_%d.png" % (tmp, i)
        render_tile(path); tiles.append(path)
    sheet(tiles, 3, os.path.join(OUT, "walk_cycle.png"))

    # 2. Rest poses, three-quarter view at the pose's hold frame.
    aim(cam, center, Vector((-max(size) * 2.1, -max(size) * 2.1, center.z + size.z * 0.25)))
    tiles = []
    for name, frame in (("idle", 75), ("sleep", 45), ("lick", 25), ("stretch", 30)):
        action = bpy.data.actions.get(name)
        if action is None:
            continue
        arm.animation_data.action = action
        scene.frame_set(frame)
        path = "%s_pose_%s.png" % (tmp, name)
        render_tile(path); tiles.append(path)
    sheet(tiles, 4, os.path.join(OUT, "pose_sheet.png"))

    # 3. Coat variants on the standing cat.
    arm.animation_data.action = bpy.data.actions.get("idle")
    scene.frame_set(1)
    aim(cam, center, Vector((-max(size) * 2.1, -max(size) * 2.1, center.z + size.z * 0.25)))
    material = mesh.data.materials[0]
    albedo_node = next(n for n in material.node_tree.nodes
                       if n.type == "TEX_IMAGE" and n.outputs["Color"].links
                       and n.outputs["Color"].links[0].to_socket.name == "Base Color")
    embedded = albedo_node.image
    tiles = []
    for coat in ("forge", "tabby_brown", "tabby_grey", "black", "ginger", "white_black"):
        if coat == "forge":
            albedo_node.image = embedded
        else:
            albedo_node.image = bpy.data.images.load(
                os.path.join(COATS, "forge_cat_albedo_%s.png" % coat))
        path = "%s_coat_%s.png" % (tmp, coat)
        render_tile(path); tiles.append(path)
    sheet(tiles, 3, os.path.join(OUT, "coat_sheet.png"))
    print("REVIEW_SHEETS=" + ",".join(["walk_cycle.png", "pose_sheet.png", "coat_sheet.png"]))


if __name__ == "__main__":
    main()
