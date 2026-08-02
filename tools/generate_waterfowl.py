#!/usr/bin/env python3
"""Deterministic standing waterfowl GLBs for P2-035.

Hunyuan3D image-to-3D was unavailable in this environment, so production meshes
are built from MapViewBirdSpecies catalog proportions with PBR feather maps.
Long-neck overrides (swan, goose, cormorant) come from the species geometry
table. Reference plates under generated/comfyui/bird_waterfowl_v1/ document
silhouettes; an optional Hunyuan candidate pass remains a follow-up.

Run from the repository root:
    blender --background --factory-startup --python tools/generate_waterfowl.py
"""

from __future__ import annotations

import hashlib
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE_DIR = ROOT / "generated" / "comfyui" / "bird_waterfowl_v1"
BIRDS_DIR = ROOT / "assets" / "birds"
REPORTS_DIR = ROOT / "docs" / "reports" / "images" / "fauna"
BLENDER_VERSION = "Blender 5.2 LTS"
GENERATOR_VERSION = "waterfowl_v3_mallard"
TEXTURE_SIZE = 256

# Catalog geometry mirrors scripts/map/view3d/map_view_bird_species.gd
# (GROUP_WATERFOWL defaults + per-species overrides).
SPECIES = {
    "mute_swan": {
        "scale_m": 1.45,
        "body": (0.72, 0.32, 0.38),
        "head": 0.13,
        "wing_span": 1.10,
        "wing_chord": 0.42,
        "tail": 0.18,
        "beak": 0.25,
        "neck": 0.72,
        "legs": 0.17,
        "neck_curve": 0.55,
        "colors": ((0xE8, 0xE5, 0xDC), (0xD8, 0xD5, 0xCC), (0xD7, 0x7A, 0x36)),
        "cap": None,
        "breast": None,
    },
    "mallard": {
        "scale_m": 0.56,
        "body": (0.62, 0.30, 0.34),
        "head": 0.16,
        "wing_span": 1.10,
        "wing_chord": 0.42,
        "tail": 0.18,
        "beak": 0.26,
        "neck": 0.13,
        "legs": 0.17,
        "neck_curve": 0.12,
        "colors": ((0x76, 0x6A, 0x4D), (0x33, 0x5B, 0x4D), (0xD3, 0xA4, 0x42)),
        "cap": (0x33, 0x5B, 0x4D),
        "breast": (0x77, 0x50, 0x3A),
    },
    "greylag_goose": {
        "scale_m": 0.82,
        "body": (0.68, 0.31, 0.36),
        "head": 0.16,
        "wing_span": 1.10,
        "wing_chord": 0.42,
        "tail": 0.18,
        "beak": 0.22,
        "neck": 0.46,
        "legs": 0.17,
        "neck_curve": 0.28,
        "colors": ((0x93, 0x8D, 0x7C), (0x6F, 0x71, 0x68), (0xD6, 0x8C, 0x4C)),
        "cap": None,
        "breast": None,
    },
    "great_cormorant": {
        "scale_m": 0.88,
        "body": (0.58, 0.25, 0.28),
        "head": 0.16,
        "wing_span": 1.10,
        "wing_chord": 0.42,
        "tail": 0.30,
        "beak": 0.29,
        "neck": 0.52,
        "legs": 0.17,
        "neck_curve": 0.18,
        "colors": ((0x25, 0x2B, 0x2B), (0x15, 0x19, 0x1A), (0xC9, 0xA8, 0x5B)),
        "cap": None,
        "breast": None,
    },
}


def _srgb_to_linear(channel: float) -> float:
    if channel <= 0.04045:
        return channel / 12.92
    return ((channel + 0.055) / 1.055) ** 2.4


def _hex_to_linear(rgb: tuple[int, int, int]) -> tuple[float, float, float]:
    return tuple(_srgb_to_linear(c / 255.0) for c in rgb)


def _reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _scale_factor(spec: dict) -> float:
    return float(spec["scale_m"]) / max(float(spec["body"][0]), 0.01)


def _create_feather_maps(
    species: str,
    body_srgb: tuple[int, int, int],
    wing_srgb: tuple[int, int, int],
    breast_srgb: tuple[int, int, int] | None,
) -> dict[str, bpy.types.Image]:
    size = TEXTURE_SIZE
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    u = xx / float(size)
    v = yy / float(size)
    body = np.array([c / 255.0 for c in body_srgb], dtype=np.float32)
    wing = np.array([c / 255.0 for c in wing_srgb], dtype=np.float32)
    wing_mask = np.clip((u - 0.48) * 2.8 + 0.12 * np.sin(v * math.tau * 2.0), 0.0, 1.0)
    breast_mask = np.clip((0.42 - v) * 3.5, 0.0, 1.0) * (1.0 - wing_mask)
    feather = 0.5 + 0.5 * np.sin((u * 26.0 + v * 5.0) * math.tau)
    mix = body * (1.0 - wing_mask)[:, :, None] + wing * wing_mask[:, :, None]
    if breast_srgb is not None:
        breast = np.array([c / 255.0 for c in breast_srgb], dtype=np.float32)
        mix = mix * (1.0 - breast_mask)[:, :, None] + breast * breast_mask[:, :, None]
    mix *= 0.92 + 0.08 * feather[:, :, None]
    alpha = np.ones((size, size, 1), dtype=np.float32)
    albedo_pixels = np.concatenate((mix, alpha), axis=2).ravel()

    albedo = bpy.data.images.new(f"{species}_albedo", size, size, alpha=False)
    albedo.pixels.foreach_set(albedo_pixels.tolist())
    albedo.colorspace_settings.name = "sRGB"
    albedo.file_format = "PNG"
    albedo.pack()

    height = (0.45 + 0.18 * feather + 0.08 * np.sin((v * 18.0 - u * 3.0) * math.tau)).astype(np.float32)
    dx = np.gradient(height, axis=1)
    dy = np.gradient(height, axis=0)
    nx = -dx * 4.0
    ny = -dy * 4.0
    nz = np.ones_like(height)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    nx, ny, nz = nx / length, ny / length, nz / length
    normal_rgb = np.stack(((nx + 1.0) * 0.5, (ny + 1.0) * 0.5, (nz + 1.0) * 0.5), axis=2)
    normal = bpy.data.images.new(f"{species}_normal", size, size, alpha=False)
    normal.pixels.foreach_set(np.concatenate((normal_rgb, alpha), axis=2).ravel().tolist())
    normal.colorspace_settings.name = "Non-Color"
    normal.file_format = "PNG"
    normal.pack()

    roughness_vals = 0.70 + 0.16 * (0.5 + 0.5 * feather)
    rough_rgb = np.repeat(roughness_vals[:, :, None], 3, axis=2)
    roughness = bpy.data.images.new(f"{species}_roughness", size, size, alpha=False)
    roughness.pixels.foreach_set(np.concatenate((rough_rgb, alpha), axis=2).ravel().tolist())
    roughness.colorspace_settings.name = "Non-Color"
    roughness.file_format = "PNG"
    roughness.pack()

    return {"albedo": albedo, "normal": normal, "roughness": roughness}


def _make_material(name: str, maps: dict[str, bpy.types.Image], base_rgb: tuple[float, float, float]) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = (*base_rgb, 1.0)
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Roughness"].default_value = 0.78
    tex_albedo = nodes.new("ShaderNodeTexImage")
    tex_albedo.image = maps["albedo"]
    tex_normal = nodes.new("ShaderNodeTexImage")
    tex_normal.image = maps["normal"]
    tex_rough = nodes.new("ShaderNodeTexImage")
    tex_rough.image = maps["roughness"]
    normal_map = nodes.new("ShaderNodeNormalMap")
    links.new(tex_albedo.outputs["Color"], bsdf.inputs["Base Color"])
    links.new(tex_rough.outputs["Color"], bsdf.inputs["Roughness"])
    links.new(tex_normal.outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], bsdf.inputs["Normal"])
    links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])
    return material


def _make_solid_material(name: str, color: tuple[int, int, int], roughness: float = 0.82) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*_hex_to_linear(color), 1.0)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    if bsdf is not None:
        bsdf.inputs["Base Color"].default_value = (*_hex_to_linear(color), 1.0)
        bsdf.inputs["Metallic"].default_value = 0.0
        bsdf.inputs["Roughness"].default_value = roughness
    return material


def _uv_smart_project(obj: bpy.types.Object) -> None:
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.select_set(False)


def _add_ellipsoid(
    bm: bmesh.types.BMesh,
    center: Vector,
    radii: Vector,
    segments: int = 10,
    rings: int = 6,
    material_index: int = 0,
) -> None:
    verts: list[bmesh.types.BMVert] = []
    for ring in range(rings + 1):
        v_t = ring / rings
        pitch = math.pi * (v_t - 0.5)
        y = math.sin(pitch) * radii.y
        ring_r = math.cos(pitch)
        for seg in range(segments):
            u_t = seg / segments
            yaw = u_t * math.tau
            x = math.cos(yaw) * radii.x * ring_r
            z = math.sin(yaw) * radii.z * ring_r
            verts.append(bm.verts.new(center + Vector((x, y, z))))
    bm.verts.ensure_lookup_table()
    for ring in range(rings):
        for seg in range(segments):
            a = ring * segments + seg
            b = ring * segments + ((seg + 1) % segments)
            c = (ring + 1) * segments + ((seg + 1) % segments)
            d = (ring + 1) * segments + seg
            face = bm.faces.new((verts[a], verts[b], verts[c], verts[d]))
            face.material_index = material_index


def _add_quad(
    bm: bmesh.types.BMesh,
    a: Vector,
    b: Vector,
    c: Vector,
    d: Vector,
    material_index: int = 0,
) -> None:
    va, vb, vc, vd = bm.verts.new(a), bm.verts.new(b), bm.verts.new(c), bm.verts.new(d)
    face = bm.faces.new((va, vb, vc, vd))
    face.material_index = material_index


def _add_tri(
    bm: bmesh.types.BMesh,
    a: Vector,
    b: Vector,
    c: Vector,
    material_index: int = 0,
) -> None:
    face = bm.faces.new((bm.verts.new(a), bm.verts.new(b), bm.verts.new(c)))
    face.material_index = material_index


def _add_wedge(
    bm: bmesh.types.BMesh,
    center: Vector,
    width: float,
    depth: float,
    height: float,
    material_index: int,
) -> None:
    """Low-poly broad duck bill with a blunt tip, rather than a pointed cone."""
    back_y = center.y + depth * 0.42
    front_y = center.y - depth * 0.58
    half_back = width * 0.50
    half_front = width * 0.39
    bottom = center.z - height * 0.52
    top = center.z + height * 0.48
    vertices = [
        Vector((-half_back, back_y, bottom)),
        Vector((half_back, back_y, bottom)),
        Vector((half_back, back_y, top)),
        Vector((-half_back, back_y, top)),
        Vector((-half_front, front_y, bottom * 0.92 + center.z * 0.08)),
        Vector((half_front, front_y, bottom * 0.92 + center.z * 0.08)),
        Vector((half_front, front_y, top * 0.92 + center.z * 0.08)),
        Vector((-half_front, front_y, top * 0.92 + center.z * 0.08)),
    ]
    # Translate the local wedge around the supplied center. The z blend above
    # keeps the bill slightly downturned without creating a needle-like beak.
    vertices = [Vector((v.x + center.x, v.y, v.z)) for v in vertices]
    for indices in ((0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (3, 2, 6, 7), (0, 3, 7, 4), (1, 5, 6, 2)):
        face = bm.faces.new(tuple(bm.verts.new(vertices[index]) for index in indices))
        face.material_index = material_index


def _add_goose_bill(
    bm: bmesh.types.BMesh,
    base: Vector,
    width: float,
    length: float,
    height: float,
    material_index: int,
) -> None:
    """Create a broad, blunt bill along the authored -Z forward axis."""
    rings = []
    for z_offset, ring_width, ring_height in (
        (0.0, width, height),
        (-length * 0.72, width * 0.72, height * 0.72),
        (-length, width * 0.32, height * 0.38),
    ):
        rings.append(
            [
                bm.verts.new(base + Vector((-ring_width * 0.5, ring_height * 0.5, z_offset))),
                bm.verts.new(base + Vector((ring_width * 0.5, ring_height * 0.5, z_offset))),
                bm.verts.new(base + Vector((ring_width * 0.5, -ring_height * 0.5, z_offset))),
                bm.verts.new(base + Vector((-ring_width * 0.5, -ring_height * 0.5, z_offset))),
            ]
        )
    for ring_index in range(len(rings) - 1):
        for corner in range(4):
            next_corner = (corner + 1) % 4
            face = bm.faces.new((rings[ring_index][corner], rings[ring_index][next_corner], rings[ring_index + 1][next_corner], rings[ring_index + 1][corner]))
            face.material_index = material_index
    cap = bm.faces.new(tuple(rings[-1]))
    cap.material_index = material_index




def _add_oriented_ellipsoid(
    bm: bmesh.types.BMesh,
    center: Vector,
    radii: Vector,
    axis: Vector,
    segments: int = 10,
    rings: int = 6,
    material_index: int = 0,
) -> None:
    """Add a smooth ellipsoid whose local Y axis follows ``axis``.

    The mallard's wing and tail feathers need a real volume and a readable grain
    direction. Rotating the primitive basis avoids the paper-thin triangle look
    of the previous asset while keeping the mesh deterministic and inexpensive.
    """
    along = axis.normalized()
    reference = Vector((0.0, 0.0, 1.0))
    if abs(along.dot(reference)) > 0.92:
        reference = Vector((0.0, 1.0, 0.0))
    basis_x = reference.cross(along).normalized()
    basis_z = along.cross(basis_x).normalized()
    verts: list[bmesh.types.BMVert] = []
    for ring in range(rings + 1):
        v_t = ring / rings
        pitch = math.pi * (v_t - 0.5)
        along_offset = math.sin(pitch) * radii.y
        ring_radius = math.cos(pitch)
        for seg in range(segments):
            yaw = seg / segments * math.tau
            local = (
                basis_x * (math.cos(yaw) * radii.x * ring_radius)
                + along * along_offset
                + basis_z * (math.sin(yaw) * radii.z * ring_radius)
            )
            verts.append(bm.verts.new(center + local))
    for ring in range(rings):
        for seg in range(segments):
            a = ring * segments + seg
            b = ring * segments + ((seg + 1) % segments)
            c = (ring + 1) * segments + ((seg + 1) % segments)
            d = (ring + 1) * segments + seg
            face = bm.faces.new((verts[a], verts[b], verts[c], verts[d]))
            face.material_index = material_index


def _build_mallard(spec: dict) -> bpy.types.Object:
    """Build a grounded, anatomically readable standing mallard from zero.

    This is intentionally not a recolour of the generic waterfowl mesh. The
    domestic mallard silhouette is driven by a low, pear-shaped torso, a short
    upright neck, a rounded green head, a broad spatulate bill, folded volumetric
    wings, a compact tail, and planted orange feet.
    """
    scale = (float(spec["scale_m"]) / 0.56) * 0.72
    bm = bmesh.new()

    MAT_BODY = 0
    MAT_BREAST = 1
    MAT_HEAD = 2
    MAT_WING = 3
    MAT_WHITE = 4
    MAT_BEAK = 5
    MAT_FEET = 6
    MAT_EYE = 7
    MAT_SPECULUM = 8

    # Body: broad at the shoulders, fuller through the belly, and slightly
    # tapered toward the rump. All dimensions remain in the 0.56 m catalog scale.
    body_center = Vector((0.0, 0.035 * scale, 0.235 * scale))
    _add_ellipsoid(
        bm,
        body_center,
        Vector((0.195 * scale, 0.335 * scale, 0.185 * scale)),
        segments=24,
        rings=14,
        material_index=MAT_BODY,
    )
    _add_oriented_ellipsoid(
        bm,
        Vector((0.0, -0.205 * scale, 0.225 * scale)),
        Vector((0.155 * scale, 0.115 * scale, 0.145 * scale)),
        Vector((0.0, -1.0, 0.0)),
        segments=14,
        rings=7,
        material_index=MAT_BREAST,
    )

    # The white collar is a shallow, rounded ring between brown breast and green
    # neck. The green neck is kept short, as on a real domestic mallard.
    _add_ellipsoid(
        bm,
        Vector((0.0, -0.155 * scale, 0.405 * scale)),
        Vector((0.090 * scale, 0.073 * scale, 0.028 * scale)),
        segments=14,
        rings=5,
        material_index=MAT_WHITE,
    )
    _add_oriented_ellipsoid(
        bm,
        Vector((0.0, -0.178 * scale, 0.445 * scale)),
        Vector((0.072 * scale, 0.075 * scale, 0.068 * scale)),
        Vector((0.0, 0.03, 1.0)),
        segments=12,
        rings=6,
        material_index=MAT_HEAD,
    )
    head_center = Vector((0.0, -0.235 * scale, 0.535 * scale))
    _add_ellipsoid(
        bm,
        head_center,
        Vector((0.125 * scale, 0.115 * scale, 0.130 * scale)),
        segments=16,
        rings=9,
        material_index=MAT_HEAD,
    )

    # Broad, slightly downturned bill. A second lower section makes the bill read
    # as a duck bill rather than a pointed cone from the isometric camera.
    _add_wedge(
        bm,
        Vector((0.0, -0.350 * scale, 0.515 * scale)),
        width=0.118 * scale,
        depth=0.145 * scale,
        height=0.052 * scale,
        material_index=MAT_BEAK,
    )
    _add_ellipsoid(
        bm,
        Vector((0.0, -0.372 * scale, 0.497 * scale)),
        Vector((0.051 * scale, 0.054 * scale, 0.012 * scale)),
        segments=10,
        rings=4,
        material_index=MAT_BEAK,
    )
    for side in (-1.0, 1.0):
        _add_ellipsoid(
            bm,
            Vector((side * 0.092 * scale, -0.318 * scale, 0.565 * scale)),
            Vector((0.015 * scale, 0.010 * scale, 0.015 * scale)),
            segments=8,
            rings=4,
            material_index=MAT_EYE,
        )

    # Folded wings are full, asymmetric-looking flank volumes. The visible outer
    # side gets a teal speculum inset and two narrow white border feathers.
    for side in (-1.0, 1.0):
        wing_outer = side * 0.190 * scale
        _add_oriented_ellipsoid(
            bm,
            Vector((wing_outer, 0.045 * scale, 0.245 * scale)),
            Vector((0.058 * scale, 0.235 * scale, 0.145 * scale)),
            Vector((0.0, -0.94, -0.18)),
            segments=14,
            rings=7,
            material_index=MAT_WING,
        )
        patch_x = side * 0.246 * scale
        _add_oriented_ellipsoid(
            bm,
            Vector((patch_x, -0.015 * scale, 0.235 * scale)),
            Vector((0.010 * scale, 0.105 * scale, 0.050 * scale)),
            Vector((0.0, -0.98, -0.08)),
            segments=10,
            rings=5,
            material_index=MAT_SPECULUM,
        )
        for y, z in ((-0.120, 0.235), (0.105, 0.265)):
            _add_oriented_ellipsoid(
                bm,
                Vector((patch_x + side * 0.002 * scale, y * scale, z * scale)),
                Vector((0.012 * scale, 0.020 * scale, 0.058 * scale)),
                Vector((0.0, -0.98, -0.08)),
                segments=8,
                rings=4,
                material_index=MAT_WHITE,
            )

    # Three rounded tail feathers overlap at the rump and angle upward gently.
    for side, y_offset, z_offset in ((-1.0, 0.0, 0.0), (0.0, 0.018, 0.012), (1.0, 0.0, 0.0)):
        _add_oriented_ellipsoid(
            bm,
            Vector((side * 0.050 * scale, 0.345 * scale + y_offset * scale, 0.275 * scale + z_offset * scale)),
            Vector((0.050 * scale, 0.145 * scale, 0.040 * scale)),
            Vector((0.0, 0.94, 0.34)),
            segments=9,
            rings=5,
            material_index=MAT_WING,
        )

    # Bent orange legs and broad three-lobed webbed feet visibly support the body.
    for side in (-1.0, 1.0):
        hip = Vector((side * 0.105 * scale, -0.020 * scale, 0.155 * scale))
        knee = Vector((side * 0.098 * scale, -0.040 * scale, 0.090 * scale))
        ankle = Vector((side * 0.097 * scale, -0.085 * scale, 0.035 * scale))
        _add_oriented_ellipsoid(
            bm,
            hip.lerp(knee, 0.5),
            Vector((0.020 * scale, 0.032 * scale, 0.020 * scale)),
            knee - hip,
            7,
            4,
            MAT_FEET,
        )
        _add_oriented_ellipsoid(
            bm,
            knee.lerp(ankle, 0.5),
            Vector((0.016 * scale, 0.030 * scale, 0.016 * scale)),
            ankle - knee,
            7,
            4,
            MAT_FEET,
        )
        foot = Vector((side * 0.097 * scale, -0.118 * scale, 0.015 * scale))
        _add_ellipsoid(
            bm,
            foot,
            Vector((0.052 * scale, 0.082 * scale, 0.014 * scale)),
            segments=10,
            rings=4,
            material_index=MAT_FEET,
        )
        for toe_x in (-0.030, 0.0, 0.030):
            _add_ellipsoid(
                bm,
                foot + Vector((toe_x * scale, -0.052 * scale, 0.004 * scale)),
                Vector((0.018 * scale, 0.050 * scale, 0.008 * scale)),
                segments=7,
                rings=3,
                material_index=MAT_FEET,
            )

    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    mesh = bpy.data.meshes.new("MallardMesh")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("MallardBody", mesh)
    bpy.context.collection.objects.link(obj)
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    obj.select_set(False)
    return obj


def _build_standing_bird(spec: dict) -> bpy.types.Object:
    """Standing waterfowl: grounded legs, folded wings, catalog neck length."""
    scale = _scale_factor(spec)
    body = Vector(spec["body"]) * scale
    body_radius = Vector((body.z, body.y, body.x)) * 0.5
    head_r = float(spec["head"]) * scale
    neck_len = float(spec["neck"]) * scale
    neck_curve = float(spec["neck_curve"]) * scale
    leg_len = float(spec["legs"]) * scale
    beak_len = float(spec["beak"]) * scale
    wing_chord = float(spec["wing_chord"]) * scale
    tail_len = float(spec["tail"]) * scale

    bm = bmesh.new()
    # Author in Y-up / Z-forward, then rotate into Blender Z-up like harbour gulls.
    body_center = Vector((0.0, leg_len + body_radius.y * 1.05, 0.0))
    _add_ellipsoid(bm, body_center, body_radius, segments=10, rings=6)

    # S-curve neck toward -Z (forward): rise, then tip forward for swan/goose.
    neck_base = body_center + Vector((0.0, body_radius.y * 0.55, -body_radius.z * 0.55))
    neck_mid = neck_base + Vector((0.0, neck_len * 0.55 + neck_curve * 0.35, -neck_len * 0.18))
    neck_end = neck_mid + Vector((0.0, neck_len * 0.25 - neck_curve * 0.15, -neck_len * 0.55 - neck_curve * 0.35))
    for point, radius in (
        (neck_base.lerp(neck_mid, 0.35), head_r * 0.55),
        (neck_mid, head_r * 0.48),
        (neck_mid.lerp(neck_end, 0.55), head_r * 0.42),
    ):
        _add_ellipsoid(bm, point, Vector((radius * 0.85, radius * 1.05, radius * 0.85)), segments=7, rings=4)

    head_center = neck_end + Vector((0.0, head_r * 0.35, -head_r * 0.15))
    _add_ellipsoid(bm, head_center, Vector((head_r * 0.90, head_r, head_r * 0.95)), segments=8, rings=5)

    if spec.get("cap"):
        _add_ellipsoid(
            bm,
            head_center + Vector((0.0, head_r * 0.28, -head_r * 0.05)),
            Vector((head_r * 0.82, head_r * 0.48, head_r * 0.78)),
            segments=8,
            rings=3,
        )

    beak_tip = head_center + Vector((0.0, -head_r * 0.05, -head_r - beak_len))
    beak_base_l = head_center + Vector((-head_r * 0.24, -head_r * 0.04, -head_r * 0.72))
    beak_base_r = head_center + Vector((head_r * 0.24, -head_r * 0.04, -head_r * 0.72))
    beak_base_t = head_center + Vector((0.0, head_r * 0.10, -head_r * 0.68))
    _add_tri(bm, beak_base_l, beak_base_t, beak_tip)
    _add_tri(bm, beak_base_t, beak_base_r, beak_tip)
    _add_tri(bm, beak_base_r, beak_base_l, beak_tip)

    # Folded wings: short slabs along the flanks (not a glide span).
    fold_span = body_radius.x * 1.15
    for side in (-1.0, 1.0):
        shoulder = body_center + Vector((side * body_radius.x * 0.72, body_radius.y * 0.18, -body_radius.z * 0.05))
        tip = shoulder + Vector((side * fold_span * 0.35, -body_radius.y * 0.55, body_radius.z * 0.55))
        rear = tip + Vector((-side * fold_span * 0.08, -body_radius.y * 0.08, wing_chord * 0.35))
        front = shoulder + Vector((side * fold_span * 0.05, body_radius.y * 0.05, -wing_chord * 0.22))
        _add_quad(bm, shoulder, front, tip, rear)
        mid = shoulder.lerp(tip, 0.55)
        _add_tri(
            bm,
            mid,
            tip,
            tip + Vector((-side * fold_span * 0.12, -body_radius.y * 0.12, wing_chord * 0.18)),
        )

    # Tail fan.
    tail_root = body_center + Vector((0.0, body_radius.y * 0.05, body_radius.z * 0.92))
    tip = tail_root + Vector((0.0, -body_radius.y * 0.05, tail_len))
    left = tail_root + Vector((-tail_len * 0.22, 0.0, tail_len * 0.40))
    right = tail_root + Vector((tail_len * 0.22, 0.0, tail_len * 0.40))
    _add_tri(bm, left, right, tip)

    # Standing legs and webbed feet.
    for side in (-1.0, 1.0):
        hip = body_center + Vector((side * body_radius.x * 0.32, -body_radius.y * 0.72, body_radius.z * 0.05))
        ankle = Vector((side * body_radius.x * 0.30, leg_len * 0.18, body_radius.z * 0.02))
        foot = Vector((side * body_radius.x * 0.30, 0.0, -leg_len * 0.08))
        _add_ellipsoid(bm, hip.lerp(ankle, 0.45), Vector((0.014, leg_len * 0.32, 0.014)), segments=5, rings=3)
        _add_ellipsoid(bm, ankle.lerp(foot, 0.45), Vector((0.012, leg_len * 0.18, 0.012)), segments=5, rings=3)
        # Simple web footprint.
        _add_tri(
            bm,
            foot + Vector((-0.018, 0.004, -0.010)),
            foot + Vector((0.018, 0.004, -0.010)),
            foot + Vector((0.0, 0.004, -0.045)),
        )

    mesh = bpy.data.meshes.new("BirdMesh")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("BirdBody", mesh)
    bpy.context.collection.objects.link(obj)

    obj.rotation_euler = (math.radians(-90.0), 0.0, 0.0)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)

    coords = [obj.matrix_world @ Vector(v.co) for v in obj.data.vertices]
    min_z = min(c.z for c in coords)
    obj.location.z -= min_z
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    obj.select_set(False)
    return obj


def _mesh_metrics(obj: bpy.types.Object) -> dict[str, object]:
    coords = [obj.matrix_world @ Vector(v.co) for v in obj.data.vertices]
    xs = [c.x for c in coords]
    ys = [c.y for c in coords]
    zs = [c.z for c in coords]
    triangles = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    return {
        "triangles": triangles,
        "dimensions_m": [
            round(max(xs) - min(xs), 4),
            round(max(zs) - min(zs), 4),
            round(max(ys) - min(ys), 4),
        ],
        "largest_axis_m": round(max(max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)), 4),
        "ground_min_z": round(min(zs), 6),
    }


def _export_glb(obj: bpy.types.Object, path: Path) -> dict[str, object]:
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
    metrics = _mesh_metrics(obj)
    metrics["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
    metrics["path"] = str(path.relative_to(ROOT))
    return metrics


def _render_species_preview(obj: bpy.types.Object, path: Path) -> None:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 640
    scene.render.resolution_y = 640
    scene.render.image_settings.file_format = "PNG"
    if scene.world is None:
        scene.world = bpy.data.worlds.new("PreviewWorld")
    scene.world.color = (0.42, 0.48, 0.52)

    bpy.ops.object.light_add(type="AREA", location=(-1.4, -1.8, 2.2))
    key = bpy.context.object
    key.data.energy = 480.0
    key.data.size = 2.0

    dims = _mesh_metrics(obj)["dimensions_m"]
    span = max(float(dims[0]), float(dims[1]), float(dims[2]), 0.4)
    bpy.ops.object.camera_add(location=(span * 1.05, -span * 1.35, span * 0.62))
    camera = bpy.context.object
    direction = Vector((0.0, 0.0, span * 0.25)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = span * 1.45
    scene.camera = camera
    path.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(camera, do_unlink=True)
    bpy.data.objects.remove(key, do_unlink=True)


def build_species(species: str, spec: dict) -> dict[str, object]:
    _reset_scene()
    maps = _create_feather_maps(species, spec["colors"][0], spec["colors"][1], spec.get("breast"))
    feather_material = _make_material(f"{species}_feather", maps, _hex_to_linear(spec["colors"][0]))
    if species == "mallard":
        obj = _build_mallard(spec)
        # Keep PBR maps on the torso while using explicit solid slots for the
        # species-defining head, collar, breast, bill, feet, and eye colours.
        solid_materials = [
            feather_material,
            _make_solid_material("mallard_breast", (0x77, 0x50, 0x3A)),
            _make_solid_material("mallard_head", (0x33, 0x5B, 0x4D)),
            _make_solid_material("mallard_wing", (0x76, 0x6A, 0x4D)),
            _make_solid_material("mallard_collar", (0xE8, 0xE4, 0xD8)),
            _make_solid_material("mallard_bill", (0xD3, 0xA4, 0x42)),
            _make_solid_material("mallard_feet", (0xD3, 0x8A, 0x38)),
            _make_solid_material("mallard_eye", (0x12, 0x10, 0x0C), roughness=0.28),
            _make_solid_material("mallard_speculum", (0x2B, 0x72, 0x6B)),
        ]
        for material in solid_materials:
            obj.data.materials.append(material)
    elif species == "greylag_goose":
        obj = _build_greylag_goose(spec)
        solid_materials = [
            feather_material,
            _make_solid_material("greylag_goose_wing", (0x6F, 0x71, 0x68)),
            _make_solid_material("greylag_goose_neck", (0xA1, 0x9B, 0x88)),
            _make_solid_material("greylag_goose_bill", (0xD6, 0x8C, 0x4C)),
            _make_solid_material("greylag_goose_leg", (0xB2, 0x72, 0x43)),
            _make_solid_material("greylag_goose_eye", (0x18, 0x15, 0x10), roughness=0.28),
            _make_solid_material("greylag_goose_foot", (0xC0, 0x79, 0x43)),
        ]
        for material in solid_materials:
            obj.data.materials.append(material)
    else:
        obj = _build_standing_bird(spec)
        obj.data.materials.append(feather_material)
    _uv_smart_project(obj)

    out_dir = BIRDS_DIR / species
    # Replace prior Sketchfab/import mallard assets with the catalog mesh.
    if out_dir.exists():
        for stale in out_dir.glob("*.glb"):
            stale.unlink()
    path = out_dir / "standing.glb"
    metrics = _export_glb(obj, path)
    metrics["species"] = species
    metrics["pose"] = "standing"
    metrics["neck"] = spec["neck"]
    _render_species_preview(obj, EVIDENCE_DIR / "previews" / f"{species}_standing.png")
    preview_report = REPORTS_DIR / f"p2_035_{species}_reference.png"
    preview_report.parent.mkdir(parents=True, exist_ok=True)
    preview_src = EVIDENCE_DIR / "previews" / f"{species}_standing.png"
    if preview_src.exists():
        preview_report.write_bytes(preview_src.read_bytes())
        metrics["reference_plate"] = str(preview_report.relative_to(ROOT))
    return metrics


def _compose_reference_sheet(reports: list[dict[str, object]]) -> str | None:
    """Side-by-side PNG of the four standing previews for verify readability."""
    try:
        from PIL import Image
    except ImportError:
        return None
    previews = []
    for report in reports:
        species = str(report["species"])
        path = EVIDENCE_DIR / "previews" / f"{species}_standing.png"
        if path.exists():
            previews.append(Image.open(path).convert("RGBA"))
    if len(previews) != 4:
        return None
    cell = 512
    sheet = Image.new("RGBA", (cell * 4, cell), (48, 56, 62, 255))
    for index, image in enumerate(previews):
        image.thumbnail((cell - 16, cell - 16))
        ox = index * cell + (cell - image.width) // 2
        oy = (cell - image.height) // 2
        sheet.paste(image, (ox, oy), image)
    out = REPORTS_DIR / "p2_035_waterfowl_reference_sheet.png"
    sheet.convert("RGB").save(out, "PNG")
    return str(out.relative_to(ROOT))


def main() -> int:
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    all_reports: list[dict[str, object]] = []
    for species, spec in SPECIES.items():
        print(f"Building {species}...", flush=True)
        all_reports.append(build_species(species, spec))

    sheet = _compose_reference_sheet(all_reports)
    report_path = EVIDENCE_DIR / "report.json"
    report_path.write_text(
        json.dumps({"generator": GENERATOR_VERSION, "assets": all_reports, "reference_sheet": sheet}, indent=2) + "\n",
        encoding="utf-8",
    )
    state = {
        "asset_id": "bird.waterfowl_batch",
        "route": "deterministic_blender",
        "stage": "production_ready",
        "generator_version": GENERATOR_VERSION,
        "blender_version": BLENDER_VERSION,
        "note": "Hunyuan3D unavailable; catalog-proportion standing waterfowl with PBR feather maps and long-neck overrides",
    }
    (EVIDENCE_DIR / "state.json").write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    print(f"ASSET_BATCH={len(all_reports)} report={report_path} sheet={sheet}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
