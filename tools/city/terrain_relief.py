"""Natural relief for the land outside the Reval walls, and the road map.

The EU-DEM trend is a 25 m surface model, so the country round the town comes
out as a smooth, flat plate. Real ground is never flat: this module adds, on top
of that trend and only where nothing else authored the ground,

- domain-warped fractal swells and hummocks (wavelengths 12 .. 260 m),
- ridged gullies and swales (the way water and thaw cut a lowland),
- low sand ridges in the beach hinterland,
- hollow ways: cart roads worn below the surrounding ground, with a spoil berm
  on each side.

Everything is deterministic (seeded lattice noise, no wall-clock, no system
RNG), so `build_reval_city_plan.py --check` stays stable. `road_map` writes the
raster the ground shader reads for wheel ruts, a trodden centre strip and
verges; ruts themselves are procedural in the shader.
"""
from __future__ import annotations

import numpy as np

# Amplitudes in metres (peak-to-peak order). Tuned so the open country reads as
# rolling: a few metres across a field, tens of centimetres across a footpath.
SWELL_AMPS = ((260.0, 5.0), (110.0, 3.2), (48.0, 1.8), (21.0, 0.6), (11.0, 0.18))
GULLY_WAVELENGTH_M = 95.0
GULLY_DEPTH_M = 0.85
DUNE_WAVELENGTH_M = 34.0
DUNE_HEIGHT_M = 0.85
# Fade-in of the relief: none against the walls, full beyond FAR_M.
NEAR_WALL_M = 16.0
FAR_WALL_M = 130.0

ROAD_TRAFFIC = {
    "road.viru": 1.0, "road.karja": 0.9, "road.harju": 0.85, "road.tartu": 0.95,
    "road.harbour": 1.0, "road.coast_west": 0.6, "road.sand_beach": 0.45,
    "road.toompea_west": 0.7, "road.toompea_south": 0.7,
}
HOLLOW_DEPTH_M = 0.24
BERM_HEIGHT_M = 0.13
# Lateral range stored in the road map (metres either side of the centreline).
LATERAL_RANGE_M = 5.0


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def lattice_noise(x, y, wavelength, seed):
    """Smooth value noise in 0..1 sampled at metre coordinates."""
    n = 1 + int(4096 // max(wavelength, 1.0)) + 3
    rng = np.random.default_rng(seed)
    lat = rng.random((n, n))
    # The indices below wrap modulo n - 1, so the lattice must be periodic. Without
    # this the noise jumped by up to ~10 m along every wrap line (a vertical scarp
    # across the south approach that the Karja road climbed).
    lat[:, n - 1] = lat[:, 0]
    lat[n - 1, :] = lat[0, :]
    fx = x / wavelength + 1024.0
    fy = y / wavelength + 1024.0
    ix = np.floor(fx).astype(np.int64)
    iy = np.floor(fy).astype(np.int64)
    ux = fx - ix
    uy = fy - iy
    ux = ux * ux * (3.0 - 2.0 * ux)
    uy = uy * uy * (3.0 - 2.0 * uy)
    ix %= n - 1
    iy %= n - 1
    a = lat[iy, ix]
    b = lat[iy, ix + 1]
    c = lat[iy + 1, ix]
    d = lat[iy + 1, ix + 1]
    return (a * (1 - ux) + b * ux) * (1 - uy) + (c * (1 - ux) + d * ux) * uy


def poly_distance(X, Y, poly, dist_point_seg):
    """Distance to a closed polygon's outline (vectorised)."""
    best = np.full(X.shape, 1e9)
    for i in range(len(poly)):
        ax, ay = poly[i]
        bx, by = poly[(i + 1) % len(poly)]
        dd, _ = dist_point_seg(X, Y, ax, ay, bx, by)
        best = np.minimum(best, dd)
    return best


def polyline_distance(X, Y, pts, dist_point_seg):
    best = np.full(X.shape, 1e9)
    for i in range(len(pts) - 1):
        dd, _ = dist_point_seg(X, Y, pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1])
        best = np.minimum(best, dd)
    return best


def relief_weight(X, Y, circuit_dist, inside_town, keepout):
    """0 where the authored ground must stay untouched, 1 in open country."""
    w = smoothstep(NEAR_WALL_M, FAR_WALL_M, circuit_dist)
    w = np.where(inside_town, 0.0, w)
    for mask in keepout:
        w = w * mask
    return w


def add_open_country_relief(asl, X, Y, weight, shore_d, road_w):
    """Return `asl` (metres) with swells, gullies and dunes added where `weight` > 0.

    `road_w` is 0..1 along cart roads: the small-scale relief is damped there so
    a road stays travelable while the broad swells still carry it up and down.
    """
    wx = X + (lattice_noise(X, Y, 180.0, 11) - 0.5) * 90.0
    wy = Y + (lattice_noise(X, Y, 180.0, 12) - 0.5) * 90.0
    big = np.zeros(X.shape)
    small = np.zeros(X.shape)
    for k, (wavelength, amp) in enumerate(SWELL_AMPS):
        layer = (lattice_noise(wx, wy, wavelength, 100 + k) - 0.5) * 2.0 * amp
        if wavelength >= 100.0:
            big += layer
        else:
            small += layer
    # Ridged noise: 1 on the crease. Cubed so gullies are narrow with broad flanks.
    # A smooth crease (not |x|, which has a sharp apex that reads as a fold).
    gully = np.exp(-(((lattice_noise(wx, wy, GULLY_WAVELENGTH_M, 200) * 2.0 - 1.0) / 0.24) ** 2))
    # Gullies grow where the swell is low (water runs downhill into them).
    low = smoothstep(0.5, -1.0, big / SWELL_AMPS[0][1])
    gullies = -gully * GULLY_DEPTH_M * (0.35 + 0.65 * low)
    # Sand ridges in the beach hinterland, 20 m .. 320 m from the water.
    dune_zone = smoothstep(18.0, 70.0, shore_d) * (1.0 - smoothstep(180.0, 340.0, shore_d))
    dune_ridge = np.exp(-(((lattice_noise(wx, wy, DUNE_WAVELENGTH_M, 300) * 2.0 - 1.0) / 0.5) ** 2))
    dunes = dune_ridge * DUNE_HEIGHT_M * dune_zone
    keep_small = 1.0 - 0.85 * road_w
    delta = big + (small + gullies + dunes) * keep_small
    return asl + delta * weight


def carve_hollow_ways(asl, X, Y, roads, near_wall, dist_point_seg):
    """Sink each road below the ground beside it and heap a berm on either side.

    `roads` is a list of (points_m, width_m). Returns (asl, road_w) where
    `road_w` is the 0..1 road body weight used to damp the small relief.
    """
    road_w = np.zeros(X.shape)
    carve = np.zeros(X.shape)
    # Near the gates the street belongs to the town plan: no hollow.
    fade = smoothstep(8.0, 40.0, near_wall)
    for pts, width in roads:
        d = polyline_distance(X, Y, pts, dist_point_seg)
        half = width * 0.5
        body = 1.0 - smoothstep(half * 0.7, half * 1.35, d)
        road_w = np.maximum(road_w, body)
        trough = (1.0 - smoothstep(0.0, half * 0.95, d)) * HOLLOW_DEPTH_M
        berm_at = half * 1.25
        berm = np.exp(-(((d - berm_at) / (half * 0.42)) ** 2)) * BERM_HEIGHT_M
        delta = (berm - trough) * (d < half * 3.0)
        carve = np.where(np.abs(delta) > np.abs(carve), delta, carve)
    return asl + carve * fade, road_w * fade


def road_map(width, height, origin, px_per_wu, roads_wu, mpu):
    """RGBA uint8 raster for the ground shader.

    R road body (1 on the track, soft edge)   G signed lateral offset
    (128 = centreline, +-LATERAL_RANGE_M)     B traffic wear   A verge band.
    `roads_wu` is a list of (id, points_wu, width_wu).
    """
    out = np.zeros((height, width, 4), dtype=np.uint8)
    out[..., 1] = 128
    best = np.full((height, width), 1e9)
    for road_id, pts, width_wu in roads_wu:
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        margin = width_wu * 2.2 + 4.0
        i0 = max(int((min(ys) - margin - origin[1]) * px_per_wu), 0)
        i1 = min(int((max(ys) + margin - origin[1]) * px_per_wu) + 1, height)
        j0 = max(int((min(xs) - margin - origin[0]) * px_per_wu), 0)
        j1 = min(int((max(xs) + margin - origin[0]) * px_per_wu) + 1, width)
        if i1 <= i0 or j1 <= j0:
            continue
        jj, ii = np.meshgrid(np.arange(j0, j1), np.arange(i0, i1))
        px = origin[0] + (jj + 0.5) / px_per_wu
        py = origin[1] + (ii + 0.5) / px_per_wu
        dmin = np.full(px.shape, 1e9)
        lat = np.zeros(px.shape)
        for k in range(len(pts) - 1):
            ax, ay = pts[k]
            bx, by = pts[k + 1]
            dx, dy = bx - ax, by - ay
            ll = max(dx * dx + dy * dy, 1e-12)
            t = np.clip(((px - ax) * dx + (py - ay) * dy) / ll, 0.0, 1.0)
            qx, qy = ax + t * dx, ay + t * dy
            dd = np.hypot(px - qx, py - qy)
            cross = dx * (py - ay) - dy * (px - ax)
            closer = dd < dmin
            dmin = np.where(closer, dd, dmin)
            lat = np.where(closer, np.sign(cross) * dd, lat)
        half = width_wu * 0.5
        body = 1.0 - smoothstep(half * 0.8, half * 1.2, dmin)
        verge = smoothstep(half * 0.9, half * 1.4, dmin) * (1.0 - smoothstep(half * 1.4, half * 2.4, dmin))
        lat_m = np.clip(lat * mpu / LATERAL_RANGE_M, -1.0, 1.0)
        region = best[i0:i1, j0:j1]
        take = (dmin < region) & (dmin < half * 2.4)
        sub = out[i0:i1, j0:j1]
        sub[..., 0] = np.where(take, np.round(body * 255), sub[..., 0])
        sub[..., 1] = np.where(take, np.round(128 + lat_m * 127), sub[..., 1])
        sub[..., 2] = np.where(take, np.round(ROAD_TRAFFIC.get(road_id, 0.7) * 255), sub[..., 2])
        sub[..., 3] = np.where(take, np.round(verge * 255), sub[..., 3])
        best[i0:i1, j0:j1] = np.where(take, dmin, region)
    return out
