#!/usr/bin/env python3
"""Verify authored bird GLBs under ``assets/birds/``.

Checks catalog alignment, pose naming, triangle budget, metric scale against
``MapViewBirdSpecies.scale_m``, and ``assets/SOURCES.csv`` provenance rows.
With zero authored GLBs the verifier still passes after validating the catalog
contract and birds root directory.

Usage:
    python3 tools/verify_bird_models.py
    python3 tools/verify_bird_models.py --birds-dir assets/birds
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import re
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BIRD_SPECIES_GD = ROOT / "scripts" / "map" / "view3d" / "map_view_bird_species.gd"
SOURCES_CSV = ROOT / "assets" / "SOURCES.csv"
BIRDS_DIR = ROOT / "assets" / "birds"

KNOWN_POSES = frozenset({"standing", "perched", "gliding"})
FLAP_FRAME_COUNT = 8
MAX_TRIANGLES = 8000
MIN_LARGEST_AXIS_RATIO = 0.35
MAX_LARGEST_AXIS_RATIO = 2.6

PROFILE_LINE_RE = re.compile(
    r"^\s*SPECIES_(\w+):\s*\{.*\"scale_m\":\s*([0-9.]+)",
)
WING_SPAN_RE = re.compile(r"\"wing_span\":\s*([0-9.]+)")
GROUP_WING_SPAN = {
    "gull": 1.20,
    "tern": 1.32,
    "waterfowl": 1.10,
    "wader": 1.02,
    "raptor": 1.42,
    "owl": 1.14,
    "corvid": 1.03,
    "swallow": 0.94,
    "songbird": 0.68,
    "woodpecker": 0.76,
}
GROUP_RE = re.compile(r"\"group\":\s*GROUP_(\w+)")


def parse_bird_catalog(path: Path = BIRD_SPECIES_GD) -> dict[str, dict[str, float]]:
    text = path.read_text(encoding="utf-8")
    catalog: dict[str, dict[str, float]] = {}
    for line in text.splitlines():
        match = PROFILE_LINE_RE.match(line)
        if not match:
            continue
        species = match.group(1).lower()
        scale_m = float(match.group(2))
        wing_match = WING_SPAN_RE.search(line)
        wing_span = float(wing_match.group(1)) if wing_match else 0.0
        if wing_span <= 0.0:
            group_match = GROUP_RE.search(line)
            if group_match:
                wing_span = GROUP_WING_SPAN.get(group_match.group(1).lower(), scale_m)
            else:
                wing_span = scale_m
        catalog[species] = {
            "scale_m": scale_m,
            "wing_span": wing_span,
        }
    if len(catalog) != 30:
        raise ValueError(f"expected 30 catalog species, parsed {len(catalog)}")
    return catalog


def _component_format(component_type: int) -> tuple[str, int]:
    formats = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2), 5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
    if component_type not in formats:
        raise ValueError(f"unsupported component type {component_type}")
    return formats[component_type]


def _read_accessor(document: dict, payload: bytes, bin_start: int, accessor_index: int) -> list[float]:
    accessor = document["accessors"][accessor_index]
    view = document["bufferViews"][accessor["bufferView"]]
    component_format, component_size = _component_format(accessor["componentType"])
    byte_offset = bin_start + view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    type_count = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[accessor["type"]]
    values = struct.unpack_from(
        "<" + component_format * accessor["count"] * type_count,
        payload,
        byte_offset,
    )
    return list(values)


def inspect_glb(path: Path) -> dict[str, float | int]:
    payload = path.read_bytes()
    if payload[:4] != b"glTF":
        raise ValueError(f"{path}: not a binary glTF file")
    json_length = struct.unpack_from("<I", payload, 12)[0]
    document = json.loads(payload[20 : 20 + json_length])
    bin_header = 20 + json_length
    bin_length = struct.unpack_from("<I", payload, bin_header)[0]
    bin_start = bin_header + 8
    if len(payload) < bin_start + bin_length:
        raise ValueError(f"{path}: truncated BIN chunk")

    triangles = 0
    min_v = [math.inf, math.inf, math.inf]
    max_v = [-math.inf, -math.inf, -math.inf]
    for mesh in document.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            if "indices" in primitive:
                accessor = document["accessors"][primitive["indices"]]
                triangles += accessor["count"] // 3
            position_index = primitive.get("attributes", {}).get("POSITION")
            if position_index is None:
                continue
            positions = _read_accessor(document, payload, bin_start, position_index)
            for index in range(0, len(positions), 3):
                x, y, z = positions[index : index + 3]
                min_v[0] = min(min_v[0], x)
                min_v[1] = min(min_v[1], y)
                min_v[2] = min(min_v[2], z)
                max_v[0] = max(max_v[0], x)
                max_v[1] = max(max_v[1], y)
                max_v[2] = max(max_v[2], z)

    dimensions = [max_v[i] - min_v[i] for i in range(3)]
    largest_axis = max(dimensions)
    return {
        "triangles": triangles,
        "dimensions_m": dimensions,
        "largest_axis_m": largest_axis,
    }


def _asset_id(species: str, pose_name: str) -> str:
    return f"assets.birds.{species}.{pose_name}"


def _accepted_pose_name(file_name: str) -> str | None:
    if file_name in {f"{pose}.glb" for pose in KNOWN_POSES}:
        return file_name.removesuffix(".glb")
    match = re.fullmatch(r"gliding_(\d{2})\.glb", file_name)
    if match:
        return f"gliding_{match.group(1)}"
    return None


def _read_sources(root: Path) -> set[str]:
    path = root / "assets" / "SOURCES.csv"
    with path.open(newline="", encoding="utf-8") as handle:
        return {row["asset_id"] for row in csv.DictReader(handle)}


def verify(*, birds_dir: Path = BIRDS_DIR, root: Path = ROOT) -> list[str]:
    errors: list[str] = []
    catalog = parse_bird_catalog()
    sources = _read_sources(root)

    if not birds_dir.is_dir():
        errors.append(f"missing birds root directory: {birds_dir}")
        return errors

    authored_count = 0
    for species_dir in sorted(path for path in birds_dir.iterdir() if path.is_dir()):
        species = species_dir.name
        if species not in catalog:
            errors.append(f"{species_dir}: unknown species folder")
            continue

        glb_files = sorted(path.name for path in species_dir.glob("*.glb"))
        flap_frames = [name for name in glb_files if name.startswith("gliding_")]
        if flap_frames and len(flap_frames) != FLAP_FRAME_COUNT:
            errors.append(
                f"{species}: partial flap cycle ({len(flap_frames)}/{FLAP_FRAME_COUNT} gliding_XX.glb files)"
            )

        for file_name in glb_files:
            pose_name = _accepted_pose_name(file_name)
            if pose_name is None:
                errors.append(f"{species_dir / file_name}: unsupported bird GLB name")
                continue

            authored_count += 1
            glb_path = species_dir / file_name
            try:
                metrics = inspect_glb(glb_path)
            except ValueError as exc:
                errors.append(str(exc))
                continue

            triangles = int(metrics["triangles"])
            if triangles <= 0:
                errors.append(f"{glb_path}: mesh has no triangles")
            elif triangles > MAX_TRIANGLES:
                errors.append(f"{glb_path}: triangle budget exceeded ({triangles}>{MAX_TRIANGLES})")

            profile = catalog[species]
            largest_axis = float(metrics["largest_axis_m"])
            expected_largest = max(
                profile["scale_m"] * 1.2,
                profile["wing_span"] * profile["scale_m"] / 0.52,
            )
            lower = profile["scale_m"] * MIN_LARGEST_AXIS_RATIO
            upper = expected_largest * MAX_LARGEST_AXIS_RATIO
            if largest_axis < lower or largest_axis > upper:
                errors.append(
                    f"{glb_path}: largest axis {largest_axis:.3f} m outside "
                    f"[{lower:.3f}, {upper:.3f}] for scale_m={profile['scale_m']}"
                )

            asset_id = _asset_id(species, pose_name)
            if asset_id not in sources:
                errors.append(f"{glb_path}: missing SOURCES.csv row {asset_id}")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--birds-dir", type=Path, default=BIRDS_DIR)
    args = parser.parse_args()

    try:
        errors = verify(birds_dir=args.birds_dir)
    except ValueError as exc:
        print(f"bird model verification failed: {exc}", file=sys.stderr)
        return 1

    if errors:
        print("bird model verification failed:")
        for error in errors:
            print(f"  - {error}")
        return 1

    glb_count = sum(1 for _ in args.birds_dir.rglob("*.glb")) if args.birds_dir.is_dir() else 0
    print(
        f"bird model verification passed "
        f"(catalog=30; authored_glbs={glb_count}; birds dir {args.birds_dir})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
