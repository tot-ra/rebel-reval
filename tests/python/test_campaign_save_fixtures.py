"""Contract checks for the P6-006 cross-act save compatibility corpus."""

from __future__ import annotations

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / "content" / "saves" / "campaign_fixtures_manifest.json"

EXPECTED_BOUNDARIES = {"seal", "break", "open"}
REQUIRED_FIXTURE_IDS = {
    "save.demo_fresh_start",
    "save.demo_post_pickup",
    "save.game_state_v1_legacy",
    "save.slice_prologue_complete",
    "save.act1_boundary_seal",
    "save.act1_boundary_break",
    "save.act1_boundary_open",
}


class TestCampaignSaveFixtures(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))

    def test_manifest_declares_current_p6_006_corpus(self) -> None:
        self.assertEqual(self.manifest["schema_version"], 1)
        self.assertEqual(self.manifest["task_id"], "P6-006")
        self.assertEqual(
            set(self.manifest["intended_act1_boundaries"]),
            EXPECTED_BOUNDARIES,
        )

        fixtures = self.manifest["fixtures"]
        self.assertEqual(
            {fixture["id"] for fixture in fixtures},
            REQUIRED_FIXTURE_IDS,
        )
        self.assertEqual(
            len(fixtures),
            len({fixture["path"] for fixture in fixtures}),
            "fixture paths must be unique",
        )

    def test_every_fixture_is_a_valid_current_or_migratable_envelope(self) -> None:
        for fixture in self.manifest["fixtures"]:
            with self.subTest(fixture=fixture["id"]):
                path = ROOT / "content" / "saves" / fixture["path"]
                self.assertTrue(path.is_file(), f"missing fixture: {path}")
                payload = json.loads(path.read_text(encoding="utf-8"))
                self.assertIsInstance(payload, dict)
                self.assertEqual(payload.get("save_version"), 1)
                game_state = payload.get("game_state")
                self.assertIsInstance(game_state, dict)
                self.assertEqual(game_state.get("phase"), fixture["expected_phase"])
                self.assertEqual(
                    game_state.get("version"),
                    fixture["expected_game_state_version"],
                )

                source_version = fixture.get("source_game_state_version")
                if source_version is not None:
                    self.assertNotEqual(
                        game_state.get("version"),
                        source_version,
                        "legacy fixture must remain a migration input",
                    )

    def test_act1_boundary_fixtures_cover_distinct_branch_outcomes(self) -> None:
        boundary_fixtures = [
            fixture
            for fixture in self.manifest["fixtures"]
            if fixture["campaign_stage"] == "act1_boundary"
        ]
        self.assertEqual(
            {fixture["expected_act_boundary"] for fixture in boundary_fixtures},
            EXPECTED_BOUNDARIES,
        )
        for fixture in boundary_fixtures:
            with self.subTest(fixture=fixture["id"]):
                payload = json.loads(
                    (ROOT / "content" / "saves" / fixture["path"]).read_text(
                        encoding="utf-8"
                    )
                )
                game_state = payload["game_state"]
                self.assertEqual(
                    game_state["act1_transition"]["act_boundary"],
                    fixture["expected_act_boundary"],
                )
                self.assertEqual(
                    game_state["quest_states"][fixture["expected_quest_id"]],
                    fixture["expected_quest_state"],
                )


if __name__ == "__main__":
    unittest.main()
