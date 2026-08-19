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

    def test_lower_town_composition_gate_is_explicitly_enforced(self) -> None:
        errors = verifier.validate_lower_town_enforcement()
        self.assertEqual(errors, [])

    def test_lower_town_gate_rejects_advisory_threshold_card(self) -> None:
        payload = json.loads(verifier.THRESHOLDS.read_text(encoding="utf-8"))
        payload["maps"]["lower_town_slice"]["enforce"] = False
        path = ROOT / "build" / "test_map_composition_advisory.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(payload), encoding="utf-8")
        original = verifier.THRESHOLDS
        verifier.THRESHOLDS = path
        try:
            errors = verifier.validate_lower_town_enforcement()
        finally:
            verifier.THRESHOLDS = original
        self.assertTrue(any("composition gate must be explicitly enforced" in error for error in errors))

    def test_lower_town_gate_requires_explicit_open_region_exclusions(self) -> None:
        payload = json.loads(verifier.LOWER_TOWN_OWNERSHIP.read_text(encoding="utf-8"))
        payload["open_regions"][0].pop("exclude_from_unowned_empty_region")
        path = ROOT / "build" / "test_lower_town_ownership.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(payload), encoding="utf-8")
        original = verifier.LOWER_TOWN_OWNERSHIP
        verifier.LOWER_TOWN_OWNERSHIP = path
        try:
            errors = verifier.validate_lower_town_enforcement()
        finally:
            verifier.LOWER_TOWN_OWNERSHIP = original
        self.assertTrue(any("must explicitly opt out" in error for error in errors))

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
