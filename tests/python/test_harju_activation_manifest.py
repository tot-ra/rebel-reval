from __future__ import annotations

import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
HARJU_RRMAP = ROOT / "content/maps/world_harju.rrmap"
CATALOG = ROOT / "scripts/map/map_catalog.gd"
DESTINATIONS = ROOT / "content/transitions/active_destinations.json"
P5_MANIFEST = ROOT / "docs/data/p5_003_activation_manifest.json"
LOCATION_MANIFEST = ROOT / "docs/data/location_activation_manifest.json"

EXPECTED_DEV_SPAWNS = {
    "from_reval_east",
    "from_world_sacred_grove",
    "from_world_rebel_kings",
    "from_world_kanavere",
    "from_world_sojamae",
}
EXPECTED_ANCHORS = {
    "landmark_village_well": (25, 15),
    "landmark_threshing_barn": (35, 12),
    "landmark_split_fields": (42, 6),
}


class TestHarjuActivationManifest(unittest.TestCase):
    def test_rrmap_stays_prototype_and_required_anchors_are_clear(self) -> None:
        text = HARJU_RRMAP.read_text(encoding="utf-8")
        map_match = re.search(
            r"^map world\.harju .* scope=(\w+) active=(true|false)\b",
            text,
            re.MULTILINE,
        )
        self.assertIsNotNone(map_match)
        self.assertEqual(("prototype", "false"), map_match.groups())

        anchors = {
            match.group(1): (int(match.group(2)), int(match.group(3)))
            for match in re.finditer(
                r"^anchor (\S+) (\d+) (\d+) kind=\S+$",
                text,
                re.MULTILINE,
            )
        }
        self.assertEqual(EXPECTED_ANCHORS, anchors)

    def test_catalog_stays_prototype_and_inactive(self) -> None:
        text = CATALOG.read_text(encoding="utf-8")
        entry_match = re.search(
            r'(?ms)^\s*"world_harju":\s*(\{.*?\})(?=,?\s*\n\s*")',
            text,
        )
        self.assertIsNotNone(entry_match)
        self.assertRegex(
            entry_match.group(1),
            r'"path":\s*"res://scenes/world_travel/world_harju\.tscn"',
        )
        self.assertRegex(entry_match.group(1), r'"scope":\s*"prototype"')
        self.assertRegex(entry_match.group(1), r'"active":\s*false')

    def test_developer_traversal_remains_unreleased(self) -> None:
        manifest = json.loads(DESTINATIONS.read_text(encoding="utf-8"))
        matches = [row for row in manifest["scenes"] if row.get("id") == "world_harju"]
        self.assertEqual(1, len(matches))
        harju = matches[0]
        self.assertTrue(harju["active"])
        self.assertFalse(harju["release"])
        self.assertEqual(EXPECTED_DEV_SPAWNS, {row["id"] for row in harju["spawns"]})

    def test_blocked_ledgers_keep_anchor_and_parity_boundaries(self) -> None:
        location_manifest = json.loads(LOCATION_MANIFEST.read_text(encoding="utf-8"))
        harju = next(row for row in location_manifest["maps"] if row["map_id"] == "world.harju")
        self.assertFalse(harju["implementation_delivered"])
        self.assertEqual("PASS", harju["mandatory_anchors"]["status"])
        self.assertEqual([], harju["mandatory_anchors"]["blocked"])
        self.assertEqual("BLOCKED", harju["gameplay"]["status"])

        p5_manifest = json.loads(P5_MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual("blocked", p5_manifest["decision"])
        self.assertIn("P5-002", p5_manifest["blockers"])
        parity = p5_manifest["gates"]["day_night_parity"]["locations"]["world_harju"]
        self.assertEqual("pending", parity["status"])
        self.assertIsNone(parity["day_capture"])
        self.assertIsNone(parity["night_capture"])


if __name__ == "__main__":
    unittest.main()
