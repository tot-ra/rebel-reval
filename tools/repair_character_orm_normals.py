#!/usr/bin/env python3
"""Repair degenerate character ORM/normal sidecars and embedded GLB images.

Blender glTF export for this project shipped constant maps:
- normals as solid black (0,0,0)
- AO/roughness ORM as solid blue (0,0,255) => roughness G=0, metallic B=1

Custom character shaders multiply roughness_base by the map, so G/R=0 forced
mirror-smooth surfaces and MapViewLighting bloom read as a weird character glow.

This rebuilds the same procedural families as tools/hero_body_textures.py
(without Blender), writes corrected PNG sidecars, and replaces matching
embedded images inside character GLBs so a later Godot re-import cannot
revive the broken constants.
"""

from __future__ import annotations

import io
import json
import re
import struct
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SHARED = ROOT / "assets" / "characters" / "shared"
SIZE = 512

_HEIGHT_STRENGTH = {
    "skin": 1.2,
    "cloth": 2.2,
    "leather": 3.0,
    "hair": 3.0,
    "metal": 1.6,
}

_ROUGHNESS_BASE = {
    "skin": 0.72,
    "cloth": 0.88,
    "leather": 0.66,
    "hair": 0.78,
    "metal": 0.42,
}

_METALLIC_BASE = {
    "skin": 0.0,
    "cloth": 0.0,
    "leather": 0.0,
    "hair": 0.0,
    "metal": 0.95,
}


def _tileable_noise(seed: int, cells_x: int, cells_y: int, size: int = SIZE) -> np.ndarray:
    rng = np.random.default_rng(seed)
    grid = rng.random((cells_y, cells_x))
    ys = np.linspace(0.0, cells_y, size, endpoint=False)
    xs = np.linspace(0.0, cells_x, size, endpoint=False)
    y0 = np.floor(ys).astype(int) % cells_y
    x0 = np.floor(xs).astype(int) % cells_x
    y1 = (y0 + 1) % cells_y
    x1 = (x0 + 1) % cells_x
    fy = (ys - np.floor(ys))[:, None]
    fx = (xs - np.floor(xs))[None, :]
    fy = fy * fy * (3.0 - 2.0 * fy)
    fx = fx * fx * (3.0 - 2.0 * fx)
    g00 = grid[np.ix_(y0, x0)]
    g01 = grid[np.ix_(y0, x1)]
    g10 = grid[np.ix_(y1, x0)]
    g11 = grid[np.ix_(y1, x1)]
    top = g00 * (1.0 - fx) + g01 * fx
    bottom = g10 * (1.0 - fx) + g11 * fx
    return top * (1.0 - fy) + bottom * fy


def _fbm(seed: int, cells: int, octaves: int, size: int = SIZE) -> np.ndarray:
    total = np.zeros((size, size))
    amplitude = 1.0
    norm = 0.0
    for octave in range(octaves):
        cells_now = cells * (2**octave)
        total += amplitude * _tileable_noise(seed + octave, cells_now, cells_now, size)
        norm += amplitude
        amplitude *= 0.5
    return total / norm


def _normal_from_height(height: np.ndarray, strength: float) -> np.ndarray:
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5 * strength
    dy = (np.roll(height, 1, axis=0) - np.roll(height, -1, axis=0)) * 0.5 * strength
    inv = 1.0 / np.sqrt(dx * dx + dy * dy + 1.0)
    return np.stack(
        [-dx * inv * 0.5 + 0.5, dy * inv * 0.5 + 0.5, inv * 0.5 + 0.5], axis=-1
    )


def _cloth_height() -> np.ndarray:
    period = 5.0
    x = np.arange(SIZE, dtype=np.float64)[None, :]
    y = np.arange(SIZE, dtype=np.float64)[:, None]
    warp = np.abs(np.sin(np.pi * x / period))
    weft = np.abs(np.sin(np.pi * y / period))
    checker = ((np.floor(x / period) + np.floor(y / period)) % 2.0) == 0.0
    weave = np.where(checker, warp * 0.75 + weft * 0.25, weft * 0.75 + warp * 0.25)
    irregularity = _fbm(101, 48, 2)
    return weave * 0.7 + irregularity * 0.3


def _leather_height() -> np.ndarray:
    grain = _fbm(201, 20, 4)
    fine = _fbm(202, 180, 2)
    pores = _tileable_noise(203, 96, 96)
    pore_mask = np.clip((pores - 0.78) / 0.22, 0.0, 1.0)
    return grain * 0.55 + fine * 0.45 - pore_mask * 0.25


def _skin_height() -> np.ndarray:
    blotch = _fbm(301, 12, 3)
    pores = _fbm(302, 220, 2)
    return blotch * 0.35 + pores * 0.65


def _hair_height() -> np.ndarray:
    columns = _tileable_noise(401, 256, 1)
    clumps = _tileable_noise(402, 40, 1)
    x = np.arange(SIZE, dtype=np.float64)[None, :]
    strand = 0.5 + 0.5 * np.sin(2.0 * np.pi * x / 2.6 + columns * 9.0)
    strand = np.broadcast_to(strand, (SIZE, SIZE)).copy()
    clump_field = np.broadcast_to(clumps, (SIZE, SIZE))
    return strand * 0.65 + clump_field * 0.35


def _metal_height() -> np.ndarray:
    streaks = _tileable_noise(501, 6, 160)
    dents = _fbm(502, 24, 3)
    dent_mask = np.clip((dents - 0.80) / 0.20, 0.0, 1.0)
    return streaks * 0.5 + dents * 0.5 - dent_mask * 0.4


_FAMILY_HEIGHT = {
    "cloth": _cloth_height,
    "leather": _leather_height,
    "skin": _skin_height,
    "hair": _hair_height,
    "metal": _metal_height,
}


def _to_png_bytes(rgb: np.ndarray) -> bytes:
    arr = np.clip(rgb * 255.0, 0, 255).astype(np.uint8)
    image = Image.fromarray(arr, mode="RGB")
    buffer = io.BytesIO()
    image.save(buffer, format="PNG", optimize=True)
    return buffer.getvalue()


def family_maps(family: str) -> tuple[bytes, bytes]:
    """Return (normal_png, orm_png) for one material family.

    ORM follows glTF occlusion-roughness-metallic packing:
    R=AO, G=roughness, B=metallic.
    """
    height = _FAMILY_HEIGHT[family]()
    normal = _normal_from_height(height, _HEIGHT_STRENGTH[family])
    roughness = np.clip(
        _ROUGHNESS_BASE[family] + (height - 0.5) * 0.16, 0.08, 0.98
    )
    relief = np.abs(height - 0.5)
    ao = np.clip(0.98 - relief * 0.22, 0.72, 1.0)
    metallic = np.full_like(roughness, _METALLIC_BASE[family])
    orm = np.stack([ao, roughness, metallic], axis=-1)
    return _to_png_bytes(normal), _to_png_bytes(orm)


def _is_degenerate_normal(path: Path) -> bool:
    image = Image.open(path).convert("RGB").resize((8, 8))
    pixels = list(image.getdata())
    return max(max(pixel) for pixel in pixels) < 8


def _is_degenerate_orm(path: Path) -> bool:
    image = Image.open(path).convert("RGB").resize((8, 8))
    pixels = list(image.getdata())
    # Broken export was solid (0,0,255). Also treat near-zero green as unusable.
    greens = [pixel[1] for pixel in pixels]
    return max(greens) < 8


_SIDECAR_NORMAL = re.compile(r"^(?P<body>.+)_hero_tex_(?P<family>skin|cloth|leather|hair|metal)_normal$")
_SIDECAR_ORM = re.compile(
    r"^(?P<body>.+)_hero_tex_(?P<family>skin|cloth|leather|hair|metal)"
    r"_ao-hero_tex_(?P=family)_roughness$"
)


def repair_sidecars(maps: dict[str, tuple[bytes, bytes]]) -> tuple[int, int]:
    repaired_normals = 0
    repaired_orms = 0
    for path in sorted(SHARED.glob("*.png")):
        stem = path.stem
        normal_match = _SIDECAR_NORMAL.match(stem)
        if normal_match:
            family = normal_match.group("family")
            if _is_degenerate_normal(path):
                path.write_bytes(maps[family][0])
                repaired_normals += 1
            continue
        orm_match = _SIDECAR_ORM.match(stem)
        if orm_match:
            family = orm_match.group("family")
            if _is_degenerate_orm(path):
                path.write_bytes(maps[family][1])
                repaired_orms += 1
    return repaired_normals, repaired_orms


def _parse_glb(path: Path) -> tuple[dict, bytes]:
    data = path.read_bytes()
    magic, version, length = struct.unpack_from("<3I", data, 0)
    if magic != 0x46546C67:
        raise ValueError(f"not a GLB: {path}")
    offset = 12
    json_len, json_type = struct.unpack_from("<2I", data, offset)
    offset += 8
    if json_type != 0x4E4F534A:
        raise ValueError(f"missing JSON chunk: {path}")
    gltf = json.loads(data[offset : offset + json_len])
    offset += json_len
    bin_len, bin_type = struct.unpack_from("<2I", data, offset)
    offset += 8
    if bin_type != 0x004E4942:
        raise ValueError(f"missing BIN chunk: {path}")
    bin_data = bytearray(data[offset : offset + bin_len])
    return gltf, bin_data


def _write_glb(path: Path, gltf: dict, bin_data: bytes) -> None:
    json_bytes = json.dumps(gltf, separators=(",", ":"), ensure_ascii=True).encode("utf-8")
    while len(json_bytes) % 4:
        json_bytes += b" "
    bin_padded = bytearray(bin_data)
    while len(bin_padded) % 4:
        bin_padded.append(0)
    total = 12 + 8 + len(json_bytes) + 8 + len(bin_padded)
    out = bytearray()
    out += struct.pack("<3I", 0x46546C67, 2, total)
    out += struct.pack("<2I", len(json_bytes), 0x4E4F534A)
    out += json_bytes
    out += struct.pack("<2I", len(bin_padded), 0x004E4942)
    out += bin_padded
    path.write_bytes(out)


def _family_from_image_name(name: str) -> tuple[str, str] | None:
    """Return (family, kind) where kind is normal|orm."""
    if name.endswith("_normal"):
        for family in _FAMILY_HEIGHT:
            if name.endswith(f"hero_tex_{family}_normal") or name == f"hero_tex_{family}_normal":
                return family, "normal"
    marker = "_ao-hero_tex_"
    if marker in name and name.endswith("_roughness"):
        for family in _FAMILY_HEIGHT:
            token = f"hero_tex_{family}{marker}{family}_roughness"
            if name.endswith(token) or name == token:
                return family, "orm"
    return None


def repair_glb(path: Path, maps: dict[str, tuple[bytes, bytes]]) -> int:
    gltf, bin_data = _parse_glb(path)
    images = gltf.get("images", [])
    buffer_views = gltf.get("bufferViews", [])
    replaced = 0
    # Append replacement PNG bytes at the end of BIN and retarget bufferViews.
    # In-place replacement is unsafe when new PNGs are larger than the old constants.
    for image in images:
        name = str(image.get("name", ""))
        parsed = _family_from_image_name(name)
        if parsed is None:
            continue
        family, kind = parsed
        payload = maps[family][0 if kind == "normal" else 1]
        view_index = image.get("bufferView")
        if view_index is None:
            continue
        view = buffer_views[view_index]
        # Only rewrite clearly degenerate constants to keep unrelated embeds stable.
        start = int(view.get("byteOffset", 0))
        length = int(view["byteLength"])
        old = bytes(bin_data[start : start + length])
        try:
            old_image = Image.open(io.BytesIO(old)).convert("RGB").resize((8, 8))
        except OSError:
            continue
        pixels = list(old_image.getdata())
        if kind == "normal":
            degenerate = max(max(pixel) for pixel in pixels) < 8
        else:
            degenerate = max(pixel[1] for pixel in pixels) < 8
        if not degenerate:
            continue
        new_offset = len(bin_data)
        bin_data.extend(payload)
        view["byteOffset"] = new_offset
        view["byteLength"] = len(payload)
        image["mimeType"] = "image/png"
        replaced += 1
    if replaced:
        # Keep a single buffer length in sync with the expanded BIN chunk.
        buffers = gltf.setdefault("buffers", [{"byteLength": 0}])
        buffers[0]["byteLength"] = len(bin_data)
        _write_glb(path, gltf, bytes(bin_data))
    return replaced


def main() -> int:
    maps = {family: family_maps(family) for family in _FAMILY_HEIGHT}
    normals, orms = repair_sidecars(maps)
    glb_replacements = 0
    glb_files = sorted(SHARED.glob("*.glb"))
    # Also repair character-owned bodies under assets/characters/<id>/ if present.
    for glb in sorted((ROOT / "assets" / "characters").rglob("*.glb")):
        if glb not in glb_files:
            glb_files.append(glb)
    for glb in glb_files:
        glb_replacements += repair_glb(glb, maps)
    print(
        f"repaired sidecars: normals={normals} orms={orms}; "
        f"glb image replacements={glb_replacements}"
    )
    if normals == 0 and orms == 0 and glb_replacements == 0:
        print("nothing degenerate found", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
