"""Saaremaa (Kaali) site plan: crater bowl and lake (ADR 0042, task R-1524,
docs/SYSTEMS/REGIONAL_SITES.md)."""
import json
import math
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/city"))

import build_site_plan as builder  # noqa: E402

SPAWNS = {"from_reval_harbor", "from_world_parnu", "from_world_poide"}


class BuildSaaremaaSitePlanTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.overlay = json.loads(builder.overlay_path("saaremaa").read_text())
        cls.result = builder.build_site(cls.overlay)
        cls.plan = cls.result["plan"]

    def test_committed_outputs_are_current(self):
        self.assertEqual(builder.main(["--site", "saaremaa", "--check"]), 0)

    def test_travel_ids_and_spawns(self):
        info = self.plan["site"]
        self.assertFalse(info["coast"])
        self.assertEqual((info["location_id"], info["map_id"], info["scene_id"]),
                         ("world_saaremaa", "world.saaremaa", "world_saaremaa"))
        self.assertTrue(SPAWNS <= {s["id"] for s in self.plan["spawns"]})
        manifest = {row["id"]: row for row in json.loads(
            (ROOT / "content/transitions/active_destinations.json").read_text())["scenes"]}
        row = manifest["world_saaremaa"]
        self.assertEqual(row["path"], "res://scenes/world/sites/saaremaa.tscn")
        self.assertEqual({s["id"] for s in row["spawns"]}, SPAWNS)

    def test_lake_sits_in_the_crater_bowl(self):
        lakes = self.plan["lakes"]
        self.assertEqual([lk["id"] for lk in lakes], ["saaremaa.lake"])
        lake = lakes[0]
        self.assertTrue(12.0 < lake["radius"] < 32.0, lake["radius"])
        hw = self.result["height_wu"]
        x0, y0 = self.plan["height_grid"]["origin"]
        cell = self.plan["height_grid"]["cell"]

        def ground(x, y):
            return float(hw[int(round((y - y0) / cell)), int(round((x - x0) / cell))])

        cx, cy = lake["at"]
        self.assertGreater(lake["surface"] - ground(cx, cy), 2.5, "deep enough to swim")
        rim = self.overlay["crater"]["rim_radius_m"]
        self.assertGreater(ground(cx, cy - rim), lake["surface"] + 12.0, "rim stands over the water")
        self.assertGreater(min(hw.flatten()), 0.0, "bowl stays above the runtime sea level")
        for t in self.plan["trees"]:
            self.assertGreater(math.dist((t[0], t[1]), (cx, cy)), lake["radius"], t)

    def test_other_sites_carry_no_lake_key(self):
        for site in ("paide", "harju", "sacred_grove"):
            plan = json.loads((ROOT / "content/world" / site / "plan.json").read_text())
            self.assertNotIn("lakes", plan, site)


if __name__ == "__main__":
    unittest.main()
