#!/usr/bin/env python3
"""Negative fixtures for ADR 0025 Decision 3 building-budget lint (R-1064)."""

from __future__ import annotations

import json
import struct
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from architecture_budgets import (  # noqa: E402
    GLB_MAX_BYTES,
    TIER_CAPS,
    classify_building_glb,
    validate_building_budgets,
)
from verify_asset_lint import validate  # noqa: E402


def _write_glb(
    path: Path,
    *,
    triangles: int = 1,
    materials: int = 1,
    embedded_images: int = 0,
    pad_bytes: int = 0,
    mesh_name: str = "lod0",
) -> None:
    """Write a tiny triangle-list GLB. Padding is why the 7 MiB case stays cheap."""
    verts: list[float] = []
    for index in range(triangles):
        # Three corners of a unit triangle, nudged so they stay unique.
        nudge = float(index)
        verts.extend((0.0, 0.0, nudge, 1.0, 0.0, nudge, 0.0, 1.0, nudge))
    positions = struct.pack("<" + "f" * len(verts), *verts)
    images: list[dict] = []
    buffer_views = [
        {"buffer": 0, "byteOffset": 0, "byteLength": len(positions)},
    ]
    bin_chunk = positions
    png = (
        b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01"
        b"\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01"
        b"\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82"
    )
    for image_index in range(embedded_images):
        buffer_views.append(
            {
                "buffer": 0,
                "byteOffset": len(bin_chunk),
                "byteLength": len(png),
            }
        )
        images.append(
            {
                "bufferView": len(buffer_views) - 1,
                "mimeType": "image/png",
                "name": f"embed_{image_index}",
            }
        )
        bin_chunk += png
    if pad_bytes:
        buffer_views.append(
            {
                "buffer": 0,
                "byteOffset": len(bin_chunk),
                "byteLength": pad_bytes,
            }
        )
        bin_chunk += b"\x00" * pad_bytes

    document = {
        "asset": {"version": "2.0"},
        "buffers": [{"byteLength": len(bin_chunk)}],
        "bufferViews": buffer_views,
        "accessors": [
            {
                "bufferView": 0,
                "componentType": 5126,
                "count": triangles * 3,
                "type": "VEC3",
                "max": [1.0, 1.0, float(max(triangles - 1, 0))],
                "min": [0.0, 0.0, 0.0],
            }
        ],
        "meshes": [
            {
                "name": mesh_name,
                "primitives": [{"attributes": {"POSITION": 0}}],
            }
        ],
        "materials": [{"name": f"slot_{index}"} for index in range(materials)],
    }
    if images:
        document["images"] = images

    json_chunk = json.dumps(document, separators=(",", ":")).encode("utf-8")
    json_padding = (4 - len(json_chunk) % 4) % 4
    json_chunk += b" " * json_padding
    bin_padding = (4 - len(bin_chunk) % 4) % 4
    bin_chunk += b"\x00" * bin_padding
    body = (
        struct.pack("<I", len(json_chunk))
        + b"JSON"
        + json_chunk
        + struct.pack("<I", len(bin_chunk))
        + b"BIN\x00"
        + bin_chunk
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b"glTF" + struct.pack("<II", 2, 12 + len(body)) + body)


def _write_k_part(root: Path, stem: str = "wall_bay", **kwargs) -> Path:
    lod0 = root / "assets/buildings/kit/wall" / f"{stem}.glb"
    _write_glb(lod0, **kwargs)
    sibling_kwargs = dict(kwargs)
    sibling_kwargs["triangles"] = min(int(kwargs.get("triangles", 1)), 10)
    sibling_kwargs.pop("embedded_images", None)
    sibling_kwargs.pop("pad_bytes", None)
    sibling_kwargs["materials"] = kwargs.get("materials", 1)
    _write_glb(
        lod0.with_name(f"{stem}_lod1.glb"),
        **sibling_kwargs,
    )
    return lod0


class ArchitectureBudgetsTests(unittest.TestCase):
    def test_current_repository_passes(self) -> None:
        self.assertEqual(validate_building_budgets(root=ROOT), [])

    def test_facades_are_grandfathered_not_guessed_as_kit(self) -> None:
        rel = (
            "assets/buildings/facades/timber_window_open_shutters/"
            "timber_window_open_shutters.glb"
        )
        classified = classify_building_glb(rel)
        self.assertTrue(classified.grandfathered)
        self.assertIsNone(classified.tier)

    def test_path_prefix_declares_tier(self) -> None:
        self.assertEqual(
            classify_building_glb("assets/buildings/kit/wall/bay.glb").tier,
            "K-part",
        )
        self.assertEqual(
            classify_building_glb("assets/buildings/monastic/dorter.glb").tier,
            "B",
        )
        self.assertEqual(
            classify_building_glb(
                "assets/buildings/fortification/modules/wall_run.glb"
            ).tier,
            "B-module",
        )

    def test_valid_kit_part_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            _write_k_part(root, triangles=12, materials=2)
            self.assertEqual(validate_building_budgets(root=root), [])

    def test_over_cap_lod0_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            cap = int(TIER_CAPS["K-part"]["lod0"] or 0)
            _write_k_part(root, triangles=cap + 1)
            errors = validate_building_budgets(root=root)
            self.assertTrue(any("lod0 triangle budget exceeded" in item for item in errors), errors)

    def test_missing_lod1_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            lod0 = root / "assets/buildings/kit/wall/bay.glb"
            _write_glb(lod0, triangles=12, materials=2)
            errors = validate_building_budgets(root=root)
            self.assertTrue(any("missing LOD1" in item for item in errors), errors)

    def test_missing_lod2_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            lod0 = root / "assets/buildings/monastic/chapel.glb"
            _write_glb(lod0, triangles=20, materials=2)
            _write_glb(lod0.with_name("chapel_lod1.glb"), triangles=8, materials=2)
            errors = validate_building_budgets(root=root)
            self.assertTrue(any("missing LOD2" in item for item in errors), errors)

    def test_embedded_kit_image_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            _write_k_part(root, triangles=8, embedded_images=1)
            errors = validate_building_budgets(root=root)
            self.assertTrue(any("must embed 0 images" in item for item in errors), errors)

    def test_seven_k_material_slots_fail(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            _write_k_part(root, triangles=8, materials=7)
            errors = validate_building_budgets(root=root)
            self.assertTrue(
                any("K material slot budget exceeded (7>6)" in item for item in errors),
                errors,
            )

    def test_seven_mib_glb_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            _write_k_part(root, triangles=4, pad_bytes=7 * 1024 * 1024)
            errors = validate_building_budgets(root=root)
            self.assertTrue(
                any("6 MiB" in item and str(GLB_MAX_BYTES) in item for item in errors),
                errors,
            )

    def test_undeclared_building_glb_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            mystery = root / "assets/buildings/scratch/box.glb"
            _write_glb(mystery, triangles=4)
            errors = validate_building_budgets(root=root)
            self.assertTrue(any("no ADR 0025 tier" in item for item in errors), errors)

    def test_asset_lint_wires_architecture_budget_rule(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            _write_k_part(root, triangles=int(TIER_CAPS["K-part"]["lod0"] or 0) + 2)
            # Style-lock and character fixtures are absent; only assert the
            # architecture rule is present so this test stays scoped to R-1064.
            rules = {issue.rule for issue in validate(root=root)}
            self.assertIn("ASSET_LINT_ARCHITECTURE_BUDGET", rules)


if __name__ == "__main__":
    unittest.main()
