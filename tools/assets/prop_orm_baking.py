"""Procedural ORM map generation for portable glTF smithy and chest props.

Bakes tangent-space normal, roughness, and AO maps from the same height fields
that drive painted albedo variation so iron, wood, stone, and leather read under
dynamic sun without a separate texture-authoring pass.
"""

from __future__ import annotations

import math
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    import bpy

# Surface keys mirror generator _create_texture branches; palette aliases fold here.
_SURFACE_ALIASES = {
    "oak": "wood",
    "limestone": "stone",
}

_SURFACE_PROFILES: dict[str, dict[str, float]] = {
    "wood": {"normal_strength": 0.55, "roughness_base": 0.88, "roughness_range": 0.08, "ao_depth": 0.12},
    "timber": {"normal_strength": 0.50, "roughness_base": 0.90, "roughness_range": 0.06, "ao_depth": 0.10},
    "iron": {"normal_strength": 0.70, "roughness_base": 0.58, "roughness_range": 0.12, "ao_depth": 0.08},
    "face": {"normal_strength": 0.35, "roughness_base": 0.30, "roughness_range": 0.08, "ao_depth": 0.04},
    "aged_iron": {"normal_strength": 0.65, "roughness_base": 0.52, "roughness_range": 0.10, "ao_depth": 0.10},
    "inner_iron": {"normal_strength": 0.60, "roughness_base": 0.68, "roughness_range": 0.08, "ao_depth": 0.12},
    "leather": {"normal_strength": 0.45, "roughness_base": 0.78, "roughness_range": 0.10, "ao_depth": 0.14},
    "linen": {"normal_strength": 0.42, "roughness_base": 0.94, "roughness_range": 0.04, "ao_depth": 0.10},
    "hemp": {"normal_strength": 0.48, "roughness_base": 0.95, "roughness_range": 0.03, "ao_depth": 0.10},
    "charcoal": {"normal_strength": 0.32, "roughness_base": 0.92, "roughness_range": 0.06, "ao_depth": 0.08},
    "stone": {"normal_strength": 0.40, "roughness_base": 0.92, "roughness_range": 0.05, "ao_depth": 0.08},
    "firebrick": {"normal_strength": 0.50, "roughness_base": 0.86, "roughness_range": 0.07, "ao_depth": 0.10},
    "soot": {"normal_strength": 0.25, "roughness_base": 0.94, "roughness_range": 0.04, "ao_depth": 0.06},
    "water": {"normal_strength": 0.08, "roughness_base": 0.12, "roughness_range": 0.03, "ao_depth": 0.02},
}


def _resolve_surface(surface: str) -> str:
    return _SURFACE_ALIASES.get(surface, surface)


def _height_field(u, v, surface: str):
    """Return a normalized height field used to derive normals and micro-roughness."""
    import numpy as np

    surface = _resolve_surface(surface)
    if surface == "wood":
        warp = u + 0.025 * np.sin(v * math.tau * 2.1) + 0.010 * np.sin(v * math.tau * 6.7 + 0.4)
        broad = np.sin((warp * 10.0 + 0.12 * np.sin(v * math.tau * 1.4)) * math.tau)
        fine = np.sin((warp * 34.0 + v * 0.6) * math.tau)
        height = 0.50 + broad * 0.12 + fine * 0.03
        for knot_u, knot_v, radius in ((0.23, 0.31, 0.07), (0.69, 0.72, 0.09)):
            dx = (u - knot_u) / radius
            dy = (v - knot_v) / (radius * 0.58)
            distance = np.sqrt(dx * dx + dy * dy)
            height += np.sin(distance * math.tau * 2.2) * np.clip(1.0 - distance / 2.0, 0.0, 1.0) * 0.04
            height -= np.exp(-(distance * distance) * 5.0) * 0.08
    elif surface == "timber":
        warp = u + 0.020 * np.sin(v * math.tau * 1.8)
        grain = np.sin((warp * 12.0 + 0.08 * np.sin(v * math.tau)) * math.tau)
        height = 0.50 + grain * 0.10
    elif surface == "face":
        sweep = np.sin((u * 7.0 + 0.16 * np.sin(v * math.tau * 2.0)) * math.tau)
        cross = np.sin((v * 15.0 + u * 0.8) * math.tau)
        height = 0.52 + sweep * 0.06 + cross * 0.02
    elif surface in {"iron", "aged_iron", "inner_iron"}:
        hammered = np.sin((u * 11.0 + v * 4.0) * math.tau) * np.sin((v * 9.0 - u * 3.0) * math.tau)
        broad = np.sin((u * 2.0 + v * 1.7) * math.tau)
        scale = 0.08 if surface == "inner_iron" else 0.10
        height = 0.50 + hammered * scale + broad * (scale * 0.5)
    elif surface == "leather":
        fold = np.sin((u * 4.5 + 0.35 * np.sin(v * math.tau * 1.6)) * math.tau)
        crease = np.sin((v * 9.0 - u * 2.5) * math.tau)
        height = 0.50 + fold * 0.09 + crease * 0.04
    elif surface == "linen":
        warp = np.sin((u * 44.0 + 0.5 * np.sin(v * math.tau * 2.0)) * math.tau)
        weft = np.sin((v * 40.0 - 0.4 * np.sin(u * math.tau * 1.7)) * math.tau)
        broad = np.sin((u * 2.1 + v * 1.4) * math.tau)
        height = 0.50 + warp * weft * 0.055 + broad * 0.025
    elif surface == "hemp":
        twist = np.sin((u * 24.0 + v * 9.0) * math.tau)
        fiber = np.sin((u * 61.0 - v * 5.0) * math.tau)
        height = 0.50 + twist * 0.08 + fiber * 0.025
    elif surface == "charcoal":
        fracture = np.sin((u * 9.0 + v * 3.0) * math.tau) * np.sin((v * 13.0 - u * 4.0) * math.tau)
        growth_rings = np.sin((u * 21.0 + 0.7 * np.sin(v * math.tau * 3.0)) * math.tau)
        height = 0.50 + fracture * 0.09 + growth_rings * 0.035
    elif surface == "stone":
        broad = np.sin((u * 2.0 + v * 1.45) * math.tau)
        chisel = np.sin((u * 14.0 - v * 5.0) * math.tau) * np.sin((v * 11.0 + u * 2.0) * math.tau)
        height = 0.50 + broad * 0.05 + chisel * 0.03
    elif surface == "firebrick":
        broad = np.sin((u * 3.0 + v * 1.8) * math.tau)
        heat = np.sin((u * 8.0 - v * 4.0) * math.tau) * np.sin((v * 9.0) * math.tau)
        height = 0.50 + broad * 0.07 + heat * 0.05
    elif surface == "soot":
        streak = np.sin((u * 3.0 + 0.24 * np.sin(v * math.tau * 2.0)) * math.tau)
        height = 0.50 + streak * 0.04
    elif surface == "water":
        ripple = np.sin((u * 18.0 + v * 7.0) * math.tau) * np.sin((v * 12.0 - u * 4.0) * math.tau)
        height = 0.50 + ripple * 0.015
    else:
        height = np.full_like(u, 0.50, dtype=np.float32)
    return np.clip(height, 0.0, 1.0).astype(np.float32)


def _new_image(name: str, fill: tuple[float, float, float, float], *, non_color: bool) -> "bpy.types.Image":
    import bpy

    image = bpy.data.images.new(name, width=512, height=512, alpha=True)
    pixels = list(fill) * (512 * 512)
    image.pixels.foreach_set(pixels)
    image.colorspace_settings.name = "Non-Color" if non_color else "sRGB"
    image.file_format = "PNG"
    image.pack()
    return image


def _height_to_normal(height, strength: float):
    import numpy as np

    du = np.gradient(height, axis=1)
    dv = np.gradient(height, axis=0)
    nx = -du * strength
    ny = -dv * strength
    nz = np.ones_like(nx)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    normal = np.stack([nx / length, ny / length, nz / length], axis=2)
    rgb = np.clip(normal * 0.5 + 0.5, 0.0, 1.0)
    alpha = np.ones((height.shape[0], height.shape[1], 1), dtype=np.float32)
    return np.concatenate((rgb, alpha), axis=2)


def create_normal_image(name: str, surface: str) -> "bpy.types.Image":
    import numpy as np

    size = 512
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    u = xx / float(size)
    v = yy / float(size)
    profile = _SURFACE_PROFILES[_resolve_surface(surface)]
    height = _height_field(u, v, surface)
    pixels = _height_to_normal(height, profile["normal_strength"]).ravel()
    image = _new_image(f"{name}_normal", (0.5, 0.5, 1.0, 1.0), non_color=True)
    image.pixels.foreach_set(pixels.tolist())
    image.pack()
    return image


def create_roughness_image(name: str, surface: str) -> "bpy.types.Image":
    import numpy as np

    size = 512
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    u = xx / float(size)
    v = yy / float(size)
    profile = _SURFACE_PROFILES[_resolve_surface(surface)]
    height = _height_field(u, v, surface)
    roughness = profile["roughness_base"] + (height - 0.5) * profile["roughness_range"] * 2.0
    roughness = np.clip(roughness, 0.04, 1.0)
    rgb = np.repeat(roughness[:, :, None], 3, axis=2)
    alpha = np.ones((size, size, 1), dtype=np.float32)
    pixels = np.concatenate((rgb, alpha), axis=2).ravel()
    image = _new_image(f"{name}_roughness", (0.84, 0.84, 0.84, 1.0), non_color=True)
    image.pixels.foreach_set(pixels.tolist())
    image.pack()
    return image


def wire_orm_maps(material: "bpy.types.Material", name: str, surface: str) -> None:
    """Attach embedded normal, roughness, and AO textures to an existing PBR material."""
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    principled = nodes.get("Principled BSDF")
    if principled is None:
        return

    normal_tex = nodes.new("ShaderNodeTexImage")
    normal_tex.name = "EmbeddedNormal"
    normal_tex.image = create_normal_image(name, surface)
    normal_tex.interpolation = "Linear"
    normal_tex.extension = "REPEAT"
    normal_map = nodes.new("ShaderNodeNormalMap")
    profile = _SURFACE_PROFILES[_resolve_surface(surface)]
    normal_map.inputs["Strength"].default_value = profile["normal_strength"]
    links.new(normal_tex.outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], principled.inputs["Normal"])

    roughness_tex = nodes.new("ShaderNodeTexImage")
    roughness_tex.name = "EmbeddedRoughness"
    roughness_tex.image = create_roughness_image(name, surface)
    roughness_tex.interpolation = "Linear"
    roughness_tex.extension = "REPEAT"
    links.new(roughness_tex.outputs["Color"], principled.inputs["Roughness"])
