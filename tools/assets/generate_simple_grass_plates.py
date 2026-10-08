#!/usr/bin/env python3
"""Draw primitive, seamless grass ground plates in code (no image generator).

Why: the earlier plates (OpenAI/Leonardo photographs) had plantain rosettes,
clover, flowers and big leaves baked into the texture. Those read as flat decals
on the ground. The ground is now only a soft green colour field with gentle
tonal patches and fine grain; every recognisable plant (grass blades, plantain,
dandelion, clover) is real 3D geometry scattered on top (CityGrass, VEGR-4).

Noise is filtered white noise in the frequency domain, so it wraps exactly and
needs no seam blending.

Outputs (same files and slice order as build_vegetation_plates.py, so no
runtime or import change):
- assets/materials/pbr/grass_ground/grass_ground_{albedo,normal}_array.jpg (4x3)
- assets/materials/pbr/grass/grass_{albedo,normal,roughness}.png (single plate
  used by the map-view terrain blend)

Usage: python3 tools/assets/generate_simple_grass_plates.py
"""

from __future__ import annotations

import hashlib
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
GROUND_OUT = ROOT / "assets/materials/pbr/grass_ground"
PLATE_OUT = ROOT / "assets/materials/pbr/grass"
SLICE = 512
GRID = (4, 3)
# Slice order is a runtime contract (city_grass_ground.gdshaderinc):
# 0-7 green meadows, 8 dry summer, 9 moss in shade, 10 leaf litter, 11 trodden.
# (mean sRGB, patch contrast, patch scale in cells per plate, grain contrast)
SLICES = [
    ((81, 111, 30), 0.10, 3, 0.05),
    ((80, 110, 31), 0.12, 4, 0.05),
    ((79, 108, 30), 0.10, 3, 0.05),
    ((78, 107, 30), 0.13, 5, 0.06),
    ((83, 113, 28), 0.09, 3, 0.04),
    ((79, 108, 31), 0.12, 4, 0.05),
    ((75, 103, 29), 0.14, 5, 0.06),
    ((83, 110, 32), 0.10, 3, 0.05),
    ((105, 110, 46), 0.12, 4, 0.06),
    ((72, 90, 30), 0.12, 4, 0.05),
    ((86, 101, 36), 0.14, 5, 0.06),
    ((110, 98, 57), 0.08, 3, 0.05),
]


def band_noise(size: int, cells: float, rng: np.random.Generator) -> np.ndarray:
    """Periodic noise with feature size ~ size/cells px, zero mean, unit std."""
    white = rng.standard_normal((size, size))
    fx = np.fft.fftfreq(size)[None, :] * size
    fy = np.fft.fftfreq(size)[:, None] * size
    radius = np.sqrt(fx * fx + fy * fy)
    # Gaussian band-pass centred on `cells` cycles per plate.
    gain = np.exp(-((radius - cells) ** 2) / (2.0 * (0.6 * cells) ** 2))
    gain[0, 0] = 0.0
    out = np.fft.ifft2(np.fft.fft2(white) * gain).real
    return out / max(out.std(), 1e-6)


def plate(mean: tuple[int, int, int], patch: float, cells: int, grain: float,
          rng: np.random.Generator) -> tuple[np.ndarray, np.ndarray]:
    """Returns (albedo 0..1 HxWx3, height 0..1 HxW)."""
    tone = (band_noise(SLICE, cells, rng) * 0.6 + band_noise(SLICE, cells * 3, rng) * 0.4)
    fine = band_noise(SLICE, SLICE / 6.0, rng)
    luma = 1.0 + patch * tone + grain * fine
    # Patches shift hue slightly (yellow-green vs blue-green) so a field is not one flat colour.
    hue = band_noise(SLICE, cells * 2, rng)[..., None] * np.array([0.035, 0.0, -0.05])
    base = np.array(mean, dtype=np.float64) / 255.0
    albedo = np.clip(base * (luma[..., None] + hue), 0.0, 1.0)
    height = 0.5 + 0.25 * fine + 0.15 * tone
    return albedo, np.clip(height, 0.0, 1.0)


def normal_from(height: np.ndarray, strength: float) -> np.ndarray:
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5
    n = np.dstack([-dx * strength, dy * strength, np.ones_like(dx)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n * 0.5 + 0.5


def to_image(arr: np.ndarray) -> Image.Image:
    return Image.fromarray((np.clip(arr, 0.0, 1.0) * 255.0).round().astype(np.uint8))


def save(img: Image.Image, path: Path, **kwargs) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, **kwargs)
    print(f"{path.relative_to(ROOT)} {path.stat().st_size // 1024} KiB "
          f"SHA-256 {hashlib.sha256(path.read_bytes()).hexdigest()}")


def build_array() -> None:
    albedo = np.zeros((GRID[1] * SLICE, GRID[0] * SLICE, 3))
    normal = np.zeros_like(albedo)
    for index, (mean, patch, cells, grain) in enumerate(SLICES):
        rng = np.random.default_rng(1343 + index)
        a, h = plate(mean, patch, cells, grain, rng)
        r, c = divmod(index, GRID[0])
        albedo[r * SLICE:(r + 1) * SLICE, c * SLICE:(c + 1) * SLICE] = a
        normal[r * SLICE:(r + 1) * SLICE, c * SLICE:(c + 1) * SLICE] = normal_from(h, 1.2)
    save(to_image(albedo), GROUND_OUT / "grass_ground_albedo_array.jpg", quality=90, subsampling=0)
    save(to_image(normal), GROUND_OUT / "grass_ground_normal_array.jpg", quality=90, subsampling=0)


def build_single() -> None:
    """Plate for the map-view terrain blend: albedo 2048 px, normal and roughness
    1024 px (the ground arrays share one layer size per map type)."""
    global SLICE
    old, SLICE = SLICE, 2048
    rng = np.random.default_rng(1343 + 100)
    a, h = plate((63, 68, 36), 0.10, 4, 0.05, rng)
    SLICE = old
    save(to_image(a), PLATE_OUT / "grass_albedo.png")
    # Box-downsample the height so the 1024 px normal/roughness still tile exactly.
    h1k = h.reshape(1024, 2, 1024, 2).mean(axis=(1, 3))
    save(to_image(normal_from(h1k, 1.2)), PLATE_OUT / "grass_normal.png")
    save(to_image(np.clip(0.9 - 0.08 * (h1k - 0.5), 0.0, 1.0)), PLATE_OUT / "grass_roughness.png")


if __name__ == "__main__":
    build_array()
    build_single()
