#!/usr/bin/env python3
"""Fail if character distance-LOD GLBs still carry unmaterialed helper meshes.

Stale Icosphere leftovers imported as Godot's default white StandardMaterial3D
and showed up as bright blobs on distant NPCs. Run after regenerating LODs:

    python3 tools/verify_character_lod_materials.py
"""

from __future__ import annotations

import json
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHARED = ROOT / "assets" / "characters" / "shared"


def _read_gltf_json(path: Path) -> dict:
    data = path.read_bytes()
    magic, _version, length = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF":
        raise ValueError(f"{path.name}: not a GLB")
    offset = 12
    while offset < length:
        chunk_len, chunk_type = struct.unpack_from("<I4s", data, offset)
        offset += 8
        chunk = data[offset : offset + chunk_len]
        offset += chunk_len
        if chunk_type == b"JSON":
            return json.loads(chunk.decode("utf-8").rstrip(" "))
    raise ValueError(f"{path.name}: missing JSON chunk")


def main() -> int:
    lod_paths = sorted(SHARED.glob("*_lod*.glb"))
    if not lod_paths:
        print("FAIL: no character LOD GLBs under assets/characters/shared/")
        return 1
    failures: list[str] = []
    for path in lod_paths:
        gltf = _read_gltf_json(path)
        for mesh in gltf.get("meshes") or []:
            name = str(mesh.get("name") or "?")
            if name.startswith("Icosphere"):
                failures.append(f"{path.name}: helper mesh {name}")
                continue
            for prim in mesh.get("primitives") or []:
                if "material" not in prim:
                    failures.append(f"{path.name}: {name} primitive has no material")
    if failures:
        print("FAIL: character LOD meshes still default white:")
        for line in failures:
            print(f"  - {line}")
        return 1
    print(f"OK: {len(lod_paths)} character LOD GLBs have authored materials only")
    return 0


if __name__ == "__main__":
    sys.exit(main())
