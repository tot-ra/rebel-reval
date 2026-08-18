#!/usr/bin/env python3
"""Generate the production Reval 1343 merchant-timber frontage kit.

Run from the repository root:
    blender --background --factory-startup --python \
        tools/generate_burgher_house_merchant_timber.py -- --preview

The profile intentionally keeps the merchant-timber family below the stone
merchant silhouette: a two-storey limewashed timber front, restrained shutters,
a single storage hatch, optional stone cellar base, and a shingle roof. The
hoist is disabled by default so an ordinary timber frontage does not become a
late-Gothic tourist or granary-crane facade.
"""

from __future__ import annotations

import sys
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "props" / "architecture" / "houses" / "merchant_timber" / "merchant_timber.glb"
EVIDENCE_DIR = ROOT / "generated" / "blender" / "burgher_house_merchant_timber_v1"
ASSET_ID = "prop.architecture.house.merchant_timber"

# R-003 / A-008: 7-11 m strip frontage, two typical storeys, timber/plaster
# frontage, small openings, optional mixed stone cellar, shingle-forward roof.
HOUSE_SPEC: dict[str, object] = {
    "name": "MerchantTimber",
    "width": 8.6,
    "depth": 18.0,
    "storeys": 2,
    "storey_h": 2.85,
    "wall": "limewash",
    "gable_wall": "limewash",
    "trim": "oak_aged",
    "roof": "shingle",
    "door": "oak_aged",
    "stone_base_h": 0.52,
    "portal_x": -2.15,
    "door_w": 1.12,
    "door_h": 2.15,
    "portal_steps": 2,
    "ground_window": True,
    "ground_window_x": 2.1,
    "ground_window_w": 1.05,
    "ground_window_h": 1.1,
    "ground_window_shutters": "closed",
    "hatch_storeys": 1,
    "hatch_x": 0.45,
    "hoist": False,
    "upper_window": True,
    "upper_window_x": -2.05,
    "timber_frame": True,
    "anchor_plates": False,
    "quoins": False,
    "chimney": True,
    "chimney_mat": "limestone_dark",
    "gable_vent": True,
    "vent_x": 2.0,
    "overhang": 0.42,
}

BRIEF = {
    "id": ASSET_ID,
    "kind": "rigid_architecture",
    "target": "res://assets/props/architecture/houses/merchant_timber/merchant_timber.glb",
    "tier": "merchant_timber",
    "dimensions_m": {"frontage": 8.6, "depth": 18.0, "typical_storeys": 2},
    "features": {
        "timber_or_plastered_front": True,
        "small_shuttered_openings": True,
        "optional_stone_cellar": True,
        "shingle_forward_roof": True,
        "default_hoist": False,
        "late_gothic_facade": False,
    },
    "triangles": {"target": 4500, "max": 9000},
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
    materials = standard_materials("MerchantTimber")
    root, objects = build_house(HOUSE_SPEC, materials)
    metrics = export_glb(root, objects, OUTPUT, ASSET_ID)
    metrics["profile"] = "merchant_timber"
    metrics["hoist_default"] = False
    metrics["roof_default"] = "shingle"
    metrics["timber_frame"] = True
    metrics["stone_cellar_base"] = True
    reports = {ASSET_ID: metrics}
    write_evidence(EVIDENCE_DIR, BRIEF, reports)

    if "--preview" in sys.argv:
        render_plate(HOUSE_SPEC, materials, EVIDENCE_DIR / "street_gable.png", "street")
        render_plate(HOUSE_SPEC, materials, EVIDENCE_DIR / "rear_yard.png", "rear")

    print(f"Generated {OUTPUT}")
    print(f"Triangles: {metrics['triangles']}; dimensions_m: {metrics['dimensions_m']}")


if __name__ == "__main__":
    main()
