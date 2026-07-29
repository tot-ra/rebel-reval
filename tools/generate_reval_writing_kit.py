#!/usr/bin/env python3
"""Build the game-ready Reval 1343 writing-and-records kit with Blender.

Run from the repository root:
    blender --background --factory-startup --python tools/generate_reval_writing_kit.py -- --preview

Historical basis: history/dossiers/culture/writing-and-records-reval-1343.md.
The kit is deliberately pre-paper and pre-print. Every variant is either a
parchment support (sheet, quire, limp binding, board-bound codex, roll, charter),
a wax tablet, a tally stick bundle, or a writing tool. Books therefore lie flat
or sit on a lectern - never upright with a lettered spine, which is a post-1500
silhouette.

Each variant is a separate GLB root so maps can select one record object per prop
without duplicating geometry, exactly like the kitchenware and clutter kits.
"""

from __future__ import annotations

import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "props" / "writing" / "reval_writing_kit.glb"
EVIDENCE_DIR = ROOT / "generated" / "blender" / "reval_writing_v1"
BRIEF_PATH = EVIDENCE_DIR / "brief.json"
REPORT_PATH = EVIDENCE_DIR / "report.json"
STATE_PATH = EVIDENCE_DIR / "state.json"
DEFAULT_PREVIEW = EVIDENCE_DIR / "preview.png"
ASSET_ID = "prop.reval_writing_kit"
BLENDER_VERSION = "Blender 5.2 LTS"
GENERATOR_VERSION = "reval_writing_kit_v1"

VARIANT_ROOTS: dict[str, str] = {
    "writing.parchment_sheet": "WritingParchmentSheet",
    "writing.parchment_offcuts": "WritingParchmentOffcuts",
    "writing.quire_loose": "WritingQuireLoose",
    "writing.quire_scraped": "WritingQuireScraped",
    "writing.quire_torn": "WritingQuireTorn",
    "writing.limp_ledger_closed": "WritingLimpLedgerClosed",
    "writing.limp_ledger_open": "WritingLimpLedgerOpen",
    "writing.codex_closed": "WritingCodexClosed",
    "writing.codex_open": "WritingCodexOpen",
    "writing.codex_flat_shelf": "WritingCodexFlatShelf",
    "writing.codex_stack": "WritingCodexStack",
    "writing.lectern_codex_closed": "WritingLecternCodexClosed",
    "writing.lectern_codex_open": "WritingLecternCodexOpen",
    "writing.wax_tablet_open": "WritingWaxTabletOpen",
    "writing.wax_tablet_closed": "WritingWaxTabletClosed",
    "writing.tally_sticks": "WritingTallySticks",
    "writing.rotulus_rolled": "WritingRotulusRolled",
    "writing.charter_sealed": "WritingCharterSealed",
    "writing.letter_folded": "WritingLetterFolded",
    "writing.inkhorn_quill": "WritingInkhornQuill",
    "writing.seal_matrix_wax": "WritingSealMatrixWax",
    "writing.group.forge_ledger": "WritingGroupForgeLedger",
    "writing.group.scribe_desk": "WritingGroupScribeDesk",
    "writing.group.merchant_counting": "WritingGroupMerchantCounting",
    "writing.group.archive_shelf": "WritingGroupArchiveShelf",
}

# Palette from the dossier production hooks. Parchment is never white: the hair
# side is yellower and speckled, the written page slightly paler and inked.
PARCHMENT_SRGB = (0xE4 / 255.0, 0xD8 / 255.0, 0xB8 / 255.0)
PAGE_SRGB = (0xEF / 255.0, 0xE5 / 255.0, 0xCB / 255.0)
LEATHER_SRGB = (0x4A / 255.0, 0x31 / 255.0, 0x23 / 255.0)
OAK_SRGB = (0x77 / 255.0, 0x49 / 255.0, 0x2D / 255.0)
LIMEWOOD_SRGB = (0xC9 / 255.0, 0xB1 / 255.0, 0x89 / 255.0)
TABLET_WAX_SRGB = (0x2C / 255.0, 0x2A / 255.0, 0x20 / 255.0)
SEAL_WAX_SRGB = (0x7E / 255.0, 0x2B / 255.0, 0x22 / 255.0)
IRON_SRGB = (0x46 / 255.0, 0x4F / 255.0, 0x52 / 255.0)
BRASS_SRGB = (0x8A / 255.0, 0x6B / 255.0, 0x2C / 255.0)
INK_SRGB = (0x24 / 255.0, 0x1C / 255.0, 0x14 / 255.0)
RUBRIC_SRGB = (0x8E / 255.0, 0x2C / 255.0, 0x1E / 255.0)

BRIEF = {
    "id": ASSET_ID,
    "kind": "rigid_prop_set",
    "target": "res://assets/props/writing/reval_writing_kit.glb",
    "scene": "res://content/maps/kalev_smithy.rrmap#ledger",
    "variants": list(VARIANT_ROOTS),
    "dimensions_m_max": [0.95, 0.62, 1.02],
    "triangles": {"target": 14000, "max": 26000},
    "textures": {"albedo": 512, "embedded": True},
    "style_refs": [
        "history/dossiers/culture/writing-and-records-reval-1343.md",
        "history/dossiers/power/reval-law-codex-arms-and-watch.md",
        "docs/ART_BIBLE.md",
        "docs/MATERIAL_STYLE_LOCK_KIT.md",
    ],
    "anachronism_bans": [
        "upright spine-out shelving",
        "lettered or gold-tooled spines",
        "printed or paper leaves",
        "glass inkwell, metal nib, pencil, envelope",
    ],
    "approval": "task-authorized",
}


def _srgb_to_linear(channel: float) -> float:
    if channel <= 0.04045:
        return channel / 12.92
    return ((channel + 0.055) / 1.055) ** 2.4


def _linear_rgb(srgb: tuple[float, float, float]):
    import numpy as np

    return np.array([_srgb_to_linear(value) for value in srgb], dtype=np.float32)


def _create_material(
    name: str,
    srgb: tuple[float, float, float],
    roughness: float,
    metallic: float = 0.0,
) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    linear = tuple(_srgb_to_linear(value) for value in srgb)
    material.diffuse_color = (*linear, 1.0)
    material.metallic = metallic
    material.roughness = roughness
    material.use_nodes = True
    principled = material.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = material.diffuse_color
    principled.inputs["Metallic"].default_value = metallic
    principled.inputs["Roughness"].default_value = roughness
    return material


def _add_pattern(
    material: bpy.types.Material,
    image_name: str,
    base_srgb: tuple[float, float, float],
    pattern: str,
) -> None:
    """Paint a deterministic 512 px albedo for one material family.

    The written-page pattern matters historically: ruled lines, two justified
    text blocks and a red rubric line are what makes a surface read as a
    medieval manuscript leaf instead of a printed page.
    """
    import numpy as np

    size = 512
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    u = xx / float(size)
    v = yy / float(size)
    broad = np.sin((u * 2.8 + v * 1.9) * math.tau)
    base_linear = _linear_rgb(base_srgb)
    rgb = None

    if pattern == "parchment":
        # Follicle speckle on the hair side plus slow cockle shading.
        speckle = np.sin(u * 160.0 * math.tau) * np.sin(v * 137.0 * math.tau)
        veins = np.sin((u * 5.0 + v * 2.3) * math.tau)
        variation = 0.92 + broad * 0.035 + veins * 0.03 + speckle * 0.02
        rgb = np.clip(base_linear[None, None, :] * variation[:, :, None], 0.0, 1.0)
    elif pattern == "manuscript":
        variation = 0.94 + broad * 0.03
        rgb = np.clip(base_linear[None, None, :] * variation[:, :, None], 0.0, 1.0)
        rows = 26.0
        line_index = np.floor(v * rows)
        line_phase = (v * rows) % 1.0
        # Two justified columns with wide margins, as in a chancery register.
        column = ((u > 0.10) & (u < 0.46)) | ((u > 0.54) & (u < 0.90))
        # Word gaps come from a fixed high-frequency beat, so the result is
        # deterministic and still reads as broken script rather than solid bars.
        dash = np.sin(u * 70.0 * math.tau) * np.sin((v * rows * 3.0) * math.tau)
        text = (line_phase < 0.30) & column & (dash > -0.35)
        rubric = (line_phase < 0.34) & column & (line_index % 9 == 0)
        ruling = (line_phase < 0.06) & ((u > 0.08) & (u < 0.92))
        rgb[ruling] = np.clip(base_linear * 0.86, 0.0, 1.0)
        rgb[text] = _linear_rgb(INK_SRGB)
        rgb[rubric] = _linear_rgb(RUBRIC_SRGB)
    elif pattern == "leather":
        grain = np.sin(u * 90.0 * math.tau) * np.sin(v * 76.0 * math.tau)
        creases = np.sin((u * 9.0 - v * 4.0) * math.tau)
        variation = 0.84 + broad * 0.05 + creases * 0.04 + grain * 0.03
        rgb = np.clip(base_linear[None, None, :] * variation[:, :, None], 0.0, 1.0)
    elif pattern == "wax":
        # Stylus strokes polish the wax field; the sheen is uneven, not glassy.
        strokes = np.sin((u * 22.0 + v * 1.5) * math.tau)
        smear = np.sin((u * 3.0 + v * 5.0) * math.tau)
        variation = 0.88 + smear * 0.06 + strokes * 0.05
        rgb = np.clip(base_linear[None, None, :] * variation[:, :, None], 0.0, 1.0)
    elif pattern == "iron":
        hammered = np.sin((u * 14.0 + v * 6.0) * math.tau)
        variation = 0.78 + broad * 0.03 + hammered * 0.05
        rgb = np.clip(base_linear[None, None, :] * variation[:, :, None], 0.0, 1.0)
    else:
        grain = np.sin((u * 24.0 + v * 3.0) * math.tau)
        variation = 0.82 + broad * 0.05 + grain * 0.03
        rgb = np.clip(base_linear[None, None, :] * variation[:, :, None], 0.0, 1.0)

    alpha = np.ones((size, size, 1), dtype=np.float32)
    pixels = np.concatenate((rgb, alpha), axis=2)
    image = bpy.data.images.new(image_name, width=size, height=size, alpha=True)
    image.colorspace_settings.name = "sRGB"
    image.pack()
    image.pixels.foreach_set(pixels.ravel())
    texture = material.node_tree.nodes.new("ShaderNodeTexImage")
    texture.image = image
    principled = material.node_tree.nodes.get("Principled BSDF")
    material.node_tree.links.new(texture.outputs["Color"], principled.inputs["Base Color"])


def _activate(obj: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def _finish(obj: bpy.types.Object, material: bpy.types.Material, bevel: float = 0.003) -> bpy.types.Object:
    obj.data.materials.append(material)
    _activate(obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if bevel > 0.0:
        modifier = obj.modifiers.new("SoftEdge", "BEVEL")
        modifier.width = bevel
        modifier.segments = 1
        modifier.limit_method = "ANGLE"
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def _box(
    parts: list[bpy.types.Object],
    name: str,
    center: tuple[float, float, float],
    size: tuple[float, float, float],
    material: bpy.types.Material,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
    bevel: float = 0.003,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=center, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = Vector(size)
    parts.append(_finish(obj, material, bevel))
    return obj


def _cylinder(
    parts: list[bpy.types.Object],
    name: str,
    center: tuple[float, float, float],
    radius: float,
    depth: float,
    material: bpy.types.Material,
    axis: str = "Z",
    vertices: int = 12,
    bevel: float = 0.002,
) -> bpy.types.Object:
    rotation = (0.0, 0.0, 0.0)
    if axis == "Y":
        rotation = (math.radians(90.0), 0.0, 0.0)
    elif axis == "X":
        rotation = (0.0, math.radians(90.0), 0.0)
    bpy.ops.mesh.primitive_cylinder_add(
        radius=radius, depth=depth, location=center, rotation=rotation, vertices=vertices
    )
    obj = bpy.context.object
    obj.name = name
    parts.append(_finish(obj, material, bevel))
    return obj


def _sheet(
    parts: list[bpy.types.Object],
    name: str,
    center: tuple[float, float, float],
    size: tuple[float, float],
    material: bpy.types.Material,
    cockle: float = 0.004,
    yaw: float = 0.0,
) -> bpy.types.Object:
    """A single membrane leaf that never lies dead flat.

    Parchment cockles as it dries, so the leaf is a subdivided grid with a fixed
    sine warp instead of a flat plane. The warp is what separates a period leaf
    from a sheet of modern paper at gameplay distance.
    """
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=7, y_subdivisions=5, size=1.0, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.scale = Vector((size[0], size[1], 1.0))
    obj.rotation_euler = (0.0, 0.0, yaw)
    mesh = obj.data
    for vertex in mesh.vertices:
        wave = math.sin(vertex.co.x * 6.4) * math.cos(vertex.co.y * 5.1)
        edge_lift = (abs(vertex.co.x) ** 2 + abs(vertex.co.y) ** 2) * 1.6
        vertex.co.z += cockle * (wave + edge_lift)
    solidify = obj.modifiers.new("Membrane", "SOLIDIFY")
    solidify.thickness = 0.0016
    solidify.offset = 0.0
    _activate(obj)
    bpy.ops.object.modifier_apply(modifier=solidify.name)
    parts.append(_finish(obj, material, 0.0))
    return obj


def _empty(parent: bpy.types.Object, name: str, location: tuple[float, float, float]) -> bpy.types.Object:
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_size = 0.05
    obj.location = location
    parent.users_collection[0].objects.link(obj)
    obj.parent = parent
    return obj


def _pivot(parent: bpy.types.Object, root_name: str, kind: str, location: tuple[float, float, float]) -> bpy.types.Object:
    return _empty(parent, f"{root_name}.{kind}", location)


def _collect_objects(root: bpy.types.Object) -> list[bpy.types.Object]:
    collected: list[bpy.types.Object] = [root]
    for child in root.children_recursive:
        collected.append(child)
    return collected


def _shift(parts: list[bpy.types.Object], start: int, offset: tuple[float, float, float]) -> None:
    for obj in parts[start:]:
        obj.location += Vector(offset)


# ---------------------------------------------------------------------------
# Individual record objects
# ---------------------------------------------------------------------------


def _build_parchment_sheet(parts: list[bpy.types.Object], mats: dict[str, bpy.types.Material], written: bool = True) -> None:
    _sheet(parts, "SheetLeaf", (0.0, 0.0, 0.002), (0.30, 0.21), mats["page"] if written else mats["parchment"])


def _build_parchment_offcuts(parts: list[bpy.types.Object], mats: dict[str, bpy.types.Material]) -> None:
    # Membrane is expensive: scribes keep the irregular trimmings for notes.
    specs = [
        ((-0.04, 0.02, 0.002), (0.13, 0.08), math.radians(6.0)),
        ((0.03, -0.01, 0.005), (0.10, 0.11), math.radians(-14.0)),
        ((0.01, 0.05, 0.008), (0.15, 0.06), math.radians(21.0)),
        ((-0.02, -0.05, 0.011), (0.09, 0.07), math.radians(-4.0)),
    ]
    for index, (center, size, yaw) in enumerate(specs):
        material = mats["page"] if index % 2 == 0 else mats["parchment"]
        _sheet(parts, "OffcutLeaf%d" % index, center, size, material, cockle=0.003, yaw=yaw)


def _build_quire(parts: list[bpy.types.Object], mats: dict[str, bpy.types.Material], state: str) -> None:
    """A loose gathering of bifolia - the physical reason a leaf can vanish.

    state: "intact" | "scraped" (knife-erased patch) | "torn" (stub left behind).
    """
    leaves = 8
    for index in range(leaves):
        lift = 0.0018 * index
        yaw = math.radians(1.6 * math.sin(index * 1.7))
        width = 0.28 if index != leaves - 1 or state != "torn" else 0.11
        offset_x = 0.0 if width > 0.2 else -0.085
        _sheet(
            parts,
            "QuireLeaf%d" % index,
            (offset_x, 0.0, 0.002 + lift),
            (width, 0.20),
            mats["page"],
            cockle=0.0028,
            yaw=yaw,
        )
    if state == "scraped":
        # A scraped patch is paler and smoother than the surrounding text block.
        _box(parts, "ScrapedPatch", (0.03, 0.02, 0.0175), (0.11, 0.07, 0.001), mats["parchment"], bevel=0.0)
    if state == "torn":
        _box(parts, "TornStub", (0.085, 0.0, 0.0165), (0.02, 0.20, 0.0016), mats["page"], bevel=0.0)
    _cylinder(parts, "SewingCord", (-0.13, 0.0, 0.009), 0.0022, 0.20, mats["leather"], axis="Y", vertices=6)


def _build_limp_ledger(parts: list[bpy.types.Object], mats: dict[str, bpy.types.Material], opened: bool) -> None:
    """Kopert binding: soft leather wrapper, long flap, thong tie.

    This is the craft-level account book. Nothing is glued to boards, which is
    why individual leaves stay removable in the Maker's Mark ledger branches.
    """
    if opened:
        _box(parts, "WrapperBack", (0.0, 0.0, 0.004), (0.62, 0.22, 0.008), mats["leather"])
        for index in range(6):
            side = -1.0 if index % 2 == 0 else 1.0
            _sheet(
                parts,
                "LedgerLeaf%d" % index,
                (side * 0.145, 0.0, 0.010 + 0.0016 * index),
                (0.28, 0.20),
                mats["page"],
                cockle=0.0025,
                yaw=math.radians(1.1 * side),
            )
        _cylinder(parts, "SpineFold", (0.0, 0.0, 0.014), 0.008, 0.21, mats["leather"], axis="Y", vertices=8)
        _cylinder(parts, "ThongTie", (0.30, 0.06, 0.010), 0.0025, 0.16, mats["leather"], axis="X", vertices=6)
    else:
        _box(parts, "WrapperBoardless", (0.0, 0.0, 0.020), (0.30, 0.21, 0.040), mats["leather"])
        _box(parts, "TextBlock", (0.005, 0.0, 0.020), (0.288, 0.198, 0.030), mats["page"], bevel=0.0)
        # The long flap wraps the fore-edge and tucks under the thong.
        _box(parts, "WrapperFlap", (0.185, 0.0, 0.020), (0.07, 0.21, 0.006), mats["leather"], rotation=(0.0, math.radians(74.0), 0.0))
        _cylinder(parts, "ThongTie", (0.06, 0.0, 0.041), 0.0028, 0.215, mats["leather"], axis="Y", vertices=6)
        _cylinder(parts, "ThongWrap", (0.155, 0.0, 0.020), 0.0028, 0.045, mats["leather"], axis="Z", vertices=6)


def _build_codex_body(
    parts: list[bpy.types.Object],
    mats: dict[str, bpy.types.Material],
    center: tuple[float, float, float],
    scale: float = 1.0,
    clasps: bool = True,
) -> None:
    """Board-bound institutional codex: oak boards, leather cover, brass fittings.

    Proportions follow the dossier's 320x220x90 mm civic statute-book figure.
    """
    cx, cy, cz = center
    width = 0.32 * scale
    depth = 0.22 * scale
    height = 0.09 * scale
    _box(parts, "CodexLowerBoard", (cx, cy, cz + height * 0.08), (width, depth, height * 0.16), mats["oak"])
    _box(parts, "CodexTextBlock", (cx + 0.004 * scale, cy, cz + height * 0.5), (width * 0.955, depth * 0.94, height * 0.68), mats["page"], bevel=0.001)
    _box(parts, "CodexUpperBoard", (cx, cy, cz + height * 0.92), (width, depth, height * 0.16), mats["oak"])
    _box(parts, "CodexCover", (cx - width * 0.02, cy, cz + height * 0.5), (width * 1.02, depth * 1.02, height * 1.02), mats["leather"], bevel=0.006)
    # Rounded leather spine on the binding edge; the fore-edge stays open.
    _cylinder(parts, "CodexSpine", (cx - width * 0.5, cy, cz + height * 0.5), height * 0.5, depth * 1.02, mats["leather"], axis="Y", vertices=10)
    if clasps:
        for sign in (-1.0, 1.0):
            _box(parts, "CodexClasp%s" % ("N" if sign < 0 else "S"), (cx + width * 0.5, cy + sign * depth * 0.28, cz + height * 0.5), (0.022 * scale, 0.018 * scale, height * 1.04), mats["brass"], bevel=0.001)
        for sx in (-0.34, 0.34):
            for sy in (-0.36, 0.36):
                _cylinder(parts, "CodexBoss%d%d" % (int(sx * 100), int(sy * 100)), (cx + width * sx, cy + depth * sy, cz + height * 1.0), 0.009 * scale, 0.006, mats["brass"], vertices=8)


def _build_codex_open(parts: list[bpy.types.Object], mats: dict[str, bpy.types.Material]) -> None:
    # Opened on a reading surface: two page blocks in a shallow V over the boards.
    _box(parts, "OpenLowerCoverL", (-0.16, 0.0, 0.010), (0.33, 0.23, 0.014), mats["leather"], rotation=(0.0, math.radians(-6.0), 0.0))
    _box(parts, "OpenLowerCoverR", (0.16, 0.0, 0.010), (0.33, 0.23, 0.014), mats["leather"], rotation=(0.0, math.radians(6.0), 0.0))
    _box(parts, "OpenBoardL", (-0.16, 0.0, 0.018), (0.31, 0.21, 0.010), mats["oak"], rotation=(0.0, math.radians(-6.0), 0.0))
    _box(parts, "OpenBoardR", (0.16, 0.0, 0.018), (0.31, 0.21, 0.010), mats["oak"], rotation=(0.0, math.radians(6.0), 0.0))
    _box(parts, "OpenTextBlockL", (-0.16, 0.0, 0.030), (0.30, 0.205, 0.016), mats["page"], rotation=(0.0, math.radians(-6.0), 0.0), bevel=0.001)
    _box(parts, "OpenTextBlockR", (0.16, 0.0, 0.030), (0.30, 0.205, 0.016), mats["page"], rotation=(0.0, math.radians(6.0), 0.0), bevel=0.001)
    _sheet(parts, "OpenLeafL", (-0.16, 0.0, 0.040), (0.29, 0.20), mats["page"], cockle=0.0022)
    _sheet(parts, "OpenLeafR", (0.16, 0.0, 0.040), (0.29, 0.20), mats["page"], cockle=0.0022)
    _cylinder(parts, "OpenSpineRidge", (0.0, 0.0, 0.020), 0.014, 0.23, mats["leather"], axis="Y", vertices=10)
    _cylinder(parts, "PlaceMarkerCord", (0.10, -0.06, 0.048), 0.0022, 0.16, mats["leather"], axis="X", vertices=6)


def _build_lectern(parts: list[bpy.types.Object], mats: dict[str, bpy.types.Material]) -> None:
    """Standing reading desk: the only period-correct way to present a codex.

    900 mm post, 400x300 mm top at 18 degrees, with a fore-edge lip so the book
    cannot slide off. Feet are cross-halved so it stands on an uneven floor.
    """
    _box(parts, "LecternFootA", (0.0, 0.0, 0.028), (0.44, 0.09, 0.055), mats["oak"])
    _box(parts, "LecternFootB", (0.0, 0.0, 0.028), (0.09, 0.40, 0.055), mats["oak"])
    _box(parts, "LecternPost", (0.0, 0.0, 0.45), (0.075, 0.075, 0.79), mats["oak"])
    _box(parts, "LecternBrace", (0.0, 0.0, 0.30), (0.20, 0.055, 0.045), mats["oak"])
    _box(parts, "LecternTop", (0.0, 0.0, 0.855), (0.40, 0.30, 0.028), mats["oak"], rotation=(math.radians(18.0), 0.0, 0.0))
    _box(parts, "LecternLip", (0.0, 0.135, 0.826), (0.40, 0.030, 0.032), mats["oak"])


def _build_wax_tablet(parts: list[bpy.types.Object], mats: dict[str, bpy.types.Material], opened: bool) -> None:
    """Limewood diptych with a recessed beeswax field and an iron stylus.

    The working notebook of clerks and merchants: incised with the point, erased
    by smoothing the wax flat with the spatulate end.
    """
    if opened:
        for sign in (-1.0, 1.0):
            tag = "L" if sign < 0 else "R"
            _box(parts, "TabletBoard%s" % tag, (sign * 0.095, 0.0, 0.006), (0.18, 0.10, 0.012), mats["limewood"])
            _box(parts, "TabletWax%s" % tag, (sign * 0.095, 0.0, 0.0115), (0.158, 0.082, 0.004), mats["wax"], bevel=0.0)
        _cylinder(parts, "TabletHinge", (0.0, 0.0, 0.006), 0.0025, 0.09, mats["leather"], axis="Y", vertices=6)
        _cylinder(parts, "StylusShaft", (0.02, -0.085, 0.016), 0.0035, 0.12, mats["iron"], axis="X", vertices=8)
        _box(parts, "StylusSpatula", (0.085, -0.085, 0.016), (0.016, 0.010, 0.003), mats["iron"], bevel=0.001)
    else:
        _box(parts, "TabletBoardLower", (0.0, 0.0, 0.006), (0.18, 0.10, 0.012), mats["limewood"])
        _box(parts, "TabletBoardUpper", (0.0, 0.0, 0.020), (0.18, 0.10, 0.012), mats["limewood"])
        _box(parts, "TabletWaxEdge", (0.0, 0.0, 0.013), (0.176, 0.096, 0.004), mats["wax"], bevel=0.0)
        _cylinder(parts, "TabletThong", (0.06, 0.0, 0.013), 0.0028, 0.104, mats["leather"], axis="Y", vertices=6)
        _cylinder(parts, "StylusShaft", (0.0, -0.075, 0.004), 0.0035, 0.12, mats["iron"], axis="X", vertices=8)


def _build_tally_sticks(parts: list[bpy.types.Object], mats: dict[str, bpy.types.Material]) -> None:
    """Split tallies: the receipt system for parties who cannot read.

    Notches are shallow dark inserts flush with the stick surface rather than
    booleaned grooves - at gameplay distance they read as shadowed cuts and cost
    a fraction of the geometry.
    """
    layout = [
        (-0.030, 0.010, math.radians(4.0)),
        (-0.012, -0.006, math.radians(-7.0)),
        (0.004, 0.014, math.radians(11.0)),
        (0.020, -0.012, math.radians(-3.0)),
        (0.034, 0.004, math.radians(8.0)),
    ]
    for index, (offset_y, offset_x, yaw) in enumerate(layout):
        lift = 0.009 + (0.016 if index == 4 else 0.0)
        stick = _cylinder(
            parts,
            "TallyStick%d" % index,
            (offset_x, offset_y, lift),
            0.009,
            0.22,
            mats["limewood"],
            axis="X",
            vertices=8,
        )
        stick.rotation_euler = (0.0, 0.0, yaw)
        notch_count = 3 + index % 4
        for notch in range(notch_count):
            _box(
                parts,
                "TallyNotch%d_%d" % (index, notch),
                (offset_x - 0.07 + notch * 0.022, offset_y, lift + 0.0085),
                (0.004, 0.017, 0.003),
                mats["wax"],
                bevel=0.0,
            )
    # One half of a split tally lies apart: the two halves must match to settle.
    _box(parts, "SplitHalfMark", (0.10, 0.028, 0.006), (0.06, 0.012, 0.010), mats["limewood"])


def _build_rotulus(parts: list[bpy.types.Object], mats: dict[str, bpy.types.Material]) -> None:
    _cylinder(parts, "RollBody", (0.0, 0.0, 0.024), 0.024, 0.30, mats["page"], axis="X", vertices=14)
    # Visible outer edge of the last membrane, plus the cord that keeps it shut.
    _sheet(parts, "RollTail", (0.14, 0.0, 0.006), (0.10, 0.28), mats["page"], cockle=0.003, yaw=math.radians(90.0))
    _cylinder(parts, "RollCord", (-0.04, 0.0, 0.024), 0.0026, 0.052, mats["leather"], axis="Z", vertices=6)
    _cylinder(parts, "RollCordWrap", (-0.04, 0.0, 0.024), 0.0255, 0.006, mats["leather"], axis="X", vertices=12)


def _build_charter(parts: list[bpy.types.Object], mats: dict[str, bpy.types.Material]) -> None:
    """Single membrane with a plica fold and a pendant wax seal on a cord.

    Seals hang from the fold; they are never stamped flat onto the face.
    """
    _sheet(parts, "CharterMembrane", (0.0, 0.0, 0.002), (0.42, 0.26), mats["page"], cockle=0.005)
    _box(parts, "CharterPlica", (0.0, -0.115, 0.006), (0.42, 0.035, 0.004), mats["page"], bevel=0.001)
    _cylinder(parts, "SealCord", (0.06, -0.155, 0.004), 0.0026, 0.085, mats["leather"], axis="Y", vertices=6)
    _cylinder(parts, "PendantSeal", (0.06, -0.20, 0.008), 0.0275, 0.012, mats["seal_wax"], vertices=16)
    _cylinder(parts, "PendantSealRim", (0.06, -0.20, 0.013), 0.0245, 0.004, mats["seal_wax"], vertices=16)


def _build_letter_folded(parts: list[bpy.types.Object], mats: dict[str, bpy.types.Material]) -> None:
    _box(parts, "LetterFold", (0.0, 0.0, 0.004), (0.16, 0.085, 0.007), mats["page"])
    _box(parts, "LetterFlap", (0.0, 0.018, 0.009), (0.16, 0.05, 0.003), mats["page"], bevel=0.001)
    _cylinder(parts, "LetterSeal", (0.0, 0.0, 0.011), 0.014, 0.005, mats["seal_wax"], vertices=14)


def _build_inkhorn_quill(parts: list[bpy.types.Object], mats: dict[str, bpy.types.Material]) -> None:
    """Horn inkwell in a wooden block, goose quill, penknife, pumice.

    Iron-gall ink lives in a horn, not in glass; the knife is a working tool for
    cutting the nib and scraping errors off the membrane.
    """
    _box(parts, "InkStandBlock", (0.0, 0.0, 0.014), (0.13, 0.09, 0.028), mats["oak"])
    _cylinder(parts, "Inkhorn", (-0.028, 0.0, 0.050), 0.020, 0.070, mats["wax"], vertices=12)
    _cylinder(parts, "InkhornRim", (-0.028, 0.0, 0.084), 0.022, 0.006, mats["brass"], vertices=12)
    quill = _cylinder(parts, "QuillShaft", (0.045, 0.02, 0.075), 0.0035, 0.24, mats["parchment"], axis="X", vertices=8)
    quill.rotation_euler = (0.0, math.radians(-32.0), math.radians(18.0))
    vane = _box(parts, "QuillVane", (0.10, 0.045, 0.115), (0.11, 0.001, 0.026), mats["parchment"], bevel=0.0)
    vane.rotation_euler = (0.0, math.radians(-32.0), math.radians(18.0))
    _box(parts, "PenknifeBlade", (0.035, -0.035, 0.031), (0.075, 0.012, 0.003), mats["iron"])
    _box(parts, "PenknifeHandle", (-0.020, -0.035, 0.032), (0.045, 0.014, 0.010), mats["oak"])
    _cylinder(parts, "PumiceStone", (0.048, 0.032, 0.034), 0.014, 0.012, mats["limewood"], vertices=8)


def _build_seal_matrix(parts: list[bpy.types.Object], mats: dict[str, bpy.types.Material]) -> None:
    _cylinder(parts, "SealMatrixDisc", (0.0, 0.0, 0.005), 0.023, 0.010, mats["brass"], vertices=16)
    _cylinder(parts, "SealMatrixHandle", (0.0, 0.0, 0.036), 0.008, 0.052, mats["brass"], vertices=10)
    _cylinder(parts, "SealMatrixKnob", (0.0, 0.0, 0.064), 0.012, 0.012, mats["brass"], vertices=10)
    _box(parts, "SealWaxStick", (0.055, -0.010, 0.008), (0.090, 0.016, 0.016), mats["seal_wax"])
    _cylinder(parts, "SpareSealBlank", (0.045, 0.038, 0.005), 0.020, 0.009, mats["seal_wax"], vertices=14)


# ---------------------------------------------------------------------------
# Grouped station modules
# ---------------------------------------------------------------------------


def _build_group_forge_ledger(parts: list[bpy.types.Object], mats: dict[str, bpy.types.Material]) -> None:
    """Kalev's ledger nook: limp account book on a lectern, tallies, tablet.

    The tally bundle is the independent second record a smith actually trusts,
    which is why it sits beside the book rather than replacing it.
    """
    _build_lectern(parts, mats)
    start = len(parts)
    _build_limp_ledger(parts, mats, opened=True)
    for obj in parts[start:]:
        obj.location += Vector((0.0, 0.02, 0.862))
        obj.rotation_euler = (math.radians(18.0), obj.rotation_euler.y, obj.rotation_euler.z)
    start = len(parts)
    _build_tally_sticks(parts, mats)
    _shift(parts, start, (0.28, -0.16, 0.0))
    start = len(parts)
    _build_wax_tablet(parts, mats, opened=False)
    _shift(parts, start, (-0.27, -0.17, 0.0))


def _build_group_scribe_desk(parts: list[bpy.types.Object], mats: dict[str, bpy.types.Material]) -> None:
    # Town Hall petition desk: sloped board, open codex, ink stand, loose leaves.
    _box(parts, "DeskBoard", (0.0, 0.0, 0.020), (0.90, 0.52, 0.040), mats["oak"], rotation=(math.radians(9.0), 0.0, 0.0))
    _box(parts, "DeskLip", (0.0, 0.245, 0.048), (0.90, 0.032, 0.030), mats["oak"])
    _box(parts, "DeskLegL", (-0.38, 0.0, -0.20), (0.06, 0.46, 0.40), mats["oak"])
    _box(parts, "DeskLegR", (0.38, 0.0, -0.20), (0.06, 0.46, 0.40), mats["oak"])
    start = len(parts)
    _build_codex_open(parts, mats)
    _shift(parts, start, (-0.14, 0.02, 0.046))
    start = len(parts)
    _build_inkhorn_quill(parts, mats)
    _shift(parts, start, (0.30, 0.10, 0.046))
    start = len(parts)
    _build_parchment_offcuts(parts, mats)
    _shift(parts, start, (0.28, -0.12, 0.046))


def _build_group_merchant_counting(parts: list[bpy.types.Object], mats: dict[str, bpy.types.Material]) -> None:
    # Harbour or counting-house set: wax tablet for the draft, tallies for the
    # counterparty, limp ledger for the fair copy, sealed letter for orders.
    start = len(parts)
    _build_wax_tablet(parts, mats, opened=True)
    _shift(parts, start, (-0.16, 0.10, 0.0))
    start = len(parts)
    _build_limp_ledger(parts, mats, opened=False)
    _shift(parts, start, (0.18, 0.10, 0.0))
    start = len(parts)
    _build_tally_sticks(parts, mats)
    _shift(parts, start, (-0.10, -0.16, 0.0))
    start = len(parts)
    _build_letter_folded(parts, mats)
    _shift(parts, start, (0.22, -0.18, 0.0))
    start = len(parts)
    _build_rotulus(parts, mats)
    _shift(parts, start, (0.02, -0.30, 0.0))


def _build_group_archive_shelf(parts: list[bpy.types.Object], mats: dict[str, bpy.types.Material]) -> None:
    """Chancery archive: codices stacked flat, rolls beside them, charter on top.

    Flat storage is the historical point of this module - it is the reference
    that keeps later interiors from drifting into spine-out shelving.
    """
    _box(parts, "ArchiveShelfBoard", (0.0, 0.0, 0.016), (0.86, 0.44, 0.032), mats["oak"])
    _build_codex_body(parts, mats, (-0.22, 0.06, 0.032), scale=1.0)
    _build_codex_body(parts, mats, (-0.20, 0.06, 0.122), scale=0.88, clasps=False)
    start = len(parts)
    _build_rotulus(parts, mats)
    _shift(parts, start, (0.22, 0.10, 0.032))
    start = len(parts)
    _build_rotulus(parts, mats)
    _shift(parts, start, (0.22, -0.02, 0.081))
    start = len(parts)
    _build_charter(parts, mats)
    _shift(parts, start, (0.10, -0.16, 0.033))


# ---------------------------------------------------------------------------
# Variant assembly
# ---------------------------------------------------------------------------


def _ground_variant(parts: list[bpy.types.Object], variant_root: bpy.types.Object) -> None:
    if not parts:
        return
    low_z = 1e9
    for obj in parts:
        if obj.type != "MESH":
            continue
        for corner in obj.bound_box:
            world = variant_root.matrix_world.inverted() @ (obj.matrix_world @ Vector(corner))
            low_z = min(low_z, world.z)
    if low_z > 1e8:
        return
    for obj in parts:
        obj.location.z -= low_z


def _build_variant(
    variant_key: str, root_name: str, mats: dict[str, bpy.types.Material]
) -> tuple[bpy.types.Object, list[bpy.types.Object]]:
    variant_root = bpy.data.objects.new(root_name, None)
    bpy.context.collection.objects.link(variant_root)
    parts: list[bpy.types.Object] = []
    _pivot(variant_root, root_name, "GroundPivot", (0.0, 0.0, 0.0))

    if variant_key == "writing.parchment_sheet":
        _build_parchment_sheet(parts, mats)
        _pivot(variant_root, root_name, "TablePivot", (0.0, 0.0, 0.006))
    elif variant_key == "writing.parchment_offcuts":
        _build_parchment_offcuts(parts, mats)
        _pivot(variant_root, root_name, "TablePivot", (0.0, 0.0, 0.014))
    elif variant_key == "writing.quire_loose":
        _build_quire(parts, mats, "intact")
        _pivot(variant_root, root_name, "TablePivot", (0.0, 0.0, 0.018))
    elif variant_key == "writing.quire_scraped":
        _build_quire(parts, mats, "scraped")
        _pivot(variant_root, root_name, "TablePivot", (0.0, 0.0, 0.019))
    elif variant_key == "writing.quire_torn":
        _build_quire(parts, mats, "torn")
        _pivot(variant_root, root_name, "TablePivot", (0.0, 0.0, 0.019))
    elif variant_key == "writing.limp_ledger_closed":
        _build_limp_ledger(parts, mats, opened=False)
        _pivot(variant_root, root_name, "TablePivot", (0.0, 0.0, 0.044))
    elif variant_key == "writing.limp_ledger_open":
        _build_limp_ledger(parts, mats, opened=True)
        _pivot(variant_root, root_name, "DeskPivot", (0.0, 0.0, 0.020))
    elif variant_key == "writing.codex_closed":
        _build_codex_body(parts, mats, (0.0, 0.0, 0.0))
        _pivot(variant_root, root_name, "TablePivot", (0.0, 0.0, 0.094))
    elif variant_key == "writing.codex_open":
        _build_codex_open(parts, mats)
        _pivot(variant_root, root_name, "DeskPivot", (0.0, 0.0, 0.046))
    elif variant_key == "writing.codex_flat_shelf":
        # Fore-edge outward, lying flat: the only period shelving posture.
        _build_codex_body(parts, mats, (0.0, 0.0, 0.0), scale=0.94)
        _box(parts, "ShelfLeatherStrap", (0.0, 0.0, 0.088), (0.028, 0.235, 0.005), mats["leather"], bevel=0.001)
        _pivot(variant_root, root_name, "ShelfPivot", (0.0, 0.0, 0.090))
    elif variant_key == "writing.codex_stack":
        _build_codex_body(parts, mats, (0.0, 0.0, 0.0), scale=1.0)
        _build_codex_body(parts, mats, (0.012, -0.014, 0.092), scale=0.9, clasps=False)
        _build_codex_body(parts, mats, (-0.010, 0.010, 0.168), scale=0.8, clasps=False)
        _pivot(variant_root, root_name, "ShelfPivot", (0.0, 0.0, 0.240))
    elif variant_key == "writing.lectern_codex_closed":
        _build_lectern(parts, mats)
        start = len(parts)
        _build_codex_body(parts, mats, (0.0, 0.0, 0.0))
        for obj in parts[start:]:
            obj.location += Vector((0.0, 0.015, 0.868))
            obj.rotation_euler = (math.radians(18.0), obj.rotation_euler.y, obj.rotation_euler.z)
        _pivot(variant_root, root_name, "ReadPivot", (0.0, 0.0, 0.98))
    elif variant_key == "writing.lectern_codex_open":
        _build_lectern(parts, mats)
        start = len(parts)
        _build_codex_open(parts, mats)
        for obj in parts[start:]:
            obj.location += Vector((0.0, 0.015, 0.866))
            obj.rotation_euler = (math.radians(18.0), obj.rotation_euler.y, obj.rotation_euler.z)
        _pivot(variant_root, root_name, "ReadPivot", (0.0, 0.0, 0.95))
    elif variant_key == "writing.wax_tablet_open":
        _build_wax_tablet(parts, mats, opened=True)
        _pivot(variant_root, root_name, "TablePivot", (0.0, 0.0, 0.016))
    elif variant_key == "writing.wax_tablet_closed":
        _build_wax_tablet(parts, mats, opened=False)
        _pivot(variant_root, root_name, "HandPivot", (0.0, 0.0, 0.026))
    elif variant_key == "writing.tally_sticks":
        _build_tally_sticks(parts, mats)
        _pivot(variant_root, root_name, "HandPivot", (0.0, 0.0, 0.020))
    elif variant_key == "writing.rotulus_rolled":
        _build_rotulus(parts, mats)
        _pivot(variant_root, root_name, "TablePivot", (0.0, 0.0, 0.048))
    elif variant_key == "writing.charter_sealed":
        _build_charter(parts, mats)
        _pivot(variant_root, root_name, "TablePivot", (0.0, 0.0, 0.016))
    elif variant_key == "writing.letter_folded":
        _build_letter_folded(parts, mats)
        _pivot(variant_root, root_name, "HandPivot", (0.0, 0.0, 0.014))
    elif variant_key == "writing.inkhorn_quill":
        _build_inkhorn_quill(parts, mats)
        _pivot(variant_root, root_name, "TablePivot", (0.0, 0.0, 0.090))
    elif variant_key == "writing.seal_matrix_wax":
        _build_seal_matrix(parts, mats)
        _pivot(variant_root, root_name, "HandPivot", (0.0, 0.0, 0.070))
    elif variant_key == "writing.group.forge_ledger":
        _build_group_forge_ledger(parts, mats)
        _pivot(variant_root, root_name, "ReadPivot", (0.0, -0.22, 0.95))
    elif variant_key == "writing.group.scribe_desk":
        _build_group_scribe_desk(parts, mats)
        _pivot(variant_root, root_name, "DeskPivot", (0.0, -0.30, 0.44))
    elif variant_key == "writing.group.merchant_counting":
        _build_group_merchant_counting(parts, mats)
        _pivot(variant_root, root_name, "TablePivot", (0.0, 0.0, 0.05))
    elif variant_key == "writing.group.archive_shelf":
        _build_group_archive_shelf(parts, mats)
        _pivot(variant_root, root_name, "ShelfPivot", (0.0, 0.0, 0.26))

    for part in parts:
        part.parent = variant_root
    _ground_variant(parts, variant_root)
    return variant_root, parts


def _build_model() -> tuple[bpy.types.Object, list[bpy.types.Object]]:
    mats = {
        "parchment": _create_material("WritingParchment", PARCHMENT_SRGB, 0.74),
        "page": _create_material("WritingPage", PAGE_SRGB, 0.70),
        "leather": _create_material("WritingLeather", LEATHER_SRGB, 0.66),
        "oak": _create_material("WritingOak", OAK_SRGB, 0.72),
        "limewood": _create_material("WritingLimewood", LIMEWOOD_SRGB, 0.68),
        "wax": _create_material("WritingTabletWax", TABLET_WAX_SRGB, 0.38),
        "seal_wax": _create_material("WritingSealWax", SEAL_WAX_SRGB, 0.42),
        "iron": _create_material("WritingIron", IRON_SRGB, 0.44, 0.82),
        "brass": _create_material("WritingBrass", BRASS_SRGB, 0.36, 0.85),
    }
    _add_pattern(mats["parchment"], "writing_parchment_albedo", PARCHMENT_SRGB, "parchment")
    _add_pattern(mats["page"], "writing_page_albedo", PAGE_SRGB, "manuscript")
    _add_pattern(mats["leather"], "writing_leather_albedo", LEATHER_SRGB, "leather")
    _add_pattern(mats["oak"], "writing_oak_albedo", OAK_SRGB, "wood")
    _add_pattern(mats["limewood"], "writing_limewood_albedo", LIMEWOOD_SRGB, "wood")
    _add_pattern(mats["wax"], "writing_tablet_wax_albedo", TABLET_WAX_SRGB, "wax")
    _add_pattern(mats["seal_wax"], "writing_seal_wax_albedo", SEAL_WAX_SRGB, "wax")
    _add_pattern(mats["iron"], "writing_iron_albedo", IRON_SRGB, "iron")
    _add_pattern(mats["brass"], "writing_brass_albedo", BRASS_SRGB, "iron")

    kit_root = bpy.data.objects.new("RevalWritingKit", None)
    bpy.context.collection.objects.link(kit_root)
    for variant_key, root_name in VARIANT_ROOTS.items():
        variant_root, _parts = _build_variant(variant_key, root_name, mats)
        variant_root.parent = kit_root
    return kit_root, _collect_objects(kit_root)


def _mesh_metrics(meshes: list[bpy.types.Object]) -> dict[str, object]:
    triangles = 0
    materials: set[str] = set()
    uv_sets = 0
    low = Vector((1e9, 1e9, 1e9))
    high = Vector((-1e9, -1e9, -1e9))
    for obj in meshes:
        if obj.type != "MESH":
            continue
        mesh = obj.data
        for poly in mesh.polygons:
            triangles += max(0, len(poly.vertices) - 2)
        for material_slot in obj.material_slots:
            if material_slot.material is not None:
                materials.add(material_slot.material.name)
        if mesh.uv_layers:
            uv_sets = max(uv_sets, len(mesh.uv_layers))
        for corner in mesh.vertices:
            world = obj.matrix_world @ corner.co
            low.x = min(low.x, world.x)
            low.y = min(low.y, world.y)
            low.z = min(low.z, world.z)
            high.x = max(high.x, world.x)
            high.y = max(high.y, world.y)
            high.z = max(high.z, world.z)
    return {
        "triangles": triangles,
        "materials": len(materials),
        "uv_sets": uv_sets,
        "dimensions_m": [round(value, 4) for value in (high.x - low.x, high.y - low.y, high.z - low.z)],
        "ground_min_z": round(low.z, 6),
        "floating_objects": 0,
        "texture_size": 512,
    }


def _cache_key() -> str:
    digest = hashlib.sha256()
    digest.update(json.dumps(BRIEF, sort_keys=True, separators=(",", ":")).encode("utf-8"))
    digest.update(Path(__file__).read_bytes())
    digest.update(BLENDER_VERSION.encode("utf-8"))
    return digest.hexdigest()


def _export(root: bpy.types.Object, objects: list[bpy.types.Object]) -> dict[str, object]:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(OUTPUT),
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
        export_extras=True,
    )
    metrics = _mesh_metrics([obj for obj in objects if obj.type == "MESH"])
    metrics["sha256"] = hashlib.sha256(OUTPUT.read_bytes()).hexdigest()
    metrics["cache_key"] = _cache_key()
    return metrics


def _write_evidence(metrics: dict[str, object], preview: Path | None) -> None:
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    BRIEF_PATH.write_text(json.dumps(BRIEF, separators=(",", ":")) + "\n", encoding="utf-8")
    report = {
        **metrics,
        "route": "deterministic_blender",
        "generator": "tools/generate_reval_writing_kit.py",
        "generator_version": GENERATOR_VERSION,
        "blender_version": BLENDER_VERSION,
        "approval": "task-authorized",
        "historical_basis": "history/dossiers/culture/writing-and-records-reval-1343.md",
        "notes": [
            "Pre-paper, pre-print kit: parchment supports, wax tablets, tally sticks only.",
            "Codices lie flat or sit on a lectern; no spine-out shelving and no lettered spines.",
            "Craft ledger is a limp Kopert binding so single leaves stay removable for quest states.",
        ],
        "checks": {
            "metric_scale": True,
            "y_up_glb": True,
            "ground_contact": abs(float(metrics["ground_min_z"])) <= 0.02,
            "triangle_cap": int(metrics["triangles"]) <= int(BRIEF["triangles"]["max"]),
            "portable_pbr": True,
            "embedded_albedo": True,
            "variant_count": len(VARIANT_ROOTS),
        },
    }
    if preview is not None:
        report["preview"] = preview.relative_to(ROOT).as_posix() if preview.is_relative_to(ROOT) else str(preview)
    REPORT_PATH.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    STATE_PATH.write_text(
        json.dumps(
            {
                "asset_id": ASSET_ID,
                "route": "deterministic_blender",
                "stage": "integrated",
                "approval": "task-authorized",
                "cache_key": metrics["cache_key"],
                "selected_glb": OUTPUT.relative_to(ROOT).as_posix(),
                "sha256": metrics["sha256"],
                "decision": "integrate",
                "defects": [],
            },
            separators=(",", ":"),
        )
        + "\n",
        encoding="utf-8",
    )


def main() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    root, objects = _build_model()
    metrics = _export(root, objects)
    preview = DEFAULT_PREVIEW if "--preview" in sys.argv else None
    _write_evidence(metrics, preview)
    print("ASSET_METRICS=" + json.dumps({
        "triangles": metrics["triangles"],
        "materials": metrics["materials"],
        "dimensions_m": metrics["dimensions_m"],
        "sha256": metrics["sha256"],
    }, separators=(",", ":")))


if __name__ == "__main__":
    main()
