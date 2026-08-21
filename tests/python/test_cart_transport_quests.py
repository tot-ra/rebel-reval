#!/usr/bin/env python3
"""Regression coverage for the R-068/R-069 cart-transport quest beats."""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from quest_packages import load_package, validate_package  # noqa: E402
from validate_content import validate_corpus  # noqa: E402

QUEST_PATHS = [
    ROOT / "content/examples/valid/quest.harbour_barrel_run.json",
    ROOT / "content/examples/valid/quest.viru_abandoned_cart.json",
    ROOT / "content/examples/valid/quest.osmond_sack_smuggle.json",
]
DIALOGUE_PATHS = [
    ROOT / "content/examples/support/dialogue.carter.harbour_barrel_run.json",
    ROOT / "content/examples/support/dialogue.carter.viru_abandoned_cart.json",
    ROOT / "content/examples/support/dialogue.carter.osmond_sack_smuggle.json",
]
PACKAGE_NAMES = ["harbour_barrel_run", "viru_abandoned_cart", "osmond_sack_smuggle"]


class CartTransportQuestTests(unittest.TestCase):
    def test_new_examples_validate_as_one_referenced_corpus(self) -> None:
        paths = QUEST_PATHS + DIALOGUE_PATHS + [
            ROOT / "content/examples/valid/bark.cart.transport.json",
            ROOT / "content/examples/valid/character.kalev.json",
            ROOT / "content/examples/support/character.aita.json",
            ROOT / "content/examples/support/character.henning.json",
            ROOT / "content/examples/support/character.mart.json",
            ROOT / "content/examples/support/character.merchant_stall.json",
            ROOT / "content/examples/support/location.lower_town_slice.json",
            ROOT / "content/examples/support/location.smithy_courtyard.json",
            ROOT / "content/examples/valid/location.kalev_smithy.json",
        ]
        self.assertEqual(validate_corpus(paths), [])

    def test_packages_validate_and_keep_three_named_beats(self) -> None:
        for package_name in PACKAGE_NAMES:
            package = load_package(ROOT / "content/packages" / package_name)
            self.assertEqual(validate_package(package), [], package_name)
            self.assertEqual(package.manifest["source_notes"][0]["confidence"], "plausible composite")
            self.assertGreaterEqual(len(package.branch_map["branches"]), 2)

    def test_quest_contracts_keep_prices_and_non_attested_toll_boundary(self) -> None:
        quests = {payload["id"]: payload for payload in map(_load, QUEST_PATHS)}
        self.assertEqual(
            set(quests),
            {
                "quest.harbour_barrel_run",
                "quest.viru_abandoned_cart",
                "quest.osmond_sack_smuggle",
            },
        )
        for quest in quests.values():
            self.assertEqual(quest["confidence"], "plausible composite")
            self.assertGreaterEqual(len(quest["source_notes"]), 1)
            text = _all_strings(quest).lower()
            self.assertNotIn("radsteuer", text)
            self.assertNotIn("wheel tax", text)

        harbour_text = _all_strings(quests["quest.harbour_barrel_run"]).lower()
        self.assertIn("6-10 schilling", harbour_text)
        self.assertIn("curfew", harbour_text)

        viru_text = _all_strings(quests["quest.viru_abandoned_cart"]).lower()
        self.assertIn("dumping", viru_text)
        self.assertIn("without a vehicle tariff claim", viru_text)

        osmond_text = _all_strings(quests["quest.osmond_sack_smuggle"]).lower()
        self.assertIn("private bribe", osmond_text)
        self.assertIn("not a municipal axle charge", osmond_text)

    def test_carter_dialogues_are_authored_and_offline(self) -> None:
        dialogues = {payload["id"]: payload for payload in map(_load, DIALOGUE_PATHS)}
        self.assertEqual(len(dialogues), 3)
        for dialogue in dialogues.values():
            self.assertTrue(dialogue["deterministic_offline"]["authored"])
            self.assertFalse(dialogue["deterministic_offline"]["runtime_llm_allowed"])
            self.assertFalse(dialogue["deterministic_offline"]["free_text_input_allowed"])
            self.assertEqual(dialogue["confidence"], "plausible composite")

        self.assertIn("six schillings", _all_strings(dialogues["dialogue.carter.harbour_barrel_run"]).lower())
        self.assertIn("dumping offence", _all_strings(dialogues["dialogue.carter.viru_abandoned_cart"]).lower())
        self.assertIn("private bribe", _all_strings(dialogues["dialogue.carter.osmond_sack_smuggle"]).lower())


def _load(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def _all_strings(value: Any) -> str:
    if isinstance(value, dict):
        return " ".join(_all_strings(item) for item in value.values())
    if isinstance(value, list):
        return " ".join(_all_strings(item) for item in value)
    return str(value) if isinstance(value, str) else ""


if __name__ == "__main__":
    unittest.main()
