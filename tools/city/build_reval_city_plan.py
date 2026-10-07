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


def import_osm(raw_path: Path) -> None:
    """Trim a raw Overpass dump to what the builder needs (keeps the ODbL notice)."""
    raw = json.loads(raw_path.read_text())
    keep_ways, keep_rels, need_nodes = [], [], set()
    for e in raw["elements"]:
        t = e.get("tags", {})
        if e["type"] == "way":
            useful = (
                ("highway" in t and t.get("highway") not in ("cycleway", "elevator", "corridor", "platform", "busway", "proposed", "construction"))
                or "building" in t
                or t.get("natural") in ("cliff", "coastline", "water")
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
        "source": "Overpass API extract, bbox 59.4290,24.7200,59.4470,24.7700",
        "timestamp_osm_base": raw.get("osm3s", {}).get("timestamp_osm_base", ""),
        "nodes": {str(k): v for k, v in sorted(nodes.items())},
        "ways": sorted(keep_ways, key=lambda w: w["id"]),
        "relations": sorted(keep_rels, key=lambda r: r["id"]),
    }
    DATA.mkdir(parents=True, exist_ok=True)
    OSM_PATH.write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")))
    print(f"OSM extract: {len(out['ways'])} ways, {len(out['relations'])} relations, {len(nodes)} nodes")


def import_dem(dem_path: Path) -> None:
    raw = json.loads(dem_path.read_text())
    raw["license"] = "EU-DEM v1.1 (Copernicus Land Monitoring Service), via api.opentopodata.org; free use with attribution"
    raw["elev"] = [[None if v is None else round(v, 2) for v in row] for row in raw["elev"]]
    DATA.mkdir(parents=True, exist_ok=True)
    DEM_PATH.write_text(json.dumps(raw, separators=(",", ":")))
    print(f"DEM: {len(raw['lats'])} x {len(raw['lons'])}")


class Osm:
    def __init__(self, frame: Frame):
        d = json.loads(OSM_PATH.read_text())
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
    def __init__(self, frame: Frame):
        d = json.loads(DEM_PATH.read_text())
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
    seabed = sea_asl - np.minimum(0.6 + shore_d * 0.035, 7.0)
    asl = np.where(in_sea, seabed, land_h)

    # Hareapea stream channel.
    hj = overlay["harjapea"]
    trace = [tuple(p) for p in hj["trace_m"]]
    river_d = np.full(X.shape, 1e9)
    river_w = np.zeros(X.shape)
    for i in range(len(trace) - 1):
        dd, t = dist_point_seg(X, Y, trace[i][0], trace[i][1], trace[i + 1][0], trace[i + 1][1])
        closer = dd < river_d
        river_d = np.where(closer, dd, river_d)
        river_w = np.where(closer, hj["width_m"][i] + (hj["width_m"][i + 1] - hj["width_m"][i]) * t, river_w)
    bank = np.clip((river_d - river_w * 0.5) / 6.0, 0.0, 1.0)
    river_bed = sea_asl - 0.9
    asl = np.where(river_d < river_w * 0.5 + 6.0, river_bed + (asl - river_bed) * bank * bank, asl)
    # River water surface descends gently toward the sea.
    river_surface = sea_asl + 0.0

    # Moat (ditch) outside the S/E curtain.
    mo = overlay["moat"]
    moat_line = offset_outward(resample([a["p"] for a in anchors[mo["from_anchor"] : mo["to_anchor"] + 1]], 6.0), circuit_poly, mo["offset_m"])
    moat_d = np.full(X.shape, 1e9)
    for i in range(len(moat_line) - 1):
        dd, _ = dist_point_seg(X, Y, moat_line[i][0], moat_line[i][1], moat_line[i + 1][0], moat_line[i + 1][1])
        moat_d = np.minimum(moat_d, dd)
    half = mo["width_m"] * 0.5
    cut = np.clip(1.0 - (moat_d - half * 0.55) / (half * 0.9), 0.0, 1.0)
    cut = cut * cut * (3 - 2 * cut)
    # Earthen causeways carry every road over the ditch: no cut near a road.
    causeways = []
    for r in overlay["streets"]["extramural_roads"]:
        pts = [tuple(q) for q in r["points_m"]]
        for k in range(len(pts) - 1):
            for i in range(len(moat_line) - 1):
                q = seg_intersection(pts[k], pts[k + 1], moat_line[i], moat_line[i + 1])
                if q is not None:
                    causeways.append((q, math.atan2(pts[k + 1][1] - pts[k][1], pts[k + 1][0] - pts[k][0]), r["width_m"]))
    keep = np.zeros(X.shape)
    for q, _, w_ in causeways:
        dq = np.hypot(X - q[0], Y - q[1])
        keep = np.maximum(keep, np.clip(1.0 - (dq - (w_ * 0.5 + 2.0)) / 4.0, 0.0, 1.0))
    asl = asl - cut * mo["depth_m"] * (1.0 - keep)

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
            "enterable": bool(door) and (bool(lm) or 22 <= area <= 520),
            "tower_h": round(lm.get("tower_h_m", 0) / mpu, 3) if lm else 0.0,
        }
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
            L = srng.uniform(7, 12) if sub["kind"] != "fisher" else srng.uniform(5, 8)
            D = srng.uniform(5, 7)
            ring = [(px_ + math.cos(ang) * sx * L / 2 - math.sin(ang) * sy * D / 2, py_ + math.sin(ang) * sx * L / 2 + math.cos(ang) * sy * D / 2) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
            # irregular: nudge one corner so houses are not perfect rectangles
            ci = srng.randrange(4)
            ring[ci] = (ring[ci][0] + srng.uniform(-0.6, 0.6), ring[ci][1] + srng.uniform(-0.6, 0.6))
            door = door_on_edge(ring, foot)
            hmin = min(h_at_m(p[0], p[1]) for p in ring)
            hmax = max(h_at_m(p[0], p[1]) for p in ring)
            hid = "bldg.%s.%02d" % (sub["id"].split(".")[1], len(placed))
            buildings.append({
                "id": hid, "kind": "house", "name_1343": "", "landmark_id": "", "confidence": sub["confidence"],
                "footprint": [[round(p[0] / mpu, 3), round(p[1] / mpu, 3)] for p in ring],
                "base_h": round(hmin, 3), "base_span": round(hmax - hmin, 3), "wall_h": round(srng.uniform(2.6, 3.4) / mpu, 3),
                "roof": "thatch", "roof_pitch_deg": 52, "ridge_angle": round(ang, 4),
                "material": "log", "street_id": seg[2]["id"],
                "door": [round(door[0] / mpu, 3), round(door[1] / mpu, 3), round(door[2], 4)] if door else None,
                "enterable": bool(door), "tower_h": 0.0,
            })

    buildings.sort(key=lambda b_: b_["id"])
    # ADR 0032 landmark sites: drop the generic buildings they replace, level
    # their terraces, then the generic landmark terraces.
    sites = load_sites()
    replaced = {rid for site in sites for rid in site["replaces"]}
    missing = replaced - {b_["id"] for b_ in buildings}
    if missing:
        raise SystemExit(f"site replaces unknown building ids: {sorted(missing)}")
    buildings = [b_ for b_ in buildings if b_["id"] not in replaced]
    site_out = [terrace_site(site, height_wu, h_at_m, x0, y0, mpu) for site in sites]
    fix_blocked_doors(buildings, [poly for so in site_out for poly in so["footprints"]])
    terrace_landmarks(buildings, height_wu, h_at_m, x0, y0, mpu)
    # Kalev's smithy: the enterable house nearest the authored spot.
    ks = overlay.get("kalev_smithy")
    if ks:
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
    occupied_by = buildings + [{"footprint": poly} for so in site_out for poly in so["footprints"] + [so["reserve"]] if poly]
    trees, fields = plant(overlay, occupied_by, streets, circuit_poly, toompea_edge, trace, h_at_m, mpu, x0, y0, x1, y1)
    bushes = shrubs(overlay, occupied_by, streets, circuit_poly, toompea_edge, trace, anchors, h_at_m, mpu, x0, y0, x1, y1)

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
        "harjapea": {"points": wu(trace), "widths": [round(w_ / mpu, 3) for w_ in hj["width_m"]], "surface": round((river_surface - sea_asl) / mpu, 3), "confidence": hj["confidence"]},
        "moat": {"points": wu(moat_line), "width": round(mo["width_m"] / mpu, 3), "wet_fraction": mo["wet_fraction"], "confidence": mo["confidence"],
                 "causeways": [{"at": [round(q[0] / mpu, 3), round(q[1] / mpu, 3)], "angle": round(a_, 4), "width": round((w_ + 1.5) / mpu, 3)} for q, a_, w_ in causeways]},
        "toompea_edge": wu(toompea_edge),
        "forum": {"id": overlay["forum"]["id"], "name_1343": overlay["forum"]["name_1343"], "polygon": wu(overlay["forum"]["polygon_m"]), "confidence": overlay["forum"]["confidence"]},
        "circuit": [{"at": [round(a["p"][0] / mpu, 3), round(a["p"][1] / mpu, 3)], "state": a["state"], "ref": a["ref"], "tower": a["tower"], "osm": a["osm"]} for a in anchors],
        "curtains": curtains,
        "towers": towers,
        "gates": gates_out,
        "toompea_walls": toompea_walls,
        "toompea_openings": toompea_openings,
        "castle": castle,
        "streets": streets,
        "buildings": buildings,
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
        "points_of_interest": pois,
        "flows": overlay["flows"],
    }

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
    return {"plan": plan, "height": height_doc, "splat": splat, "roads": roads, "minimap": minimap, "height_wu": height_wu, "extent_m": (x0, y0, x1, y1), "mpu": mpu}


SITES_DIR = ROOT / "content/world/reval_city/sites"


def load_sites():
    """ADR 0032 site manifests, in registry order (never a directory walk)."""
    registry = json.loads((SITES_DIR / "registry.json").read_text())
    return [json.loads((SITES_DIR / f"{name}.json").read_text()) for name in registry["sites"]]


def site_to_world(site, p):
    """Site-local metres (x along the anchor rotation, z to its right) to plan metres."""
    ax, ay = site["anchor"]["at"]
    r = math.radians(site["anchor"]["rotation_deg"])
    c, s_ = math.cos(r), math.sin(r)
    return (ax + p[0] * c - p[1] * s_, ay + p[0] * s_ + p[1] * c)


def flatten_ground(height_wu, ring, level, blend, x0, y0, mpu):
    """Cut or fill the heightfield inside `ring` (metres) to `level` (wu), blended
    back into the natural ground over `blend` metres with a smoothstep."""
    cell = HEIGHT_CELL_WU * mpu
    ny, nx = height_wu.shape
    xs = [p[0] for p in ring]
    ys = [p[1] for p in ring]
    m = max(blend, 1.01)
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
    # 1 m apron at full level, then a smoothstep back to the natural slope.
    t = np.clip((d - 1.0) / (m - 1.0), 0.0, 1.0)
    w = np.where(inside, 1.0, 1.0 - t * t * (3.0 - 2.0 * t))
    block = height_wu[i0:i1 + 1, j0:j1 + 1]
    height_wu[i0:i1 + 1, j0:j1 + 1] = block * (1.0 - w) + level * w


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


def terrace_landmarks(buildings, height_wu, h_at_m, x0, y0, mpu):
    for b in buildings:
        if b["kind"] not in TERRACE_KINDS or not b["door"] or b["base_span"] < TERRACE_MIN_SPAN_WU:
            continue
        ring = [(q[0] * mpu, q[1] * mpu) for q in b["footprint"]]
        dx, dy, ang = b["door"][0] * mpu, b["door"][1] * mpu, b["door"][2]
        level = h_at_m(dx + math.cos(ang) * 2.0, dy + math.sin(ang) * 2.0)
        flatten_ground(height_wu, ring, level, TERRACE_BLEND_M, x0, y0, mpu)
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


def plant(overlay, buildings, streets, circuit_poly, toompea_edge, river, h_at_m, mpu, x0, y0, x1, y1):
    """Deterministic trees and strip fields. Trees avoid footprints and streets."""
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

    def free(p, gap=0):
        k = key(p)
        for dx in range(-gap, gap + 1):
            for dy in range(-gap, gap + 1):
                if occupied.get((k[0] + dx, k[1] + dy)):
                    return False
        return True

    trees = []

    def add(p, species, scale):
        trees.append([round(p[0] / mpu, 2), round(p[1] / mpu, 2), species, round(scale, 2)])
        occupied[key(p)] = True

    # Yard orchards behind the street front inside the walls.
    for _ in range(1600):
        p = (rng.uniform(-260, 300), rng.uniform(-620, 320))
        if not pip(p, circuit_poly) or not free(p, 2):
            continue
        add(p, rng.choice(["apple", "apple", "cherry", "plum", "pear", "rowan"]), rng.uniform(0.75, 1.05))
    # Toompea slopes and the cathedral close: lindens, ashes, elms.
    for _ in range(1400):
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
        add(p, rng.choice(["oak", "birch", "birch", "ash", "spruce", "pine"]), rng.uniform(0.85, 1.35))
    # April strip fields south and east of the walls, ridge-and-furrow parcels.
    fields = []
    for fid, (cx, cy, ang, n) in enumerate([(-30, 470, 0.15, 7), (220, 400, -0.5, 6), (400, 250, -0.35, 6), (-260, 520, 0.4, 5), (480, 520, -0.2, 5)]):
        for k in range(n):
            w = rng.uniform(14, 22)
            L = rng.uniform(90, 150)
            off = (k - n / 2) * 24
            c = (cx + math.cos(ang + math.pi / 2) * off, cy + math.sin(ang + math.pi / 2) * off)
            ring = [(c[0] + math.cos(ang) * sx * L / 2 - math.sin(ang) * sy * w / 2, c[1] + math.sin(ang) * sx * L / 2 + math.cos(ang) * sy * w / 2) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
            if any(pip(q, circuit_poly) for q in ring):
                continue
            fields.append({"id": "field.%02d.%d" % (fid, k), "ploughed": rng.random() < 0.7, "polygon": [[round(q[0] / mpu, 2), round(q[1] / mpu, 2)] for q in ring]})
    trees.sort()
    return trees, fields


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


def shrubs(overlay, buildings, streets, circuit_poly, toompea_edge, river, anchors, h_at_m, mpu, x0, y0, x1, y1):
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
    for _ in range(6000):
        p = (rng.uniform(x0 + 10, x1 - 10), rng.uniform(y0 + 10, y1 - 10))
        if pip(p, circuit_poly):
            continue
        h = h_at_m(*p)
        if h < 3.0:
            add(p, rng.choice(["juniper_shrub", "sea_buckthorn", "heather"]), rng.uniform(0.8, 1.2))
        elif rng.random() < 0.6:
            add(p, rng.choice(["hazel_shrub", "hawthorn", "juniper_shrub", "raspberry", "dog_rose", "spindle"]), rng.uniform(0.8, 1.3))
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
    forum = plan["forum"]["polygon"]
    draws["earth"].polygon([T(p) for p in forum], fill=235)
    draws["paving"].polygon([T(p) for p in forum], fill=150)
    # Beach sand along the shore band and wet mud in the delta.
    shore = plan["shoreline"]
    sand_w = int(28 / mpu * SPLAT_PX_PER_WU)
    draws["sand"].line([T(p) for p in shore], fill=255, width=sand_w, joint="curve")
    hj = plan["harjapea"]
    draws["mud"].line([T(p) for p in hj["points"]], fill=255, width=int(30 / mpu), joint="curve")
    draws["mud"].line([T(p) for p in plan["moat"]["points"]], fill=200, width=int(plan["moat"]["width"] * 1.3), joint="curve")
    # Trampled ground: a light wash over the whole walled town, a strong band
    # around every house (eaves drip, doorstep, cart turn).
    circuit = [T(a["at"]) for a in plan["circuit"]]
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
    for f in plan["fields"]:
        ring = [T(p) for p in f["polygon"]]
        draws["earth"].polygon(ring, fill=235 if f["ploughed"] else 120)
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
        dr.polygon([T(p) for p in f["polygon"]], fill=(150, 128, 92) if f["ploughed"] else (140, 150, 100))
    dr.polygon([T(a["at"]) for a in plan["circuit"]], fill=(170, 160, 135))
    dr.polygon([T(p) for p in plan["toompea_edge"]], fill=(175, 168, 140))
    hj = plan["harjapea"]
    dr.line([T(p) for p in hj["points"]], fill=(92, 132, 148), width=12, joint="curve")
    dr.line([T(p) for p in plan["moat"]["points"]], fill=(92, 132, 148), width=int(plan["moat"]["width"] * 0.9), joint="curve")
    for s in plan["streets"]:
        col = (214, 200, 168) if s["class"] != "extramural_road" else (176, 150, 112)
        dr.line([T(p) for p in s["points"]], fill=col, width=max(2, int(s["width"])), joint="curve")
    forum = [T(p) for p in plan["forum"]["polygon"]]
    dr.polygon(forum, fill=(214, 200, 168))
    for t in plan["trees"]:
        x, y = T((t[0], t[1]))
        dr.ellipse([x - 2.5, y - 2.5, x + 2.5, y + 2.5], fill=(88, 112, 64))
    roof = {"tile": (176, 84, 58), "shingle": (112, 92, 76), "thatch": (178, 150, 92)}
    for b in plan["buildings"]:
        dr.polygon([T(p) for p in b["footprint"]], fill=roof.get(b["roof"], (150, 120, 100)), outline=(70, 52, 40))
    for so in plan.get("sites", []):
        for poly, fill in zip(so["footprints"], so["minimap_fill"]):
            rgb = tuple(int(fill[k:k + 2], 16) for k in (1, 3, 5))
            dr.polygon([T(p) for p in poly], fill=rgb, outline=(60, 40, 32))
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
    t = np.clip(hs / 60.0, 0, 1)
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
    args = ap.parse_args(argv)
    if args.import_osm:
        import_osm(args.import_osm)
    if args.import_dem:
        import_dem(args.import_dem)
    result = build(args)
    return write_outputs(result, check=args.check)


if __name__ == "__main__":
    sys.exit(main())
