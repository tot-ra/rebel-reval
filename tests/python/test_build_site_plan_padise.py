"""Padise regional site plan (ADR 0042, docs/SYSTEMS/REGIONAL_SITES.md#padise-april-1343)."""
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/city"))

import build_site_plan as builder  # noqa: E402

# Anchor ids the Padise monastery controller reads (scripts/world/padise_monastery_controller.gd).
CONTROLLER_ANCHORS = {
    "room_infirmary", "room_brewhouse", "landmark_monastery_well", "room_cloister_garth",
    "landmark_timber_oratory", "room_lay_brothers",
    "cloister_walk_north", "cloister_walk_south", "cloister_walk_west", "cloister_walk_east",
}


class BuildPadisePlanTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.plan = builder.build_site(json.loads(builder.overlay_path("padise").read_text()))["plan"]

    def test_committed_padise_outputs_are_current(self):
        self.assertEqual(builder.main(["--site", "padise", "--check"]), 0)

    def test_inland_and_travel_ids(self):
        site = self.plan["site"]
        self.assertFalse(site["coast"])
        self.assertEqual(self.plan["shoreline"], [])
        self.assertEqual((site["location_id"], site["map_id"], site["scene_id"]), ("world_padise", "world.padise", "world_padise"))
        self.assertEqual({s["id"] for s in self.plan["spawns"]}, {"from_reval_west", "from_world_parnu", "padise.spawn.close"})

    def test_1343_state_has_no_fortification(self):
        for key in ("curtains", "towers", "gates", "toompea_walls", "bridges"):
            self.assertEqual(self.plan[key], [], key)
        self.assertEqual(self.plan["moat"], {})
        self.assertTrue(self.plan["harjapea"]["points"], "the Kloostri river is drawn")

    def test_controller_anchors_are_points_of_interest(self):
        anchors = {p.get("anchor_id") for p in self.plan["points_of_interest"]}
        self.assertTrue(CONTROLLER_ANCHORS <= anchors, CONTROLLER_ANCHORS - anchors)
        for poi in self.plan["points_of_interest"]:
            self.assertTrue(poi["id"].startswith("padise.poi."), poi["id"])


if __name__ == "__main__":
    unittest.main()
