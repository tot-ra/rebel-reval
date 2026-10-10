#!/usr/bin/env python3
"""Build a regional site plan (ADR 0042) with the seamless-city pipeline.

One builder for every outdoor place: `--site reval_city` (the default) runs the
Reval city builder unchanged; any other site id reads its overlay
`tools/city/sites/<site_id>_1343_overlay.json` and writes the same five runtime
files the city has into `content/world/<site_id>/`:

  plan.json     vector plan in world units (x east, z south), schema rr.city_plan.v1
  height.json   uint16 heightfield, base64 (centimetres + offset)
  splat.png     RGBA ground-surface weights, 1 px per world unit
  roads.png     cart-road raster for the ground shader
  minimap.png   painted top-down map for the minimap
  docs/reports/images/sites/<site_id>_plan.png   review render (not committed)

The overlay's `site` block carries the frame (origin lat/lon, bounds), the input
extracts, the location/map/scene ids, feature flags and the arrival spawns. A
site may have no wall circuit, no stream, no ditch or no settlement: every
section is optional. Sea and shore exist only when the overlay draws a
`shoreline` (no inland site does); the plan's `site.coast` flag, false with an
empty shoreline, is what the runtime reads (CityPlan.has_coast).

The shared geometry, DEM, raster and review helpers live in
build_reval_city_plan.py, which stays the Reval builder (its --check is the
byte-identity gate for this module).

Inputs per site (committed, trimmed):
  tools/city/data/osm_<site_id>_extract.json   OpenStreetMap extract (ODbL)
  tools/city/data/eudem25m_<site_id>.json      EU-DEM 25 m samples (Copernicus)

Refreshing them: run the overlay's `inputs.overpass_query` against
https://overpass-api.de/api/interpreter and sample EU-DEM on the overlay's
`inputs.dem_grid` through api.opentopodata.org (100 points per request, JSON
{lats, lons, elev}); then

  python3 tools/city/build_site_plan.py --site paide --import-osm raw.json --import-dem dem.json

Usage:
  python3 tools/city/build_site_plan.py --site paide            # rebuild
  python3 tools/city/build_site_plan.py --site paide --check    # fail if stale
  python3 tools/city/build_site_plan.py --check                 # Reval (same as build_reval_city_plan.py --check)

Everything is deterministic: same inputs, same bytes. Every record id the
builder makes is prefixed with the site id (ADR 0042 section 5); ids come from
the overlay or from stable order inside an authored record, never from OSM ids.
"""
from __future__ import annotations

import argparse
import base64
import io
import json
import math
import random
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_reval_city_plan as reval  # noqa: E402
import terrain_relief  # noqa: E402

ROOT = reval.ROOT
SITES_DIR = ROOT / "tools/city/sites"
REVAL_SITE = "reval_city"
SCHEMA = reval.SCHEMA
HEIGHT_CELL_WU = reval.HEIGHT_CELL_WU
HEIGHT_OFFSET_CM = reval.HEIGHT_OFFSET_CM
SPLAT_PX_PER_WU = reval.SPLAT_PX_PER_WU
# Land cover a regional site keeps from OSM (ADR 0042 section 2: terrain-adjacent only).
SITE_NATURAL = ("cliff", "coastline", "water", "wood", "scrub", "wetland", "tree_row", "heath")
# Open-country swells are tuned for the Reval glint plain; the Jerwen clay plain is flatter.
RELIEF_SCALE = 0.6


def overlay_path(site_id: str) -> Path:
    return SITES_DIR / f"{site_id}_1343_overlay.json"


def out_dir(site_id: str) -> Path:
    return ROOT / "content/world" / site_id


def review_png(site_id: str) -> Path:
    return ROOT / "docs/reports/images/sites" / f"{site_id}_plan.png"


# ---------------------------------------------------------------------------
# input refresh
# ---------------------------------------------------------------------------


def clip_raw_osm(raw: dict, bbox) -> dict:
    """Keep ways with a node inside the bbox and the multipolygons built from them.
    Overpass recursion pulls whole route relations (hundreds of km of road);
    a site only needs what touches its frame."""
    s, w, n, e = bbox
    nodes = {el["id"]: el for el in raw["elements"] if el["type"] == "node"}

    def inside(nid):
        nd = nodes.get(nid)
        return nd is not None and s <= nd["lat"] <= n and w <= nd["lon"] <= e

    ways = [el for el in raw["elements"] if el["type"] == "way" and any(inside(i) for i in el["nodes"])]
    way_ids = {el["id"] for el in ways}
    rels = [
        el for el in raw["elements"]
        if el["type"] == "relation" and el.get("tags", {}).get("type") == "multipolygon"
        and any(m["type"] == "way" and m["ref"] in way_ids for m in el["members"])
    ]
    need = {i for el in ways for i in el["nodes"]}
    kept_nodes = [nodes[i] for i in sorted(need) if i in nodes]
    return {"osm3s": raw.get("osm3s", {}), "elements": kept_nodes + ways + rels}


def import_inputs(overlay: dict, osm_raw: Path | None, dem_raw: Path | None) -> None:
    site = overlay["site"]
    inputs = site["inputs"]
    if osm_raw:
        bbox = inputs["osm_bbox"]
        clipped = clip_raw_osm(json.loads(osm_raw.read_text()), bbox)
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp) / "clipped.json"
            tmp_path.write_text(json.dumps(clipped))
            reval.import_osm(
                tmp_path, ROOT / inputs["osm"],
                source="Overpass API extract, bbox %s" % ",".join("%.4f" % v for v in bbox),
                natural=SITE_NATURAL,
            )
    if dem_raw:
        reval.import_dem(dem_raw, ROOT / inputs["dem"])


# ---------------------------------------------------------------------------
# small helpers
# ---------------------------------------------------------------------------


def chain(points):
    out = [0.0]
    for a, b in zip(points, points[1:]):
        out.append(out[-1] + math.dist(a, b))
    return out


def point_along(points, at):
    """(point, direction angle) at arc length `at` along a polyline."""
    acc = chain(points)
    at = min(max(at, 0.0), acc[-1])
    for i in range(len(points) - 1):
        if acc[i + 1] >= at:
            seg = acc[i + 1] - acc[i] or 1.0
            t = (at - acc[i]) / seg
            a, b = points[i], points[i + 1]
            return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t), math.atan2(b[1] - a[1], b[0] - a[0])
    a, b = points[-2], points[-1]
    return b, math.atan2(b[1] - a[1], b[0] - a[0])


def rect_ring(cx, cy, w, d, angle):
    """Corners of a w x d rectangle centred at (cx, cy), w along `angle`."""
    c, s = math.cos(angle), math.sin(angle)
    return [(cx + c * sx * w / 2 - s * sy * d / 2, cy + s * sx * w / 2 + c * sy * d / 2) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]


def polyline_dist(p, pts):
    best = 1e18
    for a, b in zip(pts, pts[1:]):
        dd, _ = reval.dist_point_seg(np.array([p[0]]), np.array([p[1]]), a[0], a[1], b[0], b[1])
        best = min(best, float(dd[0]))
    return best


def ring_dist(p, ring):
    return polyline_dist(p, list(ring) + [ring[0]])


def rings_overlap(a, b):
    """Convex footprints (rectangles here) overlap when either has a corner or the
    centre inside the other."""
    return any(reval.pip(q, b) for q in a + [reval.poly_centroid(a)]) or any(reval.pip(q, a) for q in b + [reval.poly_centroid(b)])


def smooth_closed(ring, passes=2):
    """Chaikin corner cutting on a closed ring."""
    for _ in range(passes):
        out = []
        for i in range(len(ring)):
            a, b = ring[i], ring[(i + 1) % len(ring)]
            out.append((a[0] * 0.75 + b[0] * 0.25, a[1] * 0.75 + b[1] * 0.25))
            out.append((a[0] * 0.25 + b[0] * 0.75, a[1] * 0.25 + b[1] * 0.75))
        ring = out
    return ring


def clip_poly_halfplane(poly, nx_, ny_, c):
    """Sutherland-Hodgman: keep the part of `poly` with nx*x + ny*y <= c."""
    out = []
    for i in range(len(poly)):
        p, q = poly[i], poly[(i + 1) % len(poly)]
        fp = nx_ * p[0] + ny_ * p[1] - c
        fq = nx_ * q[0] + ny_ * q[1] - c
        if fp <= 0:
            out.append(p)
        if (fp < 0) != (fq < 0) and fp != fq:
            t = fp / (fp - fq)
            out.append((p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t))
    return out


# ---------------------------------------------------------------------------
# plan assembly
# ---------------------------------------------------------------------------


def build_site(overlay: dict) -> dict:
    site = overlay["site"]
    sid = site["id"]
    inputs = site["inputs"]
    frame = reval.Frame(site["origin"], site.get("metres_per_world_unit", 1.0))
    mpu = frame.mpu
    osm = reval.Osm(frame, ROOT / inputs["osm"])
    dem = reval.Dem(frame, ROOT / inputs["dem"])
    b = site["bounds_m"]
    x0, y0, x1, y1 = b["x0"], b["y0"], b["x1"], b["y1"]
    rng = random.Random(reval.hash_int(sid))

    def resolve(at):
        if isinstance(at, dict) and "osm" in at:
            p = osm.named_feature_centroid(at["osm"])
            return (round(p[0], 2), round(p[1], 2))
        return (float(at[0]), float(at[1]))

    def wu(points):
        return [[round(p[0] / mpu, 3), round(p[1] / mpu, 3)] for p in points]

    def wpt(p):
        return [round(p[0] / mpu, 3), round(p[1] / mpu, 3)]

    # ---------------- authored skeleton ----------------
    circ = overlay.get("circuit") or {}
    anchors = [{"p": resolve(a["at"]), **{k: a.get(k, "") for k in ("state", "ref", "tower")}} for a in circ.get("anchors", [])]
    circuit_poly = [a["p"] for a in anchors]
    roads = [{**r, "pts": [resolve(p) for p in r["points_m"]]} for r in overlay.get("roads", [])]
    road_by_id = {r["id"]: r for r in roads}
    stream = overlay.get("stream")
    trace = [resolve(p) for p in stream["trace_m"]] if stream else []

    # ---------------- terrain ----------------
    nx = int(math.ceil((x1 - x0) / mpu / HEIGHT_CELL_WU)) + 1
    ny = int(math.ceil((y1 - y0) / mpu / HEIGHT_CELL_WU)) + 1
    gx = x0 + np.arange(nx) * HEIGHT_CELL_WU * mpu
    gy = y0 + np.arange(ny) * HEIGHT_CELL_WU * mpu
    X, Y = np.meshgrid(gx, gy)
    asl = dem.sample(X, Y)
    # Inland sites have no sea to measure from: heights are kept above a local
    # datum a little under the lowest ground, so the runtime's sea tests (< 0)
    # never fire and the numbers stay small.
    datum = math.floor(float(asl.min())) - overlay.get("terrain", {}).get("datum_margin_m", 2.0)

    def bilinear(arr, px, py):
        fx = min(max((px - x0) / (HEIGHT_CELL_WU * mpu), 0), nx - 1.001)
        fy = min(max((py - y0) / (HEIGHT_CELL_WU * mpu), 0), ny - 1.001)
        i, j = int(fy), int(fx)
        u, v = fy - i, fx - j
        return float(arr[i, j] * (1 - u) * (1 - v) + arr[i + 1, j] * u * (1 - v) + arr[i, j + 1] * (1 - u) * v + arr[i + 1, j + 1] * u * v)

    # Stream: the level follows the lower bank 20 m out, never rising downstream.
    stream_out = None
    river_d = np.full(X.shape, 1e9)
    river_w = np.zeros(X.shape)
    if stream:
        widths = list(stream["width_m"])
        if bilinear(asl, *trace[0]) < bilinear(asl, *trace[-1]):
            # Downstream is the last point (runtime and Reval convention).
            trace, widths = trace[::-1], widths[::-1]
        levels = []
        for i, (tx, ty) in enumerate(trace):
            nxt = trace[min(i + 1, len(trace) - 1)]
            prv = trace[max(i - 1, 0)]
            d_ = math.hypot(nxt[0] - prv[0], nxt[1] - prv[1]) or 1.0
            sx, sy = -(nxt[1] - prv[1]) / d_, (nxt[0] - prv[0]) / d_
            levels.append(min(bilinear(asl, tx + sx * 20, ty + sy * 20), bilinear(asl, tx - sx * 20, ty - sy * 20)) - 0.7)
        for i in range(1, len(levels)):
            levels[i] = min(levels[i], levels[i - 1])
        river_s = np.zeros(X.shape)
        for i in range(len(trace) - 1):
            dd, t = reval.dist_point_seg(X, Y, trace[i][0], trace[i][1], trace[i + 1][0], trace[i + 1][1])
            closer = dd < river_d
            river_d = np.where(closer, dd, river_d)
            river_w = np.where(closer, widths[i] + (widths[i + 1] - widths[i]) * t, river_w)
            river_s = np.where(closer, levels[i] + (levels[i + 1] - levels[i]) * t, river_s)
        bed = river_s - stream["depth_m"]
        bank = np.clip((river_d - river_w * 0.5) / 8.0, 0.0, 1.0)
        bank = bank * bank * (3 - 2 * bank)
        asl = np.where(river_d < river_w * 0.5 + 8.0, bed + (asl - bed) * bank, asl)
        stream_out = {
            "id": stream["id"], "name_1343": stream["name_1343"], "confidence": stream["confidence"],
            "points": wu(trace), "widths": [round(w_ / mpu, 3) for w_ in widths],
            "surface": round((min(levels) - datum) / mpu, 3), "surfaces": [round((v - datum) / mpu, 3) for v in levels],
            "mud_m": 8.0, "minimap_px": 4,
        }

    # Ditch: one closed ring round the circuit, crossed by timber bridges.
    ditch = overlay.get("ditch")
    moat_out = {}
    ditch_line = []
    if ditch and circuit_poly:
        ring = reval.inset_ring(circuit_poly, -ditch["offset_m"])
        ring = smooth_closed(ring, 2)
        ditch_line = reval.resample(ring + [ring[0]], 6.0)
        if math.dist(ditch_line[0], ditch_line[-1]) > 0.5:
            ditch_line.append(ditch_line[0])
        dd_ = np.full(X.shape, 1e9)
        for i in range(len(ditch_line) - 1):
            dd, _ = reval.dist_point_seg(X, Y, ditch_line[i][0], ditch_line[i][1], ditch_line[i + 1][0], ditch_line[i + 1][1])
            dd_ = np.minimum(dd_, dd)
        half = ditch["width_m"] * 0.5
        cut = np.clip(1.0 - (dd_ - half * 0.5) / (half * 1.7), 0.0, 1.0)
        asl = asl - cut * cut * (3 - 2 * cut) * ditch["depth_m"]
        moat_out = {"id": ditch["id"], "name_1343": ditch["name_1343"], "points": wu(ditch_line),
                    "width": round(ditch["width_m"] / mpu, 3), "wet_fraction": ditch["wet_fraction"], "confidence": ditch["confidence"]}

    # Open-country relief and hollow ways outside the castle, stream and town.
    wall_d = terrain_relief.poly_distance(X, Y, circuit_poly, reval.dist_point_seg) if circuit_poly else np.full(X.shape, 1e9)
    inside_walls = reval.point_in_poly(X, Y, circuit_poly) if circuit_poly else np.zeros(X.shape, dtype=bool)
    if overlay.get("terrain", {}).get("relief", True):
        keepout = [reval.smoothstep01(river_d - river_w * 0.5, 4.0, 30.0)]
        for sp in overlay.get("spaces", []):
            poly = [resolve(q) for q in sp["polygon_m"]]
            keepout.append(np.where(reval.point_in_poly(X, Y, poly), 0.0, reval.smoothstep01(terrain_relief.poly_distance(X, Y, poly, reval.dist_point_seg), 4.0, 28.0)))
        relief_w = terrain_relief.relief_weight(X, Y, wall_d, inside_walls, keepout) * RELIEF_SCALE
        probe, road_w = terrain_relief.carve_hollow_ways(np.zeros(X.shape), X, Y, [(r["pts"], r["width_m"]) for r in roads], wall_d, reval.dist_point_seg)
        asl = terrain_relief.add_open_country_relief(asl, X, Y, relief_w, np.full(X.shape, 1e9), road_w)
        asl = asl + probe * (~inside_walls)

    height_wu = (asl - datum) / mpu
    # The castle court is one levelled yard (the ward was built up and levelled).
    if circuit_poly:
        inside_vals = height_wu[inside_walls]
        court = float(np.median(inside_vals)) if inside_vals.size else float(height_wu.mean())
        reval.flatten_ground(height_wu, circuit_poly, court, 5.0, x0, y0, mpu, apron=2.0)
    for sp in overlay.get("spaces", []):
        poly = [resolve(q) for q in sp["polygon_m"]]
        level = float(np.mean([bilinear(height_wu, *q) for q in poly]))
        reval.flatten_ground(height_wu, poly, level, 10.0, x0, y0, mpu)

    def h_at_m(px, py):
        return bilinear(height_wu, px, py)

    # ---------------- streets ----------------
    streets = []
    for r in roads:
        streets.append({
            "id": r["id"], "name": "", "name_1343": r["name_1343"], "register_id": "", "confidence": r["confidence"],
            "class": r.get("class", "extramural_road"), "points": wu(r["pts"]), "width": round(r["width_m"] / mpu, 3),
        })

    def nearest_street(p):
        best = None
        for r in roads:
            d = polyline_dist(p, r["pts"])
            if best is None or d < best[0]:
                best = (d, r["id"])
        return best[1] if best else ""

    # ---------------- fortifications ----------------
    tower_specs = {t["id"]: t for t in overlay.get("towers", [])}
    curtains, towers, gates_out = [], [], []
    height_m = circ.get("height_m", 8.0)
    thick_m = circ.get("thickness_m", 2.0)
    for i, a in enumerate(anchors):
        b_ = anchors[(i + 1) % len(anchors)]
        curtains.append({
            "id": "%s.curtain.%02d" % (sid, i), "from": wpt(a["p"]), "to": wpt(b_["p"]), "state": a["state"] or "stone",
            "height": round(height_m / mpu, 3), "thickness": round(thick_m / mpu, 3),
            "base_from": round(h_at_m(*a["p"]), 3), "base_to": round(h_at_m(*b_["p"]), 3),
        })

    def tower_record(spec, p, along):
        rec = {
            "id": spec["id"], "name": spec["name"], "form": spec["form"], "state": spec["state"], "confidence": spec["confidence"],
            "at": wpt(p), "angle": round(along, 4), "w": round(spec["w"] / mpu, 3), "d": round(spec["d"] / mpu, 3),
            "h": round(spec["h"] / mpu, 3), "base_h": round(h_at_m(*p), 3),
        }
        if "roof_h" in spec:
            rec["roof_h"] = round(spec["roof_h"] / mpu, 3)
        return rec

    placed_towers = set()
    for i, a in enumerate(anchors):
        if not a["tower"]:
            continue
        prev_p = anchors[i - 1]["p"]
        next_p = anchors[(i + 1) % len(anchors)]["p"]
        towers.append(tower_record(tower_specs[a["tower"]], a["p"], math.atan2(next_p[1] - prev_p[1], next_p[0] - prev_p[0])))
        placed_towers.add(a["tower"])
    for spec in overlay.get("towers", []):
        if spec["id"] in placed_towers or "at" not in spec:
            continue
        towers.append(tower_record(spec, resolve(spec["at"]), math.radians(spec.get("angle_deg", 0.0))))
    for g in overlay.get("gates", []):
        idx = next(i for i, a in enumerate(anchors) if a["ref"] == g["id"])
        prev_p = anchors[idx - 1]["p"]
        next_p = anchors[(idx + 1) % len(anchors)]["p"]
        at = anchors[idx]["p"]
        gates_out.append({
            "id": g["id"], "name_1343": g["name_1343"], "state": g["state"], "confidence": g["confidence"],
            "at": wpt(at), "angle": round(math.atan2(next_p[1] - prev_p[1], next_p[0] - prev_p[0]), 4),
            "opening": round(g.get("opening_m", 3.6) / mpu, 3), "base_h": round(h_at_m(*at), 3),
        })
    # Inner walls (an upper ward's curtains) reuse the plan's free-standing wall list.
    inner_walls, inner_openings = [], []
    iw = overlay.get("inner_walls") or {}
    for w in iw.get("walls", []):
        a, c = resolve(w["from"]), resolve(w["to"])
        inner_walls.append({
            "id": w["id"], "from": wpt(a), "to": wpt(c), "state": "stone",
            "height": round(iw["height_m"] / mpu, 3), "thickness": round(iw["thickness_m"] / mpu, 3),
            "base_from": round(h_at_m(*a), 3), "base_to": round(h_at_m(*c), 3),
        })
        for o in w.get("openings", []):
            inner_openings.append({"wall_id": w["id"], "at": wpt(resolve(o["at"])), "width": round(o["width"] / mpu, 3), "street": ""})

    # Bridges where a road crosses the ditch.
    bridges = []
    if ditch_line:
        for r in roads:
            pts = r["pts"]
            for k in range(len(pts) - 1):
                for i in range(len(ditch_line) - 1):
                    q = reval.seg_intersection(pts[k], pts[k + 1], ditch_line[i], ditch_line[i + 1])
                    if q is None:
                        continue
                    ang = math.atan2(pts[k + 1][1] - pts[k][1], pts[k + 1][0] - pts[k][0])
                    length = ditch["width_m"] * 1.5
                    c, s_ = math.cos(ang), math.sin(ang)
                    bridges.append({
                        "id": "%s.bridge.%s" % (sid, r["id"].split(".")[-1]), "road": r["id"], "kind": "moat",
                        "at": [round(q[0] / mpu, 2), round(q[1] / mpu, 2)], "angle": round(ang, 4),
                        "length": round(length / mpu, 2), "width": round((r["width_m"] + 1.5) / mpu, 2),
                        "ha": round(h_at_m(q[0] - c * length / 2, q[1] - s_ * length / 2), 3),
                        "hb": round(h_at_m(q[0] + c * length / 2, q[1] + s_ * length / 2), 3),
                        "confidence": "plausible composite; a timber bridge over the castle ditch (reversible reconstruction)",
                    })

    # ---------------- buildings ----------------
    def building_record(bid, kind, ring, wall_h, roof, pitch, material, name, confidence, street_point=None, typ=None):
        hs = [h_at_m(*q) for q in ring]
        L01 = math.dist(ring[0], ring[1])
        L12 = math.dist(ring[1], ring[2])
        ridge = math.atan2(ring[1][1] - ring[0][1], ring[1][0] - ring[0][0]) if L01 >= L12 else math.atan2(ring[2][1] - ring[1][1], ring[2][0] - ring[1][0])
        door = None
        if street_point is not None:
            d = reval.door_on_edge(ring, street_point)
            door = [round(d[0] / mpu, 3), round(d[1] / mpu, 3), round(d[2], 4)]
        rec = {
            "id": bid, "kind": kind, "name_1343": name, "landmark_id": "", "confidence": confidence,
            "footprint": wu(ring), "base_h": round(min(hs), 3), "base_span": round(max(hs) - min(hs), 3),
            "wall_h": round(wall_h / mpu, 3), "roof": roof, "roof_pitch_deg": pitch, "ridge_angle": round(ridge, 4),
            "material": material, "street_id": nearest_street(reval.poly_centroid(ring)), "door": door,
            # Interiors are off at regional sites until a task furnishes them.
            "enterable": False, "tower_h": 0.0,
        }
        if typ:
            rec["type"] = typ
            rec["openings"] = False
        return rec

    buildings = []
    for spec in overlay.get("buildings", []):
        rm = spec["rect_m"]
        ring = rect_ring(rm["at"][0], rm["at"][1], rm["w"], rm["d"], math.radians(rm.get("angle_deg", 0.0)))
        centre = reval.poly_centroid(ring)
        street_point = None
        if spec["kind"] in ("chapel", "church", "house") or spec.get("door_toward"):
            street_point = resolve(spec["door_toward"]) if spec.get("door_toward") else min(
                (pt for r in roads for pt in reval.resample(r["pts"], 4.0)), key=lambda pt: math.dist(pt, centre))
        buildings.append(building_record(
            spec["id"], spec["kind"], ring, spec["wall_h"], spec["roof"], spec["roof_pitch_deg"], spec["material"],
            spec["name_1343"], spec["confidence"], street_point, spec.get("type")))
    # Keep the masonry clear: a building must not overlap the keep or a wall line.
    keep_rings = [rect_ring(t_["at"][0] * mpu, t_["at"][1] * mpu, t_["w"] * mpu + 2, t_["d"] * mpu + 2, 0.0) for t_ in towers if t_["form"] == "octagonal"]

    settle = overlay.get("settlement")
    clear_polys = []
    for sp in overlay.get("spaces", []):
        if settle and sp["id"] in settle.get("keep_clear", []):
            clear_polys.append([resolve(q) for q in sp["polygon_m"]])
    gardens = []
    if settle:
        hs_ = settle["house"]
        count = 0
        for row in settle["rows"]:
            pts = road_by_id[row["road"]]["pts"]
            half_road = road_by_id[row["road"]]["width_m"] * 0.5
            for side in row["sides"]:
                at = row["from_m"]
                while at <= row["to_m"]:
                    p, ang = point_along(pts, at)
                    w = rng.uniform(*hs_["w_m"])
                    d = rng.uniform(*hs_["d_m"])
                    nrm = (-math.sin(ang) * side, math.cos(ang) * side)
                    off = half_road + hs_["setback_m"] + d * 0.5
                    c = (p[0] + nrm[0] * off, p[1] + nrm[1] * off)
                    ring = rect_ring(c[0], c[1], w, d, ang)
                    spacing = rng.uniform(*hs_["spacing_m"])
                    blocked = (
                        any(reval.pip(q, cp) for cp in clear_polys for q in ring + [c])
                        or any(polyline_dist(q, r["pts"]) < r["width_m"] * 0.5 + 1.0 for r in roads for q in ring + [c])
                        or any(rings_overlap(ring, [tuple(q) for q in bb["footprint"]]) for bb in buildings)
                        or (circuit_poly and ring_dist(c, circuit_poly) < 30.0)
                        or not (x0 + 12 < c[0] < x1 - 12 and y0 + 12 < c[1] < y1 - 12)
                    )
                    if not blocked:
                        count += 1
                        bid = "%s.bldg.house.%02d" % (sid, count)
                        roof = "thatch" if rng.random() < 0.55 else "shingle"
                        material = "log" if rng.random() < 0.75 else "plank"
                        rec = building_record(bid, "house", ring, rng.uniform(*hs_["wall_h_m"]), roof, rng.choice((44, 48, 52)),
                                              material, "", settle["confidence"], street_point=p)
                        buildings.append(rec)
                        # A kitchen-garden plot behind every house.
                        gd = overlay.get("fields", {}).get("gardens")
                        if gd:
                            back = off + d * 0.5 + 1.0
                            g0 = (p[0] + nrm[0] * back, p[1] + nrm[1] * back)
                            gc = (g0[0] + nrm[0] * gd["depth_m"] * 0.5, g0[1] + nrm[1] * gd["depth_m"] * 0.5)
                            gardens.append(("%s.garden.%02d" % (sid, count), rect_ring(gc[0], gc[1], w, gd["depth_m"], ang), ang))
                    at += spacing
    buildings = [bb for bb in buildings if not any(rings_overlap([tuple(q) for q in bb["footprint"]], kr) for kr in keep_rings)]

    # ---------------- land use ----------------
    occupied = [[tuple(q) for q in bb["footprint"]] for bb in buildings]
    castle_zone = reval.inset_ring(circuit_poly, -(ditch["offset_m"] + ditch["width_m"]) if ditch else -20.0) if circuit_poly else []

    def blocked_land(p, margin=3.0):
        if castle_zone and reval.pip(p, castle_zone):
            return True
        if any(polyline_dist(p, r["pts"]) < r["width_m"] * 0.5 + margin for r in roads):
            return True
        if trace and polyline_dist(p, trace) < 10.0:
            return True
        if any(reval.pip(p, cp) for cp in clear_polys):
            return True
        return any(reval.pip(p, ring) for ring in occupied)

    fields = []
    fl = overlay.get("fields", {})
    pasture_polys = [[resolve(q) for q in pa["polygon_m"]] for pa in overlay.get("pastures", [])]
    for gid, ring, ang in gardens:
        if any(blocked_land(q, 1.0) for q in ring) or any(reval.pip(reval.poly_centroid(ring), pp) for pp in pasture_polys):
            continue
        fields.append({"id": gid, "crop": rng.choice(fl["gardens"]["crops"]), "sowing": "garden", "ploughed": True,
                       "angle": round(ang, 4), "polygon": wu(ring)})
    for block in fl.get("blocks", []):
        poly = [resolve(q) for q in block["polygon_m"]]
        ang = math.radians(block["strip_angle_deg"])
        ux, uy = math.cos(ang), math.sin(ang)  # along the strip
        vx, vy = -uy, ux  # across
        across = [q[0] * vx + q[1] * vy for q in poly]
        lo, hi = min(across), max(across)
        k = 0
        s = lo + 0.8
        while s < hi - 1.0:
            # One strip: the block between two cross lines, a narrow balk left unsown.
            strip = clip_poly_halfplane(poly, -vx, -vy, -s)
            strip = clip_poly_halfplane(strip, vx, vy, s + block["strip_m"] - 1.2)
            s += block["strip_m"]
            if len(strip) < 3 or abs(reval.poly_area(strip)) < 120.0:
                continue
            # Trim the strip where it runs into roads, houses, the ditch or the brook.
            along = [q[0] * ux + q[1] * uy for q in strip]
            a0, a1 = min(along), max(along)
            pieces, cur = [], None
            t = a0
            mid_s = s - block["strip_m"] * 0.5 - 0.6
            while t <= a1:
                p = (ux * t + vx * mid_s, uy * t + vy * mid_s)
                ok = reval.pip(p, poly) and not blocked_land(p, 4.0) and not any(reval.pip(p, pp) for pp in pasture_polys)
                if ok and cur is None:
                    cur = [t, t]
                elif ok:
                    cur[1] = t
                elif cur is not None:
                    pieces.append(cur)
                    cur = None
                t += 3.0
            if cur is not None:
                pieces.append(cur)
            for t0, t1 in pieces:
                if t1 - t0 < 24.0:
                    continue
                piece = clip_poly_halfplane(strip, -ux, -uy, -t0)
                piece = clip_poly_halfplane(piece, ux, uy, t1)
                if len(piece) < 3:
                    continue
                sow = block["sowing_cycle"][k % len(block["sowing_cycle"])]
                crop = {"winter": "rye", "spring": rng.choice(("barley", "oats", "barley")), "fallow": "fallow"}[sow]
                fields.append({"id": "%s.%02d" % (block["id"].replace(".fields.", ".field."), k), "crop": crop, "sowing": sow,
                               "ploughed": sow != "fallow", "angle": round(ang, 4), "polygon": wu(piece)})
                k += 1

    pastures = []
    for pa, poly in zip(overlay.get("pastures", []), pasture_polys):
        pastures.append({"id": pa["id"], "kind": pa["kind"], "fence": pa["fence"], "stock": pa["stock"], "polygon": wu(poly)})

    # ---------------- trees and shrubs ----------------
    trees, bushes = [], []
    tr = overlay.get("trees", {})
    field_rings = [[tuple(q) for q in f["polygon"]] for f in fields]

    def free_for_tree(p):
        if not (x0 + 4 < p[0] < x1 - 4 and y0 + 4 < p[1] < y1 - 4):
            return False
        if castle_zone and reval.pip(p, castle_zone):
            return False
        if any(polyline_dist(p, r["pts"]) < r["width_m"] * 0.5 + 2.5 for r in roads):
            return False
        if trace and polyline_dist(p, trace) < 4.5:
            return False
        if any(reval.pip(p, cp) for cp in clear_polys) or any(reval.pip(p, ring) for ring in occupied):
            return False
        return not any(reval.pip(p, ring) for ring in field_rings)

    carr = tr.get("carr")
    if carr and trace:
        tl = chain(trace)
        at = 0.0
        while at < tl[-1]:
            p, ang = point_along(trace, at)
            for side in (-1, 1):
                off = rng.uniform(5.0, carr["band_m"])
                q = (p[0] - math.sin(ang) * side * off, p[1] + math.cos(ang) * side * off)
                if free_for_tree(q) and rng.random() < 0.8:
                    trees.append([round(q[0] / mpu, 2), round(q[1] / mpu, 2), rng.choice(carr["species"]), round(rng.uniform(0.85, 1.25), 2)])
                elif rng.random() < 0.5 and free_for_tree(q):
                    bushes.append([round(q[0] / mpu, 2), round(q[1] / mpu, 2), rng.choice(("willow_shrub", "alder_shrub")), round(rng.uniform(0.9, 1.3), 2)])
            at += carr["spacing_m"]
    # Field-edge trees on the balks between blocks.
    for f in fields:
        if f["sowing"] == "garden":
            continue
        ring = [tuple(q) for q in f["polygon"]]
        perim = chain(ring + [ring[0]])
        at = rng.uniform(0, tr.get("hedgerow_spacing_m", 46.0))
        while at < perim[-1]:
            p, ang = point_along(ring + [ring[0]], at)
            q = (p[0] * mpu - math.sin(ang) * 2.5, p[1] * mpu + math.cos(ang) * 2.5)
            if rng.random() < 0.35 and free_for_tree(q):
                trees.append([round(q[0] / mpu, 2), round(q[1] / mpu, 2), rng.choice(tr["hedgerow_species"]), round(rng.uniform(0.8, 1.2), 2)])
            elif rng.random() < 0.25 and free_for_tree(q):
                bushes.append([round(q[0] / mpu, 2), round(q[1] / mpu, 2), rng.choice(("hawthorn", "dog_rose", "hazel_shrub", "juniper_shrub")), round(rng.uniform(0.9, 1.3), 2)])
            at += tr.get("hedgerow_spacing_m", 46.0)
    # Fruit trees at the end of the garden plots.
    for gid, ring, ang in gardens:
        far = ((ring[2][0] + ring[3][0]) * 0.5, (ring[2][1] + ring[3][1]) * 0.5)
        c = reval.poly_centroid(ring)
        q = (far[0] + (c[0] - far[0]) * 0.2, far[1] + (c[1] - far[1]) * 0.2)
        if rng.random() < 0.7 and not (castle_zone and reval.pip(q, castle_zone)):
            trees.append([round(q[0] / mpu, 2), round(q[1] / mpu, 2), rng.choice(tr.get("garden_species", ["apple"])), round(rng.uniform(0.8, 1.1), 2)])
    woods = []
    for grove in tr.get("groves", []):
        poly = [resolve(q) for q in grove["polygon_m"]]
        xs = [q[0] for q in poly]
        ys = [q[1] for q in poly]
        sp = grove["spacing_m"]
        cells = 0
        yy = min(ys)
        while yy < max(ys):
            xx = min(xs)
            while xx < max(xs):
                q = (xx + rng.uniform(-sp * 0.4, sp * 0.4), yy + rng.uniform(-sp * 0.4, sp * 0.4))
                if reval.pip(q, poly) and free_for_tree(q):
                    trees.append([round(q[0] / mpu, 2), round(q[1] / mpu, 2), rng.choice(grove["species"]), round(rng.uniform(0.85, 1.3), 2)])
                    cells += 1
                xx += sp
            yy += sp
        woods.append({"id": grove["id"], "kind": "mixed", "at": wpt(reval.poly_centroid(poly)), "area_m2": int(abs(reval.poly_area(poly))), "cells": cells})
    trees.sort(key=lambda t_: (t_[0], t_[1]))
    bushes.sort(key=lambda t_: (t_[0], t_[1]))

    # ---------------- places ----------------
    pois = []
    for poi in overlay.get("points_of_interest", []):
        p = resolve(poi["at"])
        pois.append({**{k: v for k, v in poi.items() if k != "at"}, "at": wpt(p), "base_h": round(h_at_m(*p), 3)})
    spawns = []
    for sp in overlay.get("spawns", []):
        p = resolve(sp["at"])
        spawns.append({"id": sp["id"], "record": sp["record"], "at": wpt(p), "base_h": round(h_at_m(*p), 3)})
    districts = [{"id": d["id"], "name": d["name"], "name_1343": d["name_1343"], "polygon": wu([resolve(q) for q in d["polygon_m"]])}
                 for d in overlay.get("districts", [])]
    spaces = overlay.get("spaces", [])
    forum = {}
    if spaces:
        sp = spaces[0]
        forum = {"id": sp["id"], "name_1343": sp["name_1343"], "polygon": wu([resolve(q) for q in sp["polygon_m"]]), "confidence": sp["confidence"]}

    plan = {
        "schema": SCHEMA,
        "snapshot": overlay["snapshot"],
        "license_notes": [osm.license, "EU-DEM v1.1 (Copernicus) via OpenTopoData", "1343 overlay: Reval Rebel authors"],
        "site": {
            "id": sid, "name": site["name"], "name_1343": site["name_1343"],
            "location_id": site["location_id"], "map_id": site["map_id"], "scene_id": site["scene_id"],
            # No regional overlay draws a shoreline yet (Paide is inland), so no coast.
            "coast": False, "features": site.get("features", {}), "default_spawn": site.get("default_spawn", ""),
            "music_theme": site.get("music_theme", ""), "datum_asl": datum, "confidence": site["confidence"],
        },
        "origin": site["origin"],
        "metres_per_world_unit": mpu,
        "bounds": [round(x0 / mpu, 3), round(y0 / mpu, 3), round(x1 / mpu, 3), round(y1 / mpu, 3)],
        "sea_level": 0.0,
        "height_grid": {"cell": HEIGHT_CELL_WU, "nx": nx, "ny": ny, "origin": [round(x0 / mpu, 3), round(y0 / mpu, 3)], "file": "height.json"},
        "splat": {"file": "splat.png", "px_per_unit": SPLAT_PX_PER_WU, "channels": ["paving", "packed_earth", "sand", "mud"]},
        # No coast: an empty shoreline keeps sea, shore field, surf, ships and harbour off.
        "shoreline": [],
        "harjapea": stream_out or {},
        "moat": moat_out,
        "toompea_edge": [],
        "forum": forum,
        "circuit": [{"at": wpt(a["p"]), "state": a["state"] or "stone", "ref": a["ref"], "tower": a["tower"], "osm": ""} for a in anchors],
        "curtains": curtains,
        "towers": towers,
        "barbicans": [],
        "gates": gates_out,
        "toompea_walls": inner_walls,
        "toompea_openings": inner_openings,
        "castle": {},
        "streets": streets,
        "buildings": sorted(buildings, key=lambda b_: b_["id"]),
        "sites": [],
        "gutters": [],
        "trees": trees,
        "bushes": bushes,
        "districts": districts,
        "fields": fields,
        "pastures": pastures,
        "orchards": [],
        "woods": woods,
        "farmsteads": [],
        "bridges": bridges,
        "harbour": {},
        "points_of_interest": pois,
        "spawns": spawns,
        "flows": [],
        "review_relief_wu": 20.0,
    }

    q = np.round(height_wu * 100).astype(np.int64) + HEIGHT_OFFSET_CM
    q = np.clip(q, 0, 65535).astype("<u2")
    height_doc = {
        "schema": "rr.city_height.v1", "nx": nx, "ny": ny, "cell": HEIGHT_CELL_WU,
        "origin": [round(x0 / mpu, 3), round(y0 / mpu, 3)], "encoding": "uint16le_cm_offset", "offset_cm": HEIGHT_OFFSET_CM,
        "data": base64.b64encode(q.tobytes()).decode("ascii"),
    }
    return {
        "plan": plan, "height": height_doc, "splat": reval.render_splat(plan, mpu), "roads": reval.render_roads(plan, mpu),
        "minimap": reval.render_minimap(plan, height_wu), "height_wu": height_wu, "extent_m": (x0, y0, x1, y1), "mpu": mpu,
    }


def write_site_outputs(site_id: str, result: dict, check=False) -> int:
    od = out_dir(site_id)
    files = {
        od / "plan.json": (json.dumps(result["plan"], ensure_ascii=False, indent=None, separators=(",", ":")) + "\n").encode(),
        od / "height.json": (json.dumps(result["height"], separators=(",", ":")) + "\n").encode(),
    }
    for name in ("splat", "roads", "minimap"):
        buf = io.BytesIO()
        result[name].save(buf, format="PNG", optimize=True)
        files[od / f"{name}.png"] = buf.getvalue()
    stale = [path for path, data in files.items() if not path.exists() or path.read_bytes() != data]
    if check:
        if stale:
            print("stale %s plan outputs:\n  " % site_id + "\n  ".join(str(p.relative_to(ROOT)) for p in stale))
            return 1
        print("%s plan outputs are current" % site_id)
        return 0
    od.mkdir(parents=True, exist_ok=True)
    for path, data in files.items():
        path.write_bytes(data)
    reval.render_review(result, review_png(site_id))
    p = result["plan"]
    print(f"{site_id}: {len(p['streets'])} roads, {len(p['buildings'])} buildings, {len(p['towers'])} towers, "
          f"{len(p['gates'])} gates, {len(p['fields'])} fields, {len(p['trees'])} trees, coast={p['site']['coast']}")
    print(f"height grid {p['height_grid']['nx']}x{p['height_grid']['ny']}, range {result['height_wu'].min():.1f}..{result['height_wu'].max():.1f} wu above datum {p['site']['datum_asl']} m")
    return 0


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--site", default=REVAL_SITE)
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--import-osm", type=Path)
    ap.add_argument("--import-dem", type=Path)
    args = ap.parse_args(argv)
    if args.site == REVAL_SITE:
        # Reval keeps its own builder and constants (ADR 0042 section 1).
        rest = []
        skip = False
        for a in argv:
            if skip:
                skip = False
                continue
            if a == "--site":
                skip = True
                continue
            if a.startswith("--site="):
                continue
            rest.append(a)
        return reval.main(rest)
    path = overlay_path(args.site)
    if not path.exists():
        print(f"unknown site {args.site!r}: {path.relative_to(ROOT)} missing", file=sys.stderr)
        return 2
    overlay = json.loads(path.read_text())
    if overlay["site"]["id"] != args.site:
        print(f"{path.relative_to(ROOT)} declares site {overlay['site']['id']!r}", file=sys.stderr)
        return 2
    import_inputs(overlay, args.import_osm, args.import_dem)
    return write_site_outputs(args.site, build_site(overlay), check=args.check)


if __name__ == "__main__":
    sys.exit(main())
