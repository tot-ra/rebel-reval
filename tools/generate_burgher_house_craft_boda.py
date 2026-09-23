#!/usr/bin/env python3
"""Generate the production Reval 1343 craft-boda frontage kit.

Run from the repository root:
    blender --background --factory-startup --python \
        tools/generate_burgher_house_craft_boda.py -- --preview

The craft boda is a compact one-storey workshop-dwelling (R-003), often
rented by Estonian craftsmen from a burgher owner. Both variants are
horizontal-log houses on fieldstone corner pads with moss caulking and a
board-clad gable, and neither exposes merchant storage hatches, a hoist beam,
a granary crane, or a raised merchant cellar terrace:
- ``craft_boda.glb``: water-reed thatch weighted with crossed rider poles, no
  flue - smoke leaves through a gable vent that has sooted the boards above it;
- ``craft_boda_pentice.glb``: wider workshop under a sagging split-shingle
  roof with a low stone flue, a shop-counter shutter and a board pentice
  sheltering the street bench.
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HOUSE_DIR = ROOT / "assets" / "props" / "architecture" / "houses" / "craft_boda"
EVIDENCE_DIR = ROOT / "generated" / "blender" / "burgher_house_craft_boda_v1"
ASSET_ID = "prop.architecture.house.craft_boda"

VARIANTS: list[dict[str, object]] = [
    {
        "asset_id": ASSET_ID,
        "variant": "log_thatch",
        "name": "CraftBoda",
        "output": HOUSE_DIR / "craft_boda.glb",
        "plate": "street_gable.png",
        "rear_plate": "rear_yard.png",
        "width": 8.2,
        "depth": 6.6,
        "plinth": 0.3,
        "wall_h": 2.4,
        "roof": "thatch",
    },
    {
        "asset_id": f"{ASSET_ID}.pentice",
        "variant": "log_shingle_pentice",
        "name": "CraftBodaPentice",
        "output": HOUSE_DIR / "craft_boda_pentice.glb",
        "plate": "street_gable_pentice.png",
        "rear_plate": "rear_yard_pentice.png",
        "width": 9.4,
        "depth": 7.0,
        "plinth": 0.35,
        "wall_h": 2.45,
        "roof": "shingle",
    },
]

BRIEF = {
    "id": ASSET_ID,
    "kind": "rigid_architecture",
    "target": "res://assets/props/architecture/houses/craft_boda/craft_boda.glb",
    "variants": {
        "log_thatch": "res://assets/props/architecture/houses/craft_boda/craft_boda.glb",
        "log_shingle_pentice": "res://assets/props/architecture/houses/craft_boda/craft_boda_pentice.glb",
    },
    "tier": "craft_boda",
    "dimensions_m": {"frontage": 8.2, "depth": 6.6, "typical_storeys": 1},
    "features": {
        "compact_two_room_workshop_dwelling": True,
        "single_hearth_implication": True,
        "modest_street_openings": True,
        "minimal_rear_yard_mass": True,
        "thatch_or_shingle_roof": True,
        "horizontal_log_walls": True,
        "thatch_ridge_riders": True,
        "hypocaust": False,
        "hoist_beam": False,
        "granary_crane": False,
        "late_gothic_facade": False,
        "weathering": [
            "rising_damp",
            "silver_weathered_logs",
            "sagging_ridge",
            "thatch_moss",
            "smoke_vent_soot",
            "patched_shingles",
            "skewed_shutter",
        ],
    },
    "triangles": {"target": 7000, "max": 16000},
    "textures": {"albedo": 512, "normal": 512, "embedded": True},
    "style_refs": [
        "history/dossiers/architecture/burgher-house-plan.md",
        "docs/reports/burgher_house_art_brief.md",
        "docs/ART_BIBLE.md",
        "docs/MATERIAL_STYLE_LOCK_KIT.md",
    ],
    "approval": "task-authorized",
}


def _corner_stones(kit, house) -> None:
    """Fieldstone pads under each log corner, half sunk in the yard."""
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            size = house.rng.uniform(0.55, 0.7)
            house.box(
                f"CornerStone{'E' if sx > 0 else 'W'}{'N' if sy > 0 else 'S'}",
                (size, size * house.rng.uniform(0.85, 1.1), 0.36),
                kit.at(sx * (house.width * 0.5 + 0.05), sy * (house.depth * 0.5 + 0.05), 0.16)
                @ kit.rot_z(house.rng.uniform(-0.4, 0.4)),
                "rubble_dark",
                0.1,
            )


def _pentice(kit, house, x0: float, x1: float, wall_z: float, depth: float) -> None:
    """Lean-to board roof over the street bench, carried on two rough posts."""
    at = kit.at
    front = house.front
    drop = 0.42
    slope = math.atan2(drop, depth)
    length = math.hypot(depth, drop)
    centre_x = (x0 + x1) * 0.5
    span = x1 - x0
    house.box("PenticeWallPlate", (span + 0.2, 0.14, 0.16), at(centre_x, front - 0.2, wall_z), "oak")
    house.box(
        "PenticeRoof",
        (span + 0.3, length + 0.2, 0.07),
        at(centre_x, front - 0.2 - depth * 0.5, wall_z - drop * 0.5 + 0.1) @ kit.rot_x(slope),
        "shingle",
    )
    for index, x in enumerate((x0 + 0.1, x1 - 0.1)):
        post_h = wall_z - drop
        house.box(
            f"PenticePost{index}",
            (0.14, 0.14, post_h),
            at(x, front - 0.2 - depth + 0.1, post_h * 0.5) @ kit.rot_y(house.rng.uniform(-0.03, 0.03)),
            "oak",
        )
    house.box("PenticeBeam", (span + 0.1, 0.14, 0.14), at(centre_x, front - 0.1 - depth, wall_z - drop), "oak")
    house.box("StreetBench", (span * 0.6, 0.4, 0.08), at(centre_x - span * 0.12, front - 0.45, 0.48), "oak_dark", 0.01)
    for index, x in enumerate((centre_x - span * 0.38, centre_x + span * 0.14)):
        house.box(f"StreetBenchLeg{index}", (0.08, 0.34, 0.44), at(x, front - 0.45, 0.22), "oak")


def build(kit, spec, materials):
    house = kit.House(str(spec["name"]), materials, float(spec["width"]), float(spec["depth"]))
    at = kit.at
    width, depth = house.width, house.depth
    front, back = house.front, house.back
    plinth = float(spec["plinth"])
    eave = plinth + float(spec["wall_h"])
    cover = str(spec["roof"])
    thatch = cover == "thatch"

    house.box("Plinth", (width - 0.2, depth - 0.2, plinth), at(0.0, 0.0, plinth * 0.5), "rubble_dark", 0.03)
    _corner_stones(kit, house)
    if thatch:
        door = (-2.3, 0.95, 1.8)
        window = (1.7, 0.8, 0.65)
        openings = {
            "front": [
                (door[0] - 0.6, door[0] + 0.6, plinth, plinth + door[2] + 0.1),
                (window[0] - 0.53, window[0] + 0.53, plinth + 0.95, plinth + 0.95 + window[2] + 0.1),
            ],
            "back": [(1.4, 2.4, plinth, plinth + 1.8)],
        }
    else:
        door = (-3.2, 0.95, 1.85)
        window = (1.1, 1.6, 0.9)
        openings = {
            "front": [
                (door[0] - 0.6, door[0] + 0.6, plinth, plinth + door[2] + 0.1),
                (window[0] - 0.93, window[0] + 0.93, plinth + 0.75, plinth + 0.8 + window[2]),
            ],
            "back": [(1.6, 2.6, plinth, plinth + 1.8), (-2.8, -2.1, plinth + 0.95, plinth + 1.6)],
        }
    kit.build_log_walls(house, plinth, eave, openings, radius=0.15, course=0.27, overhang=0.32)

    if thatch:
        roof = house.roof("thatch", eave, 0.6, 0.55, 0.55, 0.42, 0.13, 0.05)
        house.thatch_ridge(roof)
    else:
        roof = house.roof("shingle", eave, 0.5, 0.5, 0.5, 0.12, 0.14, 0.035)
        house.verge_boards(roof)
        house.ridge_boards(roof)
        house.roof_patches(roof, "boards", 3)
    house.board_gable("GableFront", eave, kit.ROOF_PITCH_DEG, -1.0, 0.1)
    house.board_gable("GableRear", eave, kit.ROOF_PITCH_DEG, 1.0, 0.1)

    face = front - 0.1
    house.box("DoorStone", (1.3, 0.55, 0.2), at(door[0], front - 0.38, 0.1) @ kit.rot_z(0.04), "rubble_dark", 0.06)
    house.plank_door("Door", door[0], plinth + 0.02, door[1], door[2], face)
    gable_face = front - 0.1
    if thatch:
        house.shuttered_opening("WorkWindow", window[0], plinth + 0.95, window[1], window[2], face, "askew", False)
        # Flueless hearth: smoke leaves through the gable vent and soots the boards.
        vent_z = eave + 2.2
        house.recess("SmokeVent", 0.0, vent_z, 0.5, 0.45, gable_face)
        house.timber_frame_opening("SmokeVent", 0.0, vent_z, 0.5, 0.45, gable_face)
        house.soot.append((kit.Vector((0.0, front - 0.1, vent_z + 0.3)), 1.6, 0.55))
        house.smoke_outlet = kit.Vector((0.0, front - 0.35, vent_z + 0.3))
        house.firewood(width * 0.5 + 0.5, 0.4, True, 2.4, 4)
        house.plank_door("YardDoor", 1.9, plinth + 0.02, 0.9, 1.75, back + 0.1, 1.0)
    else:
        house.counter_shutter("Counter", window[0], plinth + 0.8, window[1], window[2], face)
        _pentice(kit, house, window[0] - 1.25, window[0] + 1.35, eave - 0.3, 1.1)
        house.recess("GableVent", 0.0, eave + 2.3, 0.34, 0.4, gable_face)
        house.timber_frame_opening("GableVent", 0.0, eave + 2.3, 0.34, 0.4, gable_face)
        house.plank_door("YardDoor", 2.1, plinth + 0.02, 0.9, 1.75, back + 0.1, 1.0)
        house.shuttered_opening("SleepingNookWindow", -2.45, plinth + 0.95, 0.6, 0.55, back + 0.1, "closed", False, 1.0)
        house.chimney(0.7, depth * 0.22, eave - 0.3, roof["ridge_top"] + 0.55)
        house.firewood(-width * 0.5 - 0.5, 0.6, True, 2.2, 4)
    house.features = {
        "variant": spec["variant"],
        "storeys": 1,
        "wall_finish": "moss_caulked_logs",
        "roof": "water_reed_thatch" if thatch else "split_shingle",
        "flue": not thatch,
    }
    return house


def main() -> None:
    # Import the shared kit only inside Blender, where bpy and mathutils exist.
    sys.path.insert(0, str(ROOT / "tools"))
    import burgher_house_kit_common as kit  # pylint: disable=import-outside-toplevel

    kit.clear_scene()
    materials = kit.Materials("CraftBoda")
    reports: dict[str, object] = {}
    for spec in VARIANTS:
        house = build(kit, spec, materials)
        root = house.finish()
        metrics = kit.export_glb(root, house, Path(spec["output"]), str(spec["asset_id"]))
        metrics["profile"] = "craft_boda"
        metrics["variant"] = spec["variant"]
        metrics["hoist_default"] = False
        metrics["roof_default"] = str(spec["roof"])
        metrics["storeys"] = 1
        metrics["single_hearth"] = True
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
