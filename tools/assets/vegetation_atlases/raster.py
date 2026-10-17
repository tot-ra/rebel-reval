"""Shared raster canvas, seeded noise, shape compositing and card finishing."""

from __future__ import annotations

import math

import numpy as np

from .species import SEED, SS

class Canvas:
    def __init__(self, width: int, height: int) -> None:
        self.w, self.h = width, height
        self.rgb = np.zeros((height, width, 3), dtype=np.float64)
        self.alpha = np.zeros((height, width), dtype=np.float64)
        self.height = np.zeros((height, width), dtype=np.float64)
        self.rough = np.zeros((height, width), dtype=np.float64)
        self.trans = np.zeros((height, width), dtype=np.float64)
        self.occ = np.ones((height, width), dtype=np.float64)

    def window(self, x0: float, y0: float, x1: float, y1: float):
        xa, xb = max(int(math.floor(x0)), 0), min(int(math.ceil(x1)) + 1, self.w)
        ya, yb = max(int(math.floor(y0)), 0), min(int(math.ceil(y1)) + 1, self.h)
        if xa >= xb or ya >= yb:
            return None
        ys, xs = np.mgrid[ya:yb, xa:xb].astype(np.float64)
        return (slice(ya, yb), slice(xa, xb)), xs + 0.5, ys + 0.5

    def shade(self, win, cover: np.ndarray, strength: float) -> None:
        """Darken what is already drawn under a soft contact shadow."""
        sl = win
        self.rgb[sl] *= (1.0 - strength * cover * self.alpha[sl])[..., None]
        self.occ[sl] *= 1.0 - strength * cover * self.alpha[sl]

    def paint(self, win, cover: np.ndarray, rgb: np.ndarray, height: np.ndarray,
              rough: np.ndarray, trans: np.ndarray) -> None:
        sl = win
        c = cover[..., None]
        self.rgb[sl] = rgb * c + self.rgb[sl] * (1.0 - c)
        self.height[sl] = height * cover + self.height[sl] * (1.0 - cover)
        self.rough[sl] = rough * cover + self.rough[sl] * (1.0 - cover)
        self.trans[sl] = trans * cover + self.trans[sl] * (1.0 - cover)
        self.occ[sl] = 1.0 * cover + self.occ[sl] * (1.0 - cover)
        self.alpha[sl] = cover + self.alpha[sl] * (1.0 - cover)


def smoothstep(e0: float, e1: float, x: np.ndarray) -> np.ndarray:
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def periodic_noise(rng: np.random.Generator, shape: tuple[int, int], wavelength: float,
                   stretch: float = 1.0) -> np.ndarray:
    """Seamless Gaussian-filtered noise (FFT, so it tiles exactly), unit std.
    `stretch` > 1 elongates features along y."""
    h, w = shape
    white = rng.standard_normal(shape)
    ky = np.fft.fftfreq(h)[:, None] * stretch
    kx = np.fft.fftfreq(w)[None, :]
    sigma = 1.0 / max(wavelength, 1.0)
    filt = np.exp(-(kx * kx + ky * ky) / (2.0 * sigma * sigma))
    out = np.real(np.fft.ifft2(np.fft.fft2(white) * filt))
    out -= out.mean()
    return out / max(out.std(), 1e-9)


def fbm(rng: np.random.Generator, shape: tuple[int, int], wavelength: float,
        octaves: int = 4, stretch: float = 1.0, gain: float = 0.5) -> np.ndarray:
    total = np.zeros(shape)
    amp = 1.0
    for octave in range(octaves):
        total += amp * periodic_noise(rng, shape, wavelength / (2 ** octave), stretch)
        amp *= gain
    return total / max(total.std(), 1e-9)


def periodic_voronoi(rng: np.random.Generator, size: int, count: int,
                     aspect: float = 1.0) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """F1, F2 distances (in cell units) and nearest-cell id on a wrapping square.
    aspect > 1 stretches cells along y."""
    points = rng.uniform(0.0, 1.0, (count, 2))
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float64) / size
    f1 = np.full((size, size), 9.0)
    f2 = np.full((size, size), 9.0)
    ident = np.zeros((size, size), dtype=np.int64)
    scale = math.sqrt(count)
    for index, (px, py) in enumerate(points):
        dx = np.abs(xs - px)
        dx = np.minimum(dx, 1.0 - dx)
        dy = np.abs(ys - py)
        dy = np.minimum(dy, 1.0 - dy) / aspect
        d = np.sqrt(dx * dx + dy * dy) * scale
        closer = d < f1
        f2 = np.where(closer, f1, np.minimum(f2, d))
        ident = np.where(closer, index, ident)
        f1 = np.where(closer, d, f1)
    return f1, f2, ident


def draw_capsule(canvas: Canvas, p0, p1, r0: float, r1: float, colour, height: float,
                 rough: float, trans: float, shadow: float = 0.0) -> None:
    x0, y0 = p0
    x1, y1 = p1
    pad = max(r0, r1) + 2.0
    win = canvas.window(min(x0, x1) - pad, min(y0, y1) - pad, max(x0, x1) + pad,
                        max(y0, y1) + pad)
    if win is None:
        return
    sl, xs, ys = win
    dx, dy = x1 - x0, y1 - y0
    length2 = max(dx * dx + dy * dy, 1e-9)
    t = np.clip(((xs - x0) * dx + (ys - y0) * dy) / length2, 0.0, 1.0)
    px, py = x0 + t * dx, y0 + t * dy
    dist = np.sqrt((xs - px) ** 2 + (ys - py) ** 2)
    radius = r0 + (r1 - r0) * t
    cover = np.clip(radius - dist + 0.5, 0.0, 1.0)
    if not cover.any():
        return
    if shadow > 0.0:
        canvas.shade(sl, np.clip(radius * 1.8 - dist, 0.0, 1.0) * 0.7, shadow)
    across = np.clip(dist / np.maximum(radius, 1e-6), 0.0, 1.0)
    dome = np.sqrt(np.clip(1.0 - across * across, 0.0, 1.0))
    rgb = np.asarray(colour)[None, None, :] * (0.78 + 0.30 * dome)[..., None]
    canvas.paint(sl, cover, rgb, height + 0.6 * dome * radius / 6.0,
                 np.full(cover.shape, rough), np.full(cover.shape, trans))


def downsample(canvas: Canvas, factor: int = SS) -> dict[str, np.ndarray]:
    def box(a: np.ndarray) -> np.ndarray:
        h, w = a.shape[:2]
        return a.reshape(h // factor, factor, w // factor, factor, *a.shape[2:]).mean(axis=(1, 3))

    alpha = box(canvas.alpha)
    weight = np.maximum(alpha, 1e-6)
    out = {"alpha": alpha}
    out["rgb"] = box(canvas.rgb * canvas.alpha[..., None]) / weight[..., None]
    for name in ("height", "rough", "trans", "occ"):
        out[name] = box(getattr(canvas, name) * canvas.alpha) / weight
    return out


def box_blur(a: np.ndarray, r: int) -> np.ndarray:
    for axis in (0, 1):
        pad = [(0, 0)] * a.ndim
        pad[axis] = (r + 1, r)
        c = np.cumsum(np.pad(a, pad, mode="edge"), axis=axis)
        n = a.shape[axis]
        a = (np.take(c, np.arange(2 * r + 1, 2 * r + 1 + n), axis=axis)
             - np.take(c, np.arange(0, n), axis=axis)) / (2 * r + 1)
    return a


def rim_fill(values: np.ndarray, solid: np.ndarray) -> np.ndarray:
    """Spread colour from covered texels into empty ones (normalised blur), so
    linear mips never mix the empty texel colour into leaf edges."""
    filled = values.copy()
    known = solid.astype(np.float64)
    channels = values[..., None] if values.ndim == 2 else values
    out = filled[..., None] if values.ndim == 2 else filled
    for radius in (2, 6, 18, 48):
        def blur(a: np.ndarray, r: int = radius) -> np.ndarray:
            return box_blur(box_blur(a, r), r)
        weight = blur(known)
        colour = np.dstack([blur(channels[..., c] * known) for c in range(channels.shape[2])])
        colour /= np.maximum(weight, 1e-6)[..., None]
        empty = (known < 0.5) & (weight > 1e-4)
        out[empty] = colour[empty]
        channels = out
        known = np.maximum(known, (weight > 1e-4).astype(np.float64))
    mean = out[solid > 0.5].mean(axis=0) if (solid > 0.5).any() else out.mean(axis=(0, 1))
    out[known < 0.5] = mean
    return out[..., 0] if values.ndim == 2 else out


def relative_detail(rgb: np.ndarray, alpha: np.ndarray) -> np.ndarray:
    """Scale each channel so the mean opaque colour is neutral 0.5 grey (the
    R-1194 contract: species colour comes from the shader)."""
    opaque = alpha > 0.5
    mean = rgb[opaque].mean(axis=0)
    return np.clip(rgb / mean[None, None, :] * 0.5, 0.0, 1.0)


def normal_map(height: np.ndarray, strength: float, wrap: bool) -> np.ndarray:
    if wrap:
        dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5
        dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5
    else:
        dy, dx = np.gradient(height)
    n = np.dstack([-dx * strength, dy * strength, np.ones_like(dx)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n * 0.5 + 0.5


def to_u8(a: np.ndarray) -> np.ndarray:
    return (np.clip(a, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)


def finish_card(canvas: Canvas) -> dict[str, np.ndarray]:
    small = downsample(canvas)
    alpha = small["alpha"]
    solid = alpha > 0.5
    detail = relative_detail(small["rgb"], alpha)
    detail = rim_fill(detail, solid)
    height = small["height"] * smoothstep(0.0, 0.5, alpha)
    normal = normal_map(height, 6.0, wrap=False)
    normal[~solid] = (0.5, 0.5, 1.0)
    surface = np.dstack([small["rough"], small["trans"], small["occ"]])
    surface = rim_fill(surface, solid)
    return {
        "albedo": np.dstack([detail, alpha]),
        "normal": normal,
        "surface": surface,
    }


def species_rng(*keys: int | str) -> np.random.Generator:
    ints = [SEED] + [k if isinstance(k, int) else int.from_bytes(k.encode(), "little") % (1 << 31)
                     for k in keys]
    return np.random.default_rng(ints)
