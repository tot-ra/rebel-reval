"""Prestige and wear variant rules (docs/SYSTEMS/EQUIPMENT_VARIANTS.md, task R-2004, EQ-2).

    python3 -m unittest tests.python.test_equipment_variants -v
"""
import collections
import json
import re
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/city"))
import citizen_wardrobe as wd  # noqa: E402

CITIZENS = ROOT / "content/world/reval_city/citizens.json"
CELL = re.compile(r"^p[123]_w[012]$")


def person(n=0, **kw):
    base = {"id": f"cit.lt.var.{n:03d}", "sex": "m", "age": 35, "status": "labourer", "trade": "labourer",
            "household_role": "head", "faction": "none", "ethnicity": "estonian"}
    base.update(kw)
    return base


def cells(p):
    return wd.variants(p, ["gambeson", "kettle_hat", "hood"])


class VariantRules(unittest.TestCase):
    def test_same_census_same_variants(self):
        p = person(trade="smith", status="master_craftsman", age=52)
        self.assertEqual(cells(p), cells(dict(p)))
        self.assertEqual(wd.own_cell(p), wd.own_cell(json.loads(json.dumps(p))))

    def test_entries_carry_the_layer_and_a_cell(self):
        entries, gear = cells(person())
        self.assertEqual([wd.layer_of(e) for e in entries], ["gambeson", "kettle_hat", "hood"])
        for entry in entries:
            self.assertRegex(entry.split("@")[1], CELL)
        self.assertRegex(gear, CELL)

    def test_prestige_by_office(self):
        watch = person(duty={"kit": "watch", "post": "gate.viru"}, status="burgher_merchant")
        self.assertEqual(wd.prestige_of(watch), 1)  # town munition, whatever his own wealth
        crown = person(trade="man_at_arms", status="soldier", duty={"kit": "crown", "post": "gate.viru"})
        self.assertEqual(wd.prestige_of(crown), 2)
        self.assertEqual(wd.prestige_of(person(trade="knight", status="noble")), 3)
        self.assertEqual(wd.prestige_of(person(trade="watch_sergeant", duty={"kit": "sergeant"})), 1)
        self.assertEqual(wd.prestige_of(person(trade="watch_sergeant", faction="danish_crown",
                                               duty={"kit": "sergeant"})), 2)
        # A rich burgher's own sword is richer than the town sergeant's issue.
        self.assertGreater(wd.prestige_of(person(status="patrician", trade="merchant")),
                           wd.prestige_of(person(trade="watch_sergeant", duty={"kit": "sergeant"})))
        self.assertEqual(wd.prestige_of(person(status="labourer")), 1)

    def test_wear_by_faction(self):
        for n in range(40):
            self.assertEqual(wd.wear_of(person(n, faction="harju_kings")), 2)
            self.assertIn(wd.wear_of(person(n, faction="livonian_order", trade="knight", status="noble")), (0, 1))

    def test_wear_by_age_and_trade(self):
        young = [wd.wear_of(person(n, age=19, status="patrician", trade="merchant")) for n in range(200)]
        old = [wd.wear_of(person(n, age=62, trade="porter")) for n in range(200)]
        self.assertLess(sum(young) / len(young), 0.6)
        self.assertGreater(sum(old) / len(old), 1.6)

    def test_issue_kit_shared_per_unit(self):
        unit = [person(n, duty={"kit": "watch", "post": "gate.sand"}, age=20 + n, trade="mason")
                for n in range(8)]
        kit = {e for p in unit for e in cells(p)[0] if wd.layer_of(e) in ("gambeson", "kettle_hat")}
        self.assertEqual(len({e.split("@")[1] for e in kit}), 1)
        self.assertEqual(len({cells(p)[1] for p in unit}), 1)
        # Own clothes (the hood) stay the man's own.
        self.assertGreater(len({cells(p)[0][2] for p in unit}), 1)

    def test_posts_differ(self):
        posts = [f"gate.{g}" for g in ("viru", "sand", "lai", "karja", "harju", "mere", "nunne", "suur")]
        issued = {wd.issue_cell(person(duty={"kit": "watch", "post": post})) for post in posts}
        self.assertGreater(len(issued), 1)

    def test_off_duty_has_no_issue(self):
        self.assertEqual(wd.issue_cell(person()), "")
        self.assertEqual(wd.issue_cell(person(duty={"kit": "keeper", "post": "gate.viru"}))[:2], "p1")


class RuntimeVariants(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.residents = json.loads(CITIZENS.read_text())["residents"]

    def test_every_entry_has_a_cell(self):
        for r in self.residents:
            for entry in r["wear"]:
                layer, _, cell = entry.partition("@")
                self.assertTrue(layer, r["id"])
                self.assertRegex(cell, CELL, r["id"])

    def test_distribution_per_office(self):
        by_kit = collections.defaultdict(collections.Counter)
        for r in self.residents:
            kit = (r.get("duty") or {}).get("kit")
            if kit in ("watch", "crown", "sergeant"):
                by_kit[kit][r["gear_variant"]] += 1
        self.assertEqual({c[:2] for c in by_kit["watch"]}, {"p1"})
        self.assertEqual({c[:2] for c in by_kit["crown"]}, {"p2"})
        # More than one unit cell among the watch: guards from different posts differ.
        self.assertGreater(len(by_kit["watch"]), 1)

    def test_rebels_and_knights(self):
        for r in self.residents:
            cells_worn = {e.partition("@")[2] for e in r["wear"]}
            if r.get("faction") in wd.REBELS and not r.get("duty"):
                self.assertTrue(all(c.endswith("_w2") for c in cells_worn), r["id"])
            if r["trade"] == "knight" and r["status"] == "noble" and r["wear"]:
                self.assertTrue(all(c.startswith("p3") for c in cells_worn), r["id"])
            if r.get("shield"):
                self.assertRegex(r["gear_variant"], CELL, r["id"])

    def test_sword_belts(self):
        """R-2007: sergeants, crown men, knights, squires and men-at-arms gird a sword; the watch does not."""
        by_kit = collections.Counter()
        for r in self.residents:
            kit = (r.get("duty") or {}).get("kit", "")
            if r.get("sword"):
                self.assertRegex(r["gear_variant"], CELL, r["id"])
                self.assertTrue(kit in ("sergeant", "crown") or r["trade"] in wd.ARMED_TRADES, r["id"])
                by_kit[kit or r["trade"]] += 1
                if r["trade"] == "knight" and r["status"] == "noble":
                    self.assertTrue(r["gear_variant"].startswith("p3"), r["id"])
            elif kit in ("sergeant", "crown"):
                self.fail(f"{r['id']} on {kit} duty without a sword")
            self.assertFalse(kit == "watch" and r.get("sword"), r["id"])
        self.assertGreater(by_kit["sergeant"], 0)
        self.assertGreater(by_kit["knight"], 0)


if __name__ == "__main__":
    unittest.main()
