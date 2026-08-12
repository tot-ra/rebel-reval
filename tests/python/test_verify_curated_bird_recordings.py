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

    def permission_entry(self, **overrides: object) -> dict[str, object]:
        entry: dict[str, object] = {
            "source": "permission",
            "recording_id": "lh-576",
            "scientific": "Haliaeetus albicilla",
            "recordist": "Veljo Runnel",
            "license": "permission-granted",
            "page": "https://example.test/recordings/lh-576",
            "download_url": "https://example.test/audio/lh-576.wav",
            "permission_evidence": "permission-grant.md",
            "rightsholder": "University of Tartu Natural History Museum",
            "commercial_scope": "commercial game, updates, DLC, trailers, and promotional materials",
            "attribution": "Veljo Runnel / University of Tartu Natural History Museum",
            "length": "26",
            "quality": "A",
            "country": "Estonia",
        }
        entry.update(overrides)
        return entry

    def test_permission_entry_accepts_explicit_commercial_grant(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            (root / "permission-grant.md").write_text(
                "Permission status: granted\nCommercial use: approved\n",
                encoding="utf-8",
            )
            errors = curated.validate_permission_entry(
                "white_tailed_eagle",
                self.permission_entry(),
                root=root,
            )
        self.assertEqual(errors, [])

    def test_permission_entry_rejects_blocked_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            (root / "blocked.md").write_text(
                "Permission status: blocked\nCommercial use: not approved\n",
                encoding="utf-8",
            )
            errors = curated.validate_permission_entry(
                "white_tailed_eagle",
                self.permission_entry(permission_evidence="blocked.md"),
                root=root,
            )
        self.assertTrue(any("commercial use: approved" in error for error in errors))

    def test_permission_entry_rejects_missing_evidence(self) -> None:
        errors = curated.validate_permission_entry(
            "white_tailed_eagle",
            self.permission_entry(permission_evidence="missing/permission.txt"),
        )
        self.assertTrue(any("permission evidence missing" in error for error in errors))

    def test_permission_entry_rejects_non_commercial_license(self) -> None:
        errors = curated.validate_permission_entry(
            "white_tailed_eagle",
            self.permission_entry(license="https://creativecommons.org/licenses/by-nc/4.0/"),
        )
        self.assertTrue(any("permission-granted" in error for error in errors))

    def test_permission_entry_rejects_wrong_species_or_source_page(self) -> None:
        errors = curated.validate_permission_entry(
            "white_tailed_eagle",
            self.permission_entry(
                scientific="Haliaeetus leucocephalus",
                page="https://example.test/recordings/other-id",
            ),
        )
        self.assertTrue(any("scientific name" in error for error in errors))
        self.assertTrue(any("must identify recording" in error for error in errors))

    def test_permission_entry_rejects_missing_local_audio(self) -> None:
        errors = curated.validate_permission_entry(
            "white_tailed_eagle",
            self.permission_entry(
                download_url="",
                local_file="sounds/birds/white_tailed_eagle/missing.wav",
            ),
        )
        self.assertTrue(any("local_file missing" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
