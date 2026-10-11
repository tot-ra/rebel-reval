#!/usr/bin/env python3
"""R-932: measure existing Compatibility vs Metal water plates and scan shaders.

Investigation only. Does not recapture and does not edit shaders. Run:

    python3 tools/probe_water_renderer_parity.py
    python3 tools/probe_water_renderer_parity.py --check

--check exits 0 when the named evidence plates still show the documented split
and the shader still has the tokens the follow-up rows must change.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
IMAGES = ROOT / "docs" / "reports" / "images"
WATER_SHADER = ROOT / "scripts" / "map" / "view3d" / "map_view_water.gdshader"
UNDERWATER_SHADER = ROOT / "scripts" / "map" / "view3d" / "underwater_pass.gdshader"
FFT_INCLUDE = ROOT / "scripts" / "map" / "view3d" / "ocean_fft_common.gdshaderinc"

# Lower-middle harbour crop used for WS-07 beach-shelf water (1280x720).
WATER_CROP = (0.42, 0.92, 0.08, 0.92)


def _load(path: Path) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGB"), dtype=np.float32)


def _crop(arr: np.ndarray, spec: tuple[float, float, float, float]) -> np.ndarray:
    h, w, _ = arr.shape
    y0, y1, x0, x1 = spec
    return arr[int(h * y0) : int(h * y1), int(w * x0) : int(w * x1)]


def _stats(arr: np.ndarray) -> dict[str, float]:
    luma = arr @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
    chroma = arr.max(axis=2) - arr.min(axis=2)
    pad = np.pad(chroma, 1, mode="edge")
    blur = (
        pad[0:-2, 0:-2]
        + pad[0:-2, 1:-1]
        + pad[0:-2, 2:]
        + pad[1:-1, 0:-2]
        + pad[1:-1, 1:-1]
        + pad[1:-1, 2:]
        + pad[2:, 0:-2]
        + pad[2:, 1:-1]
        + pad[2:, 2:]
    ) / 9.0
    hf = np.abs(chroma - blur)
    mean = arr.mean(axis=(0, 1))
    return {
        "luma": float(luma.mean()),
        "chroma_mean": float(chroma.mean()),
        "chroma_p95": float(np.percentile(chroma, 95)),
        "hf_chroma": float(hf.mean()),
        "b_minus_r": float(mean[2] - mean[0]),
        "r": float(mean[0]),
        "g": float(mean[1]),
        "b": float(mean[2]),
    }


def _abs_mean(a: Path, b: Path) -> float:
    left = _crop(_load(a), WATER_CROP)
    right = _crop(_load(b), WATER_CROP)
    return float(np.abs(left - right).mean())


def measure_plates() -> dict[str, object]:
    def plate(name: str) -> Path:
        path = IMAGES / name
        if not path.is_file():
            raise FileNotFoundError(path)
        return path

    noon_metal_off = plate("ws07_metal_clear_noon_off.png")
    noon_gl_off = plate("ws07_opengl3_clear_noon_off.png")
    noon_metal_on = plate("ws07_metal_clear_noon.png")
    noon_gl_on = plate("ws07_opengl3_clear_noon.png")
    sunset_metal = plate("ws07_metal_clear_sunset.png")
    sunset_gl = plate("ws07_opengl3_clear_sunset.png")
    sunset_gl_off = plate("ws07_opengl3_clear_sunset_off.png")
    night_metal = plate("ws07_metal_clear_night.png")
    night_gl = plate("ws07_opengl3_clear_night.png")
    under_metal = plate("ws13e_harbor_east_under_horizontal_metal.png")
    under_gl = plate("ws13e_harbor_east_under_horizontal_gl.png")

    noon_off_metal = _stats(_crop(_load(noon_metal_off), WATER_CROP))
    noon_off_gl = _stats(_crop(_load(noon_gl_off), WATER_CROP))
    sunset_metal_s = _stats(_crop(_load(sunset_metal), WATER_CROP))
    sunset_gl_s = _stats(_crop(_load(sunset_gl), WATER_CROP))
    under_gl_s = _stats(_load(under_gl))
    under_metal_s = _stats(_load(under_metal))

    return {
        "noon_off_metal": noon_off_metal,
        "noon_off_gl": noon_off_gl,
        "sunset_metal": sunset_metal_s,
        "sunset_gl": sunset_gl_s,
        "night_luma_metal": _stats(_crop(_load(night_metal), WATER_CROP))["luma"],
        "night_luma_gl": _stats(_crop(_load(night_gl), WATER_CROP))["luma"],
        "on_off_metal_noon": _abs_mean(noon_metal_on, noon_metal_off),
        "on_off_gl_noon": _abs_mean(noon_gl_on, noon_gl_off),
        "on_off_gl_sunset": _abs_mean(sunset_gl, sunset_gl_off),
        "under_gl": under_gl_s,
        "under_metal": under_metal_s,
        "chroma_ratio_noon_off": noon_off_gl["chroma_mean"] / max(noon_off_metal["chroma_mean"], 1e-6),
        "caustic_ratio_noon": _abs_mean(noon_gl_on, noon_gl_off)
        / max(_abs_mean(noon_metal_on, noon_metal_off), 1e-6),
    }


def shader_tokens() -> dict[str, bool]:
    water = WATER_SHADER.read_text()
    underwater = UNDERWATER_SHADER.read_text()
    fft = FFT_INCLUDE.read_text()
    return {
        "water_has_compat_ndc": "CURRENT_RENDERER == RENDERER_COMPATIBILITY" in water
        and "raw_depth) * 2.0 - 1.0" in water,
        "water_samples_screen": "hint_screen_texture" in water,
        "water_screen_has_mipmap": "hint_screen_texture, repeat_disable, filter_linear_mipmap"
        in water,
        "water_seen_from_below": "seen_from_below" in water,
        "water_uw_window_fringe": "uw.fringe" in water,
        "water_sky_lut_no_source_color": "uniform sampler2D sky_view_lut : filter_linear"
        in water,
        "fft_compat_alpha": "_compat_stored_alpha" in fft,
        "underwater_compat_empty_depth_hit": "COMPAT_EMPTY_DEPTH_HIT_SCALE" in underwater,
        "underwater_hint_depth": "hint_depth_texture" in underwater,
        "underwater_hint_screen": "hint_screen_texture" in underwater,
        "caustics_no_source_color": "uniform sampler2D caustics_tiles : hint_default_white"
        in water,
    }


def check(data: dict[str, object], tokens: dict[str, bool]) -> list[str]:
    errors: list[str] = []
    chroma_ratio = float(data["chroma_ratio_noon_off"])
    caustic_ratio = float(data["caustic_ratio_noon"])
    sunset_on_off = float(data["on_off_gl_sunset"])
    under_gl = data["under_gl"]
    assert isinstance(under_gl, dict)

    # GL still shows a more chromatic / bed-forward shelf than Metal.
    if chroma_ratio < 1.3:
        errors.append(f"noon-off chroma ratio {chroma_ratio:.2f} < 1.3 (split closed or plates moved)")
    if caustic_ratio < 2.0:
        errors.append(f"noon caustic |on-off| ratio {caustic_ratio:.2f} < 2.0")
    # Sunset mottle is not the caustic net.
    if sunset_on_off > 2.0:
        errors.append(f"GL sunset |on-off| {sunset_on_off:.2f} > 2 (no longer independent of caustics)")
    # Compatibility under-horizontal is a flat teal field, not a crib.
    if float(under_gl["chroma_mean"]) < 80.0:
        errors.append(f"GL under_horizontal chroma {under_gl['chroma_mean']:.1f} < 80 (crib may be visible)")
    if float(under_gl["hf_chroma"]) > 2.0:
        errors.append(f"GL under_horizontal hf_chroma {under_gl['hf_chroma']:.2f} > 2 (no longer a flat underside)")
    for key, ok in tokens.items():
        if not ok:
            errors.append(f"missing shader token {key}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="exit 1 when the split is gone")
    args = parser.parse_args()
    data = measure_plates()
    tokens = shader_tokens()
    payload = {"plates": data, "shader_tokens": tokens}
    print(json.dumps(payload, indent=2, sort_keys=True))
    if not args.check:
        return 0
    errors = check(data, tokens)
    if errors:
        print("CHECK FAILED:", file=sys.stderr)
        for item in errors:
            print(f"- {item}", file=sys.stderr)
        return 1
    print("CHECK OK: documented Compatibility vs Metal split still present.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
