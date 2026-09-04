#!/usr/bin/env python3
"""Generate the production Reval 1343 merchant-stone frontage kit.

Run from the repository root:
    blender --background --factory-startup --python \
        tools/generate_burgher_house_merchant_stone.py -- --preview

The profile is the tall limestone merchant tier from R-003: a steep
street-facing gable, raised cellar-neck threshold, large ground opening,
stacked storage hatches, and a restrained hoist beam. It intentionally avoids
late-Gothic glazed crosses, blind niches, and tourist-monument enrichment.
"""

from __future__ import annotations

import sys
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "props" / "architecture" / "houses" / "merchant_stone" / "merchant_stone.glb"
EVIDENCE_DIR = ROOT / "generated" / "blender" / "burgher_house_merchant_stone_v1"
ASSET_ID = "prop.architecture.house.merchant_stone"

# R-003 / A-008: 7-11 m frontage, 2-3 storeys, limestone or mixed front,
# street portal + ground opening, hatch-over-window storage rhythm, tile roof.
HOUSE_SPEC: dict[str, object] = {
    "name": "MerchantStone",
    "width": 9.4,
    "depth": 19.5,
    "storeys": 3,
    "storey_h": 2.9,
    "wall": "limestone",
    "gable_wall": "limestone",
    "trim": "limestone_dark",
    "roof": "tile",
    "door": "oak_aged",
    "stone_base_h": 0.0,
    "portal_x": -2.35,
    "door_w": 1.35,
    "door_h": 2.35,
    "portal_steps": 3,
    "terrace": True,
    "ground_window": True,
    "ground_window_x": 2.25,
    "ground_window_w": 1.65,
    "ground_window_h": 1.45,
    "ground_window_shutters": "open",
    "hatch_storeys": 2,
    "hatch_x": 0.65,
    "hoist": True,
    "upper_window": False,
    "anchor_plates": False,
    "quoins": True,
    "chimney": True,
    "chimney_mat": "limestone_dark",
    "gable_vent": True,
    "vent_x": 2.2,
    "overhang": 0.48,
}

BRIEF = {
    "id": ASSET_ID,
    "kind": "rigid_architecture",
    "target": "res://assets/props/architecture/houses/merchant_stone/merchant_stone.glb",
    "tier": "merchant_stone",
    "dimensions_m": {"frontage": 9.4, "depth": 19.5, "typical_storeys": 3},
    "features": {
        "steep_gable_to_street": True,
        "limestone_or_mixed_front": True,
        "street_portal": True,
        "large_ground_opening": True,
        "upper_loading_hatches": True,
        "protruding_hoist_beam": True,
        "raised_cellar_neck": True,
        "tile_roof_band": True,
        "late_gothic_facade": False,
    },
    "triangles": {"target": 6000, "max": 9000},
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
    materials = standard_materials("MerchantStone")
    root, objects = build_house(HOUSE_SPEC, materials)
    metrics = export_glb(root, objects, OUTPUT, ASSET_ID)
    metrics["profile"] = "merchant_stone"
    metrics["hoist_default"] = True
    metrics["roof_default"] = "tile"
    metrics["limestone_front"] = True
    metrics["raised_cellar_neck"] = True
    reports = {ASSET_ID: metrics}
    write_evidence(EVIDENCE_DIR, BRIEF, reports)

    if "--preview" in sys.argv:
        render_plate(HOUSE_SPEC, materials, EVIDENCE_DIR / "street_gable.png", "street")
        render_plate(HOUSE_SPEC, materials, EVIDENCE_DIR / "rear_yard.png", "rear")

    print(f"Generated {OUTPUT}")
    print(f"Triangles: {metrics['triangles']}; dimensions_m: {metrics['dimensions_m']}")


if __name__ == "__main__":
    main()
