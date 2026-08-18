#!/usr/bin/env python3
"""Build the P2-037 northern raptor gliding batch.

The preferred 3d-renderer image-to-3D route is recorded in the batch brief. This
fallback is intentionally deterministic and uses the same catalog proportions:
low-poly custom silhouettes, physically based feather materials, hooked beaks,
separated primary feathers, and an eight-frame wing flap cycle.

Run from the repository root with Blender 5.x:
    blender --background --factory-startup --python generated/comfyui/bird_raptor_v1/production/generate_raptors.py
"""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[4]
BATCH_DIR = ROOT / "generated" / "comfyui" / "bird_raptor_v1"
OUTPUT_DIR = ROOT / "assets" / "birds"
PREVIEW_DIR = BATCH_DIR / "previews"
FLAP_KEYFRAMES = (-0.62, -0.30, 0.0, 0.42, 0.72, 0.42, 0.0, -0.30)
TEXTURE_SIZE = 16
GENERATOR_VERSION = "bird_raptor_v1"

# Dimensions are authored in metres and follow the catalog's relative scale.
# The eagle's 2.45 m span is deliberately largest, while the kestrel remains a
# compact silhouette at the same catalog scale used by MapViewBirdSpecies.
SPECIES = {
    "white_tailed_eagle": {
        "scale_m": 0.86,
        "wingspan": 2.45,
        "body": (0.90, 0.34, 0.38),
        "head": 0.19,
        "neck": 0.11,
        "tail": 0.46,
        "beak": 0.18,
        "colors": {
            "body": (0.29, 0.24, 0.19, 1.0),
            "wing": (0.16, 0.14, 0.12, 1.0),
            "head": (0.52, 0.48, 0.39, 1.0),
            "tail": (0.88, 0.84, 0.73, 1.0),
            "beak": (0.82, 0.62, 0.20, 1.0),
            "leg": (0.68, 0.48, 0.17, 1.0),
            "eye": (0.015, 0.012, 0.008, 1.0),
        },
        "wing_chord": 0.42,
        "tail_fan": 0.30,
    },
    "osprey": {
        "scale_m": 0.58,
        "wingspan": 1.78,
        "body": (0.63, 0.27, 0.30),
        "head": 0.15,
        "neck": 0.08,
        "tail": 0.34,
        "beak": 0.15,
        "colors": {
            "body": (0.61, 0.55, 0.43, 1.0),
            "wing": (0.19, 0.18, 0.16, 1.0),
            "head": (0.83, 0.79, 0.68, 1.0),
            "tail": (0.70, 0.65, 0.53, 1.0),
            "beak": (0.72, 0.48, 0.12, 1.0),
            "leg": (0.57, 0.42, 0.16, 1.0),
            "eye": (0.012, 0.010, 0.008, 1.0),
        },
        "wing_chord": 0.36,
        "tail_fan": 0.24,
    },
    "common_buzzard": {
        "scale_m": 0.54,
        "wingspan": 1.58,
        "body": (0.58, 0.28, 0.31),
        "head": 0.16,
        "neck": 0.07,
        "tail": 0.31,
        "beak": 0.14,
        "colors": {
            "body": (0.39, 0.29, 0.20, 1.0),
            "wing": (0.23, 0.18, 0.14, 1.0),
            "head": (0.47, 0.38, 0.28, 1.0),
            "tail": (0.57, 0.46, 0.33, 1.0),
            "beak": (0.66, 0.49, 0.18, 1.0),
            "leg": (0.54, 0.38, 0.16, 1.0),
            "eye": (0.012, 0.009, 0.006, 1.0),
        },
        "wing_chord": 0.39,
        "tail_fan": 0.26,
    },
    "common_kestrel": {
        "scale_m": 0.34,
        "wingspan": 1.08,
        "body": (0.44, 0.22, 0.23),
        "head": 0.125,
        "neck": 0.05,
        "tail": 0.40,
        "beak": 0.105,
        "colors": {
            "body": (0.56, 0.28, 0.15, 1.0),
            "wing": (0.29, 0.24, 0.20, 1.0),
            "head": (0.45, 0.43, 0.39, 1.0),
            "tail": (0.61, 0.39, 0.20, 1.0),
            "beak": (0.55, 0.39, 0.11, 1.0),
            "leg": (0.57, 0.40, 0.15, 1.0),
            "eye": (0.012, 0.009, 0.006, 1.0),
        },
        "wing_chord": 0.29,
        "tail_fan": 0.31,
    },
}
MATERIAL_NAMES = ("body", "wing", "head", "tail", "beak", "leg", "eye")


def _reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _new_face(
    bm: bmesh.types.BMesh,
    points: list[Vector | bmesh.types.BMVert],
    material_index: int,
) -> None:
    # BMesh faces must reuse existing BMVert instances; only Vector points need
    # to be inserted here. Reusing vertices keeps ellipsoid/tube caps manifold.
    vertices = [point if isinstance(point, bmesh.types.BMVert) else bm.verts.new(point) for point in points]
    face = bm.faces.new(vertices)
    face.material_index = material_index


def _add_ellipsoid(
    bm: bmesh.types.BMesh,
    center: Vector,
    radii: Vector,
    material_index: int,
    segments: int = 10,
    rings: int = 5,
) -> None:
    top = bm.verts.new(center + Vector((0.0, 0.0, radii.z)))
    bottom = bm.verts.new(center - Vector((0.0, 0.0, radii.z)))
    ring_vertices: list[list[bmesh.types.BMVert]] = []
    for ring_index in range(1, rings):
        pitch = math.pi * (ring_index / rings - 0.5)
        ring_r = math.cos(pitch)
        z = math.sin(pitch) * radii.z
        ring: list[bmesh.types.BMVert] = []
        for segment_index in range(segments):
            yaw = math.tau * segment_index / segments
            ring.append(
                bm.verts.new(
                    center
                    + Vector(
                        (
                            math.cos(yaw) * radii.x * ring_r,
                            math.sin(yaw) * radii.y * ring_r,
                            z,
                        )
                    )
                )
            )
        ring_vertices.append(ring)
    for segment_index in range(segments):
        next_index = (segment_index + 1) % segments
        _new_face(
            bm,
            [top, ring_vertices[0][segment_index], ring_vertices[0][next_index]],
            material_index,
        )
        _new_face(
            bm,
            [bottom, ring_vertices[-1][next_index], ring_vertices[-1][segment_index]],
            material_index,
        )
    for ring_index in range(len(ring_vertices) - 1):
        first = ring_vertices[ring_index]
        second = ring_vertices[ring_index + 1]
        for segment_index in range(segments):
            next_index = (segment_index + 1) % segments
            _new_face(
                bm,
                [first[segment_index], second[segment_index], second[next_index], first[next_index]],
                material_index,
            )


def _add_tube(
    bm: bmesh.types.BMesh,
    start: Vector,
    end: Vector,
    radius: float,
    material_index: int,
    segments: int = 5,
) -> None:
    direction = (end - start).normalized()
    helper = Vector((0.0, 0.0, 1.0))
    if abs(direction.dot(helper)) > 0.9:
        helper = Vector((0.0, 1.0, 0.0))
    side = direction.cross(helper).normalized() * radius
    up = direction.cross(side).normalized() * radius
    start_ring = [start + side * math.cos(math.tau * i / segments) + up * math.sin(math.tau * i / segments) for i in range(segments)]
    end_ring = [end + side * math.cos(math.tau * i / segments) + up * math.sin(math.tau * i / segments) for i in range(segments)]
    for index in range(segments):
        next_index = (index + 1) % segments
        _new_face(bm, [start_ring[index], end_ring[index], end_ring[next_index], start_ring[next_index]], material_index)
    _new_face(bm, [start, *reversed(start_ring)], material_index)
    _new_face(bm, [end, *end_ring], material_index)


def _add_wing(
    bm: bmesh.types.BMesh,
    spec: dict,
    side: float,
    lift: float,
    material_index: int,
) -> None:
    body_length, body_width, body_height = spec["body"]
    half_span = spec["wingspan"] * 0.5
    chord = spec["wing_chord"]
    body_center = Vector((0.0, 0.0, body_height * 0.72))
    shoulder = body_center + Vector((side * body_width * 0.38, -body_length * 0.03, body_height * 0.17))
    # Progressive lift makes the elbow and primaries articulate rather than
    # translating a flat card, which keeps the flap cycle readable in flight.
    lift_z = lift * chord * 0.62
    elbow = shoulder + Vector((side * half_span * 0.31, -chord * 0.04, lift_z * 0.78))
    wrist = shoulder + Vector((side * half_span * 0.66, chord * 0.02, lift_z * 1.04))
    tip = shoulder + Vector((side * half_span, chord * 0.10, lift_z * 1.16))
    rear_shoulder = shoulder + Vector((0.0, chord * 0.78, -chord * 0.08))
    rear_elbow = elbow + Vector((-side * half_span * 0.035, chord * 0.72, -chord * 0.10))
    rear_wrist = wrist + Vector((-side * half_span * 0.055, chord * 0.57, -chord * 0.13))
    rear_tip = tip + Vector((-side * half_span * 0.12, chord * 0.36, -chord * 0.08))
    _new_face(bm, [shoulder, elbow, rear_elbow, rear_shoulder], material_index)
    _new_face(bm, [elbow, wrist, rear_wrist, rear_elbow], material_index)
    _new_face(bm, [wrist, tip, rear_tip, rear_wrist], material_index)

    # Five separated primary feathers create a hooked, fingered wingtip.
    for feather_index in range(5):
        t = feather_index / 5.0
        base = wrist.lerp(tip, 0.15 + t * 0.62).lerp(rear_wrist.lerp(rear_tip, 0.15 + t * 0.62), 0.23)
        feather_tip = tip + Vector(
            (-side * half_span * t * 0.11, chord * (0.10 + t * 0.08), lift_z * (0.06 + t * 0.15))
        )
        width = max(chord * (0.12 - t * 0.025), 0.012)
        feather_side = (feather_tip - base).cross(Vector((0.0, 1.0, 0.0)))
        if feather_side.length < 1e-6:
            feather_side = Vector((side, 0.0, 0.0))
        feather_side.normalize()
        feather_side *= width
        _new_face(bm, [base - feather_side, base + feather_side, feather_tip], material_index)


def _add_hooked_beak(bm: bmesh.types.BMesh, head: Vector, head_radius: float, beak_length: float, material_index: int) -> None:
    base_y = head.y - head_radius * 0.70
    base = [
        Vector((-head_radius * 0.30, base_y, head.z + head_radius * 0.18)),
        Vector((head_radius * 0.30, base_y, head.z + head_radius * 0.18)),
        Vector((head_radius * 0.27, base_y, head.z - head_radius * 0.20)),
        Vector((-head_radius * 0.27, base_y, head.z - head_radius * 0.20)),
    ]
    mid = Vector((0.0, base_y - beak_length * 0.70, head.z - head_radius * 0.09))
    hook = Vector((0.0, base_y - beak_length, head.z - head_radius * 0.42))
    _new_face(bm, [base[0], base[1], mid], material_index)
    _new_face(bm, [base[1], base[2], mid], material_index)
    _new_face(bm, [base[2], base[3], mid], material_index)
    _new_face(bm, [base[3], base[0], mid], material_index)
    _new_face(bm, [mid, hook, base[2]], material_index)
    _new_face(bm, [mid, base[3], hook], material_index)


def _add_tail_fan(bm: bmesh.types.BMesh, spec: dict, material_index: int) -> None:
    body_length, body_width, body_height = spec["body"]
    root = Vector((0.0, body_length * 0.43, body_height * 0.72))
    tip_center = root + Vector((0.0, spec["tail"], -body_height * 0.08))
    fan_width = body_width * spec["tail_fan"] * 1.7
    # Five rectrices overlap at the root and fan out toward the trailing edge.
    for feather_index in range(5):
        offset = feather_index - 2
        feather_root = root + Vector((offset * fan_width * 0.16, 0.0, abs(offset) * 0.008))
        feather_tip = tip_center + Vector((offset * fan_width * 0.43, 0.0, -abs(offset) * 0.018))
        rear_root = feather_root + Vector((0.0, body_width * 0.23, -body_height * 0.06))
        rear_tip = feather_tip + Vector((0.0, body_width * 0.07, -body_height * 0.03))
        _new_face(bm, [feather_root, feather_tip, rear_tip, rear_root], material_index)


def _build_mesh(spec: dict, lift: float) -> bpy.types.Object:
    body_length, body_width, body_height = spec["body"]
    body_center = Vector((0.0, 0.0, body_height * 0.72))
    bm = bmesh.new()
    _add_ellipsoid(bm, body_center, Vector((body_width * 0.56, body_length * 0.50, body_height * 0.50)), 0)

    neck = body_center + Vector((0.0, -body_length * 0.30, body_height * 0.16))
    _add_ellipsoid(bm, neck, Vector((body_width * 0.28, spec["neck"] * 0.62, spec["neck"] * 0.72)), 2)
    head = neck + Vector((0.0, -body_length * 0.19, body_height * 0.08))
    _add_ellipsoid(bm, head, Vector((spec["head"] * 0.78, spec["head"] * 0.82, spec["head"])), 2, segments=8, rings=4)
    _add_hooked_beak(bm, head, spec["head"], spec["beak"], 4)

    # Eyes are separate low-poly dark beads so the hooked profile remains legible.
    for side in (-1.0, 1.0):
        _add_ellipsoid(
            bm,
            head + Vector((side * spec["head"] * 0.67, -spec["head"] * 0.58, spec["head"] * 0.20)),
            Vector((0.018, 0.012, 0.018)),
            6,
            segments=6,
            rings=3,
        )

    _add_wing(bm, spec, -1.0, lift, 1)
    _add_wing(bm, spec, 1.0, lift, 1)
    _add_tail_fan(bm, spec, 3)

    # Tucked talons remain visible under a gliding raptor without becoming legs
    # that read as a standing pose.
    for side in (-1.0, 1.0):
        hip = body_center + Vector((side * body_width * 0.25, body_length * 0.02, -body_height * 0.32))
        ankle = hip + Vector((side * body_width * 0.04, -body_length * 0.03, -body_height * 0.18))
        _add_tube(bm, hip, ankle, max(body_height * 0.045, 0.006), 5, segments=5)
        for talon in (-1.0, 0.0, 1.0):
            toe = ankle + Vector((talon * body_width * 0.10, -body_width * 0.05, -body_height * 0.05))
            _add_tube(bm, ankle, toe, max(body_height * 0.018, 0.003), 5, segments=4)

    mesh = bpy.data.meshes.new("RaptorMesh")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("RaptorBody", mesh)
    bpy.context.collection.objects.link(obj)
    for vertex in mesh.vertices:
        vertex.co.z -= min(v.co.z for v in mesh.vertices)
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    _uv_smart_project(obj)
    return obj


def _uv_smart_project(obj: bpy.types.Object) -> None:
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.select_set(False)


def _make_image(name: str, color: tuple[float, float, float, float], *, colorspace: str) -> bpy.types.Image:
    image = bpy.data.images.new(name, TEXTURE_SIZE, TEXTURE_SIZE, alpha=True)
    pixels = list(color) * (TEXTURE_SIZE * TEXTURE_SIZE)
    image.pixels.foreach_set(pixels)
    image.colorspace_settings.name = colorspace
    image.file_format = "PNG"
    image.pack()
    return image


def _make_materials(species: str, spec: dict) -> list[bpy.types.Material]:
    materials: list[bpy.types.Material] = []
    for index, name in enumerate(MATERIAL_NAMES):
        base = spec["colors"][name]
        material = bpy.data.materials.new(f"{species}_{name}_feathers")
        material.use_nodes = True
        nodes = material.node_tree.nodes
        links = material.node_tree.links
        nodes.clear()
        output = nodes.new("ShaderNodeOutputMaterial")
        bsdf = nodes.new("ShaderNodeBsdfPrincipled")
        bsdf.inputs["Metallic"].default_value = 0.0
        bsdf.inputs["Roughness"].default_value = 0.82 if name not in {"beak", "eye"} else 0.62
        albedo = _make_image(f"{species}_{name}_albedo", base, colorspace="sRGB")
        normal = _make_image(f"{species}_{name}_normal", (0.5, 0.5, 1.0, 1.0), colorspace="Non-Color")
        roughness = _make_image(f"{species}_{name}_roughness", (0.82, 0.82, 0.82, 1.0), colorspace="Non-Color")
        albedo_node = nodes.new("ShaderNodeTexImage")
        albedo_node.image = albedo
        normal_node = nodes.new("ShaderNodeTexImage")
        normal_node.image = normal
        roughness_node = nodes.new("ShaderNodeTexImage")
        roughness_node.image = roughness
        normal_map = nodes.new("ShaderNodeNormalMap")
        links.new(albedo_node.outputs["Color"], bsdf.inputs["Base Color"])
        links.new(roughness_node.outputs["Color"], bsdf.inputs["Roughness"])
        links.new(normal_node.outputs["Color"], normal_map.inputs["Color"])
        links.new(normal_map.outputs["Normal"], bsdf.inputs["Normal"])
        links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])
        material.diffuse_color = base
        materials.append(material)
    return materials


def _metrics(obj: bpy.types.Object) -> dict[str, object]:
    coords = [obj.matrix_world @ vertex.co for vertex in obj.data.vertices]
    dimensions = [max(axis) - min(axis) for axis in zip(*coords)]
    triangles = sum(max(len(polygon.vertices) - 2, 0) for polygon in obj.data.polygons)
    return {
        "triangles": triangles,
        "dimensions_m": [round(value, 4) for value in dimensions],
        "largest_axis_m": round(max(dimensions), 4),
        "ground_min_z": round(min(point.z for point in coords), 6),
    }


def _export(obj: bpy.types.Object, path: Path) -> dict[str, object]:
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=True,
        export_texcoords=True,
        export_normals=True,
        export_tangents=True,
        export_materials="EXPORT",
        export_image_format="AUTO",
        export_cameras=False,
        export_lights=False,
        export_animations=False,
    )
    result = _metrics(obj)
    result.update({"path": str(path.relative_to(ROOT)), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    return result


def _render_preview(obj: bpy.types.Object, path: Path) -> None:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 720
    scene.render.resolution_y = 480
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    if scene.world is None:
        scene.world = bpy.data.worlds.new(f"{obj.name}_PreviewWorld")
    scene.world.color = (0.035, 0.045, 0.055)
    bpy.ops.object.light_add(type="AREA", location=(-1.8, -2.5, 3.2))
    key = bpy.context.object
    key.data.energy = 650.0
    key.data.shape = "DISK"
    key.data.size = 3.0
    bpy.ops.object.light_add(type="AREA", location=(2.5, 1.0, 1.4))
    fill = bpy.context.object
    fill.data.energy = 280.0
    fill.data.size = 2.0
    dimensions = _metrics(obj)["dimensions_m"]
    span = max(float(value) for value in dimensions)
    bpy.ops.object.camera_add(location=(span * 0.95, -span * 1.35, span * 0.58))
    camera = bpy.context.object
    target = Vector((0.0, 0.0, span * 0.35))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = span * 1.25
    scene.camera = camera
    path.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    for helper in (camera, key, fill):
        bpy.data.objects.remove(helper, do_unlink=True)


def build_species(species: str, spec: dict) -> list[dict[str, object]]:
    _reset_scene()
    materials = _make_materials(species, spec)
    reports: list[dict[str, object]] = []
    for frame, lift in enumerate(FLAP_KEYFRAMES):
        if frame:
            _reset_scene()
            materials = _make_materials(species, spec)
        obj = _build_mesh(spec, lift)
        for material in materials:
            obj.data.materials.append(material)
        path = OUTPUT_DIR / species / f"gliding_{frame:02d}.glb"
        metrics = _export(obj, path)
        metrics.update({"species": species, "frame": frame, "wing_lift": lift})
        reports.append(metrics)
        if frame == 2:
            neutral_path = OUTPUT_DIR / species / "gliding.glb"
            neutral_path.write_bytes(path.read_bytes())
            reports.append({**metrics, "path": str(neutral_path.relative_to(ROOT)), "frame": "neutral"})
            _render_preview(obj, PREVIEW_DIR / f"{species}_gliding.png")
    return reports


def main() -> int:
    BATCH_DIR.mkdir(parents=True, exist_ok=True)
    all_reports: list[dict[str, object]] = []
    for species, spec in SPECIES.items():
        print(f"Building {species}...", flush=True)
        all_reports.extend(build_species(species, spec))
    report = {
        "generator": GENERATOR_VERSION,
        "route": "deterministic_blender_guided_by_reference",
        "species": list(SPECIES),
        "flap_keyframes": list(FLAP_KEYFRAMES),
        "assets": all_reports,
    }
    (BATCH_DIR / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    (BATCH_DIR / "state.json").write_text(
        json.dumps(
            {
                "asset_id": "fauna.raptor_gliding_batch",
                "stage": "production_ready",
                "generator": GENERATOR_VERSION,
                "blender_version": bpy.app.version_string,
                "note": "Image-to-3D renderer route was unavailable; deterministic custom GLBs preserve the approved catalog silhouette contract.",
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"ASSET_BATCH={len(all_reports)} report={BATCH_DIR / 'report.json'}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
