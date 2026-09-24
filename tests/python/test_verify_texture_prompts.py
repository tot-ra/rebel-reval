#!/usr/bin/env python3
"""Contract for generated-texture prompt sidecars."""

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

from verify_texture_prompts import validate  # noqa: E402


class VerifyTexturePromptsTests(unittest.TestCase):
    def test_live_pbr_families_have_prompt_sidecars(self) -> None:
        self.assertEqual(validate(ROOT), [])

    def test_missing_prompt_is_an_error(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            family = root / "assets" / "materials" / "pbr" / "moss"
            family.mkdir(parents=True)
            (family / "moss_albedo.png").write_bytes(b"x")
            errors = validate(root)
        self.assertTrue(any("missing prompt sidecar" in error for error in errors))

    def test_empty_prompt_is_an_error(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            family = root / "assets" / "materials" / "pbr" / "moss"
            family.mkdir(parents=True)
            (family / "moss_albedo.png").write_bytes(b"x")
            (family / "prompt.json").write_text(
                json.dumps({"id": "material.moss", "family": "moss", "prompt": "", "target": "x"}),
                encoding="utf-8",
            )
            errors = validate(root)
        self.assertTrue(any("missing non-empty 'prompt'" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
