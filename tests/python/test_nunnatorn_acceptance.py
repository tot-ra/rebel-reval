"""Static contract checks for the independent Nunnatorn acceptance gate."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from verify_nunnatorn_acceptance import (  # noqa: E402
    REQUIRED_STABLE_IDS,
    Result,
    _classify_focused_nunnatorn_result,
    _classify_presentation_result,
    static_checks,
)


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

    def test_live_only_presentation_smoke_is_blocked(self) -> None:
        result = Result("focused Nunnatorn presentation suite", "PASS", "exit=0")
        blocked = _classify_presentation_result(result, ROOT)
        if (ROOT / "tests/godot/test_nunnatorn_presentation.gd").is_file():
            self.assertEqual(blocked.status, "BLOCKED", blocked.detail)

    def test_known_external_transition_blocker_is_not_a_nunnatorn_failure(self) -> None:
        result = Result(
            "focused Godot Nunnatorn suites",
            "FAIL",
            "exit=1",
            output=(
                "MAP_TRANSITION_DESTINATION_UNKNOWN kuldjala_interior "
                "test_nunnatorn_transitions.gd::test_nunnatorn_transition_ids_are_reciprocal "
                "Godot headless tests: 5 file(s), 16 test(s), 4 failure(s), 38 error(s)."
            ),
        )
        classified = _classify_focused_nunnatorn_result(result)
        self.assertEqual(classified.status, "BLOCKED")
        self.assertIn("R-250", classified.detail)

    def test_unrelated_focused_failure_remains_a_failure(self) -> None:
        result = Result("focused Godot Nunnatorn suites", "FAIL", "exit=1", output="test assertion failed")
        self.assertEqual(_classify_focused_nunnatorn_result(result).status, "FAIL")


if __name__ == "__main__":
    unittest.main()
