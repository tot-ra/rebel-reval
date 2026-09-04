#!/usr/bin/env python3
"""Generate the production Reval 1343 craft-boda frontage kit.

Run from the repository root:
    blender --background --factory-startup --python \
        tools/generate_burgher_house_craft_boda.py -- --preview

The craft-boda profile is intentionally compact: a one-storey workshop-dwelling
with a modest street opening, one hearth implication, and a simple thatch roof.
It does not expose merchant storage hatches, a hoist beam, a granary crane, or a
raised merchant cellar terrace.
"""

from __future__ import annotations

import sys
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "props" / "architecture" / "houses" / "craft_boda" / "craft_boda.glb"
EVIDENCE_DIR = ROOT / "generated" / "blender" / "burgher_house_craft_boda_v1"
ASSET_ID = "prop.architecture.house.craft_boda"

# R-003 / A-008: compact craft-edge frontage, one storey, simple timber wall,
# single workroom-to-sleeping-nook mass, and thatch-forward roof cover.
HOUSE_SPEC: dict[str, object] = {
    "name": "CraftBoda",
    "width": 6.6,
    "depth": 11.5,
    "storeys": 1,
    "storey_h": 2.65,
    "wall": "oak",
    "gable_wall": "oak",
    "trim": "oak_aged",
    "roof": "thatch",
    "door": "oak_aged",
    "portal_x": -1.55,
    "door_w": 0.92,
    "door_h": 2.05,
    "portal_steps": 1,
    "ground_window": True,
    "ground_window_x": 1.35,
    "ground_window_w": 0.82,
    "ground_window_h": 0.92,
    "ground_window_shutters": "closed",
    "hatch_storeys": 0,
    "hoist": False,
    "upper_window": False,
    "timber_frame": False,
    "anchor_plates": False,
    "quoins": False,
    "chimney": True,
    "chimney_mat": "limestone_dark",
    "gable_vent": False,
    "overhang": 0.34,
}

BRIEF = {
    "id": ASSET_ID,
    "kind": "rigid_architecture",
    "target": "res://assets/props/architecture/houses/craft_boda/craft_boda.glb",
    "tier": "craft_boda",
    "dimensions_m": {"frontage": 6.6, "depth": 11.5, "typical_storeys": 1},
    "features": {
        "compact_two_room_workshop_dwelling": True,
        "single_hearth_implication": True,
        "modest_street_openings": True,
        "minimal_rear_yard_mass": True,
        "thatch_or_shingle_roof": True,
        "hypocaust": False,
        "hoist_beam": False,
        "granary_crane": False,
        "late_gothic_facade": False,
    },
    "triangles": {"target": 2500, "max": 9000},
    "textures": {"albedo": 512, "embedded": True},
    "style_refs": [
        "history/dossiers/architecture/burgher-house-plan.md",
        "docs/reports/burgher_house_art_brief.md",
        "docs/ART_BIBLE.md",
        "docs/MATERIAL_STYLE_LOCK_KIT.md",
    ],
    "approval": "task-authorized",
}


def main() -> None:
    # Import the shared kit only inside Blender, where bpy and mathutils exist.
    sys.path.insert(0, str(ROOT / "tools"))
    from burgher_house_kit_common import (  # pylint: disable=import-outside-toplevel
        _clear_scene,
        build_house,
        export_glb,
        render_plate,
        standard_materials,
        write_evidence,
    )

    _clear_scene()
    materials = standard_materials("CraftBoda")
    root, objects = build_house(HOUSE_SPEC, materials)
    metrics = export_glb(root, objects, OUTPUT, ASSET_ID)
    metrics["profile"] = "craft_boda"
    metrics["hoist_default"] = False
    metrics["roof_default"] = "thatch"
    metrics["storeys"] = HOUSE_SPEC["storeys"]
    metrics["single_hearth"] = True
    reports = {ASSET_ID: metrics}
    write_evidence(EVIDENCE_DIR, BRIEF, reports)

    if "--preview" in sys.argv:
        render_plate(HOUSE_SPEC, materials, EVIDENCE_DIR / "street_gable.png", "street")
        render_plate(HOUSE_SPEC, materials, EVIDENCE_DIR / "rear_yard.png", "rear")

    print(f"Generated {OUTPUT}")
    print(f"Triangles: {metrics['triangles']}; dimensions_m: {metrics['dimensions_m']}")


if __name__ == "__main__":
    main()
