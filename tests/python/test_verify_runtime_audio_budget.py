#!/usr/bin/env python3
"""Tests for tools/verify_runtime_audio_budget.py."""

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

import verify_runtime_audio_budget as verifier  # noqa: E402


def _write_manifest(root: Path, **overrides: object) -> Path:
    payload = {
        "schema_version": 1,
        "owner": "P0-182",
        "policy": {
            "roots": ["music", "sounds"],
            "suffixes": [".mp3", ".wav"],
            "lossy_suffixes": [".mp3"],
            "pcm_suffixes": [".wav"],
        },
        "budget": {
            "music": {"max_bitrate_bps": 256000, "max_file_bytes": 12582912},
            "sounds_lossy": {"max_bitrate_bps": 192000, "max_file_bytes": 2097152},
            "sounds_pcm": {"max_bitrate_bps": 1536000, "max_file_bytes": 4194304},
        },
        "exceptions": [],
    }
    payload.update(overrides)
    path = root / "docs" / "data" / "runtime_audio_budget.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload), encoding="utf-8")
    return path


class VerifyRuntimeAudioBudgetTest(unittest.TestCase):
    def test_repository_budget_passes(self) -> None:
        self.assertEqual(verifier.validate(), [])

    def test_oversized_lossy_file_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            sounds = root / "sounds"
            sounds.mkdir()
            huge = sounds / "too_big.mp3"
            huge.write_bytes(b"ID3" + b"\x00" * 3_000_000)
            manifest = _write_manifest(root)
            errors = verifier.validate(root=root, manifest_path=manifest)
        self.assertTrue(any("exceeds per-file cap" in error for error in errors))

    def test_lfs_pointer_uses_declared_size(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            sounds = root / "sounds" / "birds"
            sounds.mkdir(parents=True)
            pointer = sounds / "source.mp3"
            pointer.write_text(
                "version https://git-lfs.github.com/spec/v1\n"
                "oid sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n"
                "size 5000000\n",
                encoding="utf-8",
            )
            manifest = _write_manifest(root)
            errors = verifier.validate(root=root, manifest_path=manifest)
        self.assertTrue(any("5000000 bytes exceeds per-file cap" in error for error in errors))

    def test_exception_path_is_skipped(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            sounds = root / "sounds"
            sounds.mkdir()
            (sounds / "kept.mp3").write_bytes(b"\x00" * 3_000_000)
            manifest = _write_manifest(
                root,
                exceptions=[{"path": "sounds/kept.mp3", "task": "P0-182"}],
            )
            errors = verifier.validate(root=root, manifest_path=manifest)
        self.assertEqual(errors, [])

    def test_wave_payload_with_mp3_suffix_uses_pcm_bitrate(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            sounds = root / "sounds"
            sounds.mkdir()
            # 16-bit stereo 8 kHz PCM: 256 kbps, over the 192 kbps sounds_lossy ceiling.
            wav = (
                b"RIFF"
                + (36 + 800).to_bytes(4, "little")
                + b"WAVEfmt "
                + (16).to_bytes(4, "little")
                + (1).to_bytes(2, "little")
                + (2).to_bytes(2, "little")
                + (8000).to_bytes(4, "little")
                + (32000).to_bytes(4, "little")
                + (4).to_bytes(2, "little")
                + (16).to_bytes(2, "little")
                + b"data"
                + (800).to_bytes(4, "little")
                + b"\x00" * 800
            )
            (sounds / "pcm_named.mp3").write_bytes(wav)
            manifest = _write_manifest(root)
            errors = verifier.validate(root=root, manifest_path=manifest)
        self.assertTrue(any("256000 bps exceeds encode ceiling" in error for error in errors))

    def test_missing_manifest_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            errors = verifier.validate(
                root=Path(temp_dir),
                manifest_path=Path("docs/data/runtime_audio_budget.json"),
            )
        self.assertTrue(any("missing runtime audio budget" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
