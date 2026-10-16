#!/usr/bin/env python3
"""Build Kalev's forge weapon set (task R-1754) as deterministic Blender geometry.

Run from the repository root:
    blender --background --factory-startup --python tools/assets/build_forge_weapons.py -- --preview
    blender --background --factory-startup --python tools/assets/build_forge_weapons.py -- --only=longbow

Six weapons a 1343 Reval smithy could forge, keep or repair (see
history/dossiers/military/arms-and-armour-livonia-1340s.md): an arming sword, a
yew longbow, a socketed spear, a painted heater shield, a bearded axe and a war
hammer. Output: assets/props/weapons/<slug>/<slug>.glb.

Grip convention (what the Godot equip scenes rely on):
- The GLB origin is the centre of the right hand's grip; nothing is grounded.
- The weapon's long axis is glTF +Y (Blender +Z): blade, head or upper limb up.
- Edged and striking faces point along glTF +X (Blender +X).
- The shield's painted face looks along glTF +Z (Blender -Y), its origin is the
  hand on the enarmes behind the boards.

Materials, sweeps and GLB export are reused from tools/generate_medieval_hand_tools.py
so the weapons share the hand tools' hammered iron, polished edge and ash wood.
"""

from __future__ import annotations

import importlib.util
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
_HAND_TOOLS = ROOT / "tools" / "generate_medieval_hand_tools.py"
_spec = importlib.util.spec_from_file_location("medieval_hand_tools", _HAND_TOOLS)
HT = importlib.util.module_from_spec(_spec)
# dataclasses resolve string annotations through sys.modules.
sys.modules[_spec.name] = HT
_spec.loader.exec_module(HT)

GENERATOR = "tools/assets/build_forge_weapons.py"
GENERATOR_VERSION = "forge_weapons_v1"

# Extra surfaces on top of the hand tools' wood / iron / edge.
HT.PALETTE.update(
    {
        "leather": (0x4A / 255.0, 0x2C / 255.0, 0x18 / 255.0),
        "yew": (0x9C / 255.0, 0x5E / 255.0, 0x2E / 255.0),
        "paint": (0x8E / 255.0, 0x2A / 255.0, 0x1E / 255.0),
        "paint_dark": (0x2E / 255.0, 0x2A / 255.0, 0x24 / 255.0),
        "linen": (0xC8 / 255.0, 0xBA / 255.0, 0x98 / 255.0),
    }
)
_base_fields = HT._texture_fields


def _texture_fields(surface: str):
    """Leather and linen are matte and fine-grained; paint keeps the board grain."""
    import numpy as np

    if surface in ("wood", "iron", "edge"):
        return _base_fields(surface)
    if surface in ("yew", "paint", "paint_dark"):
        height, colour, roughness = _base_fields("wood")
        if surface == "yew":
            return height, colour, np.clip(roughness - 0.18, 0.55, 0.75).astype(np.float32)
        # Distemper paint on boards: flatter colour, grain still reads through.
        return height, (0.93 + (colour - colour.mean()) * 0.5).astype(np.float32), roughness
    size = HT.TEXTURE_SIZE
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    u = xx / float(size)
    v = yy / float(size)
    if surface == "leather":
        pebble = np.sin((u * 41.0 + np.sin(v * 13.0)) * math.tau) * np.sin((v * 37.0 - u * 5.0) * math.tau)
        height = 0.5 + pebble * 0.05
        colour = 0.9 + pebble * 0.05
        roughness = np.full_like(height, 0.86)
    else:
        weave = np.sin(u * math.tau * 60.0) * np.sin(v * math.tau * 60.0)
        height = 0.5 + weave * 0.04
        colour = 0.95 + weave * 0.03
        roughness = np.full_like(height, 0.9)
    return height.astype(np.float32), colour.astype(np.float32), roughness.astype(np.float32)


HT._texture_fields = _texture_fields


def weapon_glb(slug: str) -> Path:
    return ROOT / "assets" / "props" / "weapons" / slug / f"{slug}.glb"


def _spec_for(slug: str, root_name: str, dims, tris: int, target, camera, scale) -> "HT.AssetSpec":
    return HT.AssetSpec(
        f"prop.weapon.{slug}",
        slug,
        root_name,
        weapon_glb(slug),
        f"res://content/demo/item.forge_{slug}.json",
        dims,
        tris,
        target,
        camera,
        scale,
    )


SPECS = (
    _spec_for("arming_sword", "ArmingSword", (0.22, 1.02, 0.05), 3000, (0.0, 0.0, 0.51), (1.6, -2.4, 1.1), 1.25),
    _spec_for("longbow", "Longbow", (0.2, 1.8, 0.05), 3000, (0.0, 0.0, 0.9), (2.2, -3.4, 1.4), 2.05),
    _spec_for("spear", "Spear", (0.07, 2.25, 0.07), 2500, (0.0, 0.0, 1.12), (2.6, -3.8, 1.6), 2.5),
    # heater_shield retired by R-2013: the modelled shields come from tools/assets/equipment/build_shields.py.
    _spec_for("bearded_axe", "BeardedAxe", (0.26, 0.8, 0.05), 2500, (0.0, 0.0, 0.4), (1.4, -2.3, 1.0), 1.0),
    _spec_for("war_hammer", "WarHammer", (0.22, 0.78, 0.06), 2500, (0.0, 0.0, 0.4), (1.4, -2.3, 1.0), 1.0),
)


def _lens_blade(root, name: str, stations: list[tuple[float, float, float]], material, offset_x: float = 0.0):
    """Double-edged blade along +Z: each station is (z, half_width, half_thickness).

    A six-sided lens section (edge, flat, ridge on both faces) keeps the bevelled
    edges catching light from an isometric camera without a fuller texture.
    """
    import bmesh

    bm = bmesh.new()
    rings = []
    for z, half_width, half_thick in stations:
        ring_points = [
            (half_width, 0.0),
            (half_width * 0.45, half_thick * 0.7),
            (0.0, half_thick),
            (-half_width * 0.45, half_thick * 0.7),
            (-half_width, 0.0),
            (-half_width * 0.45, -half_thick * 0.7),
            (0.0, -half_thick),
            (half_width * 0.45, -half_thick * 0.7),
        ]
        rings.append([bm.verts.new((offset_x + x, y, z)) for x, y in ring_points])
    for i in range(len(rings) - 1):
        for j in range(8):
            k = (j + 1) % 8
            bm.faces.new((rings[i][j], rings[i][k], rings[i + 1][k], rings[i + 1][j]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    return HT._mesh_object(root, name, bm, [material])


def _profile_plate(root, name: str, outline: list[tuple[float, float]], thickness: float, material, y_center: float = 0.0):
    """Flat iron plate from an X/Z outline (axe blade): thin along Y, centred on y_center."""
    return HT._vertical_prism(root, name, outline, y_center - thickness * 0.5, y_center + thickness * 0.5, material)


def _build_arming_sword(root, m) -> list:
    # Oakeshott type XII-like arming sword: tapering blade, straight cross, wheel
    # pommel, leather-wrapped grip. Blade 0.80 m, overall ~1.02 m.
    blade = [
        (0.115, 0.026, 0.0045),
        (0.30, 0.0245, 0.0042),
        (0.55, 0.021, 0.0038),
        (0.75, 0.016, 0.0034),
        (0.86, 0.010, 0.0030),
        (0.905, 0.0015, 0.0012),
    ]
    return [
        _lens_blade(root, "Blade", blade, m["edge"]),
        HT._box(root, "Crossguard", (0.0, 0.0, 0.10), (0.22, 0.026, 0.024), m["iron"]),
        HT._tube(root, "LeatherGrip", [(0.0, 0.0, -0.085), (0.0, 0.0, 0.0), (0.0, 0.0, 0.088)], [0.0155, 0.0175, 0.0155], m["leather"], sides=10, samples=3),
        HT._cylinder_between(root, "WheelPommel", (0.0, -0.014, -0.112), (0.0, 0.014, -0.112), 0.030, m["iron"], 14),
    ]


def _build_longbow(root, m) -> list:
    # Strung yew self bow, ~1.8 m: the stave bows toward -X (away from the string),
    # string straight between horn nocks at x = +0.0. Grip at the origin.
    half = 0.88
    brace = 0.16
    points = []
    radii = []
    for step in range(13):
        t = -1.0 + step / 6.0
        z = t * half
        points.append((-brace * (1.0 - t * t) + brace * 0.0, 0.0, z))
        radii.append(0.0175 - 0.0085 * abs(t))
    objects = [
        HT._tube(root, "YewStave", points, radii, m["yew"], sides=10, samples=4, profile=(1.0, 0.82)),
        HT._tube(root, "LeatherGripWrap", [(-brace, 0.0, -0.06), (-brace, 0.0, 0.06)], [0.0195, 0.0195], m["leather"], sides=10, samples=2),
        HT._tube(root, "LinenString", [(0.0, 0.0, -half), (0.0, 0.0, half)], [0.0022, 0.0022], m["linen"], sides=6, samples=2),
    ]
    for sign, label in ((-1.0, "Lower"), (1.0, "Upper")):
        objects.append(
            HT._tube(root, f"{label}HornNock", [(0.0, 0.0, sign * (half - 0.03)), (0.0, 0.0, sign * (half + 0.025))], [0.010, 0.006], m["linen"], sides=8, samples=2)
        )
    # The grip is the stave, not the string: shift so the hand (origin) holds the wrap.
    for obj in objects:
        obj.location.x += brace
    return objects


def _build_spear(root, m) -> list:
    # Ash-shafted spear, 2.25 m: held a third of the way up, so the origin sits
    # 0.70 m above the butt. Leaf head on a socket with a rivet, iron butt cap.
    butt = -0.70
    top = 1.30
    leaf = [
        (top + 0.10, 0.012, 0.0055),
        (top + 0.17, 0.026, 0.0060),
        (top + 0.26, 0.022, 0.0052),
        (top + 0.36, 0.010, 0.0040),
        (top + 0.42, 0.0012, 0.0012),
    ]
    return [
        HT._tube(root, "AshShaft", [(0.0, 0.0, butt + 0.04), (0.0, 0.0, 0.3), (0.0, 0.0, top + 0.02)], [0.0155, 0.0150, 0.0135], m["wood"], sides=10, samples=4),
        HT._tube(root, "Socket", [(0.0, 0.0, top - 0.02), (0.0, 0.0, top + 0.11)], [0.0165, 0.0115], m["iron"], sides=10, samples=2),
        HT._cylinder_between(root, "SocketRivet", (-0.019, 0.0, top + 0.02), (0.019, 0.0, top + 0.02), 0.0035, m["iron"], 6),
        _lens_blade(root, "LeafHead", leaf, m["edge"]),
        HT._tube(root, "ButtCap", [(0.0, 0.0, butt), (0.0, 0.0, butt + 0.06)], [0.012, 0.0165], m["iron"], sides=10, samples=2),
    ]


def _build_bearded_axe(root, m) -> list:
    # Bearded axe, 0.80 m ash haft held near the foot: the beard sweeps down along
    # the haft so the hand can choke up behind it. Edge faces +X.
    head_z = 0.52
    blade = [
        (0.020, head_z + 0.035),
        (0.070, head_z + 0.045),
        (0.150, head_z + 0.075),
        (0.158, head_z + 0.010),
        (0.150, head_z - 0.080),
        (0.120, head_z - 0.150),
        (0.085, head_z - 0.165),
        (0.060, head_z - 0.090),
        (0.020, head_z - 0.030),
    ]
    return [
        HT._tube(root, "AshHaft", [(0.0, 0.0, -0.17), (-0.008, 0.0, 0.2), (0.0, 0.0, 0.62)], [0.0165, 0.0150, 0.0160], m["wood"], sides=10, samples=4),
        HT._box(root, "Eye", (0.0, 0.0, head_z), (0.045, 0.040, 0.075), m["iron"]),
        _profile_plate(root, "BeardedBlade", blade, 0.010, m["iron"]),
        _profile_plate(root, "PolishedEdge", [(0.146, head_z + 0.075), (0.162, head_z + 0.012), (0.154, head_z - 0.080), (0.124, head_z - 0.152), (0.116, head_z - 0.140), (0.142, head_z - 0.076), (0.148, head_z + 0.012), (0.136, head_z + 0.068)], 0.012, m["edge"]),
        HT._box(root, "Poll", (-0.035, 0.0, head_z), (0.03, 0.036, 0.055), m["iron"]),
    ]


def _build_war_hammer(root, m) -> list:
    # Horseman's war hammer, 0.78 m: square four-point face (+X), curved back
    # spike (-X), short top spike, iron langets riveted down the haft.
    head_z = 0.55
    spike = [(-0.025, 0.0, head_z), (-0.075, 0.0, head_z - 0.006), (-0.120, 0.0, head_z - 0.030)]
    objects = [
        HT._tube(root, "AshHaft", [(0.0, 0.0, -0.18), (0.0, 0.0, 0.2), (0.0, 0.0, head_z + 0.02)], [0.0165, 0.0150, 0.0145], m["wood"], sides=10, samples=3),
        HT._tube(root, "LeatherGrip", [(0.0, 0.0, -0.10), (0.0, 0.0, 0.08)], [0.0185, 0.0185], m["leather"], sides=10, samples=2),
        HT._box(root, "HeadCore", (0.0, 0.0, head_z), (0.05, 0.042, 0.055), m["iron"]),
        HT._box(root, "StrikingFace", (0.058, 0.0, head_z), (0.07, 0.044, 0.044), m["edge"]),
        HT._tube(root, "BackSpike", spike, [0.016, 0.010, 0.0015], m["edge"], sides=8, samples=4),
        HT._cylinder_between(root, "TopSpike", (0.0, 0.0, head_z + 0.025), (0.0, 0.0, head_z + 0.09), 0.012, m["edge"], 8, 0.0015),
    ]
    for side, label in ((-1.0, "Left"), (1.0, "Right")):
        objects.append(HT._box(root, f"{label}Langet", (0.0, side * 0.0165, head_z - 0.12), (0.014, 0.004, 0.20), m["iron"]))
    return objects


def _build_heater_shield(root, m) -> list:
    # Heater shield, 0.62 x 0.80 m, glued boards faced and painted, curved to wrap
    # the forearm. Face toward -Y (glTF +Z). Origin: the hand on the enarmes.
    import bmesh

    half_w = 0.31
    top = 0.43
    point = -0.37
    thickness = 0.016
    curve = 0.085
    back_y = -0.055  # the board's back at the centre, in front of the hand

    def bottom(x: float) -> float:
        return point + (0.06 - point) * (abs(x) / half_w) ** 1.7

    def surface_y(x: float, front: bool) -> float:
        y = back_y + curve * (x / half_w) ** 2
        return y - thickness if front else y

    cols = 16
    rows = 10
    rim = 0.028
    bm = bmesh.new()
    grids = {}
    for front in (True, False):
        grid = []
        for c in range(cols + 1):
            x = -half_w + 2.0 * half_w * c / cols
            z_low = bottom(x)
            column = []
            for r in range(rows + 1):
                z = z_low + (top - z_low) * r / rows
                column.append(bm.verts.new((x, surface_y(x, front), z)))
            grid.append(column)
        grids[front] = grid
    # Material 0: painted field; 1: dark painted border; 2: bare board edges/back.
    for front in (True, False):
        grid = grids[front]
        for c in range(cols):
            for r in range(rows):
                quad = (grid[c][r], grid[c + 1][r], grid[c + 1][r + 1], grid[c][r + 1])
                face = bm.faces.new(quad if not front else tuple(reversed(quad)))
                if front:
                    cx = -half_w + 2.0 * half_w * (c + 0.5) / cols
                    z_low = bottom(cx)
                    cz = z_low + (top - z_low) * (r + 0.5) / rows
                    border = abs(cx) > half_w - rim * 1.6 or cz > top - rim * 1.6 or r == 0
                    face.material_index = 1 if border else 0
                else:
                    face.material_index = 2
    front_grid = grids[True]
    back_grid = grids[False]
    boundary = (
        [(c, 0) for c in range(cols + 1)]
        + [(cols, r) for r in range(1, rows + 1)]
        + [(c, rows) for c in range(cols - 1, -1, -1)]
        + [(0, r) for r in range(rows - 1, 0, -1)]
    )
    for i, (c, r) in enumerate(boundary):
        c2, r2 = boundary[(i + 1) % len(boundary)]
        face = bm.faces.new((front_grid[c][r], front_grid[c2][r2], back_grid[c2][r2], back_grid[c][r]))
        face.material_index = 2
    shield = HT._mesh_object(root, "PaintedBoards", bm, [m["paint"], m["paint_dark"], m["wood"]])
    for poly in shield.data.polygons:
        poly.use_smooth = False
    objects = [shield]
    # Two leather enarmes (forearm strap and hand grip) on the back.
    for z, label in ((0.0, "HandEnarme"), (0.17, "ArmEnarme")):
        objects.append(HT._box(root, label, (0.0, back_y + 0.012, z), (0.20, 0.010, 0.032), m["leather"]))
    return objects


BUILDERS = {
    "arming_sword": (_build_arming_sword, "arming sword with tapering two-edged blade, straight cross and wheel pommel"),
    "longbow": (_build_longbow, "strung yew self bow with leather grip wrap, horn nocks and linen string"),
    "spear": (_build_spear, "ash-shafted spear with riveted socket, leaf-shaped head and iron butt cap"),
    "bearded_axe": (_build_bearded_axe, "bearded axe on an ash haft with a polished welded edge"),
    "war_hammer": (_build_war_hammer, "war hammer with four-point face, back spike, top spike and iron langets"),
}


def _build(spec, preview_enabled: bool) -> dict[str, object]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    HT.CUSTOM_UV_OBJECTS.clear()
    root = bpy.data.objects.new(spec.root_name, None)
    bpy.context.collection.objects.link(root)
    materials = {
        "wood": HT._create_material("WeaponAshWood", "wood", 0.0),
        "iron": HT._create_material("WeaponHammeredIron", "iron", 0.72),
        "edge": HT._create_material("WeaponPolishedEdge", "edge", 0.85),
        "leather": HT._create_material("WeaponLeather", "leather", 0.0),
        "yew": HT._create_material("WeaponYew", "yew", 0.0),
        "paint": HT._create_material("ShieldPaintRed", "paint", 0.0),
        "paint_dark": HT._create_material("ShieldPaintDark", "paint_dark", 0.0),
        "linen": HT._create_material("WeaponLinenHorn", "linen", 0.0),
    }
    builder, identity = BUILDERS[spec.slug]
    objects = builder(root, materials)
    bpy.context.view_layer.update()
    HT._prepare_meshes(objects)
    root["asset_id"] = spec.asset_id
    root["generator"] = GENERATOR
    root["generator_version"] = GENERATOR_VERSION
    root["blender_version"] = HT.BLENDER_VERSION
    root["historical_identity"] = f"1343 Livonian forge weapon: {identity}"
    root["grip_origin"] = "right-hand grip centre; long axis +Y; edge/face +X"
    metrics = HT._export(spec, root, objects)
    if preview_enabled:
        # The hand tools' preview floor sits at z=0; weapons are centred on the grip,
        # so lift the (already exported) root to stand the weapon on the floor.
        bpy.context.view_layer.update()
        low = min((obj.matrix_world @ Vector(c)).z for obj in objects for c in obj.bound_box)
        root.location.z -= low
        bpy.context.view_layer.update()
        preview = HT._render_preview(spec)
        metrics["preview"] = preview.relative_to(ROOT).as_posix()
    return metrics


def main() -> None:
    preview_enabled = "--preview" in sys.argv
    only: set[str] = set()
    for argument in sys.argv:
        if argument.startswith("--only="):
            only.update(s.strip() for s in argument.removeprefix("--only=").split(",") if s.strip())
    specs = [spec for spec in SPECS if not only or spec.slug in only]
    if only - {spec.slug for spec in specs}:
        raise ValueError(f"Unknown weapon slugs: {sorted(only - {spec.slug for spec in specs})}")
    report = []
    for spec in specs:
        metrics = _build(spec, preview_enabled)
        report.append(
            {
                "asset": spec.slug,
                "triangles": metrics["triangles"],
                "dimensions_m": metrics["dimensions_m"],
                "sha256": metrics["sha256"],
                "preview": metrics.get("preview", ""),
            }
        )
    print("ASSET_METRICS=" + json.dumps(report, separators=(",", ":")))


if __name__ == "__main__":
    main()
