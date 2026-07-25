#!/usr/bin/env python3
"""Tests for the vertical-slice dialogue word-count report."""

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

from report_slice_dialogue_words import main as report_main  # noqa: E402
from slice_dialogue_words import (  # noqa: E402
    build_report,
    count_words,
    extract_dialogue_words,
)


class SliceDialogueWordsTest(unittest.TestCase):
    def test_count_words_ignores_punctuation(self) -> None:
        self.assertEqual(count_words("Hello, world - again."), 3)

    def test_extract_dialogue_words_skips_ids(self) -> None:
        record = {
            "id": "dialogue.test.sample",
            "nodes": [
                {
                    "id": "intro",
                    "speaker_id": "char.kalev",
                    "text": "Two spoken words.",
                    "choices": [
                        {
                            "id": "choice_one",
                            "text": "Three more words.",
                            "target_node_id": "end",
                        }
                    ],
                }
            ],
        }
        lines = extract_dialogue_words(record, "dialogue.test.sample")
        texts = [line.text for line in lines]
        self.assertIn("Two spoken words.", texts)
        self.assertIn("Three more words.", texts)
        self.assertEqual(sum(line.words for line in lines), 6)

    def test_repository_slice_report_stays_within_budget(self) -> None:
        report = build_report(ROOT)
        self.assertFalse(report.errors, msg="\n".join(report.errors))
        self.assertLessEqual(report.total_words, report.word_budget)

    def test_check_mode_exits_zero_on_current_corpus(self) -> None:
        self.assertEqual(report_main(["--check"]), 0)

    def test_manifest_is_valid_json(self) -> None:
        manifest_path = ROOT / "docs/data/slice_dialogue_manifest.json"
        payload = json.loads(manifest_path.read_text(encoding="utf-8"))
        self.assertEqual(payload["word_budget"], 2500)
        self.assertGreaterEqual(len(payload["dialogue_ids"]), 10)

    def test_json_output_is_written(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            output = Path(temp_dir) / "slice_dialogue_words.json"
            exit_code = report_main(["--json", str(output), "--check"])
            self.assertEqual(exit_code, 0)
            payload = json.loads(output.read_text(encoding="utf-8"))
            self.assertIn("total_words", payload)
            self.assertTrue(payload["within_budget"])


if __name__ == "__main__":
    unittest.main()
