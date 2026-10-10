"""Act 2 hinterland site plans: Harju village, rebel kings' camp, sacred grove
(ADR 0042, docs/SYSTEMS/REGIONAL_SITES.md)."""
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/city"))

import build_site_plan as builder  # noqa: E402

# site id -> (location id, manifest spawn ids)
SITES = {
    "harju": ("world_harju", {"from_reval_east", "from_world_sacred_grove", "from_world_rebel_kings",
                              "from_world_kanavere", "from_world_sojamae"}),
    "rebel_kings": ("world_rebel_kings", {"from_world_harju", "from_world_kanavere"}),
    "sacred_grove": ("world_sacred_grove", {"from_reval_south", "from_world_harju"}),
}
PREFIXED = ("buildings", "streets", "fields", "pastures", "districts", "points_of_interest", "woods", "gates")


class BuildHinterlandSitePlansTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.plans = {s: builder.build_site(json.loads(builder.overlay_path(s).read_text()))["plan"] for s in SITES}
        cls.manifest = {row["id"]: row for row in json.loads(
            (ROOT / "content/transitions/active_destinations.json").read_text())["scenes"]}

    def test_committed_outputs_are_current(self):
        for site in SITES:
            self.assertEqual(builder.main(["--site", site, "--check"]), 0, site)

    def test_inland_travel_ids_and_spawns(self):
        for site, (location, spawns) in SITES.items():
            plan = self.plans[site]
            info = plan["site"]
            self.assertFalse(info["coast"], site)
            self.assertEqual((info["location_id"], info["map_id"], info["scene_id"]),
                             (location, location.replace("world_", "world."), location))
            self.assertEqual({s["id"] for s in plan["spawns"]}, spawns | {info["default_spawn"]})
            row = self.manifest[location]
            self.assertEqual(row["path"], "res://scenes/world/sites/%s.tscn" % site)
            self.assertEqual({s["id"] for s in row["spawns"]}, spawns, "every spawn id kept")

    def test_record_ids_are_site_prefixed(self):
        for site, plan in self.plans.items():
            for key in PREFIXED:
                for record in plan[key]:
                    self.assertTrue(record["id"].startswith(site + "."), record["id"])

    def test_no_ground_below_the_datum(self):
        # Inland heights stay above zero, so the runtime's sea tests never fire.
        for site in SITES:
            result = builder.build_site(json.loads(builder.overlay_path(site).read_text()))
            self.assertGreater(float(result["height_wu"].min()), 0.0, site)

    def test_village_camp_and_grove_content(self):
        harju, camp, grove = self.plans["harju"], self.plans["rebel_kings"], self.plans["sacred_grove"]
        self.assertTrue(all(b["roof"] == "shingle" for b in harju["buildings"]))
        self.assertTrue(all(b["enterable"] and b["door"] for b in harju["buildings"]))
        self.assertEqual(sum("household" in b for b in harju["buildings"]), 7)
        self.assertGreater(len(harju["fields"]), 20)
        self.assertEqual({c["state"] for c in camp["curtains"]}, {"palisade"})
        self.assertGreaterEqual(sum(p["kind"] == "campfire" for p in camp["points_of_interest"]), 8)
        self.assertEqual(grove["buildings"], [])
        kinds = [p["kind"] for p in grove["points_of_interest"]]
        self.assertEqual(kinds.count("offering_stone"), 4)
        self.assertEqual(kinds.count("spring"), 1)


if __name__ == "__main__":
    unittest.main()
