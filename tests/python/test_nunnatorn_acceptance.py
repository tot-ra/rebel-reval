"""Static contract checks for the independent Nunnatorn acceptance gate."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from verify_nunnatorn_acceptance import REQUIRED_STABLE_IDS, static_checks  # noqa: E402


class NunnatornAcceptanceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.results = static_checks(ROOT)
        cls.by_name = {result.name: result for result in cls.results}

    def test_core_historical_and_art_contracts_are_green(self) -> None:
        for name in (
            "historical/art review",
            "exact stable IDs",
            "open-backed interior form",
            "reciprocal exterior/interior transitions",
            "dedicated interior scene",
            "activation isolation",
        ):
            with self.subTest(name=name):
                self.assertEqual(self.by_name[name].status, "PASS", self.by_name[name].detail)

    def test_route_outcome_and_persistence_contracts_are_green(self) -> None:
        for name in (
            "boss outcomes and loot/evidence",
            "persistence, save/load, and retry",
        ):
            with self.subTest(name=name):
                self.assertEqual(self.by_name[name].status, "PASS", self.by_name[name].detail)

    def test_frozen_contract_has_expected_cardinality(self) -> None:
        self.assertEqual(len(REQUIRED_STABLE_IDS), 23)
        self.assertEqual(self.by_name["exact stable IDs"].status, "PASS")

    def test_presentation_is_either_green_or_explicitly_blocked(self) -> None:
        result = self.by_name["lighting/audio/readability and day/night captures"]
        self.assertIn(result.status, {"PASS", "BLOCKED"}, result.detail)

    def test_missing_packaged_artifact_is_blocked_not_approved(self) -> None:
        result = self.by_name["packaged artifact discovery"]
        if not (ROOT / "build/rr.dmg").is_file():
            self.assertEqual(result.status, "BLOCKED", result.detail)


if __name__ == "__main__":
    unittest.main()
