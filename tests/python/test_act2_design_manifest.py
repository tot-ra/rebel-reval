#!/usr/bin/env python3
"""Verify P5-001 Act 2 design manifest maps missions to TODO rows and labelled events."""

from __future__ import annotations

import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / "docs" / "data" / "act2_design_manifest.json"
TODO_PATH = ROOT / "TODO.md"
REPORT_PATH = ROOT / "docs" / "reports" / "p5_001_act2_design.md"
CANON_PATH = ROOT / "docs" / "CANON.md"
FACTION_LEDGER_PATH = ROOT / "scripts" / "faction" / "faction_ledger.gd"

ALLOWED_CONFIDENCE = {"attested", "plausible composite", "folklore", "invented"}
BOUNDARY_FLAGS = {
    "flag.act_boundary.viru_seal",
    "flag.act_boundary.viru_break",
    "flag.act_boundary.viru_open",
}


class TestAct2DesignManifest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        cls.todo = TODO_PATH.read_text(encoding="utf-8")
        cls.report = REPORT_PATH.read_text(encoding="utf-8")
        cls.canon = CANON_PATH.read_text(encoding="utf-8")
        cls.faction_ledger = FACTION_LEDGER_PATH.read_text(encoding="utf-8")

    def test_manifest_task_and_report_exist(self) -> None:
        self.assertEqual(self.manifest.get("task"), "P5-001")
        self.assertTrue(REPORT_PATH.is_file())
        self.assertIn("P5-001", self.report)

    def test_boundary_flags_match_act1_contract(self) -> None:
        flags = set(self.manifest.get("act_boundary_flags", []))
        self.assertEqual(flags, BOUNDARY_FLAGS)
        for flag in BOUNDARY_FLAGS:
            self.assertIn(flag, self.report)

    def test_every_mission_maps_to_todo_row(self) -> None:
        missions = self.manifest.get("missions", [])
        self.assertGreaterEqual(len(missions), 12)
        for mission in missions:
            todo_id = mission["todo"]
            # (?m) so ^ matches each TODO row, not only the start of the file.
            pattern = rf"(?m)^- \[[ x~!]\] {re.escape(todo_id)} \|"
            self.assertIsNotNone(
                re.search(pattern, self.todo),
                msg=f"mission {mission['id']} todo {todo_id} missing from TODO.md",
            )
            self.assertTrue(mission.get("system"), msg=f"{mission['id']} missing system")

    def test_every_event_has_allowed_confidence(self) -> None:
        events = self.manifest.get("events", [])
        self.assertGreaterEqual(len(events), 5)
        for event in events:
            label = event["confidence"]
            self.assertIn(label, ALLOWED_CONFIDENCE, msg=event["id"])
            # Named battles/finale must appear in CANON with a confidence marker nearby.
            if event["id"] in {
                "event.kanavere_bog",
                "event.sojamae",
                "event.paide_four_kings",
            }:
                self.assertIn("`", self.canon)  # confidence markup present in file
                key = {
                    "event.kanavere_bog": "Kanavere",
                    "event.sojamae": "Sõjamäe",
                    "event.paide_four_kings": "Paide",
                }[event["id"]]
                self.assertIn(key, self.canon)

    def test_faction_ids_match_ledger(self) -> None:
        for faction_id in self.manifest.get("factions", []):
            self.assertIn(f'"{faction_id}"', self.faction_ledger)

    def test_siege_phases_named(self) -> None:
        phase_ids = {phase["id"] for phase in self.manifest.get("siege_phases", [])}
        self.assertEqual(
            phase_ids,
            {"siege.investment", "siege.sortie_supply", "siege.assault"},
        )


if __name__ == "__main__":
    unittest.main()
