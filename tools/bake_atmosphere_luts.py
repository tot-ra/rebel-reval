#!/usr/bin/env python3
"""Offline Hillaire atmosphere LUT bake (WS-09): transmittance and multi-scattering.

Implements Sebastien Hillaire, "A Scalable and Production Ready Sky and Atmosphere
Rendering Technique" (EGSR 2020), with Bruneton's transmittance parameterisation
(Bruneton and Neyret 2008, "Precomputed Atmospheric Scattering"). Both LUTs depend only
on the atmosphere constants, so they are baked once here instead of in compute passes the
GL Compatibility renderer does not have. The sky-view LUT stays a runtime pass (WS-10).

Ported from Tidewater (MIT), see docs/THIRD_PARTY_NOTICES.md `notice.code.tidewater`
(`src/sky/Atmosphere.js`: `atmosphereMedium`, `atmosphereTransmittanceUV`,
`atmosphereRaySphereNearest` and the transmittance / multi-scattering kernels). Two
recorded deviations, both listed in the profile `conventions` block:

1. Tidewater's forward transmittance sub-UV scales by W/(W+1) while its bake inverts with
   W/(W-1), so a lookup lands up to half a texel off. We use the consistent Bruneton pair
   `x_tex = 0.5/N + x * (N-1)/N` in both directions.
2. The multi-scattering sphere integral uses a 64-point Fibonacci sphere (contract) instead
   of Tidewater's 8x8 stratified theta/phi grid, which over-samples the poles.

Units are km. The GLSL side of the same parameterisation lives in
scripts/map/view3d/atmosphere_common.gdshaderinc and must stay in sync with this file.

Contract: docs/tasks/water_sky/WS-09_atmosphere_static_luts.md.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import struct
import sys
from dataclasses import asdict, dataclass
from pathlib import Path

import numpy as np

TOOL_VERSION = "1.0.0"
ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUT = ROOT / "assets" / "sky" / "atmosphere"
TRANSMITTANCE_FILE = "transmittance.exr"
MULTISCATTER_FILE = "multiscatter.exr"
PROFILE_FILE = "atmosphere_profile.json"
MAX_OUTPUT_BYTES = 1024 * 1024

# Hillaire 2020 section 4 / Tidewater defaults. Keep them identical: the unit tests use them as
# the analytic oracle, and art-direction tints belong to WS-10, not to the data.
R_GROUND = 6360.0
R_TOP = 6460.0
RAYLEIGH_SCATTERING = (5.802e-3, 13.558e-3, 33.1e-3)
RAYLEIGH_SCALE_HEIGHT = 8.0
MIE_SCATTERING = 3.996e-3
MIE_EXTINCTION = 4.440e-3
MIE_SCALE_HEIGHT = 1.2
MIE_G = 0.8
OZONE_ABSORPTION = (0.650e-3, 1.881e-3, 0.085e-3)
OZONE_CENTER = 25.0
OZONE_HALF_WIDTH = 15.0
GROUND_ALBEDO = (0.06, 0.08, 0.10)

TRANSMITTANCE_WIDTH = 256
TRANSMITTANCE_HEIGHT = 64
TRANSMITTANCE_STEPS = 40
MULTISCATTER_SIZE = 32
MULTISCATTER_DIRECTIONS = 64
MULTISCATTER_STEPS = 20
# Hillaire and Tidewater sample each multi-scattering segment at 0.3 of its length.
MULTISCATTER_STEP_OFFSET = 0.3
# Tidewater keeps the bottom/top multi-scattering rows just inside the shell so the
# ground-hit and top-exit ray tests never start exactly on a sphere.
MULTISCATTER_HEIGHT_CLAMP = (0.001, 0.999)

EXR_HALF = 1
EXR_MAGIC = 20000630
EXR_VERSION = 2


@dataclass(frozen=True)
class AtmosphereScales:
    rayleigh: float = 1.0
    mie: float = 1.0
    ozone: float = 1.0


# --------------------------------------------------------------------------- medium


def atmosphere_medium(h_km: np.ndarray, scales: AtmosphereScales) -> tuple[np.ndarray, np.ndarray]:
    """Hillaire 2020 section 4: (extinction, scattering) per km, shape h.shape + (3,)."""
    h = np.asarray(h_km, dtype=np.float64)[..., None]
    rayleigh = np.asarray(RAYLEIGH_SCATTERING) * np.exp(-h / RAYLEIGH_SCALE_HEIGHT) * scales.rayleigh
    mie_density = np.exp(-h / MIE_SCALE_HEIGHT) * scales.mie
    ozone_density = np.maximum(0.0, 1.0 - np.abs(h - OZONE_CENTER) / OZONE_HALF_WIDTH)
    ozone = np.asarray(OZONE_ABSORPTION) * ozone_density * scales.ozone
    extinction = rayleigh + MIE_EXTINCTION * mie_density + ozone
    scattering = rayleigh + MIE_SCATTERING * mie_density
    return extinction, scattering


def ray_sphere_nearest(ro: np.ndarray, rd: np.ndarray, radius: float) -> np.ndarray:
    """Nearest positive hit of a planet-centred sphere, -1 on a miss (Tidewater semantics)."""
    b = np.sum(ro * rd, axis=-1)
    c = np.sum(ro * ro, axis=-1) - radius * radius
    disc = b * b - c
    sq = np.sqrt(np.maximum(disc, 0.0))
    t0 = -b - sq
    t1 = -b + sq
    hit = np.where(t0 > 0.0, t0, np.where(t1 > 0.0, t1, -1.0))
    return np.where(disc < 0.0, -1.0, hit)


# --------------------------------------------------------------------------- parameterisation


def unit_to_sub_uv(x: np.ndarray, size: int) -> np.ndarray:
    """Map [0, 1] onto first..last texel centres so linear filtering never reads past the edge."""
    return 0.5 / size + np.asarray(x) * (size - 1) / size


def sub_uv_to_unit(u: np.ndarray, size: int) -> np.ndarray:
    return (np.asarray(u) - 0.5 / size) * size / (size - 1)


def transmittance_uv(r: np.ndarray, mu: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Bruneton (r, mu) -> transmittance texture uv; valid for mu above the ground horizon."""
    r = np.asarray(r, dtype=np.float64)
    mu = np.asarray(mu, dtype=np.float64)
    h_top = math.sqrt(R_TOP * R_TOP - R_GROUND * R_GROUND)
    rho = np.sqrt(np.maximum(r * r - R_GROUND * R_GROUND, 0.0))
    disc = r * r * (mu * mu - 1.0) + R_TOP * R_TOP
    d = np.maximum(0.0, -r * mu + np.sqrt(np.maximum(disc, 0.0)))
    d_min = R_TOP - r
    d_max = rho + h_top
    x_mu = (d - d_min) / (d_max - d_min)
    x_r = rho / h_top
    return unit_to_sub_uv(x_mu, TRANSMITTANCE_WIDTH), unit_to_sub_uv(x_r, TRANSMITTANCE_HEIGHT)


def transmittance_r_mu(u: np.ndarray, v: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Inverse of transmittance_uv."""
    x_mu = sub_uv_to_unit(u, TRANSMITTANCE_WIDTH)
    x_r = sub_uv_to_unit(v, TRANSMITTANCE_HEIGHT)
    h_top = math.sqrt(R_TOP * R_TOP - R_GROUND * R_GROUND)
    rho = x_r * h_top
    r = np.sqrt(rho * rho + R_GROUND * R_GROUND)
    d_min = R_TOP - r
    d_max = rho + h_top
    d = d_min + x_mu * (d_max - d_min)
    safe_d = np.where(d == 0.0, 1.0, d)
    mu = np.where(d == 0.0, 1.0, (h_top * h_top - rho * rho - d * d) / (2.0 * r * safe_d))
    return r, np.clip(mu, -1.0, 1.0)


def multiscatter_uv(r: np.ndarray, mu_sun: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Hillaire 2020 section 5.5: (r, cos sun zenith) -> multi-scattering texture uv."""
    x = np.asarray(mu_sun) * 0.5 + 0.5
    y = np.clip((np.asarray(r) - R_GROUND) / (R_TOP - R_GROUND), 0.0, 1.0)
    return unit_to_sub_uv(x, MULTISCATTER_SIZE), unit_to_sub_uv(y, MULTISCATTER_SIZE)


def texel_centres(size: int) -> np.ndarray:
    return (np.arange(size, dtype=np.float64) + 0.5) / size


def sample_bilinear(lut: np.ndarray, u: np.ndarray, v: np.ndarray) -> np.ndarray:
    """Clamp-to-edge linear filtering, matching a `filter_linear, repeat_disable` sampler."""
    height, width = lut.shape[:2]
    x = np.clip(np.asarray(u) * width - 0.5, 0.0, width - 1.0)
    y = np.clip(np.asarray(v) * height - 0.5, 0.0, height - 1.0)
    x0 = np.minimum(np.floor(x).astype(np.int64), width - 2)
    y0 = np.minimum(np.floor(y).astype(np.int64), height - 2)
    fx = (x - x0)[..., None]
    fy = (y - y0)[..., None]
    top = lut[y0, x0] * (1.0 - fx) + lut[y0, x0 + 1] * fx
    bottom = lut[y0 + 1, x0] * (1.0 - fx) + lut[y0 + 1, x0 + 1] * fx
    return top * (1.0 - fy) + bottom * fy


def sample_transmittance(lut: np.ndarray, r: np.ndarray, mu: np.ndarray) -> np.ndarray:
    u, v = transmittance_uv(r, mu)
    return sample_bilinear(lut, u, v)


# --------------------------------------------------------------------------- LUT bakes


def bake_transmittance(scales: AtmosphereScales) -> np.ndarray:
    """Hillaire 2020 section 5.1: exp(-optical depth to the top), shape (64, 256, 3).

    Row 0 is the ground (r = R_GROUND), column 0 is straight up (mu = 1). Optical depth
    uses 40 midpoint steps, exactly like Tidewater's kernel.
    """
    u, v = np.meshgrid(texel_centres(TRANSMITTANCE_WIDTH), texel_centres(TRANSMITTANCE_HEIGHT))
    r, mu = transmittance_r_mu(u, v)
    ro = np.stack([np.zeros_like(r), r, np.zeros_like(r)], axis=-1)
    rd = np.stack([np.sqrt(np.maximum(1.0 - mu * mu, 0.0)), mu, np.zeros_like(mu)], axis=-1)
    # The top row starts on the R_TOP sphere, where rounding turns the zero-length exit into a
    # -1 miss; clamp so those texels stay exactly 1 instead of exceeding it.
    dt = np.maximum(ray_sphere_nearest(ro, rd, R_TOP), 0.0) / TRANSMITTANCE_STEPS
    depth = np.zeros(r.shape + (3,))
    for i in range(TRANSMITTANCE_STEPS):
        p = ro + rd * ((i + 0.5) * dt)[..., None]
        extinction, _ = atmosphere_medium(np.linalg.norm(p, axis=-1) - R_GROUND, scales)
        depth += extinction * dt[..., None]
    return np.exp(-depth)


def fibonacci_sphere(count: int) -> np.ndarray:
    """Deterministic, near-uniform unit directions (y up); each covers 4*pi/count sr."""
    i = np.arange(count, dtype=np.float64)
    y = 1.0 - (2.0 * i + 1.0) / count
    ring = np.sqrt(np.maximum(1.0 - y * y, 0.0))
    phi = i * math.pi * (3.0 - math.sqrt(5.0))
    return np.stack([np.cos(phi) * ring, y, np.sin(phi) * ring], axis=-1)


@dataclass
class MultiscatterBake:
    psi_ms: np.ndarray  # (32, 32, 3): Hillaire's Psi_ms, row 0 = ground, column 31 = sun at zenith
    second_order: np.ndarray  # L_2nd, same shape
    transfer: np.ndarray  # f_ms, same shape


def bake_multiscatter(transmittance: np.ndarray, scales: AtmosphereScales, albedo=GROUND_ALBEDO) -> MultiscatterBake:
    """Hillaire 2020 section 5.5, equations 5-10.

    Integrates isotropic second-order in-scattering (L_2nd) and the transfer factor f_ms over
    the whole sphere of directions, then sums the geometric series Psi_ms = L_2nd / (1 - f_ms).
    Sun transmittance is read from the transmittance LUT with bilinear filtering, as the
    shader would.
    """
    n = MULTISCATTER_SIZE
    u, v = np.meshgrid(texel_centres(n), texel_centres(n))
    cos_sun = sub_uv_to_unit(u, n) * 2.0 - 1.0
    y = np.clip(sub_uv_to_unit(v, n), *MULTISCATTER_HEIGHT_CLAMP)
    r = R_GROUND + y * (R_TOP - R_GROUND)
    sun = np.stack([np.zeros_like(cos_sun), cos_sun, -np.sqrt(np.maximum(1.0 - cos_sun * cos_sun, 0.0))], axis=-1)
    sun = sun / np.linalg.norm(sun, axis=-1, keepdims=True)

    # Broadcast to (row, column, direction).
    ro = np.stack([np.zeros_like(r), r, np.zeros_like(r)], axis=-1)[:, :, None, :]
    sun_b = sun[:, :, None, :]
    rd = fibonacci_sphere(MULTISCATTER_DIRECTIONS)[None, None, :, :]
    ro, rd = np.broadcast_arrays(ro, rd)
    t_bottom = ray_sphere_nearest(ro, rd, R_GROUND)
    t_top = ray_sphere_nearest(ro, rd, R_TOP)
    hit_ground = t_bottom > 0.0
    t_max = np.where(hit_ground, t_bottom, t_top)
    dt = t_max / MULTISCATTER_STEPS

    iso_phase = 1.0 / (4.0 * math.pi)
    throughput = np.ones(t_max.shape + (3,))
    lum = np.zeros_like(throughput)
    fms = np.zeros_like(throughput)
    for s in range(MULTISCATTER_STEPS):
        p = ro + rd * ((s + MULTISCATTER_STEP_OFFSET) * dt)[..., None]
        pr = np.linalg.norm(p, axis=-1)
        extinction, scattering = atmosphere_medium(pr - R_GROUND, scales)
        cos_sun_p = np.sum(p * sun_b, axis=-1) / pr
        t_sun = sample_transmittance(transmittance, pr, cos_sun_p)
        lit = (ray_sphere_nearest(p, np.broadcast_to(sun_b, p.shape), R_GROUND) <= 0.0)[..., None]
        source = t_sun * lit * scattering * iso_phase
        t_step = np.exp(-extinction * dt[..., None])
        ext = np.maximum(extinction, 1e-6)
        # Analytic integration of a constant source over the segment (Hillaire 2015, eq. 5).
        lum += throughput * (source - source * t_step) / ext
        fms += throughput * (scattering - scattering * t_step) / ext
        throughput *= t_step

    ground = ro + rd * t_max[..., None]
    ground_up = ground / np.linalg.norm(ground, axis=-1, keepdims=True)
    cos_ground = np.sum(ground_up * sun_b, axis=-1)
    t_ground = sample_transmittance(transmittance, np.full_like(cos_ground, R_GROUND), cos_ground)
    bounce = t_ground * throughput * np.maximum(cos_ground, 0.0)[..., None] * np.asarray(albedo) / math.pi
    lum += np.where(hit_ground[..., None], bounce, 0.0)

    solid_angle = 4.0 * math.pi / MULTISCATTER_DIRECTIONS
    second_order = np.sum(lum, axis=2) * solid_angle * iso_phase
    transfer = np.sum(fms, axis=2) * solid_angle * iso_phase
    return MultiscatterBake(second_order / (1.0 - transfer), second_order, transfer)


# --------------------------------------------------------------------------- EXR


def _exr_attribute(name: str, kind: str, payload: bytes) -> bytes:
    return name.encode() + b"\0" + kind.encode() + b"\0" + struct.pack("<i", len(payload)) + payload


def encode_exr(rgb: np.ndarray) -> bytes:
    """Minimal single-part scanline OpenEXR 2.0: RGBA HALF, NO_COMPRESSION, alpha = 1.

    Row 0 of `rgb` is scanline y = 0 (the top of the image, which Godot reads as uv.y = 0).
    """
    height, width = rgb.shape[:2]
    channels = {
        "A": np.ones((height, width)),
        "B": rgb[..., 2],
        "G": rgb[..., 1],
        "R": rgb[..., 0],
    }
    names = sorted(channels)
    chlist = b"".join(name.encode() + b"\0" + struct.pack("<iB3xii", EXR_HALF, 0, 1, 1) for name in names) + b"\0"
    header = struct.pack("<ii", EXR_MAGIC, EXR_VERSION)
    header += _exr_attribute("channels", "chlist", chlist)
    header += _exr_attribute("compression", "compression", b"\0")
    header += _exr_attribute("dataWindow", "box2i", struct.pack("<4i", 0, 0, width - 1, height - 1))
    header += _exr_attribute("displayWindow", "box2i", struct.pack("<4i", 0, 0, width - 1, height - 1))
    header += _exr_attribute("lineOrder", "lineOrder", b"\0")
    header += _exr_attribute("pixelAspectRatio", "float", struct.pack("<f", 1.0))
    header += _exr_attribute("screenWindowCenter", "v2f", struct.pack("<2f", 0.0, 0.0))
    header += _exr_attribute("screenWindowWidth", "float", struct.pack("<f", 1.0))
    header += b"\0"

    halves = {name: np.asarray(channels[name], dtype="<f2") for name in names}
    line_bytes = len(names) * width * 2
    first_chunk = len(header) + 8 * height
    offsets = struct.pack(f"<{height}Q", *(first_chunk + y * (8 + line_bytes) for y in range(height)))
    chunks = b"".join(
        struct.pack("<ii", y, line_bytes) + b"".join(halves[name][y].tobytes() for name in names)
        for y in range(height)
    )
    return header + offsets + chunks


def quantize_half(rgb: np.ndarray) -> np.ndarray:
    return rgb.astype(np.float16).astype(np.float64)


# --------------------------------------------------------------------------- bake + manifest


def zenith_transmittance_oracle(scales: AtmosphereScales) -> list[float]:
    """Vertical column optical depths (curvature negligible straight up): the contract oracle."""
    ozone_column = OZONE_HALF_WIDTH  # area of the tent max(0, 1 - |h - 25| / 15)
    depth = (
        np.asarray(RAYLEIGH_SCATTERING) * RAYLEIGH_SCALE_HEIGHT * scales.rayleigh
        + MIE_EXTINCTION * MIE_SCALE_HEIGHT * scales.mie
        + np.asarray(OZONE_ABSORPTION) * ozone_column * scales.ozone
    )
    return [round(float(x), 6) for x in np.exp(-depth)]


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def bake_bytes(scales: AtmosphereScales) -> dict[str, bytes]:
    transmittance = bake_transmittance(scales)
    multiscatter = bake_multiscatter(transmittance, scales)
    t_exr = encode_exr(transmittance)
    ms_exr = encode_exr(multiscatter.psi_ms)
    t_half = quantize_half(transmittance)
    ms_half = quantize_half(multiscatter.psi_ms)
    profile = {
        "tool": "tools/bake_atmosphere_luts.py",
        "tool_version": TOOL_VERSION,
        "contract": "docs/tasks/water_sky/WS-09_atmosphere_static_luts.md",
        "technique": "Hillaire 2020 (EGSR) transmittance + multi-scattering LUTs; Bruneton 2008 transmittance mapping; ported from Tidewater (MIT, notice.code.tidewater)",
        "units": "km; LUT values are dimensionless transmittance and multi-scattering luminance per unit sun illuminance",
        "scales": asdict(scales),
        "constants": {
            "r_ground_km": R_GROUND,
            "r_top_km": R_TOP,
            "rayleigh_scattering_per_km": list(RAYLEIGH_SCATTERING),
            "rayleigh_scale_height_km": RAYLEIGH_SCALE_HEIGHT,
            "mie_scattering_per_km": MIE_SCATTERING,
            "mie_extinction_per_km": MIE_EXTINCTION,
            "mie_scale_height_km": MIE_SCALE_HEIGHT,
            "mie_g": MIE_G,
            "ozone_absorption_per_km": list(OZONE_ABSORPTION),
            "ozone_center_km": OZONE_CENTER,
            "ozone_half_width_km": OZONE_HALF_WIDTH,
            "ground_albedo": list(GROUND_ALBEDO),
        },
        "luts": {
            "transmittance": {
                "file": TRANSMITTANCE_FILE,
                "width": TRANSMITTANCE_WIDTH,
                "height": TRANSMITTANCE_HEIGHT,
                "steps": TRANSMITTANCE_STEPS,
                "format": "OpenEXR RGBA half, NO_COMPRESSION, scanline; RGB = transmittance to the top, A = 1",
                "sha256": sha256(t_exr),
            },
            "multiscatter": {
                "file": MULTISCATTER_FILE,
                "width": MULTISCATTER_SIZE,
                "height": MULTISCATTER_SIZE,
                "directions": MULTISCATTER_DIRECTIONS,
                "steps": MULTISCATTER_STEPS,
                "step_offset": MULTISCATTER_STEP_OFFSET,
                "height_clamp": list(MULTISCATTER_HEIGHT_CLAMP),
                "format": "OpenEXR RGBA half, NO_COMPRESSION, scanline; RGB = Psi_ms, A = 1",
                "sha256": sha256(ms_exr),
            },
        },
        "conventions": {
            "sub_uv": "tex = 0.5/N + unit * (N-1)/N on both axes of both LUTs (Bruneton); inverse unit = (tex - 0.5/N) * N/(N-1)",
            "transmittance_uv": "u from the distance to the top d: (d - d_min)/(d_max - d_min); v = rho/H; row 0 (uv.y = 0) is the ground, column 0 is mu = 1 (zenith), the last column is the ground horizon",
            "multiscatter_uv": "u = cos(sun zenith) * 0.5 + 0.5, v = (r - R_ground)/(R_top - R_ground); row 0 is the ground",
            "sampler": "filter_linear, repeat_disable; import without mipmaps",
            "deviation_tidewater_sub_uv": "Tidewater's forward transmittance sub-UV uses W/(W+1) but its bake inverts with W/(W-1); we use the consistent Bruneton pair so lookups hit the baked texel centres",
            "deviation_tidewater_sphere": "multi-scattering integrates a 64-point Fibonacci sphere instead of Tidewater's 8x8 theta/phi grid",
        },
        # Values the Godot import test checks after loading the EXRs (half-quantised bake).
        "oracles": {
            "zenith_ground_transmittance_analytic": zenith_transmittance_oracle(scales),
            "zenith_ground_transmittance_texel": [0, 0],
            "zenith_ground_transmittance_baked": [round(float(x), 6) for x in t_half[0, 0]],
            "ground_zenith_sun_multiscatter_texel": [MULTISCATTER_SIZE - 1, 0],
            "ground_zenith_sun_multiscatter_baked": [round(float(x), 8) for x in ms_half[0, MULTISCATTER_SIZE - 1]],
        },
    }
    profile_bytes = (json.dumps(profile, indent=2, sort_keys=True) + "\n").encode()
    return {TRANSMITTANCE_FILE: t_exr, MULTISCATTER_FILE: ms_exr, PROFILE_FILE: profile_bytes}


def write_bake(out: Path, scales: AtmosphereScales) -> dict[str, bytes]:
    files = bake_bytes(scales)
    out.mkdir(parents=True, exist_ok=True)
    for name, data in files.items():
        if len(data) > MAX_OUTPUT_BYTES:
            raise ValueError(f"{name} is {len(data)} bytes, over the {MAX_OUTPUT_BYTES}-byte budget")
        (out / name).write_bytes(data)
    return files


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT, help="output directory (default: assets/sky/atmosphere)")
    parser.add_argument("--check", action="store_true", help="re-bake in memory and compare byte-for-byte with --out")
    parser.add_argument("--rayleigh-scale", type=float, default=1.0)
    parser.add_argument("--mie-scale", type=float, default=1.0, help="hazy Baltic summer ~1.5 is a re-bake, not a code change")
    parser.add_argument("--ozone-scale", type=float, default=1.0)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    scales = AtmosphereScales(args.rayleigh_scale, args.mie_scale, args.ozone_scale)
    if args.check:
        mismatched = [
            name for name, data in bake_bytes(scales).items()
            if not (args.out / name).is_file() or (args.out / name).read_bytes() != data
        ]
        if mismatched:
            print(f"atmosphere LUTs out of date in {args.out}: {', '.join(mismatched)}", file=sys.stderr)
            return 1
        print(f"atmosphere LUTs in {args.out} match a fresh bake")
        return 0
    files = write_bake(args.out, scales)
    for name, data in files.items():
        print(f"wrote {args.out / name} ({len(data)} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
