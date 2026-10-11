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
from unittest.mock import patch

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


class HouseholdCoverageTests(unittest.TestCase):
    def setUp(self) -> None:
        self.needs = lib.load_json(lib.CATALOG_DIR / "_household_needs.json")
        self.entries = {e["id"]: e for e in lib.load_catalog()}
        self.owners = lib.load_json(validator.PLANNED_OWNERS_PATH)

    def test_every_shipped_planned_object_has_a_modeling_task(self) -> None:
        self.assertEqual(validator._check_planned_owners(self.owners, self.entries), [])
        planned = {oid for oid, e in self.entries.items() if e["lifecycle"] == "planned"}
        self.assertTrue(planned <= set(self.owners["owners"]))

    def test_unowned_planned_object_is_rejected(self) -> None:
        del self.owners["owners"]["obj.blanket_wool"]
        self.assertIn("obj.blanket_wool: no modeling task assigned", " ".join(
            validator._check_planned_owners(self.owners, self.entries)))

    def test_usable_object_does_not_need_a_task_and_completed_assignments_remain_valid(self) -> None:
        self.entries["obj.blanket_wool"]["lifecycle"] = "usable"
        self.assertEqual(validator._check_planned_owners(self.owners, self.entries), [])
        del self.owners["owners"]["obj.blanket_wool"]
        self.assertEqual(validator._check_planned_owners(self.owners, self.entries), [])

    def test_unknown_owner_object_and_invalid_task_refs_are_rejected(self) -> None:
        self.owners["owners"]["obj.not_real"] = "R-1379"
        self.assertIn("unknown catalog object", " ".join(
            validator._check_planned_owners(self.owners, self.entries)))
        for task in ("", "R-0", "R-01", "HOMEOBJ-2", "R-12 extra", None, 1368):
            with self.subTest(task=task):
                self.owners["owners"]["obj.blanket_wool"] = task
                self.assertIn("expected task reference", " ".join(
                    validator._check_planned_owners(self.owners, self.entries)))

    def test_malformed_owner_report_is_rejected_without_crashing(self) -> None:
        for data in (None, [], {}, {**self.owners, "extra": True},
                     {**self.owners, "version": True}, {**self.owners, "version": 2},
                     {**self.owners, "coverage_mode": "off"},
                     {**self.owners, "owners": []},
                     {**self.owners, "needs_tag_legacy_ids": [None]},
                     {**self.owners, "needs_tag_legacy_ids": "obj.apple"}):
            with self.subTest(data=data):
                self.assertTrue(validator._check_planned_owners(data, self.entries))

    def test_legacy_list_cannot_have_unknown_duplicate_or_out_of_scope_ids(self) -> None:
        for legacy in (["obj.not_real"], ["obj.apple", "obj.apple"], ["obj.hatchet"]):
            self.owners["needs_tag_legacy_ids"] = legacy
            self.assertTrue(validator._check_planned_owners(self.owners, self.entries))

    def test_need_tier_without_any_usable_object_fails_coverage(self) -> None:
        needs = {"needs": {"sleep": {"poor": [{"id": "obj.blanket_wool"}]}}}
        self.assertEqual(validator._check_household_coverage(needs, self.entries), [
            "household needs sleep/poor: no usable/complete catalog object"])

    def test_one_usable_or_complete_object_covers_each_tier(self) -> None:
        needs = {"needs": {"sleep": {
            "poor": [{"id": "obj.blanket_wool"}, {"id": "obj.bolster_straw"}],
            "mid": [{"id": "obj.bolster_straw"}],
        }}}
        for lifecycle in ("usable", "complete"):
            self.entries["obj.bolster_straw"]["lifecycle"] = lifecycle
            self.assertEqual(validator._check_household_coverage(needs, self.entries), [])

    def test_unknown_object_never_counts_as_usable_coverage(self) -> None:
        needs = {"needs": {"sleep": {"poor": [{"id": "obj.not_real"}]}}}
        self.assertTrue(validator._check_household_coverage(needs, self.entries))

    def test_new_scoped_objects_need_a_recognized_need_tag(self) -> None:
        for category in sorted(validator.NEEDS_TAG_CATEGORIES):
            candidate = {"category": category, "tags": ["household", "luxury"]}
            entries = {"obj.new_object": candidate}
            self.assertTrue(validator._check_needs_tags(self.needs, entries, []))
            candidate["tags"].append("sleep")
            self.assertEqual(validator._check_needs_tags(self.needs, entries, []), [])

    def test_only_explicit_legacy_ids_are_exempt_from_needs_tags(self) -> None:
        self.assertEqual(validator._check_needs_tags(
            self.needs, self.entries, self.owners["needs_tag_legacy_ids"]), [])
        self.assertTrue(validator._check_needs_tags(self.needs, self.entries, []))
        self.assertEqual(validator._check_needs_tags(
            self.needs, {"obj.new_tool": {"category": "tool", "tags": ["iron"]}}, []), [])

    def test_warning_rollout_and_strict_mode_have_same_other_errors(self) -> None:
        warnings: list[str] = []
        gap = "household needs sleep/poor: no usable/complete catalog object"
        # Keep mode-routing regression coverage independent of future art delivery.
        with patch.object(validator, "_check_household_coverage", return_value=[gap]):
            problems = validator.validate(warnings=warnings)
            strict = validator.validate(strict_household_coverage=True)
        self.assertEqual(warnings, [gap])
        self.assertCountEqual(strict, problems + warnings)
        original = lib.load_json
        with patch.object(lib, "load_json", wraps=original) as load_json:

            def load_strict(path: Path):
                if path == validator.PLANNED_OWNERS_PATH:
                    return {**self.owners, "coverage_mode": "error"}
                return original(path)

            load_json.side_effect = load_strict
            with patch.object(validator, "_check_household_coverage", return_value=[gap]):
                self.assertCountEqual(validator.validate(), strict)

    def test_missing_or_malformed_owner_file_is_a_validation_error(self) -> None:
        original = lib.load_json
        for error in (OSError("missing"), ValueError("malformed JSON")):
            def load_bad(path: Path):
                if path == validator.PLANNED_OWNERS_PATH:
                    raise error
                return original(path)

            with patch.object(lib, "load_json", side_effect=load_bad):
                self.assertTrue(any("planned owners: missing or invalid" in p
                                    for p in validator.validate()))

    def test_cli_prints_warnings_but_does_not_fail_on_them(self) -> None:
        def warning_only(**kwargs):
            kwargs["warnings"].append("household needs sleep/poor: uncovered")
            return []

        with patch.object(validator, "validate", side_effect=warning_only) as validate:
            buffer = io.StringIO()
            with redirect_stdout(buffer):
                self.assertEqual(validator.main([]), 0)
            self.assertIn("WARNING: household needs sleep/poor", buffer.getvalue())
            self.assertIn("0 problem(s), 1 warning(s)", buffer.getvalue())
            with redirect_stdout(io.StringIO()) as quiet:
                self.assertEqual(validator.main(["--quiet", "--strict-household-coverage"]), 0)
            self.assertEqual(quiet.getvalue(), "")
            self.assertTrue(validate.call_args.kwargs["strict_household_coverage"])


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
