"""Census invariants: deterministic, within the dated brackets, consistent with the plan."""

from __future__ import annotations

import json
import subprocess
import sys
import unittest
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CENSUS = json.loads((ROOT / "docs/data/city_census.json").read_text(encoding="utf-8"))
PLAN = json.loads((ROOT / "docs/data/citizen_cards_plan.json").read_text(encoding="utf-8"))
CITY = json.loads((ROOT / "content/world/reval_city/plan.json").read_text(encoding="utf-8"))


class CensusTests(unittest.TestCase):
    def setUp(self):
        self.P = {p["id"]: p for p in CENSUS["persons"]}
        self.H = {h["id"]: h for h in CENSUS["households"]}

    def test_generators_are_deterministic_and_committed(self):
        for script in ("tools/city/build_city_census.py", "tools/city/plan_citizen_cards.py"):
            r = subprocess.run([sys.executable, str(ROOT / script), "--check"], capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)

    def test_population_inside_dated_bracket(self):
        self.assertGreaterEqual(len(self.P), 3000)
        self.assertLessEqual(len(self.P), 4500)

    def test_every_plot_house_has_a_household(self):
        houses = {b["id"] for b in CITY["buildings"] if b["kind"] == "house"}
        have = {h["building"] for h in CENSUS["households"] if h["kind"] != "institution"}
        self.assertEqual(houses, have)

    def test_no_household_references_a_building_missing_from_the_plan(self):
        plan_ids = {b["id"] for b in CITY["buildings"]}
        sites = {s["id"] for s in CITY["sites"]}
        for h in CENSUS["households"]:
            if h["building"]:
                self.assertIn(h["building"], plan_ids, h["id"])
            if h.get("site"):
                self.assertIn(h["site"], sites, h["id"])
            self.assertNotEqual(h["xy"], [0, 0], h["id"])

    def test_displaced_households_are_rehomed_or_retired(self):
        """R-1934: every household a landmark site took the plot of has a pinned fate."""
        pins = json.loads((ROOT / "tools/city/census_continuity.json").read_text(encoding="utf-8"))["displaced"]
        retired = {r["id"]: r for r in CENSUS["retired_households"]}
        by_from = {h["rehomed_from"]["building"]: h for h in CENSUS["households"] if h.get("rehomed_from")}
        self.assertEqual(len(by_from) + len(retired), len(pins))
        reserved = set()
        for e in pins:
            if e["fate"] == "rehome":
                h = by_from[e["building"]]
                self.assertEqual(h["building"], e["to"])
                self.assertEqual(h["rehomed_from"]["site"], e["site"])
                self.assertEqual(h["class"], "poor")
            else:
                r = next(r for r in retired.values() if r["former"]["building"] == e["building"])
                self.assertNotIn(r["id"], self.H)
                reserved.update(r["members"])
        # retired IDs stay reserved: nobody in the city reuses them
        self.assertFalse(reserved & set(self.P))
        booths = [h["building"] for h in by_from.values()]
        self.assertEqual(len(booths), len(set(booths)))

    def test_ids_and_slugs_are_unique_and_references_resolve(self):
        self.assertEqual(len(self.P), len(CENSUS["persons"]))
        self.assertEqual(len({p["slug"] for p in CENSUS["persons"]}), len(CENSUS["persons"]))
        for h in CENSUS["households"]:
            for m in h["members"]:
                self.assertEqual(self.P[m]["household"], h["id"])

    def test_age_structure_is_period_plausible(self):
        n = len(self.P)
        under15 = sum(1 for p in self.P.values() if p["age"] < 15) / n
        over60 = sum(1 for p in self.P.values() if p["age"] >= 60) / n
        self.assertTrue(0.25 <= under15 <= 0.38, under15)
        self.assertTrue(0.04 <= over60 <= 0.09, over60)
        female = sum(1 for p in self.P.values() if p["sex"] == "f") / n
        self.assertTrue(0.44 <= female <= 0.56, female)

    def test_ethnic_mix_matches_dossier_brackets(self):
        c = Counter(p["ethnicity"] for p in self.P.values())
        n = len(self.P)
        self.assertLess(c["german"] / n, 0.5)
        self.assertGreater(c["estonian"] / n, 0.33)
        self.assertLess(c["russian"] / n, 0.05)

    def test_families_are_biologically_sane(self):
        for h in CENSUS["households"]:
            if h["kind"] == "institution" or h["class"] == "shed":
                continue
            heads = [self.P[m] for m in h["members"] if self.P[m]["household_role"] == "head"]
            self.assertEqual(len(heads), 1, h["id"])
            for m in h["members"]:
                p = self.P[m]
                if p["household_role"] == "child":
                    self.assertGreaterEqual(heads[0]["age"] - p["age"], 15, (h["id"], p["name"]))

    def test_only_german_burghers_sit_on_the_council(self):
        council = [p for p in self.P.values() if p.get("office") in ("councillor", "burgomaster")]
        self.assertGreaterEqual(len(council), 19)
        self.assertEqual(sum(1 for p in council if p["office"] == "burgomaster"), 2)
        for p in council:
            self.assertEqual((p["ethnicity"], p["sex"]), ("german", "m"))

    def test_gates_and_watch_are_staffed(self):
        self.assertEqual(sum(1 for p in self.P.values() if (p.get("office") or "").startswith("gatekeeper")), 8)
        self.assertGreaterEqual(sum(1 for p in self.P.values() if p.get("office") == "estonian_night_watch"), 8)

    def test_card_plan_edges_are_between_planned_cards(self):
        cards = set(PLAN["cards"])
        for e in PLAN["edges"]:
            self.assertIn(e["a"], cards)
            self.assertIn(e["b"], cards)
            self.assertNotEqual(self.P[e["a"]]["household"], self.P[e["b"]]["household"])
            self.assertTrue(e["fact"])


if __name__ == "__main__":
    unittest.main()
