#!/usr/bin/env python3
"""Offline FFT ocean bake (WS-03): band-split, time-looping JONSWAP/TMA cascades.

The GL Compatibility renderer has no compute shaders, so the Tessendorf FFT ocean is
baked offline. Every wave frequency is rounded to a multiple of 2*pi/T, which makes each
cascade exactly periodic in time; the FFT patch is periodic in space by construction.
Each cascade is written as vertical-strip RGBA atlases that Godot imports as
Texture2DArray (one layer per frame).

Physics follows Tidewater (MIT, see docs/THIRD_PARTY_NOTICES.md `notice.code.tidewater`)
`jonswap()`, `tmaCorrection()`, `directionSpectrum()` and `normalisationFactor()`, which in
turn follow Horvath 2015 and Tessendorf 2001. Units are SI metres and seconds; the
metres-to-world-units conversion happens in the shader (WS-04).

Contract: docs/tasks/water_sky/WS-03_fft_ocean_bake_tool.md.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
import tempfile
from dataclasses import asdict, dataclass
from pathlib import Path

import numpy as np
from PIL import Image

TOOL_VERSION = "1.0.0"
GRAVITY = 9.81
METERS_PER_WORLD_UNIT = 0.87
MAX_OUTPUT_BYTES = 10 * 1024 * 1024
SHORT_WAVE_DAMPING_M = 0.01
JONSWAP_GAMMA = 3.3
# Reference choppiness used only to decide where foam is generated; runtime choppiness is WS-04.
FOAM_LAMBDA = 0.9
# Tidewater's h0 = xi/sqrt(2)*sqrt(2*E) is 2x our physical amplitude (see build_cascade).
FOAM_AMPLITUDE_EQUIVALENCE = 2.0
FOAM_BIAS = 0.58
FOAM_GAIN = 3.0
FOAM_DECAY = 0.35
FOAM_ADD = 2.5
FOAM_LOOP_TOLERANCE = 1.0 / 255.0
FOAM_MAX_LOOPS = 16
MIN_FRAMES_PER_SHORTEST_PERIOD = 8
PNG_COMPRESS_LEVEL = 9
ENCODE_PERCENTILE = 99.9
# Relative imaginary residue allowed after the inverse FFT (contract item 8).
MAX_IMAG_RESIDUE = 1e-5

DISP_CHANNELS = ("dx", "dy", "dz")
DERIV_CHANNELS = ("dy_dx", "dy_dz", "dx_dx", "dz_dz")


@dataclass(frozen=True)
class SeaState:
    wind_speed: float  # U10, m/s
    fetch: float  # m
    depth: float  # m
    swell: float  # 0 = pure wind sea, 1 = long-crested swell
    spread_blend: float  # 0 = cos^2 only, 1 = Horvath cos(theta/2)^2s only
    spectrum_scale: float = 1.0


@dataclass(frozen=True)
class CascadeSpec:
    name: str
    patch_m: float
    n: int
    wavelength_long_m: float  # band start (k_low = 2*pi / wavelength_long)
    wavelength_short_m: float  # band end, exclusive (k_high = 2*pi / wavelength_short)
    period_s: float
    frames: int
    write_disp: bool = True

    @property
    def k_low(self) -> float:
        return 2.0 * math.pi / self.wavelength_long_m

    @property
    def k_high(self) -> float:
        return 2.0 * math.pi / self.wavelength_short_m


PROFILES: dict[str, dict] = {
    "baltic_reference": {
        "sea": SeaState(wind_speed=9.0, fetch=40_000.0, depth=20.0, swell=0.25, spread_blend=0.85),
        "seed": 1343,
        "cascades": (
            CascadeSpec("c0", 128.0, 128, 128.0, 16.0, 25.6, 64, True),
            CascadeSpec("c1", 32.0, 128, 16.0, 4.0, 12.8, 64, True),
            CascadeSpec("c2", 8.0, 64, 4.0, 1.0, 6.4, 64, False),
        ),
    },
}


# --- Spectrum -------------------------------------------------------------------------------


def dispersion(k: np.ndarray, depth: float) -> np.ndarray:
    return np.sqrt(GRAVITY * k * np.tanh(np.minimum(k * depth, 20.0)))


def dispersion_derivative(k: np.ndarray, depth: float) -> np.ndarray:
    kh = np.minimum(k * depth, 20.0)
    omega = dispersion(k, depth)
    with np.errstate(divide="ignore", invalid="ignore"):
        d = GRAVITY * (depth * k / np.cosh(kh) ** 2 + np.tanh(kh)) / (2.0 * omega)
    return np.where(omega > 0.0, d, 0.0)


def tma_correction(omega: np.ndarray, depth: float) -> np.ndarray:
    omega_h = omega * math.sqrt(depth / GRAVITY)
    return np.where(
        omega_h <= 1.0,
        0.5 * omega_h**2,
        np.where(omega_h < 2.0, 1.0 - 0.5 * (2.0 - omega_h) ** 2, 1.0),
    )


def jonswap_parameters(sea: SeaState) -> tuple[float, float]:
    alpha = 0.076 * (sea.wind_speed**2 / (sea.fetch * GRAVITY)) ** 0.22
    omega_p = 22.0 * (GRAVITY**2 / (sea.wind_speed * sea.fetch)) ** (1.0 / 3.0)
    return alpha, omega_p


def jonswap(omega: np.ndarray, sea: SeaState) -> np.ndarray:
    alpha, omega_p = jonswap_parameters(sea)
    safe = np.where(omega > 0.0, omega, 1.0)
    sigma = np.where(safe <= omega_p, 0.07, 0.09)
    r = np.exp(-((safe - omega_p) ** 2) / (2.0 * sigma**2 * omega_p**2))
    s = (
        sea.spectrum_scale
        * tma_correction(safe, sea.depth)
        * alpha
        * GRAVITY**2
        / safe**5
        * np.exp(-1.25 * (omega_p / safe) ** 4)
        * JONSWAP_GAMMA**r
    )
    return np.where(omega > 0.0, s, 0.0)


def normalisation_factor(s: np.ndarray) -> np.ndarray:
    s2, s3, s4 = s * s, s * s * s, s * s * s * s
    low = -0.000564 * s4 + 0.00776 * s3 - 0.044 * s2 + 0.192 * s + 0.163
    high = -4.80e-08 * s4 + 1.07e-05 * s3 - 9.53e-04 * s2 + 5.90e-02 * s + 3.93e-01
    return np.where(s < 5.0, low, high)


def direction_spectrum(theta: np.ndarray, omega: np.ndarray, sea: SeaState) -> np.ndarray:
    _, omega_p = jonswap_parameters(sea)
    safe = np.where(omega > 0.0, omega, 1.0)
    # Horvath 2015 eq. 45: Hasselmann base spread power plus the swell term. The contract's
    # swell-only s stays below 1 for the reference sea, which bakes near-isotropic blobs
    # instead of wave trains running downwind.
    ratio = safe / omega_p
    peak_exponent = -2.33 - 1.45 * (sea.wind_speed * omega_p / GRAVITY - 1.17)
    s_base = np.where(ratio <= 1.0, 6.97 * ratio**4.06, 9.77 * ratio**peak_exponent)
    s = s_base + 16.0 * np.tanh(omega_p / safe) * sea.swell**2
    horvath = normalisation_factor(s) * np.abs(np.cos(theta * 0.5)) ** (2.0 * s)
    # The cos^2 lobe is restricted to the downwind half-plane so it integrates to 1 over
    # [-pi, pi] like the Horvath lobe; Tidewater's unrestricted form integrates to 2 and
    # would put mirrored upwind energy into the reference Hs.
    cos2 = np.where(np.abs(theta) <= 0.5 * math.pi, (2.0 / math.pi) * np.cos(theta) ** 2, 0.0)
    return cos2 + sea.spread_blend * (horvath - cos2)


# --- Cascade evaluation ---------------------------------------------------------------------


@dataclass
class CascadeField:
    spec: CascadeSpec
    kx: np.ndarray  # [z, x]
    kz: np.ndarray
    k: np.ndarray
    omega_q: np.ndarray
    h0: np.ndarray  # complex [z, x]
    h0_neg_conj: np.ndarray  # conj(h0(-k)) at each texel
    energy: np.ndarray  # S*D*(domega/dk)/k*dk^2 per kept texel (m^2)


def check_frame_rate(spec: CascadeSpec, depth: float) -> None:
    shortest_period = 2.0 * math.pi / float(dispersion(np.array(spec.k_high), depth))
    frame_dt = spec.period_s / spec.frames
    limit = shortest_period / MIN_FRAMES_PER_SHORTEST_PERIOD
    # Small relative slack: the reference layout sits exactly on the 8-frames-per-period limit.
    if frame_dt > limit * (1.0 + 1e-9):
        raise SystemExit(
            f"cascade {spec.name}: {spec.frames} frames over {spec.period_s} s gives "
            f"{frame_dt:.4f} s per frame, but the shortest wave ({spec.wavelength_short_m} m, "
            f"period {shortest_period:.4f} s) needs at most {limit:.4f} s per frame "
            f"({MIN_FRAMES_PER_SHORTEST_PERIOD} frames per period); raise --frames to at least "
            f"{math.ceil(spec.period_s / limit)}"
        )


def build_cascade(
    spec: CascadeSpec, sea: SeaState, rng: np.random.Generator, *, unit_amplitude: bool = False
) -> CascadeField:
    n = spec.n
    dk = 2.0 * math.pi / spec.patch_m
    # fftfreq ordering: index m holds wave number 2*pi*m/L, so ifft2 needs no fftshift.
    k_axis = np.fft.fftfreq(n, d=1.0 / n) * dk
    kx, kz = np.meshgrid(k_axis, k_axis, indexing="xy")
    k = np.hypot(kx, kz)
    omega = dispersion(k, sea.depth)
    omega0 = 2.0 * math.pi / spec.period_s
    omega_q = np.round(omega / omega0) * omega0

    in_band = (k >= spec.k_low) & (k < spec.k_high) & (omega_q > 0.0)
    # Nyquist row/column pair with themselves, so odd operators (i*k) cannot stay real there.
    nyquist = n // 2
    in_band[nyquist, :] = False
    in_band[:, nyquist] = False

    theta = np.arctan2(kz, kx)  # wind blows along +X
    with np.errstate(divide="ignore", invalid="ignore"):
        energy = (
            jonswap(omega, sea)
            * direction_spectrum(theta, omega, sea)
            * dispersion_derivative(k, sea.depth)
            / np.where(k > 0.0, k, 1.0)
            * dk
            * dk
            * np.exp(-(k**2) * SHORT_WAVE_DAMPING_M**2)
        )
    energy = np.where(in_band, energy, 0.0)

    if unit_amplitude:
        xi = np.exp(1j * rng.uniform(0.0, 2.0 * math.pi, size=(n, n)))
    else:
        xi = (rng.standard_normal((n, n)) + 1j * rng.standard_normal((n, n))) / math.sqrt(2.0)
    # E|h0|^2 = energy/2: h(k,t) sums h0(k) and conj(h0(-k)), so the spatial variance is the
    # one-sided band energy m0 and Hs = 4*sqrt(m0) (oceanographic definition). The literal
    # Tidewater amplitude sqrt(2*E) is 2x taller; WS-04 per-cascade weights own art scaling.
    h0 = xi * np.sqrt(0.5 * energy)
    neg = (-np.arange(n)) % n
    h0_neg_conj = np.conj(h0[np.ix_(neg, neg)])
    return CascadeField(spec, kx, kz, k, np.where(in_band, omega_q, 0.0), h0, h0_neg_conj, energy)


def spectrum_at(field: CascadeField, t: float) -> np.ndarray:
    phase = np.exp(1j * field.omega_q * t)
    return field.h0 * phase + field.h0_neg_conj * np.conj(phase)


def evaluate_complex(field: CascadeField, t: float) -> dict[str, np.ndarray]:
    """Returns every baked channel as complex spatial fields (imag part is FFT residue).

    Horizontal displacement uses D = IFFT(+i*k_hat*h) with surface point x' = x + lambda*D,
    so points move toward crests and the Jacobian drops below 1 on crests (foam on crests,
    Horvath/Acerola convention). The contract's -i sign would compress troughs instead.
    """
    h = spectrum_at(field, t)
    n2 = field.spec.n * field.spec.n
    with np.errstate(divide="ignore", invalid="ignore"):
        inv_k = np.where(field.k > 0.0, 1.0 / field.k, 0.0)
    kx, kz = field.kx, field.kz
    spectra = {
        "dy": h,
        "dx": 1j * kx * inv_k * h,
        "dz": 1j * kz * inv_k * h,
        "dy_dx": 1j * kx * h,
        "dy_dz": 1j * kz * h,
        "dx_dx": -(kx * kx) * inv_k * h,
        "dz_dz": -(kz * kz) * inv_k * h,
        "dx_dz": -(kx * kz) * inv_k * h,
    }
    # numpy's ifft2 divides by N^2; the ocean sum is unnormalised.
    return {name: np.fft.ifft2(spec) * n2 for name, spec in spectra.items()}


def evaluate(field: CascadeField, t: float) -> dict[str, np.ndarray]:
    complex_fields = evaluate_complex(field, t)
    out: dict[str, np.ndarray] = {}
    for name, value in complex_fields.items():
        peak = float(np.max(np.abs(value.real)))
        residue = float(np.max(np.abs(value.imag)))
        if peak > 0.0 and residue > MAX_IMAG_RESIDUE * peak:
            raise SystemExit(f"cascade {field.spec.name}: channel {name} imaginary residue {residue:g} vs peak {peak:g}")
        out[name] = value.real
    return out


def band_energy(field: CascadeField) -> float:
    return float(np.sum(field.energy))


# --- Foam -----------------------------------------------------------------------------------


def jacobian(frame: dict[str, np.ndarray], lam: float = FOAM_LAMBDA) -> np.ndarray:
    return (1.0 + lam * frame["dx_dx"]) * (1.0 + lam * frame["dz_dz"]) - (lam * frame["dx_dz"]) ** 2


def simulate_foam(
    frames: list[dict[str, np.ndarray]], period_s: float, lam: float = FOAM_LAMBDA
) -> tuple[list[np.ndarray], int, float]:
    """Runs the foam integrator until one loop maps onto itself; returns the settled loop."""
    dt = period_s / len(frames)
    decay = math.exp(-FOAM_DECAY * dt)
    gens = [np.clip((FOAM_BIAS - jacobian(f, lam)) * FOAM_GAIN, 0.0, 1.0) * FOAM_ADD * dt for f in frames]
    foam = np.zeros_like(gens[0])
    loop: list[np.ndarray] = []
    for loops in range(1, FOAM_MAX_LOOPS + 1):
        loop = []
        for gen in gens:
            foam = np.clip(foam * decay + gen, 0.0, 1.0)
            loop.append(foam)
        if loops < 2:
            continue
        # Foam after the next loop's frame 0 must equal the stored frame 0 for a seamless loop.
        wrap = np.clip(foam * decay + gens[0], 0.0, 1.0)
        drift = float(np.max(np.abs(wrap - loop[0])))
        if drift < FOAM_LOOP_TOLERANCE:
            return loop, loops, drift
    raise SystemExit(f"foam did not settle into a loop after {FOAM_MAX_LOOPS} loops (drift {drift:.5f})")


# --- Encoding and output --------------------------------------------------------------------


def encode_signed(values: np.ndarray, scale: float) -> np.ndarray:
    if scale <= 0.0:
        return np.full(values.shape, 128, dtype=np.uint8)
    return np.round(np.clip(0.5 + values / (2.0 * scale), 0.0, 1.0) * 255.0).astype(np.uint8)


def encode_unit(values: np.ndarray) -> np.ndarray:
    return np.round(np.clip(values, 0.0, 1.0) * 255.0).astype(np.uint8)


def channel_scale(stack: np.ndarray) -> float:
    return float(np.percentile(np.abs(stack), ENCODE_PERCENTILE))


def write_png(path: Path, rgba: np.ndarray) -> None:
    # Pillow writes no tIME/text chunks unless asked, so fixed compression gives stable bytes.
    Image.fromarray(rgba).save(path, format="PNG", optimize=False, compress_level=PNG_COMPRESS_LEVEL)
    size = path.stat().st_size
    if size >= MAX_OUTPUT_BYTES:
        raise SystemExit(f"{path.name} is {size} bytes; the storage policy limit is {MAX_OUTPUT_BYTES} bytes")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


@dataclass
class CascadeBake:
    spec: CascadeSpec
    field: CascadeField
    frames: list[dict[str, np.ndarray]]
    height_variance: float
    divergence_std: float
    foam: list[np.ndarray] | None = None
    foam_lambda: float = FOAM_LAMBDA
    foam_loops: int = 0
    foam_drift: float = 0.0


def bake_cascade(spec: CascadeSpec, sea: SeaState, rng: np.random.Generator, *, unit_amplitude: bool) -> CascadeBake:
    check_frame_rate(spec, sea.depth)
    field = build_cascade(spec, sea, rng, unit_amplitude=unit_amplitude)
    dt = spec.period_s / spec.frames
    frames = [evaluate(field, f * dt) for f in range(spec.frames)]
    variance = float(np.mean([np.var(f["dy"]) for f in frames]))
    divergence = float(np.std(np.stack([f["dx_dx"] + f["dz_dz"] for f in frames])))
    return CascadeBake(spec, field, frames, variance, divergence)


def foam_lambdas(bakes: list[CascadeBake]) -> list[float]:
    """Per-cascade choppiness for the foam Jacobian.

    Whitecaps break where the *summed* sea folds, but each cascade's foam must loop with its
    own patch and period, so it can only see its own derivatives. Scaling a cascade's lambda by
    sigma_total / sigma_cascade gives its Jacobian the statistics of the full sea (bands are
    independent, so divergence variances add) while keeping its own crest pattern.
    FOAM_AMPLITUDE_EQUIVALENCE maps our physical amplitude to the Tidewater amplitude the
    foam constants (bias 0.58, gain 3) were tuned against; without it the reference sea bakes
    no foam at all.
    """
    total = math.sqrt(sum(b.divergence_std**2 for b in bakes))
    return [
        FOAM_LAMBDA * FOAM_AMPLITUDE_EQUIVALENCE * (total / b.divergence_std if b.divergence_std > 0.0 else 1.0)
        for b in bakes
    ]


def bake(
    sea: SeaState,
    cascades: tuple[CascadeSpec, ...],
    seed: int,
    out_dir: Path,
    *,
    profile_name: str,
    unit_amplitude: bool = False,
) -> dict:
    out_dir.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(seed)
    alpha, omega_p = jonswap_parameters(sea)
    cascade_entries = []
    total_variance = 0.0
    # Cascades draw from one RNG in order, so evaluation order is part of the determinism contract.
    bakes = [bake_cascade(spec, sea, rng, unit_amplitude=unit_amplitude) for spec in cascades]
    for result, lam in zip(bakes, foam_lambdas(bakes)):
        result.foam_lambda = lam
        result.foam, result.foam_loops, result.foam_drift = simulate_foam(result.frames, result.spec.period_s, lam)
    for result in bakes:
        spec = result.spec
        total_variance += result.height_variance
        stacks = {name: np.stack([f[name] for f in result.frames]) for name in DISP_CHANNELS + DERIV_CHANNELS}
        scales = {name: channel_scale(stacks[name]) for name in stacks if spec.write_disp or name in DERIV_CHANNELS}

        def atlas(channels: list[np.ndarray]) -> np.ndarray:
            # [frames, N, N, 4] -> vertical strip [frames*N, N, 4]; frame f occupies rows f*N..f*N+N-1.
            return np.stack(channels, axis=-1).reshape(spec.frames * spec.n, spec.n, 4)

        files: dict[str, str] = {}
        if spec.write_disp:
            disp_path = out_dir / f"{spec.name}_disp.png"
            write_png(
                disp_path,
                atlas([encode_signed(stacks[c], scales[c]) for c in DISP_CHANNELS] + [encode_unit(np.stack(result.foam))]),
            )
            files[disp_path.name] = sha256(disp_path)
        deriv_path = out_dir / f"{spec.name}_deriv.png"
        write_png(deriv_path, atlas([encode_signed(stacks[c], scales[c]) for c in DERIV_CHANNELS]))
        files[deriv_path.name] = sha256(deriv_path)

        cascade_entries.append(
            {
                "name": spec.name,
                "patch_m": spec.patch_m,
                "n": spec.n,
                "wavelength_long_m": spec.wavelength_long_m,
                "wavelength_short_m": spec.wavelength_short_m,
                "k_low": round(spec.k_low, 9),
                "k_high": round(spec.k_high, 9),
                "period_s": spec.period_s,
                "frames": spec.frames,
                "channel_scales": {name: round(value, 9) for name, value in scales.items()},
                "foam_encoding": "linear 0..1 in disp alpha" if spec.write_disp else "not baked (no disp atlas)",
                "foam_lambda": round(result.foam_lambda, 9),
                "foam_loops_simulated": result.foam_loops,
                "foam_loop_drift": round(result.foam_drift, 9),
                "hs_m": round(4.0 * math.sqrt(result.height_variance), 6),
                "files": files,
            }
        )

    profile = {
        "tool": "tools/bake_ocean_fft.py",
        "tool_version": TOOL_VERSION,
        "profile": profile_name,
        "seed": seed,
        "unit_amplitude": unit_amplitude,
        "sea_state": asdict(sea),
        "g": GRAVITY,
        "depth_m": sea.depth,
        "jonswap": {"alpha": round(alpha, 9), "omega_p": round(omega_p, 9), "gamma": JONSWAP_GAMMA},
        "meters_per_world_unit": METERS_PER_WORLD_UNIT,
        "wind_direction": "+X (runtime rotates the lookup)",
        "conventions": {
            "atlas_layout": "vertical strip; frame f is rows f*N..f*N+N-1; row = +Z, column = +X",
            "disp_rgba": list(DISP_CHANNELS) + ["foam"],
            "deriv_rgba": list(DERIV_CHANNELS),
            "signed_encoding": "byte = round(clamp(0.5 + v / (2*scale), 0, 1) * 255)",
            "horizontal_displacement": "x' = x + lambda * D with D = IFFT(+i*k_hat*h); crests compress",
            "choppiness_baked": 1.0,
            "foam_reference_choppiness": FOAM_LAMBDA,
            "foam_amplitude_equivalence": FOAM_AMPLITUDE_EQUIVALENCE,
            "foam_lambda_rule": "lambda0 * amplitude_equivalence * sigma_total_divergence / sigma_cascade_divergence",
            "foam": {"bias": FOAM_BIAS, "gain": FOAM_GAIN, "decay": FOAM_DECAY, "add": FOAM_ADD},
            "short_wave_damping_m": SHORT_WAVE_DAMPING_M,
            "amplitude_normalisation": "spatial variance = one-sided band energy m0; Hs = 4*sqrt(m0)",
        },
        "cascades": cascade_entries,
        # Cascade bands are disjoint and independent, so the total variance is the sum.
        "hs_m": round(4.0 * math.sqrt(total_variance), 6),
    }
    (out_dir / "ocean_fft_profile.json").write_text(json.dumps(profile, indent=2) + "\n", encoding="utf-8")
    profile["_bakes"] = bakes  # in-memory only, for --preview and tests
    return profile


def write_preview(bakes: list[CascadeBake], path: Path, tile: int = 128) -> None:
    rows = []
    for result in bakes:
        indices = [f for f in (0, 16, 32, 48) if f < result.spec.frames]
        heights = [result.frames[f]["dy"] for f in indices]
        scale = max(float(np.max(np.abs(h))) for h in heights) or 1.0
        tiles = [encode_signed(h, scale) for h in heights] + [encode_unit(result.foam[f]) for f in indices]
        row = [np.array(Image.fromarray(t).resize((tile, tile), Image.NEAREST)) for t in tiles]
        rows.append(np.concatenate(row, axis=1))
    width = max(r.shape[1] for r in rows)
    rows = [np.pad(r, ((0, 0), (0, width - r.shape[1]))) for r in rows]
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(np.concatenate(rows, axis=0)).save(path, format="PNG")


# --- WS-06 foam tile -------------------------------------------------------------------------
#
# One seamless RGBA8 detail texture for FFT whitecaps (docs/tasks/water_sky/WS-06_*.md).
# Every channel is a function of tile coordinates (u, v) that is exactly periodic with
# period 1, so sampling u = 0 and u = 1 gives the same bytes and the tile wraps with no
# seam. R = bubble clusters, G = fine speckle, B = wind streaks stretched 6:1 along +X
# (the bake frame's downwind axis), A = 1.

FOAM_TILE_SIZE = 256
# Worley lattices for the two bubble scales (cells per tile).
FOAM_BUBBLE_CELLS = (22, 51)
# Anisotropic value-noise lattice for the streak channel: 4 cells along X, 24 along Y
# makes each cell 6x longer downwind than across.
FOAM_STREAK_LATTICE = ((4, 24), (8, 48), (16, 96))


def _lattice_hash(ix: np.ndarray, iy: np.ndarray, salt: int) -> np.ndarray:
    """Deterministic integer hash -> [0, 1). Pure integer maths, so it is platform stable."""
    h = (ix.astype(np.uint64) * np.uint64(0x9E3779B1)) ^ (iy.astype(np.uint64) * np.uint64(0x85EBCA77))
    h ^= np.uint64(salt & 0xFFFFFFFF) * np.uint64(0xC2B2AE3D)
    h &= np.uint64(0xFFFFFFFF)
    h ^= h >> np.uint64(15)
    h = (h * np.uint64(0x2C1B3C6D)) & np.uint64(0xFFFFFFFF)
    h ^= h >> np.uint64(12)
    h = (h * np.uint64(0x297A2D39)) & np.uint64(0xFFFFFFFF)
    h ^= h >> np.uint64(15)
    return (h & np.uint64(0xFFFFFF)).astype(np.float64) / float(1 << 24)


def _periodic_value_noise(u: np.ndarray, v: np.ndarray, nx: int, ny: int, salt: int) -> np.ndarray:
    """Smooth value noise on an nx-by-ny lattice that wraps once per unit tile."""
    x = u * nx
    y = v * ny
    x0 = np.floor(x)
    y0 = np.floor(y)
    fx = x - x0
    fy = y - y0
    fx = fx * fx * (3.0 - 2.0 * fx)
    fy = fy * fy * (3.0 - 2.0 * fy)
    ix0 = np.mod(x0, nx).astype(np.int64)
    iy0 = np.mod(y0, ny).astype(np.int64)
    ix1 = np.mod(ix0 + 1, nx)
    iy1 = np.mod(iy0 + 1, ny)
    a = _lattice_hash(ix0, iy0, salt)
    b = _lattice_hash(ix1, iy0, salt)
    c = _lattice_hash(ix0, iy1, salt)
    d = _lattice_hash(ix1, iy1, salt)
    return (a * (1.0 - fx) + b * fx) * (1.0 - fy) + (c * (1.0 - fx) + d * fx) * fy


def _periodic_worley(u: np.ndarray, v: np.ndarray, cells: int, salt: int) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """F1, F2 (in cell units) and the random radius of the nearest feature point."""
    x = u * cells
    y = v * cells
    cx = np.floor(x)
    cy = np.floor(y)
    f1 = np.full(x.shape, 9.0)
    f2 = np.full(x.shape, 9.0)
    radius = np.zeros(x.shape)
    for oy in (-1, 0, 1):
        for ox in (-1, 0, 1):
            gx = cx + ox
            gy = cy + oy
            ix = np.mod(gx, cells).astype(np.int64)
            iy = np.mod(gy, cells).astype(np.int64)
            px = gx + _lattice_hash(ix, iy, salt)
            py = gy + _lattice_hash(ix, iy, salt + 1)
            r = _lattice_hash(ix, iy, salt + 2)
            dist = np.hypot(x - px, y - py)
            closer = dist < f1
            f2 = np.where(closer, f1, np.minimum(f2, dist))
            radius = np.where(closer, r, radius)
            f1 = np.where(closer, dist, f1)
    return f1, f2, radius


def _bubble_layer(u: np.ndarray, v: np.ndarray, cells: int, salt: int) -> np.ndarray:
    """Inverted Worley F1 thresholded into rims: bright bubble walls, darker cores,
    and a foam film filling the gaps where cells meet (F2 - F1 small)."""
    f1, f2, rand_r = _periodic_worley(u, v, cells, salt)
    radius = 0.28 + 0.22 * rand_r
    inv_f1 = np.clip(1.0 - f1 / radius, 0.0, 1.0)
    rim = np.exp(-(((f1 - radius) / 0.07) ** 2))
    core = 0.35 * inv_f1
    film = np.clip(1.0 - (f2 - f1) / 0.18, 0.0, 1.0) * 0.55
    return np.clip(np.maximum(rim, film) + core, 0.0, 1.0)


def foam_tile_channels(u: np.ndarray, v: np.ndarray, seed: int) -> np.ndarray:
    """Float RGBA in 0..1 at tile coordinates (u, v); periodic with period 1 in both."""
    salt = int(seed) * 97
    # Clusters: a low-frequency envelope groups bubbles into patches instead of an even
    # carpet, so the shader threshold uncovers clumps first as the whitecap mask rises.
    cluster = 0.6 * _periodic_value_noise(u, v, 6, 6, salt + 11) + 0.4 * _periodic_value_noise(u, v, 13, 13, salt + 12)
    big = _bubble_layer(u, v, FOAM_BUBBLE_CELLS[0], salt + 20)
    small = _bubble_layer(u, v, FOAM_BUBBLE_CELLS[1], salt + 30)
    bubbles = np.maximum(big, small * 0.85)
    red = np.clip(bubbles * (0.45 + 1.1 * cluster**1.5), 0.0, 1.0)
    speckle = 0.65 * _periodic_value_noise(u, v, 96, 96, salt + 40) + 0.35 * _periodic_value_noise(u, v, 173, 173, salt + 41)
    green = np.clip((speckle - 0.5) * 1.6 + 0.5, 0.0, 1.0)
    # Ridged anisotropic noise gives thin lines along +X; a gentle periodic warp across
    # the wind makes them meander instead of running as ruler-straight bands.
    warp = 0.025 * (_periodic_value_noise(u, v, 3, 5, salt + 49) - 0.5)
    streak = np.zeros(u.shape)
    weight = 0.0
    for octave, (nx, ny) in enumerate(FOAM_STREAK_LATTICE):
        amplitude = 0.5**octave
        ridge = 1.0 - np.abs(2.0 * _periodic_value_noise(u, v + warp, nx, ny, salt + 50 + octave) - 1.0)
        streak += amplitude * ridge
        weight += amplitude
    streak /= weight
    blue = np.clip((streak - 0.62) / 0.25, 0.0, 1.0) ** 1.5
    alpha = np.ones(u.shape)
    return np.stack([red, green, blue, alpha], axis=-1)


def foam_tile_image(seed: int, size: int = FOAM_TILE_SIZE) -> np.ndarray:
    coords = np.arange(size, dtype=np.float64) / size
    u, v = np.meshgrid(coords, coords)
    return encode_unit(foam_tile_channels(u, v, seed))


def foam_tile_main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="bake_ocean_fft.py foam-tile", description="WS-06 seamless foam detail tile")
    parser.add_argument("--out", type=Path, required=True, help="output PNG path")
    parser.add_argument("--seed", type=int, default=1343)
    parser.add_argument("--size", type=int, default=FOAM_TILE_SIZE)
    args = parser.parse_args(argv)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    write_png(args.out, foam_tile_image(args.seed, args.size))
    print(f"wrote foam tile {args.out} ({args.out.stat().st_size} bytes, sha256 {sha256(args.out)})")
    return 0


# --- WS-07 caustic tiles ---------------------------------------------------------------------
#
# Two static single-channel tiles of the light a flat bed receives under one frame of the
# WS-03 spectrum (docs/tasks/water_sky/WS-07_baked_caustics.md). Photon area-ratio method:
# every surface texel refracts a vertical sun ray, lands on a flat bed at depth d, and splats
# its unit energy bilinearly into a periodic histogram. Unlike the analytic 1/|det J| this has
# no infinities on the focus lines. Ported in spirit from Tidewater (MIT, see
# docs/THIRD_PARTY_NOTICES.md `notice.code.tidewater`) causticsFineTex / causticsBroadTex.

WATER_IOR = 1.333
CAUSTICS_TILE_N = 512
# Stored byte = round(clamp(v, 0, 4) / 4 * 255); the shader multiplies the sample by 4.
CAUSTICS_ENCODE_SCALE = 4.0
CAUSTICS_BLUR_SIGMA_TEXELS = 1.0
# The contract's short-wave ends (0.5 m fine, 2 m broad) carry too little curvature to focus
# at 1.2 m / 4 m under the reference sea: the splat histogram's std is only 0.18 / 0.15, a
# faint mottle instead of a net. Real shallow-water caustic nets come from decimetre ripples,
# so both bands extend down to where the pattern focuses (std ~1.3 / ~1.0) while the long
# ends, patches and bed depths stay as specified (decision recorded in the WS-07 task doc).
CAUSTICS_TILES: tuple[CascadeSpec, ...] = (
    # period_s/frames are unused (one frame at t = 0); patch = long end keeps the tile periodic.
    CascadeSpec("caustics_fine", 4.0, CAUSTICS_TILE_N, 4.0, 0.12, 1.0, 1, False),
    CascadeSpec("caustics_broad", 16.0, CAUSTICS_TILE_N, 16.0, 0.5, 1.0, 1, False),
)
CAUSTICS_BED_DEPTH_M = {"caustics_fine": 1.2, "caustics_broad": 4.0}
CAUSTICS_RENORMALISE_PASSES = 8


def caustic_landing_offsets(slope_x: np.ndarray, slope_z: np.ndarray, depth_m: float) -> np.ndarray:
    """Horizontal landing offset (metres, [z, x, 2] as x/z) of a vertical sun ray refracted
    through the surface normal (-sx, 1, -sz) and stopped on a flat bed depth_m below."""
    normal = np.stack([-slope_x, np.ones_like(slope_x), -slope_z], axis=-1)
    normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
    eta = 1.0 / WATER_IOR
    # GLSL refract(I, N, eta) with I = (0, -1, 0): cos_i = -dot(N, I) = N.y.
    cos_i = normal[..., 1]
    cos_t = np.sqrt(1.0 - eta * eta * (1.0 - cos_i * cos_i))
    transmitted = eta * np.array([0.0, -1.0, 0.0]) + (eta * cos_i - cos_t)[..., None] * normal
    return depth_m * transmitted[..., [0, 2]] / (-transmitted[..., 1:2])


def splat_periodic(offset_texels: np.ndarray) -> np.ndarray:
    """Bilinear splat of one unit of energy per texel onto its landing texel, wrapping."""
    n = offset_texels.shape[0]
    zz, xx = np.meshgrid(np.arange(n), np.arange(n), indexing="ij")
    px = xx + offset_texels[..., 0]
    pz = zz + offset_texels[..., 1]
    x0 = np.floor(px)
    z0 = np.floor(pz)
    fx = px - x0
    fz = pz - z0
    x0 = x0.astype(np.int64) % n
    z0 = z0.astype(np.int64) % n
    histogram = np.zeros((n, n))
    for dz, dx, weight in ((0, 0, (1 - fx) * (1 - fz)), (0, 1, fx * (1 - fz)), (1, 0, (1 - fx) * fz), (1, 1, fx * fz)):
        np.add.at(histogram, ((z0 + dz) % n, (x0 + dx) % n), weight)
    return histogram


def blur_periodic(values: np.ndarray, sigma_texels: float) -> np.ndarray:
    """Periodic Gaussian blur through the FFT; the DC term is untouched, so energy is kept."""
    n = values.shape[0]
    freq = np.fft.fftfreq(n)
    fx, fz = np.meshgrid(freq, freq, indexing="xy")
    kernel = np.exp(-2.0 * (math.pi * sigma_texels) ** 2 * (fx * fx + fz * fz))
    return np.fft.ifft2(np.fft.fft2(values) * kernel).real


def normalise_caustics(values: np.ndarray) -> np.ndarray:
    """Mean 1.0 after clamping to [0, CAUSTICS_ENCODE_SCALE]: clamping the brightest focus
    lines lowers the mean, so rescale and re-clamp until it settles."""
    out = values / float(np.mean(values))
    for _ in range(CAUSTICS_RENORMALISE_PASSES):
        out = np.clip(out, 0.0, CAUSTICS_ENCODE_SCALE)
        out = out / float(np.mean(out))
    return np.clip(out, 0.0, CAUSTICS_ENCODE_SCALE)


@dataclass
class CausticTile:
    spec: CascadeSpec
    depth_m: float
    histogram: np.ndarray  # raw splat, sum = N^2
    values: np.ndarray  # blurred, normalised, clamped light gain (mean 1)
    slope_rms: float


def bake_caustic_tile(spec: CascadeSpec, sea: SeaState, rng: np.random.Generator, depth_m: float) -> CausticTile:
    frame = evaluate(build_cascade(spec, sea, rng), 0.0)
    offsets_m = caustic_landing_offsets(frame["dy_dx"], frame["dy_dz"], depth_m)
    histogram = splat_periodic(offsets_m / (spec.patch_m / spec.n))
    values = normalise_caustics(blur_periodic(histogram, CAUSTICS_BLUR_SIGMA_TEXELS))
    slope_rms = float(np.sqrt(np.mean(frame["dy_dx"] ** 2 + frame["dy_dz"] ** 2)))
    return CausticTile(spec, depth_m, histogram, values, slope_rms)


def caustic_min_pair_mean(values: np.ndarray) -> float:
    """Mean of min(layer A, layer B) for the shader's cross-scroll (B = A rotated 90 degrees
    and shifted), taken over a few shifts because the layers drift against each other."""
    n = values.shape[0]
    means = [
        float(np.mean(np.minimum(values, np.rot90(np.roll(values, (n * i // 7, n * i // 5), (0, 1))))))
        for i in range(1, 5)
    ]
    return float(np.mean(means))


def encode_caustics(values: np.ndarray) -> np.ndarray:
    return encode_unit(values / CAUSTICS_ENCODE_SCALE)


def bake_caustics(sea: SeaState, seed: int, out_dir: Path) -> dict:
    out_dir.mkdir(parents=True, exist_ok=True)
    # Fine then broad from one RNG: the order is part of the determinism contract.
    rng = np.random.default_rng(seed)
    tiles = [bake_caustic_tile(spec, sea, rng, CAUSTICS_BED_DEPTH_M[spec.name]) for spec in CAUSTICS_TILES]
    entries = []
    for tile in tiles:
        path = out_dir / f"{tile.spec.name}.png"
        # A 2D uint8 array saves as mode "L": Godot imports a one-channel L8 texture, read as .r.
        Image.fromarray(encode_caustics(tile.values)).save(
            path, format="PNG", optimize=False, compress_level=PNG_COMPRESS_LEVEL
        )
        if path.stat().st_size >= 1024 * 1024:
            raise SystemExit(f"{path.name} is {path.stat().st_size} bytes; WS-07 caps each tile at 1 MiB")
        entries.append(
            {
                "name": tile.spec.name,
                "patch_m": tile.spec.patch_m,
                "n": tile.spec.n,
                "wavelength_long_m": tile.spec.wavelength_long_m,
                "wavelength_short_m": tile.spec.wavelength_short_m,
                "bed_depth_m": tile.depth_m,
                "surface_slope_rms": round(tile.slope_rms, 6),
                "splat_std": round(float(np.std(tile.histogram)), 6),
                "stored_std": round(float(np.std(tile.values)), 6),
                # The shader crosses two scrolled layers with min(a, b) (layer B rotated 90
                # degrees); min pulls the mean below 1, so it divides by this to keep the
                # bed's average light unchanged. MapViewWaterMaterials mirrors the value.
                "min_pair_mean": round(caustic_min_pair_mean(tile.values), 4),
                "file": path.name,
                "sha256": sha256(path),
            }
        )
    profile = {
        "tool": "tools/bake_ocean_fft.py caustics",
        "tool_version": TOOL_VERSION,
        "seed": seed,
        "sea_state": asdict(sea),
        "ior": WATER_IOR,
        "method": "photon area ratio: vertical sun ray refracted at t = 0, bilinear periodic splat, "
        f"{CAUSTICS_BLUR_SIGMA_TEXELS:g}-texel Gaussian, mean 1 after clamp",
        "encoding": f"L8 byte = round(clamp(v, 0, {CAUSTICS_ENCODE_SCALE:g}) / {CAUSTICS_ENCODE_SCALE:g} * 255)",
        "scale": CAUSTICS_ENCODE_SCALE,
        "tiles": entries,
    }
    (out_dir / "caustics_profile.json").write_text(json.dumps(profile, indent=2) + "\n", encoding="utf-8")
    profile["_tiles"] = tiles  # in-memory only, for tests
    return profile


def caustics_main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="bake_ocean_fft.py caustics", description="WS-07 photon-splat caustic tiles")
    parser.add_argument("--out", type=Path, help="output directory (default assets/water/ocean_fft)")
    parser.add_argument("--seed", type=int, default=PROFILES["baltic_reference"]["seed"])
    parser.add_argument("--check", action="store_true", help="re-bake to a temp dir and compare with --out")
    args = parser.parse_args(argv)
    sea: SeaState = PROFILES["baltic_reference"]["sea"]
    out = args.out or Path(__file__).resolve().parent.parent / "assets" / "water" / "ocean_fft"
    if args.check:
        with tempfile.TemporaryDirectory() as tmp:
            bake_caustics(sea, args.seed, Path(tmp))
            drift = [
                fresh.name
                for fresh in sorted(Path(tmp).iterdir())
                if not (out / fresh.name).is_file() or sha256(out / fresh.name) != sha256(fresh)
            ]
        if drift:
            print(f"caustics bake drift in {out}: {', '.join(drift)}", file=sys.stderr)
            return 1
        print(f"caustics bake matches {out}")
        return 0
    profile = bake_caustics(sea, args.seed, out)
    for entry in profile["tiles"]:
        print(f"wrote {out / entry['file']}: bed {entry['bed_depth_m']} m, std {entry['stored_std']:.3f}")
    return 0


# --- CLI ------------------------------------------------------------------------------------


def parse_cascade(text: str) -> CascadeSpec:
    parts = text.split(":")
    if len(parts) not in (7, 8):
        raise argparse.ArgumentTypeError("cascade must be name:patch_m:n:wavelength_long:wavelength_short:period_s:frames[:nodisp]")
    name, patch, n, long_wl, short_wl, period, frames = parts[:7]
    return CascadeSpec(name, float(patch), int(n), float(long_wl), float(short_wl), float(period), int(frames), len(parts) == 7)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--profile", default="baltic_reference", choices=sorted(PROFILES))
    parser.add_argument("--out", type=Path, help="output directory for atlases and ocean_fft_profile.json")
    parser.add_argument("--check", action="store_true", help="re-bake to a temp dir and compare with --out (default: profile asset dir)")
    parser.add_argument("--preview", type=Path, help="write a height/foam contact sheet PNG (keep out of assets/)")
    parser.add_argument("--seed", type=int)
    parser.add_argument("--wind-speed", type=float)
    parser.add_argument("--fetch", type=float)
    parser.add_argument("--depth", type=float)
    parser.add_argument("--swell", type=float)
    parser.add_argument("--spread-blend", type=float)
    parser.add_argument("--cascade", action="append", type=parse_cascade, help="override cascades (repeatable)")
    parser.add_argument("--unit-amplitude", action="store_true", help=argparse.SUPPRESS)  # test-only
    return parser


def resolve(args: argparse.Namespace) -> tuple[SeaState, tuple[CascadeSpec, ...], int]:
    profile = PROFILES[args.profile]
    base: SeaState = profile["sea"]
    sea = SeaState(
        wind_speed=args.wind_speed if args.wind_speed is not None else base.wind_speed,
        fetch=args.fetch if args.fetch is not None else base.fetch,
        depth=args.depth if args.depth is not None else base.depth,
        swell=args.swell if args.swell is not None else base.swell,
        spread_blend=args.spread_blend if args.spread_blend is not None else base.spread_blend,
    )
    cascades = tuple(args.cascade) if args.cascade else profile["cascades"]
    seed = args.seed if args.seed is not None else profile["seed"]
    return sea, cascades, seed


def main(argv: list[str] | None = None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    # WS-06: the foam tile is a separate subcommand so the cascade flags stay unchanged.
    if argv and argv[0] == "foam-tile":
        return foam_tile_main(argv[1:])
    if argv and argv[0] == "caustics":
        return caustics_main(argv[1:])
    args = build_parser().parse_args(argv)
    sea, cascades, seed = resolve(args)
    default_out = Path(__file__).resolve().parent.parent / "assets" / "water" / "ocean_fft" / args.profile

    if args.check:
        reference = args.out or default_out
        with tempfile.TemporaryDirectory() as tmp:
            bake(sea, cascades, seed, Path(tmp), profile_name=args.profile, unit_amplitude=args.unit_amplitude)
            drift = []
            for fresh in sorted(Path(tmp).iterdir()):
                committed = reference / fresh.name
                if not committed.is_file() or sha256(committed) != sha256(fresh):
                    drift.append(fresh.name)
        if drift:
            print(f"ocean FFT bake drift in {reference}: {', '.join(drift)}", file=sys.stderr)
            return 1
        print(f"ocean FFT bake matches {reference}")
        return 0

    if args.out is None and args.preview is None:
        build_parser().error("give --out, --check or --preview")
    out = args.out
    tmp_ctx = None
    if out is None:
        tmp_ctx = tempfile.TemporaryDirectory()
        out = Path(tmp_ctx.name)
    try:
        profile = bake(sea, cascades, seed, out, profile_name=args.profile, unit_amplitude=args.unit_amplitude)
        if args.preview:
            write_preview(profile["_bakes"], args.preview)
            print(f"wrote preview {args.preview}")
        if args.out is not None:
            print(f"baked {args.profile} into {out}: Hs = {profile['hs_m']:.3f} m")
    finally:
        if tmp_ctx is not None:
            tmp_ctx.cleanup()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
