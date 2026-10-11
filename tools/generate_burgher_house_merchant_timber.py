#!/usr/bin/env python3
"""Generate the production Reval 1343 merchant-timber frontage kit.

Run from the repository root:
    blender --background --factory-startup --python \
        tools/generate_burgher_house_merchant_timber.py -- --preview

R-003 notes that in 1343 most street-front houses were still timber, built in
log, in-fill or half-timber technique on a stone cellar. Two variants share
one material set:
- ``merchant_timber.glb``: oak post-and-rail frame with corner foot braces
  (structural rhythm only, no decorative late Fachwerk figures), wattle and
  daub infill under a limewash that has fallen away in places, a board-clad
  street gable with a storage hatch, and a split-shingle roof;
- ``merchant_timber_log.glb``: wider two-storey horizontal-log front with
  saddle-notched corners and moss caulking, a shop-counter shutter at the
  diele, and the same board gable and shingle roof.
Neither carries a hoist beam (merchant_timber hoist default stays off).
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HOUSE_DIR = ROOT / "assets" / "props" / "architecture" / "houses" / "merchant_timber"
EVIDENCE_DIR = ROOT / "generated" / "blender" / "burgher_house_merchant_timber_v1"
ASSET_ID = "prop.architecture.house.merchant_timber"

VARIANTS: list[dict[str, object]] = [
    {
        "asset_id": ASSET_ID,
        "variant": "timber_frame",
        "name": "MerchantTimber",
        "output": HOUSE_DIR / "merchant_timber.glb",
        "plate": "street_gable.png",
        "rear_plate": "rear_yard.png",
        "width": 8.4,
        "depth": 8.4,
        "plinth": 0.6,
        "storeys": 2,
        "storey_h": 2.75,
    },
    {
        "asset_id": f"{ASSET_ID}.log",
        "variant": "horizontal_log",
        "name": "MerchantTimberLog",
        "output": HOUSE_DIR / "merchant_timber_log.glb",
        "plate": "street_gable_log.png",
        "rear_plate": "rear_yard_log.png",
        "width": 10.0,
        "depth": 8.4,
        "plinth": 0.45,
        "storeys": 2,
        "storey_h": 2.6,
    },
]

BRIEF = {
    "id": ASSET_ID,
    "kind": "rigid_architecture",
    "target": "res://assets/props/architecture/houses/merchant_timber/merchant_timber.glb",
    "variants": {
        "timber_frame": "res://assets/props/architecture/houses/merchant_timber/merchant_timber.glb",
        "horizontal_log": "res://assets/props/architecture/houses/merchant_timber/merchant_timber_log.glb",
    },
    "tier": "merchant_timber",
    "dimensions_m": {"frontage": 8.4, "depth": 8.4, "typical_storeys": 2},
    "features": {
        "steep_gable_to_street": True,
        "timber_or_plastered_front": True,
        "small_shuttered_openings": True,
        "optional_stone_cellar": True,
        "upper_loading_hatch": True,
        "shingle_forward_roof": True,
        "board_clad_gable": True,
        "shop_counter_shutter": True,
        "default_hoist": False,
        "weathering": [
            "rising_damp",
            "fallen_daub_exposing_wattle",
            "silver_weathered_oak",
            "sagging_ridge",
            "patched_shingles",
            "roof_moss",
            "flue_soot",
            "skewed_shutter",
        ],
        "late_gothic_facade": False,
        "decorative_fachwerk": False,
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


def _frame_face(kit, house, face: str, plinth: float, storeys: int, storey_h: float, openings) -> None:
    """Post-and-rail frame on one face; openings are (u0, u1, z0, z1) on that face."""
    at = kit.at
    along_x = face in {"front", "back"}
    span = house.width if along_x else house.depth
    plane = {"front": house.front, "back": house.back, "left": -house.width * 0.5, "right": house.width * 0.5}[face]
    outward = -1.0 if face in {"front", "left"} else 1.0
    offset = outward * 0.04

    def place(u: float, z: float) -> "kit.Matrix":
        if along_x:
            return at(u, plane + offset, z)
        return at(plane + offset, u, z) @ kit.rot_z(math.pi * 0.5)

    half = span * 0.5
    house.box(f"Sill{face}", (span + 0.24, 0.22, 0.24), place(0.0, plinth + 0.12), "oak", 0.02)
    for level in range(storeys):
        base = plinth + 0.24 + level * storey_h
        top = plinth + (level + 1) * storey_h
        house.box(
            f"Plate{face}{level}",
            (span + 0.2, 0.2, 0.2),
            place(house.rng.uniform(-0.02, 0.02), top) @ kit.rot_y(house.rng.uniform(-0.004, 0.004)),
            "oak",
            0.02,
        )
        storey_openings = [o for o in openings if o[2] < top and o[3] > base]
        # Posts: corners, then fill bays no wider than ~1.4 m, skipping openings
        # (their own jamb frames stand in for the posts there).
        posts = [-half + 0.12, half - 0.12]
        for u0, u1, _z0, _z1 in storey_openings:
            posts += [u0 - 0.16, u1 + 0.16]
        posts.sort()
        filled: list[float] = []
        for index, u in enumerate(posts):
            filled.append(u)
            if index + 1 < len(posts):
                gap = posts[index + 1] - u
                inside = any(o[0] - 0.2 <= (u + posts[index + 1]) * 0.5 <= o[1] + 0.2 for o in storey_openings)
                if gap > 1.5 and not inside:
                    count = int(gap / 1.3)
                    for k in range(1, count + 1):
                        filled.append(u + gap * k / (count + 1))
        height = top - base - 0.1
        for index, u in enumerate(filled):
            corner = index in (0, len(filled) - 1)
            house.box(
                f"Post{face}{level}_{index}",
                (0.24 if corner else house.rng.uniform(0.15, 0.2), 0.2, height),
                place(u, base + height * 0.5) @ kit.rot_y(house.rng.uniform(-0.01, 0.01)),
                "oak",
            )
        # Mid rail at sill height, broken where a door or tall opening passes.
        rail_z = base + 0.95
        bays = sorted(filled)
        for index in range(len(bays) - 1):
            u0, u1 = bays[index], bays[index + 1]
            mid = (u0 + u1) * 0.5
            if any(o[0] - 0.1 <= mid <= o[1] + 0.1 and o[2] - 0.2 < rail_z < o[3] + 0.3 for o in storey_openings):
                continue
            house.box(f"Rail{face}{level}_{index}", (u1 - u0 - 0.14, 0.17, 0.15), place(mid, rail_z), "oak")
        # Corner foot braces: diagonal from the sill/plate up to each corner post.
        for side in (-1.0, 1.0):
            corner_u = side * (half - 0.12)
            foot_u = corner_u - side * 1.05
            if any(min(foot_u, corner_u) - 0.1 < o[1] and max(foot_u, corner_u) + 0.1 > o[0] for o in storey_openings):
                continue
            rise = min(1.5, height * 0.62)
            run = abs(corner_u - foot_u)
            length = math.hypot(run, rise)
            angle = math.atan2(rise, run) * side
            house.box(
                f"Brace{face}{level}{'E' if side > 0 else 'W'}",
                (length, 0.16, 0.15),
                place((corner_u + foot_u) * 0.5, base + rise * 0.5) @ kit.rot_y(-angle),
                "oak",
            )


def build_frame(kit, spec, materials):
    house = kit.House(str(spec["name"]), materials, float(spec["width"]), float(spec["depth"]))
    at = kit.at
    width, depth = house.width, house.depth
    front, back = house.front, house.back
    plinth = float(spec["plinth"])
    storeys = int(spec["storeys"])
    storey_h = float(spec["storey_h"])
    eave = plinth + storeys * storey_h

    house.box("Plinth", (width + 0.12, depth + 0.12, plinth), at(0.0, 0.0, plinth * 0.5), "rubble_dark", 0.03)
    house.box("Infill", (width - 0.06, depth - 0.06, eave - plinth), at(0.0, 0.0, (eave + plinth) * 0.5), "limewash")
    roof = house.roof("shingle", eave, 0.48, 0.5, 0.5, 0.12, 0.09, 0.025)
    house.verge_boards(roof)
    house.ridge_boards(roof)
    house.roof_patches(roof, "boards", 3)
    house.board_gable("GableFront", eave, kit.ROOF_PITCH_DEG, -1.0)
    house.board_gable("GableRear", eave, kit.ROOF_PITCH_DEG, 1.0)

    door = (-2.35, 1.1, 2.0)
    counter = (1.75, 1.5, 1.0)
    upper_base = plinth + storey_h
    front_openings = [
        (door[0] - door[1] * 0.5, door[0] + door[1] * 0.5, plinth, plinth + door[2]),
        (counter[0] - counter[1] * 0.5, counter[0] + counter[1] * 0.5, plinth + 0.85, plinth + 0.85 + counter[2]),
        (-0.5, 0.5, upper_base + 0.45, upper_base + 1.75),
        (-2.95, -2.25, upper_base + 0.9, upper_base + 1.7),
        (2.25, 2.95, upper_base + 0.9, upper_base + 1.7),
    ]
    rear_openings = [(1.75, 2.7, plinth, plinth + 1.9), (-2.6, -1.9, plinth + 1.0, plinth + 1.7)]
    _frame_face(kit, house, "front", plinth, storeys, storey_h, front_openings)
    _frame_face(kit, house, "back", plinth, storeys, storey_h, rear_openings)
    _frame_face(kit, house, "left", plinth, storeys, storey_h, [])
    _frame_face(kit, house, "right", plinth, storeys, storey_h, [])

    face = front - 0.03
    house.steps("Door", door[0], 1.5, front - 0.06, 3, plinth / 3.0, 0.3)
    house.plank_door("Door", door[0], plinth, door[1], door[2], face)
    house.counter_shutter("Counter", counter[0], plinth + 0.85, counter[1], counter[2], face)
    house.shuttered_opening("Hatch1", 0.0, upper_base + 0.45, 1.0, 1.3, face, "closed", False)
    house.shuttered_opening("UpperWindowW", -2.6, upper_base + 0.9, 0.7, 0.8, face, "askew", False)
    house.shuttered_opening("UpperWindowE", 2.6, upper_base + 0.9, 0.7, 0.8, face, "closed", False)

    gable_face = front - 0.06
    house.shuttered_opening("GableHatch", 0.0, eave + 0.5, 0.9, 1.1, gable_face, "closed", False)
    house.recess("GableVent", 0.0, eave + 2.4, 0.32, 0.4, gable_face)
    house.timber_frame_opening("GableVent", 0.0, eave + 2.4, 0.32, 0.4, gable_face)

    # Daub lost from a few panels, showing the wattle behind the limewash.
    for index, (plane_face, u, z) in enumerate(
        (("front", -0.9, plinth + 0.55), ("front", 3.2, upper_base + 0.45), ("left", 1.4, plinth + 1.6), ("right", -2.2, upper_base + 1.2))
    ):
        plane = {"front": front, "left": -width * 0.5, "right": width * 0.5}[plane_face]
        house.blob(f"WattleBreach{index}", (u, z), (0.34, 0.28), plane_face, plane, "wattle", 0.018, 9)

    house.plank_door("YardDoor", 2.2, plinth, 0.95, 1.9, back + 0.03, 1.0)
    house.box("YardDoorStep", (1.2, 0.5, plinth * 0.5), at(2.2, back + 0.3, plinth * 0.25), "ashlar", 0.02)
    house.shuttered_opening("DornseWindow", -2.25, plinth + 1.0, 0.7, 0.7, back + 0.03, "closed", False, 1.0)

    house.chimney(-0.6, depth * 0.18, eave - 0.4, roof["ridge_top"] + 0.95)
    house.features = {"variant": spec["variant"], "storeys": storeys, "wall_finish": "limewashed_wattle_and_daub", "roof": "split_shingle"}
    return house


def build_log(kit, spec, materials):
    house = kit.House(str(spec["name"]), materials, float(spec["width"]), float(spec["depth"]))
    at = kit.at
    width, depth = house.width, house.depth
    front, back = house.front, house.back
    plinth = float(spec["plinth"])
    storeys = int(spec["storeys"])
    storey_h = float(spec["storey_h"])
    eave = plinth + storeys * storey_h
    upper = plinth + storey_h

    house.box("Plinth", (width + 0.1, depth + 0.1, plinth), at(0.0, 0.0, plinth * 0.5), "rubble_dark", 0.03)
    door = (-3.2, 1.1, 2.0)
    counter = (-0.8, 1.6, 1.0)
    openings = {
        "front": [
            (door[0] - 0.68, door[0] + 0.68, plinth, plinth + door[2] + 0.1),
            (counter[0] - 0.93, counter[0] + 0.93, plinth + 0.8, plinth + 0.9 + counter[2]),
            (2.2, 3.1, plinth + 1.0, plinth + 1.8),
            (-0.65, 0.65, upper + 0.35, upper + 1.75),
            (-3.5, -2.6, upper + 0.8, upper + 1.7),
            (2.6, 3.5, upper + 0.8, upper + 1.7),
        ],
        "back": [(1.6, 2.8, plinth, plinth + 2.0), (-3.0, -2.2, plinth + 1.0, plinth + 1.8)],
    }
    kit.build_log_walls(house, plinth, eave, openings)
    roof = house.roof("shingle", eave, 0.5, 0.55, 0.55, 0.12, 0.11, 0.03)
    house.verge_boards(roof)
    house.ridge_boards(roof)
    house.roof_patches(roof, "boards", 4)
    house.board_gable("GableFront", eave, kit.ROOF_PITCH_DEG, -1.0, 0.1)
    house.board_gable("GableRear", eave, kit.ROOF_PITCH_DEG, 1.0, 0.1)

    face = front - 0.1
    house.steps("Door", door[0], 1.5, face, 2, plinth / 2.0 + 0.02, 0.32)
    house.plank_door("Door", door[0], plinth + 0.05, door[1], door[2], face)
    house.counter_shutter("Counter", counter[0], plinth + 0.9, counter[1], counter[2], face)
    house.shuttered_opening("DieleWindow", 2.65, plinth + 1.05, 0.75, 0.7, face, "closed", False)
    house.shuttered_opening("Hatch1", 0.0, upper + 0.4, 1.1, 1.3, face, "closed", False)
    house.shuttered_opening("UpperWindowW", -3.05, upper + 0.85, 0.75, 0.8, face, "open", False)
    house.shuttered_opening("UpperWindowE", 3.05, upper + 0.85, 0.75, 0.8, face, "askew", False)
    gable_face = front - 0.1
    house.shuttered_opening("GableHatch", 0.0, eave + 0.55, 0.9, 1.1, gable_face, "closed", False)
    house.recess("GableVent", 0.0, eave + 2.9, 0.34, 0.42, gable_face)
    house.timber_frame_opening("GableVent", 0.0, eave + 2.9, 0.34, 0.42, gable_face)

    house.plank_door("YardDoor", 2.2, plinth + 0.05, 1.0, 1.9, back + 0.1, 1.0)
    house.box("YardDoorStep", (1.3, 0.5, plinth * 0.6), at(2.2, back + 0.4, plinth * 0.3), "ashlar", 0.02)
    house.shuttered_opening("DornseWindow", -2.6, plinth + 1.05, 0.7, 0.7, back + 0.1, "closed", False, 1.0)
    house.chimney(0.65, depth * 0.2, eave - 0.4, roof["ridge_top"] + 0.9)
    house.firewood(width * 0.5 + 0.45, 1.2, True, 2.6, 4)
    house.features = {"variant": spec["variant"], "storeys": storeys, "wall_finish": "moss_caulked_logs", "roof": "split_shingle"}
    return house


def build(kit, spec, materials):
    return build_frame(kit, spec, materials) if spec["variant"] == "timber_frame" else build_log(kit, spec, materials)


def main() -> None:
    # Import the shared kit only inside Blender, where bpy and mathutils exist.
    sys.path.insert(0, str(ROOT / "tools"))
    import burgher_house_kit_common as kit  # pylint: disable=import-outside-toplevel

    kit.clear_scene()
    materials = kit.Materials("MerchantTimber")
    reports: dict[str, object] = {}
    for spec in VARIANTS:
        house = build(kit, spec, materials)
        root = house.finish()
        metrics = kit.export_glb(root, house, Path(spec["output"]), str(spec["asset_id"]))
        metrics["profile"] = "merchant_timber"
        metrics["variant"] = spec["variant"]
        metrics["hoist_default"] = False
        metrics["roof_default"] = "shingle"
        metrics["timber_front"] = True
        metrics["stone_cellar_base"] = True
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
