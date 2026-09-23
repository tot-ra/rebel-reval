#!/usr/bin/env python3
"""Generate the production Reval 1343 merchant-stone frontage kit.

Run from the repository root:
    blender --background --factory-startup --python \
        tools/generate_burgher_house_merchant_stone.py -- --preview

The profile is the tall limestone merchant tier from R-003: a steep
street-facing gable carried up as a coped fire wall, raised diele threshold
behind a pointed stone portal, a large shuttered diele opening, a cellar neck
(Kellerhals), a stacked storage-hatch column with a hoisting beam, and a
monk-and-nun tile roof. It intentionally avoids late-Gothic glazed crosses,
blind niches, stepped display gables and tourist-monument enrichment.

Two variants share one material set:
- ``merchant_stone.glb``: narrow three-storey front in bare coursed rubble,
  old render surviving only in patches;
- ``merchant_stone_rendered.glb``: wider two-storey front under a flaking
  lime render, upper living-room openings beside the hatch column.
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HOUSE_DIR = ROOT / "assets" / "props" / "architecture" / "houses" / "merchant_stone"
EVIDENCE_DIR = ROOT / "generated" / "blender" / "burgher_house_merchant_stone_v1"
ASSET_ID = "prop.architecture.house.merchant_stone"

VARIANTS: list[dict[str, object]] = [
    {
        "asset_id": ASSET_ID,
        "variant": "coursed_rubble",
        "name": "MerchantStone",
        "output": HOUSE_DIR / "merchant_stone.glb",
        "plate": "street_gable.png",
        "rear_plate": "rear_yard.png",
        "width": 9.0,
        "depth": 9.6,
        "storeys": 3,
        "storey_h": 2.85,
        "wall": "rubble",
        "portal_x": -2.35,
        "window_x": 2.2,
        "sag": 0.07,
        "upper_windows": False,
    },
    {
        "asset_id": f"{ASSET_ID}.rendered",
        "variant": "lime_rendered_wide",
        "name": "MerchantStoneRendered",
        "output": HOUSE_DIR / "merchant_stone_rendered.glb",
        "plate": "street_gable_rendered.png",
        "rear_plate": "rear_yard_rendered.png",
        "width": 11.0,
        "depth": 9.6,
        "storeys": 2,
        "storey_h": 3.05,
        "wall": "render",
        "portal_x": -3.3,
        "window_x": -0.9,
        "cellar_x": 3.2,
        "sag": 0.1,
        "upper_windows": True,
    },
]

BRIEF = {
    "id": ASSET_ID,
    "kind": "rigid_architecture",
    "target": "res://assets/props/architecture/houses/merchant_stone/merchant_stone.glb",
    "variants": {
        "coursed_rubble": "res://assets/props/architecture/houses/merchant_stone/merchant_stone.glb",
        "lime_rendered_wide": "res://assets/props/architecture/houses/merchant_stone/merchant_stone_rendered.glb",
    },
    "tier": "merchant_stone",
    "dimensions_m": {"frontage": 9.0, "depth": 9.6, "typical_storeys": 3},
    "features": {
        "steep_gable_to_street": True,
        "limestone_or_mixed_front": True,
        "street_portal": True,
        "large_ground_opening": True,
        "upper_loading_hatches": True,
        "protruding_hoist_beam": True,
        "raised_cellar_neck": True,
        "tile_roof_band": True,
        "coped_parapet_gable": True,
        "putlog_holes": True,
        "weathering": [
            "rising_damp",
            "flaking_lime_render",
            "lost_coping_stone",
            "sagging_ridge",
            "roof_moss_and_lichen",
            "flue_soot",
            "skewed_shutter",
            "cracked_step",
        ],
        "late_gothic_facade": False,
    },
    "triangles": {"target": 9000, "max": 16000},
    "textures": {"albedo": 512, "normal": 512, "embedded": True},
    "style_refs": [
        "history/dossiers/architecture/burgher-house-plan.md",
        "docs/reports/burgher_house_art_brief.md",
        "docs/ART_BIBLE.md",
        "docs/MATERIAL_STYLE_LOCK_KIT.md",
    ],
    "approval": "task-authorized",
}


def build(kit, spec: dict[str, object], materials):
    house = kit.House(str(spec["name"]), materials, float(spec["width"]), float(spec["depth"]))
    at = kit.at
    width = house.width
    front = house.front
    storeys = int(spec["storeys"])
    storey_h = float(spec["storey_h"])
    eave = storeys * storey_h
    wall = str(spec["wall"])

    house.box("Plinth", (width + 0.16, house.depth + 0.16, 0.5), at(0.0, 0.0, 0.25), "rubble_dark", 0.03)
    house.box("Walls", (width, house.depth, eave), at(0.0, 0.0, eave * 0.5), wall, 0.02)
    roof = house.roof("tile", eave, 0.32, -0.55, -0.55, 0.2, float(spec["sag"]), 0.025)
    house.parapet_gable("GableFront", roof, -1.0, key=wall)
    house.parapet_gable("GableRear", roof, 1.0, key=wall)
    house.ridge_tiles(roof)
    house.roof_patches(roof, "tile", 2)

    avoid: list[tuple[float, float, float, float]] = []
    # Street entry: stepped threshold up to the raised diele floor.
    portal_x = float(spec["portal_x"])
    landing = house.steps("Portal", portal_x, 1.8, front, 3)
    house.pointed_portal("Portal", portal_x, landing, 1.3, 2.45, front)
    avoid.append((portal_x - 1.0, portal_x + 1.0, 0.0, landing + 2.7))

    window_x = float(spec["window_x"])
    house.shuttered_opening("DieleWindow", window_x, 1.3, 1.7, 1.45, front, "askew", True)
    house.box("DieleWindowMullion", (0.14, 0.16, 1.45), at(window_x, front - 0.05, 1.3 + 0.725), "oak")
    avoid.append((window_x - 1.3, window_x + 1.3, 1.0, 3.0))
    cellar_x = float(spec.get("cellar_x", window_x))
    house.cellar_neck("CellarNeck", cellar_x, 1.7, front)

    for level in range(1, storeys):
        z0 = level * storey_h + 0.5
        house.shuttered_opening(f"Hatch{level}", 0.0, z0, 1.0, 1.3, front, "closed", True)
        for strap, f in enumerate((0.25, 0.75)):
            house.box(f"Hatch{level}Strap{strap}", (0.8, 0.02, 0.05), at(0.0, front - 0.09, z0 + 1.3 * f), "iron")
        avoid.append((-0.9, 0.9, z0 - 0.3, z0 + 1.6))
        if spec["upper_windows"]:
            for index, x in enumerate((-width * 0.3, width * 0.3)):
                house.shuttered_opening(
                    f"UpperWindow{level}_{index}", x, z0 + 0.35, 0.8, 1.0, front, "open" if index else "closed", True
                )
                avoid.append((x - 0.8, x + 0.8, z0, z0 + 1.6))
        for index, x in enumerate((-width * 0.5 + 1.25, width * 0.5 - 1.25)):
            if spec["upper_windows"]:
                continue
            house.recess(f"Slit{level}_{index}", x, z0 + 0.3, 0.22, 0.8, front)
            house.stone_frame_opening(f"Slit{level}_{index}", x, z0 + 0.3, 0.22, 0.8, front)
            avoid.append((x - 0.5, x + 0.5, z0, z0 + 1.4))

    gable_z = eave + 0.55
    house.shuttered_opening("GableHatch", 0.0, gable_z, 0.9, 1.15, front, "closed", True)
    for index, x in enumerate((-1.45, 1.45)):
        house.recess(f"GableVent{index}", x, gable_z + 0.3, 0.2, 0.6, front)
        house.stone_frame_opening(f"GableVent{index}", x, gable_z + 0.3, 0.2, 0.6, front)
    house.hoist(0.0, gable_z + 1.15 + 0.75, front, eave - 0.2)

    corners = [(sx * width * 0.5, sy * house.depth * 0.5) for sx in (-1.0, 1.0) for sy in (-1.0, 1.0)]
    house.quoins(eave, corners, 0.5)
    # Straight iron wall anchors where the floor beams are tied to the facade.
    for level in range(1, storeys):
        for side in (-1.0, 1.0):
            house.box(
                f"Anchor{level}{'E' if side > 0 else 'W'}",
                (0.05, 0.03, 0.62),
                at(side * (width * 0.5 - 0.75), front - 0.02, level * storey_h + 0.1),
                "iron",
            )
    rows = [1.9 + 1.45 * index for index in range(8)]
    house.putlog_holes("front", rows, avoid)
    house.putlog_holes("left", rows, [])
    house.putlog_holes("right", rows, [])
    house.putlog_holes("back", rows, [])
    back = house.back
    house.plank_door("YardDoor", width * 0.25, 0.5, 1.0, 2.0, back, 1.0)
    house.box("YardDoorStep", (1.3, 0.45, 0.25), kit.at(width * 0.25, back + 0.62, 0.125), "ashlar", 0.025)
    house.box("YardDoorSill", (1.3, 0.4, 0.5), kit.at(width * 0.25, back + 0.2, 0.25), "rubble_dark", 0.02)
    house.shuttered_opening("DornseWindow", -width * 0.25, 1.35, 0.8, 0.9, back, "closed", True, 1.0)
    house.shuttered_opening("RearHatch", 0.0, storey_h + 0.6, 0.9, 1.15, back, "closed", True, 1.0)

    house.chimney(0.55, house.depth * 0.12, eave - 0.5, roof["ridge_top"] + 1.05)
    house.features = {
        "variant": spec["variant"],
        "storeys": storeys,
        "wall_finish": wall,
        "hatch_column": storeys,
        "hoist_beam": True,
        "roof": "monk_and_nun_tile",
    }
    return house


def main() -> None:
    # Import the shared kit only inside Blender, where bpy and mathutils exist.
    sys.path.insert(0, str(ROOT / "tools"))
    import burgher_house_kit_common as kit  # pylint: disable=import-outside-toplevel

    kit.clear_scene()
    materials = kit.Materials("MerchantStone")
    reports: dict[str, object] = {}
    for spec in VARIANTS:
        house = build(kit, spec, materials)
        root = house.finish()
        metrics = kit.export_glb(root, house, Path(spec["output"]), str(spec["asset_id"]))
        metrics["profile"] = "merchant_stone"
        metrics["variant"] = spec["variant"]
        metrics["hoist_default"] = True
        metrics["roof_default"] = "tile"
        metrics["limestone_front"] = True
        metrics["raised_cellar_neck"] = True
        reports[str(spec["asset_id"])] = metrics
        print(f"Generated {spec['output']}: {metrics['triangles']} tris, body {metrics['body_m']}")
        kit.remove_house(root, house)
    kit.write_evidence(EVIDENCE_DIR, BRIEF, reports)

    if "--preview" in sys.argv:
        for spec in VARIANTS:
            house = build(kit, spec, materials)
            root = house.finish()
            kit.render_plate(house, root, EVIDENCE_DIR / str(spec["plate"]), "street")
            kit.render_plate(house, root, EVIDENCE_DIR / str(spec["rear_plate"]), "rear")
            kit.remove_house(root, house)


if __name__ == "__main__":
    main()
