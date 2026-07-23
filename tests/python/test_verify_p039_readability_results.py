#!/usr/bin/env python3
"""Tests for the P0-039 blind readability results verifier."""

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

import verify_p039_readability_results as verifier  # noqa: E402


def _sample_results(participant_count: int = 5) -> dict:
    template = json.loads(
        (ROOT / "docs/reports/data/p039_readability_results.template.json").read_text(
            encoding="utf-8"
        )
    )
    participant = template["participants"][0]
    return {
        "schema_version": 1,
        "pack_schema_version": 1,
        "session_utc": "2026-07-23T12:00:00+00:00",
        "facilitator": "test.facilitator",
        "participants": [
            {**participant, "participant_id": f"P{index:02d}"}
            for index in range(1, participant_count + 1)
        ],
    }


class VerifyP039ReadabilityResultsTest(unittest.TestCase):
    def test_template_participant_fails_minimum_count(self) -> None:
        minimum, labels, motion_labels = verifier.load_pack_labels(root=ROOT)
        errors = verifier.validate_results(
            _sample_results(participant_count=1),
            minimum_participants=minimum,
            blind_labels=labels,
            motion_labels=motion_labels,
        )
        self.assertTrue(any("at least" in error for error in errors))

    def test_five_participants_pass_validation(self) -> None:
        minimum, labels, motion_labels = verifier.load_pack_labels(root=ROOT)
        errors = verifier.validate_results(
            _sample_results(participant_count=5),
            minimum_participants=minimum,
            blind_labels=labels,
            motion_labels=motion_labels,
        )
        self.assertEqual(errors, [])

    def test_static_stimulus_rejects_motion_score(self) -> None:
        minimum, labels, motion_labels = verifier.load_pack_labels(root=ROOT)
        results = _sample_results(participant_count=5)
        results["participants"][0]["responses"][0]["motion_score"] = 4
        errors = verifier.validate_results(
            results,
            minimum_participants=minimum,
            blind_labels=labels,
            motion_labels=motion_labels,
        )
        self.assertTrue(any("motion_score must be null" in error for error in errors))

    def test_missing_results_file_reports_error(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            missing = root / "docs/reports/data/p039_readability_results.json"
            errors = verifier.verify_file(missing, root=ROOT)
            self.assertTrue(any("missing" in error.lower() or "No such file" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
