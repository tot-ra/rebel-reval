#!/usr/bin/env python3
"""Bake adult heroic proportions into KayKit body meshes (P0-037).

The KayKit Adventurers rig is a technical proof with chibi geometry. This script
deforms only the Barbarian body-part vertices while leaving the skeleton,
skin weights, animations, and accessory nodes untouched so SharedCharacterRig
keeps the same API and clip names.
"""

from __future__ import annotations

import copy
import json
import struct
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/characters/shared/kaykit_barbarian.glb"
OUTPUT = ROOT / "assets/characters/shared/heroic_humanoid.glb"

BODY_PARTS = {
    "Barbarian_Head": {"pivot": np.array([0.0, 1.134, 0.0]), "scale": np.array([0.62, 0.62, 0.62])},
    "Barbarian_Body": {"pivot": np.array([0.0, 0.376, 0.0]), "scale": np.array([1.02, 0.86, 1.0])},
    "Barbarian_ArmLeft": {"pivot": np.array([0.513, 0.975, 0.0]), "scale": np.array([1.0, 1.22, 1.0])},
    "Barbarian_ArmRight": {"pivot": np.array([-0.513, 0.975, 0.0]), "scale": np.array([1.0, 1.22, 1.0])},
    "Barbarian_LegLeft": {"pivot": np.array([0.168, 0.0, 0.0]), "scale": np.array([0.96, 1.42, 0.96])},
    "Barbarian_LegRight": {"pivot": np.array([-0.168, 0.0, 0.0]), "scale": np.array([0.96, 1.42, 0.96])},
}


def _load_glb(path: Path) -> tuple[dict, bytes]:
    data = path.read_bytes()
    offset = 12
    json_chunk = None
    bin_chunk = b""
    while offset < len(data):
        chunk_len, chunk_type = struct.unpack_from("<II", data, offset)
        offset += 8
        chunk_data = data[offset : offset + chunk_len]
        offset += chunk_len
        if chunk_type == 0x4E4F534A:
            json_chunk = json.loads(chunk_data)
        elif chunk_type == 0x004E4942:
            bin_chunk = chunk_data
    if json_chunk is None:
        raise ValueError(f"{path} has no JSON chunk")
    return json_chunk, bin_chunk


def _write_glb(gltf: dict, bin_chunk: bytearray) -> bytes:
    json_bytes = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    json_pad = (4 - len(json_bytes) % 4) % 4
    json_bytes += b" " * json_pad
    bin_pad = (4 - len(bin_chunk) % 4) % 4
    bin_chunk.extend(b"\x00" * bin_pad)
    total = 12 + 8 + len(json_bytes) + 8 + len(bin_chunk)
    out = bytearray()
    out.extend(struct.pack("<4sII", b"glTF", 2, total))
    out.extend(struct.pack("<II", len(json_bytes), 0x4E4F534A))
    out.extend(json_bytes)
    out.extend(struct.pack("<II", len(bin_chunk), 0x004E4942))
    out.extend(bin_chunk)
    return bytes(out)


def _component_dtype(component_type: int) -> np.dtype:
    return {
        5120: np.int8,
        5121: np.uint8,
        5122: np.int16,
        5123: np.uint16,
        5125: np.uint32,
        5126: np.float32,
    }[component_type]


def _num_components(accessor_type: str) -> int:
    return {
        "SCALAR": 1,
        "VEC2": 2,
        "VEC3": 3,
        "VEC4": 4,
        "MAT2": 4,
        "MAT3": 9,
        "MAT4": 16,
    }[accessor_type]


def _read_accessor(gltf: dict, bin_chunk: bytes, accessor_index: int) -> np.ndarray:
    accessor = gltf["accessors"][accessor_index]
    view = gltf["bufferViews"][accessor["bufferView"]]
    dtype = _component_dtype(accessor["componentType"])
    ncomp = _num_components(accessor["type"])
    start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    count = accessor["count"]
    stride = view.get("byteStride", ncomp * dtype().itemsize)
    arr = np.frombuffer(
        bin_chunk,
        dtype=dtype,
        count=count * ncomp,
        offset=start,
    ).reshape(count, ncomp)
    if stride != ncomp * dtype().itemsize:
        # Packed layout with custom stride is not used in the KayKit export.
        raise ValueError("unsupported buffer stride")
    return arr.copy()


def _write_accessor(
    gltf: dict,
    bin_chunk: bytearray,
    accessor_index: int,
    values: np.ndarray,
) -> None:
    accessor = gltf["accessors"][accessor_index]
    view = gltf["bufferViews"][accessor["bufferView"]]
    dtype = _component_dtype(accessor["componentType"])
    ncomp = _num_components(accessor["type"])
    start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    flat = np.asarray(values, dtype=dtype).reshape(-1)
    bin_chunk[start : start + flat.nbytes] = flat.tobytes()
    accessor["min"] = values.min(axis=0).tolist()
    accessor["max"] = values.max(axis=0).tolist()


def _transform_positions(positions: np.ndarray, pivot: np.ndarray, scale: np.ndarray) -> np.ndarray:
    relative = positions - pivot
    return pivot + relative * scale


def _mesh_bounds(gltf: dict, bin_chunk: bytes, mesh_index: int) -> tuple[np.ndarray, np.ndarray]:
    prim = gltf["meshes"][mesh_index]["primitives"][0]
    pos = _read_accessor(gltf, bin_chunk, prim["attributes"]["POSITION"])
    return pos.min(axis=0), pos.max(axis=0)


def build() -> None:
    gltf, bin_data = _load_glb(SOURCE)
    bin_chunk = bytearray(bin_data)
    nodes = gltf["nodes"]

    for node in nodes:
        name = node.get("name", "")
        if name not in BODY_PARTS or "mesh" not in node:
            continue
        spec = BODY_PARTS[name]
        mesh_index = node["mesh"]
        prim = gltf["meshes"][mesh_index]["primitives"][0]
        pos_index = prim["attributes"]["POSITION"]
        positions = _read_accessor(gltf, bin_chunk, pos_index)
        deformed = _transform_positions(positions, spec["pivot"], spec["scale"])
        _write_accessor(gltf, bin_chunk, pos_index, deformed)

    # Recompute overall body height for the scale constant in shared_character_rig.tscn.
    ymin = float("inf")
    ymax = float("-inf")
    for node in nodes:
        name = node.get("name", "")
        if not name.startswith("Barbarian_") or "mesh" not in node:
            continue
        lo, hi = _mesh_bounds(gltf, bytes(bin_chunk), node["mesh"])
        ymin = min(ymin, lo[1])
        ymax = max(ymax, hi[1])

    height = ymax - ymin
    scale_for_two_units = 2.0 / height if height > 0 else 1.0
    print(f"Deformed body height: {height:.4f} units")
    print(f"Suggested Model scale for 2.0 world units: {scale_for_two_units:.4f}")

    OUTPUT.write_bytes(_write_glb(gltf, bin_chunk))
    print(f"Wrote {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    try:
        build()
    except Exception as exc:  # pragma: no cover - CLI surface
        print(f"error: {exc}", file=sys.stderr)
        sys.exit(1)
