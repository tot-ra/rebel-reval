"""Citizen wardrobe rules (docs/SYSTEMS/CITIZEN_WARDROBE.md, tasks R-1663, R-1665).

    python3 -m unittest tests.python.test_citizen_wardrobe -v
"""
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/city"))
sys.path.insert(0, str(ROOT / "tools/assets/realistic_humans"))
import build_citizen_runtime as runtime  # noqa: E402
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

    def test_wives_covered_maidens_braided(self):
        """WD-3: a grown woman wears exactly one of braids, headscarf, head cloth; wives
        and widows are never bareheaded; the veil only goes over the headscarf."""
        for outfit in citizen_bodies.FEMALE_OUTFITS:
            for role in ("spouse", "head", "maid", "child", "resident"):
                for status, trade in (("servant", "maid"), ("patrician", "merchant"),
                                      ("master_craftsman", "weaver"), ("labourer", "washerwoman")):
                    for i in range(60):
                        p = person(id=f"cit.wd3.{outfit}.{role}.{trade}.{i}", sex="f", age=20 + i % 30,
                                   status=status, trade=trade, household_role=role)
                        wear, dye = wd.dress(p, layers(p, outfit))
                        heads = [h for h in wear if h in wd.WOMAN_HEAD]
                        self.assertEqual(len(heads), 1, (outfit, role, wear))
                        if role in ("spouse", "head"):
                            self.assertNotIn("braids", wear, (outfit, role, wear))
                        if "veil_over" in wear:
                            self.assertTrue(any(h in wear for h in wd.UNDER_VEIL), wear)
                        for h in ("headscarf", "head_cloth", "wimple", "barbette"):
                            if h in wear:
                                self.assertIn(h, dye)

    def test_unmarried_women_mostly_braided(self):
        braided = 0
        for i in range(400):
            p = person(id=f"cit.wd3.m.{i}", sex="f", age=19, status="servant", trade="spinner",
                       household_role="maid")
            braided += "braids" in wd.dress(p, layers(p, "d"))[0]
        self.assertEqual(braided, 400)  # no kerchief trade: always bareheaded

    def test_elder_women_always_covered_never_braided(self):
        for i in range(200):
            p = person(id=f"cit.wd3.e.{i}", sex="f", age=66, status="servant", trade="spinner",
                       household_role="resident")
            wear, _ = wd.dress(p, layers(p))
            self.assertIn("headscarf", wear)
            self.assertNotIn("braids", layers(p))

    def test_girls_keep_baked_braids(self):
        girl = person(sex="f", age=9, trade="child", status="dependent", household_role="child")
        self.assertEqual(citizen_bodies.layers_of("f", "child"), ())
        self.assertEqual(wd.dress(girl, ())[0], [])

    def test_head_cloth_is_estonian_wives_only(self):
        for outfit in "abc":
            self.assertNotIn("head_cloth", citizen_bodies.layers_of("f", "adult", outfit))
        self.assertIn("head_cloth", citizen_bodies.layers_of("f", "adult", "d"))
        self.assertNotIn("veil_over", citizen_bodies.layers_of("f", "adult", "d"))
        self.assertNotIn("waist_apron", citizen_bodies.layers_of("f", "adult", "c"))
        wife = person(id="cit.wd3.hc", sex="f", status="servant", trade="spinner", household_role="spouse")
        covered = {h for i in range(100) for h in wd.dress(dict(wife, id=f"cit.wd3.hc.{i}"), layers(wife, "d"))[0]
                   if h in wd.WOMAN_HEAD}
        self.assertEqual(covered, {"head_cloth", "headscarf"})

    def test_wimple_and_barbette_follow_age_and_purse(self):
        """EQ-27: barbette only on rich burgher wives, wimple on nuns and widows or elders of
        means; neither on the Estonian wrap-skirt body nor on maidens, labourers or children."""
        for outfit in "abc":
            for layer in ("wimple", "barbette"):
                self.assertIn(layer, citizen_bodies.layers_of("f", "adult", outfit))
        for layer in ("wimple", "barbette"):
            self.assertNotIn(layer, citizen_bodies.layers_of("f", "adult", "d"))
            self.assertNotIn(layer, citizen_bodies.layers_of("f", "child"))
        seen = set()
        for i in range(300):
            wife = person(id=f"cit.eq27.w.{i}", sex="f", age=34, status="patrician", trade="merchant",
                          household_role="spouse")
            wear, dye = wd.dress(wife, layers(wife, "c"))
            seen.update(wear)
            if "barbette" in wear:
                self.assertIn("veil_over", wear)
                self.assertIn("barbette", dye)
            maid = person(id=f"cit.eq27.m.{i}", sex="f", age=19, status="patrician", trade="merchant",
                          household_role="maid")
            self.assertNotIn("barbette", wd.dress(maid, layers(maid, "c"))[0])
            poor = person(id=f"cit.eq27.p.{i}", sex="f", age=36, status="servant", trade="spinner",
                          household_role="spouse")
            self.assertFalse({"barbette", "wimple"} & set(wd.dress(poor, layers(poor, "b"))[0]))
            widow = person(id=f"cit.eq27.e.{i}", sex="f", age=66, status="master_craftsman", trade="weaver",
                           household_role="resident")
            wear, _ = wd.dress(widow, layers(widow, "b"))
            seen.update(wear)
            self.assertEqual(len([h for h in wear if h in wd.WOMAN_HEAD]), 1, wear)
            nun = person(id=f"cit.eq27.n.{i}", sex="f", age=30, status="master_craftsman", trade="nun")
            wear, dye = wd.dress(nun, layers(nun, "b"))
            self.assertEqual([h for h in wear if h in wd.WOMAN_HEAD], ["wimple"])
            self.assertEqual(dye["veil_over"], list(wd.HABIT_BLACK) if isinstance(wd.HABIT_BLACK, tuple) else wd.HABIT_BLACK)
        self.assertTrue({"barbette", "wimple", "headscarf"} <= seen, seen)

    def test_gown_census_rule(self):
        """Outfit c only on the rich (women's surcoat, young men's cotehardie), d only on
        Estonian or Finnish women below the rich, no man in d, nuns stay in the long habit gown."""
        seen = set()
        for i in range(600):
            for status in ("noble", "patrician", "burgher_merchant", "master_craftsman", "servant"):
                for eth in ("estonian", "german"):
                    for sex in "mf":
                        p = person(id=f"cit.gown.{i}", sex=sex, status=status, trade="spinner",
                                   ethnicity=eth)
                        outfit = runtime.clothing(p, "adult")[0]
                        seen.add(outfit)
                        if outfit == "c":
                            self.assertEqual(wd.wealth_of(p), "rich")
                            if sex == "m":
                                self.assertLessEqual(p["age"], runtime.COTE_MAX_AGE)
                        if outfit == "d":
                            self.assertEqual(sex, "f")
                            self.assertEqual(eth, "estonian")
                            self.assertNotEqual(wd.wealth_of(p), "rich")
        self.assertEqual(seen, {"a", "b", "c", "d"})
        nun = person(sex="f", trade="nun", status="cleric", ethnicity="estonian")
        self.assertEqual(runtime.clothing(nun, "adult")[0], "b")
        self.assertEqual(runtime.clothing(person(sex="f", status="noble", age=70), "elder")[0], "a")

    def test_cotehardie_census_rule(self):
        """EQ-21: the buttoned cotehardie on rich young men only; older rich men wear the
        calf-length tunic, the poor the short one, friars their habit."""
        young = [runtime.clothing(person(id=f"cit.cote.{i}", status="patrician", trade="merchant", age=24),
                                  "adult")[0] for i in range(400)]
        self.assertGreater(young.count("c"), 200)
        self.assertEqual(set(young), {"b", "c"})
        for i in range(400):
            old = person(id=f"cit.cote.old.{i}", status="noble", trade="knight", age=50)
            self.assertNotEqual(runtime.clothing(old, "adult")[0], "c")
            poor = person(id=f"cit.cote.poor.{i}", age=22)
            self.assertNotEqual(runtime.clothing(poor, "adult")[0], "c")
            friar = person(id=f"cit.cote.friar.{i}", status="noble", trade="monk", age=22)
            self.assertNotEqual(runtime.clothing(friar, "adult")[0], "c")
        self.assertEqual(citizen_bodies.outfits_of("m", "adult"), ("a", "b", "c"))
        for apron in ("smith_apron", "waist_apron", "back_sack"):
            self.assertNotIn(apron, citizen_bodies.layers_of("m", "adult", "c"))
        self.assertIn("gambeson", citizen_bodies.layers_of("m", "adult", "c"))

    def test_body_ids_round_trip(self):
        for sex in "mf":
            for stage, builds in citizen_bodies.STAGE_BUILDS.items():
                for outfit in citizen_bodies.outfits_of(sex, stage):
                    body = citizen_bodies.body_id(sex, stage, builds[0], outfit)
                    self.assertEqual(citizen_bodies.outfit_of(body), outfit, body)

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
            for layer in map(wd.layer_of, r["wear"]):
                path = ROOT / f"assets/characters/realistic/{r['body']}/layers/{layer}.glb"
                if not path.is_file():
                    missing.add(str(path.relative_to(ROOT)))
        self.assertEqual(sorted(missing), [])

    def test_armour_residents_obey_rules(self):
        for r in self.residents:
            if set(map(wd.layer_of, r["wear"])) & wd.KNIGHT_ONLY:
                self.assertEqual((r["trade"], r["status"]), ("knight", "noble"), r["id"])
            if r.get("shield"):
                self.assertTrue(r["trade"] in ("knight", "man_at_arms"), r["id"])

    def test_dominican_friars_wear_white_habit_and_black_hood(self):
        friars = [r for r in self.residents if r.get("order") == "dominican" and r["trade"] == "monk"]
        self.assertEqual(len(friars), 24)
        for r in friars:
            self.assertEqual(r["cloth"], list(runtime.DOMINICAN_WHITE), r["id"])
            worn = [wd.layer_of(e) for e in r["wear"]]
            self.assertIn("hood", worn, r["id"])
            self.assertEqual(r["wear_dye"]["hood"], [round(c, 3) for c in wd.HABIT_BLACK], r["id"])
            self.assertNotIn("order_mantle", worn, r["id"])
            self.assertFalse(r.get("shield"), r["id"])

    def test_variety(self):
        looks = {(r["body"], tuple(map(wd.layer_of, r["wear"]))) for r in self.residents}
        self.assertGreater(len(looks), 200)
        dressed = sum(1 for r in self.residents if r["wear"])
        self.assertGreater(dressed / len(self.residents), 0.5)


if __name__ == "__main__":
    unittest.main()
