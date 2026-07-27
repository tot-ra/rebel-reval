"""Tests for Act 1 content-budget report (P4-010)."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from act1_content_budget import build_report  # noqa: E402
from report_act1_content_budget import main as report_main  # noqa: E402

MANIFEST = ROOT / "docs/data/act1_content_budget_manifest.json"


class TestReportAct1ContentBudget(unittest.TestCase):
    def test_manifest_matches_authored_act1_scope(self) -> None:
        report = build_report(ROOT, MANIFEST)
        self.assertTrue(report.within_budget, "\n".join(report.errors))
        self.assertEqual(report.district_count, 3)
        self.assertEqual(report.core_character_count, 7)
        self.assertEqual(report.cycle_quest_count, 5)
        self.assertEqual(report.climax_quest_count, 1)
        self.assertEqual(report.substantial_quest_count, 8)
        self.assertEqual(report.faction_line_count, 2)

    def test_dialogue_and_audio_stay_within_budget(self) -> None:
        report = build_report(ROOT, MANIFEST)
        self.assertLessEqual(report.dialogue_words, report.dialogue_word_budget)
        self.assertLessEqual(
            report.audio_duration_seconds,
            float(report.audio_duration_budget_seconds),
        )

    def test_check_mode_exits_zero_on_current_corpus(self) -> None:
        self.assertEqual(report_main(["--check"]), 0)


if __name__ == "__main__":
    unittest.main()
