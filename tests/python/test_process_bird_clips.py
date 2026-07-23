#!/usr/bin/env python3
"""Tests for P0-123 bird clip processing and verification."""

from __future__ import annotations

import csv
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
AUDIO_TOOLS = ROOT / "tools" / "audio"
TOOLS = ROOT / "tools"
for path in (str(AUDIO_TOOLS), str(TOOLS)):
    if path not in sys.path:
        sys.path.insert(0, path)

import process_bird_clips as process  # noqa: E402
import verify_bird_audio_clips as verify  # noqa: E402


class ProcessBirdClipsTest(unittest.TestCase):
    def test_cue_kind_for_songbirds(self) -> None:
        self.assertEqual(process.cue_kind_for("skylark"), "song")
        self.assertEqual(process.cue_kind_for("herring_gull"), "call")

    def test_trim_window_keeps_short_clips(self) -> None:
        start, duration = process.trim_window(43.0, lo=15, hi=90)
        self.assertEqual(start, 0.0)
        self.assertEqual(duration, 43.0)

    def test_trim_window_centers_long_clips(self) -> None:
        start, duration = process.trim_window(120.0, lo=15, hi=90)
        self.assertEqual(duration, 90.0)
        self.assertAlmostEqual(start, 15.0)

    def test_processed_path_matches_catalog_kind(self) -> None:
        birds_dir = Path("/tmp/birds")
        self.assertEqual(
            process.processed_path(birds_dir, "common_chaffinch"),
            birds_dir / "common_chaffinch" / "song.mp3",
        )
        self.assertEqual(
            process.processed_path(birds_dir, "mallard"),
            birds_dir / "mallard" / "call.mp3",
        )


class VerifyBirdAudioClipsTest(unittest.TestCase):
    def test_extract_catalog_cues_matches_species_count(self) -> None:
        cues = verify.extract_catalog_cues()
        self.assertEqual(len(cues), len(process.SPECIES))
        self.assertIn("bird.herring_gull.call", cues)
        self.assertIn("bird.skylark.song", cues)

    def test_verify_reports_missing_processed_clip(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            birds_dir = Path(temp_dir)
            manifest = birds_dir / "processed_manifest.csv"
            with open(manifest, "w", newline="", encoding="utf-8") as fh:
                writer = csv.DictWriter(
                    fh,
                    fieldnames=["cue", "bird_id", "kind", "source_file", "processed_file", "license"],
                )
                writer.writeheader()
            errors = verify.verify(birds_dir)
            self.assertTrue(any("missing processed clip" in err for err in errors))

    def test_verify_passes_for_fixture(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            birds_dir = Path(temp_dir)
            rows = []
            for bird_id in process.SPECIES:
                species_dir = birds_dir / bird_id
                species_dir.mkdir()
                source = species_dir / f"{bird_id}_XC1.mp3"
                processed = process.processed_path(birds_dir, bird_id)
                source.write_bytes(b"raw")
                processed.write_bytes(b"processed")
                Path(f"{processed}.import").write_text(
                    '[remap]\n\nimporter="mp3"\n',
                    encoding="utf-8",
                )
                rows.append(
                    {
                        "cue": process.cue_id_for(bird_id),
                        "bird_id": bird_id,
                        "kind": process.cue_kind_for(bird_id),
                        "source_file": str(source),
                        "processed_file": str(processed),
                        "license": "https://creativecommons.org/licenses/by/4.0/",
                    }
                )
            with open(birds_dir / "processed_manifest.csv", "w", newline="", encoding="utf-8") as fh:
                writer = csv.DictWriter(fh, fieldnames=rows[0].keys())
                writer.writeheader()
                writer.writerows(rows)
            self.assertEqual(verify.verify(birds_dir), [])


if __name__ == "__main__":
    unittest.main()
