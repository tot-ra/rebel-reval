#!/usr/bin/env python3
"""Tests for P0-140 character fidelity tier classification and budgets."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from character_fidelity_tiers import (  # noqa: E402
    TIER_BUDGETS,
    TIER_HERO,
    TIER_NAMED_NPC,
    classify_character_glb,
    inspect_glb,
    validate_character_tier_budgets,
)


class CharacterFidelityTiersTest(unittest.TestCase):
    def test_runtime_glbs_classify_into_expected_tiers(self) -> None:
        expectations = {
            "assets/characters/shared/heroic_humanoid.glb": TIER_HERO,
            "assets/characters/shared/mart.glb": TIER_HERO,
            "assets/characters/shared/henning.glb": TIER_HERO,
            "assets/characters/shared/townswoman.glb": TIER_HERO,
            "assets/characters/shared/innkeeper.glb": TIER_NAMED_NPC,
            "assets/characters/shared/watchman.glb": TIER_NAMED_NPC,
            "assets/characters/shared/sergeant.glb": TIER_NAMED_NPC,
            "assets/characters/shared/danish_warrior.glb": TIER_NAMED_NPC,
            "assets/characters/shared/hero_cape.glb": TIER_HERO,
            "assets/characters/shared/hero_hat.glb": TIER_HERO,
            "assets/characters/shared/kaykit_barbarian.glb": None,
        }
        for rel_path, expected in expectations.items():
            with self.subTest(rel_path=rel_path):
                self.assertEqual(classify_character_glb(rel_path, root=ROOT), expected)

    def test_repository_character_glbs_stay_within_tier_budgets(self) -> None:
        self.assertEqual(validate_character_tier_budgets(root=ROOT), [])

    def test_heroic_humanoid_triangle_count_is_documented_range(self) -> None:
        glb = ROOT / "assets/characters/shared/heroic_humanoid.glb"
        stats = inspect_glb(glb)
        self.assertGreaterEqual(stats["triangles"], 50_000)
        self.assertLessEqual(stats["triangles"], TIER_BUDGETS[TIER_HERO].triangle_cap)


if __name__ == "__main__":
    unittest.main()
