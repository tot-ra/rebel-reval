#!/usr/bin/env python3
"""Tests for the ADR 0035 sfx catalog validator and audio license gate."""

from __future__ import annotations

import copy
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import validate_asset_sources as sources  # noqa: E402
import validate_sfx_catalog as catalog  # noqa: E402


def _row(**overrides: str) -> dict[str, str]:
    row = {
        "asset_id": "sounds.test",
        "path": "sounds/test.mp3",
        "creator_or_tool": "someone",
        "model_version": "n/a",
        "prompt_or_url": "https://example.invalid",
        "seed": "n/a",
        "license": "CC0 1.0",
        "edits": "none",
        "approval": "approved - test",
    }
    row.update(overrides)
    return row


class SfxCatalogTest(unittest.TestCase):
    def test_repository_catalog_passes(self) -> None:
        self.assertEqual(catalog.validate(), [])

    def test_unknown_source_and_missing_stream_are_rejected(self) -> None:
        payload = json.loads(catalog.CATALOG.read_text(encoding="utf-8"))
        entry = copy.deepcopy(payload["entries"][0])
        entry["source_ids"] = ["sounds.nope"]
        entry["streams"] = ["res://sounds/missing.mp3"]
        payload["entries"] = [entry, copy.deepcopy(entry)]
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "cat.json"
            path.write_text(json.dumps(payload), encoding="utf-8")
            errors = catalog.validate(path)
        text = "\n".join(errors)
        self.assertIn("duplicate id", text)
        self.assertIn("not in assets/SOURCES.csv", text)
        self.assertIn("stream missing on disk", text)

    def test_bad_bus_fails_schema(self) -> None:
        payload = json.loads(catalog.CATALOG.read_text(encoding="utf-8"))
        payload["entries"][0]["bus"] = "Nope"
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "cat.json"
            path.write_text(json.dumps(payload), encoding="utf-8")
            self.assertTrue(catalog.validate(path)[0].startswith("schema:"))


class AudioLicenseGateTest(unittest.TestCase):
    def test_allowlisted_rows_pass(self) -> None:
        self.assertEqual(sources.audio_license_errors([_row(), _row(license="CC BY 4.0")]), [])

    def test_non_commercial_and_banned_models_fail(self) -> None:
        rows = [
            _row(license="CC BY-NC 4.0"),
            _row(creator_or_tool="AudioLDM 2"),
            _row(license="BBC RemArc"),
        ]
        self.assertEqual(len(sources.audio_license_errors(rows)), 3)

    def test_elevenlabs_requires_paid_plan_note(self) -> None:
        self.assertEqual(len(sources.audio_license_errors([_row(creator_or_tool="ElevenLabs SFX")])), 1)
        ok = _row(creator_or_tool="ElevenLabs SFX", edits="generated on paid plan 2026-10-08")
        self.assertEqual(sources.audio_license_errors([ok]), [])

    def test_non_audio_and_unapproved_rows_are_ignored(self) -> None:
        self.assertEqual(sources.audio_license_errors([_row(path="a.png", license="CC BY-NC")]), [])
        self.assertEqual(sources.audio_license_errors([_row(license="CC BY-NC", approval="quarantine")]), [])


if __name__ == "__main__":
    unittest.main()
