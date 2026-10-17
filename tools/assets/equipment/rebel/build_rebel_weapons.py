#!/usr/bin/env python3
"""Build the rebel levy weapons of R-2014 (EQ-12) and render their turntables.

Pipeline and conventions: docs/SYSTEMS/EQUIPMENT_VARIANTS.md ("Rebel levy weapons");
forms: history/dossiers/military/rebel-levy-improvised-weapons-1343.md.

Meshy and Leonardo were both out of credit when this set was made (402 on
2026-10-17), so nothing is scanned. Two routes instead, both deterministic:

- photo items (clubs, sickle): the OpenAI reference photo IS the source. This
  script cuts its silhouette from the white background and writes the shape
  data plus the albedo, normal and ORM maps derived from the photo; Blender
  (rebel_mesh.py) turns a club's silhouette into a body of revolution
  ("photo-lathe") and a sickle's into a 3 mm plate with a turned grip, and
  projects the photo back onto them;
- wooden poles (threshing flail, hayfork): fully procedural in rebel_mesh.py
  on the repo's ash plates (a 1.3-1.8 m pole is the shape Meshy cannot resolve
  anyway).

A later Meshy scan of the same reference can replace a GLB file for file.

    python3 tools/assets/equipment/rebel/build_rebel_weapons.py [--only club_oak_p1_w1,...] [--no-turntable]
    /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
    python3 tools/assets/equipment/rebel/build_rebel_weapons.py --scenes   # held scenes from the import uids
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import subprocess
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
MANIFEST = HERE / "rebel_weapons.json"
WORK = ROOT / "build" / "rebel_weapons"
SHEETS = ROOT / "docs" / "reports" / "images" / "equipment"
BLENDER = os.environ.get("BLENDER", "/Applications/Blender.app/Contents/MacOS/Blender")


# ---------------------------------------------------------------- image helpers


def _box(a: np.ndarray, r: int) -> np.ndarray:
    """Box blur of a 2D array with radius r (summed-area table, edges clamped)."""
    if r <= 0:
        return a
    p = np.pad(a, r + 1, mode="edge")
    s = p.cumsum(0).cumsum(1)
    k = 2 * r + 1
    out = s[k:, k:] - s[:-k, k:] - s[k:, :-k] + s[:-k, :-k]
    return out[: a.shape[0], : a.shape[1]] / (k * k)


def _morph(mask: np.ndarray, flt: ImageFilter.Filter) -> np.ndarray:
    return np.asarray(Image.fromarray((mask * 255).astype(np.uint8)).filter(flt)) > 127


def _largest_component(mask: np.ndarray) -> np.ndarray:
    """Keep the largest 4-connected blob (BFS on a 4x downsample, then masked back)."""
    small = mask[::4, ::4]
    h, w = small.shape
    label = np.zeros((h, w), np.int32)
    best, best_n, n = 0, 0, 0
    for y0, x0 in zip(*np.nonzero(small)):
        if label[y0, x0]:
            continue
        n += 1
        label[y0, x0] = n
        q, count = deque([(y0, x0)]), 0
        while q:
            y, x = q.popleft()
            count += 1
            for yy, xx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                if 0 <= yy < h and 0 <= xx < w and small[yy, xx] and not label[yy, xx]:
                    label[yy, xx] = n
                    q.append((yy, xx))
        if count > best_n:
            best, best_n = n, count
    keep = np.kron(label == best, np.ones((4, 4), bool))[: mask.shape[0], : mask.shape[1]]
    return mask & _morph(keep, ImageFilter.MaxFilter(9))


def _foreground(rgb: np.ndarray, dark: float = 0.70) -> np.ndarray:
    """Object mask on the generator's pure white background.

    The "no cast shadow" photos still carry a faint neutral-grey contact shadow;
    it is light and unsaturated, so an object pixel must be either coloured
    (wood, rust) or clearly dark (iron). A lathe item only needs its outline, so it
    passes a strict `dark`; a flat item keeps grey iron with a looser one."""
    _h, sat, val = _hsv(rgb)
    m = ((1.0 - rgb.min(-1)) > 0.10) & ((sat > 0.14) | (val < dark))
    m = _morph(_morph(m, ImageFilter.MinFilter(5)), ImageFilter.MaxFilter(5))  # specks
    m = _morph(_morph(m, ImageFilter.MaxFilter(9)), ImageFilter.MinFilter(9))  # pinholes
    return _largest_component(m)


def _fill_background(rgb: np.ndarray, mask: np.ndarray) -> np.ndarray:
    """Push object colours out over the background so mip-maps and the UV
    margins never pick up the white studio backdrop (or its anti-aliased fringe)."""
    core = _morph(mask, ImageFilter.MinFilter(7))
    out = rgb.copy()
    todo = ~core
    w = core.astype(np.float32)
    for r in (3, 8, 24, 64, 160):
        wb = _box(w, r)
        ok = todo & (wb > 1e-3)
        for c in range(3):
            out[..., c][ok] = (_box(rgb[..., c] * w, r)[ok] / wb[ok])
        todo &= ~ok
    return out


def _hsv(rgb: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    mx, mn = rgb.max(-1), rgb.min(-1)
    d = mx - mn + 1e-6
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) / 6
    return h, d / (mx + 1e-6), mx


def _normal_map(lum: np.ndarray, strength: float) -> np.ndarray:
    """Tangent-space normal (glTF / OpenGL, green up) from the photo's high-pass
    luminance: dark cracks and grain read as grooves."""
    hgt = _box(lum, 1) - _box(lum, 10)
    gx = np.zeros_like(hgt)
    gy = np.zeros_like(hgt)
    gx[:, 1:-1] = (hgt[:, 2:] - hgt[:, :-2]) * 0.5
    gy[1:-1, :] = (hgt[2:, :] - hgt[:-2, :]) * 0.5  # down the rows
    n = np.stack([-gx * strength, gy * strength, np.ones_like(hgt)], -1)  # +rows = -v
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5


def _save(arr: np.ndarray, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8)).save(path)


def _fit(img: np.ndarray, tex: int) -> tuple[np.ndarray, float]:
    """Downscale so the longer side is at most `tex`; returns (image, factor)."""
    h, w = img.shape[:2]
    f = min(1.0, tex / max(w, h))
    if f >= 1.0:
        return img, 1.0
    size = (max(1, round(w * f)), max(1, round(h * f)))
    chans = [np.asarray(Image.fromarray(img[..., c].astype(np.float32)).resize(size, Image.LANCZOS)) for c in range(img.shape[2])]
    return np.stack(chans, -1), f


# ---------------------------------------------------------------- photo items


def _orm(rgb: np.ndarray, metal_zone: np.ndarray, it: dict, grip_zone: np.ndarray) -> np.ndarray:
    """O = 1 (the photo already carries its shading), R per material, M for bare iron.

    Iron is told from wood by colour, inside a zone the manifest names (the
    hoops of a club, the sickle blade): grey and dark = bare iron, orange-brown
    on a rusted item = rust (rough, not metal). Wood is matte, the hand-worn grip
    smoother."""
    h, s, v = _hsv(rgb)
    wear = it["wear"]
    wood_rough = 0.80 if wear == "w1" else 0.86
    rough = np.full(rgb.shape[:2], wood_rough, np.float32)
    rough[grip_zone] = 0.62 if wear == "w1" else 0.58  # hands polish the grip
    iron = metal_zone & (s < 0.32) & (v < 0.62)
    rust = metal_zone & ~iron
    metal = np.zeros_like(rough)
    metal[iron] = 0.85 if not it.get("metal_rusted") else 0.6
    rough[iron] = 0.55 if not it.get("metal_rusted") else 0.68
    rough[rust] = 0.9
    metal = _box(metal, 2)
    rough = _box(rough, 2)
    return np.stack([np.ones_like(rough), rough, metal], -1)


def _flatten_shading(rgb: np.ndarray, mask: np.ndarray, c: np.ndarray, r: np.ndarray) -> np.ndarray:
    """Divide out the studio light across a round item (lit top, dark flanks).

    Every object pixel gets its position across the item, s = (row - centre) / radius;
    the mean brightness per s-band is evened to the overall mean, so the lathe's
    mirrored back half does not carry a second highlight."""
    ys, xs = np.nonzero(mask)
    ok = r[xs] > 2
    ys, xs = ys[ok], xs[ok]
    s = np.clip((ys - c[xs]) / r[xs], -1, 1)
    bins = np.clip(((s + 1) * 0.5 * 24).astype(int), 0, 23)
    lum = rgb[ys, xs].mean(-1)
    mean = np.array([lum[bins == b].mean() if np.any(bins == b) else lum.mean() for b in range(24)])
    gain = np.clip(lum.mean() / np.maximum(mean, 1e-3), 0.75, 1.45)
    gain = np.convolve(np.pad(gain, 2, mode="edge"), np.ones(5) / 5, mode="valid")
    out = rgb.copy()
    out[ys, xs] *= gain[bins][:, None]
    return np.clip(out, 0, 1)


def prep_lathe(it: dict, tex: int, out: Path) -> dict:
    src = Image.open(ROOT / it["reference"]).convert("RGB")
    rgb = np.asarray(src, np.float32) / 255
    mask = _foreground(rgb, 0.42)
    ys, xs = np.nonzero(mask)
    cov = np.cov(np.stack([xs, ys]).astype(np.float64))
    w, v = np.linalg.eigh(cov)
    ax = v[:, int(np.argmax(w))]
    ang = math.degrees(math.atan2(ax[1], ax[0]))
    ang = (ang + 90) % 180 - 90
    # PIL rotates counter-clockwise on screen; the axis sits at -ang on screen.
    rot = src.rotate(ang, resample=Image.BICUBIC, expand=True, fillcolor=(255, 255, 255))
    rgb = np.asarray(rot, np.float32) / 255
    mask = _foreground(rgb, 0.42)
    ys, xs = np.nonzero(mask)
    m = 8
    y0, y1, x0, x1 = max(0, ys.min() - m), ys.max() + m + 1, max(0, xs.min() - m), xs.max() + m + 1
    rgb, mask = rgb[y0:y1, x0:x1], mask[y0:y1, x0:x1]
    cols = np.nonzero(mask.any(0))[0]
    # Head to the right (+axis = Godot +Y): the fatter end.
    tops = np.array([np.nonzero(mask[:, x])[0].min() if mask[:, x].any() else 0 for x in range(mask.shape[1])])
    bots = np.array([np.nonzero(mask[:, x])[0].max() if mask[:, x].any() else 0 for x in range(mask.shape[1])])
    width = (bots - tops).astype(np.float64) * mask.any(0)
    n = len(cols) // 6
    if width[cols[:n]].mean() > width[cols[-n:]].mean():
        rgb, mask = rgb[:, ::-1], mask[:, ::-1]
        tops, bots = tops[::-1], bots[::-1]
        cols = np.nonzero(mask.any(0))[0]
    r = (bots - tops) / 2.0 * mask.any(0)
    c = (bots + tops) / 2.0
    k = np.ones(7) / 7
    r_s = np.convolve(np.pad(r, 3, mode="edge"), k, mode="valid")
    # The centre of a thin end column is noise: hold it at the last column that is
    # at least half the typical width, then smooth (else the ends bend off as spikes).
    full = np.nonzero(r > 0.5 * np.median(r[cols]))[0]
    c = c.copy()
    c[: full.min()] = c[full.min()]
    c[full.max() + 1 :] = c[full.max()]
    c_s = np.convolve(np.pad(c, 7, mode="edge"), np.ones(15) / 15, mode="valid")
    rgb = _flatten_shading(rgb, mask, c_s, np.maximum(r_s, 1e-3))
    rgb = _fill_background(rgb, mask)
    xa, xb = int(cols.min()), int(cols.max())
    t = (np.arange(rgb.shape[1]) - xa) / max(1, xb - xa)
    zone = np.zeros(mask.shape, bool)
    for lo, hi in [it["metal_x"]] if it.get("metal_x") else []:
        zone[:, (t >= lo) & (t <= hi)] = True
    grip = np.zeros(mask.shape, bool)
    grip[:, (t >= 0) & (t <= 0.22)] = True
    orm = _orm(rgb, zone & mask, it, grip & mask)
    lum = rgb.mean(-1)
    nrm = _normal_map(lum, 3.0 if it["wear"] == "w2" else 2.2)
    rgb_t, f = _fit(rgb, tex)
    _save(rgb_t, out / "albedo.png")
    _save(_fit(nrm, tex)[0], out / "normal.png")
    _save(_fit(orm, tex)[0], out / "orm.png")
    stations = list(range(xa, xb + 1))
    return {
        "kind": "lathe",
        "tex_w": rgb_t.shape[1], "tex_h": rgb_t.shape[0], "f": f,
        "x": stations,
        "c": [float(c_s[x]) for x in stations],
        "r": [float(r_s[x]) for x in stations],
        "m_per_px": float(it["length_m"]) / (xb - xa),
    }


def prep_flat(it: dict, tex: int, out: Path) -> dict:
    rgb = np.asarray(Image.open(ROOT / it["reference"]).convert("RGB"), np.float32) / 255
    mask = _foreground(rgb)
    ys, xs = np.nonzero(mask)
    m = 8
    y0, y1, x0, x1 = max(0, ys.min() - m), ys.max() + m + 1, max(0, xs.min() - m), xs.max() + m + 1
    longest = float(max(ys.max() - ys.min(), xs.max() - xs.min()))
    (gx0, gy0), (gx1, gy1) = it["grip_axis_px"]
    rgb, mask = rgb[y0:y1, x0:x1], mask[y0:y1, x0:x1]
    g0 = np.array([gx0 - x0, gy0 - y0], np.float64)
    g1 = np.array([gx1 - x0, gy1 - y0], np.float64)
    a = (g1 - g0) / np.linalg.norm(g1 - g0)
    b = np.array([-a[1], a[0]])
    glen = float(np.linalg.norm(g1 - g0))
    # Grip half-width along its axis, measured across the mask.
    stations = np.arange(0.0, glen + 1e-6, 2.0)
    half = []
    for s in stations:
        p = g0 + a * s
        w = 0
        for side in (1, -1):
            d = 0
            while d < 200:
                q = (p + b * side * (d + 1)).round().astype(int)
                if not (0 <= q[1] < mask.shape[0] and 0 <= q[0] < mask.shape[1]) or not mask[q[1], q[0]]:
                    break
                d += 1
            w += d
        half.append(w / 2.0)
    half_s = np.convolve(np.pad(np.array(half), 2, mode="edge"), np.ones(5) / 5, mode="valid")
    # The grip is turned on its own; cut its capsule out of the flat plate.
    yy, xx = np.mgrid[0 : mask.shape[0], 0 : mask.shape[1]]
    rel = np.stack([xx - g0[0], yy - g0[1]], -1)
    # Explicit dot products: `rel @ a` on this array trips spurious BLAS fp warnings.
    along = rel[..., 0] * a[0] + rel[..., 1] * a[1]
    across = np.abs(rel[..., 0] * b[0] + rel[..., 1] * b[1])
    idx = np.clip((along / 2.0).astype(int), 0, len(half_s) - 1)
    in_grip = (along > -3) & (along < glen + 1) & (across <= half_s[idx] + 3)
    plate = mask & ~in_grip
    plate = _morph(_morph(plate, ImageFilter.MinFilter(3)), ImageFilter.MaxFilter(3))
    plate = _largest_component(plate)
    rgb_f = _fill_background(rgb, mask)
    grip_zone = in_grip & mask
    orm = _orm(rgb_f, plate, it, grip_zone)
    nrm = _normal_map(rgb_f.mean(-1), 2.6)
    rgb_t, f = _fit(rgb_f, tex)
    _save(rgb_t, out / "albedo.png")
    _save(_fit(nrm, tex)[0], out / "normal.png")
    _save(_fit(orm, tex)[0], out / "orm.png")
    Image.fromarray((plate * 255).astype(np.uint8)).save(out / "plate_mask.png")
    return {
        "kind": "flat",
        "tex_w": rgb_t.shape[1], "tex_h": rgb_t.shape[0], "f": f,
        "src_w": mask.shape[1], "src_h": mask.shape[0],
        "grip_g0": g0.tolist(), "grip_a": a.tolist(), "grip_len_px": glen,
        "grip_stations": stations.tolist(), "grip_half": half_s.tolist(),
        "m_per_px": float(it["longest_m"]) / longest,
    }


# ---------------------------------------------------------------- driver

HELD = """[gd_scene load_steps=2 format=3]

[ext_resource type="PackedScene" uid="{uid}" path="res://{glb}" id="1"]

[node name="{node}" type="Node3D"]
rotation = Vector3(0, 0, {turn})
metadata/variant = "{variant}"

[node name="Visual" parent="." instance=ExtResource("1")]
"""


def write_held_scenes(man: dict) -> None:
    """`<family>/scenes/<variant>_held.tscn` for the right-hand slot, origin = socket_grip.

    `carry: upright` (flail, hayfork): the spear's quarter turn, pole up along the
    forearm. `carry: hang` (clubs, sickle): the opposite turn, so the head hangs by the
    leg; turned up like the axe, a 0.8 m club ran its head through the shoulder."""
    for it in man["items"]:
        glb = f"{man['out_dir']}/{it['family']}/variants/{it['variant']}.glb"
        meta = (ROOT / f"{glb}.import").read_text()
        uid = next(ln.split('"')[1] for ln in meta.splitlines() if ln.startswith("uid="))
        node = "".join(w.capitalize() for w in it["family"].split("_")) + "Held"
        out = ROOT / man["out_dir"] / it["family"] / "scenes" / f"{it['variant']}_held.tscn"
        out.parent.mkdir(parents=True, exist_ok=True)
        turn = -math.pi / 2 if it.get("carry") == "hang" else math.pi / 2
        out.write_text(HELD.format(uid=uid, glb=glb, node=node, variant=it["variant"], turn=repr(turn)))
        print("SCENE", out.relative_to(ROOT))



def _blender(script: str, *args: str) -> str:
    cmd = [BLENDER, "-b", "--factory-startup", "--python", str(script), "--", *args]
    out = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, check=False)
    if out.returncode != 0 or "Traceback" in out.stdout + out.stderr:
        sys.exit(f"{script} failed:\n{out.stdout[-3000:]}\n{out.stderr[-3000:]}")
    return out.stdout


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--only", default="", help="comma-separated variants")
    p.add_argument("--no-turntable", action="store_true")
    p.add_argument("--scenes", action="store_true", help="only write the held scenes (after a Godot --import)")
    a = p.parse_args()
    man = json.loads(MANIFEST.read_text())
    if a.scenes:
        write_held_scenes(man)
        return
    only = {s for s in a.only.split(",") if s}
    for it in man["items"]:
        name = it["variant"]
        if only and name not in only:
            continue
        work = WORK / name
        work.mkdir(parents=True, exist_ok=True)
        shape: dict = {"kind": it["build"]}
        if it["build"] == "lathe":
            shape = prep_lathe(it, int(man["tex"]), work)
        elif it["build"] == "flat":
            shape = prep_flat(it, int(man["tex"]), work)
        (work / "shape.json").write_text(json.dumps(shape))
        log = _blender(HERE / "rebel_mesh.py", "--manifest", str(MANIFEST), "--variant", name)
        info = json.loads(next(ln for ln in log.splitlines() if ln.startswith("EQUIPMENT ")).removeprefix("EQUIPMENT "))
        glb = ROOT / info["out"]
        info["out_sha256"] = hashlib.sha256(glb.read_bytes()).hexdigest()
        info["out_kib"] = glb.stat().st_size // 1024
        if not a.no_turntable:
            _blender(HERE.parent / "render_turntable.py", "--glb", str(glb), "--out", str(SHEETS / "rebel" / f"{name}_turntable.png"))
        print(json.dumps(info))


if __name__ == "__main__":
    main()
