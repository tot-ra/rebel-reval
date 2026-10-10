#!/usr/bin/env python3
"""Tests for tools/city/vegetation_habitat.py and its use in the Reval plan (R-1617)."""

from __future__ import annotations

import json
import sys
import unittest
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CITY_TOOLS = ROOT / "tools/city"
if str(CITY_TOOLS) not in sys.path:
    sys.path.insert(0, str(CITY_TOOLS))

import vegetation_habitat as vh  # noqa: E402

PLAN = ROOT / "content/world/reval_city/plan.json"


class ClearanceTest(unittest.TestCase):
    def setUp(self):
        street = {"points_m": [(0.0, 0.0), (100.0, 0.0)], "width_m": 6.0}
        # A 20 m long, 8 m wide deck centred at (50, 40), running along x.
        bridge = {"at": [50.0, 40.0], "angle": 0.0, "length": 20.0, "width": 8.0}
        self.cl = vh.Clearance([street], [bridge], 1.0)

    def test_trunk_keeps_off_the_carriageway(self):
        self.assertFalse(self.cl.tree_ok((50.0, 2.0)), "on the road")
        self.assertFalse(self.cl.tree_ok((50.0, 4.5)), "on the verge, inside the edge margin")
        self.assertTrue(self.cl.tree_ok((50.0, 3.0 + vh.TREE_ROAD_EDGE_M + 0.5)))

    def test_no_crown_through_a_bridge_deck(self):
        self.assertEqual(self.cl.bridge_distance((50.0, 40.0)), 0.0)
        self.assertFalse(self.cl.tree_ok((50.0, 40.0)), "on the deck")
        self.assertFalse(self.cl.tree_ok((62.0, 40.0)), "2 m off the deck end: crown overhangs it")
        self.assertTrue(self.cl.tree_ok((50.0, 44.0 + vh.TREE_BRIDGE_CLEAR_M + 0.5)))
        self.assertFalse(self.cl.bush_ok((50.0, 45.0)))
        self.assertTrue(self.cl.bush_ok((50.0, 44.0 + vh.BUSH_BRIDGE_CLEAR_M + 0.5)))


class SoilTest(unittest.TestCase):
    def setUp(self):
        # Shore along y = 0, land rising 1 m per 50 m inland (y > 0).
        self.soil = vh.Soil([(-1000.0, 0.0), (1000.0, 0.0)], lambda x, y: y / 50.0)

    def test_sand_is_the_low_coastal_plain(self):
        self.assertTrue(self.soil.sandy((0.0, 300.0)))
        self.assertFalse(self.soil.sandy((0.0, 10.0)), "below the land line")
        self.assertFalse(self.soil.sandy((0.0, 600.0)), "too high and far: inland loam")

    def test_heath_stands_back_from_the_beach(self):
        self.assertFalse(self.soil.heath_ground((0.0, 100.0)), "under HEATH_MIN_H_M: open beach ridge")
        self.assertTrue(self.soil.heath_ground((0.0, 300.0)))

    def test_heath_mix_is_mostly_mature_pine_and_stable(self):
        picks = Counter(vh.heath_species((x * 7.3, y * 5.1)) for x in range(60) for y in range(60))
        self.assertGreater(picks["pine_tall"] / sum(picks.values()), 0.5)
        self.assertEqual(vh.heath_species((12.3, 45.6)), vh.heath_species((12.3, 45.6)))
        self.assertAlmostEqual(sum(w for _, w in vh.HEATH_MIX), 1.0)


class RevalPlanTest(unittest.TestCase):
    """The committed plan obeys the rules (regenerate with build_reval_city_plan.py)."""

    @classmethod
    def setUpClass(cls):
        cls.plan = json.loads(PLAN.read_text())
        mpu = float(cls.plan["metres_per_world_unit"])
        streets = [{"points_m": [(q[0] * mpu, q[1] * mpu) for q in s["points"]], "width_m": s["width"] * mpu} for s in cls.plan["streets"]]
        cls.cl = vh.Clearance(streets, cls.plan["bridges"], mpu)
        cls.mpu = mpu

    def test_no_tree_in_a_bridge_or_on_a_road(self):
        bad = [t for t in self.plan["trees"] if not self.cl.tree_ok((t[0] * self.mpu, t[1] * self.mpu))]
        self.assertEqual(bad, [])

    def test_sandy_coast_carries_a_mature_pine_heath(self):
        species = Counter(t[2] for t in self.plan["trees"])
        self.assertGreater(species["pine_tall"], 300, "a pine bor, not a few lone pines")
        self.assertIn("pine_heath", {w["kind"] for w in self.plan["woods"]})


if __name__ == "__main__":
    unittest.main()
