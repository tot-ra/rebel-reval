"""P4-021 faction-line package contract checks."""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from quest_packages import load_package, validate_package  # noqa: E402

LINES = {
    "faction_line.livonian_order": {
        "faction_id": "faction.livonian_order",
        "packages": (
            "livonian_order_grain_tally",
            "livonian_order_night_checkpoint",
            "livonian_order_relic_vigil",
        ),
    },
    "faction_line.black_cloaks": {
        "faction_id": "faction.black_cloaks",
        "packages": (
            "black_cloaks_iron_mark",
            "black_cloaks_night_route",
            "black_cloaks_safehouse_debt",
        ),
    },
}


class FactionQuestLineTests(unittest.TestCase):
    def test_each_line_has_three_valid_packages(self) -> None:
        for line_id, contract in LINES.items():
            with self.subTest(line=line_id):
                self.assertEqual(len(contract["packages"]), 3)
                for package_name in contract["packages"]:
                    package = load_package(ROOT / "content/packages" / package_name)
                    self.assertEqual(validate_package(package), [], package_name)
                    quest_path = package.root / package.manifest["quest"]
                    quest = json.loads(quest_path.read_text(encoding="utf-8"))
                    self.assertEqual(quest["approval"]["reviewer"], "P4-021")
                    self.assertGreaterEqual(len(package.branch_map["branches"]), 2)
                    self.assertTrue(_ledger_events(quest), package_name)
                    for event in _ledger_events(quest):
                        self.assertEqual(event["value"], contract["faction_id"])

    def test_both_lines_have_night_combat_and_non_combat_routes(self) -> None:
        for line_id, contract in LINES.items():
            with self.subTest(line=line_id):
                night_packages = []
                for package_name in contract["packages"]:
                    package = load_package(ROOT / "content/packages" / package_name)
                    routes = {
                        branch.get("route")
                        for branch in package.branch_map["branches"]
                        if branch.get("route")
                    }
                    if routes:
                        night_packages.append((package_name, routes))
                self.assertEqual(len(night_packages), 1)
                self.assertEqual(night_packages[0][1], {"combat", "non_combat"})

    def test_manifest_marks_lines_authored_with_exact_ids(self) -> None:
        manifest = json.loads(
            (ROOT / "docs/data/act1_content_budget_manifest.json").read_text(encoding="utf-8")
        )
        authored = {line["line_id"]: line for line in manifest["planned_faction_lines"]}
        for line_id, contract in LINES.items():
            with self.subTest(line=line_id):
                self.assertEqual(authored[line_id]["status"], "authored")
                quest_ids = {
                    json.loads(
                        (ROOT / "content/packages" / package_name / "content/quest.json").read_text(
                            encoding="utf-8"
                        )
                    )["id"]
                    for package_name in contract["packages"]
                }
                self.assertEqual(set(authored[line_id]["quest_ids"]), quest_ids)


def _ledger_events(quest: dict) -> list[dict]:
    events = []
    for transition in quest.get("transitions", []):
        events.extend(
            effect
            for effect in transition.get("effects", [])
            if effect.get("op") == "record_faction_event"
        )
    return events


if __name__ == "__main__":
    unittest.main()
