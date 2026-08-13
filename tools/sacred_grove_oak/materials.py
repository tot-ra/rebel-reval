"""Painted materials for the Sacred Grove ancient oak Blender generator."""

from __future__ import annotations

import math

import bpy
import numpy as np

def _srgb_to_linear(channel: float) -> float:
    if channel <= 0.04045:
        return channel / 12.92
    return ((channel + 0.055) / 1.055) ** 2.4


def _image_from_array(name: str, pixels: np.ndarray, colorspace: str = "sRGB") -> bpy.types.Image:
    height, width, channels = pixels.shape
    if channels == 3:
        pixels = np.concatenate((pixels, np.ones((height, width, 1), dtype=np.float32)), axis=2)
    image = bpy.data.images.new(name, width=width, height=height, alpha=True)
    image.colorspace_settings.name = colorspace
    image.file_format = "PNG"
    image.pixels.foreach_set(np.ascontiguousarray(pixels, dtype=np.float32).ravel())
    image.pack()
    return image


def _create_bark_images(seed: int) -> tuple[bpy.types.Image, bpy.types.Image]:
    """Bake broad fissured oak bark and a matching tangent-space normal map."""
    size = 1024
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    u = xx / float(size)
    v = yy / float(size)
    rng = np.random.default_rng(seed)

    # Several warped vertical frequencies produce irregular old-oak plates rather
    # than the repeated sine stripes used by the former runtime tube material.
    warp = u + 0.035 * np.sin(v * math.tau * 1.7) + 0.014 * np.sin(v * math.tau * 6.1 + 1.2)
    broad = np.abs(np.sin((warp * 7.0 + 0.09 * np.sin(v * math.tau * 2.3)) * math.tau))
    middle = np.abs(np.sin((warp * 19.0 - v * 0.7) * math.tau))
    fine = np.abs(np.sin((warp * 43.0 + v * 1.8) * math.tau))
    cellular = rng.random((64, 64), dtype=np.float32)
    cellular = np.repeat(np.repeat(cellular, size // 64, axis=0), size // 64, axis=1)
    cellular = (
        cellular
        + np.roll(cellular, 1, axis=0)
        + np.roll(cellular, -1, axis=0)
        + np.roll(cellular, 1, axis=1)
        + np.roll(cellular, -1, axis=1)
    ) / 5.0
    height = np.clip(0.24 + broad * 0.46 + middle * 0.19 + fine * 0.07 + cellular * 0.08, 0.0, 1.0)
    fissure = np.clip((0.43 - broad) * 2.8, 0.0, 1.0)
    plate = np.clip(height * (0.90 + 0.08 * np.sin(v * math.tau * 3.0)), 0.0, 1.0)

    base = np.array([0.20, 0.105, 0.050], dtype=np.float32)
    warm = np.array([0.40, 0.225, 0.105], dtype=np.float32)
    rgb_srgb = base[None, None, :] * (1.0 - plate[:, :, None]) + warm[None, None, :] * plate[:, :, None]
    rgb_srgb *= (1.0 - fissure[:, :, None] * 0.48)

    # Sparse desaturated lichen belongs in the bark surface, not as implausible
    # long hanging moss on a northern European oak.
    lichen_field = (
        np.sin(u * math.tau * 3.0 + np.sin(v * math.tau * 2.0))
        + np.sin(v * math.tau * 4.0 - u * math.tau * 1.5)
    )
    lichen_mask = np.clip((lichen_field - 1.05) * 1.7, 0.0, 0.52) * np.clip(1.15 - v, 0.0, 1.0)
    lichen = np.array([0.32, 0.39, 0.23], dtype=np.float32)
    rgb_srgb = rgb_srgb * (1.0 - lichen_mask[:, :, None]) + lichen[None, None, :] * lichen_mask[:, :, None]
    rgb_linear = np.vectorize(_srgb_to_linear)(np.clip(rgb_srgb, 0.0, 1.0)).astype(np.float32)
    albedo = _image_from_array("ancient_oak_bark_albedo", rgb_linear)

    dx = np.roll(height, -2, axis=1) - np.roll(height, 2, axis=1)
    dy = np.roll(height, -2, axis=0) - np.roll(height, 2, axis=0)
    strength = 2.9
    nx = -dx * strength
    ny = -dy * strength
    nz = np.ones_like(height)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    normal = np.stack((nx / length * 0.5 + 0.5, ny / length * 0.5 + 0.5, nz / length * 0.5 + 0.5), axis=2)
    normal_image = _image_from_array("ancient_oak_bark_normal", normal.astype(np.float32), "Non-Color")
    return albedo, normal_image


def _create_leaf_image() -> bpy.types.Image:
    """Bake restrained leaf value variation and veins for the shaped leaf mesh."""
    size = 512
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    u = xx / float(size)
    v = yy / float(size)
    broad = 0.76 + 0.10 * np.sin((u * 2.2 + v * 1.1) * math.tau)
    fine = 0.035 * np.sin((u * 13.0 - v * 9.0) * math.tau)
    central_vein = np.exp(-((u - 0.5) / 0.018) ** 2) * 0.19
    side_veins = np.zeros_like(u)
    for offset in (0.20, 0.31, 0.42, 0.54, 0.66, 0.77):
        distance = np.minimum(np.abs((u - 0.5) - (v - offset) * 0.72), np.abs((u - 0.5) + (v - offset) * 0.72))
        side_veins += np.exp(-(distance / 0.012) ** 2) * np.exp(-((v - offset) / 0.12) ** 2) * 0.055
    edge_age = np.clip((np.abs(u - 0.5) - 0.34) * 1.4, 0.0, 0.08)
    value = np.clip(broad + fine + central_vein + side_veins - edge_age, 0.55, 1.05)
    base = np.array([0.115, 0.255, 0.075], dtype=np.float32)
    rgb_srgb = np.clip(base[None, None, :] * value[:, :, None], 0.0, 1.0)
    rgb_linear = np.vectorize(_srgb_to_linear)(rgb_srgb).astype(np.float32)
    return _image_from_array("ancient_oak_leaf_albedo", rgb_linear)


def _create_heartwood_image() -> bpy.types.Image:
    """Bake growth rings and torn fibres for the face of the snapped bough."""
    size = 256
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    u = xx / float(size) - 0.5
    v = yy / float(size) - 0.5
    # The disc UVs are radial, so polar coordinates land the rings concentrically
    # around the break instead of smearing a square texture across it.
    radius = np.sqrt(u * u + v * v) * 2.0
    theta = np.arctan2(v, u)
    rings = 0.5 + 0.5 * np.sin(radius * 47.0 + 0.7 * np.sin(theta * 3.0))
    fibres = 0.5 + 0.5 * np.sin(theta * 41.0 + radius * 7.0)
    value = 0.58 + 0.26 * rings + 0.16 * fibres
    # Decayed heart: the centre of an old break is darker than the sapwood ring.
    value *= 0.52 + 0.48 * np.clip(radius / 0.38, 0.0, 1.0)
    base = np.array([0.295, 0.210, 0.140], dtype=np.float32)
    rgb_srgb = np.clip(base[None, None, :] * value[:, :, None], 0.0, 1.0)
    rgb_linear = np.vectorize(_srgb_to_linear)(rgb_srgb).astype(np.float32)
    return _image_from_array("ancient_oak_heartwood_albedo", rgb_linear)


def create_materials(seed: int) -> dict[str, bpy.types.Material]:
    bark_albedo, bark_normal = _create_bark_images(seed)
    leaf_albedo = _create_leaf_image()

    bark = bpy.data.materials.new("Ancient oak fissured bark")
    bark.use_nodes = True
    bark.diffuse_color = (0.12, 0.055, 0.025, 1.0)
    bark.roughness = 0.92
    nodes = bark.node_tree.nodes
    links = bark.node_tree.links
    principled = nodes.get("Principled BSDF")
    principled.inputs["Roughness"].default_value = 0.92
    color_node = nodes.new("ShaderNodeTexImage")
    color_node.name = "EmbeddedBarkAlbedo"
    color_node.image = bark_albedo
    color_node.extension = "REPEAT"
    normal_node = nodes.new("ShaderNodeTexImage")
    normal_node.name = "EmbeddedBarkNormal"
    normal_node.image = bark_normal
    normal_node.extension = "REPEAT"
    normal_map = nodes.new("ShaderNodeNormalMap")
    normal_map.inputs["Strength"].default_value = 0.72
    links.new(color_node.outputs["Color"], principled.inputs["Base Color"])
    links.new(normal_node.outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], principled.inputs["Normal"])

    leaf = bpy.data.materials.new("Ancient oak leaves")
    leaf.use_nodes = True
    leaf.use_backface_culling = False
    leaf.diffuse_color = (0.08, 0.23, 0.05, 1.0)
    leaf.roughness = 0.84
    leaf_nodes = leaf.node_tree.nodes
    leaf_links = leaf.node_tree.links
    leaf_principled = leaf_nodes.get("Principled BSDF")
    leaf_principled.inputs["Roughness"].default_value = 0.84
    leaf_principled.inputs["Coat Weight"].default_value = 0.04
    leaf_texture = leaf_nodes.new("ShaderNodeTexImage")
    leaf_texture.name = "EmbeddedLeafAlbedo"
    leaf_texture.image = leaf_albedo
    leaf_texture.extension = "CLIP"
    leaf_links.new(leaf_texture.outputs["Color"], leaf_principled.inputs["Base Color"])

    # Viewport diffuse_color alone is ignored by the glTF exporter: a node-less
    # material lands in the GLB as the default light grey, which made the snapped
    # bough and the hollow read as bright white cuts in game.
    # An old snapped bough greys off; a fresh sawmill orange would pull the eye
    # away from the bark and the crown.
    heartwood = _flat_material("Weathered heartwood", (0.225, 0.155, 0.105), 0.95)
    heartwood_nodes = heartwood.node_tree.nodes
    heartwood_texture = heartwood_nodes.new("ShaderNodeTexImage")
    heartwood_texture.name = "EmbeddedHeartwoodAlbedo"
    heartwood_texture.image = _create_heartwood_image()
    heartwood_texture.extension = "CLIP"
    heartwood.node_tree.links.new(
        heartwood_texture.outputs["Color"], heartwood_nodes.get("Principled BSDF").inputs["Base Color"]
    )

    hollow = _flat_material("Deep hollow", (0.035, 0.020, 0.012), 1.0)
    return {"bark": bark, "leaf": leaf, "heartwood": heartwood, "hollow": hollow}


def _flat_material(name: str, srgb: tuple[float, float, float], roughness: float) -> bpy.types.Material:
    """Untextured Principled material that survives the glTF material export."""
    linear = tuple(_srgb_to_linear(value) for value in srgb)
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    material.diffuse_color = linear + (1.0,)
    material.roughness = roughness
    principled = material.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = linear + (1.0,)
    principled.inputs["Roughness"].default_value = roughness
    principled.inputs["Metallic"].default_value = 0.0
    return material
