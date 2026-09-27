"""R-1015: slice magic grant budget stays at 6 elements and 8 castables."""

from __future__ import annotations

import json
import re
import unittest
from collections.abc import Iterable
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VALID_ROOT = ROOT / "content" / "examples" / "valid"
MAGIC_DOC = ROOT / "docs" / "SYSTEMS" / "MAGIC.md"
SESSION_STATE = ROOT / "scripts" / "session" / "session_state.gd"

SLICE_ELEMENT_CAP = 6
SLICE_CASTABLE_CAP = 8

# Budget chips a slice grant may introduce. Divine rite tags are not chips.
SLICE_STARTER_ELEMENTS = frozenset(
    {
        "element.fire",
        "element.metal",
        "element.earth",
        "element.water",
        "element.life",
        "element.mind",
    }
)
DIVINE_RITE_TAGS = frozenset(
    {
        "element.faith",
        "element.order",
        "element.sacrifice",
    }
)
# WHY: Fireball and the Double already sit in the slice band. Their extra tags
# stay recipe metadata so the six-chip budget does not grow.
SECONDARY_EXCEPTIONS = frozenset(
    {
        ("spell.pagan.fireball", "element.air"),
        ("spell.pagan.illusionary_double", "element.deception"),
    }
)
SLICE_CASTABLES = frozenset(
    {
        "spell.pagan.spark",
        "spell.pagan.fireball",
        "spell.pagan.earth_tremor",
        "spell.pagan.healing_mist",
        "spell.pagan.illusionary_double",
        "spell.pagan.iron_skin",
        "rite.blessing",
        "spell.pagan.forgefire_weapon",
    }
)
ACT1_CASTABLES = frozenset({"spell.pagan.air_gust"})

_DEMO_SEED_BLOCK = re.compile(
    r"func _seed_demo_bag_if_empty\(\) -> void:.*?"
    r"for grant_id: StringName in \[(.*?)\].*?"
    r"MagicResolver\.apply_grant_operation",
    re.S,
)
_GRANT_ID = re.compile(r'&"(magic\.grant\.[^"]+)"')
_VALID_EXAMPLE_PREFIX = "content/examples/valid/"
_BUDGET_TRIGGER_PATHS = frozenset(
    {
        "docs/SYSTEMS/MAGIC.md",
        "tests/python/test_magic_budget.py",
        "tools/run_pre_commit_checks.sh",
    }
)


class SliceBudgetError(AssertionError):
    """A grant or recipe would push the slice band past the 6/8 caps."""


def magic_budget_paths_trigger(paths: Iterable[str]) -> bool:
    """True when staged paths must re-run the slice budget unittest.

    WHY: a new magic.grant JSON can land without staging this module. The
    on-commit hook queues the check only for grant/spell/rite examples,
    MAGIC.md, this test, or the hook itself. Other content JSON stays out.
    """

    for raw in paths:
        path = raw.replace("\\", "/").lstrip("./")
        if path in _BUDGET_TRIGGER_PATHS:
            return True
        if not path.startswith(_VALID_EXAMPLE_PREFIX) or not path.endswith(".json"):
            continue
        name = path[len(_VALID_EXAMPLE_PREFIX) :]
        if "/" in name:
            continue
        if name.startswith(("magic.grant.", "spell.", "rite.")):
            return True
    return False


def collect_slice_grant_targets(
    records: dict[str, dict], grants: list[dict]
) -> set[str]:
    slice_targets: set[str] = set()
    for grant in grants:
        target_id = str(grant["target_id"])
        if target_id not in records:
            raise SliceBudgetError(f"{grant['id']} targets missing {target_id}")
        if target_id in ACT1_CASTABLES:
            continue
        if target_id not in SLICE_CASTABLES:
            raise SliceBudgetError(
                f"{grant['id']} targets {target_id}, which is outside the slice band"
            )
        slice_targets.add(target_id)
    if slice_targets != SLICE_CASTABLES:
        raise SliceBudgetError(
            "slice grants %s do not match the declared band %s"
            % (sorted(slice_targets), sorted(SLICE_CASTABLES))
        )
    if len(slice_targets) > SLICE_CASTABLE_CAP:
        raise SliceBudgetError(
            "slice castables %d exceed cap %d"
            % (len(slice_targets), SLICE_CASTABLE_CAP)
        )
    return slice_targets


def _load_valid_records() -> dict[str, dict]:
    records: dict[str, dict] = {}
    for path in sorted(VALID_ROOT.glob("*.json")):
        payload = json.loads(path.read_text(encoding="utf-8"))
        record_id = str(payload.get("id", ""))
        if record_id:
            records[record_id] = payload
    return records


def _grant_ops(records: dict[str, dict]) -> list[dict]:
    return [
        record
        for record in records.values()
        if record.get("type") == "magic_grant" and record.get("operation") == "grant"
    ]


def _recipe_elements(recipe: dict) -> list[str]:
    raw = recipe.get("sequence") or recipe.get("tags") or []
    return [str(item) for item in raw]


def _budget_elements(recipe_id: str, elements: list[str]) -> set[str]:
    counted: set[str] = set()
    for element in elements:
        if element in DIVINE_RITE_TAGS:
            continue
        if (recipe_id, element) in SECONDARY_EXCEPTIONS:
            continue
        counted.add(element)
    return counted


class MagicBudgetTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.records = _load_valid_records()
        cls.grants = _grant_ops(cls.records)
        cls.magic_md = MAGIC_DOC.read_text(encoding="utf-8")
        cls.session_gd = SESSION_STATE.read_text(encoding="utf-8")

    def test_slice_castable_count_is_at_cap(self) -> None:
        self.assertEqual(len(SLICE_CASTABLES), SLICE_CASTABLE_CAP)

    def test_grant_targets_resolve_and_stay_inside_declared_bands(self) -> None:
        slice_targets = collect_slice_grant_targets(self.records, self.grants)
        self.assertEqual(slice_targets, SLICE_CASTABLES)
        self.assertLessEqual(len(slice_targets), SLICE_CASTABLE_CAP)

    def test_ninth_slice_grant_is_rejected(self) -> None:
        records = dict(self.records)
        records["spell.pagan.ninth"] = {
            "id": "spell.pagan.ninth",
            "sequence": ["element.fire"],
        }
        grants = list(self.grants) + [
            {
                "id": "magic.grant.slice_ninth",
                "type": "magic_grant",
                "operation": "grant",
                "target_id": "spell.pagan.ninth",
            }
        ]
        with self.assertRaises(SliceBudgetError) as raised:
            collect_slice_grant_targets(records, grants)
        self.assertIn("spell.pagan.ninth", str(raised.exception))
        self.assertIn("outside the slice band", str(raised.exception))

    def test_budget_hook_triggers_on_grant_spell_rite_and_magic_md(self) -> None:
        for path in (
            "content/examples/valid/magic.grant.slice_ninth.json",
            "content/examples/valid/spell.pagan.ninth.json",
            "content/examples/valid/rite.blessing.json",
            "docs/SYSTEMS/MAGIC.md",
            "tests/python/test_magic_budget.py",
            "tools/run_pre_commit_checks.sh",
        ):
            self.assertTrue(magic_budget_paths_trigger([path]), path)

    def test_budget_hook_ignores_non_magic_json(self) -> None:
        for path in (
            "content/examples/valid/quest.bitter_brew.json",
            "content/demo/flag.aita_detained.json",
            "content/examples/valid/nested/spell.ignored.json",
            "README.md",
        ):
            self.assertFalse(magic_budget_paths_trigger([path]), path)

    def test_pre_commit_runner_queues_budget_via_trigger_helper(self) -> None:
        runner = (ROOT / "tools" / "run_pre_commit_checks.sh").read_text(
            encoding="utf-8"
        )
        self.assertIn("magic_budget_paths_trigger", runner)
        self.assertIn("tests.python.test_magic_budget", runner)
        self.assertIn('print("1" if magic_budget_paths_trigger(paths) else "0")', runner)

    def test_slice_granted_elements_stay_inside_six_chip_budget(self) -> None:
        granted: set[str] = set()
        for grant in self.grants:
            target_id = str(grant["target_id"])
            if target_id in ACT1_CASTABLES:
                continue
            recipe = self.records[target_id]
            budget = _budget_elements(target_id, _recipe_elements(recipe))
            extra = budget - SLICE_STARTER_ELEMENTS
            self.assertFalse(
                extra,
                f"{grant['id']} introduces non-slice chips {sorted(extra)}",
            )
            granted.update(budget)
        self.assertLessEqual(len(granted), SLICE_ELEMENT_CAP)
        self.assertEqual(granted, SLICE_STARTER_ELEMENTS)

    def test_secondary_exceptions_do_not_count_as_chips(self) -> None:
        fireball = _recipe_elements(self.records["spell.pagan.fireball"])
        double = _recipe_elements(self.records["spell.pagan.illusionary_double"])
        self.assertIn("element.air", fireball)
        self.assertIn("element.deception", double)
        self.assertNotIn(
            "element.air",
            _budget_elements("spell.pagan.fireball", fireball),
        )
        self.assertNotIn(
            "element.deception",
            _budget_elements("spell.pagan.illusionary_double", double),
        )

    def test_air_gust_stays_in_act1_band(self) -> None:
        grant = self.records["magic.grant.starter_air_gust"]
        self.assertEqual(grant["target_id"], "spell.pagan.air_gust")
        self.assertEqual(
            _recipe_elements(self.records["spell.pagan.air_gust"]),
            ["element.air"],
        )
        self.assertIn("spell.pagan.air_gust", ACT1_CASTABLES)
        self.assertNotIn("spell.pagan.air_gust", SLICE_CASTABLES)

    def test_demo_seed_grants_are_slice_band_subset(self) -> None:
        match = _DEMO_SEED_BLOCK.search(self.session_gd)
        self.assertIsNotNone(match, "demo seed grant loop missing in session_state.gd")
        grant_ids = _GRANT_ID.findall(match.group(1))
        self.assertGreaterEqual(len(grant_ids), 1)
        seeded_elements: set[str] = set()
        for grant_id in grant_ids:
            self.assertIn(grant_id, self.records)
            grant = self.records[grant_id]
            self.assertEqual(grant.get("operation"), "grant")
            target_id = str(grant["target_id"])
            self.assertIn(target_id, SLICE_CASTABLES)
            seeded_elements.update(
                _budget_elements(target_id, _recipe_elements(self.records[target_id]))
            )
        self.assertLessEqual(len(seeded_elements), SLICE_ELEMENT_CAP)
        self.assertTrue(seeded_elements <= SLICE_STARTER_ELEMENTS)

    def test_magic_md_records_the_r1015_decision_and_count_table(self) -> None:
        self.assertIn("Secondary-tag exceptions (R-1015)", self.magic_md)
        self.assertIn("`spell.pagan.fireball` may list `element.air`", self.magic_md)
        self.assertIn(
            "`spell.pagan.illusionary_double` may list `element.deception`",
            self.magic_md,
        )
        self.assertIn("Slice-band authored castables (8, at cap)", self.magic_md)
        for recipe_id in sorted(SLICE_CASTABLES):
            self.assertIn(f"`{recipe_id}`", self.magic_md)
        self.assertIn("`tests/python/test_magic_budget.py`", self.magic_md)
        self.assertIn(
            "stays in the Act 1 optional band because it is air-primary",
            self.magic_md,
        )


if __name__ == "__main__":
    unittest.main()
