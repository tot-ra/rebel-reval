#!/usr/bin/env python3
"""Tests for curated gap-species bird recording policy."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
AUDIO_TOOLS = ROOT / "tools" / "audio"
if str(AUDIO_TOOLS) not in sys.path:
    sys.path.insert(0, str(AUDIO_TOOLS))

import verify_curated_bird_recordings as curated  # noqa: E402


class VerifyCuratedBirdRecordingsTest(unittest.TestCase):
    def test_verify_passes_on_repository_manifest(self) -> None:
        errors = curated.verify(curated.DEFAULT_CURATED)
        self.assertEqual(errors, [])

    def test_verify_rejects_procedural_maintainer_gap_fill(self) -> None:
        payload = json.loads(curated.DEFAULT_CURATED.read_text(encoding="utf-8"))
        payload["recordings"]["great_cormorant"] = {
            "scientific": "Phalacrocorax carbo",
            "source": "maintainer",
            "recording_id": "122b01",
            "recordist": "project maintainer",
            "license": "https://creativecommons.org/publicdomain/zero/1.0/",
            "page": "tools/audio/generate_gap_bird_clips.py",
            "local_file": "sounds/birds/great_cormorant/great_cormorant_MR122b01.mp3",
            "length": "24",
            "quality": "A",
            "country": "Estonia",
        }
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "curated.json"
            path.write_text(json.dumps(payload), encoding="utf-8")
            errors = curated.verify(path)
        self.assertTrue(any("procedural maintainer" in err for err in errors))

    def test_verify_rejects_wikimedia_gap_fill(self) -> None:
        payload = json.loads(curated.DEFAULT_CURATED.read_text(encoding="utf-8"))
        payload["recordings"]["great_cormorant"] = {
            "scientific": "Phalacrocorax carbo",
            "source": "wikimedia",
            "xc_id": "1",
            "license": "https://creativecommons.org/licenses/by-sa/4.0/",
            "page": "https://commons.wikimedia.org/",
            "length": "20",
            "quality": "A",
            "country": "India",
        }
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "curated.json"
            path.write_text(json.dumps(payload), encoding="utf-8")
            errors = curated.verify(path)
        self.assertTrue(any("wikimedia" in err for err in errors))

    def test_verify_rejects_stand_in_species(self) -> None:
        payload = json.loads(curated.DEFAULT_CURATED.read_text(encoding="utf-8"))
        payload["recordings"]["white_tailed_eagle"]["stand_in_species"] = "Haliaeetus leucogaster"
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "curated.json"
            path.write_text(json.dumps(payload), encoding="utf-8")
            errors = curated.verify(path)
        self.assertTrue(any("stand_in_species" in err for err in errors))


if __name__ == "__main__":
    unittest.main()
