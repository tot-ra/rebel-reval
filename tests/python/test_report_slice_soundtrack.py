#!/usr/bin/env python3
"""Tests for the vertical-slice soundtrack budget report."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from report_slice_soundtrack import main as report_main  # noqa: E402
from slice_soundtrack import (  # noqa: E402
    build_report,
    music_director_slice_track_paths,
    verify_music_director_matches_manifest,
)


class SliceSoundtrackReportTest(unittest.TestCase):
    def test_manifest_is_valid_json(self) -> None:
        manifest_path = ROOT / "docs/data/slice_soundtrack_manifest.json"
        payload = json.loads(manifest_path.read_text(encoding="utf-8"))
        self.assertEqual(payload["duration_budget_seconds"], 720)
        self.assertEqual(payload["release_theme_ids"], ["menu", "forge", "town"])

    def test_repository_slice_report_stays_within_budget(self) -> None:
        report = build_report(ROOT)
        self.assertFalse(report.errors, msg="\n".join(report.errors))
        self.assertLessEqual(
            report.budgeted_duration_seconds,
            report.duration_budget_seconds,
        )
        self.assertEqual(report.unique_track_count(), 4)

    def test_music_director_matches_manifest(self) -> None:
        errors = verify_music_director_matches_manifest(ROOT)
        self.assertEqual(errors, [])

    def test_slice_track_paths_are_trimmed(self) -> None:
        wired = music_director_slice_track_paths(ROOT)
        self.assertEqual(len(wired["forge"]), 1)
        self.assertEqual(len(wired["town"]), 2)
        self.assertEqual(wired["menu"], ["music/menu/Menu.mp3"])

    def test_check_mode_exits_zero_on_current_corpus(self) -> None:
        self.assertEqual(report_main(["--check"]), 0)

    def test_json_output_is_written(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            output = Path(temp_dir) / "slice_soundtrack.json"
            exit_code = report_main(["--json", str(output), "--check"])
            self.assertEqual(exit_code, 0)
            payload = json.loads(output.read_text(encoding="utf-8"))
            self.assertIn("budgeted_duration_seconds", payload)
            self.assertTrue(payload["within_budget"])


if __name__ == "__main__":
    unittest.main()
