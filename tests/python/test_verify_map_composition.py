#!/usr/bin/env python3
"""Tests for tools/verify_map_composition.py."""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import verify_map_composition as verifier  # noqa: E402


class VerifyMapCompositionTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.thresholds = json.loads(verifier.THRESHOLDS.read_text(encoding="utf-8"))
        cls.registry = verifier.REGISTRY.read_text(encoding="utf-8")

    def test_threshold_cards_cover_registry(self) -> None:
        self.assertEqual(verifier.validate_threshold_contract(), [])

    def test_seeded_missing_threshold_card_fails(self) -> None:
        payload = json.loads(verifier.THRESHOLDS.read_text(encoding="utf-8"))
        payload["maps"].pop("kalev_smithy", None)
        path = ROOT / "build" / "test_map_composition_thresholds.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(payload), encoding="utf-8")
        original = verifier.THRESHOLDS
        verifier.THRESHOLDS = path
        try:
            errors = verifier.validate_threshold_contract()
        finally:
            verifier.THRESHOLDS = original
        self.assertTrue(any("kalev_smithy" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
