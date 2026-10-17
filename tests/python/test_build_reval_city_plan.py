"""ADR 0031: the continuous Reval 1343 city plan builder."""
import json
import math
import re
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

    def test_stream_depth_is_deterministic_with_wadeable_margins(self):
        overlay = json.loads(builder.OVERLAY_PATH.read_text())
        chain, pools = builder.stream_pools(overlay)
        self.assertEqual((chain, pools), builder.stream_pools(overlay))
        self.assertEqual({p[0] for p in pools},
                         {"pool.lower_bend", "pool.viru", "pool.tartu"})
        for _, at, _, peak in pools:
            self.assertAlmostEqual(float(builder.stream_depth(0.0, 10.0, at, pools)), peak)
            margin = float(builder.stream_depth(5.0, 10.0, at, pools))
            self.assertLess(margin, 1.05)
            self.assertGreater(margin, 0.12)
        self.assertAlmostEqual(float(builder.stream_depth(0.0, 10.0, 0.0, pools)), 1.05)
        self.assertEqual(float(builder.stream_depth(8.0, 10.0, pools[0][1], pools)), 0.9)

    def test_stream_planting_excludes_wet_banks_not_just_nominal_bed(self):
        # A 10 m bed has submerged banks out to 8 m. Width-only exclusion fails.
        wet = builder.stream_vegetation_exclusion(
            [(0, 0), (0, 100)], [10, 10], [3, 3],
            lambda x, y: 2.0 if abs(x) < 8 else 4.0, 1.0)
        self.assertTrue(wet((0, 50)))
        self.assertTrue(wet((7, 50)))
        self.assertFalse(wet((9, 50)))
        self.assertFalse(wet((50, 50)))

    TIER_KEYS = ("wealth_tier", "age_tier", "upkeep")

    def _tiered_houses(self):
        return [b for b in self.plan["buildings"] if b.get("kind") == "house" and "wealth_tier" in b]

    def test_every_intramural_house_carries_tiers_that_match_its_material(self):
        houses = self._tiered_houses()
        self.assertGreater(len(houses), 300)
        for b in houses:
            self.assertIn(b["wealth_tier"], ("poor", "craft", "merchant", "great"))
            self.assertIn(b["age_tier"], ("new", "settled", "old"))
            self.assertIn(b["upkeep"], ("kept", "worn"))
            if b["material"] == "limestone" and b["roof"] == "tile":
                self.assertNotIn(b["wealth_tier"], ("poor", "craft"), b["id"])
            if b["material"] in ("log", "plank"):
                self.assertIn(b["wealth_tier"], ("poor", "craft"), b["id"])
        for b in self.plan["buildings"]:
            # Landmark houses tagged later (Kalev's smithy) keep their tiers.
            if b.get("landmark_id") and b.get("kind") != "house":
                for k in self.TIER_KEYS:
                    self.assertNotIn(k, b)

    def test_tiers_are_deterministic(self):
        again = builder.build(None)["plan"]
        self.assertEqual(self.plan["buildings"], again["buildings"])

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

    # ---- WB-13c strip plots (R-1413) ----

    def _plot_frame(self, house):
        # Door frame as the builder uses it: t along the street face, n into the plot.
        o, a = house["door"][:2], house["door"][2]
        n = (-math.cos(a), -math.sin(a))
        t = (-n[1], n[0])
        return [(q[0] - o[0]) * t[0] + (q[1] - o[1]) * t[1] for q in house["footprint"]]

    @staticmethod
    def _clip_convex(subject, convex):
        """Area (m2 at mpu 1) of subject clipped to a counter- or clockwise convex quad."""
        sign = 1.0 if builder.poly_area(convex) > 0 else -1.0
        poly = [tuple(p) for p in subject]
        for i in range(len(convex)):
            a, b = convex[i], convex[(i + 1) % len(convex)]
            # inside = left of a->b for a CCW ring
            nx, ny = -(b[1] - a[1]) * sign, (b[0] - a[0]) * sign
            poly = builder.clip_halfplane(poly, nx, ny, nx * a[0] + ny * a[1])
            if len(poly) < 3:
                return 0.0
        return abs(builder.poly_area(poly))

    @staticmethod
    def _bbox(ring):
        return (min(p[0] for p in ring), min(p[1] for p in ring), max(p[0] for p in ring), max(p[1] for p in ring))

    @staticmethod
    def _boxes_meet(a, b):
        return a[0] < b[2] and b[0] < a[2] and a[1] < b[3] and b[1] < a[3]

    def test_plots_are_derived_from_eligible_houses(self):
        plots = self.plan["plots"]
        by_id = {b["id"]: b for b in self.plan["buildings"]}
        self.assertGreater(len(plots), 300)
        self.assertEqual([p["id"] for p in plots], sorted(p["id"] for p in plots))
        self.assertEqual(len({p["id"] for p in plots}), len(plots))
        self.assertEqual(len({p["building"] for p in plots}), len(plots))
        for p in plots:
            b = by_id[p["building"]]
            self.assertEqual(p["id"], "plot." + b["id"].removeprefix("bldg."))
            self.assertEqual(b["kind"], "house")
            self.assertFalse(b["landmark_id"], b["id"])
            self.assertEqual(p["wealth_tier"], b["wealth_tier"])
            self.assertEqual(p["street_id"], b["street_id"])
            self.assertEqual(len(p["polygon"]), 4)
            self.assertIn(len(p["yard"]), (0, 4))
            self.assertLessEqual(p["depth_m"], builder.PLOT_MAX_DEPTH_M + 0.01)
            ts = self._plot_frame(b)
            # Widening stops at the tier target; a wider house keeps its own frontage.
            self.assertLessEqual(p["frontage_m"], max(11.0, max(ts) - min(ts)) + 0.02, p["id"])

    def test_plots_never_overlap_each_other_or_foreign_buildings(self):
        plots = self.plan["plots"]
        boxes = [self._bbox(p["polygon"]) for p in plots]
        bad = []
        for i in range(len(plots)):
            for j in range(i + 1, len(plots)):
                if self._boxes_meet(boxes[i], boxes[j]):
                    area = self._clip_convex(plots[j]["polygon"], plots[i]["polygon"])
                    if area > 0.05:
                        bad.append((plots[i]["id"], plots[j]["id"], round(area, 3)))
        self.assertEqual(bad, [], "overlapping plots")
        for p, box in zip(plots, boxes):
            for b in self.plan["buildings"]:
                # The plot's own house and its own WB-13e service range are not foreign.
                if b["id"] == p["building"] or b.get("plot") == p["id"] or not self._boxes_meet(box, self._bbox(b["footprint"])):
                    continue
                area = self._clip_convex(b["footprint"], p["polygon"])
                if area > 0.05:
                    bad.append((p["id"], b["id"], round(area, 3)))
        self.assertEqual(bad, [], "plots over foreign buildings")

    def test_plots_keep_off_streets_and_inside_the_town(self):
        circuit = [tuple(a["at"]) for a in self.plan["circuit"]]
        toompea = [tuple(q) for q in self.plan["toompea_edge"]]
        segs = []
        for s in self.plan["streets"]:
            # Plan width carries a 1.5 m margin over the street's own width.
            half = (s["width"] - 1.5) / 2
            pts = s["points"]
            segs += [(tuple(pts[k]), tuple(pts[k + 1]), half) for k in range(len(pts) - 1)]
        bad = []
        for p in self.plan["plots"]:
            poly = [tuple(q) for q in p["polygon"]]
            inside = all(builder.pip(q, circuit) for q in poly) or all(builder.pip(q, toompea) for q in poly)
            if not inside:
                bad.append((p["id"], "outside"))
            box = self._bbox(poly)
            for a, b, half in segs:
                if max(a[0], b[0]) < box[0] - 20 or min(a[0], b[0]) > box[2] + 20:
                    continue
                if max(a[1], b[1]) < box[1] - 20 or min(a[1], b[1]) > box[3] + 20:
                    continue
                if self._seg_poly_distance(a, b, poly) < half - 0.01:
                    bad.append((p["id"], "street"))
                    break
        self.assertEqual(bad, [])

    def _seg_poly_distance(self, a, b, poly):
        n = len(poly)
        for i in range(n):
            if builder.seg_intersection(a, b, poly[i], poly[(i + 1) % n]) is not None:
                return 0.0
        if builder.pip(a, poly):
            return 0.0

        def ps(p, u, v):
            dx, dy = v[0] - u[0], v[1] - u[1]
            t = max(0.0, min(1.0, ((p[0] - u[0]) * dx + (p[1] - u[1]) * dy) / max(dx * dx + dy * dy, 1e-12)))
            return math.dist(p, (u[0] + dx * t, u[1] + dy * t))

        d = min(ps(q, a, b) for q in poly)
        return min([d] + [ps(e, poly[i], poly[(i + 1) % n]) for e in (a, b) for i in range(n)])

    def test_plot_frontage_follows_the_h04_band(self):
        plots = self.plan["plots"]
        by_id = {b["id"]: b for b in self.plan["buildings"]}

        def hist(values, step):
            buckets = {}
            for v in values:
                k = int(v // step) * step
                buckets[k] = buckets.get(k, 0) + 1
            return " ".join("%d:%d" % kv for kv in sorted(buckets.items()))

        front = [p["frontage_m"] for p in plots]
        yard = [abs(builder.poly_area(p["yard"])) if p["yard"] else 0.0 for p in plots]
        print("\nWB-13c plots %d, frontage m (2 m bins) %s" % (len(plots), hist(front, 2)))
        print("WB-13c yard m2 (25 m2 bins) %s; empty %d" % (hist(yard, 25), sum(1 for y in yard if not y)))
        # Houses no wider than the band are widened toward it (H04 7-11 m);
        # wider OSM footprints (merged modern blocks) keep their own frontage.
        narrow = sorted(p["frontage_m"] for p in plots
                        if (lambda ts: max(ts) - min(ts))(self._plot_frame(by_id[p["building"]])) <= 11.0)
        self.assertGreater(len(narrow), 60)
        median = narrow[len(narrow) // 2]
        self.assertGreaterEqual(median, 7.0)
        self.assertLessEqual(median, 11.0)
        self.assertGreater(sum(1 for p in plots if p["yard"]), 100, "deep plots open into rear yards")

    # ---- WB-13d plot walls and gates (R-1414) ----

    def _walled(self):
        return [p for p in self.plan["plots"] if p["yard"]]

    @staticmethod
    def _run_samples(run, step=0.1):
        out = []
        for a, b in zip(run, run[1:]):
            n = max(1, int(math.ceil(math.dist(a, b) / step)))
            out += [(a[0] + (b[0] - a[0]) * k / n, a[1] + (b[1] - a[1]) * k / n) for k in range(n)]
        out.append(tuple(run[-1]))
        return out

    def test_every_yard_has_one_wall_record_with_a_gate_or_house_access(self):
        plots = self._walled()
        self.assertGreater(len(plots), 100)
        through = 0
        for p in plots:
            w = p["wall"]
            self.assertIn(w["kind"], ("wattle", "plank", "stone"))
            self.assertGreaterEqual(w["height_m"], 1.4)
            self.assertLessEqual(w["height_m"], 2.2)
            self.assertTrue(w["runs"], p["id"])
            if w["gate"] is None:
                through += 1
                self.assertEqual(w["access"], "through_house")
            else:
                self.assertEqual(w["access"], "gate")
                self.assertIn(w["gate"]["via"], ("street", "passage"))
                self.assertGreaterEqual(w["gate"]["width"], 1.4)
                self.assertLessEqual(w["gate"]["width"], 2.4)
        for p in self.plan["plots"]:
            if not p["yard"]:
                self.assertIsNone(p["wall"])
        print("\nWB-13d yards %d, gate %d, through_house %d" % (len(plots), len(plots) - through, through))

    def test_gates_open_on_a_street_corridor_or_a_passage_to_one(self):
        segs = []
        for s in self.plan["streets"]:
            # The corridor the plot pass uses: half the plan width plus its 0.25 m margin.
            half = s["width"] / 2 + 0.25
            pts = s["points"]
            segs += [(pts[k], pts[k + 1], half) for k in range(len(pts) - 1)]

        def corridor_gap(q):
            best = 1e9
            for a, b, half in segs:
                if min(a[0], b[0]) - 60 > q[0] or max(a[0], b[0]) + 60 < q[0]:
                    continue
                best = min(best, self._seg_poly_distance(q, q, [(a[0], a[1]), (b[0], b[1]), (b[0], b[1])]) - half)
            return best

        by_id = {p["id"]: p for p in self.plan["plots"]}
        for p in self._walled():
            g = p["wall"]["gate"]
            if g is None:
                continue
            target = g["at"] if g["via"] == "street" else g["mouth"]
            self.assertLessEqual(corridor_gap(target), 0.5 + 0.01, p["id"])
            if g["via"] == "passage":
                mid = [(g["at"][0] + g["mouth"][0]) / 2, (g["at"][1] + g["mouth"][1]) / 2]
                self.assertTrue(builder.pip(mid, [tuple(q) for q in by_id[p["id"]]["polygon"]]), p["id"])

    def test_plot_walls_keep_clear_of_foreign_footprints_and_share_boundaries_once(self):
        houses = self.plan["buildings"]
        walled = self._walled()
        owned = []
        for p in walled:
            pts = [q for run in p["wall"]["runs"] for q in self._run_samples(run)]
            owned.append((p["id"], pts))
            box = self._bbox(pts)
            for b in houses:
                if b["id"] == p["building"] or not self._boxes_meet(box, self._bbox(b["footprint"])):
                    continue
                ring = [tuple(q) for q in b["footprint"]]
                for q in pts:
                    if builder.pip(q, ring):
                        self.fail((p["id"], b["id"], "wall inside footprint"))
                    d = min(self._seg_poly_distance(q, q, [ring[i], ring[(i + 1) % len(ring)], ring[(i + 1) % len(ring)]])
                            for i in range(len(ring)))
                    self.assertGreaterEqual(d, 0.3 - 1e-6, (p["id"], b["id"]))
        grid = {}
        for pid, pts in owned:
            for q in pts:
                grid.setdefault((int(q[0] // 0.2), int(q[1] // 0.2)), []).append((pid, q))
        for pid, pts in owned:
            for q in pts:
                cx, cy = int(q[0] // 0.2), int(q[1] // 0.2)
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        for other, r in grid.get((cx + dx, cy + dy), ()):
                            if other != pid:
                                self.assertGreater(math.dist(q, r), 0.1, (pid, other, "boundary walled twice"))
        by_id = {p["id"]: p for p in walled}
        for p in walled:
            for other in p["wall"]["shared_with"]:
                self.assertIn(p["id"], by_id[other]["wall"]["shared_with"])

    def test_wall_kind_follows_the_tier_ladder(self):
        allowed = {"poor": {"wattle"}, "craft": {"wattle", "plank"}, "merchant": {"plank", "stone"}, "great": {"stone"}}
        for p in self._walled():
            self.assertIn(p["wall"]["kind"], allowed[p["wealth_tier"]], p["id"])

    # ---- WB-13e rear service ranges (R-1415) ----

    def _service(self):
        return [b for b in self.plan["buildings"] if b.get("plot")]

    @staticmethod
    def _ring_gap(a, b):
        """Smallest distance between two closed rings (0 when they cross or nest)."""
        def edges(r):
            return [(r[i], r[(i + 1) % len(r)]) for i in range(len(r))]
        if any(builder.pip(q, b) for q in a) or any(builder.pip(q, a) for q in b):
            return 0.0
        best = 1e9
        for p, q in edges(a):
            for s, t in edges(b):
                for x, (u, v) in ((p, (s, t)), (q, (s, t)), (s, (p, q)), (t, (p, q))):
                    d, _ = builder.dist_point_seg(x[0], x[1], u[0], u[1], v[0], v[1])
                    best = min(best, float(d))
        return best

    def test_service_ranges_stand_inside_deep_yards_clear_of_house_walls_and_gate(self):
        service = self._service()
        self.assertGreater(len(service), 30, "deep yards carry rear service buildings")
        plots = {p["id"]: p for p in self.plan["plots"]}
        by_id = {b["id"]: b for b in self.plan["buildings"]}
        for b in service:
            p = plots[b["plot"]]
            ring = [tuple(q) for q in b["footprint"]]
            yard = [tuple(q) for q in p["yard"]]
            self.assertGreaterEqual(math.dist(yard[0], yard[3]) * self.mpu, 14.0 - 1e-6, b["id"])
            for q in ring:
                self.assertTrue(builder.pip(q, yard), (b["id"], "outside its yard"))
            house = [tuple(q) for q in by_id[p["building"]]["footprint"]]
            self.assertGreaterEqual(self._ring_gap(ring, house) * self.mpu, 3.0 - 0.01, (b["id"], "house"))
            for run in p["wall"]["runs"]:
                for q in self._run_samples(run):
                    d = min(float(builder.dist_point_seg(q[0], q[1], ring[k][0], ring[k][1], ring[(k + 1) % 4][0], ring[(k + 1) % 4][1])[0])
                            for k in range(4))
                    self.assertGreaterEqual(d * self.mpu, 0.3, (b["id"], "wall"))
            g = p["wall"]["gate"]
            if g:
                gap = min(float(builder.dist_point_seg(g["at"][0], g["at"][1], ring[k][0], ring[k][1], ring[(k + 1) % 4][0], ring[(k + 1) % 4][1])[0])
                          for k in range(4))
                self.assertFalse(builder.pip(tuple(g["at"]), ring), b["id"])
                self.assertGreaterEqual(gap, g["width"] / 2 + 1.5 - 0.01, (b["id"], "gate line"))
            self.assertFalse(b["enterable"])
            self.assertIsNotNone(b["door"])

    def test_service_ranges_keep_off_every_other_building_and_trees(self):
        service = self._service()
        others = self.plan["buildings"]
        for b in service:
            ring = [tuple(q) for q in b["footprint"]]
            box = self._bbox(ring)
            for o in others:
                if o["id"] == b["id"] or not self._boxes_meet(box, self._bbox(o["footprint"])):
                    continue
                self.assertGreater(self._ring_gap(ring, [tuple(q) for q in o["footprint"]]), 0.5, (b["id"], o["id"]))
            for t in self.plan["trees"]:
                if box[0] - 3 < t[0] < box[2] + 3 and box[1] - 3 < t[1] < box[3] + 3:
                    self.assertFalse(builder.pip((t[0], t[1]), ring), (b["id"], "tree inside"))

    def test_service_types_follow_the_tier_ladder_and_reject_list(self):
        allowed = {"poor": {"aux_dwelling"}, "craft": {"workshop", "aux_dwelling", "store"},
                   "merchant": {"store"}, "great": {"store", "kitchen_shed"}}
        tiers = {p["id"]: p["wealth_tier"] for p in self.plan["plots"]}
        share = {}
        for b in self._service():
            tier = tiers[b["plot"]]
            self.assertIn(b["type"], allowed[tier], b["id"])
            self.assertNotIn(b["type"], builder.PLOT_SERVICE_REJECT)
            self.assertRegex(b["id"], r"^bldg\.%s\.[a-z]+\d$" % re.escape(b["plot"].removeprefix("plot.")))
            share.setdefault(tier, {}).setdefault(b["type"], 0)
            share[tier][b["type"]] += 1
        ids = [b["id"] for b in self.plan["buildings"]]
        self.assertEqual(len(ids), len(set(ids)))
        # Appended after every other building, so no earlier index or ID moves.
        first = min(i for i, b in enumerate(self.plan["buildings"]) if b.get("plot"))
        self.assertTrue(all(b.get("plot") for b in self.plan["buildings"][first:]))
        print("\nWB-13e service ranges by tier %s" % json.dumps(share, sort_keys=True))

    def test_plots_ignore_input_order_and_leave_buildings_untouched(self):
        import copy
        import random
        rng = random.Random(1343)
        buildings = copy.deepcopy(self.plan["buildings"])
        obstacles = list(self.result["plot_obstacles"])
        rng.shuffle(buildings)
        rng.shuffle(obstacles)
        before = copy.deepcopy(buildings)
        self.assertEqual(builder.burgher_plots(buildings, obstacles, self.mpu), self.plan["plots"])
        self.assertEqual(buildings, before)


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
