"""Where trees and shrubs may root on the generated Reval plan (R-1617).

Two rule sets, both pure functions of the plan geometry so the plan stays
deterministic:

* Clearance: nothing roots on a carriageway, and no crown grows through a
  bridge or harbour deck. The planting loops only reserve coarse 6 m cells
  along street centrelines, which let bank alders and open-country trees stand
  on a road verge and push their crowns through the Hareapea and moat bridges.
  This filter runs once, after every placement, so it never changes the seeded
  RNG sequences that name fields, pastures and woods.
* Soil: the low coastal plain is Litorina-sea sand (the strip running east
  toward Kadriorg and Pirita). Woods and lone trees there are pine heath, with
  mature Scots pines (`pine_tall`) far above a person; the inland loam keeps the
  mixed spruce, oak and birch woods.
"""

from __future__ import annotations

import math

import numpy as np

# Trunk this far beyond the carriageway edge (a crown may overhang a verge).
TREE_ROAD_EDGE_M = 2.0
# Shrubs already keep the busy-street verges bare in shrubs(); bridges only.
# A deck plus this margin: about the crown radius of a 10 m tree.
TREE_BRIDGE_CLEAR_M = 5.0
BUSH_BRIDGE_CLEAR_M = 1.5

# Sandy coastal plain: within this distance of the 1343 shoreline and at most
# this high above the 1343 sea. The beach strand itself (closer than
# HEATH_MIN_SHORE_M, or under HEATH_MIN_H_M) stays bare sand and juniper.
SAND_SHORE_M = 420.0
SAND_MAX_H_M = 10.0
HEATH_MIN_SHORE_M = 45.0
HEATH_MIN_H_M = 3.0

# Pine heath mix: mostly mature pines, some younger ones, birch at gaps and a
# juniper understorey. Weights must sum to 1.
HEATH_MIX = (("pine_tall", 0.62), ("pine", 0.18), ("birch", 0.08), ("juniper", 0.12))


def _hash01(x: float, y: float, salt: int) -> float:
    """Stable 0..1 hash of a position (no RNG draw, so no sequence shifts)."""
    h = (int(round(x * 10)) * 374761393 + int(round(y * 10)) * 668265263 + salt * 2147483647) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0


def heath_species(p, salt: int = 1617) -> str:
    u = _hash01(p[0], p[1], salt)
    acc = 0.0
    for species, weight in HEATH_MIX:
        acc += weight
        if u < acc:
            return species
    return HEATH_MIX[-1][0]


class Soil:
    """Sandy coastal plain vs inland ground, from shore distance and height."""

    def __init__(self, shoreline_m, h_at_m):
        pts = np.array(shoreline_m, dtype=float)
        self._a = pts[:-1]
        self._ab = pts[1:] - pts[:-1]
        self._len2 = np.maximum((self._ab ** 2).sum(axis=1), 1e-9)
        self._h = h_at_m

    def shore_distance(self, p) -> float:
        d = np.array(p, dtype=float) - self._a
        t = np.clip((d * self._ab).sum(axis=1) / self._len2, 0.0, 1.0)
        q = self._a + self._ab * t[:, None]
        return float(np.min(np.hypot(q[:, 0] - p[0], q[:, 1] - p[1])))

    def sandy(self, p) -> bool:
        h = self._h(*p)
        return 0.6 <= h <= SAND_MAX_H_M and self.shore_distance(p) <= SAND_SHORE_M

    def heath_ground(self, p) -> bool:
        """Sandy ground back from the beach, where a pine bor can stand."""
        return self.sandy(p) and self._h(*p) >= HEATH_MIN_H_M and self.shore_distance(p) >= HEATH_MIN_SHORE_M


class Clearance:
    """Keeps trunks off roads and crowns out of bridge decks.

    streets: plan street records with `points_m` and `width_m` (metres).
    bridges: plan bridge records (`at`, `angle`, `length`, `width` in world units).
    """

    def __init__(self, streets, bridges, mpu: float):
        segs = []
        for s in streets:
            pts = s["points_m"]
            half = float(s.get("width_m", 5.0)) * 0.5
            for a, b in zip(pts[:-1], pts[1:]):
                segs.append((a[0], a[1], b[0], b[1], half))
        self._segs = np.array(segs, dtype=float) if segs else np.zeros((0, 5))
        self._bridges = [
            (
                float(b["at"][0]) * mpu,
                float(b["at"][1]) * mpu,
                float(b["angle"]),
                float(b["length"]) * mpu * 0.5,
                float(b["width"]) * mpu * 0.5,
            )
            for b in bridges
        ]

    def road_edge_distance(self, p) -> float:
        """Distance from p to the nearest carriageway edge (negative on the road)."""
        if not len(self._segs):
            return math.inf
        s = self._segs
        abx, aby = s[:, 2] - s[:, 0], s[:, 3] - s[:, 1]
        t = np.clip(((p[0] - s[:, 0]) * abx + (p[1] - s[:, 1]) * aby) / np.maximum(abx * abx + aby * aby, 1e-9), 0.0, 1.0)
        d = np.hypot(s[:, 0] + abx * t - p[0], s[:, 1] + aby * t - p[1]) - s[:, 4]
        return float(d.min())

    def bridge_distance(self, p) -> float:
        """Distance from p to the nearest bridge or deck rectangle (0 on a deck)."""
        best = math.inf
        for cx, cy, ang, half_l, half_w in self._bridges:
            c, s_ = math.cos(ang), math.sin(ang)
            dx, dy = p[0] - cx, p[1] - cy
            u = abs(dx * c + dy * s_) - half_l
            v = abs(-dx * s_ + dy * c) - half_w
            best = min(best, math.hypot(max(u, 0.0), max(v, 0.0)))
        return best

    def tree_ok(self, p) -> bool:
        return self.bridge_distance(p) > TREE_BRIDGE_CLEAR_M and self.road_edge_distance(p) > TREE_ROAD_EDGE_M

    def bush_ok(self, p) -> bool:
        return self.bridge_distance(p) > BUSH_BRIDGE_CLEAR_M
