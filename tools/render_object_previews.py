#!/usr/bin/env python3
"""Render a flat-shaded preview PNG for every catalog object that has a GLB model.

The previews are deterministic software renders (numpy z-buffer, orthographic
three-quarter view, material colour = mean of the albedo texture). They are
*reference thumbnails* so agents and designers can see what an object is; the
final runtime icon is the separate ``visual.icon`` field.

Usage:
    python3 tools/render_object_previews.py            # render missing/stale
    python3 tools/render_object_previews.py --all      # re-render everything
    python3 tools/render_object_previews.py obj.pitchfork obj.cup
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

TOOLS = Path(__file__).resolve().parent
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import object_catalog_lib as lib  # noqa: E402
from object_catalog_glb import GlbFile, Triangles  # noqa: E402

SIZE = 256
SUPERSAMPLE = 2
VIEW_DIR = np.array([0.62, 0.55, 0.78])  # camera sits on this side of the object
LIGHT_DIR = np.array([-0.35, 0.85, 0.45])


def _camera_basis() -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    forward = -VIEW_DIR / np.linalg.norm(VIEW_DIR)
    right = np.cross(forward, np.array([0.0, 1.0, 0.0]))
    right /= np.linalg.norm(right)
    up = np.cross(right, forward)
    return right, up, forward


def render(tris: Triangles, size: int = SIZE) -> Image.Image:
    px = size * SUPERSAMPLE
    image = np.zeros((px, px, 4), dtype=np.float32)
    depth = np.full((px, px), -np.inf, dtype=np.float32)
    if tris.count == 0:
        return Image.fromarray(image.astype(np.uint8), "RGBA")

    right, up, forward = _camera_basis()
    flat = tris.verts.reshape(-1, 3)
    centre = (flat.min(axis=0) + flat.max(axis=0)) / 2.0
    rel = tris.verts - centre
    x = rel @ right
    y = rel @ up
    z = rel @ -forward  # larger = closer to camera
    span = max(np.ptp(x), np.ptp(y), 1e-6)
    scale = px * 0.82 / span
    sx = x * scale + px / 2.0
    sy = px / 2.0 - y * scale

    edge1 = tris.verts[:, 1] - tris.verts[:, 0]
    edge2 = tris.verts[:, 2] - tris.verts[:, 0]
    normals = np.cross(edge1, edge2)
    lengths = np.linalg.norm(normals, axis=1, keepdims=True)
    normals = normals / np.where(lengths == 0, 1, lengths)
    facing = normals @ (VIEW_DIR / np.linalg.norm(VIEW_DIR))
    normals = normals * np.where(facing < 0, -1.0, 1.0)[:, None]  # two-sided
    light = LIGHT_DIR / np.linalg.norm(LIGHT_DIR)
    shade = 0.42 + 0.58 * np.clip(normals @ light, 0.0, 1.0)
    base = np.clip(tris.colors, 0.0, 1.0) ** (1 / 2.2)
    shaded = np.clip(0.12 + base * shade[:, None] * 1.55, 0.0, 1.0)

    for i in range(tris.count):
        xs, ys, zs = sx[i], sy[i], z[i]
        min_x = max(int(np.floor(xs.min())), 0)
        max_x = min(int(np.ceil(xs.max())), px - 1)
        min_y = max(int(np.floor(ys.min())), 0)
        max_y = min(int(np.ceil(ys.max())), px - 1)
        if min_x > max_x or min_y > max_y:
            continue
        denom = (ys[1] - ys[2]) * (xs[0] - xs[2]) + (xs[2] - xs[1]) * (ys[0] - ys[2])
        if abs(denom) < 1e-9:
            continue
        gx, gy = np.meshgrid(
            np.arange(min_x, max_x + 1) + 0.5, np.arange(min_y, max_y + 1) + 0.5
        )
        w0 = ((ys[1] - ys[2]) * (gx - xs[2]) + (xs[2] - xs[1]) * (gy - ys[2])) / denom
        w1 = ((ys[2] - ys[0]) * (gx - xs[2]) + (xs[0] - xs[2]) * (gy - ys[2])) / denom
        w2 = 1.0 - w0 - w1
        inside = (w0 >= -1e-4) & (w1 >= -1e-4) & (w2 >= -1e-4)
        if not inside.any():
            continue
        zz = w0 * zs[0] + w1 * zs[1] + w2 * zs[2]
        window = depth[min_y : max_y + 1, min_x : max_x + 1]
        write = inside & (zz > window)
        window[write] = zz[write]
        pix = image[min_y : max_y + 1, min_x : max_x + 1]
        pix[write, :3] = shaded[i] * 255.0
        pix[write, 3] = 255.0

    out = Image.fromarray(image.astype(np.uint8), "RGBA")
    return out.resize((size, size), Image.LANCZOS)


def triangles_for(entry: dict) -> Triangles:
    model = entry["model"]
    glb = GlbFile.load(lib.res_to_path(model["glb"]))
    node = model.get("node")
    if node is None and model.get("states"):
        node = next(iter(model["states"].values()))
    if node is None:
        return glb.triangles()
    index = glb.find_node(node)
    if index is None:
        raise ValueError(f"{entry['id']}: node {node!r} not in {model['glb']}")
    return glb.triangles(index)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ids", nargs="*", help="object ids to render (default: missing/stale)")
    parser.add_argument("--all", action="store_true", help="re-render every object")
    args = parser.parse_args(argv)

    entries = lib.load_catalog()
    rendered = 0
    for entry in entries:
        if args.ids and entry["id"] not in args.ids:
            continue
        model = entry["model"]
        if model["status"] != "glb":
            continue
        target = lib.ROOT / entry["visual"]["preview"]
        glb_path = lib.res_to_path(model["glb"])
        if target.is_file() and not args.all and not args.ids:
            if target.stat().st_mtime >= glb_path.stat().st_mtime:
                continue
        target.parent.mkdir(parents=True, exist_ok=True)
        render(triangles_for(entry)).save(target, optimize=True)
        rendered += 1
        print(f"rendered {entry['id']} -> {target.relative_to(lib.ROOT)}")
    print(f"{rendered} preview(s) written")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
