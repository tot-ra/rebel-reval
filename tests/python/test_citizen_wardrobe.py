"""Citizen wardrobe rules (docs/SYSTEMS/CITIZEN_WARDROBE.md, task R-1663).

    python3 -m unittest tests.python.test_citizen_wardrobe -v
"""
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/city"))
sys.path.insert(0, str(ROOT / "tools/assets/realistic_humans"))
import citizen_bodies  # noqa: E402
import citizen_wardrobe as wd  # noqa: E402

CITIZENS = ROOT / "content/world/reval_city/citizens.json"
ARMOUR = wd.ARMOUR | wd.KNIGHT_ONLY


def person(**kw):
    base = {"id": "cit.lt.test.01", "sex": "m", "age": 35, "status": "labourer", "trade": "labourer",
            "household_role": "head", "faction": "none", "ethnicity": "estonian"}
    base.update(kw)
    return base


def layers(p, outfit="a"):
    return citizen_bodies.layers_of(p["sex"], wd.stage_of(p["age"]), outfit)


class WardrobeRules(unittest.TestCase):
    def test_deterministic(self):
        p = person(trade="smith", status="master_craftsman")
        self.assertEqual(wd.dress(p, layers(p)), wd.dress(dict(p), layers(p)))

    def test_only_fitted_layers(self):
        girl = person(sex="f", age=9, trade="child", status="dependent", household_role="child")
        self.assertEqual(wd.dress(girl, layers(girl))[0], [])
        boy = person(age=9, trade="child", household_role="child")
        for i in range(200):
            wear, _ = wd.dress(dict(boy, id=f"cit.b.{i}"), layers(boy))
            self.assertTrue(set(wear) <= set(layers(boy)), wear)

    def test_nuns_black_veil_monks_black_hood(self):
        nun = person(sex="f", trade="nun", status="cleric", household_role="resident")
        wear, dye = wd.dress(nun, layers(nun, "b"))
        self.assertIn("veil_over", wear)
        self.assertEqual(dye["veil_over"], list(wd.HABIT_BLACK))
        monk = person(trade="monk", status="cleric", household_role="resident")
        wear, dye = wd.dress(monk, layers(monk, "b"))
        self.assertEqual(dye.get("hood"), list(wd.HABIT_BLACK))

    def test_no_armour_on_civilians(self):
        for status, trade in (("patrician", "merchant"), ("burgher_merchant", "merchant"),
                              ("master_craftsman", "smith"), ("labourer", "porter")):
            for i in range(300):
                p = person(id=f"cit.c.{i}", status=status, trade=trade)
                wear, _ = wd.dress(p, layers(p))
                self.assertFalse(ARMOUR & set(wear), (status, trade, wear))

    def test_duty_kits(self):
        crown = person(trade="man_at_arms", status="soldier", duty={"kit": "crown"})
        wear, dye = wd.dress(crown, layers(crown))
        self.assertEqual(wear[:4], ["gambeson", "mail_haubergeon", "surcoat", "kettle_hat"])
        self.assertEqual(dye["surcoat"], list(wd.CROWN_RED))
        watch = person(duty={"kit": "watch"})
        self.assertEqual(wd.dress(watch, layers(watch))[0][:2], ["gambeson", "kettle_hat"])

    def test_one_head_covering_except_armour_stack(self):
        for i in range(400):
            p = person(id=f"cit.h.{i}", trade="knight", status="noble")
            wear, _ = wd.dress(p, layers(p))
            heads = [w for w in wear if w in wd.HEADWEAR]
            self.assertTrue(len(heads) <= 1 or set(heads) <= wd.ARMOUR_HEADS, wear)

    def test_poor_women_not_veiled(self):
        for i in range(300):
            p = person(id=f"cit.w.{i}", sex="f", status="servant", trade="maid", household_role="maid")
            self.assertNotIn("veil_over", wd.dress(p, layers(p))[0])

    def test_one_shoulder_strap(self):
        for i in range(400):
            p = person(id=f"cit.s.{i}", trade="pedlar", status="free_commoner")
            wear, _ = wd.dress(p, layers(p))
            self.assertLessEqual(sum(w in wd.STRAPS for w in wear), 1, wear)

    def test_layers_are_wardrobe_garments(self):
        src = (ROOT / "tools/assets/realistic_humans/garments.py").read_text()
        for stage_layers in citizen_bodies.LAYERS.values():
            for layer in stage_layers:
                self.assertIn(f'"{layer}": (', src, layer)


class ArmourRange(unittest.TestCase):
    """WD-4: knightly harness by rank and faction; nothing of it on the non-noble."""

    def test_knight_kit_only_on_noble_knights(self):
        for status in ("journeyman", "burgher", "free_commoner", "soldier", "master_craftsman"):
            for trade in ("knight", "squire", "man_at_arms", "smith", "merchant"):
                for faction in ("danish_crown", "livonian_order", "none", "hanseatic"):
                    for i in range(60):
                        p = person(id=f"cit.k.{i}", status=status, trade=trade, faction=faction)
                        wear, _ = wd.dress(p, layers(p))
                        self.assertFalse(wd.KNIGHT_ONLY & set(wear), (status, trade, faction, wear))

    def test_squires_and_men_at_arms_wear_no_plate(self):
        for trade, status in (("squire", "noble"), ("man_at_arms", "soldier")):
            for faction in ("danish_crown", "livonian_order", "none"):
                for i in range(200):
                    p = person(id=f"cit.s.{i}", status=status, trade=trade, faction=faction)
                    wear, _ = wd.dress(p, layers(p))
                    self.assertFalse(wd.KNIGHT_ONLY & set(wear), (trade, faction, wear))

    def test_vassal_knight_kit(self):
        seen = set()
        for i in range(300):
            p = person(id=f"cit.v.{i}", status="noble", trade="knight", faction="danish_crown")
            wear, dye = wd.dress(p, layers(p))
            seen |= set(wear)
            if "coat_of_plates" in wear:
                self.assertEqual(dye["coat_of_plates"], list(wd.CROWN_RED))
                self.assertNotIn("surcoat", wear)
            if "bascinet" in wear:
                self.assertIn("aventail", wear)
            if "great_helm" in wear:
                self.assertIn("mail_coif", wear)
                self.assertNotIn("bascinet", wear)
            self.assertNotIn("order_mantle", wear)
        for layer in ("coat_of_plates", "aventail", "bascinet", "great_helm", "mail_chausses", "gauntlets"):
            self.assertIn(layer, seen)

    def test_order_brother_white_mantle(self):
        p = person(status="noble", trade="knight", faction="livonian_order")
        wear, dye = wd.dress(p, layers(p))
        self.assertIn("order_mantle", wear)
        self.assertEqual(dye["order_mantle"], list(wd.ORDER_WHITE))
        self.assertEqual(dye["surcoat"], list(wd.ORDER_WHITE))
        self.assertEqual(wd.shield_of(dict(p), wear), "order")
        self.assertLess(wear.index("surcoat"), wear.index("order_mantle"))

    def test_stack_order_matches_the_clearing_order(self):
        order = citizen_bodies.LAYERS[("m", "adult")]
        stack = ["gambeson", "mail_haubergeon", "coat_of_plates", "mail_coif", "aventail", "surcoat",
                 "order_mantle"]
        self.assertEqual([g for g in order if g in stack], stack)

    def test_shields(self):
        crown = person(trade="man_at_arms", status="soldier", duty={"kit": "crown"})
        self.assertEqual(wd.shield_of(crown, ["gambeson", "mail_haubergeon"]), "")
        burgher = person(trade="smith", status="master_craftsman")
        self.assertEqual(wd.shield_of(burgher, []), "")
        knight = person(trade="knight", status="noble", faction="danish_crown")
        self.assertEqual(wd.shield_of(knight, ["gambeson", "mail_haubergeon"]), "crown")
        knight["faction"] = "none"
        self.assertEqual(wd.shield_of(knight, ["gambeson", "mail_haubergeon"]), "field")

    def test_layer_ids_unique_and_budgeted(self):
        import re
        src = (ROOT / "tools/assets/realistic_humans/build_human.py").read_text()
        for layer in ("coat_of_plates", "aventail", "great_helm", "mail_chausses", "gauntlets", "order_mantle"):
            self.assertIn(f'"{layer}":', src)
            self.assertEqual(citizen_bodies.LAYERS[("m", "adult")].count(layer), 1)
            for key in ("m", "f"):
                for stage in ("elder", "child"):
                    self.assertNotIn(layer, citizen_bodies.LAYERS[(key, stage)])


class RuntimeData(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.residents = json.loads(CITIZENS.read_text())["residents"]

    def test_every_worn_layer_has_a_fitted_glb(self):
        missing = set()
        for r in self.residents:
            for layer in r["wear"]:
                path = ROOT / f"assets/characters/realistic/{r['body']}/layers/{layer}.glb"
                if not path.is_file():
                    missing.add(str(path.relative_to(ROOT)))
        self.assertEqual(sorted(missing), [])

    def test_armour_residents_obey_rules(self):
        for r in self.residents:
            if set(r["wear"]) & wd.KNIGHT_ONLY:
                self.assertEqual((r["trade"], r["status"]), ("knight", "noble"), r["id"])
            if r.get("shield"):
                self.assertTrue(r["trade"] in ("knight", "man_at_arms"), r["id"])

    def test_variety(self):
        looks = {(r["body"], tuple(r["wear"])) for r in self.residents}
        self.assertGreater(len(looks), 200)
        dressed = sum(1 for r in self.residents if r["wear"])
        self.assertGreater(dressed / len(self.residents), 0.5)


if __name__ == "__main__":
    unittest.main()
