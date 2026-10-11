"""Regression tests for the R-261 completed-tower portfolio gate."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from tools.verify_p4_027f_tower_portfolio import verify


ROOT = Path(__file__).resolve().parents[2]


class TestTowerPortfolioGate(unittest.TestCase):
    def test_repository_ledger_is_consistent_but_fail_closed(self) -> None:
        self.assertEqual([], verify(ROOT))
        ledger = json.loads(
            (ROOT / "docs/data/p4_027f_tower_portfolio.json").read_text(encoding="utf-8")
        )
        self.assertEqual(ledger["decision"], "blocked")
        self.assertEqual(ledger["completed_registry_count"], 4)

    def test_registry_drift_is_rejected(self) -> None:
        with self._fixture() as root:
            registry = root / "scripts/map/reval_fortification_registry.gd"
            text = registry.read_text(encoding="utf-8")
            registry.write_text(
                text.replace(
                    '"historical_id": &"kuldjala"',
                    '"historical_id": &"later_tower"',
                ),
                encoding="utf-8",
            )
            errors = verify(root)
            self.assertTrue(any("completed registry" in error for error in errors), errors)

    def test_construction_candidate_cannot_be_promoted(self) -> None:
        with self._fixture() as root:
            ledger_path = root / "docs/data/p4_027f_tower_portfolio.json"
            ledger = json.loads(ledger_path.read_text(encoding="utf-8"))
            ledger["portfolio"][0]["historical_id"] = "viru_gate"
            ledger_path.write_text(json.dumps(ledger), encoding="utf-8")
            errors = verify(root)
            self.assertTrue(
                any(
                    "cannot be a completed-tower portfolio row" in error
                    for error in errors
                ),
                errors,
            )

    def test_approved_state_requires_every_row_to_pass(self) -> None:
        with self._fixture() as root:
            ledger_path = root / "docs/data/p4_027f_tower_portfolio.json"
            ledger = json.loads(ledger_path.read_text(encoding="utf-8"))
            ledger["decision"] = "approved"
            ledger["blockers"] = []
            ledger_path.write_text(json.dumps(ledger), encoding="utf-8")
            errors = verify(root)
            self.assertTrue(any("every completed row" in error for error in errors), errors)

    def _fixture(self):
        temporary = tempfile.TemporaryDirectory()
        root = Path(temporary.name)
        paths = [
            "docs/data/p4_027f_tower_portfolio.json",
            "docs/reports/p4_027f_completed_tower_portfolio.md",
            "scripts/map/reval_fortification_registry.gd",
            "docs/data/accessibility_checklist.json",
        ]
        for relative in paths:
            destination = root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes((ROOT / relative).read_bytes())

        class Fixture:
            def __enter__(self):
                return root

            def __exit__(self, exc_type, exc_value, traceback):
                temporary.cleanup()

        return Fixture()


if __name__ == "__main__":
    unittest.main()
