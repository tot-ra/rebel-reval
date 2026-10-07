"""The compiled citizen file stays consistent with the census and the body library."""
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/assets/realistic_humans"))
import citizen_bodies  # noqa: E402

DATA = json.loads((ROOT / "content/world/reval_city/citizens.json").read_text())
PLACE_KEYS = ("home", "work", "errand", "errand2", "water", "food", "fuel", "latrine", "supply",
              "school", "church", "stroll")
STAY_KEYS = {"door", "home"} | set(PLACE_KEYS)


class CitizenRuntimeTest(unittest.TestCase):
    def test_every_body_is_in_the_library(self):
        names = {citizen_bodies.body_id(sex, stage, build, outfit)
                 for sex in "mf" for stage, builds in citizen_bodies.STAGE_BUILDS.items()
                 for build in builds for outfit in (("a", "b") if stage == "adult" else ("a",))}
        for r in DATA["residents"]:
            self.assertIn(r["body"], names, r["id"])
            self.assertTrue((ROOT / f"assets/characters/variants/{r['body']}.tscn").is_file(), r["body"])

    def test_places_and_patterns_resolve(self):
        places = len(DATA["places"])
        for r in DATA["residents"]:
            self.assertIn(r["pattern"], DATA["patterns"])
            for key in PLACE_KEYS:
                self.assertTrue(0 <= r[key] < places, (r["id"], key))
        for name, legs in DATA["patterns"].items():
            hours = [h for h, _ in legs]
            self.assertEqual(hours, sorted(hours), name)
            for _, key in legs:
                self.assertIn(key, STAY_KEYS | {"door"}, name)

    def test_children_and_infants(self):
        ages = [r["age"] for r in DATA["residents"]]
        self.assertGreaterEqual(min(ages), 3)
        schoolchildren = [r for r in DATA["residents"] if r["pattern"] == "school"]
        self.assertTrue(schoolchildren)
        self.assertTrue(all(7 <= r["age"] < 15 for r in schoolchildren))


if __name__ == "__main__":
    unittest.main()
