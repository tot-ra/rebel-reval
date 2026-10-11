#!/usr/bin/env python3
"""Tests for the authored dialogue voice-manifest builder."""

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

from dialogue_voice_manifest import build_manifest  # noqa: E402


class DialogueVoiceManifestTest(unittest.TestCase):
    def test_builds_sorted_pending_cues_with_stable_text_hashes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            content = root / "content"
            localization = root / "localization"
            content.mkdir()
            localization.mkdir()
            (localization / "et.json").write_text(
                json.dumps(
                    {
                        "locale": "et",
                        "translations": {
                            "dialogue.test.start": "Tere, Kalev.",
                        },
                    }
                ),
                encoding="utf-8",
            )
            (content / "dialogue.json").write_text(
                json.dumps(
                    {
                        "type": "dialogue",
                        "id": "dialogue.test",
                        "nodes": [
                            {
                                "id": "z_node",
                                "speaker_id": "char.mart",
                                "text": "Fallback line.",
                            },
                            {
                                "id": "a_node",
                                "speaker_id": "char.kalev",
                                "text_key": "dialogue.test.start",
                                "text": "Hello, Kalev.",
                            },
                        ],
                    }
                ),
                encoding="utf-8",
            )

            manifest, errors = build_manifest(
                project_root=root,
                content_dirs=[content],
                locale="et-EE",
                catalog_dir=localization,
                voice_map_path=None,
            )

            self.assertEqual(errors, [])
            self.assertEqual(
                [entry["cue_id"] for entry in manifest["entries"]],
                ["dialogue.test.a_node", "dialogue.test.z_node"],
            )
            translated = manifest["entries"][0]
            self.assertEqual(translated["locale"], "et-ee")
            self.assertEqual(translated["text"], "Tere, Kalev.")
            self.assertEqual(translated["status"], "pending")
            self.assertIsNone(translated["voice_id"])
            self.assertTrue(translated["text_sha256"])
            self.assertFalse(manifest["source_policy"]["runtime_api_allowed"])

    def test_includes_barks_and_applies_voice_map(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            content = root / "content"
            localization = root / "localization"
            content.mkdir()
            localization.mkdir()
            (content / "bark.json").write_text(
                json.dumps(
                    {
                        "type": "bark_pool",
                        "id": "bark.test",
                        "entries": [
                            {
                                "id": "comment",
                                "speaker_id": "char.henning",
                                "text": "Keep your lamps low.",
                            }
                        ],
                    }
                ),
                encoding="utf-8",
            )
            voice_map = root / "voice-map.json"
            voice_map.write_text(json.dumps({"char.henning": "voice_henning"}), encoding="utf-8")

            manifest, errors = build_manifest(
                project_root=root,
                content_dirs=[content],
                catalog_dir=localization,
                voice_map_path=voice_map,
            )

            self.assertEqual(errors, [])
            self.assertEqual(len(manifest["entries"]), 1)
            entry = manifest["entries"][0]
            self.assertEqual(entry["cue_id"], "bark.test.comment")
            self.assertEqual(entry["voice_id"], "voice_henning")
            self.assertEqual(entry["audio_path"], "audio/voice/en/char.henning/bark_test_comment.mp3")

    def test_reports_missing_authored_text_and_speaker(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            content = root / "content"
            localization = root / "localization"
            content.mkdir()
            localization.mkdir()
            (content / "bad.json").write_text(
                json.dumps(
                    {
                        "type": "dialogue",
                        "id": "dialogue.bad",
                        "nodes": [
                            {"id": "no_speaker", "text": "Line."},
                            {"id": "no_text", "speaker_id": "char.mart"},
                        ],
                    }
                ),
                encoding="utf-8",
            )

            manifest, errors = build_manifest(
                project_root=root,
                content_dirs=[content],
                catalog_dir=localization,
            )

            self.assertEqual(manifest["entries"], [])
            self.assertEqual(len(errors), 2)
            self.assertTrue(any("missing speaker_id" in error for error in errors))
            self.assertTrue(any("no authored text" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
