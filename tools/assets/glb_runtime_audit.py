#!/usr/bin/env python3
"""JSON-chunk audit for runtime GLB helper leftovers.

Blender's glTF importer can fabricate a phantom ``Icosphere`` that is not in the
file. Cleanup must read the GLB JSON chunk before any import/re-export.

KayKit reuses ``Cube.NNN``, ``Plane.NNN``, and ``Cylinder.NNN``. Only the
exact primitive names ``Cube``, ``Plane``, and ``Cylinder`` are helpers.
"""

from __future__ import annotations

import argparse
import json
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
# Camera/Light leftovers keep numeric suffixes. KayKit body/prop meshes reuse
# Cube.NNN, Plane.NNN, and Cylinder.NNN, so those roots match only exactly.
ALWAYS_HELPER_ROOTS = frozenset({"icosphere", "camera", "light"})
EXACT_PRIMITIVE_HELPERS = frozenset({"cube", "plane", "cylinder"})


def is_helper_name(name: str) -> bool:
    """Return True only for authoring leftovers, not KayKit primitive meshes."""
    raw = str(name or "").strip()
    if not raw:
        return False
    lowered = raw.lower()
    root = lowered.split(".", 1)[0]
    if root in ALWAYS_HELPER_ROOTS:
        return True
    return lowered in EXACT_PRIMITIVE_HELPERS


def read_gltf_json(path: Path) -> dict:
    data = path.read_bytes()
    magic, _version, length = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF":
        raise ValueError(f"{path}: not a GLB")
    offset = 12
    while offset < length:
        chunk_len, chunk_type = struct.unpack_from("<I4s", data, offset)
        offset += 8
        chunk = data[offset : offset + chunk_len]
        offset += chunk_len
        if chunk_type == b"JSON":
            return json.loads(chunk.decode("utf-8").rstrip(" "))
    raise ValueError(f"{path}: missing JSON chunk")


def authored_helper_names(path: Path) -> list[str]:
    """Return leftover helper object names, not primitive mesh datablock names.

    Songbird legs keep mesh data named ``Cylinder`` while the node is ``Leg_L``.
    KayKit cape/shield keep ``Plane.006`` / ``Cylinder.404`` under named nodes.
    """
    gltf = read_gltf_json(path)
    nodes = list(gltf.get("nodes") or [])
    meshes = list(gltf.get("meshes") or [])
    production_mesh_indices: set[int] = set()
    found: list[str] = []
    for node in nodes:
        name = str(node.get("name") or "")
        if is_helper_name(name):
            found.append(name)
            continue
        if "mesh" in node:
            production_mesh_indices.add(int(node["mesh"]))
    for index, mesh in enumerate(meshes):
        name = str(mesh.get("name") or "")
        if is_helper_name(name) and index not in production_mesh_indices:
            found.append(name)
    return found


def _iter_manifest(manifest: Path) -> list[Path]:
    paths: list[Path] = []
    for line in manifest.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        rel = line.removeprefix("res://")
        paths.append(ROOT / rel if not Path(rel).is_absolute() else Path(rel))
    return paths


def main() -> int:
    parser = argparse.ArgumentParser(description="Fail if runtime GLBs contain authored helpers")
    parser.add_argument("paths", nargs="*", help="Repo-relative or absolute GLB paths")
    parser.add_argument("--manifest", type=Path, help="Text file with one path per line")
    args = parser.parse_args()
    targets = [ROOT / token.removeprefix("res://") for token in args.paths]
    if args.manifest is not None:
        targets.extend(_iter_manifest(args.manifest))
    if not targets:
        raise SystemExit("No GLB paths provided")
    failures: list[str] = []
    for path in targets:
        if not path.is_file():
            failures.append(f"{path}: missing")
            continue
        helpers = authored_helper_names(path)
        if helpers:
            failures.append(f"{path.relative_to(ROOT)}: {', '.join(helpers)}")
    if failures:
        print("FAIL: authored helper leftovers:")
        for line in failures:
            print(f"  - {line}")
        return 1
    print(f"OK: {len(targets)} GLBs have no authored helper meshes/nodes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
