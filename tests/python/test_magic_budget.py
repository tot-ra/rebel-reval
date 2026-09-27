"""R-1015: slice magic grant budget stays at 6 elements and 8 castables."""

from __future__ import annotations

import json
import re
import unittest
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
        slice_targets: set[str] = set()
        for grant in self.grants:
            target_id = str(grant["target_id"])
            self.assertIn(target_id, self.records, grant["id"])
            if target_id in ACT1_CASTABLES:
                continue
            self.assertIn(
                target_id,
                SLICE_CASTABLES,
                f"{grant['id']} targets {target_id}, which is outside the slice band",
            )
            slice_targets.add(target_id)
        self.assertEqual(slice_targets, SLICE_CASTABLES)
        self.assertLessEqual(len(slice_targets), SLICE_CASTABLE_CAP)

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
