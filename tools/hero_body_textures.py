"""Procedural PBR texture families for generated characters (P0-144/P0-145).

Runtime character GLBs used to ship with zero images: every material was a
flat per-part color, which is what made clothing and hair read as toy plastic.
This module generates deterministic, tileable grayscale detail maps (albedo
luminance around 1.0 plus tangent-space normals) with numpy inside Blender's
Python. Materials multiply the detail albedo by their palette color, so one
512 px set per family serves every character, palette variant, and garment
without per-character texture memory growth.

The maps are build-time artifacts embedded into the exported GLBs; no runtime
GDScript changes are involved. Families are deliberately coarse - cloth,
leather, skin, hair, metal - matching the material response table in
tools/generate_hero_body.py.
"""

from __future__ import annotations

import bpy
import numpy as np

SIZE = 512

# Material name -> texture family. Materials not listed (eyes, eye_white,
# lips) stay flat: they cover a few pixels and gain nothing from grain.
MATERIAL_FAMILIES = {
    "skin": "skin",
    "tunic": "cloth",
    "sleeves": "cloth",
    "sleeve_band": "cloth",
    "pants": "cloth",
    "trim": "cloth",
    "outerwear": "cloth",
    "cape": "cloth",
    "hat": "cloth",
    "boots": "leather",
    "sole": "leather",
    "belt": "leather",
    "leather": "leather",
    "hair": "hair",
    "beard": "hair",
    "armor": "metal",
    "mail": "metal",
}

# Heightfield-to-normal slope per family, tuned so weave and grain read at
# portrait distance without turning the surface into sandpaper.
_HEIGHT_STRENGTH = {
    "skin": 1.2,
    "cloth": 2.2,
    "leather": 3.0,
    "hair": 3.0,
    "metal": 1.6,
}

# NormalMap node strength per family (exporter carries this as normal scale).
NORMAL_STRENGTH = {
    "skin": 0.35,
    "cloth": 0.85,
    "leather": 0.75,
    "hair": 0.65,
    "metal": 0.55,
}


def _tileable_noise(
    seed: int, cells_x: int, cells_y: int, size: int = SIZE
) -> np.ndarray:
    """Smooth value noise on a wrapping grid, so every map tiles seamlessly."""
    rng = np.random.default_rng(seed)
    grid = rng.random((cells_y, cells_x))
    ys = np.linspace(0.0, cells_y, size, endpoint=False)
    xs = np.linspace(0.0, cells_x, size, endpoint=False)
    y0 = np.floor(ys).astype(int) % cells_y
    x0 = np.floor(xs).astype(int) % cells_x
    y1 = (y0 + 1) % cells_y
    x1 = (x0 + 1) % cells_x
    fy = (ys - np.floor(ys))[:, None]
    fx = (xs - np.floor(xs))[None, :]
    # Smoothstep interpolation hides the underlying grid.
    fy = fy * fy * (3.0 - 2.0 * fy)
    fx = fx * fx * (3.0 - 2.0 * fx)
    g00 = grid[np.ix_(y0, x0)]
    g01 = grid[np.ix_(y0, x1)]
    g10 = grid[np.ix_(y1, x0)]
    g11 = grid[np.ix_(y1, x1)]
    top = g00 * (1.0 - fx) + g01 * fx
    bottom = g10 * (1.0 - fx) + g11 * fx
    return top * (1.0 - fy) + bottom * fy


def _fbm(seed: int, cells: int, octaves: int, size: int = SIZE) -> np.ndarray:
    total = np.zeros((size, size))
    amplitude = 1.0
    norm = 0.0
    for octave in range(octaves):
        cells_now = cells * (2**octave)
        total += amplitude * _tileable_noise(seed + octave, cells_now, cells_now, size)
        norm += amplitude
        amplitude *= 0.5
    return total / norm


def _normal_from_height(height: np.ndarray, strength: float) -> np.ndarray:
    """OpenGL-convention tangent-space normal map from a tileable heightfield."""
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5 * strength
    dy = (np.roll(height, 1, axis=0) - np.roll(height, -1, axis=0)) * 0.5 * strength
    inv = 1.0 / np.sqrt(dx * dx + dy * dy + 1.0)
    return np.stack(
        [-dx * inv * 0.5 + 0.5, dy * inv * 0.5 + 0.5, inv * 0.5 + 0.5], axis=-1
    )


def _cloth_maps() -> tuple[np.ndarray, np.ndarray]:
    """Plain wool weave: alternating warp/weft bumps plus fiber irregularity."""
    period = 5.0
    x = np.arange(SIZE, dtype=np.float64)[None, :]
    y = np.arange(SIZE, dtype=np.float64)[:, None]
    warp = np.abs(np.sin(np.pi * x / period))
    weft = np.abs(np.sin(np.pi * y / period))
    checker = ((np.floor(x / period) + np.floor(y / period)) % 2.0) == 0.0
    weave = np.where(checker, warp * 0.75 + weft * 0.25, weft * 0.75 + warp * 0.25)
    irregularity = _fbm(101, 48, 2)
    height = weave * 0.7 + irregularity * 0.3
    albedo = 0.90 + 0.10 * weave + (irregularity - 0.5) * 0.07
    return np.repeat(albedo[..., None], 3, axis=-1), height


def _leather_maps() -> tuple[np.ndarray, np.ndarray]:
    """Vegetable-tanned leather: broad grain, fine pores, darker creases."""
    grain = _fbm(201, 20, 4)
    fine = _fbm(202, 180, 2)
    pores = _tileable_noise(203, 96, 96)
    pore_mask = np.clip((pores - 0.78) / 0.22, 0.0, 1.0)
    height = grain * 0.55 + fine * 0.45 - pore_mask * 0.25
    albedo = 0.87 + 0.15 * grain + (fine - 0.5) * 0.07 - pore_mask * 0.09
    return np.repeat(albedo[..., None], 3, axis=-1), height


def _skin_maps() -> tuple[np.ndarray, np.ndarray]:
    """Subtle skin: low-frequency blotch, fine pores, sparse darker freckles."""
    blotch = _fbm(301, 12, 3)
    pores = _fbm(302, 220, 2)
    freckles = _tileable_noise(303, 64, 64)
    freckle_mask = np.clip((freckles - 0.88) / 0.12, 0.0, 1.0)
    height = blotch * 0.35 + pores * 0.65
    albedo = 0.95 + 0.05 * blotch + (pores - 0.5) * 0.03 - freckle_mask * 0.05
    return np.repeat(albedo[..., None], 3, axis=-1), height


def _hair_maps() -> tuple[np.ndarray, np.ndarray]:
    """Strand streaks running along U with per-clump brightness variation."""
    columns = _tileable_noise(401, 256, 1)
    clumps = _tileable_noise(402, 40, 1)
    x = np.arange(SIZE, dtype=np.float64)[None, :]
    strand = 0.5 + 0.5 * np.sin(2.0 * np.pi * x / 2.6 + columns * 9.0)
    strand = np.broadcast_to(strand, (SIZE, SIZE)).copy()
    clump_field = np.broadcast_to(clumps, (SIZE, SIZE))
    height = strand * 0.65 + clump_field * 0.35
    # Restrained contrast: strong streak deltas read as zebra stripes once the
    # palette color multiplies in, especially under direct sun.
    albedo = 0.84 + 0.18 * strand * (0.75 + 0.50 * clump_field)
    return np.repeat(albedo[..., None], 3, axis=-1), height


def _metal_maps() -> tuple[np.ndarray, np.ndarray]:
    """Brushed metal: anisotropic streaks with sparse hammered dents."""
    streaks = _tileable_noise(501, 6, 160)
    dents = _fbm(502, 24, 3)
    dent_mask = np.clip((dents - 0.80) / 0.20, 0.0, 1.0)
    height = streaks * 0.5 + dents * 0.5 - dent_mask * 0.4
    albedo = 0.88 + 0.10 * streaks + (dents - 0.5) * 0.06 - dent_mask * 0.14
    return np.repeat(albedo[..., None], 3, axis=-1), height


_FAMILY_BUILDERS = {
    "cloth": _cloth_maps,
    "leather": _leather_maps,
    "skin": _skin_maps,
    "hair": _hair_maps,
    "metal": _metal_maps,
}

_image_cache: dict[str, tuple[bpy.types.Image, bpy.types.Image, bpy.types.Image, bpy.types.Image]] = {}


def _make_image(name: str, rgb: np.ndarray, non_color: bool) -> bpy.types.Image:
    image = bpy.data.images.new(name, SIZE, SIZE, alpha=False)
    rgba = np.empty((SIZE, SIZE, 4), dtype=np.float32)
    rgba[..., :3] = np.clip(rgb, 0.0, 1.0).astype(np.float32)
    rgba[..., 3] = 1.0
    image.pixels = rgba.reshape(-1)
    if non_color:
        image.colorspace_settings.name = "Non-Color"
    # Packed images are embedded into the exported GLB.
    image.pack()
    return image


def family_images(
    family: str,
) -> tuple[bpy.types.Image, bpy.types.Image, bpy.types.Image, bpy.types.Image]:
    """Return (albedo, normal, roughness, AO) maps for one material family."""
    cached = _image_cache.get(family)
    if cached is not None:
        return cached
    albedo, height = _FAMILY_BUILDERS[family]()
    normal = _normal_from_height(height, _HEIGHT_STRENGTH[family])
    # Roughness is mostly a material-family value, with restrained authored
    # variation so wool/leather/skin do not respond like uniform plastic.
    roughness_base = {
        "skin": 0.72,
        "cloth": 0.88,
        "leather": 0.66,
        "hair": 0.78,
        "metal": 0.42,
    }[family]
    roughness = np.clip(roughness_base + (height - 0.5) * 0.16, 0.08, 0.98)
    roughness_rgb = np.repeat(roughness[..., None], 3, axis=-1)
    # A conservative cavity mask derived from local relief. It is intentionally
    # subtle: AO should anchor seams and facial recesses without dirtying the
    # palette or replacing Godot's scene-level ambient occlusion.
    relief = np.abs(height - 0.5)
    ao = np.clip(0.98 - relief * 0.22, 0.72, 1.0)
    ao_rgb = np.repeat(ao[..., None], 3, axis=-1)
    maps = (
        _make_image(f"hero_tex_{family}_albedo", albedo, non_color=False),
        _make_image(f"hero_tex_{family}_normal", normal, non_color=True),
        _make_image(f"hero_tex_{family}_roughness", roughness_rgb, non_color=True),
        _make_image(f"hero_tex_{family}_ao", ao_rgb, non_color=True),
    )
    _image_cache[family] = maps
    return maps


def _gltf_material_output_group() -> bpy.types.NodeTree:
    """Create Blender's standard glTF AO settings group for export."""
    group_name = "glTF Material Output"
    group = bpy.data.node_groups.get(group_name)
    if group is None:
        group = bpy.data.node_groups.new(group_name, "ShaderNodeTree")
        group.interface.new_socket("Occlusion", socket_type="NodeSocketFloat")
        group.interface.new_socket("Thickness", socket_type="NodeSocketFloat")
        group.nodes.new("NodeGroupInput")
        group.nodes.new("NodeGroupOutput")
    return group


def apply_texture(material: bpy.types.Material, material_name: str) -> None:
    """Wire family albedo/normal/roughness/AO maps into a PBR material.

    Blender's glTF exporter packs roughness and AO into the standard glTF
    metallic-roughness and occlusion texture channels. The source maps remain
    separate in the build graph, while the exported runtime asset stays within
    the format's native PBR contract.
    """
    family = MATERIAL_FAMILIES.get(material_name)
    if family is None:
        return
    albedo, normal, roughness, ao = family_images(family)
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    bsdf = nodes["Principled BSDF"]
    base_input = bsdf.inputs["Base Color"]
    palette_color = tuple(base_input.default_value)

    albedo_node = nodes.new("ShaderNodeTexImage")
    albedo_node.image = albedo
    multiply = nodes.new("ShaderNodeMix")
    multiply.data_type = "RGBA"
    multiply.blend_type = "MULTIPLY"
    multiply.inputs["Factor"].default_value = 1.0
    multiply.inputs["B"].default_value = palette_color
    links.new(albedo_node.outputs["Color"], multiply.inputs["A"])
    links.new(multiply.outputs["Result"], base_input)

    normal_node = nodes.new("ShaderNodeTexImage")
    normal_node.image = normal
    normal_map = nodes.new("ShaderNodeNormalMap")
    normal_map.inputs["Strength"].default_value = NORMAL_STRENGTH[family]
    links.new(normal_node.outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], bsdf.inputs["Normal"])

    roughness_node = nodes.new("ShaderNodeTexImage")
    roughness_node.image = roughness
    links.new(roughness_node.outputs["Color"], bsdf.inputs["Roughness"])

    ao_node = nodes.new("ShaderNodeTexImage")
    ao_node.image = ao
    gltf_output = nodes.new("ShaderNodeGroup")
    gltf_output.node_tree = _gltf_material_output_group()
    gltf_output.name = "glTF Material Output"
    links.new(ao_node.outputs["Color"], gltf_output.inputs["Occlusion"])
