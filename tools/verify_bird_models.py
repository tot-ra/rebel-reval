#!/usr/bin/env python3
"""Verify ambient bird poses and the complete domestic bird-gait set.

Ambient poses are checked against ``MapViewBirdSpecies`` and ``SOURCES.csv``.
Walking chicken, mallard and greylag-goose assets additionally require one
skinned mesh, weighted legs, Idle/Walk clips, ground contact and real Walk
leg deformation.

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
BIRDS_DIR = ROOT / "assets" / "birds"

KNOWN_POSES = frozenset({"standing", "perched", "gliding"})
FLAP_FRAME_COUNT = 8
MAX_TRIANGLES = 8000
MIN_LARGEST_AXIS_RATIO = 0.35
MAX_LARGEST_AXIS_RATIO = 2.6
PROFILE_LINE_RE = re.compile(
    r"^\s*SPECIES_(\w+):\s*\{.*\"scale_m\":\s*([0-9.]+)",
)
PROFILES_DECLARATION = "const PROFILES: Dictionary = {"
WING_SPAN_RE = re.compile(r"\"wing_span\":\s*([0-9.]+)")
GROUP_RE = re.compile(r"\"group\":\s*GROUP_(\w+)")
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

# These walking assets are livestock runtime models, not three new entries in the
# 30-species ambient catalog. Keep their structural contract separate.
GAIT_SPECS = {
    "chicken": {"scale_m": 0.34},
    "mallard": {"scale_m": 0.56},
    "greylag_goose": {"scale_m": 0.82},
}
GAIT_LEG_BONES = frozenset(
    {"FrontLeftLeg", "FrontRightLeg", "BackLeftLeg", "BackRightLeg"}
)
GAIT_REQUIRED_NODES = GAIT_LEG_BONES | {"Root", "Body", "AnimalMesh", "BirdRig"}
GAIT_FORBIDDEN_NODE_NAMES = frozenset({"camera", "cube", "icosphere", "light"})
GAIT_ANIMATION_NAMES = frozenset({"Idle", "Walk"})


def _catalog_entry(block: str) -> dict[str, float] | None:
    scale_match = re.search(r"\"scale_m\":\s*([0-9.]+)", block)
    if not scale_match:
        return None
    scale_m = float(scale_match.group(1))
    wing_match = WING_SPAN_RE.search(block)
    wing_span = float(wing_match.group(1)) if wing_match else 0.0
    if wing_span <= 0.0:
        group_match = GROUP_RE.search(block)
        wing_span = (
            GROUP_WING_SPAN.get(group_match.group(1).lower(), scale_m)
            if group_match
            else scale_m
        )
    return {"scale_m": scale_m, "wing_span": wing_span}


def parse_bird_catalog(path: Path = BIRD_SPECIES_GD) -> dict[str, dict[str, float]]:
    text = path.read_text(encoding="utf-8")
    catalog: dict[str, dict[str, float]] = {}

    # Current profiles are multiline. The fallback retains compatibility with
    # historical one-line fixtures used by downstream tooling.
    profile_text = (
        text[text.find(PROFILES_DECLARATION) :]
        if PROFILES_DECLARATION in text
        else ""
    )
    blocks = re.finditer(
        r"^\s*SPECIES_(\w+):\s*\n\s*\{(.*?)(?=^\s*SPECIES_\w+:|^\})",
        profile_text,
        re.MULTILINE | re.DOTALL,
    )
    for match in blocks:
        entry = _catalog_entry(match.group(2))
        if entry is not None:
            catalog[match.group(1).lower()] = entry

    if not catalog:
        for line in text.splitlines():
            match = PROFILE_LINE_RE.match(line)
            if not match:
                continue
            entry = _catalog_entry(line)
            if entry is not None:
                catalog[match.group(1).lower()] = entry

    if len(catalog) != 30:
        raise ValueError(f"expected 30 catalog species, parsed {len(catalog)}")
    return catalog


def _component_format(component_type: int) -> tuple[str, int]:
    formats = {
        5120: ("b", 1),
        5121: ("B", 1),
        5122: ("h", 2),
        5123: ("H", 2),
        5125: ("I", 4),
        5126: ("f", 4),
    }
    if component_type not in formats:
        raise ValueError(f"unsupported component type {component_type}")
    return formats[component_type]


def _read_accessor(
    document: dict, payload: bytes, bin_start: int, accessor_index: int
) -> list[float]:
    accessor = document["accessors"][accessor_index]
    view = document["bufferViews"][accessor["bufferView"]]
    component_format, component_size = _component_format(accessor["componentType"])
    component_count = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[accessor["type"]]
    byte_offset = bin_start + view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    byte_stride = view.get("byteStride", component_size * component_count)
    values: list[float] = []
    for index in range(accessor["count"]):
        values.extend(
            struct.unpack_from(
                "<" + component_format * component_count,
                payload,
                byte_offset + index * byte_stride,
            )
        )
    return values


def _load_glb_document(path: Path) -> tuple[dict, bytes, int]:
    payload = path.read_bytes()
    if payload[:4] != b"glTF" or len(payload) < 20:
        raise ValueError(f"{path}: not a complete binary glTF file")
    json_length = struct.unpack_from("<I", payload, 12)[0]
    json_end = 20 + json_length
    if len(payload) < json_end + 8:
        raise ValueError(f"{path}: truncated JSON chunk")
    document = json.loads(payload[20:json_end])
    bin_length = struct.unpack_from("<I", payload, json_end)[0]
    bin_start = json_end + 8
    if len(payload) < bin_start + bin_length:
        raise ValueError(f"{path}: truncated BIN chunk")
    return document, payload, bin_start


def inspect_glb(path: Path) -> dict[str, float | int]:
    document, payload, bin_start = _load_glb_document(path)
    triangles = 0
    min_v = [math.inf, math.inf, math.inf]
    max_v = [-math.inf, -math.inf, -math.inf]
    for mesh in document.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            if "indices" in primitive:
                triangles += document["accessors"][primitive["indices"]]["count"] // 3
            position_index = primitive.get("attributes", {}).get("POSITION")
            if position_index is None:
                continue
            positions = _read_accessor(document, payload, bin_start, position_index)
            for index in range(0, len(positions), 3):
                for axis in range(3):
                    min_v[axis] = min(min_v[axis], positions[index + axis])
                    max_v[axis] = max(max_v[axis], positions[index + axis])
    dimensions = [max_v[index] - min_v[index] for index in range(3)]
    return {
        "triangles": triangles,
        "dimensions_m": dimensions,
        "largest_axis_m": max(dimensions),
    }


def _walk_deforms_leg(document: dict, payload: bytes, bin_start: int) -> bool:
    node_names = [node.get("name", "") for node in document.get("nodes", [])]
    for animation in document.get("animations", []):
        if animation.get("name") != "Walk":
            continue
        for channel in animation.get("channels", []):
            target = channel.get("target", {})
            node_index = target.get("node", -1)
            if node_index < 0 or node_names[node_index] not in GAIT_LEG_BONES:
                continue
            path = target.get("path")
            if path not in {"rotation", "translation"}:
                continue
            sampler = animation["samplers"][channel["sampler"]]
            accessor = document["accessors"][sampler["output"]]
            width = 4 if path == "rotation" else 3
            values = _read_accessor(document, payload, bin_start, sampler["output"])
            if accessor["count"] < 2:
                continue
            first = values[:width]
            if any(
                abs(values[offset + axis] - first[axis]) > 0.02
                for offset in range(width, len(values), width)
                for axis in range(width)
            ):
                return True
    return False


def inspect_gait_glb(path: Path, *, expected_scale_m: float) -> list[str]:
    """Return structural, scale, grounding and deformation violations."""
    try:
        return _inspect_gait_glb(path, expected_scale_m=expected_scale_m)
    except (AttributeError, LookupError, TypeError, ValueError, struct.error) as exc:
        return [f"{path}: malformed GLB: {exc}"]


def _inspect_gait_glb(path: Path, *, expected_scale_m: float) -> list[str]:
    """Run gait validation after the public malformed-document guard."""
    try:
        document, payload, bin_start = _load_glb_document(path)
    except (OSError, ValueError, json.JSONDecodeError, struct.error) as exc:
        return [str(exc)]

    errors: list[str] = []
    nodes = document.get("nodes", [])
    node_names = [node.get("name", "") for node in nodes]
    meshes = document.get("meshes", [])
    skins = document.get("skins", [])
    animations = document.get("animations", [])

    if len(meshes) != 1:
        errors.append(f"{path}: gait GLB must contain exactly one mesh")
    if len(skins) != 1:
        errors.append(f"{path}: gait GLB must contain exactly one skin")
    if {animation.get("name") for animation in animations} != GAIT_ANIMATION_NAMES:
        errors.append(f"{path}: gait GLB must contain exactly Idle and Walk")
    if set(node_names) != GAIT_REQUIRED_NODES:
        errors.append(f"{path}: nodes must be exactly the authored gait node set")
    forbidden = sorted(
        name for name in node_names if name.lower() in GAIT_FORBIDDEN_NODE_NAMES
    )
    if forbidden:
        errors.append(f"{path}: helper nodes exported: {', '.join(forbidden)}")

    mesh_nodes = [node for node in nodes if "mesh" in node]
    if len(mesh_nodes) != 1 or mesh_nodes[0].get("name") != "AnimalMesh":
        errors.append(f"{path}: production mesh must be named AnimalMesh")
    if mesh_nodes and mesh_nodes[0].get("skin") != 0:
        errors.append(f"{path}: AnimalMesh must reference skin 0")
    if skins and len(skins[0].get("joints", [])) != 6:
        errors.append(f"{path}: gait skin must contain six authored joints")

    triangles = 0
    min_v = [math.inf, math.inf, math.inf]
    max_v = [-math.inf, -math.inf, -math.inf]
    weighted_joints: set[str] = set()
    if meshes:
        for primitive in meshes[0].get("primitives", []):
            attributes = primitive.get("attributes", {})
            if "JOINTS_0" not in attributes or "WEIGHTS_0" not in attributes:
                errors.append(f"{path}: every production primitive must be skinned")
            if "indices" in primitive:
                triangles += document["accessors"][primitive["indices"]]["count"] // 3
            if "POSITION" in attributes:
                positions = _read_accessor(
                    document, payload, bin_start, attributes["POSITION"]
                )
                for index in range(0, len(positions), 3):
                    for axis in range(3):
                        min_v[axis] = min(min_v[axis], positions[index + axis])
                        max_v[axis] = max(max_v[axis], positions[index + axis])
            if skins and "JOINTS_0" in attributes and "WEIGHTS_0" in attributes:
                joints = _read_accessor(
                    document, payload, bin_start, attributes["JOINTS_0"]
                )
                weights = _read_accessor(
                    document, payload, bin_start, attributes["WEIGHTS_0"]
                )
                joint_names = [
                    nodes[index].get("name", "")
                    for index in skins[0].get("joints", [])
                ]
                for index, weight in enumerate(weights):
                    if weight > 0.01:
                        weighted_joints.add(joint_names[int(joints[index])])

    if triangles <= 0 or triangles > MAX_TRIANGLES:
        errors.append(f"{path}: triangle budget invalid ({triangles})")
    if not GAIT_LEG_BONES.issubset(weighted_joints):
        missing = sorted(GAIT_LEG_BONES - weighted_joints)
        errors.append(f"{path}: leg bones have no mesh weights: {', '.join(missing)}")
    dimensions = [max_v[index] - min_v[index] for index in range(3)]
    if not all(math.isfinite(value) for value in dimensions) or abs(min_v[1]) > 0.001:
        errors.append(f"{path}: feet must be grounded at y=0 (min_y={min_v[1]:.4f})")
    largest_axis = max(dimensions)
    if largest_axis < expected_scale_m * 0.35 or largest_axis > expected_scale_m * 3.5:
        errors.append(
            f"{path}: largest axis {largest_axis:.3f} m conflicts with "
            f"scale_m={expected_scale_m}"
        )
    if not document.get("materials"):
        errors.append(f"{path}: gait GLB has no materials")
    if not _walk_deforms_leg(document, payload, bin_start):
        errors.append(f"{path}: Walk does not deform a weight-bearing leg")
    return errors


def verify_gait_assets(
    *, birds_dir: Path = BIRDS_DIR, require_all: bool = True
) -> list[str]:
    errors: list[str] = []
    for species, spec in GAIT_SPECS.items():
        path = birds_dir / species / "walking.glb"
        if not path.is_file():
            if require_all:
                errors.append(f"missing domestic bird gait asset: {path}")
            continue
        errors.extend(inspect_gait_glb(path, expected_scale_m=spec["scale_m"]))
    return errors


def _asset_id(species: str, pose_name: str) -> str:
    return f"assets.birds.{species}.{pose_name}"


def _accepted_pose_name(file_name: str) -> str | None:
    if file_name in {f"{pose}.glb" for pose in KNOWN_POSES}:
        return file_name.removesuffix(".glb")
    match = re.fullmatch(r"gliding_(\d{2})\.glb", file_name)
    return f"gliding_{match.group(1)}" if match else None


def _read_sources(root: Path) -> set[str]:
    with (root / "assets" / "SOURCES.csv").open(
        newline="", encoding="utf-8"
    ) as handle:
        return {row["asset_id"] for row in csv.DictReader(handle)}


def verify(*, birds_dir: Path = BIRDS_DIR, root: Path = ROOT) -> list[str]:
    errors = verify_gait_assets(birds_dir=birds_dir, require_all=False)
    catalog = parse_bird_catalog()
    sources = _read_sources(root)
    if not birds_dir.is_dir():
        return [f"missing birds root directory: {birds_dir}"]

    for species_dir in sorted(path for path in birds_dir.iterdir() if path.is_dir()):
        species = species_dir.name
        glb_files = sorted(
            path.name for path in species_dir.glob("*.glb") if path.name != "walking.glb"
        )
        if species not in catalog:
            if species not in GAIT_SPECS or glb_files:
                errors.append(f"{species_dir}: unknown species folder")
            continue

        flap_frames = [name for name in glb_files if name.startswith("gliding_")]
        if flap_frames and len(flap_frames) != FLAP_FRAME_COUNT:
            errors.append(
                f"{species}: partial flap cycle "
                f"({len(flap_frames)}/{FLAP_FRAME_COUNT} gliding_XX.glb files)"
            )
        for file_name in glb_files:
            pose_name = _accepted_pose_name(file_name)
            if pose_name is None:
                errors.append(f"{species_dir / file_name}: unsupported bird GLB name")
                continue
            glb_path = species_dir / file_name
            try:
                metrics = inspect_glb(glb_path)
            except (OSError, KeyError, IndexError, TypeError, struct.error) as exc:
                errors.append(f"{glb_path}: malformed GLB: {exc}")
                continue
            except ValueError as exc:
                errors.append(str(exc))
                continue
            triangles = int(metrics["triangles"])
            if triangles <= 0 or triangles > MAX_TRIANGLES:
                errors.append(f"{glb_path}: invalid triangle count {triangles}")
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
                    f"[{lower:.3f}, {upper:.3f}]"
                )
            if _asset_id(species, pose_name) not in sources:
                errors.append(f"{glb_path}: missing SOURCES.csv row")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--birds-dir", type=Path, default=BIRDS_DIR)
    args = parser.parse_args()
    try:
        errors = verify(birds_dir=args.birds_dir)
        errors.extend(verify_gait_assets(birds_dir=args.birds_dir, require_all=True))
        errors = list(dict.fromkeys(errors))
    except ValueError as exc:
        print(f"bird model verification failed: {exc}", file=sys.stderr)
        return 1
    if errors:
        print("bird model verification failed:")
        for error in errors:
            print(f"  - {error}")
        return 1
    glb_count = sum(1 for _ in args.birds_dir.rglob("*.glb"))
    print(
        "bird model verification passed "
        f"(catalog=30; gait_models=3; authored_glbs={glb_count})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
