"""ADR 0031: the continuous Reval 1343 city plan builder."""
import json
import math
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "city"))

import build_reval_city_plan as builder  # noqa: E402


class CityPlanBuilderTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.result = builder.build(None)
        cls.plan = cls.result["plan"]
        cls.mpu = cls.plan["metres_per_world_unit"]

    def test_committed_outputs_are_current(self):
        # Same inputs, same bytes: the committed plan is what the builder makes.
        self.assertEqual(builder.write_outputs(self.result, check=True), 0)

    def test_every_gate_sits_on_the_wall_and_its_street(self):
        anchors = {a["ref"]: a["at"] for a in self.plan["circuit"] if a["ref"]}
        for gate in self.plan["gates"]:
            self.assertIn(gate["id"], anchors)
            self.assertEqual(gate["at"], anchors[gate["id"]])

    def test_nuns_gate_road_runs_straight_through_the_passage(self):
        # The Nunne road used to end slanted against the wall beside the gate.
        gate = next(g for g in self.plan["gates"] if g["id"] == "gate.nuns")
        passage = (-math.sin(gate["angle"]), math.cos(gate["angle"]))
        street = next(s for s in self.plan["streets"] if s["name"] == "Nunne")
        pts = street["points"]
        k = next(i for i, p in enumerate(pts) if p == gate["at"])
        self.assertGreater(k, 0)
        self.assertLess(k, len(pts) - 1)
        for a, b in ((pts[k - 1], pts[k]), (pts[k], pts[k + 1])):
            d = (b[0] - a[0], b[1] - a[1])
            n = math.hypot(*d)
            self.assertGreater(abs(d[0] * passage[0] + d[1] * passage[1]) / n, 0.99)

    def test_streets_cross_the_curtain_only_at_gates(self):
        gates = [tuple(g["at"]) for g in self.plan["gates"]]
        curtains = self.plan["curtains"]
        crossings = []
        for s in self.plan["streets"]:
            pts = s["points"]
            for k in range(len(pts) - 1):
                for c in curtains:
                    q = builder.seg_intersection(tuple(c["from"]), tuple(c["to"]), tuple(pts[k]), tuple(pts[k + 1]))
                    if q is None:
                        continue
                    near_gate = min(math.dist(q, g) for g in gates) * self.mpu
                    if near_gate > 12.0:
                        crossings.append((s["name"] or s["id"], round(q[0] * self.mpu), round(q[1] * self.mpu)))
        self.assertEqual(crossings, [], "streets breaching the 1343 curtain away from a gate")

    def test_post_1343_fortifications_are_absent(self):
        names = " ".join(t["name"] for t in self.plan["towers"])
        # Towers up to ~50 years late are shown on purpose (maintainer direction 2026-10-08).
        for later in ("Margaret", "Kiek", "Hermann"):
            self.assertNotIn(later, names)
        states = {g["id"]: g["state"] for g in self.plan["gates"]}
        self.assertEqual(states["gate.long_hill"], "wooden")
        self.assertEqual(states["gate.viru"], "unfinished")

    def test_buildings_have_doors_on_their_footprint(self):
        for b in self.plan["buildings"]:
            if not b["enterable"]:
                continue
            ring = b["footprint"]
            door = b["door"]
            d = min(
                float(builder.dist_point_seg(
                    builder.np.array([door[0]]), builder.np.array([door[1]]),
                    ring[i][0], ring[i][1], ring[(i + 1) % len(ring)][0], ring[(i + 1) % len(ring)][1])[0][0])
                for i in range(len(ring))
            )
            self.assertLess(d, 0.05, b["id"])

    def test_toompea_relief(self):
        h = self.result["height_wu"]
        x0, y0 = self.plan["height_grid"]["origin"]
        cell = self.plan["height_grid"]["cell"]

        def at(xm, ym):
            return h[int(round((ym / self.mpu - y0) / cell)), int(round((xm / self.mpu - x0) / cell))] * self.mpu

        lift = at(-370, 175) - at(5, -10)
        self.assertGreater(lift, 18.0)
        self.assertLess(lift, 30.0)



class TerrainReliefTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        import terrain_relief
        cls.relief = terrain_relief

    def test_lattice_noise_is_deterministic_and_bounded(self):
        import numpy as np
        x, y = np.meshgrid(np.linspace(-500, 500, 64), np.linspace(-500, 500, 64))
        a = self.relief.lattice_noise(x, y, 110.0, 5)
        b = self.relief.lattice_noise(x, y, 110.0, 5)
        self.assertTrue((a == b).all())
        self.assertGreaterEqual(a.min(), 0.0)
        self.assertLessEqual(a.max(), 1.0)

    def test_relief_leaves_masked_ground_untouched(self):
        import numpy as np
        x, y = np.meshgrid(np.linspace(0, 400, 80), np.linspace(0, 400, 80))
        asl = np.full(x.shape, 10.0)
        weight = np.zeros(x.shape)
        weight[:, 40:] = 1.0
        out = self.relief.add_open_country_relief(asl, x, y, weight, np.full(x.shape, 500.0), np.zeros(x.shape))
        self.assertTrue((out[:, :40] == 10.0).all())
        self.assertGreater(float(out[:, 40:].std()), 0.3)

    def test_hollow_way_sinks_the_track_and_heaps_berms(self):
        import numpy as np
        import build_reval_city_plan as b
        x, y = np.meshgrid(np.linspace(-20, 20, 81), np.linspace(-10, 10, 41))
        road = [((-30.0, 0.0), (30.0, 0.0))]
        out, road_w = self.relief.carve_hollow_ways(
            np.zeros(x.shape), x, y, [([(-30.0, 0.0), (30.0, 0.0)], 5.0)], np.full(x.shape, 500.0), b.dist_point_seg
        )
        centre = out[20, 40]
        self.assertAlmostEqual(centre, -self.relief.HOLLOW_DEPTH_M, delta=0.03)
        self.assertGreater(float(out.max()), 0.05, "spoil berm beside the road")
        self.assertGreater(road_w[20, 40], 0.9)

    def test_road_map_encodes_lateral_offset(self):
        import numpy as np
        arr = self.relief.road_map(40, 40, (0.0, 0.0), 1.0, [("road.test", [(5.0, 20.0), (35.0, 20.0)], 6.0)], 1.0)
        centre = arr[20, 20]
        side = arr[24, 20]
        other = arr[16, 20]
        self.assertGreater(int(centre[0]), 200)
        self.assertLess(abs(int(centre[1]) - 128), 20)
        self.assertNotEqual(np.sign(int(side[1]) - 128), np.sign(int(other[1]) - 128))
        self.assertEqual(int(arr[2, 2][0]), 0)


if __name__ == "__main__":
    unittest.main()
