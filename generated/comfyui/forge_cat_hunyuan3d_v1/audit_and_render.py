"""Audit and render a Hunyuan3D candidate without modifying its GLB.

The script writes three independent views and a JSON topology report. It does
not decimate, repair, rig, texture, or install the candidate in Godot because
those production steps must wait for explicit visual approval.
"""

import json
import math
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector


ASSET_DIR = Path(__file__).resolve().parent
GLB_PATH = ASSET_DIR / "forge_cat_hunyuan3d_v1.glb"
REPORT_PATH = ASSET_DIR / "mesh_audit.json"


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def point_at(obj: bpy.types.Object, target: Vector) -> None:
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


def material(name: str, color: tuple[float, float, float, float]) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = color
    shader.inputs["Roughness"].default_value = 0.72
    return mat


def world_bounds(objects: list[bpy.types.Object]) -> tuple[Vector, Vector]:
    corners = [obj.matrix_world @ Vector(corner) for obj in objects for corner in obj.bound_box]
    return (
        Vector((min(v.x for v in corners), min(v.y for v in corners), min(v.z for v in corners))),
        Vector((max(v.x for v in corners), max(v.y for v in corners), max(v.z for v in corners))),
    )


def mesh_report(obj: bpy.types.Object) -> dict:
    mesh = obj.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.verts.ensure_lookup_table()
    bm.edges.ensure_lookup_table()
    bm.faces.ensure_lookup_table()

    unseen = set(range(len(bm.verts)))
    components = []
    while unseen:
        start = unseen.pop()
        stack = [bm.verts[start]]
        vertex_count = 0
        face_ids = set()
        while stack:
            vertex = stack.pop()
            vertex_count += 1
            for face in vertex.link_faces:
                face_ids.add(face.index)
            for edge in vertex.link_edges:
                other = edge.other_vert(vertex)
                if other.index in unseen:
                    unseen.remove(other.index)
                    stack.append(other)
        components.append({"vertices": vertex_count, "faces": len(face_ids)})
    components.sort(key=lambda entry: entry["vertices"], reverse=True)

    report = {
        "name": obj.name,
        "vertices": len(mesh.vertices),
        "edges": len(mesh.edges),
        "polygons": len(mesh.polygons),
        "triangles": sum(max(0, len(face.vertices) - 2) for face in mesh.polygons),
        "connected_components": len(components),
        "components": components,
        "loose_vertices": sum(1 for vertex in bm.verts if not vertex.link_edges),
        "loose_edges": sum(1 for edge in bm.edges if not edge.link_faces),
        "boundary_edges": sum(1 for edge in bm.edges if len(edge.link_faces) == 1),
        "non_manifold_edges": sum(1 for edge in bm.edges if not edge.is_manifold),
    }
    bm.free()
    return report


def configure_render(meshes: list[bpy.types.Object], bounds_min: Vector, bounds_max: Vector) -> bpy.types.Object:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 768
    scene.render.resolution_y = 768
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.render.film_transparent = False
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.69, 0.69, 0.69, 1.0)
    background.inputs["Strength"].default_value = 0.8
    scene.view_settings.look = "AgX - Medium High Contrast"

    clay = material("Inspection clay", (0.29, 0.16, 0.075, 1.0))
    for obj in meshes:
        obj.data.materials.clear()
        obj.data.materials.append(clay)
        for polygon in obj.data.polygons:
            polygon.use_smooth = True

    center = (bounds_min + bounds_max) * 0.5
    size = bounds_max - bounds_min
    radius = max(size.x, size.y, size.z) * 0.5

    camera_data = bpy.data.cameras.new("InspectionCamera")
    camera = bpy.data.objects.new("InspectionCamera", camera_data)
    bpy.context.collection.objects.link(camera)
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = max(size.x, size.y, size.z) * 1.32
    scene.camera = camera

    for name, location, energy, area_size in (
        ("Key", center + Vector((-radius * 2.0, -radius * 2.2, radius * 2.4)), 1150.0, radius * 2.5),
        ("Fill", center + Vector((radius * 2.2, -radius * 1.0, radius * 1.3)), 650.0, radius * 2.0),
        ("Rim", center + Vector((radius * 0.8, radius * 2.2, radius * 2.2)), 900.0, radius * 1.7),
    ):
        light_data = bpy.data.lights.new(name=name, type="AREA")
        light_data.energy = energy
        light_data.shape = "DISK"
        light_data.size = area_size
        light = bpy.data.objects.new(name, light_data)
        bpy.context.collection.objects.link(light)
        light.location = location
        point_at(light, center)

    return camera


def render_views(camera: bpy.types.Object, center: Vector, bounds_min: Vector, bounds_max: Vector) -> None:
    # Hunyuan output orientation is discovered from bounds: longest horizontal
    # extent is treated as body front/back, the narrower extent as side depth.
    size = bounds_max - bounds_min
    distance = max(size.x, size.y, size.z) * 3.0
    if size.x >= size.y:
        views = {
            "front": center + Vector((-distance, 0.0, size.z * 0.08)),
            "side": center + Vector((0.0, -distance, size.z * 0.08)),
            "back": center + Vector((distance, 0.0, size.z * 0.08)),
        }
    else:
        views = {
            "front": center + Vector((0.0, -distance, size.z * 0.08)),
            "side": center + Vector((distance, 0.0, size.z * 0.08)),
            "back": center + Vector((0.0, distance, size.z * 0.08)),
        }

    for name, location in views.items():
        camera.location = location
        point_at(camera, center)
        bpy.context.scene.render.filepath = str(ASSET_DIR / f"preview_{name}.png")
        bpy.ops.render.render(write_still=True)


def main() -> None:
    clear_scene()
    bpy.ops.import_scene.gltf(filepath=str(GLB_PATH), import_shading="NORMALS")
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"No meshes imported from {GLB_PATH}")

    bounds_min, bounds_max = world_bounds(meshes)
    report = {
        "source": GLB_PATH.name,
        "object_count": len(bpy.context.scene.objects),
        "mesh_object_count": len(meshes),
        "bounds_min": list(bounds_min),
        "bounds_max": list(bounds_max),
        "dimensions": list(bounds_max - bounds_min),
        "meshes": [mesh_report(obj) for obj in meshes],
    }
    REPORT_PATH.write_text(json.dumps(report, indent=2) + "\n")

    center = (bounds_min + bounds_max) * 0.5
    camera = configure_render(meshes, bounds_min, bounds_max)
    render_views(camera, center, bounds_min, bounds_max)
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
