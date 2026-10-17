#!/usr/bin/env python3
"""Build the continuous Reval 1343 city plan (ADR 0031).

Inputs (all committed):
  tools/city/data/osm_reval_extract.json   trimmed OpenStreetMap extract (ODbL)
  tools/city/data/eudem25m_reval.json      EU-DEM 25 m surface samples (Copernicus)
  tools/city/reval_1343_overlay.json       hand-authored 1343 corrections
  docs/data/reval_street_register.json     1343 street register (R-1111)

Outputs (runtime, consumed by scripts/city/):
  content/world/reval_city/plan.json       vector plan in world units (x east, z south)
  content/world/reval_city/height.json     uint16 heightfield, base64 (centimetres + offset)
  content/world/reval_city/splat.png       RGBA ground-surface weights, 1 px per world unit
  docs/reports/images/city/reval_city_plan.png   review render

Usage:
  python3 tools/city/build_reval_city_plan.py            # rebuild everything
  python3 tools/city/build_reval_city_plan.py --check    # fail if outputs are stale
  python3 tools/city/build_reval_city_plan.py --site paide [--check]   # a regional site (ADR 0042)
  python3 tools/city/build_reval_city_plan.py --import-osm build/city_osm/raw.json --import-dem build/city_osm/dem.json

Everything is deterministic: same inputs, same bytes.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import io
import json
import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import terrain_relief  # noqa: E402
import vegetation_habitat  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "tools/city/data"
OSM_PATH = DATA / "osm_reval_extract.json"
DEM_PATH = DATA / "eudem25m_reval.json"
OVERLAY_PATH = ROOT / "tools/city/reval_1343_overlay.json"
REGISTER_PATH = ROOT / "docs/data/reval_street_register.json"
OUT_DIR = ROOT / "content/world/reval_city"
REVIEW_PNG = ROOT / "docs/reports/images/city/reval_city_plan.png"

SCHEMA = "rr.city_plan.v1"
HEIGHT_CELL_WU = 2.0  # heightfield spacing in world units
HEIGHT_OFFSET_CM = 2000  # stored = round(height_wu * 100) + offset
SPLAT_PX_PER_WU = 1.0
# Mud-channel value (of 255) that marks tilled field soil in splat.png; keep in sync
# with FIELD_MUD_* in scripts/city/city_ground.gdshader and CityGrass.field_share.
FIELD_MUD_LEVEL = 110

# Shallow margins stay wadeable; local pools clear the 1.25 m swim threshold
# even after the 2 m height grid is quantised and bilinearly sampled.
STREAM_MARGIN_DEPTH_M = 0.9
STREAM_THALWEG_DEPTH_M = 1.05


def stream_pools(overlay):
    """Deterministic chainage-based scour pools, not attested 1343 bathymetry."""
    trace = overlay["harjapea"]["trace_m"]
    chain = [0.0]
    for a, b in zip(trace, trace[1:]):
        chain.append(chain[-1] + math.dist(a, b))
    # The lower bend is where the stream swings furthest west below the Viru road;
    # keyed to that vertex, not to the end of the trace, so extending the reach to
    # the mouth does not move the pool.
    bend = min(range(len(trace)), key=lambda i: trace[i][0])
    pools = [("pool.lower_bend", chain[bend] - 16.0, 28.0, 1.8)]
    for road in overlay["streets"]["extramural_roads"]:
        if road["id"] not in ("road.viru", "road.tartu"):
            continue
        for a, b in zip(road["points_m"], road["points_m"][1:]):
            for i, (c, d) in enumerate(zip(trace, trace[1:])):
                q = seg_intersection(a, b, c, d)
                if q is not None:
                    # 18 m downstream keeps swimming clear of the walkable deck.
                    pools.append(("pool." + road["id"].split(".")[1],
                                  chain[i] + math.dist(c, q) + 18.0, 32.0, 2.0))
    return chain, pools


def stream_depth(distance, width, chainage, pools):
    """Smooth lateral thalweg and compact longitudinal pools; no bank steps."""
    centre = np.full_like(np.asarray(chainage, dtype=float), STREAM_THALWEG_DEPTH_M)
    for _, at, radius, depth in pools:
        t = np.clip(1.0 - np.abs(chainage - at) / radius, 0.0, 1.0)
        centre = np.maximum(centre, STREAM_THALWEG_DEPTH_M +
                            (depth - STREAM_THALWEG_DEPTH_M) * t * t * (3.0 - 2.0 * t))
    t = np.clip(1.0 - (distance / (width * 0.5)) ** 2, 0.0, 1.0)
    lateral = t * t * (3.0 - 2.0 * t)
    return STREAM_MARGIN_DEPTH_M + (centre - STREAM_MARGIN_DEPTH_M) * lateral


def stream_vegetation_exclusion(trace, widths, levels, h_at_m, mpu):
    """Reject the wet banks as well as the bed, using final terrain and levels.

    The 14 m carved bank envelope bounds the query; the waterline, not the
    nominal bed width, decides. Check serialized positions with the runtime's
    0.25-unit clearance plus height quantisation tolerance.
    """
    def wet(p):
        px, py = (round(v / mpu, 2) * mpu for v in p)
        for i, (a, b) in enumerate(zip(trace, trace[1:])):
            dx, dy = b[0] - a[0], b[1] - a[1]
            t = min(max(((px - a[0]) * dx + (py - a[1]) * dy) / (dx * dx + dy * dy), 0), 1)
            half = (widths[i] + (widths[i + 1] - widths[i]) * t) * 0.5
            if math.hypot(px - a[0] - dx * t, py - a[1] - dy * t) > half + 14.0:
                continue
            surface = levels[i] + (levels[i + 1] - levels[i]) * t
            if h_at_m(px, py) < surface + 0.26:
                return True
        return False
    return wet


# ---------------------------------------------------------------------------
# small geometry kit
# ---------------------------------------------------------------------------


def dist_point_seg(px, py, ax, ay, bx, by):
    """Vectorised distance from points (px, py) to segment a-b; also returns t."""
    dx, dy = bx - ax, by - ay
    ll = dx * dx + dy * dy
    if ll < 1e-12:
        return np.hypot(px - ax, py - ay), np.zeros_like(px)
    t = np.clip(((px - ax) * dx + (py - ay) * dy) / ll, 0.0, 1.0)
    return np.hypot(px - (ax + t * dx), py - (ay + t * dy)), t


def smoothstep01(x, a, b):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def point_in_poly(px, py, poly):
    """Vectorised even-odd test; poly is a list of (x, y)."""
    inside = np.zeros(np.shape(px), dtype=bool)
    n = len(poly)
    for i in range(n):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % n]
        cond = (y1 > py) != (y2 > py)
        with np.errstate(divide="ignore", invalid="ignore"):
            xint = (x2 - x1) * (py - y1) / (y2 - y1 + 1e-12) + x1
        inside ^= cond & (px < xint)
    return inside


def pip(p, poly):
    return bool(point_in_poly(np.array([p[0]]), np.array([p[1]]), poly)[0])


def poly_area(poly):
    a = 0.0
    for i in range(len(poly)):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % len(poly)]
        a += x1 * y2 - x2 * y1
    return a / 2.0


def poly_centroid(poly):
    a = poly_area(poly)
    if abs(a) < 1e-9:
        xs = [p[0] for p in poly]
        ys = [p[1] for p in poly]
        return (sum(xs) / len(xs), sum(ys) / len(ys))
    cx = cy = 0.0
    for i in range(len(poly)):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % len(poly)]
        c = x1 * y2 - x2 * y1
        cx += (x1 + x2) * c
        cy += (y1 + y2) * c
    return (cx / (6 * a), cy / (6 * a))


def rdp(points, eps):
    if len(points) < 3:
        return list(points)
    a, b = np.array(points[0]), np.array(points[-1])
    best, idx = -1.0, 0
    for i in range(1, len(points) - 1):
        p = np.array(points[i])
        ab = b - a
        if np.dot(ab, ab) < 1e-12:
            d = np.linalg.norm(p - a)
        else:
            t = np.clip(np.dot(p - a, ab) / np.dot(ab, ab), 0, 1)
            d = np.linalg.norm(p - (a + t * ab))
        if d > best:
            best, idx = d, i
    if best > eps:
        return rdp(points[: idx + 1], eps)[:-1] + rdp(points[idx:], eps)
    return [points[0], points[-1]]


def simplify_ring(poly, eps):
    if len(poly) < 4:
        return poly
    ring = rdp(poly + [poly[0]], eps)[:-1]
    return ring if len(ring) >= 3 else poly


def polyline_length(pts):
    return sum(math.dist(pts[i], pts[i + 1]) for i in range(len(pts) - 1))


def resample(pts, step):
    out = [pts[0]]
    carry = 0.0
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        seg = math.dist(a, b)
        d = step - carry
        while d <= seg:
            t = d / seg
            out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
            d += step
        carry = seg - (d - step)
    if math.dist(out[-1], pts[-1]) > 1e-6:
        out.append(pts[-1])
    return out


def convex_hull(points):
    pts = sorted(set(points))
    if len(pts) <= 2:
        return pts

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def min_area_rect(poly):
    """Returns (angle, length_along_angle, width) of the minimum-area enclosing rectangle."""
    hull = convex_hull([tuple(p) for p in poly])
    best = None
    for i in range(len(hull)):
        a, b = hull[i], hull[(i + 1) % len(hull)]
        ang = math.atan2(b[1] - a[1], b[0] - a[0])
        c, s = math.cos(-ang), math.sin(-ang)
        xs = [p[0] * c - p[1] * s for p in hull]
        ys = [p[0] * s + p[1] * c for p in hull]
        w, h = max(xs) - min(xs), max(ys) - min(ys)
        if best is None or w * h < best[0]:
            best = (w * h, ang, w, h)
    _, ang, w, h = best
    if h > w:
        ang += math.pi / 2
        w, h = h, w
    return ang, w, h


# ---------------------------------------------------------------------------
# inputs
# ---------------------------------------------------------------------------


class Frame:
    def __init__(self, origin, mpu):
        self.lat0 = origin["lat"]
        self.lon0 = origin["lon"]
        self.kx = math.cos(math.radians(self.lat0)) * 111320.0
        self.ky = 110574.0
        self.mpu = mpu

    def m(self, lat, lon):
        return ((lon - self.lon0) * self.kx, -(lat - self.lat0) * self.ky)

    def latlon(self, x, y):
        return (self.lat0 - y / self.ky, self.lon0 + x / self.kx)


def import_osm(raw_path: Path, out_path: Path = OSM_PATH, source="Overpass API extract, bbox 59.4290,24.7200,59.4470,24.7700",
               natural=("cliff", "coastline", "water")) -> None:
    """Trim a raw Overpass dump to what the builder needs (keeps the ODbL notice).
    Regional sites (build_site_plan.py) pass their own output, source note and
    the wider land-cover set they keep."""
    raw = json.loads(raw_path.read_text())
    keep_ways, keep_rels, need_nodes = [], [], set()
    for e in raw["elements"]:
        t = e.get("tags", {})
        if e["type"] == "way":
            useful = (
                ("highway" in t and t.get("highway") not in ("cycleway", "elevator", "corridor", "platform", "busway", "proposed", "construction"))
                or "building" in t
                or t.get("natural") in natural
                or t.get("barrier") == "city_wall"
                or t.get("historic") in ("city_wall", "citywalls")
            )
            if useful:
                keep_ways.append({"id": e["id"], "nodes": e["nodes"], "tags": {k: v for k, v in t.items() if k in ("highway", "building", "name", "natural", "barrier", "historic", "building:levels", "area", "tower:type", "amenity")}})
        elif e["type"] == "relation" and ("building" in t or t.get("historic")):
            keep_rels.append({"id": e["id"], "members": [m for m in e["members"] if m["type"] == "way"], "tags": {k: v for k, v in t.items() if k in ("building", "name", "historic", "tower:type")}})
    member_ways = {m["ref"] for r in keep_rels for m in r["members"]}
    way_ids = {w["id"] for w in keep_ways}
    for e in raw["elements"]:
        if e["type"] == "way" and e["id"] in member_ways and e["id"] not in way_ids:
            keep_ways.append({"id": e["id"], "nodes": e["nodes"], "tags": {}})
    for w in keep_ways:
        need_nodes.update(w["nodes"])
    nodes = {e["id"]: [round(e["lat"], 7), round(e["lon"], 7)] for e in raw["elements"] if e["type"] == "node" and e["id"] in need_nodes}
    out = {
        "license": "ODbL 1.0, (c) OpenStreetMap contributors, https://www.openstreetmap.org/copyright",
        "source": source,
        "timestamp_osm_base": raw.get("osm3s", {}).get("timestamp_osm_base", ""),
        "nodes": {str(k): v for k, v in sorted(nodes.items())},
        "ways": sorted(keep_ways, key=lambda w: w["id"]),
        "relations": sorted(keep_rels, key=lambda r: r["id"]),
    }
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")))
    print(f"OSM extract: {len(out['ways'])} ways, {len(out['relations'])} relations, {len(nodes)} nodes")


def import_dem(dem_path: Path, out_path: Path = DEM_PATH) -> None:
    raw = json.loads(dem_path.read_text())
    raw["license"] = "EU-DEM v1.1 (Copernicus Land Monitoring Service), via api.opentopodata.org; free use with attribution"
    raw["elev"] = [[None if v is None else round(v, 2) for v in row] for row in raw["elev"]]
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(raw, separators=(",", ":")))
    print(f"DEM: {len(raw['lats'])} x {len(raw['lons'])}")


class Osm:
    def __init__(self, frame: Frame, path: Path = OSM_PATH):
        d = json.loads(path.read_text())
        self.license = d["license"]
        self.frame = frame
        self.nodes = {int(k): frame.m(v[0], v[1]) for k, v in d["nodes"].items()}
        self.ways = {w["id"]: w for w in d["ways"]}
        self.relations = d["relations"]

    def way_points(self, w):
        return [self.nodes[n] for n in w["nodes"] if n in self.nodes]

    def relation_outer(self, r):
        rings = []
        for m in r["members"]:
            if m.get("role") == "inner" or m["ref"] not in self.ways:
                continue
            rings.append(self.way_points(self.ways[m["ref"]]))
        # join open member ways end to end into closed rings
        closed, pending = [], [ring for ring in rings if ring]
        while pending:
            cur = pending.pop(0)
            changed = True
            while changed and math.dist(cur[0], cur[-1]) > 0.01:
                changed = False
                for i, nxt in enumerate(pending):
                    if math.dist(cur[-1], nxt[0]) < 0.01:
                        cur = cur + nxt[1:]
                    elif math.dist(cur[-1], nxt[-1]) < 0.01:
                        cur = cur + nxt[::-1][1:]
                    else:
                        continue
                    pending.pop(i)
                    changed = True
                    break
            closed.append(cur)
        return max(closed, key=lambda r: abs(poly_area(r))) if closed else []

    def named_feature_centroid(self, name):
        for r in self.relations:
            if r["tags"].get("name") == name:
                ring = self.relation_outer(r)
                if ring:
                    return poly_centroid(ring[:-1] if math.dist(ring[0], ring[-1]) < 0.01 else ring)
        for w in self.ways.values():
            if w["tags"].get("name") == name:
                pts = self.way_points(w)
                if pts:
                    ring = pts[:-1] if math.dist(pts[0], pts[-1]) < 0.01 else pts
                    return poly_centroid(ring)
        raise KeyError(name)

    def named_footprint(self, name):
        for r in self.relations:
            if r["tags"].get("name") == name:
                ring = self.relation_outer(r)
                if ring:
                    return ring[:-1] if math.dist(ring[0], ring[-1]) < 0.01 else ring
        for w in self.ways.values():
            if w["tags"].get("name") == name and "building" in w["tags"]:
                pts = self.way_points(w)
                return pts[:-1] if pts and math.dist(pts[0], pts[-1]) < 0.01 else pts
        raise KeyError(name)


class Dem:
    def __init__(self, frame: Frame, path: Path = DEM_PATH):
        d = json.loads(path.read_text())
        self.lats = np.array(d["lats"])
        self.lons = np.array(d["lons"])
        e = np.array([[np.nan if v is None else v for v in row] for row in d["elev"]], dtype=float)
        e = np.nan_to_num(e, nan=0.0)

        def stack(a, r):
            return np.stack([np.roll(np.roll(a, dy, 0), dx, 1) for dy in range(-r, r + 1) for dx in range(-r, r + 1)])

        # Surface model -> ground: an erosion removes roofs and canopies, the
        # blurs remove the 25 m stair-stepping.
        g = stack(e, 1).min(0)
        g = stack(g, 2).mean(0)
        g = stack(g, 1).mean(0)
        self.ground = g
        self.frame = frame

    def sample(self, x, y):
        lat, lon = self.frame.latlon(x, y)
        fi = (lat - self.lats[0]) / (self.lats[1] - self.lats[0])
        fj = (lon - self.lons[0]) / (self.lons[1] - self.lons[0])
        fi = np.clip(fi, 0, len(self.lats) - 1.001)
        fj = np.clip(fj, 0, len(self.lons) - 1.001)
        a, b = np.floor(fi).astype(int), np.floor(fj).astype(int)
        u, v = fi - a, fj - b
        g = self.ground
        return g[a, b] * (1 - u) * (1 - v) + g[a + 1, b] * u * (1 - v) + g[a, b + 1] * (1 - u) * v + g[a + 1, b + 1] * u * v


# ---------------------------------------------------------------------------
# plan assembly
# ---------------------------------------------------------------------------


def resolve_point(ref, overlay, osm, gates):
    if "ref" in ref:
        return tuple(gates[ref["ref"]]["at"])
    if "osm" in ref:
        return osm.named_feature_centroid(ref["osm"])
    return tuple(ref["at"])


def snap_gates(overlay, osm):
    """A gate sits on its street: move it to the nearest point of the named
    street's polylines when that is within 8 m (OSM tower centroids and hand
    estimates are a few metres off the passage)."""
    for g in overlay["gates"]:
        name = g.get("street")
        if not name:
            continue
        best = None
        for w in osm.ways.values():
            if w["tags"].get("name") != name or "highway" not in w["tags"]:
                continue
            pts = osm.way_points(w)
            for i in range(len(pts) - 1):
                dd, t = dist_point_seg(np.array([g["at"][0]]), np.array([g["at"][1]]), pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1])
                d = float(dd[0])
                if best is None or d < best[0]:
                    tt = float(t[0])
                    best = (d, (pts[i][0] + (pts[i + 1][0] - pts[i][0]) * tt, pts[i][1] + (pts[i + 1][1] - pts[i][1]) * tt))
        if best and best[0] <= 8.0:
            g["at"] = [round(best[1][0], 2), round(best[1][1], 2)]


def build_circuit(overlay, osm):
    gates = {g["id"]: g for g in overlay["gates"]}
    anchors = []
    for a in overlay["lower_town_circuit"]["anchors"]:
        p = resolve_point(a, overlay, osm, gates)
        anchors.append({"p": (round(p[0], 2), round(p[1], 2)), "state": a["state"], "ref": a.get("ref", ""), "tower": a.get("tower", ""), "osm": a.get("osm", "")})
    return anchors


def classify_street(name, highway, overlay):
    cls = overlay["streets"]["class_by_name"].get(name)
    if cls:
        return cls
    if highway == "steps":
        return "steps"
    if highway in ("footway", "path"):
        return "alley"
    return "lane"


def street_register_lookup():
    reg = json.loads(REGISTER_PATH.read_text())
    by_modern = {}
    for w in reg["ways"]:
        for token in w["modern_name"].replace("(", "/").replace(")", "/").split("/"):
            token = token.strip()
            base = token.split(" (")[0].strip()
            if base:
                by_modern.setdefault(base, w)
    return by_modern


def build(args) -> dict:
    overlay = json.loads(OVERLAY_PATH.read_text())
    frame = Frame(overlay["origin"], overlay["metres_per_world_unit"])
    mpu = frame.mpu
    osm = Osm(frame)
    dem = Dem(frame)
    b = overlay["bounds_m"]
    x0, y0, x1, y1 = b["x0"], b["y0"], b["x1"], b["y1"]
    rng = random.Random(1343)

    snap_gates(overlay, osm)
    anchors = build_circuit(overlay, osm)
    circuit_poly = [a["p"] for a in anchors]
    toompea_edge = [(p[0], p[1]) for p in overlay["toompea"]["plateau_edge_m"]]
    toompea_w = [p[2] for p in overlay["toompea"]["plateau_edge_m"]]

    # ---------------- streets ----------------
    excluded = set(overlay["streets"]["excluded_names"])
    widths = overlay["streets"]["widths_m"]
    register = street_register_lookup()
    walled = lambda p: pip(p, circuit_poly) or pip(p, toompea_edge)  # noqa: E731
    streets = []
    for w in sorted(osm.ways.values(), key=lambda w: w["id"]):
        t = w["tags"]
        name = t.get("name", "")
        hw = t.get("highway")
        if not hw or not name or name in excluded:
            continue
        if hw in ("primary", "secondary", "tertiary", "primary_link", "secondary_link", "tertiary_link", "service", "cycleway"):
            # Modern arterials outside the walls are replaced by authored 1343 roads.
            if hw != "service":
                continue
        pts = osm.way_points(w)
        if len(pts) < 2:
            continue
        inside = sum(1 for p in pts if walled(p))
        if inside < max(1, len(pts) // 2) and name not in overlay["streets"].get("always_include", []):
            continue
        if t.get("area") == "yes" or (math.dist(pts[0], pts[-1]) < 0.1 and name != "Raekoja plats"):
            continue
        cls = classify_street(name, hw, overlay)
        reg = register.get(name)
        pts = rdp(pts, 0.4)
        streets.append({
            "id": "street.osm.%d" % w["id"],
            "name": name,
            "name_1343": reg["name_1343"] if reg else "",
            "register_id": reg["id"] if reg else "",
            "confidence": (reg["route_1343"] if reg else "modern trace assumed medieval"),
            "class": cls,
            "width_m": widths[cls] if cls in widths else widths["lane"],
            "points_m": [[round(p[0], 2), round(p[1], 2)] for p in pts],
        })
    # The 1343 curtain is pierced only at gates: later passages through the
    # wall (Bremeni kaik, Suurtuki, the outer end of Olevimagi) are cut back
    # to the inside of the circuit.
    gate_points = [tuple(g["at"]) for g in overlay["gates"]]
    for s in streets:
        s["points_m"] = clip_to_circuit(s["points_m"], circuit_poly, gate_points)
    streets = [s for s in streets if len(s["points_m"]) >= 2 and polyline_length(s["points_m"]) > 2.0]
    # A gate whose street meets the curtain at a slant leaves the road ending
    # against the wall beside the opening. Where the overlay asks for it
    # ("approach"), bend the street's gate end onto the wall normal so the road
    # runs straight through the passage and a short stub continues outside.
    for g in overlay["gates"]:
        ap = g.get("approach")
        if not ap:
            continue
        ai = next(i for i, a in enumerate(anchors) if a["ref"] == g["id"])
        pp, np_ = anchors[ai - 1]["p"], anchors[(ai + 1) % len(anchors)]["p"]
        wl = math.hypot(np_[0] - pp[0], np_[1] - pp[1])
        nrm = (-(np_[1] - pp[1]) / wl, (np_[0] - pp[0]) / wl)
        cen = (sum(a["p"][0] for a in anchors) / len(anchors), sum(a["p"][1] for a in anchors) / len(anchors))
        if (cen[0] - g["at"][0]) * nrm[0] + (cen[1] - g["at"][1]) * nrm[1] > 0:
            nrm = (-nrm[0], -nrm[1])  # outward (field side)
        cands = [s for s in streets if s["name"] == g["street"]]
        ends = [(math.dist(s["points_m"][e], g["at"]), s, e) for s in cands for e in (0, -1)]
        _, st, e = min(ends, key=lambda t: t[0])
        pts = [tuple(p) for p in st["points_m"]]
        if e == 0:
            pts.reverse()
        # drop the slanted tail inside the approach distance, then re-enter on the normal
        while len(pts) > 2 and math.dist(pts[-1], g["at"]) < ap["inside_m"]:
            pts.pop()
        gx, gy = g["at"]
        pts += [(gx - nrm[0] * ap["inside_m"], gy - nrm[1] * ap["inside_m"]), (gx, gy),
                (gx + nrm[0] * ap["outside_m"], gy + nrm[1] * ap["outside_m"])]
        if e == 0:
            pts.reverse()
        st["points_m"] = [[round(p[0], 2), round(p[1], 2)] for p in pts]
    for r in overlay["streets"]["extramural_roads"]:
        streets.append({
            "id": r["id"], "name": "", "name_1343": r["name_1343"], "register_id": "",
            "confidence": r["confidence"], "class": "extramural_road", "width_m": r["width_m"],
            "points_m": r["points_m"],
        })

    # ---------------- terrain ----------------
    nx = int(math.ceil((x1 - x0) / mpu / HEIGHT_CELL_WU)) + 1
    ny = int(math.ceil((y1 - y0) / mpu / HEIGHT_CELL_WU)) + 1
    gx = x0 + np.arange(nx) * HEIGHT_CELL_WU * mpu
    gy = y0 + np.arange(ny) * HEIGHT_CELL_WU * mpu
    X, Y = np.meshgrid(gx, gy)
    base = dem.sample(X, Y)
    # Rooftop bias of the surface model inside the dense walled town.
    tr = overlay.get("terrain", {})
    if tr.get("dsm_bias_m"):
        cd = np.full(X.shape, 1e9)
        for i in range(len(circuit_poly)):
            ax, ay = circuit_poly[i]
            bx, by = circuit_poly[(i + 1) % len(circuit_poly)]
            dd, _ = dist_point_seg(X, Y, ax, ay, bx, by)
            cd = np.minimum(cd, dd)
        inside_town = point_in_poly(X, Y, circuit_poly)
        w = np.where(inside_town, 1.0, np.clip(1.0 - cd / tr["bias_taper_m"], 0.0, 1.0))
        base = base - tr["dsm_bias_m"] * w * w * (3 - 2 * w)

    # Plateau signed distance and per-edge slope width.
    sd = np.full(X.shape, 1e9)
    sw = np.zeros(X.shape)
    n = len(toompea_edge)
    for i in range(n):
        ax, ay = toompea_edge[i]
        bx, by = toompea_edge[(i + 1) % n]
        dd, tt = dist_point_seg(X, Y, ax, ay, bx, by)
        closer = dd < sd
        sd = np.where(closer, dd, sd)
        sw = np.where(closer, toompea_w[i] + (toompea_w[(i + 1) % n] - toompea_w[i]) * tt, sw)
    inside = point_in_poly(X, Y, toompea_edge)
    sd = np.where(inside, sd, -sd)

    # Inpaint the lower ground under the hill so Toompea is authored, not DEM blur.
    hole = sd > -70
    filled = base.copy()
    coarse = 4
    small = filled[::coarse, ::coarse].copy()
    small_hole = hole[::coarse, ::coarse]
    small[small_hole] = np.mean(small[~small_hole])
    for _ in range(600):
        avg = 0.25 * (np.roll(small, 1, 0) + np.roll(small, -1, 0) + np.roll(small, 1, 1) + np.roll(small, -1, 1))
        small = np.where(small_hole, avg, small)
    up = np.repeat(np.repeat(small, coarse, 0), coarse, 1)[: X.shape[0], : X.shape[1]]
    lower = np.where(hole, up, base)
    tp = overlay["toompea"]
    top = np.clip(base + tp["dem_lift_m"], tp["plateau_min_asl_m"], tp["plateau_max_asl_m"])
    # Smooth the plateau top so it reads as a limestone table, not a dome.
    for _ in range(3):
        top = 0.2 * (top + np.roll(top, 1, 0) + np.roll(top, -1, 0) + np.roll(top, 1, 1) + np.roll(top, -1, 1))
    tt = np.clip((sd + sw) / np.maximum(sw, 1.0), 0.0, 1.0)
    prof = tt * tt * (3 - 2 * tt)
    asl = lower + (top - lower) * prof

    # Hill ramps: Pikk jalg and Luhike jalg are cut into the east face.
    def carve(points, half_w, blend):
        nonlocal asl
        pts = resample(points, 2.0)
        hs = [float(dem_height(p)) for p in pts]
        a_h, b_h = hs[0], hs[-1]
        cum = [0.0]
        for i in range(1, len(pts)):
            cum.append(cum[-1] + math.dist(pts[i - 1], pts[i]))
        total = cum[-1]
        best_d = np.full(X.shape, 1e9)
        best_h = np.zeros(X.shape)
        for i in range(len(pts) - 1):
            dd, t = dist_point_seg(X, Y, pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1])
            closer = dd < best_d
            s = (cum[i] + t * (cum[i + 1] - cum[i])) / total
            best_d = np.where(closer, dd, best_d)
            best_h = np.where(closer, a_h + (b_h - a_h) * s, best_h)
        wgt = np.clip(1.0 - (best_d - half_w) / blend, 0.0, 1.0)
        wgt = wgt * wgt * (3 - 2 * wgt)
        asl = asl * (1 - wgt) + best_h * wgt

    def dem_height(p):
        i = int(round((p[1] - y0) / (HEIGHT_CELL_WU * mpu)))
        j = int(round((p[0] - x0) / (HEIGHT_CELL_WU * mpu)))
        i = min(max(i, 0), ny - 1)
        j = min(max(j, 0), nx - 1)
        return asl[i, j]

    ramp_paths = {}
    for s in streets:
        if s["name"] in ("Pikk jalg", "Lühike jalg"):
            ramp_paths.setdefault(s["name"], []).append(s["points_m"])
    for name, parts in ramp_paths.items():
        chain = chain_parts(parts)
        carve(chain, 3.0 if name == "Pikk jalg" else 2.0, 7.0)

    # Gentle street grading: streets are smoothed along their length so lanes do not ripple.
    # 1343 sea level in modern datum: land has risen ~1.4 m since.
    sea_asl = overlay["sea"]["uplift_m_since_1343"]
    shore = [tuple(p) for p in overlay["sea"]["shoreline_m"]]
    sea_poly = shore + [(x1 + 50, y0 - 50), (x0 - 50, y0 - 50)]
    sea_poly = [shore[0]] + shore[1:] + [(x1 + 50, shore[-1][1]), (x1 + 50, y0 - 50), (x0 - 50, y0 - 50)]
    in_sea = point_in_poly(X, Y, sea_poly)
    # Distance to the shoreline for beach and seabed profiles.
    shore_d = np.full(X.shape, 1e9)
    for i in range(len(shore) - 1):
        dd, _ = dist_point_seg(X, Y, shore[i][0], shore[i][1], shore[i + 1][0], shore[i + 1][1])
        shore_d = np.minimum(shore_d, dd)
    beach = sea_asl + 0.35 + shore_d * 0.045
    coastal_cliff_zone = np.hypot(X - 222.5, Y - 600.0 * -1) < 0  # placeholder (no-op)
    land_h = np.where(~in_sea, np.minimum(asl, np.maximum(beach, sea_asl + 0.35)), asl)
    # Above the beach band the authored land keeps its own height; the min() only
    # lowers the post-1840 harbour fill near the shore.
    blend = np.clip((shore_d - 60.0) / 140.0, 0.0, 1.0)
    land_h = np.where(~in_sea, land_h * (1 - blend) + asl * blend, land_h)
    # Beach berms and runnels parallel to the water, hummocks of drift sand: the
    # strand is not a plane (docs/SYSTEMS/CITY_SEA.md). Nothing within 1.5 m of the
    # waterline, so the shore stays where the overlay put it.
    strand = smoothstep01(shore_d, 1.5, 8.0) * (1.0 - smoothstep01(shore_d, 28.0, 55.0))
    berm = 0.26 * np.sin(shore_d / 5.2 + terrain_relief.lattice_noise(X, Y, 70.0, 9201) * 4.0)
    hummock = (terrain_relief.lattice_noise(X, Y, 16.0, 9202) - 0.5) * 0.55
    land_h = np.where(~in_sea, land_h + (berm + hummock) * strand, land_h)
    # Seabed: shore-parallel sandbars and troughs, boulder fields and undulation, so
    # the water has real depth variety (bars are broken along the shore by noise).
    seabed = sea_asl - np.minimum(0.6 + shore_d * 0.035, 7.0)
    ss = terrain_relief.smoothstep
    bar_a = 0.55 * np.exp(-(((shore_d - 32.0) / 9.0) ** 2)) * ss(0.42, 0.68, terrain_relief.lattice_noise(X, Y, 90.0, 9101))
    bar_b = 0.45 * np.exp(-(((shore_d - 85.0) / 13.0) ** 2)) * ss(0.4, 0.65, terrain_relief.lattice_noise(X, Y, 130.0, 9102))
    trough = -0.4 * np.exp(-(((shore_d - 56.0) / 10.0) ** 2))
    swell = (terrain_relief.lattice_noise(X, Y, 38.0, 9103) - 0.5) * 0.7 + (terrain_relief.lattice_noise(X, Y, 14.0, 9104) - 0.5) * 0.25
    boulders = ss(0.6, 0.8, terrain_relief.lattice_noise(X, Y, 60.0, 9105)) * ss(0.5, 0.85, terrain_relief.lattice_noise(X, Y, 5.0, 9106)) * 0.75 * (shore_d < 170.0)
    seabed = seabed + (bar_a + bar_b + trough + swell + boulders) * ss(5.0, 24.0, shore_d)
    seabed = np.minimum(seabed, sea_asl - 0.14)  # a bar may shoal the water, never dry it
    asl = np.where(in_sea, seabed, land_h)

    # Hareapea stream channel. The DEM is a smooth plate that falls ~16 m from the
    # south edge to the sea, so a river held at sea level would sit in a 12 m
    # gorge (bridges hung mid-slope, banks too steep to walk). The water instead
    # follows the land: surface = valley floor minus a shallow bank, never rising
    # downstream, and the banks stay gentle enough to walk down to the water.
    hj = overlay["harjapea"]
    trace = [tuple(p) for p in hj["trace_m"]]

    def asl_pre(px, py):
        fx = min(max((px - x0) / (HEIGHT_CELL_WU * mpu), 0), nx - 1.001)
        fy = min(max((py - y0) / (HEIGHT_CELL_WU * mpu), 0), ny - 1.001)
        i, j = int(fy), int(fx)
        u, v = fy - i, fx - j
        return float(asl[i, j] * (1 - u) * (1 - v) + asl[i + 1, j] * u * (1 - v) + asl[i, j + 1] * (1 - u) * v + asl[i + 1, j + 1] * u * v)

    # Land beside the stream (lowest of both banks, 30 m out) sets the water level.
    river_level = []
    for i, (tx, ty) in enumerate(trace):
        nxt = trace[min(i + 1, len(trace) - 1)]
        prv = trace[max(i - 1, 0)]
        d_ = math.hypot(nxt[0] - prv[0], nxt[1] - prv[1]) or 1.0
        sx, sy = -(nxt[1] - prv[1]) / d_, (nxt[0] - prv[0]) / d_
        bank_land = min(asl_pre(tx + sx * 30.0, ty + sy * 30.0), asl_pre(tx - sx * 30.0, ty - sy * 30.0))
        river_level.append(bank_land - 1.6)
    # Downstream is the last trace point: the level never rises toward it, and
    # the mouth meets the sea.
    for i in range(1, len(river_level)):
        river_level[i] = min(river_level[i], river_level[i - 1])
    river_level = [max(v_, sea_asl + 0.0) for v_ in river_level]
    river_d = np.full(X.shape, 1e9)
    river_w = np.zeros(X.shape)
    river_s = np.zeros(X.shape)
    river_chain, pools = stream_pools(overlay)
    river_along = np.zeros(X.shape)
    for i in range(len(trace) - 1):
        dd, t = dist_point_seg(X, Y, trace[i][0], trace[i][1], trace[i + 1][0], trace[i + 1][1])
        closer = dd < river_d
        river_d = np.where(closer, dd, river_d)
        river_w = np.where(closer, hj["width_m"][i] + (hj["width_m"][i + 1] - hj["width_m"][i]) * t, river_w)
        river_s = np.where(closer, river_level[i] + (river_level[i + 1] - river_level[i]) * t, river_s)
        river_along = np.where(closer, river_chain[i] + (river_chain[i + 1] - river_chain[i]) * t, river_along)
    bank = np.clip((river_d - river_w * 0.5) / 14.0, 0.0, 1.0)
    river_bed = river_s - STREAM_MARGIN_DEPTH_M
    river_lowering = stream_depth(river_d, river_w, river_along, pools) - STREAM_MARGIN_DEPTH_M
    asl = np.where(river_d < river_w * 0.5 + 14.0, river_bed + (asl - river_bed) * bank, asl)

    # Moat (ditch) outside the S/E curtain.
    mo = overlay["moat"]
    wall_line = [a["p"] for a in anchors[mo["from_anchor"] : mo["to_anchor"] + 1]]
    moat_line = offset_outward(resample(wall_line, 6.0), circuit_poly, mo["offset_m"])
    # Rounded corners, kept clear of the curtain foot (ditch inner edge >= 3 m out).
    moat_line = resample(smooth_ditch(moat_line, wall_line, mo["offset_m"] - 1.5), 6.0)
    # The ditch runs out gently at both ends (depth and width fade over the last
    # MOAT_TAPER_M of its length) instead of stopping at a blunt cut-off.
    arc = [0.0]
    for i in range(1, len(moat_line)):
        arc.append(arc[-1] + math.hypot(moat_line[i][0] - moat_line[i - 1][0], moat_line[i][1] - moat_line[i - 1][1]))
    taper = [float(smoothstep01(min(a_, arc[-1] - a_), 0.0, MOAT_TAPER_M)) for a_ in arc]
    moat_d = np.full(X.shape, 1e9)
    moat_fade = np.zeros(X.shape)
    for i in range(len(moat_line) - 1):
        dd, tt = dist_point_seg(X, Y, moat_line[i][0], moat_line[i][1], moat_line[i + 1][0], moat_line[i + 1][1])
        closer = dd < moat_d
        moat_fade = np.where(closer, taper[i] + (taper[i + 1] - taper[i]) * tt, moat_fade)
        moat_d = np.where(closer, dd, moat_d)
    half = mo["width_m"] * 0.5
    # Narrower ditch toward the ends: shrink the profile, not just its depth.
    half_here = half * (0.35 + 0.65 * moat_fade)
    cut = np.clip(1.0 - (moat_d - half_here * 0.5) / (half_here * 1.7), 0.0, 1.0)
    cut = cut * cut * (3 - 2 * cut) * moat_fade
    # Every road crosses the ditch: remember where, for the moat bridges.
    causeways = []
    for r in overlay["streets"]["extramural_roads"]:
        pts = [tuple(q) for q in r["points_m"]]
        for k in range(len(pts) - 1):
            for i in range(len(moat_line) - 1):
                q = seg_intersection(pts[k], pts[k + 1], moat_line[i], moat_line[i + 1])
                if q is not None:
                    causeways.append((q, math.atan2(pts[k + 1][1] - pts[k][1], pts[k + 1][0] - pts[k][0]), r.get("causeway_width_m", r["width_m"]), r["id"]))
    # Roads cross the ditch on timber bridges (below), so the ditch is cut unbroken.
    asl = asl - cut * mo["depth_m"]

    # Final light smoothing outside the cliff band keeps the ground from stair-stepping.
    cliff_band = (sd > -np.maximum(sw, 1) - 2) & (sd < 3)
    sm = 0.2 * (asl + np.roll(asl, 1, 0) + np.roll(asl, -1, 0) + np.roll(asl, 1, 1) + np.roll(asl, -1, 1))
    asl = np.where(cliff_band, asl, sm)

    # Open-country relief: the DEM trend is a smooth plate, real ground is not.
    # Authored ground (town, Toompea, shore, river, suburbs) keeps its height.
    wall_d = terrain_relief.poly_distance(X, Y, circuit_poly, dist_point_seg)
    inside_walls = point_in_poly(X, Y, circuit_poly)
    keepout = [
        smoothstep01(terrain_relief.poly_distance(X, Y, toompea_edge, dist_point_seg), 10.0, 60.0)
        * (~point_in_poly(X, Y, toompea_edge)),
        smoothstep01(shore_d, 6.0, 40.0) * (~in_sea),
        smoothstep01(river_d - river_w * 0.5, 4.0, 30.0),
    ]
    for sub in overlay["suburbs"]:
        poly = [tuple(q) for q in sub["polygon_m"]]
        keepout.append(
            np.where(point_in_poly(X, Y, poly), 0.0, smoothstep01(terrain_relief.poly_distance(X, Y, poly, dist_point_seg), 4.0, 28.0))
        )
    relief_w = terrain_relief.relief_weight(X, Y, wall_d, inside_walls, keepout)
    hollow_roads = [([tuple(q) for q in r["points_m"]], r["width_m"]) for r in overlay["streets"]["extramural_roads"]]
    # Roads first so the small relief knows where to stay out of the way.
    probe, road_w = terrain_relief.carve_hollow_ways(np.zeros(X.shape), X, Y, hollow_roads, wall_d, dist_point_seg)
    asl = terrain_relief.add_open_country_relief(asl, X, Y, relief_w, shore_d, road_w)
    asl = asl + probe * (~inside_walls) * (~in_sea)

    height_wu = (asl - sea_asl) / mpu  # world units above the 1343 sea

    def h_at_m(px, py):
        fx = (px - x0) / (HEIGHT_CELL_WU * mpu)
        fy = (py - y0) / (HEIGHT_CELL_WU * mpu)
        fx = min(max(fx, 0), nx - 1.001)
        fy = min(max(fy, 0), ny - 1.001)
        i, j = int(fy), int(fx)
        u, v = fy - i, fx - j
        h = height_wu
        return float(h[i, j] * (1 - u) * (1 - v) + h[i + 1, j] * u * (1 - v) + h[i, j + 1] * (1 - u) * v + h[i + 1, j + 1] * u * v)

    # ---------------- bridges: every extramural road over the Hareapea ----------------
    bridges = []
    for r in overlay["streets"]["extramural_roads"]:
        pts = [tuple(q) for q in r["points_m"]]
        for k in range(len(pts) - 1):
            for i in range(len(trace) - 1):
                q = seg_intersection(pts[k], pts[k + 1], trace[i], trace[i + 1])
                if q is None:
                    continue
                ang = math.atan2(pts[k + 1][1] - pts[k][1], pts[k + 1][0] - pts[k][0])
                t = math.dist(trace[i], q) / max(math.dist(trace[i], trace[i + 1]), 1e-9)
                river = hj["width_m"][i] + (hj["width_m"][i + 1] - hj["width_m"][i]) * t
                length = river + 16.0
                c, s_ = math.cos(ang), math.sin(ang)
                ha = h_at_m(q[0] - c * length / 2, q[1] - s_ * length / 2)
                hb = h_at_m(q[0] + c * length / 2, q[1] + s_ * length / 2)
                bridges.append({
                    "id": "bridge.%s" % r["id"].split(".")[1], "road": r["id"],
                    "at": [round(q[0] / mpu, 2), round(q[1] / mpu, 2)], "angle": round(ang, 4),
                    "length": round(length / mpu, 2), "width": round((r["width_m"] + 1.5) / mpu, 2),
                    "ha": round(ha, 3), "hb": round(hb, 3),
                    "confidence": "plausible composite; no 1343 bridge is attested, a plank-deck timber bridge is a reversible reconstruction",
                })
    # Moat bridges: a plank deck on trestles carries each road over the ditch.
    for q, ang, _w, road_id in causeways:
        road = next(r for r in overlay["streets"]["extramural_roads"] if r["id"] == road_id)
        length = mo["width_m"] * 2.0 + 4.0
        c, s_ = math.cos(ang), math.sin(ang)
        bridges.append({
            "id": "bridge.moat.%s" % road["id"].split(".")[1], "road": road["id"], "kind": "moat",
            "at": [round(q[0] / mpu, 2), round(q[1] / mpu, 2)], "angle": round(ang, 4),
            "length": round(length / mpu, 2), "width": round((road["width_m"] + 1.5) / mpu, 2),
            "ha": round(h_at_m(q[0] - c * length / 2, q[1] - s_ * length / 2), 3),
            "hb": round(h_at_m(q[0] + c * length / 2, q[1] + s_ * length / 2), 3),
            "confidence": "plausible composite; the ditch is crossed by a timber plank bridge (reversible reconstruction), no 1343 bridge is attested",
        })

    # ---------------- buildings ----------------
    excluded_b = set(overlay["excluded_osm_buildings"])
    landmark_by_osm = {lm["osm_building"]: lm for lm in overlay["landmarks"] if "osm_building" in lm}
    street_segments = []
    for s in streets:
        p = s["points_m"]
        for i in range(len(p) - 1):
            street_segments.append((p[i], p[i + 1], s))
    street_arr = np.array([[a[0], a[1], b_[0], b_[1]] for a, b_, _ in street_segments])
    spine_names = {"Pikk", "Lai", "Raekoja plats", "Vene", "Viru", "Harju", "Suur-Karja"}

    def nearest_street(c):
        ax, ay, bx, by = street_arr.T
        dx, dy = bx - ax, by - ay
        ll = np.maximum(dx * dx + dy * dy, 1e-9)
        t = np.clip(((c[0] - ax) * dx + (c[1] - ay) * dy) / ll, 0, 1)
        qx, qy = ax + t * dx, ay + t * dy
        d = np.hypot(c[0] - qx, c[1] - qy)
        i = int(np.argmin(d))
        return float(d[i]), (float(qx[i]), float(qy[i])), street_segments[i]

    buildings = []
    footprints = []
    for w in sorted(osm.ways.values(), key=lambda w: w["id"]):
        t = w["tags"]
        if "building" not in t:
            continue
        if t.get("name") in excluded_b:
            continue
        pts = osm.way_points(w)
        if len(pts) < 4:
            continue
        ring = pts[:-1] if math.dist(pts[0], pts[-1]) < 0.01 else pts
        footprints.append((("w", w["id"]), t, ring))
    for r in osm.relations:
        if "building" not in r["tags"] or r["tags"].get("name") in excluded_b:
            continue
        ring = osm.relation_outer(r)
        if len(ring) >= 4:
            footprints.append((("r", r["id"]), r["tags"], ring[:-1] if math.dist(ring[0], ring[-1]) < 0.01 else ring))

    lower_town_area = 0
    for key, tags, ring in footprints:
        ring = simplify_ring([(round(p[0], 2), round(p[1], 2)) for p in ring], 0.35)
        if len(ring) < 3:
            continue
        if poly_area(ring) < 0:
            ring = ring[::-1]
        area = poly_area(ring)
        c = poly_centroid(ring)
        name = tags.get("name", "")
        lm = landmark_by_osm.get(name)
        in_lower = pip(c, circuit_poly)
        in_toompea = pip(c, toompea_edge)
        if not (in_lower or in_toompea):
            continue
        if not lm and (area < 18 or area > 1400):
            continue
        # Footprints that straddle the curtain or the klint edge are later fabric.
        if not lm and in_lower and any(not pip(p, circuit_poly) for p in ring):
            continue
        d_street, foot, seg = nearest_street(c)
        street = seg[2]
        hid = "bldg.osm.%s%d" % key
        rnd = random.Random(hash_int(hid))
        if lm:
            kind = lm["kind"]
        else:
            # 1343 density: back plots stay yards and gardens more often than today.
            if d_street > 22 and rnd.random() < 0.45:
                continue
            if d_street > 12 and rnd.random() < 0.18:
                continue
            kind = "house"
        if in_toompea and not lm:
            on_spine = False
            wealth = 0.75
        else:
            on_spine = street["name"] in spine_names and d_street < 14
            wealth = (0.8 if on_spine else 0.35) + rnd.random() * 0.25
        ang, length, depth = min_area_rect(ring)
        # Gable faces the street for merchant houses: ridge runs away from the street.
        to_street = math.atan2(foot[1] - c[1], foot[0] - c[0])
        # The ridge always follows one of the footprint's own axes. Long plots
        # roof along their length; near-square plots turn the gable to the
        # street (Diele house type, docs/CANON.md).
        ridge = ang
        if not lm and length / max(depth, 0.1) < 1.35:
            if abs(math.cos(to_street - (ang + math.pi / 2))) > abs(math.cos(to_street - ang)):
                ridge = ang + math.pi / 2
        if lm:
            material = "limestone"
            roof = lm.get("roof", "tile")
            storeys_h = lm.get("nave_h_m", 12)
        elif wealth > 0.85:
            material, roof = "limestone", "tile"
            storeys_h = 7.5 + rnd.random() * 3.0
        elif wealth > 0.6:
            material = "limestone" if rnd.random() < 0.55 else "plaster"
            roof = "tile" if material == "limestone" and rnd.random() < 0.5 else "shingle"
            storeys_h = 5.5 + rnd.random() * 2.5
        else:
            material = "log" if rnd.random() < 0.6 else "plank"
            roof = "thatch" if rnd.random() < 0.55 else "shingle"
            storeys_h = 3.2 + rnd.random() * 1.6
        door = door_on_edge(ring, foot)
        hmin = min(h_at_m(p[0], p[1]) for p in ring)
        hmax = max(h_at_m(p[0], p[1]) for p in ring)
        bld = {
            "id": hid,
            "kind": kind,
            "name_1343": lm["name_1343"] if lm else "",
            "landmark_id": lm["id"] if lm else "",
            "confidence": lm["confidence"] if lm else "plot from modern footprint (plausible composite)",
            "footprint": [[round(p[0] / mpu, 3), round(p[1] / mpu, 3)] for p in ring],
            "base_h": round(hmin, 3),
            "base_span": round(hmax - hmin, 3),
            "wall_h": round(storeys_h / mpu, 3),
            "roof": roof,
            "roof_pitch_deg": 52 if roof in ("thatch",) else (48 if roof == "shingle" else 50),
            "ridge_angle": round(ridge, 4),
            "material": material,
            "street_id": street["id"],
            "door": [round(door[0] / mpu, 3), round(door[1] / mpu, 3), round(door[2], 4)] if door else None,
            # Churches and chapels are walked into like houses (one open nave).
            # No upper size cap (R-1906): the census settles a household in every
            # big merchant house, and HouseholdLayout splits it into hall, living
            # room and chamber, so a closed 900 m2 house was a home nobody could reach.
            # Slivers under 2 m wide (OSM wall remnants) leave no room inside.
            "enterable": bool(door) and (bool(lm) or (area >= 22 and min(length, depth) >= 2.0)),
            "tower_h": round(lm.get("tower_h_m", 0) / mpu, 3) if lm else 0.0,
        }
        if not lm:
            # WB-13b: persist the tiers so plots and rendering read them instead of
            # re-deriving from material/roof. Tier thresholds follow the material
            # bands above (limestone+tile = great, >0.6 = merchant, log/plank below).
            # Age and upkeep use their own Random so the draws above stay untouched.
            trng = random.Random(hash_int(hid + "|tiers"))
            bld["wealth_tier"] = ("great" if wealth > 0.85 else "merchant" if wealth > 0.6
                                  else "craft" if wealth >= 0.47 else "poor")
            bld["age_tier"] = trng.choices(("new", "settled", "old"), weights=(2, 5, 3))[0]
            bld["upkeep"] = "kept" if trng.random() < 0.6 else "worn"
        buildings.append(bld)
        lower_town_area += area

    # Town hall: authored, the modern building is later.
    for lm in overlay["landmarks"]:
        if "near" not in lm:
            continue
        cx, cy = lm["near"]
        a = math.radians(lm["angle_deg"])
        hw_, hd = lm["w_m"] / 2, lm["d_m"] / 2
        ring = [(cx + math.cos(a) * sx * hw_ - math.sin(a) * sy * hd, cy + math.sin(a) * sx * hw_ + math.cos(a) * sy * hd) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        # remove OSM buildings overlapping the authored hall
        buildings = [bb for bb in buildings if not (pip((bb["footprint"][0][0] * mpu, bb["footprint"][0][1] * mpu), ring) or pip(poly_centroid([(p[0] * mpu, p[1] * mpu) for p in bb["footprint"]]), ring))]
        door = ((ring[0][0] + ring[1][0]) / 2, (ring[0][1] + ring[1][1]) / 2, a - math.pi / 2)
        hmin = min(h_at_m(p[0], p[1]) for p in ring)
        hmax = max(h_at_m(p[0], p[1]) for p in ring)
        buildings.append({
            "id": lm["id"].replace("landmark.", "bldg.lm."), "kind": lm["kind"], "name_1343": lm["name_1343"],
            "landmark_id": lm["id"], "confidence": lm["confidence"],
            "footprint": [[round(p[0] / mpu, 3), round(p[1] / mpu, 3)] for p in ring],
            "base_h": round(hmin, 3), "base_span": round(hmax - hmin, 3), "wall_h": round(lm["h_m"] / mpu, 3), "roof": lm["roof"],
            "roof_pitch_deg": 50, "ridge_angle": round(a, 4), "material": "limestone", "street_id": "",
            "door": [round(door[0] / mpu, 3), round(door[1] / mpu, 3), round(door[2], 4)], "enterable": True, "tower_h": 0.0,
        })

    # Suburb houses outside the walls: deterministic scatter along roads.
    farm_houses = []
    for sub in overlay["suburbs"]:
        poly = [tuple(p) for p in sub["polygon_m"]]
        xs = [p[0] for p in poly]
        ys = [p[1] for p in poly]
        srng = random.Random(hash_int(sub["id"]))
        placed = []
        attempts = int(abs(poly_area(poly)) / 180 * sub["density"])
        for k in range(attempts * 4):
            if len(placed) >= attempts:
                break
            px_, py_ = srng.uniform(min(xs), max(xs)), srng.uniform(min(ys), max(ys))
            if not pip((px_, py_), poly) or pip((px_, py_), circuit_poly):
                continue
            if h_at_m(px_, py_) < 0.5:
                continue
            d_street, foot, seg = nearest_street((px_, py_))
            if d_street < 6 or d_street > 40:
                continue
            if any(math.dist((px_, py_), q) < 16 for q in placed):
                continue
            placed.append((px_, py_))
            ang = math.atan2(foot[1] - py_, foot[0] - px_) + math.pi / 2 + srng.uniform(-0.25, 0.25)
            L = srng.uniform(7, 12) if sub["kind"] != "fisher" else srng.uniform(4.2, 9.5)
            D = srng.uniform(5, 7) if sub["kind"] != "fisher" else srng.uniform(3.4, 5.4)
            if sub["kind"] == "fisher" and L * D < 24.0:
                # A fisher hut is a dwelling: the census (tools/city/build_city_census.py)
                # files anything under 22 m2 as an empty shed, so a moved hut must not
                # shrink below that and evict its household. Stretched, not re-drawn,
                # so the seeded sequence and every later hut stay put.
                L = 24.0 / D
            ring = [(px_ + math.cos(ang) * sx * L / 2 - math.sin(ang) * sy * D / 2, py_ + math.sin(ang) * sx * L / 2 + math.cos(ang) * sy * D / 2) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
            # irregular: nudge one corner so houses are not perfect rectangles
            ci = srng.randrange(4)
            ring[ci] = (ring[ci][0] + srng.uniform(-0.6, 0.6), ring[ci][1] + srng.uniform(-0.6, 0.6))
            door = door_on_edge(ring, foot)
            hmin = min(h_at_m(p[0], p[1]) for p in ring)
            hmax = max(h_at_m(p[0], p[1]) for p in ring)
            hid = "bldg.%s.%02d" % (sub["id"].split(".")[1], len(placed))
            if sub["kind"] == "farm":
                farm_houses.append((hid, (px_, py_), ang, seg[2]["id"], sub["confidence"]))
            buildings.append({
                "id": hid, "kind": "house", "name_1343": "", "landmark_id": "", "confidence": sub["confidence"],
                "footprint": [[round(p[0] / mpu, 3), round(p[1] / mpu, 3)] for p in ring],
                "base_h": round(hmin, 3), "base_span": round(hmax - hmin, 3), "wall_h": round((srng.uniform(2.6, 3.4) if sub["kind"] != "fisher" else srng.uniform(1.7, 2.4)) / mpu, 3),
                "roof": "thatch", "roof_pitch_deg": 52 if sub["kind"] != "fisher" else srng.choice([34, 38, 42, 48]), "ridge_angle": round(ang, 4),
                "material": "log", "street_id": seg[2]["id"],
                "door": [round(door[0] / mpu, 3), round(door[1] / mpu, 3), round(door[2], 4)] if door else None,
                "enterable": bool(door), "tower_h": 0.0,
            })

    buildings.extend(farm_outbuildings(farm_houses, buildings, h_at_m, nearest_street, mpu))
    harbour_b, harbour_decks, harbour = harbour_features(buildings, h_at_m, nearest_street, mpu)
    buildings.extend(harbour_b)
    bridges.extend(harbour_decks)
    buildings.sort(key=lambda b_: b_["id"])
    # ADR 0032 landmark sites: drop the generic buildings they replace, level
    # their terraces, then the generic landmark terraces.
    sites = load_sites()
    replaced = {rid for site in sites for rid in site["replaces"]}
    missing = replaced - {b_["id"] for b_ in buildings}
    if missing:
        raise SystemExit(f"site replaces unknown building ids: {sorted(missing)}")
    # Footprints a walled close replaced; see the vegetation note below.
    closed_out = {rid for site in sites if site.get("close") for rid in site["replaces"]}
    replaced_footprints = [b_["footprint"] for b_ in buildings if b_["id"] in closed_out]
    buildings = [b_ for b_ in buildings if b_["id"] not in replaced]
    site_out = [terrace_site(site, height_wu, h_at_m, x0, y0, mpu) for site in sites]
    fix_blocked_doors(buildings, [poly for so in site_out for poly in so["footprints"]])
    lower_high_doors(buildings, [poly for so in site_out for poly in so["footprints"]], h_at_m, mpu)
    # R-1929: farm-suburb houses are smoke cottages and the barn-dwelling is a
    # walk-in two-bay elurehi (no household: the census only counts houses).
    # After the door fix, so the plan follows the final door.
    farm_ids = {fh[0] for fh in farm_houses}
    for b_ in buildings:
        if b_["id"] in farm_ids:
            b_["rural_plan"] = rural_plan(b_, "smoke_cottage", mpu)
        elif b_.get("type") == "barn_dwelling":
            b_["enterable"] = bool(b_["door"])
            b_["rural_plan"] = rural_plan(b_, "barn_dwelling", mpu)
    terrace_landmarks(buildings, height_wu, h_at_m, x0, y0, mpu)
    # A small site squeezed between houses (Kalev's smithy) sets `over_houses`:
    # the neighbours' plot aprons are cut after the site terrace and would
    # otherwise push their ground through its floor, so its terrace is levelled
    # once more on top, with a short blend.
    for site, so in zip(sites, site_out):
        ter = site["terrace"]
        if ter.get("over_houses"):
            ring = [site_to_world(site, q) for q in ter["polygon"]]
            flatten_ground(height_wu, ring, so["level"], 1.2, x0, y0, mpu, apron=0.4)
    # A side door whose ground a neighbour's plot cut away (the Holy Spirit
    # almshouse door: the terrace stands ~1.8 m above the house plot next to
    # it) gets a graded approach from its sill down to the open ground.
    for site, so in zip(sites, site_out):
        for appr in site["terrace"].get("approaches", []):
            grade_approach(site, appr, so["level"], height_wu, h_at_m, x0, y0, mpu)
    # Kalev's smithy: the enterable house nearest the authored spot, unless a
    # landmark site (site.kalev_smithy) already models it and replaced that house.
    ks = overlay.get("kalev_smithy")
    if ks and not any(s_.get("landmark_id") == "landmark.kalev_smithy" for s_ in sites):
        target = (ks["near_m"][0] / mpu, ks["near_m"][1] / mpu)
        cands = [b_ for b_ in buildings if b_["enterable"] and not b_["landmark_id"] and b_["door"]]
        smithy = min(cands, key=lambda b_: math.dist(target, poly_centroid([tuple(q) for q in b_["footprint"]])))
        smithy["landmark_id"] = "landmark.kalev_smithy"
        smithy["name_1343"] = ks["name_1343"]
        smithy["material"] = "log"
        smithy["roof"] = "shingle"

    # ---------------- fortifications ----------------
    tower_specs = {t["id"]: t for t in overlay["towers_1343"]}
    curtains = []
    for i, a in enumerate(anchors):
        b_ = anchors[(i + 1) % len(anchors)]
        state = a["state"]
        spec = {"stone": (6.2, 1.5), "construction": (3.8, 1.4), "palisade": (3.6, 0.5)}[state]
        curtains.append({
            "id": "curtain.%02d" % i,
            "from": [round(a["p"][0] / mpu, 3), round(a["p"][1] / mpu, 3)],
            "to": [round(b_["p"][0] / mpu, 3), round(b_["p"][1] / mpu, 3)],
            "state": state,
            "height": round(spec[0] / mpu, 3),
            "thickness": round(spec[1] / mpu, 3),
            "base_from": round(h_at_m(*a["p"]), 3),
            "base_to": round(h_at_m(*b_["p"]), 3),
        })
    towers = []
    for i, a in enumerate(anchors):
        if not a["tower"]:
            continue
        spec = tower_specs[a["tower"]]
        prev_p = anchors[i - 1]["p"]
        next_p = anchors[(i + 1) % len(anchors)]["p"]
        along = math.atan2(next_p[1] - prev_p[1], next_p[0] - prev_p[0])
        towers.append({
            "id": spec["id"], "name": spec["name"], "form": spec["form"], "state": spec["state"],
            "confidence": spec["confidence"],
            "at": [round(a["p"][0] / mpu, 3), round(a["p"][1] / mpu, 3)],
            "angle": round(along, 4),
            "w": round(spec["w"] / mpu, 3), "d": round(spec["d"] / mpu, 3), "h": round(spec["h"] / mpu, 3),
            "base_h": round(h_at_m(*a["p"]), 3),
        })
    flank_specs = {f["gate"]: f for f in overlay.get("flanking_towers", [])}
    gates_out = []
    barbicans_out = []
    circuit_centroid = (sum(a["p"][0] for a in anchors) / len(anchors), sum(a["p"][1] for a in anchors) / len(anchors))
    for g in overlay["gates"]:
        idx = next(i for i, a in enumerate(anchors) if a["ref"] == g["id"])
        prev_p = anchors[idx - 1]["p"]
        next_p = anchors[(idx + 1) % len(anchors)]["p"]
        along = math.atan2(next_p[1] - prev_p[1], next_p[0] - prev_p[0])
        # The passage runs along the street: the gate face is perpendicular to it.
        sdir = street_direction_at(streets, g.get("street"), g["at"])
        if sdir is not None:
            cand = sdir + math.pi / 2
            # keep the wall-wise orientation sign so "field side" stays consistent
            if math.cos(cand - along) < 0:
                cand += math.pi
            along = cand
        if g["id"] in flank_specs:
            fs = flank_specs[g["id"]]
            ax = (math.cos(along), math.sin(along))
            for sign, tid in zip((-1, 1), fs["towers"]):
                spec = tower_specs[tid]
                p = (g["at"][0] + ax[0] * sign * fs["offset_m"], g["at"][1] + ax[1] * sign * fs["offset_m"])
                towers.append({
                    "id": spec["id"], "name": spec["name"], "form": spec["form"], "state": spec["state"],
                    "confidence": spec["confidence"], "at": [round(p[0] / mpu, 3), round(p[1] / mpu, 3)],
                    "angle": round(along, 4), "w": round(spec["w"] / mpu, 3), "d": round(spec["d"] / mpu, 3),
                    "h": round(spec["h"] / mpu, 3), "base_h": round(h_at_m(*p), 3),
                    **({"roof_h": round(spec["roof_h"] / mpu, 3)} if "roof_h" in spec else {}),
                })
        for bb in overlay.get("barbicans", []):
            if bb["gate"] != g["id"]:
                continue
            # Outer gate, bailey side walls and the outer tower pair: the passage
            # runs along the street (perpendicular to the wall), outward = field side.
            ax = (math.cos(along), math.sin(along))
            nrm = (-ax[1], ax[0])
            if math.dist((g["at"][0] + nrm[0], g["at"][1] + nrm[1]), circuit_centroid) < math.dist((g["at"][0] - nrm[0], g["at"][1] - nrm[1]), circuit_centroid):
                nrm = (-nrm[0], -nrm[1])
            outer = (g["at"][0] + nrm[0] * bb["length_m"], g["at"][1] + nrm[1] * bb["length_m"])
            hw = bb["half_width_m"]
            for sign, tid in zip((-1, 1), bb["outer_towers"]):
                spec = tower_specs[tid]
                p = (outer[0] + ax[0] * sign * hw, outer[1] + ax[1] * sign * hw)
                towers.append({
                    "id": spec["id"], "name": spec["name"], "form": spec["form"], "state": spec["state"],
                    "confidence": spec["confidence"], "at": [round(p[0] / mpu, 3), round(p[1] / mpu, 3)],
                    "angle": round(along, 4), "w": round(spec["w"] / mpu, 3), "d": round(spec["d"] / mpu, 3),
                    "h": round(spec["h"] / mpu, 3), "base_h": round(h_at_m(*p), 3),
                })
            walls = []
            for sign in (-1, 1):
                # Tower centres of the inner pair sit on the wall line; the outer pair is
                # offset the same way, so each side wall joins the two drums.
                a0 = (g["at"][0] + ax[0] * sign * hw, g["at"][1] + ax[1] * sign * hw)
                a1 = (outer[0] + ax[0] * sign * hw, outer[1] + ax[1] * sign * hw)
                walls.append({
                    "from": [round(a0[0] / mpu, 3), round(a0[1] / mpu, 3)], "to": [round(a1[0] / mpu, 3), round(a1[1] / mpu, 3)],
                    "height": round(bb["wall_height_m"] / mpu, 3), "thickness": round(bb["wall_thickness_m"] / mpu, 3),
                    "base_from": round(h_at_m(*a0), 3), "base_to": round(h_at_m(*a1), 3),
                })
            barbicans_out.append({
                "id": bb["id"], "gate": g["id"], "confidence": bb["confidence"], "walls": walls,
                "outer_gate": {
                    "id": g["id"] + ".outer", "name_1343": bb["outer_name"], "state": "present",
                    "confidence": bb["confidence"], "at": [round(outer[0] / mpu, 3), round(outer[1] / mpu, 3)],
                    "angle": round(along, 4), "opening": round(3.6 / mpu, 3), "base_h": round(h_at_m(*outer), 3),
                },
            })
        gates_out.append({
            "id": g["id"], "name_1343": g["name_1343"], "state": g["state"], "confidence": g["confidence"],
            "at": [round(g["at"][0] / mpu, 3), round(g["at"][1] / mpu, 3)], "angle": round(along, 4),
            "opening": round(3.6 / mpu, 3), "base_h": round(h_at_m(*g["at"]), 3),
        })
    # Toompea castrum maius wall: the plateau edge pulled in by inset_m.
    tw = overlay["toompea_wall"]
    inner = inset_ring(toompea_edge, tw["inset_m"])
    toompea_walls = []
    for i in range(len(inner)):
        a, b_ = inner[i], inner[(i + 1) % len(inner)]
        toompea_walls.append({
            "id": "toompea_wall.%02d" % i,
            "from": [round(a[0] / mpu, 3), round(a[1] / mpu, 3)], "to": [round(b_[0] / mpu, 3), round(b_[1] / mpu, 3)],
            "state": "stone", "height": round(tw["height_m"] / mpu, 3), "thickness": round(tw["thickness_m"] / mpu, 3),
            "base_from": round(h_at_m(*a), 3), "base_to": round(h_at_m(*b_), 3),
        })
    # Openings wherever a street or road crosses the plateau wall (hill-way
    # heads, the castle roads), each as wide as the way plus a margin.
    toompea_openings = []
    for i in range(len(inner)):
        a, b_ = inner[i], inner[(i + 1) % len(inner)]
        hits = []
        for s in streets:
            pts = s["points_m"]
            for k in range(len(pts) - 1):
                q = seg_intersection(a, b_, tuple(pts[k]), tuple(pts[k + 1]))
                if q is not None:
                    hits.append((q, max(4.5, s["width_m"] + 1.5), s["name"] or s["name_1343"]))
        hits.sort(key=lambda h: math.dist(a, h[0]))
        merged = []
        for h in hits:
            if merged and math.dist(merged[-1][0], h[0]) < 6.0:
                continue
            merged.append(h)
        for q, width, name in merged:
            toompea_openings.append({"wall_id": "toompea_wall.%02d" % i, "at": [round(q[0] / mpu, 3), round(q[1] / mpu, 3)], "width": round(width / mpu, 3), "street": name})
    castle_ring = osm.named_footprint(tw["castle"]["osm"])
    castle_ring = simplify_ring(castle_ring, 2.0)
    castle = {
        "id": "castle.toompea", "name_1343": "Danish castle (castrum minus)", "confidence": "plausible composite (modern footprint of the later convent castle)",
        "ring": [[round(p[0] / mpu, 3), round(p[1] / mpu, 3)] for p in castle_ring],
        "wall_h": round(tw["castle"]["wall_height_m"] / mpu, 3), "tower_h": round(tw["castle"]["tower_height_m"] / mpu, 3),
        "base_h": round(min(h_at_m(*p) for p in castle_ring), 3),
    }
    # Buildings inside the castle footprint are its ranges; keep only small ones.
    buildings = [bb for bb in buildings if not pip(poly_centroid([(p[0] * mpu, p[1] * mpu) for p in bb["footprint"]]), castle_ring) or bb["landmark_id"]]

    # ---------------- water, drainage, life ----------------
    gutters = []
    for s in streets:
        if s["class"] not in ("spine", "lane", "square_edge"):
            continue
        p = s["points_m"]
        h0 = h_at_m(*p[0])
        h1 = h_at_m(*p[-1])
        pts = p if h0 >= h1 else p[::-1]
        gutters.append({"street_id": s["id"], "points": [[round(q[0] / mpu, 3), round(q[1] / mpu, 3)] for q in pts], "fall": round(abs(h0 - h1), 3)})
    pois = []
    for poi in overlay["points_of_interest"]:
        pois.append({**{k: v for k, v in poi.items() if k != "at"}, "at": [round(poi["at"][0] / mpu, 3), round(poi["at"][1] / mpu, 3)], "base_h": round(h_at_m(*poi["at"]), 3)})

    def wu(points):
        return [[round(p[0] / mpu, 3), round(p[1] / mpu, 3)] for p in points]

    # ---------------- vegetation and fields ----------------
    # Site buildings and their open reserves keep trees and shrubs off.
    # A walled close (R-1719) is a block of the town, not a plot: the seeded
    # yard-orchard loop draws only on free cells, so planting round its new
    # buildings would reshuffle every later tree, field and pasture of the
    # countryside. Planting sees the houses it replaced instead; site_closes
    # clears the close, its buildings and its reserve afterwards.
    occupied_by = buildings + [{"footprint": poly} for site, so in zip(sites, site_out) if not site.get("close") for poly in so["footprints"] + [so["reserve"]] if poly]
    occupied_by += [{"footprint": fp} for fp in replaced_footprints]
    wet_stream = stream_vegetation_exclusion(
        trace, hj["width_m"], [(v - sea_asl) / mpu for v in river_level], h_at_m, mpu)
    soil = vegetation_habitat.Soil(shore, h_at_m)
    trees, fields, pastures, woods, farmsteads, orchards = plant(overlay, occupied_by, streets, circuit_poly, toompea_edge, trace, h_at_m, mpu, x0, y0, x1, y1, wet_stream, soil)
    bushes = shrubs(overlay, occupied_by, streets, circuit_poly, toompea_edge, trace, anchors, h_at_m, mpu, x0, y0, x1, y1, wet_stream, soil)
    bushes = drop_inside([[tuple(q) for q in f["polygon"]] for f in fields + pastures + orchards], bushes)
    trees, bushes, closed_orchards = site_closes(sites, trees, bushes, mpu)
    orchards += closed_orchards
    # Last word on rooting (R-1617): no trunk on a road, no crown through a
    # bridge or harbour deck. Filtering here, after every seeded loop, keeps the
    # field, pasture and wood IDs stable.
    clearance = vegetation_habitat.Clearance(streets, bridges, mpu)
    trees = [t for t in trees if clearance.tree_ok((t[0] * mpu, t[1] * mpu))]
    bushes = [b for b in bushes if clearance.bush_ok((b[0] * mpu, b[1] * mpu))]
    harbour["fish_racks"] = kalarand_fish_racks(buildings, harbour, bridges, trees, bushes, streets, h_at_m, mpu)
    for o in orchards:
        ring = [(q[0] * mpu, q[1] * mpu) for q in o["polygon"]]
        o["trees"] = sum(1 for t in trees if pip((t[0] * mpu, t[1] * mpu), ring))

    # WB-13c: strip plots behind the houses. Read-only over everything above
    # (no RNG, nothing moved), so no existing ID or footprint changes.
    plot_obs = plot_obstacles(
        streets, circuit_poly, toompea_edge, inner, tw["thickness_m"] / 2 + 0.3, castle_ring,
        overlay["forum"]["polygon_m"], site_out, mpu)
    plots = burgher_plots(buildings, plot_obs, mpu)
    # WB-13e: rear service ranges, appended after every other building so no
    # existing ID, footprint or seeded placement changes.
    buildings.extend(plot_service_ranges(plots, trees, bushes, h_at_m, mpu))
    # WB-13f: yard items, after the service ranges that they must stay clear of.
    plot_yard_items(plots, buildings, pois, trees, bushes, h_at_m, mpu)

    for s in streets:
        s["points"] = wu(s.pop("points_m"))
        s["width"] = round(s.pop("width_m") / mpu, 3)

    plan = {
        "schema": SCHEMA,
        "snapshot": overlay["snapshot"],
        "license_notes": [osm.license, "EU-DEM v1.1 (Copernicus) via OpenTopoData", "1343 overlay: Reval Rebel authors"],
        "origin": overlay["origin"],
        "metres_per_world_unit": mpu,
        "bounds": [round(x0 / mpu, 3), round(y0 / mpu, 3), round(x1 / mpu, 3), round(y1 / mpu, 3)],
        "sea_level": 0.0,
        "height_grid": {"cell": HEIGHT_CELL_WU, "nx": nx, "ny": ny, "origin": [round(x0 / mpu, 3), round(y0 / mpu, 3)], "file": "height.json"},
        "splat": {"file": "splat.png", "px_per_unit": SPLAT_PX_PER_WU, "channels": ["paving", "packed_earth", "sand", "mud"]},
        "shoreline": wu(shore),
        "harjapea": {"points": wu(trace), "widths": [round(w_ / mpu, 3) for w_ in hj["width_m"]], "surface": round((min(river_level) - sea_asl) / mpu, 3), "surfaces": [round((v_ - sea_asl) / mpu, 3) for v_ in river_level], "confidence": hj["confidence"]},
        "moat": {"points": wu(moat_line), "width": round(mo["width_m"] / mpu, 3), "wet_fraction": mo["wet_fraction"], "confidence": mo["confidence"]},
        "toompea_edge": wu(toompea_edge),
        "forum": {"id": overlay["forum"]["id"], "name_1343": overlay["forum"]["name_1343"], "polygon": wu(overlay["forum"]["polygon_m"]), "confidence": overlay["forum"]["confidence"]},
        "circuit": [{"at": [round(a["p"][0] / mpu, 3), round(a["p"][1] / mpu, 3)], "state": a["state"], "ref": a["ref"], "tower": a["tower"], "osm": a["osm"]} for a in anchors],
        "curtains": curtains,
        "towers": towers,
        "barbicans": barbicans_out,
        "gates": gates_out,
        "toompea_walls": toompea_walls,
        "toompea_openings": toompea_openings,
        "castle": castle,
        "streets": streets,
        "buildings": buildings,
        "plots": plots,
        "sites": site_out,
        "gutters": gutters,
        "trees": trees,
        "bushes": bushes,
        "districts": [
            {"id": "district.toompea", "name": "Toompea", "name_1343": "Danish castle hill (castrum)", "polygon": wu(toompea_edge)},
            {"id": "district.lower_town", "name": "Lower Town", "name_1343": "All-linn, the burghers' town", "polygon": wu(circuit_poly)},
        ] + [
            {"id": "district." + sub["id"].split(".")[1], "name": sub["name_1343"].split(" (")[0].capitalize(), "name_1343": sub["name_1343"], "polygon": wu([tuple(q) for q in sub["polygon_m"]])}
            for sub in overlay["suburbs"]
        ],
        "fields": fields,
        "pastures": pastures,
        "orchards": orchards,
        "woods": woods,
        "farmsteads": farmsteads,
        "bridges": bridges,
        "harbour": harbour,
        "points_of_interest": pois,
        "flows": overlay["flows"],
    }

    # Deepen only the submerged bed after land-use/bridge placement. Its wet
    # margins do not move, and underwater slopes must not reshuffle countryside
    # RNG decisions (and thereby rename unrelated stable field/pasture IDs).
    height_wu -= river_lowering / mpu

    # ---------------- rasters ----------------
    q = np.round(height_wu * 100).astype(np.int64) + HEIGHT_OFFSET_CM
    q = np.clip(q, 0, 65535).astype("<u2")
    height_doc = {
        "schema": "rr.city_height.v1", "nx": nx, "ny": ny, "cell": HEIGHT_CELL_WU,
        "origin": [round(x0 / mpu, 3), round(y0 / mpu, 3)], "encoding": "uint16le_cm_offset", "offset_cm": HEIGHT_OFFSET_CM,
        "data": base64.b64encode(q.tobytes()).decode("ascii"),
    }
    splat = render_splat(plan, mpu)
    roads = render_roads(plan, mpu)
    minimap = render_minimap(plan, height_wu)
    return {"plan": plan, "height": height_doc, "splat": splat, "roads": roads, "minimap": minimap, "height_wu": height_wu, "extent_m": (x0, y0, x1, y1), "mpu": mpu,
            "plot_obstacles": plot_obs, "h_at_m": h_at_m}


SITES_DIR = ROOT / "content/world/reval_city/sites"


def load_sites():
    """ADR 0032 site manifests, in registry order (never a directory walk)."""
    registry = json.loads((SITES_DIR / "registry.json").read_text())
    return [json.loads((SITES_DIR / f"{name}.json").read_text()) for name in registry["sites"]]


def site_closes(sites, trees, bushes, mpu):
    """Walled site closes (R-1719, St Michael's nunnery): a site's `close.polygon`,
    reserve and buildings keep the generic trees and shrubs out, and its `orchards` (site-local
    polygons) are planted in rows inside it as unfenced plan orchards. Run after
    every seeded planting loop with its own per-orchard RNG, so no countryside
    field, pasture or orchard ID moves. Returns (trees, bushes, orchards)."""
    rings = []
    for site in sites:
        if site.get("close"):
            for poly in [site["close"]["polygon"], site.get("reserve", [])] + [b["footprint"] for b in site.get("buildings", [])]:
                if poly:
                    rings.append([site_to_world(site, q) for q in poly])
    trees = drop_inside(rings, trees, mpu)
    bushes = drop_inside(rings, bushes, mpu)
    out = []
    for site in sites:
        for orc in site.get("orchards", []):
            local = [tuple(q) for q in orc["polygon"]]
            rng = random.Random(int(hashlib.md5(orc["id"].encode()).hexdigest()[:8], 16))
            step = float(orc.get("step", 5.5))
            mix = orc.get("mix", ["apple", "apple", "apple", "cherry", "pear", "plum"])
            xs = [q[0] for q in local]
            zs = [q[1] for q in local]
            count = 0
            u = min(xs) + step * 0.5
            while u < max(xs):
                v = min(zs) + step * 0.5
                while v < max(zs):
                    p = (u + rng.uniform(-0.4, 0.4), v + rng.uniform(-0.4, 0.4))
                    edge = min(math.dist(p, seg_closest(p, local[k], local[(k + 1) % len(local)])) for k in range(len(local)))
                    if pip(p, local) and edge > 1.8 and rng.random() > 0.06:
                        w = site_to_world(site, p)
                        trees.append([round(w[0] / mpu, 2), round(w[1] / mpu, 2), rng.choice(mix), round(rng.uniform(0.8, 1.05), 2)])
                        count += 1
                    v += step
                u += step
            out.append({"id": orc["id"], "fence": False, "trees": count,
                        "polygon": [[round(q[0] / mpu, 2), round(q[1] / mpu, 2)] for q in (site_to_world(site, p) for p in local)]})
    return trees, bushes, out


def seg_closest(p, a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    t = max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / max(dx * dx + dy * dy, 1e-9)))
    return (a[0] + dx * t, a[1] + dy * t)


def site_to_world(site, p):
    """Site-local metres (x along the anchor rotation, z to its right) to plan metres."""
    ax, ay = site["anchor"]["at"]
    r = math.radians(site["anchor"]["rotation_deg"])
    c, s_ = math.cos(r), math.sin(r)
    return (ax + p[0] * c - p[1] * s_, ay + p[0] * s_ + p[1] * c)


def flatten_ground(height_wu, ring, level, blend, x0, y0, mpu, apron=1.0):
    """Cut or fill the heightfield inside `ring` (metres) to `level` (wu), blended
    back into the natural ground over `blend` metres with a smoothstep."""
    cell = HEIGHT_CELL_WU * mpu
    ny, nx = height_wu.shape
    xs = [p[0] for p in ring]
    ys = [p[1] for p in ring]
    m = max(blend, apron + 0.01)
    j0 = max(0, int((min(xs) - m - x0) / cell))
    j1 = min(nx - 1, int((max(xs) + m - x0) / cell) + 1)
    i0 = max(0, int((min(ys) - m - y0) / cell))
    i1 = min(ny - 1, int((max(ys) + m - y0) / cell) + 1)
    X, Y = np.meshgrid(x0 + np.arange(j0, j1 + 1) * cell, y0 + np.arange(i0, i1 + 1) * cell)
    inside = point_in_poly(X, Y, ring)
    d = np.full(X.shape, np.inf)
    for k in range(len(ring)):
        a, c = ring[k], ring[(k + 1) % len(ring)]
        dk, _ = dist_point_seg(X, Y, a[0], a[1], c[0], c[1])
        d = np.minimum(d, dk)
    # Apron at full level (1 m by default), then a smoothstep back to the
    # natural slope.
    t = np.clip((d - apron) / (m - apron), 0.0, 1.0)
    w = np.where(inside, 1.0, 1.0 - t * t * (3.0 - 2.0 * t))
    block = height_wu[i0:i1 + 1, j0:j1 + 1]
    height_wu[i0:i1 + 1, j0:j1 + 1] = block * (1.0 - w) + level * w


def grade_approach(site, appr, level, height_wu, h_at_m, x0, y0, mpu):
    """Grade a straight path from a site door down to `appr["to"]` (site-local).

    A flat landing at the terrace level runs `landing_m` out of the door, then
    the path falls linearly to the ground already at `to`, so it meets it
    without a step. Full strength across `width_m`, smoothstep back to the
    existing ground over `blend_m` on either side; nothing behind the door."""
    door = next(d for d in site["doors"] if d["id"] == appr["door"])
    mid = ((door["a"][0] + door["b"][0]) * 0.5, (door["a"][1] + door["b"][1]) * 0.5)
    a = site_to_world(site, mid)
    b = site_to_world(site, appr["to"])
    end_h = h_at_m(*b)
    half_w = appr.get("width_m", 2.5) * 0.5
    blend = appr.get("blend_m", 1.2)
    landing = appr.get("landing_m", 1.2)
    length = math.dist(a, b)
    ux, uy = (b[0] - a[0]) / length, (b[1] - a[1]) / length
    cell = HEIGHT_CELL_WU * mpu
    ny, nx = height_wu.shape
    m = half_w + blend
    j0 = max(0, int((min(a[0], b[0]) - m - x0) / cell))
    j1 = min(nx - 1, int((max(a[0], b[0]) + m - x0) / cell) + 1)
    i0 = max(0, int((min(a[1], b[1]) - m - y0) / cell))
    i1 = min(ny - 1, int((max(a[1], b[1]) + m - y0) / cell) + 1)
    X, Y = np.meshgrid(x0 + np.arange(j0, j1 + 1) * cell, y0 + np.arange(i0, i1 + 1) * cell)
    along = (X - a[0]) * ux + (Y - a[1]) * uy
    across = np.abs((X - a[0]) * uy - (Y - a[1]) * ux)
    t = np.clip((along - landing) / (length - landing), 0.0, 1.0)
    path_h = level + (end_h - level) * t
    w = 1.0 - smoothstep01(across, half_w, half_w + blend)
    w = np.where((along >= 0.0) & (along <= length), w, 0.0)
    block = height_wu[i0:i1 + 1, j0:j1 + 1]
    height_wu[i0:i1 + 1, j0:j1 + 1] = block * (1.0 - w) + path_h * w


def terrace_site(site, height_wu, h_at_m, x0, y0, mpu):
    """Level a site's terrace to the ground outside its named door and return the
    runtime record: anchor, level and world footprints (world units)."""
    ter = site["terrace"]
    door = next(d for d in site["doors"] if d["id"] == ter["level"]["door"])
    mid = ((door["a"][0] + door["b"][0]) * 0.5, (door["a"][1] + door["b"][1]) * 0.5)
    out = ter["level"].get("outside_m", 2.0)
    outside = (mid[0] - door["inward"][0] * out, mid[1] - door["inward"][1] * out)
    level = h_at_m(*site_to_world(site, outside))
    ring = [site_to_world(site, p) for p in ter["polygon"]]
    flatten_ground(height_wu, ring, level, ter.get("blend_m", 6.0), x0, y0, mpu)

    def wu(points):
        return [[round(q[0] / mpu, 3), round(q[1] / mpu, 3)] for q in points]

    return {
        "id": site["id"],
        "at": [round(site["anchor"]["at"][0] / mpu, 3), round(site["anchor"]["at"][1] / mpu, 3)],
        "rotation_deg": site["anchor"]["rotation_deg"],
        "level": round(level, 3),
        "footprints": [wu([site_to_world(site, p) for p in b["footprint"]]) for b in site.get("buildings", [])],
        "minimap_fill": [b.get("minimap_fill", "#8a4a36") for b in site.get("buildings", [])],
        "reserve": wu([site_to_world(site, p) for p in site.get("reserve", [])]),
    }


# Churches, chapels and the council hall stand on levelled terraces, as large
# buildings on a slope were built: the ground under the footprint is cut or
# filled to the level of the street at the door and blended back into the
# slope over TERRACE_BLEND_M. Without it the floor sits at the highest ground
# under a 60 m footprint and the door hangs metres above the square.
TERRACE_KINDS = ("church", "chapel", "hall")
TERRACE_MIN_SPAN_WU = 0.8
TERRACE_BLEND_M = 8.0
# Houses get the same treatment on a smaller scale: the floor is the highest
# ground under the footprint, so on a slope the street-side door sat up to a
# metre and a half above the street and the runtime filled the gap with a tall
# flight of steps. Cutting the plot to the door's street level keeps the
# threshold at 0-2 treads. A footprint spanning more than HOUSE_TERRACE_MAX_SPAN_WU
# is a merged OSM polygon or a cliff edge; levelling it would carve a quarry, so
# those keep the runtime steps.
HOUSE_TERRACE_MIN_SPAN_WU = 0.3
HOUSE_TERRACE_MAX_SPAN_WU = 3.0
HOUSE_TERRACE_BLEND_M = 3.0


def terrace_landmarks(buildings, height_wu, h_at_m, x0, y0, mpu):
    plots = []
    for b in buildings:
        if not b["door"]:
            continue
        if b["kind"] in TERRACE_KINDS:
            if b["base_span"] < TERRACE_MIN_SPAN_WU:
                continue
            blend = TERRACE_BLEND_M
        elif b["kind"] == "house":
            if not HOUSE_TERRACE_MIN_SPAN_WU <= b["base_span"] <= HOUSE_TERRACE_MAX_SPAN_WU:
                continue
            blend = HOUSE_TERRACE_BLEND_M
        else:
            continue
        ring = [(q[0] * mpu, q[1] * mpu) for q in b["footprint"]]
        dx, dy, ang = b["door"][0] * mpu, b["door"][1] * mpu, b["door"][2]
        # Every level is read from the natural ground before any plot is cut, so
        # the result does not depend on building order.
        level = h_at_m(dx + math.cos(ang) * 2.0, dy + math.sin(ang) * 2.0)
        plots.append((ring, level, blend))
    for ring, level, blend in plots:
        flatten_ground(height_wu, ring, level, blend, x0, y0, mpu)
    # In a dense row the blend of one plot lands on its neighbour's floor. Cut
    # the footprints once more with a 2.2 m apron (just over one 2 wu grid cell,
    # so every cell the bilinear lookup at a footprint corner reads is at level)
    # and almost no blend, so each floor ends up at its own door level.
    # R-2197: highest plot first. A later (lower) cut can only lower a corner
    # it shares with a higher neighbour, never raise it, so no house's floor
    # (the highest ground at its corners) climbs to the uphill neighbour's
    # level. In list order a row of houses down a slope took the upper
    # neighbour's level at the shared wall and left 1.5-2.8 m door steps.
    for ring, level, _blend in sorted(plots, key=lambda p_: -p_[1]):
        flatten_ground(height_wu, ring, level, 2.3, x0, y0, mpu, apron=2.2)
    # Bases of every building near a terrace changed: recompute them all.
    for b in buildings:
        ring = [(q[0] * mpu, q[1] * mpu) for q in b["footprint"]]
        hs = [h_at_m(p[0], p[1]) for p in ring]
        b["base_h"] = round(min(hs), 3)
        b["base_span"] = round(max(hs) - min(hs), 3)


def footprint_cells(ring, cell, margin):
    """Grid cells covered by a footprint grown by `margin` metres."""
    xs = [p[0] for p in ring]
    ys = [p[1] for p in ring]
    out = set()
    gx = np.arange(math.floor((min(xs) - margin) / cell), math.floor((max(xs) + margin) / cell) + 1)
    gy = np.arange(math.floor((min(ys) - margin) / cell), math.floor((max(ys) + margin) / cell) + 1)
    X, Y = np.meshgrid((gx + 0.5) * cell, (gy + 0.5) * cell)
    inside = point_in_poly(X, Y, ring)
    near = np.zeros(X.shape, dtype=bool)
    for i in range(len(ring)):
        a, b = ring[i], ring[(i + 1) % len(ring)]
        d, _ = dist_point_seg(X, Y, a[0], a[1], b[0], b[1])
        near |= d < margin + cell * 0.71
    for iy, ix in zip(*np.nonzero(inside | near)):
        out.add((int(gx[ix]), int(gy[iy])))
    return out


def plant(overlay, buildings, streets, circuit_poly, toompea_edge, river, h_at_m, mpu, x0, y0, x1, y1, wet_stream, soil):
    """Deterministic trees and strip fields. Trees avoid footprints and streets;
    on the sandy coastal plain (`soil`) they are pine heath."""
    rng = random.Random(4013)
    occupied = {}
    cell = 6.0

    def key(p):
        return (int(p[0] // cell), int(p[1] // cell))

    for b in buildings:
        for k in footprint_cells([(q[0] * mpu, q[1] * mpu) for q in b["footprint"]], cell, 1.5):
            occupied[k] = True
    for s in streets:
        pts = s["points_m"] if "points_m" in s else [(q[0] * mpu, q[1] * mpu) for q in s["points"]]
        for p in resample([tuple(q) for q in pts], 3.0):
            occupied[key(p)] = True
    # The forum is a market reserve kept clear for stalls and carts (R-1207).
    forum = [tuple(q) for q in overlay["forum"]["polygon_m"]]
    for k in footprint_cells(forum, cell, 6.0):
        occupied[k] = True

    static_occupied = dict(occupied)  # buildings, streets, forum: no trees yet

    def free_static(p, gap=0):
        k = key(p)
        return not any(static_occupied.get((k[0] + dx, k[1] + dy)) for dx in range(-gap, gap + 1) for dy in range(-gap, gap + 1))

    def free(p, gap=0):
        k = key(p)
        for dx in range(-gap, gap + 1):
            for dy in range(-gap, gap + 1):
                if occupied.get((k[0] + dx, k[1] + dy)):
                    return False
        return True

    trees = []

    def add(p, species, scale):
        # Reserve the candidate even when wet: rejection must not reshuffle the
        # seeded countryside sequence and rename unrelated fields/pastures.
        occupied[key(p)] = True
        # All countryside wood/orchard placements use this same guarded sink.
        if not wet_stream(p):
            trees.append([round(p[0] / mpu, 2), round(p[1] / mpu, 2), species, round(scale, 2)])

    # Yard orchards behind the street front inside the walls.
    for _ in range(1600):
        p = (rng.uniform(-260, 300), rng.uniform(-620, 320))
        if not pip(p, circuit_poly) or not free(p, 2):
            continue
        add(p, rng.choice(["apple", "apple", "cherry", "plum", "pear", "rowan"]), rng.uniform(0.75, 1.05))
    # Toompea slopes and the cathedral close: lindens, ashes, elms.
    for _ in range(1000):
        p = (rng.uniform(-560, -150), rng.uniform(-200, 330))
        if pip(p, circuit_poly) or not free(p, 1):
            continue
        h = h_at_m(*p)
        if h < 10:
            continue
        on_top = pip(p, toompea_edge)
        if on_top and rng.random() < 0.75:
            continue
        add(p, rng.choice(["linden", "ash", "elm", "maple", "oak"]), rng.uniform(0.9, 1.3))
    # Stream banks: alder and willow.
    for p in resample(river, 9.0):
        for side in (-1, 1):
            q = (p[0] + side * rng.uniform(9, 16), p[1] + rng.uniform(-4, 4))
            if free(q) and h_at_m(*q) > 0.4:
                add(q, rng.choice(["alder", "willow", "alder"]), rng.uniform(0.8, 1.2))
    # Open country: scattered oak, birch and junipers by the shore.
    for _ in range(1800):
        p = (rng.uniform(x0 + 10, x1 - 10), rng.uniform(y0 + 10, y1 - 10))
        if pip(p, circuit_poly) or pip(p, toompea_edge) or not free(p, 2):
            continue
        h = h_at_m(*p)
        if h < 0.6:
            continue
        if h < 4.0:
            if rng.random() < 0.6:
                add(p, "juniper", rng.uniform(0.6, 1.0))
            continue
        if rng.random() < 0.55:
            continue
        sp = rng.choice(["oak", "birch", "birch", "ash", "spruce", "pine"])
        # Sand grows pine: the species is re-picked from a position hash, so
        # the seeded sequence (and every later field ID) is unchanged.
        add(p, vegetation_habitat.heath_species(p) if soil.heath_ground(p) else sp, rng.uniform(0.85, 1.35))
    fields, pastures, woods, farmsteads, orchards = countryside(
        overlay, buildings, streets, circuit_poly, toompea_edge, h_at_m, mpu, x0, y0, x1, y1, free, free_static, add, rng, trees, soil
    )
    pine_heath(circuit_poly, toompea_edge, h_at_m, mpu, x0, y0, x1, y1, free, add, soil, fields + pastures + orchards, trees)
    trees.sort()
    return trees, fields, pastures, woods, farmsteads, orchards


# ---------------------------------------------------------------------------
# Countryside: farmland, pastures, woods, farmsteads (April 1343)
# ---------------------------------------------------------------------------

# Three-field system: winter grain, spring grain, fallow. Rye and barley carry
# the Estonian diet; oats feed the horses; winter wheat is a minor crop on the
# best soil near the town (docs/CANON.md diet note). Weights are per block.
CROP_WEIGHTS = [
    ("rye", "winter", 26), ("wheat", "winter", 18), ("barley", "spring", 22),
    ("oat", "spring", 14), ("pea", "spring", 4), ("flax", "spring", 3), ("fallow", "fallow", 18),
]
GARDEN_CROPS = ["cabbage", "turnip", "pea", "onion", "flax", "cabbage", "turnip"]
FARM_SUBURBS = ("karja", "harju", "toompea_foot")


def _h2(ix, iy, seed):
    h = (ix * 374761393 + iy * 668265263 + seed * 2147483647) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0


def vnoise(x, y, seed):
    ix, iy = math.floor(x), math.floor(y)
    fx, fy = x - ix, y - iy
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a, b = _h2(ix, iy, seed), _h2(ix + 1, iy, seed)
    c, d = _h2(ix, iy + 1, seed), _h2(ix + 1, iy + 1, seed)
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(x, y, seed):
    return 0.58 * vnoise(x / 300, y / 300, seed) + 0.30 * vnoise(x / 130, y / 130, seed + 1) + 0.12 * vnoise(x / 55, y / 55, seed + 2)


def drop_inside(rings, items, mpu=1.0):
    """Items ([x, y, ...] in world units) that stand in none of the rings (metres)."""
    boxes = [(min(q[0] for q in r_), min(q[1] for q in r_), max(q[0] for q in r_), max(q[1] for q in r_)) for r_ in rings]
    return [t for t in items if not any(bx[0] <= t[0] * mpu <= bx[2] and bx[1] <= t[1] * mpu <= bx[3] and pip((t[0] * mpu, t[1] * mpu), r_) for bx, r_ in zip(boxes, rings))]


def pine_heath(circuit_poly, toompea_edge, h_at_m, mpu, x0, y0, x1, y1, free, add, soil, farmland, trees):
    """A pine bor on the sandy coastal plain (R-1617): mature pines a few metres
    apart with heath glades, planted after every seeded countryside loop with
    its own RNG, so the field, pasture and wood IDs do not move."""
    hrng = random.Random(1617)
    cell = 7.0
    rings = [[tuple(q) for q in f["polygon"]] for f in farmland]
    rings = [[(q[0] * mpu, q[1] * mpu) for q in r_] for r_ in rings]
    town = [tuple(q) for q in resample(circuit_poly + [circuit_poly[0]], 8.0)]
    tx = np.array([q[0] for q in town])
    ty = np.array([q[1] for q in town])
    for gx in range(int(x0 // cell) + 4, int(x1 // cell) - 4):
        for gy in range(int(y0 // cell) + 4, int(y1 // cell) - 4):
            jx, jy, size = hrng.random(), hrng.random(), hrng.uniform(0.85, 1.25)
            p = ((gx + jx) * cell, (gy + jy) * cell)
            if not soil.heath_ground(p) or fbm(p[0], p[1], 7031) < 0.36:
                continue  # inland soil, or a heath glade
            if pip(p, circuit_poly) or pip(p, toompea_edge) or not free(p, 1):
                continue
            if float(np.min(np.hypot(tx - p[0], ty - p[1]))) < 60.0:
                continue  # the walls keep a clear field of view
            if any(pip(p, r_) for r_ in rings):
                continue
            sp = vegetation_habitat.heath_species(p, 1618)
            add(p, sp, size if sp != "juniper" else 0.9 + 0.3 * jx)


def countryside(overlay, buildings, streets, circuit_poly, toompea_edge, h_at_m, mpu, x0, y0, x1, y1, free, free_static, add, rng, trees, soil):
    """Deterministic woods, strip fields, kitchen gardens, pastures and farmsteads
    outside the walls. Woods first (they claim the damp, steep and far ground),
    then fields on dry gentle land near the town, then fenced pastures."""
    crng = random.Random(5171)
    town = [tuple(q) for q in resample(circuit_poly + [circuit_poly[0]], 8.0)]
    town += [tuple(q) for q in resample(list(toompea_edge) + [toompea_edge[0]], 8.0)]
    tx = np.array([q[0] for q in town])
    ty = np.array([q[1] for q in town])

    def dist_town(p):
        return float(np.min(np.hypot(tx - p[0], ty - p[1])))

    def slope(p, d=6.0):
        return max(abs(h_at_m(p[0] + d, p[1]) - h_at_m(p[0] - d, p[1])), abs(h_at_m(p[0], p[1] + d) - h_at_m(p[0], p[1] - d))) / (2 * d)

    def inside_town(p):
        return pip(p, circuit_poly) or pip(p, toompea_edge)

    def open_land(p, hmin=1.8, smax=0.45):
        if not (x0 + 24 < p[0] < x1 - 24 and y0 + 24 < p[1] < y1 - 24):
            return False  # keep a margin at the plan edge: the world ends there
        return h_at_m(*p) >= hmin and slope(p) < smax and not inside_town(p) and free_static(p, 1)

    # ---- woods: a coarse mask, thicker with distance from the walls ----
    cell = 12.0
    gx0, gy0 = int(x0 // cell) + 1, int(y0 // cell) + 1
    gx1, gy1 = int(x1 // cell) - 1, int(y1 // cell) - 1
    wood = {}
    for gx in range(gx0, gx1):
        for gy in range(gy0, gy1):
            p = ((gx + 0.5) * cell, (gy + 0.5) * cell)
            d = dist_town(p)
            if d < 70 or not open_land(p, 1.5, 0.55):
                continue
            far = min(max((d - 60) / 480, 0.0), 1.0)
            if fbm(p[0], p[1], 7001) > 0.50 + 0.22 * (1.0 - far) ** 1.5:
                if fbm(p[0], p[1], 7011) > 0.86:
                    continue  # glade
                wood[(gx, gy)] = True

    def in_wood(p):
        return (int(p[0] // cell), int(p[1] // cell)) in wood

    def wood_kind(p):
        return "pine_heath" if soil.heath_ground(p) else inland_wood_kind(p)

    def inland_wood_kind(p):
        h = h_at_m(*p)
        n = fbm(p[0], p[1], 7021)
        if h < 6.0:
            return "alder_birch"
        if h < 14.0 and n < 0.5:
            return "pine"
        return "spruce_pine" if n < 0.55 else ("oak_mixed" if n > 0.7 else "mixed")

    mixes = {
        "alder_birch": ["alder", "alder", "birch", "birch", "willow", "ash"],
        "pine": ["pine", "pine", "pine", "pine", "spruce", "birch", "juniper"],
        "spruce_pine": ["spruce", "spruce", "spruce", "pine", "pine", "birch"],
        "mixed": ["spruce", "pine", "birch", "birch", "oak", "ash", "linden", "alder"],
        "oak_mixed": ["oak", "oak", "linden", "ash", "elm", "maple", "birch", "hazel"],
    }
    wood_trees = 0
    for (gx, gy) in sorted(wood):
        edge = sum(1 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if (gx + dx, gy + dy) not in wood)
        for _ in range(3 if edge == 0 else 2):
            p = ((gx + crng.random()) * cell, (gy + crng.random()) * cell)
            if not free(p):
                continue
            kind = wood_kind(p)
            # Draw from the pre-R-1617 mix so the seeded sequence is unchanged;
            # heath ground then re-picks its species from a position hash.
            sp = crng.choice(mixes[inland_wood_kind(p)])
            if edge and crng.random() < 0.5:
                sp = crng.choice(["birch", "rowan", "hazel", "juniper"])
            elif kind == "pine_heath":
                sp = vegetation_habitat.heath_species(p)
            add(p, sp, crng.uniform(0.85, 1.4) if sp not in ("hazel", "juniper") else crng.uniform(0.9, 1.2))
            wood_trees += 1
    # connected wood components -> named records
    seen, woods = set(), []
    for c0 in sorted(wood):
        if c0 in seen:
            continue
        stack, comp = [c0], []
        seen.add(c0)
        while stack:
            c = stack.pop()
            comp.append(c)
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n_ = (c[0] + dx, c[1] + dy)
                if n_ in wood and n_ not in seen:
                    seen.add(n_)
                    stack.append(n_)
        if len(comp) < 6:
            continue
        mx = sum(c[0] for c in comp) / len(comp)
        my = sum(c[1] for c in comp) / len(comp)
        at = ((mx + 0.5) * cell, (my + 0.5) * cell)
        woods.append({"id": "wood.%02d" % len(woods), "kind": wood_kind(at), "at": [round(at[0] / mpu, 2), round(at[1] / mpu, 2)], "area_m2": int(len(comp) * cell * cell), "cells": len(comp)})

    taken = set()
    fcell = 6.0

    # ---- farmsteads: the farm-suburb houses, each with a yard and a fenced croft ----
    farmsteads = []
    for b in buildings:
        bid = b.get("id", "")
        if not bid.startswith("bldg.") or bid.split(".")[1] not in FARM_SUBURBS or "footprint" not in b:
            continue
        c = poly_centroid([(q[0] * mpu, q[1] * mpu) for q in b["footprint"]])
        farmsteads.append({"id": "farmstead." + bid.split(".", 1)[1], "building": bid, "at": [round(c[0] / mpu, 2), round(c[1] / mpu, 2)]})

    # ---- pastures: fenced crofts beside farmsteads, common grazing along the cattle road ----
    pastures = []

    def blob(c, r, seed):
        prng = random.Random(seed)
        k = 9
        ph = prng.uniform(0, math.tau)
        return [(c[0] + math.cos(ph + math.tau * i / k) * r * prng.uniform(0.78, 1.15), c[1] + math.sin(ph + math.tau * i / k) * r * prng.uniform(0.78, 1.15)) for i in range(k)]

    def pasture_ok(ring):
        c = poly_centroid(ring)
        for q in ring + [c]:
            if in_wood(q) or not open_land(q, 1.0, 0.3) or dist_town(q) < 25:
                return False
        return not (footprint_cells(ring, fcell, 0.5) & taken)

    def add_pasture(kind, c, r, stock, fence, seed):
        ring = blob(c, r, seed)
        if not pasture_ok(ring):
            return False
        taken.update(footprint_cells(ring, fcell, 0.5))
        pastures.append({"id": "pasture.%02d" % len(pastures), "kind": kind, "fence": fence, "stock": stock,
                         "polygon": [[round(q[0] / mpu, 2), round(q[1] / mpu, 2)] for q in ring]})
        return True

    karja = next(r_ for r_ in overlay["streets"]["extramural_roads"] if r_["id"] == "road.karja")
    for i, q in enumerate(resample([tuple(q) for q in karja["points_m"]], 70.0)[2:]):
        for side in (-1, 1):
            for attempt in range(8):
                c = (q[0] + side * crng.uniform(45, 120), q[1] + crng.uniform(-30, 30))
                if add_pasture("common", c, crng.uniform(30, 48), [{"species": "cow", "count": 4}, {"species": "sheep", "count": 5}], False, 100 + i * 20 + attempt):
                    break
    for fs in farmsteads:
        mix = crng.choice([[{"species": "cow", "count": 2}, {"species": "goat", "count": 2}], [{"species": "sheep", "count": 4}], [{"species": "horse", "count": 1}, {"species": "cow", "count": 1}]])
        for attempt in range(12):
            a = crng.uniform(0, math.tau)
            c = (fs["at"][0] * mpu + math.cos(a) * crng.uniform(26, 50), fs["at"][1] * mpu + math.sin(a) * crng.uniform(26, 50))
            if add_pasture("croft", c, crng.uniform(13, 21), mix, True, 300 + len(pastures) * 13 + attempt):
                break
    # damp low meadows by the streams and the shore: sheep and geese
    for i in range(300):
        p = (crng.uniform(x0 + 40, x1 - 40), crng.uniform(y0 + 40, y1 - 40))
        d = dist_town(p)
        if 60 < d < 600 and 1.2 < h_at_m(*p) < 6.0:
            if sum(1 for pa in pastures if pa["kind"] == "meadow") < 10:
                add_pasture("meadow", p, crng.uniform(24, 40), [{"species": "sheep", "count": 3}, {"species": "goose", "count": 3}], False, 500 + i)
    # ---- orchards: fenced fruit gardens (apple, cherry, plum, pear) ----
    # Claimed before the fields so strips go round them. One beside most
    # farmsteads, plus a few on dry ground near the walls (town gardeners).
    # Trees stand in a regular grid with a little jitter, as planted rows do.
    orchards = []
    orchard_trees = []

    def add_orchard(c, ang, w, L, seed):
        ring = strip_ring_o(c, ang, w, L)
        pts = ring + [poly_centroid(ring)]
        if any(in_wood(q) or not open_land(q, 1.5, 0.3) or dist_town(q) < 28 for q in pts) or (footprint_cells(ring, fcell, 0.5) & taken):
            return False
        taken.update(footprint_cells(ring, fcell, 0.5))
        orng = random.Random(seed)
        # one or two dominant kinds per orchard; apple leads (northern orchard mix)
        mix = orng.choice([["apple"] * 5 + ["cherry"], ["apple"] * 3 + ["pear", "plum"], ["cherry"] * 3 + ["apple"] * 2 + ["plum"], ["apple"] * 4 + ["cherry", "plum", "pear"]])
        ca, sa = math.cos(ang), math.sin(ang)
        step = orng.uniform(5.2, 6.4)
        n_along, n_across = int((L - 4.0) / step), int((w - 4.0) / step)
        count = 0
        for i in range(n_along):
            for j in range(n_across):
                if orng.random() < 0.08:
                    continue  # a lost or felled tree
                u = (i - (n_along - 1) / 2) * step + orng.uniform(-0.5, 0.5)
                v = (j - (n_across - 1) / 2) * step + orng.uniform(-0.5, 0.5)
                orchard_trees.append(((c[0] + ca * u - sa * v, c[1] + sa * u + ca * v), orng.choice(mix), orng.uniform(0.75, 1.05)))
                count += 1
        if count < 4:
            return False
        orchards.append({"id": "orchard.%02d" % len(orchards), "fence": True, "trees": count,
                         "polygon": [[round(q[0] / mpu, 2), round(q[1] / mpu, 2)] for q in ring]})
        return True

    def strip_ring_o(c, ang, w, L):
        ca, sa = math.cos(ang), math.sin(ang)
        return [(c[0] + ca * sx * L / 2 - sa * sy * w / 2, c[1] + sa * sx * L / 2 + ca * sy * w / 2) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]

    orng_ = random.Random(6203)
    for fs in farmsteads:
        if orng_.random() < 0.3:
            continue
        for attempt in range(14):
            a = orng_.uniform(0, math.tau)
            c = (fs["at"][0] * mpu + math.cos(a) * orng_.uniform(34, 58), fs["at"][1] * mpu + math.sin(a) * orng_.uniform(34, 58))
            if add_orchard(c, orng_.uniform(0, math.pi), orng_.uniform(24, 34), orng_.uniform(30, 44), 7000 + len(orchards) * 31 + attempt):
                break
    for i in range(400):
        p = (orng_.uniform(x0 + 40, x1 - 40), orng_.uniform(y0 + 40, y1 - 40))
        if 45 < dist_town(p) < 260 and len(orchards) < 30:
            add_orchard(p, orng_.uniform(0, math.pi), orng_.uniform(26, 38), orng_.uniform(34, 50), 9000 + i)

    # ---- farmland: strip blocks on dry, gentle ground near the town ----
    def strip_ring(c, ang, w, L):
        ca, sa = math.cos(ang), math.sin(ang)
        return [(c[0] + ca * sx * L / 2 - sa * sy * w / 2, c[1] + sa * sx * L / 2 + ca * sy * w / 2) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]

    def ring_ok(ring):
        c = poly_centroid(ring)
        pts = ring + [c] + [((ring[i][0] + ring[(i + 1) % 4][0]) / 2, (ring[i][1] + ring[(i + 1) % 4][1]) / 2) for i in range(4)]
        for q in pts:
            if in_wood(q) or not open_land(q, 2.0, 0.22) or dist_town(q) < 30:
                return False
        return not (footprint_cells(ring, fcell, 0.5) & taken)

    def pick_crop():
        total = sum(w_ for _, _, w_ in CROP_WEIGHTS)
        r = crng.uniform(0, total)
        for crop, sow, w_ in CROP_WEIGHTS:
            r -= w_
            if r <= 0:
                return crop, sow
        return "rye", "winter"

    fields = []
    cands = []
    for gx in range(int(x0 // 40), int(x1 // 40) + 1):
        for gy in range(int(y0 // 40), int(y1 // 40) + 1):
            p = ((gx + 0.5) * 40 + crng.uniform(-12, 12), (gy + 0.5) * 40 + crng.uniform(-12, 12))
            d = dist_town(p)
            if 40 <= d <= 620 and crng.random() < 0.95 - 0.7 * min(d / 620, 1.0):
                cands.append((d, p))
    cands.sort()
    for bid, (d, p) in enumerate(cands):
        if not open_land(p, 2.0, 0.2) or in_wood(p):
            continue
        garden = d < 230 and crng.random() < 0.4
        ang = (vnoise(p[0] / 380, p[1] / 380, 7031) - 0.5) * 2.4 + 0.2
        block_crop, block_sow = pick_crop()
        n = crng.randint(3, 5) if garden else crng.randint(4, 8)
        placed = 0
        for k in range(n):
            w = crng.uniform(7, 11) if garden else crng.uniform(14, 24)
            L = crng.uniform(28, 48) if garden else crng.uniform(80, 150)
            off = (k - n / 2) * (w + 2.0)
            c = (p[0] + math.cos(ang + math.pi / 2) * off, p[1] + math.sin(ang + math.pi / 2) * off)
            ring = strip_ring(c, ang, w, L)
            if not ring_ok(ring):
                continue
            taken |= footprint_cells(ring, fcell, 0.5)
            if garden:
                crop, sow = crng.choice(GARDEN_CROPS), "garden"
            elif crng.random() < 0.75:
                crop, sow = block_crop, block_sow
            else:
                crop, sow = pick_crop()
            fields.append({
                "id": "field.%02d.%d" % (bid, placed), "crop": crop, "sowing": sow,
                "ploughed": crop != "fallow", "angle": round(ang, 4),
                "polygon": [[round(q[0] / mpu, 2), round(q[1] / mpu, 2)] for q in ring],
            })
            placed += 1

    # no trees stand in a field or pasture
    rings = [[(q[0] * mpu, q[1] * mpu) for q in f["polygon"]] for f in fields + pastures + orchards]
    trees[:] = drop_inside(rings, trees, mpu)
    # the orchard's own trees go in after the clearing above
    for p, sp, sc in orchard_trees:
        add(p, sp, sc)
    return fields, pastures, woods, farmsteads, orchards



# ---------------------------------------------------------------------------
# Rural dwelling plan (R-1929, docs/SYSTEMS/FARMLAND.md "Rural dwelling plan")
# ---------------------------------------------------------------------------

# Heated share of a barn-dwelling's length: the same 38/62 seam as the map-view
# facade (MapViewRuralDwellingModels.ROOM_SHARE); EVM gives a rehetuba of 25-40 m2
# beside a threshing floor about twice as big. Never below RURAL_MIN_SHARE when the
# seam has to step clear of the outer door.
RURAL_ROOM_SHARE = 0.38
RURAL_MIN_SHARE = 0.3
# Low doors (a 1343 smoke room had a low door with a high sill) that still pass
# Kalev's 1 m collision capsule; the inner door of the log partition is lower.
RURAL_INNER_DOOR = (1.2, 1.65)
# Broad threshing gate: width clamp of the map-view work gate, height under the eave.
RURAL_GATE_MIN, RURAL_GATE_MAX, RURAL_GATE_H = 1.75, 2.7, 2.32
# Heap oven (kerisahi) plan side in metres; the cottage stove is the smaller one.
RURAL_OVEN = {"smoke_cottage": 1.5, "barn_dwelling": 1.8}
RURAL_WALL = 0.32  # CityBuildingBuilder.TIMBER_WALL


def _fit_oven(ring, centre, size, mouth, clear):
    """Slide the oven square toward the room centre until every corner keeps
    `clear` from every wall line: farm houses have one nudged corner (up to
    0.6 m) and the room is the footprint minus the wall."""
    c = poly_centroid(ring)
    f = (math.cos(mouth), math.sin(mouth))
    s_ = (-f[1], f[0])
    h = size / 2

    def ok(p):
        for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            q = (p[0] + (f[0] * sx + s_[0] * sy) * h, p[1] + (f[1] * sx + s_[1] * sy) * h)
            if not pip(q, ring):
                return False
            for i in range(len(ring)):
                a, b = ring[i], ring[(i + 1) % len(ring)]
                L2 = (b[0] - a[0]) ** 2 + (b[1] - a[1]) ** 2
                t = max(0.0, min(1.0, ((q[0] - a[0]) * (b[0] - a[0]) + (q[1] - a[1]) * (b[1] - a[1])) / max(L2, 1e-9)))
                if math.dist(q, (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)) < clear:
                    return False
        return True

    p = centre
    for _ in range(80):
        if ok(p):
            return p
        d = math.dist(p, c)
        if d < 0.05:
            break
        p = (p[0] + (c[0] - p[0]) * 0.05 / d, p[1] + (c[1] - p[1]) * 0.05 / d)
    return p


def rural_plan(rec, form, mpu):
    """Declarative plan of a 1343 smoke dwelling, computed from the record's final
    footprint, ridge and door (run after fix_blocked_doors). `smoke_cottage`: one
    heated room with a heap oven in the back corner. `barn_dwelling`: a log
    partition across the ridge axis splits a heated bay (oven in its back corner,
    mouth to the front wall) from a threshing bay that holds the outer door, a
    broad yard-side gate and the low inner door to the warm room. Coordinates are
    world units like the footprint; new parts carry stable ids <bid>.oven,
    <bid>.inner_door, <bid>.gate."""
    ring = [tuple(q) for q in rec["footprint"]]
    c = poly_centroid(ring)
    ra = float(rec["ridge_angle"])
    u = (math.cos(ra), math.sin(ra))
    v = (-u[1], u[0])
    dot = lambda p, d: (p[0] - c[0]) * d[0] + (p[1] - c[1]) * d[1]
    at = lambda s, t: (c[0] + u[0] * s + v[0] * t, c[1] + u[1] * s + v[1] * t)
    lo, hi = min(dot(q, u) for q in ring), max(dot(q, u) for q in ring)
    door = rec.get("door")
    # Front = the long side the door (else the yard) faces; the oven mouth looks there.
    if door:
        side = 1.0 if math.cos(door[2]) * v[0] + math.sin(door[2]) * v[1] >= 0 else -1.0
        door_s = dot((door[0], door[1]), u)
        on_long = abs(math.cos(door[2]) * u[0] + math.sin(door[2]) * u[1]) < 0.5
    else:
        side, door_s, on_long = 1.0, 0.0, False
    size = RURAL_OVEN[form] / mpu
    inset = (RURAL_WALL + 0.08) / mpu + size / 2
    vmin, vmax = min(dot(q, v) for q in ring), max(dot(q, v) for q in ring)
    front_v = vmax if side > 0 else vmin
    back_v = vmin if side > 0 else vmax
    # The far end from the door along the ridge (ties go to the + end).
    end = -1.0 if door_s > 0 else 1.0
    heated_edge = hi if end > 0 else lo
    plan = {"form": form}
    if form == "smoke_cottage":
        # Back corner at the far end; the mouth looks to the front wall, or
        # down the room when the door is in a gable.
        centre = at(heated_edge - end * inset, back_v + side * inset)
        mouth = (v[0] * side, v[1] * side) if (on_long or not door) else (-u[0] * end, -u[1] * end)
        centre = _fit_oven(ring, centre, size, math.atan2(mouth[1], mouth[0]), (RURAL_WALL + 0.1) / mpu)
        plan["oven"] = {"id": rec["id"] + ".oven", "at": [round(centre[0], 3), round(centre[1], 3)],
                        "size": round(size, 3), "mouth": round(math.atan2(mouth[1], mouth[0]), 4)}
        return plan
    # Barn-dwelling: the heated end is the one away from the outer door.
    length = hi - lo
    share = RURAL_ROOM_SHARE
    seam_s = heated_edge - end * share * length
    clear = (RURAL_INNER_DOOR[0] / 2 + 0.9) / mpu
    if door and on_long and (seam_s - door_s) * end < clear:
        seam_s = door_s + end * clear
        share = max(RURAL_MIN_SHARE, (heated_edge - seam_s) * end / length)
        seam_s = heated_edge - end * share * length
    seam = [at(seam_s, back_v - side * 0.5), at(seam_s, front_v + side * 0.5)]
    # Inner door toward the front, so the walk from the outer door is short and
    # the oven keeps the back corner.
    inner = at(seam_s, back_v + (front_v - back_v) * 0.72)
    # Gate on the front wall of the threshing bay, in the longer stretch the outer
    # door leaves free (a door on a gable leaves the whole front wall).
    t_lo, t_hi = (lo, seam_s) if end > 0 else (seam_s, hi)
    margin = 0.4 / mpu
    spans = [(t_lo + margin, t_hi - margin)]
    if door and on_long:
        half = RURAL_INNER_DOOR[0] / 2 / mpu + margin
        spans = [(t_lo + margin, door_s - half), (door_s + half, t_hi - margin)]
    g0, g1 = max(spans, key=lambda s: s[1] - s[0])
    width = min(max(length * mpu * 0.32, RURAL_GATE_MIN), RURAL_GATE_MAX) / mpu
    width = max(min(width, g1 - g0), 0.0)
    gate_c = at((g0 + g1) / 2, front_v)
    # Under the eave with room for the lintel log (0.16 m) above the leaves.
    gate_h = min(RURAL_GATE_H, float(rec["wall_h"]) * mpu - 0.35) / mpu
    oven_s = heated_edge - end * inset
    oven_c = _fit_oven(ring, at(oven_s, back_v + side * inset), size, math.atan2(v[1] * side, v[0] * side), (RURAL_WALL + 0.1) / mpu)
    plan.update({
        "share": round(share, 4), "heated_end": int(end),
        "seam": [[round(p[0], 3), round(p[1], 3)] for p in seam],
        "inner_door": {"id": rec["id"] + ".inner_door", "at": [round(inner[0], 3), round(inner[1], 3)],
                       "w": round(RURAL_INNER_DOOR[0] / mpu, 3), "h": round(RURAL_INNER_DOOR[1] / mpu, 3)},
        "gate": {"id": rec["id"] + ".gate", "at": [round(gate_c[0], 3), round(gate_c[1], 3), round(math.atan2(v[1] * side, v[0] * side), 4)],
                 "w": round(width, 3), "h": round(gate_h, 3)},
        "oven": {"id": rec["id"] + ".oven", "at": [round(oven_c[0], 3), round(oven_c[1], 3)],
                 "size": round(size, 3), "mouth": round(math.atan2(v[1] * side, v[0] * side), 4)},
    })
    if width < RURAL_GATE_MIN / mpu:
        # Too short a threshing bay for a cart gate: keep the plan, drop the gate.
        del plan["gate"]
    return plan


# ---------------------------------------------------------------------------
# Farm outbuildings (history/dossiers/architecture/rural-smoke-dwelling-and-farmstead-1343.md)
# ---------------------------------------------------------------------------

# type -> (length m, depth m, wall height m, roof pitch deg, door). Sizes keep the
# silhouettes apart: the barn-dwelling is the long, high log mass; the byre is
# low and long; pigsty and hen house are knee-high sheds. No rabbit hutches: no
# domestic rabbit is evidenced in 1343 Estonia (dossier open question).
OUTBUILDING_TYPES = {
    "barn_dwelling": ((14.0, 18.0), (6.8, 8.0), 2.9, 54, "door"),
    "barn": ((10.0, 14.0), (6.0, 7.0), 2.7, 52, None),
    "byre": ((8.0, 10.5), (4.6, 5.4), 1.9, 46, "door"),
    "sheep_shed": ((5.5, 7.0), (3.6, 4.4), 1.7, 44, "door"),
    "pigsty": ((3.4, 4.4), (2.5, 3.1), 1.25, 38, "door"),
    "hen_house": ((2.2, 2.8), (1.9, 2.3), 1.1, 40, None),
    "store": ((3.8, 4.6), (3.3, 3.9), 2.2, 50, "door"),
    # Burgher rear service ranges (WB-13e, R-1415; docs/tasks/world/WB-13_burgher_plot_prefab.md
    # element table). aux_dwelling is H05's mid-14th-century round-log building with
    # a dirt floor; the kitchen shed is the rear-yard alternative to the living-bay hearth.
    "workshop": ((4.6, 6.0), (3.4, 4.0), 2.3, 46, "door"),
    "aux_dwelling": ((4.2, 5.4), (3.6, 4.2), 2.1, 48, "door"),
    "kitchen_shed": ((3.0, 3.8), (2.6, 3.2), 2.0, 44, "door"),
    # Harbour (history/dossiers/topography/harbour-and-shoreline.md, kalamaja-fishing-shore-1343.md)
    "cargo_shed": ((8.0, 11.0), (4.6, 5.6), 2.4, 32, None),
    "smoke_shed": ((3.8, 4.8), (2.8, 3.4), 1.8, 38, "door"),
    "salt_shed": ((4.0, 5.0), (3.0, 3.6), 1.9, 36, "door"),
}
# What a farmstead keeps by wealth tier (hash of its house id): grain farm with a
# barn-dwelling, ordinary farm, poor croft.
FARM_TIERS = [
    ["barn_dwelling", "byre", "pigsty", "hen_house", "store"],
    ["barn", "byre", "hen_house", "pigsty"],
    ["barn", "sheep_shed", "hen_house"],
    ["sheep_shed", "hen_house", "pigsty"],
    ["hen_house", "pigsty"],
]


def outbuilding_record(bid, typ, cx, cy, axis, L, D, face, h_at_m, mpu, street_id, confidence, extra=None):
    """One non-enterable outbuilding of OUTBUILDING_TYPES at (cx, cy) metres."""
    _, _, wall, pitch, door_kind = OUTBUILDING_TYPES[typ]
    ring = [(cx + math.cos(axis) * sx * L / 2 - math.sin(axis) * sy * D / 2, cy + math.sin(axis) * sx * L / 2 + math.cos(axis) * sy * D / 2) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    door = None
    if door_kind:
        d = door_on_edge(ring, face)
        door = [round(d[0] / mpu, 3), round(d[1] / mpu, 3), round(d[2], 4)]
    hs = [h_at_m(q[0], q[1]) for q in ring]
    rec = {
        "id": bid, "kind": "outbuilding", "type": typ, "name_1343": "", "landmark_id": "", "confidence": confidence,
        "footprint": [[round(q[0] / mpu, 3), round(q[1] / mpu, 3)] for q in ring],
        "base_h": round(min(hs), 3), "base_span": round(max(hs) - min(hs), 3), "wall_h": round(wall / mpu, 3),
        "roof": "thatch", "roof_pitch_deg": pitch, "ridge_angle": round(axis if L >= D else axis + math.pi / 2, 4),
        "material": "log", "street_id": street_id, "door": door, "enterable": False, "openings": False, "tower_h": 0.0,
    }
    rec.update(extra or {})
    return rec


def farm_outbuildings(farm_houses, buildings, h_at_m, nearest_street, mpu):
    """Deterministic yard buildings round every farm-suburb house: kind
    "outbuilding", never enterable, so the census and doors ignore them."""
    out = []
    taken = [(poly_centroid([(q[0] * mpu, q[1] * mpu) for q in b["footprint"]]), 9.0 if b.get("kind") == "house" else 5.0) for b in buildings]
    for hid, (hx, hy), ang, street_id, conf in farm_houses:
        rng = random.Random(hash_int(hid) ^ 0x5F3)
        tier = FARM_TIERS[hash_int(hid + "tier") % len(FARM_TIERS)]
        for n, typ in enumerate(tier):
            (lmin, lmax), (dmin, dmax), _, _, _ = OUTBUILDING_TYPES[typ]
            L, D = rng.uniform(lmin, lmax), rng.uniform(dmin, dmax)
            radius = math.hypot(L, D) / 2
            for attempt in range(40):
                a = rng.uniform(0, math.tau)
                dist = rng.uniform(11, 26) + radius * 0.5 + attempt * 0.4
                cx, cy = hx + math.cos(a) * dist, hy + math.sin(a) * dist
                if h_at_m(cx, cy) < 0.6:
                    continue
                if any(math.dist((cx, cy), t[0]) < t[1] + radius + 1.5 for t in taken):
                    continue
                d_street, foot, seg = nearest_street((cx, cy))
                if d_street < 5.5 + radius * 0.4:
                    continue
                axis = ang + rng.choice([0.0, math.pi / 2]) + rng.uniform(-0.18, 0.18)
                ring = [(cx + math.cos(axis) * sx * L / 2 - math.sin(axis) * sy * D / 2, cy + math.sin(axis) * sx * L / 2 + math.cos(axis) * sy * D / 2) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
                if min(h_at_m(q[0], q[1]) for q in ring) < 0.5:
                    continue
                taken.append(((cx, cy), radius))
                out.append(outbuilding_record(
                    "bldg.%s.%s%d" % (hid.split(".", 1)[1], typ.replace("_", ""), n), typ, cx, cy, axis, L, D, (hx, hy), h_at_m, mpu, street_id,
                    "plausible composite (rural-smoke-dwelling-and-farmstead-1343 dossier); %s" % conf,
                    {"farmstead": "farmstead." + hid.split(".", 1)[1]},
                ))
                break
    return out



def shore_march(h_at_m, x, y, dx, dy, limit=160.0):
    """Walk from (x, y) along (dx, dy) until the ground drops under the sea; returns
    the last dry point (metres)."""
    last = (x, y)
    t = 0.0
    while t < limit:
        px, py = x + dx * t, y + dy * t
        if h_at_m(px, py) < 0.2:
            return last
        last = (px, py)
        t += 1.0
    return last


# Kalamaja fishing beach frame. The 1343 shore runs northwest from the fish landing
# along Kalarand (reval_1343_overlay.json sea.shoreline_note), so the beach layout
# is authored in shore-local axes instead of map north/east: KJ_SEA points out to
# sea (northeast), KJ_ALONG runs along the beach (southeast), KJ_ROT turns a
# map-east angle into the along-beach one.
KJ_SEA = (0.8, -0.6)
KJ_ALONG = (0.6, 0.8)
KJ_ROT = math.atan2(KJ_ALONG[1], KJ_ALONG[0])
# Inland stations of the three beach decks, northwest to southeast, ~60 m behind the waterline.
KJ_STATIONS = ((37.0, -877.0), (82.0, -817.0), (127.0, -757.0))


def kj(p, along, inland):
    """Offset point p by metres along the Kalamaja beach and inland from it."""
    return (p[0] + KJ_ALONG[0] * along - KJ_SEA[0] * inland, p[1] + KJ_ALONG[1] * along - KJ_SEA[1] * inland)


def harbour_features(buildings, h_at_m, nearest_street, mpu):
    """Merchant landing below the Coastal Gate and the Kalamaja fishing shore:
    short timber jetties and beach decks (walkable, like bridges), one treadwheel
    crane, cargo sheds, three net yards, smoke and salt sheds, a boatwright
    ground and small clinker boats on the sand. No stone quay, no foregate."""
    hrng = random.Random(1343_77)
    taken = [(poly_centroid([(q[0] * mpu, q[1] * mpu) for q in b["footprint"]]), 9.0 if b.get("kind") == "house" else 5.0) for b in buildings]
    out_b, decks, harbour = [], [], {"crane": None, "net_yards": [], "boats": [], "stacks": [], "boatwright": None, "landings": []}

    def place(bid, typ, around, spread, face, conf, shore_dir=None, min_h=0.7):
        (lmin, lmax), (dmin, dmax), _, _, _ = OUTBUILDING_TYPES[typ]
        L, D = hrng.uniform(lmin, lmax), hrng.uniform(dmin, dmax)
        radius = math.hypot(L, D) / 2
        for attempt in range(80):
            cx = around[0] + hrng.uniform(-spread, spread)
            cy = around[1] + hrng.uniform(-spread, spread)
            if h_at_m(cx, cy) < min_h or any(math.dist((cx, cy), t[0]) < t[1] + radius + 1.2 for t in taken):
                continue
            d_street, _, seg = nearest_street((cx, cy))
            if d_street < 5.0 + radius * 0.4:
                continue
            axis = shore_dir if shore_dir is not None else hrng.uniform(0, math.pi)
            ring_h = [h_at_m(cx + math.cos(axis) * sx * L / 2, cy + math.sin(axis) * sx * L / 2) for sx in (-1, 1)]
            if min(ring_h) < min_h - 0.1:
                continue
            taken.append(((cx, cy), radius))
            out_b.append(outbuilding_record(bid, typ, cx, cy, axis, L, D, face, h_at_m, mpu, seg[2]["id"], conf))
            return (cx, cy)
        return None

    def deck(did, kind, start, direction, length, width, conf):
        ang = math.atan2(direction[1], direction[0])
        level = max(h_at_m(*start), 0.8)
        mid = (start[0] + direction[0] * length / 2, start[1] + direction[1] * length / 2)
        decks.append({"id": did, "road": "", "kind": kind, "at": [round(mid[0] / mpu, 2), round(mid[1] / mpu, 2)], "angle": round(ang, 4),
                      "length": round(length / mpu, 2), "width": round(width / mpu, 2), "ha": round(level, 3), "hb": round(level, 3), "rails": False,
                      "confidence": conf})

    conf = "plausible composite (harbour-and-shoreline / kalamaja-fishing-shore-1343 dossiers)"
    # ---- merchant landing under the Coastal Gate: two short timber jetties, one crane ----
    north = (0.0, -1.0)
    shore = {}
    for name, x in (("a", 204.0), ("b", 252.0)):
        s_ = shore_march(h_at_m, x, -600.0, *north)
        shore[name] = s_
        start = (s_[0], s_[1] + 4.0)
        deck("jetty.coastal.%s" % name, "jetty", start, north, 15.0 if name == "a" else 10.5, 2.4, conf + "; short timber jetty, not a continuous dressed-stone quay")
    mid = shore_march(h_at_m, 228.0, -600.0, *north)
    harbour["crane"] = {"id": "crane.coastal", "at": [round(mid[0] / mpu, 2), round(mid[1] / mpu, 2)], "angle": round(-math.pi / 2, 4), "confidence": "plausible composite (one reversible treadwheel crane; no Reval-specific attestation)"}
    taken.append(((mid[0], mid[1]), 5.0))
    for i in range(3):
        place("bldg.coastal.cargoshed%d" % i, "cargo_shed", (228.0 + (i - 1) * 24, mid[1] + 14 + hrng.uniform(-2, 3)), 9.0, (228.0, mid[1]), conf + "; plank cargo shed", shore_dir=0.04, min_h=0.45)
    for i in range(6):
        harbour["stacks"].append({"id": "stack.coastal.%d" % i, "kind": ["barrel", "barrel", "bale", "crate"][i % 4], "at": [round(mid[0] + hrng.uniform(-14, 14), 2), round(mid[1] + hrng.uniform(1, 7), 2)]})
    # ---- Kalamaja fishing shore: three beach decks, three net yards, sheds, boats ----
    for k, station in enumerate(KJ_STATIONS):
        s_ = shore_march(h_at_m, *station, *KJ_SEA)
        harbour["landings"].append([round(s_[0], 2), round(s_[1], 2)])
        deck("jetty.kalamaja.%d" % k, "beach_deck", kj(s_, 0.0, 3.0), KJ_SEA, 7.0, 1.8, conf + "; short timber beach deck")
        yard_c = kj(s_, 9.0, 12.0 + hrng.uniform(0, 4))
        if h_at_m(*yard_c) > 0.7:
            # R-1640: two long pole racks per yard (11 m and 9.5 m), one net
            # draped over each, instead of four 3 m strips. Fixed offsets, no
            # hrng draw, so every later seeded placement keeps its position.
            rack_a, rack_b = kj(yard_c, 0.0, -2.0), kj(yard_c, 0.6, 1.9)
            racks = [[round(rack_a[0], 2), round(rack_a[1], 2), round(KJ_ROT, 4), 11.0],
                     [round(rack_b[0], 2), round(rack_b[1], 2), round(KJ_ROT, 4), 9.5]]
            ring = [kj(yard_c, sx * 7.5, sy * 4.5) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
            harbour["net_yards"].append({"id": "netyard.%d" % k, "polygon": [[round(q[0] / mpu, 2), round(q[1] / mpu, 2)] for q in ring], "racks": [[round(r_[0] / mpu, 2), round(r_[1] / mpu, 2), r_[2], round(r_[3] / mpu, 2)] for r_ in racks]})
            taken.append((yard_c, 8.0))
    mid_k = shore_march(h_at_m, *KJ_STATIONS[1], *KJ_SEA)
    place("bldg.kalamaja.smokeshed0", "smoke_shed", kj(mid_k, -24, 14), 6.0, mid_k, conf + "; timber smoke rack under a low roof", shore_dir=KJ_ROT)
    place("bldg.kalamaja.smokeshed1", "smoke_shed", kj(mid_k, 30, 14), 6.0, mid_k, conf, shore_dir=KJ_ROT)
    place("bldg.kalamaja.saltshed0", "salt_shed", kj(mid_k, 4, 22), 6.0, mid_k, conf + "; imported Hanseatic salt", shore_dir=KJ_ROT)
    bw = kj(mid_k, -55, 10)
    harbour["boatwright"] = {"id": "boatwright.kalamaja", "at": [round(bw[0] / mpu, 2), round(bw[1] / mpu, 2)], "confidence": conf}
    taken.append((bw, 7.0))
    for i in range(8):
        k = i % 3
        base = shore_march(h_at_m, *kj(KJ_STATIONS[k], hrng.uniform(-30, 30), 0.0), *KJ_SEA)
        p = kj(base, hrng.uniform(-4, 4), hrng.uniform(0.5, 3.0))
        harbour["boats"].append({"id": "boat.kalamaja.%d" % i, "type": "skiff" if i % 3 == 2 else "clinker", "at": [round(p[0] / mpu, 2), round(p[1] / mpu, 2)], "angle": round(hrng.uniform(-0.5, 0.5) + math.pi / 2 + KJ_ROT, 3), "lift": round(max(h_at_m(*p), 0.0), 3)})
    # Boats turned over for tarring, on trestles by the boatwright ground and a net yard.
    for i, (bx, by) in enumerate((kj(bw, 12, 4), kj(shore_march(h_at_m, *kj(KJ_STATIONS[1], 22, 0.0), *KJ_SEA), 0.0, 9))):
        harbour["boats"].append({"id": "boat.kalamaja.up%d" % i, "type": "overturned", "at": [round(bx / mpu, 2), round(by / mpu, 2)], "angle": round(hrng.uniform(-0.3, 0.3) + KJ_ROT, 3), "lift": round(max(h_at_m(bx, by), 0.5), 3)})
    # Cargo lighters at the jetty tips of the merchant landing: cargo goes by lighter
    # and cart through the shallows to the cogs in the roadstead.
    for name, j in (("a", decks[0]), ("b", decks[1])):
        tip = (j["at"][0] * mpu, j["at"][1] * mpu - j["length"] * mpu / 2 - 7.0)
        for n in range(2 if name == "a" else 1):
            harbour["boats"].append({"id": "lighter.coastal.%s%d" % (name, n), "type": "lighter", "at": [round(tip[0] / mpu + n * 10.0 - 4.0, 2), round(tip[1] / mpu - n * 8.0 - 3.0, 2)], "angle": round(math.pi / 2 + hrng.uniform(-0.2, 0.2), 3), "lift": 0.0})
    return out_b, decks, harbour



def kalarand_fish_racks(buildings, harbour, bridges, trees, bushes, streets, h_at_m, mpu):
    """R-1640: fish drying racks beside the shore-side Kalarand huts, on the open
    ground between the huts and the beach (kalamaja-fishing-shore-1343.md:
    drying preferred for lean spring herring). Runs after vegetation with its own
    RNG, so no earlier id or position moves; racks dodge trees and bushes instead
    of displacing them. Rack: id, at (centre), angle (pole axis, radians, roughly
    shore-parallel), length (m), variant (a fish_rack.* style variant)."""
    rng = random.Random(1343_1640)
    conf = "plausible composite (kalamaja-fishing-shore-1343 dossier; drying racks beside fisher huts)"
    huts = sorted((b for b in buildings if b["id"].startswith("bldg.kalarand.")), key=lambda b: b["id"])
    polys = [[(q[0] * mpu, q[1] * mpu) for q in b["footprint"]] for b in buildings]
    yards = [[(q[0] * mpu, q[1] * mpu) for q in y["polygon"]] for y in harbour["net_yards"]]
    round_obstacles = [((b["at"][0] * mpu, b["at"][1] * mpu), 3.5) for b in harbour["boats"]]
    round_obstacles += [((d["at"][0] * mpu, d["at"][1] * mpu), d["length"] * mpu / 2 + 1.5) for d in bridges if d.get("kind") in ("jetty", "beach_deck")]
    round_obstacles += [((t[0] * mpu, t[1] * mpu), 2.2) for t in trees]
    round_obstacles += [((b[0] * mpu, b[1] * mpu), 1.4) for b in bushes]
    bw = harbour.get("boatwright")
    if bw:
        round_obstacles.append(((bw["at"][0] * mpu, bw["at"][1] * mpu), 9.0))
    lanes = [(s["points_m"], s.get("width", 4.0) / 2) for s in streets]

    def seg_d(p, a, b):
        dx, dy = b[0] - a[0], b[1] - a[1]
        ll = dx * dx + dy * dy
        t = 0.0 if ll < 1e-12 else max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / ll))
        return math.hypot(p[0] - (a[0] + t * dx), p[1] - (a[1] + t * dy))

    def poly_clear(p, margin):
        for poly in polys + yards:
            if pip(p, poly):
                return False
            n = len(poly)
            for i in range(n):
                a, b = poly[i], poly[(i + 1) % n]
                if seg_d(p, a, b) < margin:
                    return False
        return True

    def street_clear(p, margin):
        for pts, half_w in lanes:
            for i in range(len(pts) - 1):
                if seg_d(p, pts[i], pts[i + 1]) < half_w + margin:
                    return False
        return True

    racks, placed = [], []
    variants = ["fish_rack.herring", "fish_rack.mixed", "fish_rack.herring", "fish_rack.mixed", "fish_rack.empty"]
    for hut in huts:
        c = poly_centroid([(q[0] * mpu, q[1] * mpu) for q in hut["footprint"]])
        shore = shore_march(h_at_m, c[0], c[1], *KJ_SEA, limit=120.0)
        # Shore-side huts only: the front row facing the beach (sea to the
        # northeast) within ~100 m; the inland rows keep their gardens.
        if math.dist(c, shore) > 100.0:
            continue
        want = 2 if rng.random() < 0.35 else 1
        got = 0
        for attempt in range(60):
            if got >= want:
                break
            ang = math.atan2(KJ_SEA[1], KJ_SEA[0]) + rng.uniform(-1.1, 1.1)
            d = rng.uniform(5.5, 12.0)
            p = (c[0] + math.cos(ang) * d, c[1] + math.sin(ang) * d)
            length = rng.uniform(3.0, 3.8)
            axis = KJ_ROT + rng.uniform(-0.3, 0.3)
            ends = [(p[0] + math.cos(axis) * sx * (length / 2 + 0.2), p[1] + math.sin(axis) * sx * (length / 2 + 0.2)) for sx in (-1, 1)]
            if min(h_at_m(*q) for q in ends + [p]) < 0.8:
                continue
            if not all(poly_clear(q, 1.6) for q in ends + [p]):
                continue
            if not all(street_clear(q, 1.5) for q in ends + [p]):
                continue
            if any(math.dist(q, o) < r + 0.7 for o, r in round_obstacles for q in ends + [p]):
                continue
            if any(math.dist(p, o) < 4.6 for o in placed):
                continue
            placed.append(p)
            racks.append({"id": "fishrack.kalarand.%02d" % len(racks), "hut": hut["id"], "at": [round(p[0] / mpu, 2), round(p[1] / mpu, 2)],
                          "angle": round(axis, 4), "length": round(length, 2), "variant": variants[len(racks) % len(variants)], "confidence": conf})
            got += 1
    return racks


def clip_to_circuit(points, circuit, gates, gate_radius=12.0):
    """Cut a street where it crosses the curtain away from a gate; keep the
    part with the most length inside the circuit."""
    pieces = [[tuple(points[0])]]
    n = len(circuit)
    for k in range(len(points) - 1):
        a, b = tuple(points[k]), tuple(points[k + 1])
        hits = []
        for i in range(n):
            q = seg_intersection(a, b, circuit[i], circuit[(i + 1) % n])
            if q is not None and min(math.dist(q, g) for g in gates) > gate_radius:
                hits.append(q)
        hits.sort(key=lambda q: math.dist(a, q))
        for q in hits:
            pieces[-1].append(q)
            pieces.append([q])
        pieces[-1].append(b)
    if len(pieces) == 1:
        return [list(p) for p in points]

    def inside_length(piece):
        total = 0.0
        for k in range(len(piece) - 1):
            mid = ((piece[k][0] + piece[k + 1][0]) / 2, (piece[k][1] + piece[k + 1][1]) / 2)
            if pip(mid, circuit):
                total += math.dist(piece[k], piece[k + 1])
        return total

    best = max(pieces, key=inside_length)
    # Stop a little short of the wall face.
    if len(best) >= 2:
        for end in (0, -1):
            p, q = best[end], best[1 if end == 0 else -2]
            if not pip(((p[0] + q[0]) / 2, (p[1] + q[1]) / 2), circuit):
                continue
            d = math.dist(p, q)
            if d > 1.5 and (end == 0 and p != tuple(points[0]) or end == -1 and p != tuple(points[-1])):
                t = 1.0 / d
                best[end] = (p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t)
    return [[round(p[0], 2), round(p[1], 2)] for p in best]


def street_direction_at(streets, name, at):
    if not name:
        return None
    best = None
    for s in streets:
        if s["name"] != name:
            continue
        pts = s["points_m"]
        for k in range(len(pts) - 1):
            dd, _ = dist_point_seg(np.array([at[0]]), np.array([at[1]]), pts[k][0], pts[k][1], pts[k + 1][0], pts[k + 1][1])
            if best is None or float(dd[0]) < best[0]:
                best = (float(dd[0]), math.atan2(pts[k + 1][1] - pts[k][1], pts[k + 1][0] - pts[k][0]))
    return best[1] if best and best[0] < 6.0 else None


def seg_intersection(p1, p2, p3, p4):
    d = (p2[0] - p1[0]) * (p4[1] - p3[1]) - (p2[1] - p1[1]) * (p4[0] - p3[0])
    if abs(d) < 1e-9:
        return None
    t = ((p3[0] - p1[0]) * (p4[1] - p3[1]) - (p3[1] - p1[1]) * (p4[0] - p3[0])) / d
    u = ((p3[0] - p1[0]) * (p2[1] - p1[1]) - (p3[1] - p1[1]) * (p2[0] - p1[0])) / d
    if 0.0 <= t <= 1.0 and 0.0 <= u <= 1.0:
        return (p1[0] + t * (p2[0] - p1[0]), p1[1] + t * (p2[1] - p1[1]))
    return None


def thicket_mix(p, h_at_m, soil, rng):
    """Shrub species for an open-country thicket at p, by ground; [] skips it.

    Weights repeat entries. Juniper is kept to sandy heath and dry rises and is
    always a minority inside a mixed stand (R-2245).
    """
    h = h_at_m(*p)
    shore = soil.shore_distance(p)
    if soil.heath_ground(p):
        return ["juniper_shrub"] + ["hazel_shrub"] * 2 + ["dog_rose", "raspberry", "hawthorn"]
    if soil.sandy(p):
        return ["sea_buckthorn"] * 4 + ["juniper_shrub", "dog_rose"] if shore < 200 else ["sea_buckthorn", "dog_rose"]
    if h < 3.0:
        return ["willow_shrub"] * 3 + ["alder_shrub"] * 2 + ["guelder_rose", "elder"]
    if h > 12.0 and rng.random() < 0.18:
        return ["juniper_shrub"] * 2 + ["hawthorn", "dog_rose", "blackthorn"]
    return ["hazel_shrub"] * 3 + ["hawthorn", "blackthorn", "dog_rose", "spindle", "raspberry", "elder", "guelder_rose"]


def shrubs(overlay, buildings, streets, circuit_poly, toompea_edge, river, anchors, h_at_m, mpu, x0, y0, x1, y1, wet_stream, soil):
    """Hedges, yard shrubs, wall-foot scrub, stream thickets and field edges."""
    rng = random.Random(1344)
    cell = 2.5
    occupied = set()
    for b in buildings:
        occupied.update(footprint_cells([(q[0] * mpu, q[1] * mpu) for q in b["footprint"]], cell, 1.0))
    for s in streets:
        pts = s["points_m"] if "points_m" in s else [(q[0] * mpu, q[1] * mpu) for q in s["points"]]
        # Busy streets keep their verges trodden bare: shrubs only in back yards.
        half = int(math.ceil(s.get("width_m", 5.0) / 2 / cell)) + 3
        for p in resample([tuple(q) for q in pts], 1.5):
            k = (int(p[0] // cell), int(p[1] // cell))
            for dx in range(-half, half + 1):
                for dy in range(-half, half + 1):
                    occupied.add((k[0] + dx, k[1] + dy))
    out = []

    def add(p, species, scale):
        k = (int(p[0] // cell), int(p[1] // cell))
        if k in occupied or h_at_m(*p) < 0.5:
            return
        occupied.add(k)
        if wet_stream(p):
            return
        out.append([round(p[0] / mpu, 2), round(p[1] / mpu, 2), species, round(scale, 2)])

    yard = ["elder", "raspberry", "hazel_shrub", "dog_rose", "guelder_rose"]
    forum = [tuple(q) for q in overlay["forum"]["polygon_m"]]
    occupied.update(footprint_cells(forum, cell, 8.0))
    for _ in range(3000):
        p = (rng.uniform(-260, 300), rng.uniform(-620, 320))
        if pip(p, circuit_poly):
            add(p, rng.choice(yard), rng.uniform(0.8, 1.3))
    # Scrub along the wall foot and the ditch banks.
    ring = [a["p"] for a in anchors]
    for p in resample(ring + [ring[0]], 4.0):
        for _ in range(2):
            q = (p[0] + rng.uniform(-14, 14), p[1] + rng.uniform(-14, 14))
            if not pip(q, circuit_poly):
                add(q, rng.choice(["hawthorn", "blackthorn", "dog_rose", "elder"]), rng.uniform(0.9, 1.4))
    for p in resample(river, 5.0):
        for side in (-1, 1):
            q = (p[0] + side * rng.uniform(7, 14), p[1] + rng.uniform(-3, 3))
            add(q, rng.choice(["willow_shrub", "alder_shrub", "guelder_rose"]), rng.uniform(0.9, 1.4))
    # Open country (R-2245): shrubs stand in thickets of one habitat, not as lone
    # random bushes. A lone juniper on every low field read as an alien conifer in
    # a winter village, so juniper only grows on dry sandy heath and rises, and
    # damp ground carries willow and alder, loam hazel/thorn/rose scrub.
    thicket_rng = random.Random(1345)
    for _ in range(1000):
        c = (thicket_rng.uniform(x0 + 10, x1 - 10), thicket_rng.uniform(y0 + 10, y1 - 10))
        if pip(c, circuit_poly) or h_at_m(*c) < 0.5:
            continue
        mix = thicket_mix(c, h_at_m, soil, thicket_rng)
        if not mix:
            continue
        reach = thicket_rng.uniform(3.0, 8.0)
        for _ in range(thicket_rng.randint(3, 9)):
            a, d = thicket_rng.uniform(0, math.tau), reach * math.sqrt(thicket_rng.random())
            add((c[0] + d * math.cos(a), c[1] + d * math.sin(a)), thicket_rng.choice(mix), thicket_rng.uniform(0.8, 1.3))
    for p in toompea_edge:
        for _ in range(6):
            q = (p[0] + rng.uniform(-30, 30), p[1] + rng.uniform(-30, 30))
            add(q, rng.choice(["hazel_shrub", "elder", "spindle", "hawthorn"]), rng.uniform(0.9, 1.4))
    out.sort()
    return out


def chain_parts(parts):
    """Join street parts into one polyline (greedy end matching)."""
    parts = [list(map(tuple, p)) for p in parts]
    chain = parts.pop(0)
    while parts:
        best = None
        for i, p in enumerate(parts):
            for rev_p in (False, True):
                q = p[::-1] if rev_p else p
                for at_end in (True, False):
                    d = math.dist(chain[-1], q[0]) if at_end else math.dist(chain[0], q[-1])
                    if best is None or d < best[0]:
                        best = (d, i, q, at_end)
        _, i, q, at_end = best
        parts.pop(i)
        chain = chain + q[1:] if at_end else q[:-1] + chain
    # Ramps start at the lower end.
    return chain


# Length over which the moat ditch shallows and narrows at each end.
MOAT_TAPER_M = 80.0


def smooth_ditch(line, wall_pts, keep_m, passes=3, window=4):
    """Round the corners of a ditch centre line (moving average along it, end
    points fixed), then push it back out to keep_m from the wall so rounding
    never pulls the ditch into the curtain foot."""
    pts = [list(q) for q in line]
    for _ in range(passes):
        nxt = [pts[0][:]]
        for i in range(1, len(pts) - 1):
            lo, hi = max(0, i - window), min(len(pts) - 1, i + window)
            k = min(i - lo, hi - i)
            seg = pts[i - k : i + k + 1]
            nxt.append([sum(q[0] for q in seg) / len(seg), sum(q[1] for q in seg) / len(seg)])
        nxt.append(pts[-1][:])
        pts = nxt
    wall = [tuple(w) for w in wall_pts]
    for _ in range(4):
        for i, q in enumerate(pts):
            best = None
            for k in range(len(wall) - 1):
                (ax, ay), (bx, by) = wall[k], wall[k + 1]
                dx, dy = bx - ax, by - ay
                t = max(0.0, min(1.0, ((q[0] - ax) * dx + (q[1] - ay) * dy) / max(dx * dx + dy * dy, 1e-9)))
                cx, cy = ax + dx * t, ay + dy * t
                d = math.hypot(q[0] - cx, q[1] - cy)
                if best is None or d < best[0]:
                    best = (d, cx, cy)
            d, cx, cy = best
            if d < keep_m and d > 1e-6:
                f = keep_m / d
                pts[i] = [cx + (q[0] - cx) * f, cy + (q[1] - cy) * f]
    return [tuple(q) for q in pts]


def offset_outward(line, poly, dist):
    out = []
    c = poly_centroid(poly)
    for i, p in enumerate(line):
        a = line[max(i - 1, 0)]
        b = line[min(i + 1, len(line) - 1)]
        tx, ty = b[0] - a[0], b[1] - a[1]
        ln = math.hypot(tx, ty) or 1.0
        nx_, ny_ = -ty / ln, tx / ln
        if (p[0] + nx_ - c[0]) ** 2 + (p[1] + ny_ - c[1]) ** 2 < (p[0] - c[0]) ** 2 + (p[1] - c[1]) ** 2:
            nx_, ny_ = -nx_, -ny_
        out.append((p[0] + nx_ * dist, p[1] + ny_ * dist))
    return out


def inset_ring(ring, dist):
    c = poly_centroid(ring)
    out = []
    n = len(ring)
    for i in range(n):
        a, p, b = ring[i - 1], ring[i], ring[(i + 1) % n]
        tx, ty = b[0] - a[0], b[1] - a[1]
        ln = math.hypot(tx, ty) or 1.0
        nx_, ny_ = -ty / ln, tx / ln
        if (p[0] + nx_ - c[0]) ** 2 + (p[1] + ny_ - c[1]) ** 2 > (p[0] - c[0]) ** 2 + (p[1] - c[1]) ** 2:
            nx_, ny_ = -nx_, -ny_
        out.append((p[0] + nx_ * dist, p[1] + ny_ * dist))
    return out


DOOR_CLEAR_PROBES = (1.2, 2.5)


def fix_blocked_doors(buildings, extra_blockers):
    """Plot footprints are modern survivals, so the street-facing edge can open
    straight into a neighbour. Move such a door to the clear edge nearest the
    original street side; with no clear edge the house gets no door and is not
    enterable. Footprints and doors are in world units."""
    polys = [[tuple(q) for q in b_["footprint"]] for b_ in buildings] + [[tuple(q) for q in p_] for p_ in extra_blockers]
    boxes = [(min(q[0] for q in pl), min(q[1] for q in pl), max(q[0] for q in pl), max(q[1] for q in pl)) for pl in polys]

    def blocked(pt, own):
        for k, (pl, bx) in enumerate(zip(polys, boxes)):
            if k == own or not (bx[0] <= pt[0] <= bx[2] and bx[1] <= pt[1] <= bx[3]):
                continue
            if point_in_ring(pt, pl):
                return True
        return False

    def clear(door, own):
        o = (math.cos(door[2]), math.sin(door[2]))
        return not any(blocked((door[0] + o[0] * k, door[1] + o[1] * k), own) for k in DOOR_CLEAR_PROBES)

    for i, b in enumerate(buildings):
        if not b["door"] or clear(b["door"], i):
            continue
        d = b["door"]
        street = (d[0] + math.cos(d[2]) * 6.0, d[1] + math.sin(d[2]) * 6.0)
        best = None
        for cand in door_candidates(polys[i], street):
            if clear(cand, i):
                best = cand
                break
        if best is None:
            b["door"] = None
            b["enterable"] = False
        else:
            b["door"] = [round(best[0], 3), round(best[1], 3), round(best[2], 4)]


# R-2197: the floor stands on the highest ground under the footprint, and the
# plot terrace (terrace_landmarks) only levels house spans up to
# HOUSE_TERRACE_MAX_SPAN_WU. A merged OSM block on a steep slope (the St
# Catherine's houses by the town wall span 4-5 wu) kept its street door on the
# low side, metres above the ground at the top of a long flight. A house built
# into a slope is entered from the upper side and shows a cellar plinth below,
# so such a door moves to the clear edge with the least rise.
DOOR_HIGH_RISE_WU = 1.0
DOOR_RISE_GAIN_WU = 0.5


def door_rise(door, top, h_at_m, mpu):
    """Floor-to-street height of a door: `top` (wu) minus the ground 1 m out."""
    o = (math.cos(door[2]), math.sin(door[2]))
    return top - h_at_m((door[0] + o[0]) * mpu, (door[1] + o[1]) * mpu)


def lower_high_doors(buildings, extra_blockers, h_at_m, mpu):
    """Move doors that rise more than DOOR_HIGH_RISE_WU above the street, on
    buildings the plot terrace leaves alone, to the clear edge with the least
    rise when that saves at least DOOR_RISE_GAIN_WU. Run after fix_blocked_doors
    and before terrace_landmarks (which levels to the final door)."""
    polys = [[tuple(q) for q in b_["footprint"]] for b_ in buildings] + [[tuple(q) for q in p_] for p_ in extra_blockers]

    def clear(door, own):
        o = (math.cos(door[2]), math.sin(door[2]))
        for k in DOOR_CLEAR_PROBES:
            pt = (door[0] + o[0] * k, door[1] + o[1] * k)
            if any(j != own and point_in_ring(pt, pl) for j, pl in enumerate(polys)):
                return False
        return True

    for i, b in enumerate(buildings):
        # A building nobody enters already sets its threshold at the street
        # level in front of the door (CityPlan.floor_height).
        if not b["door"] or not b["enterable"]:
            continue
        terraced =(b["kind"] in TERRACE_KINDS and b["base_span"] >= TERRACE_MIN_SPAN_WU) or (
            b["kind"] == "house" and HOUSE_TERRACE_MIN_SPAN_WU <= b["base_span"] <= HOUSE_TERRACE_MAX_SPAN_WU
        )
        if terraced:
            continue
        top = max(h_at_m(q[0] * mpu, q[1] * mpu) for q in b["footprint"])
        rise = door_rise(b["door"], top, h_at_m, mpu)
        if rise <= DOOR_HIGH_RISE_WU:
            continue
        d = b["door"]
        street = (d[0] + math.cos(d[2]) * 6.0, d[1] + math.sin(d[2]) * 6.0)
        best, best_rise = None, rise - DOOR_RISE_GAIN_WU
        # door_candidates is ordered nearest the street first, so a tie keeps
        # the door on the street side.
        for cand in door_candidates(polys[i], street):
            r = door_rise(cand, top, h_at_m, mpu)
            if r < best_rise - 0.05 and clear(cand, i):
                best, best_rise = cand, r
        if best is not None:
            b["door"] = [round(best[0], 3), round(best[1], 3), round(best[2], 4)]


def point_in_ring(pt, ring):
    inside = False
    n = len(ring)
    for k in range(n):
        x1_, y1_ = ring[k]
        x2_, y2_ = ring[(k + 1) % n]
        if (y1_ > pt[1]) != (y2_ > pt[1]) and pt[0] < (x2_ - x1_) * (pt[1] - y1_) / (y2_ - y1_ + 1e-12) + x1_:
            inside = not inside
    return inside


def door_candidates(ring, street_point):
    """Door positions (x, y, outward_angle) at the middle of every edge of 1.6 m
    or more, nearest the street point first."""
    out = []
    c = poly_centroid(ring)
    for i in range(len(ring)):
        a, b = ring[i], ring[(i + 1) % len(ring)]
        L = math.dist(a, b)
        if L < 1.6:
            continue
        m = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        nx_, ny_ = (b[1] - a[1]) / L, -(b[0] - a[0]) / L
        if (m[0] + nx_ - c[0]) ** 2 + (m[1] + ny_ - c[1]) ** 2 < (m[0] - c[0]) ** 2 + (m[1] - c[1]) ** 2:
            nx_, ny_ = -nx_, -ny_
        out.append((math.dist(m, street_point), (m[0], m[1], math.atan2(ny_, nx_))))
    out.sort(key=lambda e: e[0])
    return [e[1] for e in out]


def door_on_edge(ring, street_point):
    """Door at the middle of the footprint edge facing the street: (x, y, outward_angle)."""
    best = None
    c = poly_centroid(ring)
    for i in range(len(ring)):
        a, b = ring[i], ring[(i + 1) % len(ring)]
        L = math.dist(a, b)
        if L < 1.6:
            continue
        m = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        d = math.dist(m, street_point)
        if best is None or d < best[0]:
            nx_, ny_ = (b[1] - a[1]) / L, -(b[0] - a[0]) / L
            if (m[0] + nx_ - c[0]) ** 2 + (m[1] + ny_ - c[1]) ** 2 < (m[0] - c[0]) ** 2 + (m[1] - c[1]) ** 2:
                nx_, ny_ = -nx_, -ny_
            best = (d, (m[0], m[1], math.atan2(ny_, nx_)))
    return best[1] if best else None


def hash_int(s):
    return int(hashlib.sha256(s.encode()).hexdigest()[:12], 16)


# ---------------- burgher strip plots (WB-13c, R-1413) ----------------
# H04 (docs/HISTORICAL_AUDIT.md) and dossier Section 5: an ordinary house fronts
# the street on a strip plot commonly 7-11 m wide and up to 100 m deep. The
# per-tier frontage target is a class-D gameplay assignment inside that band
# (WB-13 tier ladder: poor low end, merchant upper half, great high end).
PLOT_FRONTAGE_TARGET_M = {"poor": 7.5, "craft": 8.5, "merchant": 9.5, "great": 10.5}
PLOT_MAX_DEPTH_M = 100.0
PLOT_GAP_M = 0.05  # clearance kept from every obstacle, so touching never counts as overlap
PLOT_MIN_YARD_M = 1.0  # a rear strip shallower than this is no yard
PLOT_STREET_MARGIN_M = 0.25  # added to a street's own half width (plan width_m)
PLOT_CURTAIN_CLEAR_M = 1.5  # half the 1343 curtain plus a walk behind it
PLOT_EDGE_CLEAR_M = 0.5  # Toompea plateau edge (klint)
PLOT_AREA_EPS = 1e-4  # m2; clipped slivers below this are numeric noise
# WB-13d plot walls. Gate widths and wall kinds are the class-D tier ladder of
# docs/tasks/world/WB-13_burgher_plot_prefab.md (merchant and great get a cart gate).
PLOT_GATE_WIDTH_M = {"poor": 1.4, "craft": 1.6, "merchant": 2.0, "great": 2.4}
PLOT_WALL_HEIGHT_M = {"wattle": 1.5, "plank": 1.8, "stone": 2.0}
PLOT_WALL_CLEAR_M = 0.3  # a wall stays this far from any foreign footprint (roof overhang rule)
PLOT_WALL_STEP_M = 0.1  # wall sampling step
PLOT_WALL_SHARE_M = 0.2  # two plot walls closer than this are one shared wall
PLOT_GATE_STREET_M = 0.5  # a street gate centre lies within this of a street corridor


def clip_halfplane(poly, a, b, c):
    """Part of `poly` with a*x + b*y >= c (Sutherland-Hodgman, one edge). The
    subject may be concave; the clipped area stays exact for a convex window."""
    out = []
    n = len(poly)
    for i in range(n):
        p, q = poly[i], poly[(i + 1) % n]
        fp, fq = a * p[0] + b * p[1] - c, a * q[0] + b * q[1] - c
        if fp >= 0:
            out.append(p)
        if (fp >= 0) != (fq >= 0):
            t = fp / (fp - fq)
            out.append((p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t))
    return out


def clip_box(poly, t0, t1, n0, n1):
    """Clip a polygon already in a (t, n) frame to the box t0..t1 x n0..n1."""
    for a, b, c in ((1, 0, t0), (-1, 0, -t1), (0, 1, n0), (0, -1, -n1)):
        poly = clip_halfplane(poly, a, b, c)
        if len(poly) < 3:
            return []
    return poly if abs(poly_area(poly)) > PLOT_AREA_EPS else []


def capsule(a, b, r, sides=12):
    """Convex polygon around segment a-b at radius r (inscribed caps)."""
    pts = []
    for p in (a, b):
        for k in range(sides):
            ang = 2 * math.pi * k / sides
            pts.append((p[0] + r * math.cos(ang), p[1] + r * math.sin(ang)))
    return convex_hull(pts)


def burgher_plots(buildings, obstacles, mpu):
    """One strip plot per ordinary intramural house, in metres internally.

    `obstacles` are (owner, ring) pairs in metres that no plot may enter
    (owner "street:<id>" marks a street corridor): street corridors,
    the curtain and klint edge, the castle, the forum, site footprints and
    reserves. Foreign building footprints and plots placed before are added
    here. Houses are taken in building-id order, so the result never depends
    on the order of `buildings`.
    """
    def box_of(ring):
        xs = [p[0] for p in ring]
        ys = [p[1] for p in ring]
        return (min(xs), min(ys), max(xs), max(ys))

    rings = []  # (owner building id or "", ring, bbox)
    for b in buildings:
        if b.get("plot"):
            continue  # a WB-13e service range is derived from the plots, never bounds one
        ring = [(p[0] * mpu, p[1] * mpu) for p in b["footprint"]]
        rings.append((b["id"], ring, box_of(ring)))
    for oid, ring in obstacles:
        rings.append((oid, ring, box_of(ring)))

    eligible = sorted(
        (b for b in buildings
         if b["kind"] == "house" and b.get("wealth_tier") and not b["landmark_id"] and b["door"] and b["street_id"]),
        key=lambda b: b["id"])
    plots = []
    metas = []  # per plot: frame and extents the wall pass needs
    reach = PLOT_MAX_DEPTH_M + 30.0
    for b in eligible:
        ring = [(p[0] * mpu, p[1] * mpu) for p in b["footprint"]]
        # The strip runs perpendicular to the house's street face (the door
        # edge, which follows the street line), away from the street.
        door = (b["door"][0] * mpu, b["door"][1] * mpu)
        out_ang = b["door"][2]
        N = (-math.cos(out_ang), -math.sin(out_ang))  # into the plot
        T = (-N[1], N[0])

        def frame(ring_, o=door, T=T, N=N):
            return [((p[0] - o[0]) * T[0] + (p[1] - o[1]) * T[1],
                     (p[0] - o[0]) * N[0] + (p[1] - o[1]) * N[1]) for p in ring_]

        own = frame(ring)
        t_lo, t_hi = min(p[0] for p in own), max(p[0] for p in own)
        front, back = min(p[1] for p in own), max(p[1] for p in own)
        cx, cy = door
        near = [(oid, frame(r)) for oid, r, bb in rings
                if oid != b["id"] and bb[0] < cx + reach and bb[2] > cx - reach and bb[1] < cy + reach and bb[3] > cy - reach]

        # Row houses share party walls, and the simplified OSM rings of
        # neighbours overlap by slivers, so a strip the full width of the
        # house's box would meet them. The strip is instead the free interval
        # along the street around the door (t = 0), narrowed by whatever
        # stands beside it; the house may overhang its plot at a party wall.
        span = PLOT_FRONTAGE_TARGET_M["great"]
        mid = (front + back) / 2
        # 1. Front line: the house's own street corridor may reach over the
        #    front of the house; the plot starts behind it.
        n0 = front
        for oid, r in near:
            if oid == "street:" + b["street_id"]:
                part = clip_box(r, t_lo, t_hi, front - 5.0, back)
                if part and min(p[1] for p in part) <= front + 0.01:
                    n0 = max(n0, max(p[1] for p in part) + PLOT_GAP_M)
        if n0 >= mid:
            continue  # the house stands in its street: no room for a plot
        # 2. Sides: across the house's depth, a part wholly left or right of
        #    the door bounds the interval; a part across the door caps depth.
        # The window stays fixed while lo/hi tighten, so the result does not
        # depend on the order the obstacles come in.
        lo, hi = t_lo - span, t_hi + span
        win_lo, win_hi = lo, hi
        cap = front + PLOT_MAX_DEPTH_M
        for _, r in near:
            part = clip_box(r, win_lo, win_hi, n0, back)
            if not part:
                continue
            a_, b_ = min(p[0] for p in part), max(p[0] for p in part)
            if b_ <= 0.0:
                lo = max(lo, b_ + PLOT_GAP_M)
            elif a_ >= 0.0:
                hi = min(hi, a_ - PLOT_GAP_M)
            else:
                cap = min(cap, min(p[1] for p in part) - PLOT_GAP_M)
        # 3. Width: the house's own frontage, widened toward the tier target
        #    where the interval is free (split evenly, the rest to the free side).
        t0, t1 = max(t_lo, lo), min(t_hi, hi)
        need = max(0.0, PLOT_FRONTAGE_TARGET_M[b["wealth_tier"]] - (t1 - t0))
        left = min(need / 2, t0 - lo)
        right = min(need - left, hi - t1)
        left = min(need - right, t0 - lo)
        t0, t1 = t0 - left, t1 + right
        # 4. Depth: the first obstacle anywhere across the final interval.
        # Fixed window again: a shrinking one would drop a just-entering
        # obstacle as a sub-epsilon sliver, depending on obstacle order.
        far = cap
        for _, r in near:
            part = clip_box(r, t0, t1, n0, cap)
            if part:
                far = min(far, min(p[1] for p in part) - PLOT_GAP_M)
        if t1 - t0 < 3.0 or far - n0 < 2.0:
            continue  # a sliver between neighbours is no plot
        depth = far - n0
        corners = [(t0, n0), (t1, n0), (t1, far), (t0, far)]
        yard_c = [(t0, back), (t1, back), (t1, far), (t0, far)] if far - back >= PLOT_MIN_YARD_M else []

        def world(pts, o=door, T=T, N=N):
            return [[round((o[0] + t * T[0] + n * N[0]) / mpu, 3), round((o[1] + t * T[1] + n * N[1]) / mpu, 3)] for t, n in pts]

        poly_w = world(corners)
        plots.append({
            "id": "plot." + b["id"].removeprefix("bldg."),
            "building": b["id"],
            "street_id": b["street_id"],
            "wealth_tier": b["wealth_tier"],
            "frontage_m": round(t1 - t0, 2),
            "depth_m": round(depth, 2),
            "polygon": poly_w,
            "yard": world(yard_c) if yard_c else [],
        })
        placed = [(p[0] * mpu, p[1] * mpu) for p in poly_w]
        rings.append((plots[-1]["id"], placed, box_of(placed)))
        metas.append({"door": door, "T": T, "N": N, "t_lo": t_lo, "t_hi": t_hi, "t0": t0, "t1": t1,
                      "n0": n0, "back": back, "far": far, "has_yard": bool(yard_c)})
    plot_walls(plots, metas, rings, mpu)
    return plots


def plot_walls(plots, metas, rings, mpu):
    """Add `wall` to every plot (WB-13d, R-1414); `None` for plots without a yard.

    Works in metres in each plot's door frame (t along the street face, n into
    the plot). The wall encloses the yard: its two sides, its back, and the
    part of its front line beside the house (the house's own back wall is the
    enclosure behind it). The line is sampled every PLOT_WALL_STEP_M and a
    sample is dropped when it
    - is within PLOT_WALL_CLEAR_M of a foreign house or site footprint (their
      walls and eaves enclose there, and a wall that close would z-fight a roof), or
    - lies on a boundary a lower-id plot already walls (one shared wall, owned
      by the lower id; both records list the other in `shared_with`).
    The gate is the narrowest case first: on a sample within PLOT_GATE_STREET_M
    of a street corridor; else across the side passage beside the house when
    that passage opens on a street; else none, and the yard is entered through
    the house (`access: "through_house"`, the Diele drive-through of H04).
    Plots are handled in id order, so the result never depends on input order.
    """
    step = PLOT_WALL_STEP_M
    foreign = [(oid, np.array(r), bb) for oid, r, bb in rings if oid.startswith("bldg.") or oid.startswith("site.")]
    streets = [("", np.array(r), bb) for oid, r, bb in rings if oid.startswith("street:")]

    def ring_dist(pts, ring):
        best = np.full(len(pts), np.inf)
        for k in range(len(ring)):
            a, b = ring[k], ring[(k + 1) % len(ring)]
            d, _ = dist_point_seg(pts[:, 0], pts[:, 1], a[0], a[1], b[0], b[1])
            best = np.minimum(best, d)
        return best

    def near_rings(group, box, pad):
        return [g for g in group if g[-1][0] < box[2] + pad and g[-1][2] > box[0] - pad
                and g[-1][1] < box[3] + pad and g[-1][3] > box[1] - pad]

    def min_dist(pts, group):
        best = np.full(len(pts), np.inf)
        for g in group:
            best = np.minimum(best, ring_dist(pts, g[1]))
        return best

    order = sorted(range(len(plots)), key=lambda i: plots[i]["id"])
    # Pieces (straight, in frame) of every plot with a yard, sampled once.
    pieces = {}
    for i in order:
        m = metas[i]
        if not m["has_yard"]:
            continue
        t0, t1, back, far = m["t0"], m["t1"], m["back"], m["far"]
        cl = min(max(m["t_lo"], t0), t1)
        cr = min(max(m["t_hi"], t0), t1)
        chain = []
        if cl - t0 > 1e-6:
            chain.append(("front", (cl, back), (t0, back)))
        chain += [("side", (t0, back), (t0, far)), ("back", (t0, far), (t1, far)), ("side", (t1, far), (t1, back))]
        if t1 - cr > 1e-6:
            chain.append(("front", (t1, back), (cr, back)))
        out = []
        for kind, a, b in chain:
            n = max(1, int(math.ceil(math.dist(a, b) / step)))
            out.append((kind, a, b, [(a[0] + (b[0] - a[0]) * k / n, a[1] + (b[1] - a[1]) * k / n) for k in range(n + 1)]))
        pieces[i] = out

    def to_world(m, t, n):
        return (m["door"][0] + t * m["T"][0] + n * m["N"][0], m["door"][1] + t * m["T"][1] + n * m["N"][1])

    # Every yard's full perimeter, to keep gates off a neighbour's yard.
    def cell(p):
        return (int(math.floor(p[0] / PLOT_WALL_SHARE_M)), int(math.floor(p[1] / PLOT_WALL_SHARE_M)))

    def near_owner(grid, p, skip):
        cx, cy = cell(p)
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for owner, q in grid.get((cx + dx, cy + dy), ()):
                    if owner != skip and math.dist(p, q) <= PLOT_WALL_SHARE_M:
                        yield owner

    yards = {}
    for i, ps in pieces.items():
        m = metas[i]
        t0, t1, back, far = m["t0"], m["t1"], m["back"], m["far"]
        ring = [(t0, back), (t1, back), (t1, far), (t0, far)]
        for k in range(4):
            a, b = ring[k], ring[(k + 1) % 4]
            n = max(1, int(math.ceil(math.dist(a, b) / step)))
            for j in range(n + 1):
                q = to_world(m, a[0] + (b[0] - a[0]) * j / n, a[1] + (b[1] - a[1]) * j / n)
                yards.setdefault(cell(q), []).append((plots[i]["id"], q))
    kept_grid = {}
    shared = {plots[i]["id"]: set() for i in pieces}

    for i in order:
        if i not in pieces:
            continue
        p, m = plots[i], metas[i]
        pid = p["id"]
        pcs = pieces[i]
        world = [[to_world(m, *q) for q in pc[3]] for pc in pcs]
        allpts = np.array([q for w in world for q in w])
        box = (allpts[:, 0].min(), allpts[:, 1].min(), allpts[:, 0].max(), allpts[:, 1].max())
        own = "bldg." + pid.removeprefix("plot.")
        f_near = [g for g in near_rings(foreign, box, 1.0) if g[0] != own]
        s_near = near_rings(streets, box, 2.0)
        keep = []
        for w in world:
            pts = np.array(w)
            ok = min_dist(pts, f_near) >= PLOT_WALL_CLEAR_M + step / 2 if f_near else np.ones(len(pts), bool)
            ok = list(ok)
            for k, q in enumerate(w):
                if ok[k]:
                    for owner in near_owner(kept_grid, q, pid):
                        if owner < pid:
                            ok[k] = False
                            shared[pid].add(owner)
                            shared[owner].add(pid)
                            break
            keep.append(ok)
        for w, ok in zip(world, keep):
            for q, o in zip(w, ok):
                if o:
                    kept_grid.setdefault(cell(q), []).append((pid, q))

        tier = p["wealth_tier"]
        width = PLOT_GATE_WIDTH_M[tier]
        half = int(math.ceil(width / 2 / step))

        def window_ok(pi, k):
            if k - half < 0 or k + half >= len(world[pi]):
                return False
            for j in range(k - half, k + half + 1):
                if not keep[pi][j]:
                    return False
                if any(True for _ in near_owner(yards, world[pi][j], pid)):
                    return False
            return True

        gate = None
        best = None
        if s_near:
            for pi, w in enumerate(world):
                d = min_dist(np.array(w), s_near)
                for k in np.nonzero(d <= PLOT_GATE_STREET_M)[0]:
                    cand = (float(d[k]), pi, int(k))
                    if (best is None or cand < best) and window_ok(pi, int(k)):
                        best = cand
        gate_at = None
        if best:
            gate = {"via": "street", "pi": best[1], "k": best[2], "street_dist_m": round(best[0], 3)}
        else:
            # Side passage: the longest uncovered front piece that opens on a street.
            fronts = sorted((-math.dist(pc[1], pc[2]), pi) for pi, pc in enumerate(pcs) if pc[0] == "front")
            for _, pi in fronts:
                k = len(world[pi]) // 2
                tm = pcs[pi][3][k][0]
                mouth = to_world(m, tm, m["n0"])
                if s_near and float(min_dist(np.array([mouth]), s_near)[0]) <= PLOT_GATE_STREET_M and window_ok(pi, k):
                    gate = {"via": "passage", "pi": pi, "k": k, "mouth": mouth}
                    break
        if gate:
            pi, k = gate["pi"], gate["k"]
            pc = pcs[pi]
            dt, dn = pc[2][0] - pc[1][0], pc[2][1] - pc[1][1]
            tc, nc = (m["t0"] + m["t1"]) / 2, (m["back"] + m["far"]) / 2
            q = pc[3][k]
            nt, nn = dn, -dt
            if nt * (q[0] - tc) + nn * (q[1] - nc) < 0:
                nt, nn = -nt, -nn
            vx = nt * m["T"][0] + nn * m["N"][0]
            vy = nt * m["T"][1] + nn * m["N"][1]
            at = world[pi][k]
            rec = {"at": [round(at[0] / mpu, 3), round(at[1] / mpu, 3)], "angle": round(math.atan2(vy, vx), 4),
                   "width": round(width / mpu, 3), "via": gate["via"]}
            if gate["via"] == "street":
                rec["street_dist_m"] = gate["street_dist_m"]
            else:
                rec["mouth"] = [round(gate["mouth"][0] / mpu, 3), round(gate["mouth"][1] / mpu, 3)]
            gate_at = (pi, k)
            gate = rec
            for j in range(k - half + 1, k + half):
                keep[pi][j] = False

        # Runs: contiguous kept samples of a piece, joined across piece corners.
        runs = []
        pending = None  # run that ends on the last sample of the previous piece
        for w, ok in zip(world, keep):
            prev, pending = pending, None
            piece_runs, cur = [], []
            for q, o in zip(w, ok):
                if o:
                    cur.append(q)
                else:
                    piece_runs.append(cur)
                    cur = []
            piece_runs.append(cur)
            for r in (r for r in piece_runs if len(r) >= 2):
                if prev is not None and r[0] == w[0] and math.dist(prev[-1], r[0]) < 1e-9:
                    joined, prev = prev + [r[-1]], None
                else:
                    if prev is not None:
                        runs.append(prev)
                        prev = None
                    joined = [r[0], r[-1]]
                if r[-1] == w[-1]:
                    pending = joined
                else:
                    runs.append(joined)
            if prev is not None:
                runs.append(prev)
        if pending is not None:
            runs.append(pending)

        if tier == "poor":
            kind = "wattle"
        elif tier == "craft":
            kind = ("wattle", "plank")[hash_int(pid) % 2]
        elif tier == "merchant":
            kind = ("plank", "stone")[hash_int(pid) % 2]
        else:
            kind = "stone"
        height = 2.2 if tier == "great" else PLOT_WALL_HEIGHT_M[kind]
        p["wall"] = {
            "kind": kind,
            "height_m": height,
            "runs": [[[round(q[0] / mpu, 3), round(q[1] / mpu, 3)] for q in r] for r in runs],
            "gate": gate,
            "access": "gate" if gate else "through_house",
            "shared_with": [],
        }
    for pid, others in shared.items():
        for p in plots:
            if p["id"] == pid and p.get("wall"):
                p["wall"]["shared_with"] = sorted(others)
    for p in plots:
        p.setdefault("wall", None)


# WB-13e rear service ranges (R-1415). Which building a deep yard keeps follows the
# tier ladder of docs/tasks/world/WB-13_burgher_plot_prefab.md: poor and craft
# favour the round-log auxiliary dwelling and a workshop, merchant a store, great
# a store and a kitchen shed. Never a byre, hay barn, sty or sheep shed inside the
# wall (WB-12 section 5 reject list).
PLOT_SERVICE_MIN_YARD_M = 14.0  # yard depth (house back line to plot rear) that carries one
PLOT_SERVICE_HOUSE_CLEAR_M = 3.0  # open yard kept behind the house
PLOT_SERVICE_WALL_INSET_M = 0.6  # 0.3 m clearance plus the half thickness of the thickest wall
PLOT_SERVICE_GATE_CLEAR_M = 1.5  # free ground in front of a gate
PLOT_SERVICE_TREE_CLEAR_M = 1.0
PLOT_SERVICE_BUSH_CLEAR_M = 0.6
PLOT_SERVICE_GAP_M = 1.2  # between two service buildings of one yard
PLOT_SERVICE_LADDER = {
    "poor": (("aux_dwelling",), ("aux_dwelling",), ()),
    "craft": (("workshop",), ("workshop",), ("aux_dwelling",), ("store",)),
    "merchant": (("store",),),
    "great": (("store", "kitchen_shed"),),
}
PLOT_SERVICE_REJECT = ("byre", "barn", "barn_dwelling", "pigsty", "sheep_shed")


def plot_service_ranges(plots, trees, bushes, h_at_m, mpu):
    """Rear outbuildings in deep burgher yards, as `outbuilding_record`s.

    The plot frame is read back from the yard quad (corner 0 -> 1 runs along the
    street, 0 -> 3 into the plot). Each building's long axis runs along the plot,
    it stands at the back of the yard, inset from every yard edge (the wall line),
    keeps PLOT_SERVICE_HOUSE_CLEAR_M behind the house, keeps the ground in front of
    the gate free and steers round trees and bushes. Candidate spots are tried in
    a fixed order and the type and size come from the plot id, so the result is
    deterministic and never moves anything else. Each record carries `plot`, so
    the plot pass (burgher_plots) ignores it on a rebuild."""
    out = []
    flora = [((t[0] * mpu, t[1] * mpu), PLOT_SERVICE_TREE_CLEAR_M) for t in trees]
    flora += [((b[0] * mpu, b[1] * mpu), PLOT_SERVICE_BUSH_CLEAR_M) for b in bushes]
    cell = 16.0
    flora_grid = {}
    for q, r in flora:
        flora_grid.setdefault((int(q[0] // cell), int(q[1] // cell)), []).append((q, r))

    def ring_gap(p, ring):
        """Distance from point p to a closed ring, 0 inside."""
        if pip(p, ring):
            return 0.0
        return min(float(dist_point_seg(p[0], p[1], ring[k][0], ring[k][1], ring[(k + 1) % len(ring)][0], ring[(k + 1) % len(ring)][1])[0])
                   for k in range(len(ring)))

    def rings_meet(a, b, gap):
        return any(ring_gap(q, b) < gap for q in a) or any(ring_gap(q, a) < gap for q in b) or \
            any(ring_gap(((a[k][0] + a[(k + 1) % 4][0]) / 2, (a[k][1] + a[(k + 1) % 4][1]) / 2), b) < gap for k in range(4))

    for p in sorted(plots, key=lambda p: p["id"]):
        yard = [(q[0] * mpu, q[1] * mpu) for q in p["yard"]]
        if not yard:
            continue
        width, depth = math.dist(yard[0], yard[1]), math.dist(yard[0], yard[3])
        if depth < PLOT_SERVICE_MIN_YARD_M:
            continue
        options = PLOT_SERVICE_LADDER[p["wealth_tier"]]
        types = options[hash_int(p["id"] + "service") % len(options)]
        if not types:
            continue
        T = ((yard[1][0] - yard[0][0]) / width, (yard[1][1] - yard[0][1]) / width)
        N = ((yard[3][0] - yard[0][0]) / depth, (yard[3][1] - yard[0][1]) / depth)

        def at(t, n, o=yard[0], T=T, N=N):
            return (o[0] + t * T[0] + n * N[0], o[1] + t * T[1] + n * N[1])

        gate = p["wall"]["gate"] if p.get("wall") else None
        gate_at = (gate["at"][0] * mpu, gate["at"][1] * mpu) if gate else None
        gate_clear = (gate["width"] * mpu / 2 + PLOT_SERVICE_GATE_CLEAR_M) if gate else 0.0
        rng = random.Random(hash_int(p["id"] + "range"))
        suffix = p["id"].removeprefix("plot.")
        inset = PLOT_SERVICE_WALL_INSET_M
        placed = []
        n_back = depth - inset  # rear face of the next building
        for n_idx, typ in enumerate(types):
            (lmin, lmax), (dmin, dmax), _, _, _ = OUTBUILDING_TYPES[typ]
            L, D = rng.uniform(lmin, lmax), rng.uniform(dmin, dmax)
            free_w = width - 2 * inset
            if free_w < dmin:
                break
            D = min(D, free_w)
            # Lateral spots: against one side wall (a passage left on the
            # other), the other side, then centred.
            side = hash_int(p["id"] + "side") % 2
            t_spots = [inset + D / 2, width - inset - D / 2]
            if side:
                t_spots.reverse()
            t_spots.append(width / 2)
            spot = None
            n_far = n_back
            while spot is None and n_far - L >= PLOT_SERVICE_HOUSE_CLEAR_M - 1e-9:
                n_c = n_far - L / 2
                for t_c in t_spots:
                    ring = [at(t_c + sx * D / 2, n_c + sy * L / 2) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
                    if gate_at is not None and ring_gap(gate_at, ring) < gate_clear:
                        continue
                    c = at(t_c, n_c)
                    reach = math.hypot(L, D) / 2 + PLOT_SERVICE_TREE_CLEAR_M
                    if any(ring_gap(q, ring) < r
                           for gx in range(int((c[0] - reach) // cell), int((c[0] + reach) // cell) + 1)
                           for gy in range(int((c[1] - reach) // cell), int((c[1] + reach) // cell) + 1)
                           for q, r in flora_grid.get((gx, gy), ())
                           if math.dist(q, c) < reach + r):
                        continue
                    if any(rings_meet(ring, other, PLOT_SERVICE_GAP_M) for other in placed):
                        continue
                    spot = (c, ring, n_c)
                    break
                n_far -= 0.5
            if spot is None:
                continue
            c, ring, n_c = spot
            placed.append(ring)
            n_back = n_c - L / 2 - PLOT_SERVICE_GAP_M
            # The door faces the house across the open yard.
            face = at(width / 2, 0.0)
            out.append(outbuilding_record(
                "bldg.%s.%s%d" % (suffix, typ.replace("_", ""), n_idx), typ, c[0], c[1],
                math.atan2(N[1], N[0]), L, D, face, h_at_m, mpu, p["street_id"],
                "plausible composite (WB-13 element table: H04 rear service buildings, H05 round-log auxiliary building); %s tier" % p["wealth_tier"],
                {"plot": p["id"]},
            ))
    return out


# WB-13f yard infrastructure items (R-1416). The set and the evidence class of each
# item come from docs/reports/reval_domestic_infrastructure_1343.md section 5 and the
# trace table of docs/tasks/world/WB-13_burgher_plot_prefab.md. Only these types exist;
# nothing from the WB-12 reject list (byre, barn, pipes, sewer grates) is ever placed.
PLOT_ITEM_CLASS = {
    "firewood_stack": "A", "privy": "B", "midden": "A", "well": "B", "shared_well": "B",
    "water_butt": "B", "garden_bed": "B", "drying_line": "D", "chicken_coop": "B",
}
# Conflict radius (m) of each item; a garden bed is 3 x 2 m and a drying line 3 m long.
PLOT_ITEM_RADIUS_M = {
    "firewood_stack": 1.2, "privy": 1.0, "midden": 1.0, "well": 1.0, "water_butt": 0.5,
    "garden_bed": 1.8, "drying_line": 1.6, "chicken_coop": 0.8,
}
PLOT_ITEM_WALL_INSET_M = 0.6  # wall line (0.3 m clearance + half of the thickest wall)
PLOT_ITEM_WALL_CLEAR_M = 0.3  # an item's circle stays this far inside the wall line
PLOT_ITEM_BUILDING_CLEAR_M = 0.5  # open ground between an item and any house or outbuilding
PLOT_ITEM_GAP_M = 0.4  # between two items
PLOT_ITEM_PATH_HALF_M = 0.6  # the gate -> back door path is 1.2 m wide
PLOT_ITEM_GATE_APRON_M = 3.0  # nothing heaps up in front of a gate
PLOT_ITEM_FUEL_CLEAR_M = 3.0  # firewood keeps clear of privy and well
PLOT_ITEM_WELL_NEAR_M = 20.0  # the privy-vs-well rules cover wells this close (same or neighbouring yard)
PLOT_ITEM_PRIVY_WELL_M = 6.0  # a privy stands at least this far from a well, and downslope of it
PLOT_ITEM_SHARED_WELL_M = 40.0  # reach of a shared well reference
PLOT_ITEM_BED_MIN_OPEN_M2 = 12.0  # open yard needed before a kitchen-garden bed
PLOT_ITEM_BED_M2 = 6.0
PLOT_ITEM_SPACING_M = 0.6  # candidate lattice
PLOT_ITEM_MIN_YARD_M = 6.0  # a yard this deep and wide always carries firewood, privy and midden


def plot_yard_items(plots, buildings, pois, trees, bushes, h_at_m, mpu):
    """Add `items` to every plot (WB-13f, R-1416): `[]` for plots without a yard.

    Works in metres on each yard quad (frame as in plot_service_ranges). Passes run
    over plots in id order so the result never depends on input order: privies first
    (lowest ground that is downslope of and >= 6 m from every near well), then
    private wells of merchant and great yards on the highest ground that keeps the
    same rule against every placed privy, then the rest of the set per plot. Items
    keep off every building (service ranges included), tree, bush, other item, the
    yard edge (wall line) and the 1.2 m path from the gate to the back door. Spots
    are tried in a fixed order and the choice between equal ones comes from the plot
    id, so nothing else in the plan moves."""
    yards = {}
    for p in plots:
        p["items"] = []
        yard = [(q[0] * mpu, q[1] * mpu) for q in p["yard"]]
        if not yard:
            continue
        width, depth = math.dist(yard[0], yard[1]), math.dist(yard[0], yard[3])
        T = ((yard[1][0] - yard[0][0]) / width, (yard[1][1] - yard[0][1]) / width)
        N = ((yard[3][0] - yard[0][0]) / depth, (yard[3][1] - yard[0][1]) / depth)
        yards[p["id"]] = {"plot": p, "o": yard[0], "T": T, "N": N, "w": width, "d": depth, "ring": yard, "items": []}

    cell = 16.0

    def grid_of(entries):
        g = {}
        for q, r in entries:
            g.setdefault((int(q[0] // cell), int(q[1] // cell)), []).append((q, r))
        return g

    flora = grid_of([((t[0] * mpu, t[1] * mpu), PLOT_SERVICE_TREE_CLEAR_M) for t in trees]
                    + [((b[0] * mpu, b[1] * mpu), PLOT_SERVICE_BUSH_CLEAR_M) for b in bushes])
    rings = []  # (building id, ring, bbox) of every house and outbuilding
    for b in buildings:
        ring = [(q[0] * mpu, q[1] * mpu) for q in b["footprint"]]
        rings.append((b["id"], ring, (min(q[0] for q in ring), min(q[1] for q in ring), max(q[0] for q in ring), max(q[1] for q in ring))))
    by_id = {b["id"]: b for b in buildings}

    def ring_gap(p, ring):
        if pip(p, ring):
            return 0.0
        return min(float(dist_point_seg(p[0], p[1], ring[k][0], ring[k][1], ring[(k + 1) % len(ring)][0], ring[(k + 1) % len(ring)][1])[0])
                   for k in range(len(ring)))

    wells = [("%s" % w["id"], (w["at"][0] * mpu, w["at"][1] * mpu), h_at_m(w["at"][0] * mpu, w["at"][1] * mpu))
             for w in pois if w["kind"] == "well"]
    privies = []  # (plot id, at, ground)

    def near_wells(c):
        return [w for w in wells if math.dist(c, w[1]) <= PLOT_ITEM_WELL_NEAR_M + PLOT_ITEM_PRIVY_WELL_M]

    def candidates(y):
        out = []
        r_t = int((y["w"] - 2 * PLOT_ITEM_WALL_INSET_M) / PLOT_ITEM_SPACING_M)
        r_n = int((y["d"] - 2 * PLOT_ITEM_WALL_INSET_M) / PLOT_ITEM_SPACING_M)
        for i in range(r_t + 1):
            for j in range(r_n + 1):
                t = PLOT_ITEM_WALL_INSET_M + i * PLOT_ITEM_SPACING_M
                n = PLOT_ITEM_WALL_INSET_M + j * PLOT_ITEM_SPACING_M
                out.append((t, n, (y["o"][0] + t * y["T"][0] + n * y["N"][0], y["o"][1] + t * y["T"][1] + n * y["N"][1])))
        return out

    for y in yards.values():
        y["cand"] = candidates(y)
        p = y["plot"]
        y["house"] = [(q[0] * mpu, q[1] * mpu) for q in by_id[p["building"]]["footprint"]]
        gate = p["wall"]["gate"] if p.get("wall") else None
        y["gate"] = (gate["at"][0] * mpu, gate["at"][1] * mpu) if gate else None
        y["door"] = (y["o"][0] + min(max(y["w"] / 2, 0.0), y["w"]) * y["T"][0], y["o"][1] + min(max(y["w"] / 2, 0.0), y["w"]) * y["T"][1])
        # Buildings that can touch this yard: every ring whose box meets it.
        xs = [q[0] for q in y["ring"]]
        ys = [q[1] for q in y["ring"]]
        box = (min(xs) - 3, min(ys) - 3, max(xs) + 3, max(ys) + 3)
        y["near"] = [(bid, r) for bid, r, bb in rings if bb[0] < box[2] and bb[2] > box[0] and bb[1] < box[3] and bb[3] > box[1]]
        y["area"] = abs(poly_area(y["ring"]))
        y["used"] = sum(abs(poly_area(r)) for bid, r in y["near"] if by_id[bid].get("plot") == p["id"])

    def spot_ok(y, c, typ, r):
        t = (c[0] - y["o"][0]) * y["T"][0] + (c[1] - y["o"][1]) * y["T"][1]
        n = (c[0] - y["o"][0]) * y["N"][0] + (c[1] - y["o"][1]) * y["N"][1]
        if min(t, y["w"] - t, y["d"] - n) < r + PLOT_ITEM_WALL_CLEAR_M:
            return False
        for bid, ring in y["near"]:
            need = r + (0.05 if (typ == "water_butt" and bid == y["plot"]["building"]) else PLOT_ITEM_BUILDING_CLEAR_M)
            if ring_gap(c, ring) < need:
                return False
        for q, rr in (e for gx in range(int((c[0] - 4) // cell), int((c[0] + 4) // cell) + 1)
                      for gy in range(int((c[1] - 4) // cell), int((c[1] + 4) // cell) + 1)
                      for e in flora.get((gx, gy), ())):
            if math.dist(q, c) < r + rr:
                return False
        for it in y["items"]:
            if math.dist(it["c"], c) < r + it["r"] + PLOT_ITEM_GAP_M:
                return False
        if y["gate"] is not None:
            if math.dist(c, y["gate"]) < PLOT_ITEM_GATE_APRON_M + r and typ in ("midden", "privy", "firewood_stack"):
                return False
            # Path from the gate to the house's back door stays clear.
            if dist_point_seg(c[0], c[1], y["gate"][0], y["gate"][1], y["door"][0], y["door"][1])[0] < PLOT_ITEM_PATH_HALF_M + r:
                return False
        return True

    def put(y, typ, t, n, c, angle, extra=None):
        r = PLOT_ITEM_RADIUS_M[typ]
        count = sum(1 for it in y["items"] if it["type"] == typ)
        rec = {"id": "%s.%s%d" % (y["plot"]["id"], typ.replace("_", ""), count), "type": typ,
               "at": [round(c[0] / mpu, 3), round(c[1] / mpu, 3)], "angle": round(angle, 4), "class": PLOT_ITEM_CLASS[typ]}
        y["plot"]["items"].append(rec)
        y["items"].append({"type": typ, "c": c, "r": r, "area": math.pi * r * r if typ != "garden_bed" else PLOT_ITEM_BED_M2})
        return rec

    def ground(c):
        return h_at_m(c[0], c[1])

    order = sorted(yards)
    axis = lambda y: math.atan2(y["T"][1], y["T"][0])  # noqa: E731
    facing = lambda y: math.atan2(-y["N"][1], -y["N"][0])  # noqa: E731

    # Pass 1: privies. Lowest ground first, deeper in the yard on ties.
    for pid in order:
        y = yards[pid]
        r = PLOT_ITEM_RADIUS_M["privy"]
        best = None
        for t, n, c in y["cand"]:
            if n < 3.0 or not spot_ok(y, c, "privy", r):
                continue
            g = ground(c)
            if any(math.dist(c, w[1]) < PLOT_ITEM_PRIVY_WELL_M or (math.dist(c, w[1]) <= PLOT_ITEM_WELL_NEAR_M and g > w[2]) for w in near_wells(c)):
                continue
            key = (round(g, 2), -n, t)
            if best is None or key < best[0]:
                best = (key, t, n, c)
        if best:
            put(y, "privy", best[1], best[2], best[3], facing(y))
            privies.append((pid, best[3], ground(best[3])))
        else:
            # Poor and crowded plots share a neighbour's privy (WB-13 trace table).
            near = sorted((math.dist(y["o"], q), o) for o, q, _ in privies if o != pid and math.dist(y["o"], q) <= 30.0)
            if near:
                rec = {"id": "%s.privy0" % pid, "type": "privy", "at": next(i["at"] for i in yards[near[0][1]]["plot"]["items"] if i["type"] == "privy"),
                       "angle": 0.0, "class": PLOT_ITEM_CLASS["privy"], "shared_with": near[0][1]}
                y["plot"]["items"].append(rec)

    # Pass 2: private wells on merchant and great yards, on the highest ground that keeps
    # every near privy downslope and 6 m away; the others get a shared-well reference below.
    placed_wells = list(wells)
    for pid in order:
        y = yards[pid]
        if y["plot"]["wealth_tier"] not in ("merchant", "great"):
            continue
        r = PLOT_ITEM_RADIUS_M["well"]
        best = None
        for t, n, c in y["cand"]:
            if n < 2.0 or not spot_ok(y, c, "well", r):
                continue
            g = ground(c)
            if any(math.dist(c, q) < PLOT_ITEM_PRIVY_WELL_M or (math.dist(c, q) <= PLOT_ITEM_WELL_NEAR_M and pg > g) for _, q, pg in privies):
                continue
            key = (-round(g, 2), n, t)
            if best is None or key < best[0]:
                best = (key, t, n, c)
        if best:
            put(y, "well", best[1], best[2], best[3], 0.0)
            placed_wells.append((pid + ".well0", best[3], ground(best[3])))

    # Pass 3: the rest of the set, per plot.
    for pid in order:
        y = yards[pid]
        p = y["plot"]
        tier = p["wealth_tier"]
        h = hash_int(pid + "items")
        kinds = ["firewood_stack", "midden"]
        if tier in ("craft", "merchant", "great") and by_id[p["building"]]["roof"] == "shingle":
            kinds.append("water_butt")
        kinds.append("garden_bed")
        if tier in ("poor", "craft") and h % 2 == 0:
            kinds.append("drying_line")
        if tier in ("poor", "craft") and h % 3 == 0:
            kinds.append("chicken_coop")
        for typ in kinds:
            r = PLOT_ITEM_RADIUS_M[typ]
            if typ == "garden_bed":
                open_m2 = y["area"] - y["used"] - sum(it["area"] for it in y["items"])
                if open_m2 < PLOT_ITEM_BED_MIN_OPEN_M2:
                    continue
            best = None
            for t, n, c in y["cand"]:
                if not spot_ok(y, c, typ, r):
                    continue
                if typ == "firewood_stack" and any(
                        math.dist(c, it["c"]) < PLOT_ITEM_FUEL_CLEAR_M + r for it in y["items"] if it["type"] in ("privy", "well")):
                    continue
                edge = min(t, y["w"] - t, y["d"] - n)
                if typ == "firewood_stack":
                    key = (n, abs(t - y["w"] / 2), t)  # by the house back wall
                elif typ == "midden":
                    key = (-n, edge, t)  # far back
                elif typ == "water_butt":
                    key = (ring_gap(c, y["house"]), n, t)  # against the house wall
                elif typ == "garden_bed":
                    key = (n, -edge, t)  # sunny side of the house
                else:
                    key = (edge, -n, t)  # against a wall
                if best is None or key < best[0]:
                    best = (key, t, n, c)
            if best is None:
                continue
            angle = {"privy": 0.0, "chicken_coop": facing(y)}.get(typ, axis(y))
            if typ == "midden":
                angle = (hash_int(pid + "midden") % 628) / 100.0
            put(y, typ, best[1], best[2], best[3], angle)

    # Wells every other yard may draw from (existing POI wells count): a reference, not a copy.
    for pid in order:
        y = yards[pid]
        if any(i["type"] == "well" for i in y["plot"]["items"]):
            continue
        centre = (y["o"][0] + (y["w"] / 2) * y["T"][0] + (y["d"] / 2) * y["N"][0], y["o"][1] + (y["w"] / 2) * y["T"][1] + (y["d"] / 2) * y["N"][1])
        near = sorted((math.dist(centre, q), wid, q) for wid, q, _ in placed_wells if not wid.startswith(pid + ".") and math.dist(centre, q) <= PLOT_ITEM_SHARED_WELL_M)
        if near:
            d, wid, q = near[0]
            y["plot"]["items"].append({"id": "%s.sharedwell0" % pid, "type": "shared_well", "at": [round(q[0] / mpu, 3), round(q[1] / mpu, 3)],
                                       "angle": 0.0, "class": PLOT_ITEM_CLASS["shared_well"], "ref": wid, "distance_m": round(d, 1)})


def plot_obstacles(streets, circuit_poly, toompea_edge, toompea_inner, toompea_wall_half, castle_ring, forum_poly, site_out, mpu):
    """(owner, ring) pairs in metres that bound every strip plot; see burgher_plots."""
    obs = []
    for s in streets:
        pts = s["points_m"]
        r = s["width_m"] / 2 + PLOT_STREET_MARGIN_M
        for k in range(len(pts) - 1):
            obs.append(("street:" + s["id"], capsule(tuple(pts[k]), tuple(pts[k + 1]), r)))
    for ring_, r in ((circuit_poly, PLOT_CURTAIN_CLEAR_M), (toompea_edge, PLOT_EDGE_CLEAR_M), (toompea_inner, toompea_wall_half)):
        for k in range(len(ring_)):
            obs.append(("edge", capsule(tuple(ring_[k]), tuple(ring_[(k + 1) % len(ring_)]), r)))
    obs.append(("castle", [tuple(p) for p in castle_ring]))
    obs.append(("forum", [tuple(p) for p in forum_poly]))
    for so in site_out:
        for poly in so["footprints"] + ([so["reserve"]] if so["reserve"] else []):
            obs.append((so["id"], [(p[0] * mpu, p[1] * mpu) for p in poly]))
    return obs


def render_splat(plan, mpu):
    x0, y0, x1, y1 = plan["bounds"]
    W = int(math.ceil((x1 - x0) * SPLAT_PX_PER_WU))
    H = int(math.ceil((y1 - y0) * SPLAT_PX_PER_WU))
    layers = {k: Image.new("L", (W, H), 0) for k in ("paving", "earth", "sand", "mud")}
    draws = {k: ImageDraw.Draw(v) for k, v in layers.items()}

    def T(p):
        return ((p[0] - x0) * SPLAT_PX_PER_WU, (p[1] - y0) * SPLAT_PX_PER_WU)

    paved_names = {"Pikk", "Lai", "Viru", "Vene", "Raekoja plats", "Pikk jalg", "Lossi plats"}
    for s in plan["streets"]:
        pts = [T(p) for p in s["points"]]
        w = max(1, int(round(s["width"] * SPLAT_PX_PER_WU)))
        layer = "paving" if s["name"] in paved_names else "earth"
        draws[layer].line(pts, fill=255, width=w, joint="curve")
        r = w / 2
        for p in pts:
            draws[layer].ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=255)
    # Market forum: packed earth with patches of paving (1343: "unpaved /
    # partially paved", raekoja-plats-extents-1343.md).
    # Regional sites (ADR 0042) may lack any feature: each is drawn only when present.
    forum = plan.get("forum", {}).get("polygon", [])
    if len(forum) >= 3:
        draws["earth"].polygon([T(p) for p in forum], fill=235)
        draws["paving"].polygon([T(p) for p in forum], fill=150)
    # Beach sand along the shore band and wet mud in the delta.
    shore = plan["shoreline"]
    sand_w = int(28 / mpu * SPLAT_PX_PER_WU)
    if len(shore) >= 2:
        draws["sand"].line([T(p) for p in shore], fill=255, width=sand_w, joint="curve")
    hj = plan.get("harjapea", {})
    if len(hj.get("points", [])) >= 2:
        draws["mud"].line([T(p) for p in hj["points"]], fill=255, width=int(hj.get("mud_m", 30) / mpu), joint="curve")
    # Lakes (regional sites only): mud under the water (no grass grows there)
    # and a wet band round the waterline.
    for lk in plan.get("lakes", []):
        cx, cy = T(lk["at"])
        rr = (lk["radius"] + 3.0) * SPLAT_PX_PER_WU
        draws["mud"].ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=200)
        rr = (lk["radius"] + 0.5) * SPLAT_PX_PER_WU
        draws["mud"].ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=255)
    # Ditch banks grade from grass through wet earth to mud at the waterline.
    if len(plan.get("moat", {}).get("points", [])) >= 2:
        for scale_, fill_ in ((2.5, 70), (1.9, 130), (1.4, 190), (1.0, 245)):
            draws["mud"].line([T(p) for p in plan["moat"]["points"]], fill=fill_, width=int(plan["moat"]["width"] * scale_), joint="curve")
    # Trampled ground: a light wash over the whole walled town, a strong band
    # around every house (eaves drip, doorstep, cart turn).
    circuit = [T(a["at"]) for a in plan["circuit"]]
    if len(circuit) >= 3:
        draws["earth"].polygon(circuit, fill=70)
    for b in plan["buildings"]:
        ring = [T(p) for p in b["footprint"]]
        if len(ring) >= 3:
            draws["earth"].line(ring + [ring[0]], fill=210, width=int(5 / mpu), joint="curve")
            # Drip line and rising damp: a narrow muddy seam at the wall foot.
            draws["mud"].line(ring + [ring[0]], fill=150, width=max(1, int(1.4 / mpu * SPLAT_PX_PER_WU)), joint="curve")
    for so in plan.get("sites", []):
        # 1343 forum ground: packed earth with patches of paving (dossier "unpaved /
        # partially paved"); site buildings get the trampled band and drip line.
        if so["reserve"]:
            draws["earth"].polygon([T(p) for p in so["reserve"]], fill=235)
            draws["paving"].polygon([T(p) for p in so["reserve"]], fill=150)
        for poly in so["footprints"]:
            ring = [T(p) for p in poly]
            draws["earth"].line(ring + [ring[0]], fill=210, width=int(5 / mpu), joint="curve")
            draws["mud"].line(ring + [ring[0]], fill=150, width=max(1, int(1.4 / mpu * SPLAT_PX_PER_WU)), joint="curve")
    # Tilled fields: black-earth soil, never turf. The ground shader reads a field as
    # full packed earth plus a mud-channel marker in FIELD_MUD_LEVEL (a band no other
    # surface uses), so it can add clods and stones and the grass scatter stays off.
    # The outline is warped by smooth noise so a strip is not a ruler-straight box.
    field_earth = Image.new("L", (W, H), 0)
    field_mark = Image.new("L", (W, H), 0)
    fe_draw = ImageDraw.Draw(field_earth)
    fm_draw = ImageDraw.Draw(field_mark)
    for f in plan["fields"]:
        ring = [T(p) for p in f["polygon"]]
        sowing = f.get("sowing")
        if sowing == "fallow":
            # Fallow stays rough grass with a trampled wash.
            draws["earth"].polygon(ring, fill=55)
            continue
        fe_draw.polygon(ring, fill=255)
        fm_draw.polygon(ring, fill=FIELD_MUD_LEVEL)
    rng_w = np.random.default_rng(1343)
    coarse = rng_w.random((2, max(H // 14, 2), max(W // 14, 2))).astype(np.float32)
    warp = []
    for k in range(2):
        im = Image.fromarray((coarse[k] * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC)
        warp.append((np.asarray(im, dtype=np.float32) / 255.0 - 0.5) * 9.0)
    yy, xx = np.mgrid[0:H, 0:W]
    sx = np.clip((xx + warp[0]).astype(np.int32), 0, W - 1)
    sy = np.clip((yy + warp[1]).astype(np.int32), 0, H - 1)
    for src, key in ((field_earth, "earth"), (field_mark, "mud")):
        warped = Image.fromarray(np.asarray(src)[sy, sx])
        layers[key] = Image.fromarray(np.maximum(np.asarray(layers[key]), np.asarray(warped)))
    blurred = {}
    from PIL import ImageFilter

    for k, im in layers.items():
        blurred[k] = im.filter(ImageFilter.GaussianBlur(1.2 if k == "paving" else 2.5))
    return Image.merge("RGBA", (blurred["paving"], blurred["earth"], blurred["sand"], blurred["mud"]))


def render_roads(plan, mpu):
    """Cart-road raster for the ground shader (see terrain_relief.road_map)."""
    x0, y0, x1, y1 = plan["bounds"]
    W = int(math.ceil((x1 - x0) * SPLAT_PX_PER_WU))
    H = int(math.ceil((y1 - y0) * SPLAT_PX_PER_WU))
    roads = [
        (s["id"], [tuple(p) for p in s["points"]], s["width"])
        for s in plan["streets"]
        if s["class"] == "extramural_road"
    ]
    arr = terrain_relief.road_map(W, H, (x0, y0), SPLAT_PX_PER_WU, roads, mpu)
    return Image.fromarray(arr)


def render_minimap(plan, height_wu):
    """Painted top-down map for the in-game minimap, 1 px per world unit."""
    x0, y0, x1, y1 = plan["bounds"]
    W, H = int(x1 - x0), int(y1 - y0)
    hs = np.array(Image.fromarray(height_wu.astype(np.float32)).resize((W, H), Image.BILINEAR))
    gy, gx = np.gradient(hs)
    shade = np.clip(0.92 + (-gx - gy) * 0.35, 0.7, 1.12)
    land = np.stack([np.full_like(hs, 0.62), np.full_like(hs, 0.64), np.full_like(hs, 0.46)], -1) * 255
    rgb = land * shade[..., None]
    sea = hs < 0.05
    rgb[sea] = (np.array([0.36, 0.52, 0.58]) * 255) * (1.0 + np.clip(hs[sea], -6, 0)[:, None] * 0.04)
    img = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8))
    dr = ImageDraw.Draw(img)

    def T(p):
        return (p[0] - x0, p[1] - y0)

    for f in plan["fields"]:
        tone = {"spring": (156, 126, 88), "winter": (128, 150, 84), "garden": (122, 140, 78), "fallow": (150, 156, 104)}
        dr.polygon([T(p) for p in f["polygon"]], fill=tone.get(f.get("sowing"), (150, 128, 92)))
    for pa in plan.get("pastures", []):
        dr.polygon([T(p) for p in pa["polygon"]], fill=(150, 168, 108), outline=(112, 98, 72) if pa["fence"] else None)
    for orc in plan.get("orchards", []):
        dr.polygon([T(p) for p in orc["polygon"]], fill=(132, 160, 92), outline=(112, 98, 72))
    if len(plan["circuit"]) >= 3:
        dr.polygon([T(a["at"]) for a in plan["circuit"]], fill=(170, 160, 135))
    if len(plan["toompea_edge"]) >= 3:
        dr.polygon([T(p) for p in plan["toompea_edge"]], fill=(175, 168, 140))
    hj = plan.get("harjapea", {})
    if len(hj.get("points", [])) >= 2:
        dr.line([T(p) for p in hj["points"]], fill=(92, 132, 148), width=hj.get("minimap_px", 12), joint="curve")
    for lk in plan.get("lakes", []):
        cx, cy = T(lk["at"])
        dr.ellipse([cx - lk["radius"], cy - lk["radius"], cx + lk["radius"], cy + lk["radius"]], fill=(92, 132, 148))
    if len(plan.get("moat", {}).get("points", [])) >= 2:
        dr.line([T(p) for p in plan["moat"]["points"]], fill=(92, 132, 148), width=int(plan["moat"]["width"] * 0.9), joint="curve")
    for s in plan["streets"]:
        col = (214, 200, 168) if s["class"] != "extramural_road" else (176, 150, 112)
        dr.line([T(p) for p in s["points"]], fill=col, width=max(2, int(s["width"])), joint="curve")
    forum = [T(p) for p in plan.get("forum", {}).get("polygon", [])]
    if len(forum) >= 3:
        dr.polygon(forum, fill=(214, 200, 168))
    # Crowns are only ~5 px wide: drawn directly PIL rasterises them as squares,
    # so paint a 4x coverage mask and box-downsample it into antialiased discs.
    ss = 4
    crowns = Image.new("L", (W * ss, H * ss), 0)
    cdr = ImageDraw.Draw(crowns)
    for t in plan["trees"]:
        x, y = T((t[0], t[1]))
        cdr.ellipse([(x - 2.5) * ss, (y - 2.5) * ss, (x + 2.5) * ss, (y + 2.5) * ss], fill=255)
    img.paste((88, 112, 64), (0, 0), crowns.resize((W, H), Image.BOX))
    roof = {"tile": (176, 84, 58), "shingle": (112, 92, 76), "thatch": (178, 150, 92)}
    for b in plan["buildings"]:
        dr.polygon([T(p) for p in b["footprint"]], fill=roof.get(b["roof"], (150, 120, 100)), outline=(70, 52, 40))
    for so in plan.get("sites", []):
        for poly, fill in zip(so["footprints"], so["minimap_fill"]):
            rgb = tuple(int(fill[k:k + 2], 16) for k in (1, 3, 5))
            dr.polygon([T(p) for p in poly], fill=rgb, outline=(60, 40, 32))
    if plan.get("castle"):
        dr.polygon([T(p) for p in plan["castle"]["ring"]], outline=(80, 74, 66), width=3)
    for c in plan["curtains"] + plan["toompea_walls"]:
        dr.line([T(c["from"]), T(c["to"])], fill=(96, 90, 80), width=max(3, int(c["thickness"] * 1.6)))
    for t in plan["towers"]:
        x, y = T(t["at"])
        r = t["w"] * 0.55
        dr.ellipse([x - r, y - r, x + r, y + r], fill=(176, 84, 58), outline=(70, 60, 52), width=2)
    for g in plan["gates"]:
        x, y = T(g["at"])
        dr.rectangle([x - 3, y - 3, x + 3, y + 3], fill=(70, 60, 52))
    return img


def render_review(result, out_png):
    plan = result["plan"]
    h = result["height_wu"]
    x0, y0, x1, y1 = plan["bounds"]
    scale = 1.0  # px per world unit
    W, H = int((x1 - x0) * scale), int((y1 - y0) * scale)
    hs = np.array(Image.fromarray(h.astype(np.float32)).resize((W, H), Image.BILINEAR))
    gy, gx = np.gradient(hs)
    shade = np.clip(0.75 + (-gx * 0.6 - gy * 0.6) * 0.5, 0.35, 1.25)
    t = np.clip(hs / plan.get("review_relief_wu", 60.0), 0, 1)
    rgb = np.stack([90 + 120 * t, 120 + 90 * t, 70 + 40 * t], -1) * shade[..., None]
    sea = hs < 0
    rgb[sea] = np.stack([30 + hs[sea] * 2, 70 + hs[sea] * 3, 120 + hs[sea] * 4], -1)
    contour = (np.abs(hs - np.round(hs / 5.75) * 5.75) < 0.18) & ~sea
    rgb[contour] *= 0.6
    img = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8))
    dr = ImageDraw.Draw(img)

    def T(p):
        return ((p[0] - x0) * scale, (p[1] - y0) * scale)

    for s in plan["streets"]:
        col = {"spine": (245, 230, 190), "lane": (225, 210, 175), "alley": (200, 190, 160), "ramp": (255, 200, 120), "steps": (255, 170, 90), "square_edge": (245, 230, 190), "extramural_road": (190, 160, 110)}[s["class"]]
        dr.line([T(p) for p in s["points"]], fill=col, width=max(1, int(s["width"] * scale)), joint="curve")
    for b in plan["buildings"]:
        col = {"limestone": (200, 196, 185), "plaster": (220, 210, 190), "log": (130, 95, 65), "plank": (150, 115, 80)}[b["material"]]
        if b["landmark_id"]:
            col = (235, 225, 205)
        dr.polygon([T(p) for p in b["footprint"]], fill=col, outline=(60, 50, 40))
    if plan.get("castle"):
        dr.polygon([T(p) for p in plan["castle"]["ring"]], outline=(120, 20, 20), width=3)
    for c in plan["curtains"] + plan["toompea_walls"]:
        col = {"stone": (90, 85, 80), "construction": (170, 120, 60), "palisade": (110, 70, 30)}[c["state"]]
        dr.line([T(c["from"]), T(c["to"])], fill=col, width=max(2, int(c["thickness"] * scale * 1.4)))
    for t in plan["towers"]:
        x, y = T(t["at"])
        r = t["w"] * scale / 2
        dr.ellipse([x - r, y - r, x + r, y + r], fill=(70, 65, 60) if t["state"] == "completed" else (170, 120, 60))
    for g in plan["gates"]:
        x, y = T(g["at"])
        dr.rectangle([x - 5, y - 5, x + 5, y + 5], outline=(255, 255, 0), width=2)
        dr.text((x + 8, y - 6), g["id"].split(".")[1], fill=(255, 255, 120))
    for p in plan["points_of_interest"]:
        x, y = T(p["at"])
        col = {"well": (60, 140, 255), "guard_post": (255, 60, 60), "barracks": (255, 0, 0), "market": (255, 220, 0), "granary": (230, 180, 60), "covered_drain": (0, 200, 255)}.get(p["kind"], (255, 255, 255))
        dr.ellipse([x - 3, y - 3, x + 3, y + 3], fill=col)
    for gtr in plan["gutters"]:
        pts = [T(p) for p in gtr["points"]]
        if len(pts) >= 2:
            ex, ey = pts[-1]
            dr.ellipse([ex - 1.5, ey - 1.5, ex + 1.5, ey + 1.5], fill=(40, 120, 255))
    out_png.parent.mkdir(parents=True, exist_ok=True)
    img.save(out_png, optimize=True)


def write_outputs(result, check=False):
    files = {
        OUT_DIR / "plan.json": (json.dumps(result["plan"], ensure_ascii=False, indent=None, separators=(",", ":")) + "\n").encode(),
        OUT_DIR / "height.json": (json.dumps(result["height"], separators=(",", ":")) + "\n").encode(),
    }
    buf = io.BytesIO()
    result["splat"].save(buf, format="PNG", optimize=True)
    files[OUT_DIR / "splat.png"] = buf.getvalue()
    buf = io.BytesIO()
    result["roads"].save(buf, format="PNG", optimize=True)
    files[OUT_DIR / "roads.png"] = buf.getvalue()
    buf = io.BytesIO()
    result["minimap"].save(buf, format="PNG", optimize=True)
    files[OUT_DIR / "minimap.png"] = buf.getvalue()
    stale = []
    for path, data in files.items():
        if not path.exists() or path.read_bytes() != data:
            stale.append(path)
    if check:
        if stale:
            print("stale city plan outputs:\n  " + "\n  ".join(str(p.relative_to(ROOT)) for p in stale))
            return 1
        print("city plan outputs are current")
        return 0
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for path, data in files.items():
        path.write_bytes(data)
    render_review(result, REVIEW_PNG)
    p = result["plan"]
    print(f"plan: {len(p['streets'])} streets, {len(p['buildings'])} buildings ({sum(1 for b in p['buildings'] if b['enterable'])} enterable), {len(p['curtains'])} curtains, {len(p['towers'])} towers, {len(p['gates'])} gates")
    print(f"height grid {p['height_grid']['nx']}x{p['height_grid']['ny']}, range {result['height_wu'].min():.1f}..{result['height_wu'].max():.1f} wu")
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--import-osm", type=Path)
    ap.add_argument("--import-dem", type=Path)
    ap.add_argument("--site", default="reval_city", help="regional site id (ADR 0042); default the Reval city")
    args = ap.parse_args(argv)
    if args.site != "reval_city":
        # Regional sites run on the site-parameterised builder; imported lazily
        # because that module imports this one for the shared helpers.
        import build_site_plan
        return build_site_plan.main(argv)
    if args.import_osm:
        import_osm(args.import_osm)
    if args.import_dem:
        import_dem(args.import_dem)
    result = build(args)
    return write_outputs(result, check=args.check)


if __name__ == "__main__":
    sys.exit(main())
