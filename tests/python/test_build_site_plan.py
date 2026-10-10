"""Regional site plan builder (ADR 0042, docs/SYSTEMS/REGIONAL_SITES.md)."""
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/city"))

import build_site_plan as builder  # noqa: E402

PAIDE = ROOT / "content/world/paide/plan.json"


class BuildSitePlanTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.overlay = json.loads(builder.overlay_path("paide").read_text())
        cls.result = builder.build_site(cls.overlay)
        cls.plan = cls.result["plan"]

    def test_committed_paide_outputs_are_current(self):
        self.assertEqual(builder.main(["--site", "paide", "--check"]), 0)

    def test_build_is_deterministic(self):
        again = builder.build_site(json.loads(builder.overlay_path("paide").read_text()))
        self.assertEqual(json.dumps(again["plan"]), json.dumps(self.plan))
        self.assertEqual(again["height"]["data"], self.result["height"]["data"])

    def test_inland_site_has_no_coast(self):
        self.assertEqual(self.plan["shoreline"], [])
        self.assertFalse(self.plan["site"]["coast"])
        self.assertEqual(self.plan["harbour"], {})

    def test_site_block_keeps_travel_ids(self):
        site = self.plan["site"]
        self.assertEqual(site["id"], "paide")
        self.assertEqual(site["location_id"], "world_paide")
        self.assertEqual(site["map_id"], "world.paide")
        self.assertEqual(site["scene_id"], "world_paide")
        self.assertAlmostEqual(self.plan["origin"]["lat"], 58.889, places=2)

    def test_every_record_id_is_site_prefixed(self):
        for key in ("buildings", "towers", "gates", "streets", "fields", "pastures", "bridges", "districts",
                    "points_of_interest", "curtains", "toompea_walls", "woods"):
            for rec in self.plan[key]:
                self.assertTrue(rec["id"].startswith("paide."), f"{key}: {rec['id']}")
        for spawn in self.plan["spawns"]:
            self.assertTrue(spawn["record"].startswith("paide.spawn."))

    def test_manifest_spawns_are_plan_arrivals(self):
        manifest = json.loads((ROOT / "content/transitions/active_destinations.json").read_text())
        scene = next(s for s in manifest["scenes"] if s["id"] == "world_paide")
        self.assertEqual(scene["path"], "res://scenes/world/sites/paide.tscn")
        arrivals = {s["id"] for s in self.plan["spawns"]}
        for spawn in scene["spawns"]:
            self.assertIn(spawn["id"], arrivals)

    def test_castle_has_keep_ditch_and_gates(self):
        forms = {t["id"]: t["form"] for t in self.plan["towers"]}
        self.assertEqual(forms["paide.tower.keep"], "octagonal")
        self.assertEqual({g["id"] for g in self.plan["gates"]}, {"paide.gate.west", "paide.gate.northeast"})
        self.assertGreater(len(self.plan["moat"]["points"]), 10)
        # The castle way crosses the ditch on a bridge.
        self.assertIn("paide.road.castle", {b["road"] for b in self.plan["bridges"]})

    def test_heights_stay_above_the_local_datum(self):
        h = self.result["height_wu"]
        self.assertGreater(float(h.min()), 0.0, "an inland site never dips under the runtime's sea level")
        self.assertLess(float(h.max()), 40.0)

    def test_clip_drops_route_relation_ways_outside_the_frame(self):
        raw = {"elements": [
            {"type": "node", "id": 1, "lat": 58.889, "lon": 25.572},
            {"type": "node", "id": 2, "lat": 58.890, "lon": 25.573},
            {"type": "node", "id": 3, "lat": 59.40, "lon": 24.70},
            {"type": "node", "id": 4, "lat": 59.41, "lon": 24.71},
            {"type": "way", "id": 10, "nodes": [1, 2], "tags": {"highway": "track"}},
            {"type": "way", "id": 11, "nodes": [3, 4], "tags": {"highway": "trunk"}},
            {"type": "relation", "id": 20, "members": [{"type": "way", "ref": 11, "role": ""}], "tags": {"type": "route"}},
        ]}
        out = builder.clip_raw_osm(raw, self.overlay["site"]["inputs"]["osm_bbox"])
        ids = {(e["type"], e["id"]) for e in out["elements"]}
        self.assertIn(("way", 10), ids)
        self.assertNotIn(("way", 11), ids)
        self.assertNotIn(("relation", 20), ids)
        self.assertNotIn(("node", 3), ids)

    def test_unknown_site_is_rejected(self):
        self.assertEqual(builder.main(["--site", "atlantis", "--check"]), 2)


if __name__ == "__main__":
    unittest.main()
