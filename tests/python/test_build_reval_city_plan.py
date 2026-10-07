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
        for later in ("Margaret", "Kiek", "Neitsi", "Hermann", "Epping", "Loewenschede"):
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


if __name__ == "__main__":
    unittest.main()
