#!/usr/bin/env python3
"""Tests for offline dialogue voice bundling and review."""

from __future__ import annotations

import copy
import hashlib
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from dialogue_voice_bundle import review_bundle, stage_manifest  # noqa: E402


def valid_mp3_frame() -> bytes:
    # MPEG-1 Layer III, 128 kbps, 44.1 kHz, stereo frame header plus payload.
    return bytes((0xFF, 0xFB, 0x90, 0x64)) + bytes(413)


def fixture_manifest() -> dict:
    return {
        "schema_version": 1,
        "entries": [
            {
                "cue_id": "bark.test.comment",
                "status": "pending",
                "audio_path": "audio/voice/en/char.henning/bark_test_comment.mp3",
            }
        ],
    }


class DialogueVoiceBundleTest(unittest.TestCase):
    def test_stage_accepts_manifest_filename_and_records_hash(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            exports = root / "exports"
            exports.mkdir()
            clip = exports / "bark_test_comment.mp3"
            clip.write_bytes(valid_mp3_frame())

            updated, errors, staged = stage_manifest(fixture_manifest(), exports, root)

            self.assertEqual(errors, [])
            self.assertEqual(staged, ["bark.test.comment"])
            entry = updated["entries"][0]
            self.assertEqual(entry["status"], "generated")
            self.assertEqual(entry["audio_sha256"], hashlib.sha256(clip.read_bytes()).hexdigest())
            self.assertEqual(review_bundle(updated, root, require_all=True), [])

    def test_stage_rejects_invalid_export_without_copying(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            exports = root / "exports"
            exports.mkdir()
            (exports / "bark.test.comment.mp3").write_bytes(b"not audio")

            updated, errors, staged = stage_manifest(fixture_manifest(), exports, root)

            self.assertEqual(staged, [])
            self.assertTrue(any("not a valid MP3" in error for error in errors))
            self.assertEqual(updated, fixture_manifest())
            self.assertFalse((root / "audio").exists())

    def test_review_rejects_pending_missing_and_orphan_clips(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            orphan = root / "audio" / "voice" / "en" / "char.mart" / "orphan.mp3"
            orphan.parent.mkdir(parents=True)
            orphan.write_bytes(valid_mp3_frame())

            errors = review_bundle(copy.deepcopy(fixture_manifest()), root, require_all=True)

            self.assertTrue(any("pending clip is missing" in error for error in errors))
            self.assertTrue(any("orphan bundled clip" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
