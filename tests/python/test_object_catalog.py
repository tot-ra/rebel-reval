#!/usr/bin/env python3
"""Tests for the physical-object catalog tooling (content/objects/)."""

from __future__ import annotations

import copy
import io
import json
import sys
import unittest
from contextlib import redirect_stdout
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS_DIR = ROOT / "tools"
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

import object_catalog as cli  # noqa: E402
import object_catalog_lib as lib  # noqa: E402
import render_object_previews as previews  # noqa: E402
import validate_object_catalog as validator  # noqa: E402


def entry(object_id: str) -> dict:
    for candidate in lib.load_catalog():
        if candidate["id"] == object_id:
            return copy.deepcopy(candidate)
    raise KeyError(object_id)


def problems_for(mutated: dict) -> list[str]:
    problems: list[str] = []
    validator._check_entry(mutated, lib.entry_path(mutated), problems, {})
    return problems


class CatalogContentTests(unittest.TestCase):
    def test_shipped_catalog_is_clean(self) -> None:
        self.assertEqual(validator.validate(), [])

    def test_catalog_covers_every_player_facing_category(self) -> None:
        categories = {e["category"] for e in lib.load_catalog()}
        for expected in ("container", "furniture", "tool", "weapon", "armor_clothing", "food", "drink", "light_source", "trade_good"):
            self.assertIn(expected, categories)

    def test_sync_is_idempotent(self) -> None:
        for candidate in lib.load_catalog():
            self.assertFalse(cli._refresh(candidate), candidate["id"])

    def test_every_glb_object_has_a_preview_and_every_planned_one_a_prompt(self) -> None:
        for candidate in lib.load_catalog():
            if candidate["model"]["status"] == "glb":
                self.assertTrue((lib.ROOT / candidate["visual"]["preview"]).is_file(), candidate["id"])
            self.assertIn(lib.style_suffix(), cli.prompt_for(candidate))


class RuleTests(unittest.TestCase):
    def test_fixed_objects_cannot_be_taken(self) -> None:
        bad = entry("obj.anvil_smithy")
        bad["actions"].append("take")
        self.assertTrue(any("fixed objects cannot take" in p for p in problems_for(bad)))

    def test_heavy_objects_cannot_be_taken_or_thrown(self) -> None:
        bad = entry("obj.barrel_oak")
        bad["actions"] += ["take", "throw"]
        messages = " ".join(problems_for(bad))
        self.assertIn("cannot take", messages)
        self.assertIn("cannot throw", messages)

    def test_mass_must_fit_the_handling_class(self) -> None:
        bad = entry("obj.apple")
        bad["physical"]["mass_kg"] = 5
        self.assertTrue(any("needs mass" in p for p in problems_for(bad)))

    def test_consume_requires_an_edible_block_and_vice_versa(self) -> None:
        bad = entry("obj.rye_bread_loaf")
        del bad["edible"]
        self.assertTrue(any("edible block and the consume action" in p for p in problems_for(bad)))
        bad = entry("obj.jug")
        bad["actions"].append("consume")
        self.assertTrue(any("edible block and the consume action" in p for p in problems_for(bad)))

    def test_bagged_objects_need_a_footprint_and_others_must_not_have_one(self) -> None:
        bad = entry("obj.jug")
        del bad["carry"]
        self.assertTrue(any("need a carry block" in p for p in problems_for(bad)))
        bad = entry("obj.barrel_oak")
        bad["carry"] = {"grid_width": 2, "grid_height": 2, "stackable": False}
        self.assertTrue(any("only for pocketable" in p for p in problems_for(bad)))

    def test_lifecycle_is_derived_from_model_and_icon(self) -> None:
        bad = entry("obj.apple")
        bad["lifecycle"] = "usable"
        self.assertTrue(any("lifecycle should be 'planned'" in p for p in problems_for(bad)))

    def test_missing_node_in_glb_is_reported(self) -> None:
        bad = entry("obj.jug")
        bad["model"]["node"] = "NoSuchNode"
        self.assertTrue(any("not found" in p for p in problems_for(bad)))

    def test_stale_measured_size_is_reported(self) -> None:
        bad = entry("obj.pitchfork")
        bad["model"]["measured_size_m"] = [9, 9, 9]
        self.assertTrue(any("stale" in p for p in problems_for(bad)))

    def test_item_ref_must_agree_with_item_carry_stats(self) -> None:
        sword = lib.entry_path(entry("obj.sword_cruciform"))
        original = sword.read_text(encoding="utf-8")
        try:
            data = json.loads(original)
            data["physical"]["mass_kg"] = 2.0
            lib.dump_json(sword, data)
            self.assertTrue(any("disagrees" in p for p in validator.validate()))
        finally:
            sword.write_text(original, encoding="utf-8")


class HouseholdNeedsTests(unittest.TestCase):
    TOP_20 = (
        "blanket_wool", "bolster_straw", "chamber_pot", "tunic_wool", "kirtle_wool",
        "leather_boots", "wall_peg_rail", "pot_crane", "ladle_wood", "tinderbox",
        "hatchet", "dagger_belt", "sword_cruciform", "coin_purse", "iron_key",
        "ale_tankard", "sack_grain", "root_veg_basket", "spindle_distaff", "crucifix_wall",
    )

    def setUp(self) -> None:
        self.data = lib.load_json(lib.CATALOG_DIR / "_household_needs.json")
        self.entries = {e["id"]: e for e in lib.load_catalog()}
        self.store = validator.SchemaStore(ROOT / "schemas")

    def check(self, data: dict) -> list[str]:
        return validator._check_household_needs(data, self.entries, self.store)

    def test_shipped_needs_table_and_references_are_valid(self) -> None:
        self.assertEqual(self.check(self.data), [])
        referenced = {r["id"] for tiers in self.data["needs"].values()
                      for requirements in tiers.values() for r in requirements}
        for slug in self.TOP_20:
            self.assertIn("obj." + slug, referenced)

    def test_top_20_records_have_stats_prompts_and_valid_schema(self) -> None:
        for slug in self.TOP_20:
            candidate = self.entries["obj." + slug]
            validator.validate_value(candidate, self.store.resolve("world_object.schema.json"), self.store)
            self.assertTrue(candidate["visual"]["image_prompt"])
            self.assertTrue(candidate["placement"]["spaces"])
            if candidate["model"]["status"] == "missing":
                self.assertEqual(candidate["lifecycle"], "planned")
                self.assertEqual(problems_for(candidate), [])

    def test_unknown_object_is_rejected(self) -> None:
        self.data["needs"]["sleep"]["poor"][0]["id"] = "obj.no_such_object"
        self.assertIn("unknown catalog object", " ".join(self.check(self.data)))

    def test_duplicate_object_is_rejected(self) -> None:
        requirements = self.data["needs"]["money"]["poor"]
        requirements.append(copy.deepcopy(requirements[0]))
        self.assertIn("duplicate object", " ".join(self.check(self.data)))

    def test_missing_need_tier_and_unknown_vocabulary_are_rejected(self) -> None:
        for mutation in ("need", "tier", "unknown_need", "unknown_tier"):
            with self.subTest(mutation=mutation):
                data = copy.deepcopy(self.data)
                if mutation == "need":
                    del data["needs"]["faith"]
                elif mutation == "tier":
                    del data["needs"]["faith"]["mid"]
                elif mutation == "unknown_need":
                    data["needs"]["luxury"] = data["needs"]["faith"]
                else:
                    data["needs"]["faith"]["noble"] = data["needs"]["faith"]["rich"]
                self.assertTrue(self.check(data))

    def test_empty_or_more_than_three_objects_are_rejected(self) -> None:
        for requirements in ([], [{"id": "obj.coin_purse", "count_per_resident": 1}] * 4):
            self.data["needs"]["money"]["poor"] = requirements
            self.assertTrue(self.check(self.data))

    def test_invalid_counts_and_unknown_fields_are_rejected(self) -> None:
        for count in (0, -1, True, "1", 11):
            with self.subTest(count=count):
                self.data["needs"]["money"]["poor"][0]["count_per_resident"] = count
                self.assertTrue(self.check(self.data))
        self.data["needs"]["money"]["poor"][0] = {"id": "obj.coin_purse", "count_per_resident": 1, "extra": 1}
        self.assertTrue(self.check(self.data))

    def test_shared_fixture_fraction_and_planned_objects_are_allowed(self) -> None:
        self.data["needs"]["money"]["poor"][0]["count_per_resident"] = 0.25
        self.assertEqual(self.check(self.data), [])

    def test_malformed_top_level_and_version_are_rejected(self) -> None:
        for data in ([], None, {}, {"version": 2, "needs": self.data["needs"]}):
            self.assertTrue(self.check(data))


class ToolTests(unittest.TestCase):
    def test_index_in_docs_is_current(self) -> None:
        buffer = io.StringIO()
        with redirect_stdout(buffer):
            self.assertEqual(cli.main(["index", "--check"]), 0, buffer.getvalue())

    def test_preview_renderer_draws_pixels(self) -> None:
        image = previews.render(previews.triangles_for(entry("obj.pitchfork")), size=64)
        self.assertEqual(image.size, (64, 64))
        self.assertIsNotNone(image.getchannel("A").getbbox())


if __name__ == "__main__":
    unittest.main()
