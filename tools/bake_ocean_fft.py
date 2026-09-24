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
