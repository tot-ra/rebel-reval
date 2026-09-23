#!/usr/bin/env python3
"""Generate Lower Town 1343 service-building exteriors (storehouse, brewhouse,
public bath, barn) with the burgher-house kit v2.

Run from the repository root:
    blender --background --factory-startup --python \
        tools/generate_lower_town_service_buildings.py -- --preview

These replace the untextured placeholder boxes on special Lower Town plots
that sit outside the closed R-003 house-tier allowlist:
- ``stone_storehouse``: guild/merchant stone warehouse (Speicher). Pikk-Lai
  frontage dossier: stone warehouses and rear storehouses on affluent plots,
  hoist beams on merchants. Unheated (no flue - fire safety), cart portal,
  stacked loading hatches, ventilation slits, coped parapet gable, tile roof.
- ``brewhouse``: rubble brewing floor for the hot copper under a board-clad
  malt loft, a louvred steam lantern on the ridge, a wide kiln flue and
  double cart doors; kegs at the door (brewery-ordinance dossier art brief).
- ``public_bath``: municipal timber bath rented to an operator
  (public-bath-locations-1343): low log house with smoke-sauna vents under the
  eaves and soot streaks, a water cask and a large firewood stack. Not the
  stone Saunatorn (1371).
- ``log_barn``: thatched log barn with plank double doors and a hay hatch.
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILDING_DIR = ROOT / "assets" / "props" / "architecture" / "buildings"
EVIDENCE_DIR = ROOT / "generated" / "blender" / "lower_town_service_buildings_v1"
ASSET_PREFIX = "prop.architecture.building"

VARIANTS: list[dict[str, object]] = [
    {
        "asset_id": f"{ASSET_PREFIX}.stone_storehouse",
        "variant": "stone_storehouse",
        "name": "StoneStorehouse",
        "output": BUILDING_DIR / "stone_storehouse" / "stone_storehouse.glb",
        "plate": "street_stone_storehouse.png",
        "width": 11.0,
        "depth": 8.0,
    },
    {
        "asset_id": f"{ASSET_PREFIX}.brewhouse",
        "variant": "brewhouse",
        "name": "Brewhouse",
        "output": BUILDING_DIR / "brewhouse" / "brewhouse.glb",
        "plate": "street_brewhouse.png",
        "width": 9.0,
        "depth": 8.0,
    },
    {
        "asset_id": f"{ASSET_PREFIX}.public_bath",
        "variant": "public_bath",
        "name": "PublicBath",
        "output": BUILDING_DIR / "public_bath" / "public_bath.glb",
        "plate": "street_public_bath.png",
        "width": 6.0,
        "depth": 8.0,
    },
    {
        "asset_id": f"{ASSET_PREFIX}.log_barn",
        "variant": "log_barn",
        "name": "LogBarn",
        "output": BUILDING_DIR / "log_barn" / "log_barn.glb",
        "plate": "street_log_barn.png",
        "width": 8.0,
        "depth": 6.0,
    },
]

BRIEF = {
    "id": f"{ASSET_PREFIX}.lower_town_service",
    "kind": "rigid_architecture",
    "variants": {str(spec["variant"]): str(spec["asset_id"]) for spec in VARIANTS},
    "features": {
        "steep_gable_to_street": True,
        "storehouse_unheated": True,
        "storehouse_hoist_beam": True,
        "brewhouse_steam_louvre": True,
        "public_bath_timber_not_saunatorn": True,
        "barn_thatch": True,
        "late_gothic_facade": False,
    },
    "triangles": {"max": 16000},
    "textures": {"albedo": 512, "normal": 512, "embedded": True},
    "style_refs": [
        "history/dossiers/architecture/burgher-house-plan.md",
        "history/dossiers/topography/pikk-lai-frontage-materials-1340s.md",
        "history/dossiers/topography/public-bath-locations-1343.md",
        "history/dossiers/economy/reval-brewery-ordinances-1340s.md",
        "docs/ART_BIBLE.md",
    ],
    "approval": "task-authorized",
}


def _barrel(kit, house, name: str, x: float, y: float, radius: float = 0.3, height: float = 0.8, lying: bool = False) -> None:
    transform = kit.at(x, y, radius if lying else height * 0.5)
    if lying:
        transform = transform @ kit.rot_y(math.pi * 0.5)
    house.cylinder(name, radius, height, transform, "oak_dark", 10, radius * 0.92)
    for index, f in enumerate((-0.32, 0.32)):
        offset = kit.Vector((0.0, 0.0, height * f))
        hoop = transform @ kit.at(offset.x, offset.y, offset.z)
        house.cylinder(f"{name}Hoop{index}", radius * 1.02, 0.05, hoop, "iron", 10)


def build_storehouse(kit, spec, materials):
    house = kit.House(str(spec["name"]), materials, float(spec["width"]), float(spec["depth"]))
    at = kit.at
    width, front = house.width, house.front
    storey_h = 2.7
    storeys = 3
    eave = storey_h * storeys
    house.box("Plinth", (width + 0.16, house.depth + 0.16, 0.45), at(0.0, 0.0, 0.225), "rubble_dark", 0.03)
    house.box("Walls", (width, house.depth, eave), at(0.0, 0.0, eave * 0.5), "rubble", 0.02)
    roof = house.roof("tile", eave, 0.3, -0.55, -0.55, 0.2, 0.12, 0.03)
    house.parapet_gable("GableFront", roof, -1.0)
    house.parapet_gable("GableRear", roof, 1.0)
    house.ridge_tiles(roof)
    house.roof_patches(roof, "tile", 3)
    avoid = []
    # Cart portal: wide pointed arch straight into the goods floor.
    house.box("PortalSill", (3.0, 0.5, 0.12), at(0.0, front - 0.25, 0.06), "ashlar", 0.02)
    house.pointed_portal("Portal", 0.0, 0.12, 2.3, 3.1, front)
    avoid.append((-1.6, 1.6, 0.0, 3.5))
    for level in range(1, storeys):
        z0 = level * storey_h + 0.45
        house.shuttered_opening(f"Hatch{level}", 0.0, z0, 1.1, 1.4, front, "closed", True)
        for strap, f in enumerate((0.25, 0.75)):
            house.box(f"Hatch{level}Strap{strap}", (0.9, 0.02, 0.05), at(0.0, front - 0.09, z0 + 1.4 * f), "iron")
        avoid.append((-1.0, 1.0, z0 - 0.3, z0 + 1.7))
    for level in range(storeys):
        for index, x in enumerate((-3.3, 3.3)):
            z0 = level * storey_h + 1.0
            house.recess(f"Slit{level}_{index}", x, z0, 0.18, 0.9, front)
            house.stone_frame_opening(f"Slit{level}_{index}", x, z0, 0.18, 0.9, front)
            avoid.append((x - 0.5, x + 0.5, z0 - 0.3, z0 + 1.2))
    gable_z = eave + 0.5
    house.shuttered_opening("GableHatch", 0.0, gable_z, 1.0, 1.2, front, "closed", True)
    for index, x in enumerate((-1.7, 1.7)):
        house.recess(f"GableVent{index}", x, gable_z + 0.2, 0.18, 0.7, front)
        house.stone_frame_opening(f"GableVent{index}", x, gable_z + 0.2, 0.18, 0.7, front)
    house.hoist(0.0, gable_z + 1.2 + 0.8, front, eave - 0.1, 1.7)
    corners = [(sx * width * 0.5, sy * house.depth * 0.5) for sx in (-1.0, 1.0) for sy in (-1.0, 1.0)]
    house.quoins(eave, corners, 0.45)
    for level in range(1, storeys):
        for side in (-1.0, 1.0):
            house.box(
                f"Anchor{level}{'E' if side > 0 else 'W'}",
                (0.05, 0.03, 0.7),
                at(side * (width * 0.5 - 0.8), front - 0.02, level * storey_h + 0.1),
                "iron",
            )
    rows = [1.7 + 1.35 * index for index in range(6)]
    for face in ("front", "left", "right", "back"):
        house.putlog_holes(face, rows, avoid if face == "front" else [])
    house.plank_door("YardDoor", 2.6, 0.45, 1.2, 2.2, house.back, 1.0)
    house.box("YardDoorStep", (1.5, 0.5, 0.45), at(2.6, house.back + 0.25, 0.225), "rubble_dark", 0.02)
    house.features = {"variant": spec["variant"], "storeys": storeys, "heated": False, "hoist_beam": True}
    return house


def build_brewhouse(kit, spec, materials):
    house = kit.House(str(spec["name"]), materials, float(spec["width"]), float(spec["depth"]))
    at = kit.at
    width, depth, front = house.width, house.depth, house.front
    ground = 3.1
    eave = ground + 2.5
    # Stone brewing floor for the hot copper; board-clad malt loft above.
    house.box("Walls", (width, depth, ground), at(0.0, 0.0, ground * 0.5), "rubble", 0.02)
    house.box("LoftCore", (width - 0.1, depth - 0.1, eave - ground), at(0.0, 0.0, (ground + eave) * 0.5), "boards")
    house.box("LoftGirt", (width + 0.14, depth + 0.14, 0.22), at(0.0, 0.0, ground + 0.05), "oak", 0.02)
    for face, plane in (("front", front - 0.05), ("back", house.back + 0.05)):
        for index in range(int(width / 0.55) + 1):
            x = -width * 0.5 + width * index / int(width / 0.55)
            house.box(f"LoftBatten{face}{index}", (0.07, 0.04, eave - ground - 0.2), at(x, plane, (ground + eave) * 0.5), "boards")
    roof = house.roof("shingle", eave, 0.5, 0.5, 0.5, 0.12, 0.1, 0.03)
    house.verge_boards(roof)
    house.ridge_boards(roof)
    house.roof_patches(roof, "boards", 3)
    house.board_gable("GableFront", eave, kit.ROOF_PITCH_DEG, -1.0, 0.08)
    house.board_gable("GableRear", eave, kit.ROOF_PITCH_DEG, 1.0, 0.08)
    # Louvred steam lantern straddling the ridge over the copper.
    lantern_t = 0.42
    ridge = house.roof_surface(roof, 1.0, 1.0, lantern_t)
    house.box("LouvreBase", (0.9, 1.6, 0.5), at(0.0, ridge.y, ridge.z + 0.1), "boards")
    for index in range(4):
        house.box(f"LouvreSlat{index}", (1.0, 1.5, 0.05), at(0.0, ridge.y, ridge.z + 0.42 + index * 0.14) @ kit.rot_x(0.0), "oak")
    for side in (1.0, -1.0):
        house.box(
            f"LouvreRoof{'E' if side > 0 else 'W'}",
            (0.8, 1.9, 0.05),
            at(side * 0.28, ridge.y, ridge.z + 1.08) @ kit.rot_y(side * roof["pitch"]),
            "shingle",
        )
    house.soot.append((kit.Vector((0.0, ridge.y, ridge.z + 1.0)), 1.4, 0.35))
    # Double cart doors and a small window on the brewing floor.
    house.recess("CartDoor", -1.3, 0.05, 2.2, 2.5, front)
    house.timber_frame_opening("CartDoor", -1.3, 0.05, 2.2, 2.5, front)
    house.plank_leaf("CartDoorL", -1.85, 0.05, 1.06, 2.45, front, -1.0)
    house.plank_leaf("CartDoorR", -0.75, 0.05, 1.06, 2.45, front, -1.0)
    house.shuttered_opening("BrewWindow", 2.5, 1.2, 0.9, 0.8, front, "askew", True)
    house.shuttered_opening("LoftHatch", 0.4, ground + 0.6, 1.0, 1.2, front - 0.05, "closed", False)
    house.shuttered_opening("GableHatch", 0.0, eave + 0.6, 0.8, 1.0, front - 0.1, "closed", False)
    house.chimney(-0.7, depth * 0.24, eave - 0.5, roof["ridge_top"] + 0.9)
    house.box("ChimneyStackWide", (1.0, 0.9, 0.6), at(-0.7, depth * 0.24, roof["ridge_top"] - 0.2), "rubble", 0.03)
    for index, (x, y) in enumerate(((1.4, front - 0.55), (2.1, front - 0.6), (3.5, front - 0.5))):
        _barrel(kit, house, f"Keg{index}", x, y, 0.28, 0.75)
    _barrel(kit, house, "KegLying", 1.8, front - 1.2, 0.3, 0.8, True)
    house.plank_door("YardDoor", 2.4, 0.05, 1.0, 2.0, house.back, 1.0)
    house.features = {"variant": spec["variant"], "storeys": 2, "steam_louvre": True, "kegs": 4}
    return house


def build_public_bath(kit, spec, materials):
    house = kit.House(str(spec["name"]), materials, float(spec["width"]), float(spec["depth"]))
    at = kit.at
    width, depth, front = house.width, house.depth, house.front
    plinth = 0.35
    eave = plinth + 2.4
    house.box("Plinth", (width - 0.2, depth - 0.2, plinth), at(0.0, 0.0, plinth * 0.5), "rubble_dark", 0.03)
    openings = {
        "front": [(-1.9, -0.7, plinth, plinth + 1.95)],
        "left": [(1.0, 1.5, eave - 0.6, eave - 0.25), (-2.0, -1.5, eave - 0.6, eave - 0.25)],
        "right": [(1.0, 1.5, eave - 0.6, eave - 0.25)],
    }
    kit.build_log_walls(house, plinth, eave, openings, radius=0.15, course=0.27, overhang=0.3)
    roof = house.roof("shingle", eave, 0.45, 0.45, 0.45, 0.12, 0.13, 0.035)
    house.verge_boards(roof)
    house.ridge_boards(roof)
    house.roof_patches(roof, "boards", 2)
    house.board_gable("GableFront", eave, kit.ROOF_PITCH_DEG, -1.0, 0.1)
    house.board_gable("GableRear", eave, kit.ROOF_PITCH_DEG, 1.0, 0.1)
    house.box("DoorStone", (1.3, 0.5, 0.2), at(-1.3, front - 0.35, 0.1), "rubble_dark", 0.06)
    house.plank_door("Door", -1.3, plinth + 0.02, 0.9, 1.85, front - 0.1)
    # Smoke-sauna vents under the eaves: the stove has no flue.
    for index, (plane, y) in enumerate(((-width * 0.5, 1.25), (-width * 0.5, -1.75), (width * 0.5, 1.25))):
        house.box(
            f"SmokeVent{index}",
            (0.04, 0.46, 0.32),
            at(plane + (-0.012 if plane < 0 else 0.012), y, eave - 0.42),
            "recess",
        )
        house.soot.append((kit.Vector((plane, y, eave - 0.3)), 1.3, 0.6))
    house.smoke_outlet = kit.Vector((-width * 0.5 - 0.3, 1.25, eave - 0.2))
    house.soot.append((kit.Vector((0.0, front, eave + 1.2)), 1.2, 0.25))
    _barrel(kit, house, "WaterCask", 1.6, front - 0.6, 0.42, 0.95)
    house.box("CaskLid", (0.9, 0.9, 0.05), at(1.6, front - 0.6, 0.98) @ kit.rot_z(0.3), "oak_dark")
    house.box("Bucket", (0.3, 0.3, 0.3), at(0.9, front - 0.55, 0.15), "oak_dark", 0.03)
    house.firewood(width * 0.5 + 0.5, 0.0, True, 3.6, 5)
    house.recess("GableVent", 0.0, eave + 1.5, 0.34, 0.34, front - 0.1)
    house.timber_frame_opening("GableVent", 0.0, eave + 1.5, 0.34, 0.34, front - 0.1)
    house.features = {"variant": spec["variant"], "storeys": 1, "flue": False, "smoke_vents": 3}
    return house


def build_barn(kit, spec, materials):
    house = kit.House(str(spec["name"]), materials, float(spec["width"]), float(spec["depth"]))
    at = kit.at
    width, front = house.width, house.front
    plinth = 0.25
    eave = plinth + 2.9
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            size = house.rng.uniform(0.55, 0.7)
            house.box(
                f"CornerStone{'E' if sx > 0 else 'W'}{'N' if sy > 0 else 'S'}",
                (size, size, 0.34),
                at(sx * (width * 0.5 + 0.05), sy * (house.depth * 0.5 + 0.05), 0.15) @ kit.rot_z(house.rng.uniform(-0.4, 0.4)),
                "rubble_dark",
                0.1,
            )
    openings = {"front": [(-1.45, 1.45, 0.0, plinth + 2.55)], "back": [(-0.6, 0.6, plinth, plinth + 1.8)]}
    kit.build_log_walls(house, plinth, eave, openings, radius=0.16, course=0.29, overhang=0.34)
    roof = house.roof("thatch", eave, 0.6, 0.55, 0.55, 0.42, 0.16, 0.06)
    house.thatch_ridge(roof)
    house.board_gable("GableFront", eave, kit.ROOF_PITCH_DEG, -1.0, 0.1)
    house.board_gable("GableRear", eave, kit.ROOF_PITCH_DEG, 1.0, 0.1)
    face = front - 0.12
    house.recess("BarnDoor", 0.0, 0.1, 2.7, 2.5, face)
    house.timber_frame_opening("BarnDoor", 0.0, 0.1, 2.7, 2.5, face)
    house.plank_leaf("BarnDoorL", -0.68, 0.12, 1.3, 2.4, face, -1.0)
    # The right leaf stands open against the wall.
    house.box("BarnDoorR", (0.06, 1.3, 2.5), at(1.45 + 0.1, face - 0.68, 1.27) @ kit.rot_z(0.08), "oak_dark", 0.01)
    house.shuttered_opening("HayHatch", 0.0, eave + 0.5, 1.1, 1.0, front - 0.12, "open", False)
    house.plank_door("YardDoor", 0.0, plinth, 1.1, 1.8, house.back + 0.12, 1.0)
    house.features = {"variant": spec["variant"], "storeys": 1, "hay_loft": True}
    return house


BUILDERS = {
    "stone_storehouse": build_storehouse,
    "brewhouse": build_brewhouse,
    "public_bath": build_public_bath,
    "log_barn": build_barn,
}


def main() -> None:
    # Import the shared kit only inside Blender, where bpy and mathutils exist.
    sys.path.insert(0, str(ROOT / "tools"))
    import burgher_house_kit_common as kit  # pylint: disable=import-outside-toplevel

    kit.clear_scene()
    materials = kit.Materials("LowerTownService")
    reports: dict[str, object] = {}
    for spec in VARIANTS:
        house = BUILDERS[str(spec["variant"])](kit, spec, materials)
        root = house.finish()
        metrics = kit.export_glb(root, house, Path(spec["output"]), str(spec["asset_id"]))
        metrics["profile"] = "lower_town_service"
        metrics["variant"] = spec["variant"]
        reports[str(spec["asset_id"])] = metrics
        print(f"Generated {spec['output']}: {metrics['triangles']} tris, body {metrics['body_m']}")
        kit.remove_house(root, house)
    kit.write_evidence(EVIDENCE_DIR, BRIEF, reports)

    if "--preview" in sys.argv:
        for spec in VARIANTS:
            house = BUILDERS[str(spec["variant"])](kit, spec, materials)
            root = house.finish()
            kit.render_plate(house, root, EVIDENCE_DIR / str(spec["plate"]), "street")
            kit.remove_house(root, house)


if __name__ == "__main__":
    main()
