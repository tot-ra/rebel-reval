#!/usr/bin/env python3
"""Deterministic current-revision audit for the Lower Town P0-101 baseline."""

from __future__ import annotations

import hashlib
import json
import re
import unittest
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAP_PATH = ROOT / "content/maps/lower_town_slice.rrmap"
MANIFEST_PATH = ROOT / "docs/reports/images/lower_town_p0_101/capture_manifest.json"
RECORD_RE = re.compile(r"^(building|landmark)\s+(\S+)\s+(\S+)\s+")
TIER_RE = re.compile(r"\bhouse_tier=(\S+)")

EXPECTED_MAP_SHA256 = "6ae0b82a0a46a7391cb5db5a0bb02e562756def8073fe08cf63beebd7ace7e50"
EXPECTED_CAPTURE_PRESETS = {
    "market_primary_spine",
    "merchant_craft_lane",
    "service_yard",
    "eastern_artisan_wet_margin",
    "landmark_approaches",
}
EXPECTED_COUNTS = {"house": 61, "wall": 36, "gate_arch": 2}
EXPECTED_TIERS = {"merchant_stone": 14, "merchant_timber": 14, "craft_boda": 23}
REQUIRED_IDS = {
    "st_catherines_church",
    "viru_gate_arch",
    "viru_foregate_arch",
    "viru_gate_north_tower",
    "viru_gate_south_tower",
    "viru_gate_north_jamb",
    "viru_gate_south_jamb",
    "foregate_tower_north",
    "foregate_tower_south",
    "foregate_north_jamb",
    "foregate_south_jamb",
}
REAR_WORKSHOP_IDS = {
    "saddlers_rear_workshop",
    "coopers_rear_workshop",
    "sauna_rear_boda",
    "rope_makers_rear_store",
    "karja_rear_boda",
    "brewery_rear_store",
    "smithy_rear_shed",
    "carriers_barn",
}


def parse_records() -> list[dict[str, object]]:
    records: list[dict[str, object]] = []
    for line_number, line in enumerate(MAP_PATH.read_text(encoding="utf-8").splitlines(), 1):
        match = RECORD_RE.match(line)
        if match is None:
            continue
        kind, stable_id, subtype = match.groups()
        records.append(
            {
                "line": line_number,
                "kind": kind,
                "id": stable_id,
                "subtype": subtype,
                "tier": (TIER_RE.search(line).group(1) if TIER_RE.search(line) else None),
            }
        )
    return records


class LowerTownP0101BaselineTest(unittest.TestCase):
    def test_current_source_fingerprint_and_record_counts(self) -> None:
        records = parse_records()
        self.assertEqual(hashlib.sha256(MAP_PATH.read_bytes()).hexdigest(), EXPECTED_MAP_SHA256)
        self.assertEqual(len(records), 99)
        self.assertEqual(Counter(str(record["subtype"]) for record in records), Counter(EXPECTED_COUNTS))
        self.assertEqual(len({str(record["id"]) for record in records}), len(records))

    def test_current_tier_and_rear_workshop_inventory(self) -> None:
        records = parse_records()
        tiers = Counter(
            str(record["tier"])
            for record in records
            if record["tier"] is not None
        )
        self.assertEqual(tiers, Counter(EXPECTED_TIERS))
        self.assertEqual(
            {str(record["id"]) for record in records if record["tier"] == "craft_boda"}
            & REAR_WORKSHOP_IDS,
            REAR_WORKSHOP_IDS,
        )

    def test_required_landmark_and_gate_ids_are_present(self) -> None:
        records = parse_records()
        record_by_id = {str(record["id"]): record for record in records}
        self.assertTrue(REQUIRED_IDS <= record_by_id.keys())
        self.assertEqual(record_by_id["st_catherines_church"]["subtype"], "house")
        self.assertEqual(record_by_id["viru_gate_arch"]["subtype"], "gate_arch")
        self.assertEqual(record_by_id["viru_foregate_arch"]["subtype"], "gate_arch")

    def test_capture_manifest_matches_current_source_and_preserves_packet_integrity(self) -> None:
        manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        current_source_sha = hashlib.sha256(MAP_PATH.read_bytes()).hexdigest()
        self.assertEqual(manifest["map_source_sha256"], current_source_sha)
        self.assertEqual(manifest["map_source_sha256"], EXPECTED_MAP_SHA256)
        self.assertEqual(len(manifest["plates"]), 10)
        plates_by_preset = Counter(
            str(plate["preset_id"])
            for plate in manifest["plates"]
        )
        self.assertEqual(plates_by_preset, Counter({preset: 2 for preset in EXPECTED_CAPTURE_PRESETS}))
        self.assertEqual(Counter(str(plate["time_of_day"]) for plate in manifest["plates"]), Counter(day=5, night=5))
        self.assertTrue(all("stable_ids" not in plate for plate in manifest["plates"]))

    def test_capture_manifest_keeps_stable_id_observations_unreviewed(self) -> None:
        manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        observations = manifest["stable_id_observation_coverage"]
        self.assertEqual(len(observations), 5)
        self.assertEqual(
            {str(observation["preset_id"]) for observation in observations},
            EXPECTED_CAPTURE_PRESETS,
        )
        for observation in observations:
            for time_of_day in ("day", "night"):
                review = observation[time_of_day]
                self.assertEqual(review["status"], "not_reviewed")
                self.assertEqual(review["stable_ids"], [])
        self.assertFalse(any(observation["day"]["stable_ids"] for observation in observations))
        self.assertFalse(any(observation["night"]["stable_ids"] for observation in observations))


if __name__ == "__main__":
    unittest.main()
