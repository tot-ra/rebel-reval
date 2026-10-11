#!/usr/bin/env python3
"""Tests for tools/verify_world_layout.py (WB-08 / R-980)."""

from __future__ import annotations

import copy
import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS_DIR = ROOT / "tools"
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from verify_world_layout import DEFAULT_MANIFEST, fingerprint, main, verify  # noqa: E402

A_RRMAP = (
    "map map_a\n"
    "transition to_b 9 2 1 4 to=scene_b spawn=a_from_b destination_spawn=b_from_a\n"
    "transition to_forge 3 3 1 1 to=forge spawn=a_door destination_spawn=forge_in\n"
)
B_RRMAP = (
    "map map_b\n"
    "transition to_a 0 2 1 4 to=scene_a spawn=b_from_a destination_spawn=a_from_b\n"
    "transition road 9 5 1 2 to=scene_a spawn=b_road destination_spawn=a_road alignment=travel\n"
)


def _location(location_id: str, scene_id: str, origin: list[int], parent: str, sha: str) -> dict:
    return {
        "location_id": location_id,
        "scene_id": scene_id,
        "location_kind": "outdoor_streamed",
        "package_path": f"res://maps/{location_id}.rrmap",
        "source_sha256": sha,
        "map_fingerprint": f"{location_id}-fp",
        "cell_size": 32,
        "origin_cell": origin,
        "size_cells": [10, 8],
        "global_bounds_cells": [origin[0], origin[1], origin[0] + 10, origin[1] + 8],
        "placement_parent": parent,
    }


def _manifest(root: Path) -> dict:
    sha_a = hashlib.sha256(A_RRMAP.encode()).hexdigest()
    sha_b = hashlib.sha256(B_RRMAP.encode()).hexdigest()
    manifest = {
        "schema": "rr.world_layout.v1",
        "world_group_id": "test_outdoor",
        "root_location_id": "map_a",
        "cell_size": 32,
        "valid": True,
        "errors": [],
        "warnings": [],
        "locations": [
            _location("map_a", "scene_a", [0, 0], "", sha_a),
            _location("map_b", "scene_b", [10, 0], "map_a", sha_b),
        ],
        "seams": [
            {
                "id": "map_a/to_b|map_b/to_a",
                "base_map_id": "map_a",
                "neighbor_map_id": "map_b",
                "base_transition_id": "to_b",
                "neighbor_transition_id": "to_a",
                "base_side": "east",
                "neighbor_side": "west",
                "base_span_cells": 4,
                "neighbor_span_cells": 4,
                "alignment": "physical",
                "status": "streamable",
                "diagnostics": [],
            }
        ],
        "explicit_transitions": [],
        "unplaced": [],
    }
    manifest["fingerprint"] = fingerprint(manifest)
    return manifest


def _refingerprint(manifest: dict) -> dict:
    manifest["fingerprint"] = fingerprint(manifest)
    return manifest


class VerifyWorldLayoutTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        (self.root / "maps").mkdir()
        (self.root / "maps/map_a.rrmap").write_text(A_RRMAP, encoding="utf-8")
        (self.root / "maps/map_b.rrmap").write_text(B_RRMAP, encoding="utf-8")
        self.manifest = _manifest(self.root)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def test_fixture_passes(self) -> None:
        self.assertEqual(verify(self.manifest, self.root), [])

    def test_checked_in_state_passes(self) -> None:
        # ADR 0031 retired reval_outdoor: no manifest, and the plan streams nothing.
        self.assertFalse((ROOT / DEFAULT_MANIFEST).exists())
        self.assertEqual(main(["--manifest", DEFAULT_MANIFEST]), 0)

    def test_missing_manifest_fails_while_plan_streams_members(self) -> None:
        (self.root / "docs").mkdir()
        (self.root / "docs/SEAMLESS_STREAMING_PLAN.md").write_text(
            "### Streamed: `world_group_id = reval_outdoor`\n| `map_a` | a |\n### Interiors: y\n",
            encoding="utf-8",
        )
        self.assertEqual(main(["--manifest", "missing.json", "--root", str(self.root)]), 1)

    def test_tampered_body_fails_fingerprint(self) -> None:
        self.manifest["locations"][1]["origin_cell"] = [11, 0]
        errors = verify(self.manifest, self.root)
        self.assertTrue(any("fingerprint" in error for error in errors), errors)

    def test_stale_source_fails(self) -> None:
        (self.root / "maps/map_b.rrmap").write_text(B_RRMAP + "# edit\n", encoding="utf-8")
        errors = verify(self.manifest, self.root)
        self.assertTrue(any("source changed" in error for error in errors), errors)

    def test_overlap_fails(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        manifest["locations"][1]["origin_cell"] = [8, 0]
        manifest["locations"][1]["global_bounds_cells"] = [8, 0, 18, 8]
        errors = verify(_refingerprint(manifest), self.root)
        self.assertTrue(any("overlap" in error for error in errors), errors)
        self.assertTrue(any("touching edges" in error for error in errors), errors)

    def test_placement_cycle_fails(self) -> None:
        self.manifest["locations"][0]["placement_parent"] = "map_b"
        errors = verify(_refingerprint(self.manifest), self.root)
        self.assertTrue(any("cycle" in error for error in errors), errors)

    def test_travel_transition_as_seam_fails(self) -> None:
        # Pretend the travel road on map_b was streamed.
        self.manifest["seams"][0]["neighbor_transition_id"] = "road"
        errors = verify(_refingerprint(self.manifest), self.root)
        self.assertTrue(any("travel or out-of-group" in error for error in errors), errors)
        self.assertTrue(any("is not a manifest seam" in error for error in errors), errors)

    def test_missing_reciprocal_seam_fails(self) -> None:
        self.manifest["seams"] = []
        errors = verify(_refingerprint(self.manifest), self.root)
        self.assertTrue(any("is not a manifest seam" in error for error in errors), errors)

    def test_mismatched_span_must_be_blocked(self) -> None:
        self.manifest["seams"][0]["neighbor_span_cells"] = 3
        errors = verify(_refingerprint(self.manifest), self.root)
        self.assertTrue(any("mismatched spans but streams" in error for error in errors), errors)
        self.manifest["seams"][0]["status"] = "blocked"
        self.manifest["seams"][0]["diagnostics"] = ["MAP_WORLD_SEAM_SPAN_MISMATCH"]
        self.assertEqual(verify(_refingerprint(self.manifest), self.root), [])

    def test_membership_must_match_plan(self) -> None:
        (self.root / "docs").mkdir()
        (self.root / "docs/SEAMLESS_STREAMING_PLAN.md").write_text(
            "### Streamed: x\n| `map_a` | a |\n### Interiors: y\n", encoding="utf-8"
        )
        errors = verify(self.manifest, self.root)
        self.assertTrue(any("streamed table" in error for error in errors), errors)


if __name__ == "__main__":
    unittest.main()
