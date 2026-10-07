#!/usr/bin/env python3
"""Verify the checked-in reval_outdoor world-layout manifest (WB-08 / R-980).

The manifest is built by ``tools/build_world_layout.gd``. This check runs without
Godot and recomputes what it can independently:

* the sha256 fingerprint over the canonical JSON body;
* membership equals the "Streamed" table in docs/SEAMLESS_STREAMING_PLAN.md;
* every package path exists and its sha256 matches (a stale manifest fails);
* bounds are origin + size, half-open, and never overlap by area;
* the placement tree is rooted at ``root_location_id`` and cycle-free;
* every seam joins two members on opposite, touching edges, and its status is
  ``blocked`` exactly when it carries diagnostics;
* from the .rrmap sources: every reciprocal edge-aligned transition pair between
  members is a manifest seam, and no ``alignment=travel`` transition or
  transition leaving the group is a seam (the travel boundary).

Usage: python3 tools/verify_world_layout.py [--manifest PATH] [--root PATH]
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = "content/world/reval_outdoor_layout.json"
PLAN = "docs/SEAMLESS_STREAMING_PLAN.md"
SCHEMA = "rr.world_layout.v1"
OPPOSITE = {"north": "south", "south": "north", "east": "west", "west": "east"}


def fingerprint(manifest: dict) -> str:
    body = {key: value for key, value in manifest.items() if key != "fingerprint"}
    canonical = json.dumps(body, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def plan_members(plan_text: str) -> list[str]:
    # Only the reval_outdoor table: the reval_hinterland table (ADR 0027) is a
    # separate world group, so stop at the next heading.
    match = re.search(r"### Streamed: `world_group_id = reval_outdoor`.*?(?=^### )", plan_text, re.S | re.M)
    if not match:
        return []
    return re.findall(r"^\|\s*`([^`]+)`\s*\|", match.group(0), re.M)


def res_path(root: Path, package_path: str) -> Path:
    return root / package_path.removeprefix("res://")


def parse_transitions(text: str) -> list[dict]:
    transitions = []
    for line in text.splitlines():
        parts = line.split()
        if len(parts) < 6 or parts[0] != "transition":
            continue
        record = {"id": parts[1]}
        for token in parts[6:]:
            if "=" in token:
                key, value = token.split("=", 1)
                record[key] = value
        transitions.append(record)
    return transitions


def _overlap_area(first: list[int], second: list[int]) -> int:
    width = min(first[2], second[2]) - max(first[0], second[0])
    height = min(first[3], second[3]) - max(first[1], second[1])
    return width * height if width > 0 and height > 0 else 0


def _touches(first: list[int], second: list[int], side: str) -> bool:
    """True when `second` sits across `side` of `first` with a shared edge span."""
    if side == "east":
        return first[2] == second[0] and min(first[3], second[3]) > max(first[1], second[1])
    if side == "west":
        return first[0] == second[2] and min(first[3], second[3]) > max(first[1], second[1])
    if side == "south":
        return first[3] == second[1] and min(first[2], second[2]) > max(first[0], second[0])
    if side == "north":
        return first[1] == second[3] and min(first[2], second[2]) > max(first[0], second[0])
    return False


def verify(manifest: dict, root: Path = ROOT, check_sources: bool = True) -> list[str]:
    errors: list[str] = []
    if manifest.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    if manifest.get("fingerprint") != fingerprint(manifest):
        errors.append("fingerprint does not match the manifest body")
    if not manifest.get("valid") or manifest.get("errors"):
        errors.append(f"manifest was built with errors: {manifest.get('errors')}")
    if manifest.get("unplaced"):
        errors.append(f"unplaced locations: {manifest['unplaced']}")

    locations = {entry["location_id"]: entry for entry in manifest.get("locations", [])}
    plan_path = root / PLAN
    if plan_path.exists():
        expected = plan_members(plan_path.read_text(encoding="utf-8"))
        if sorted(expected) != sorted(locations):
            errors.append(
                f"members {sorted(locations)} differ from {PLAN} streamed table {sorted(expected)}"
            )

    for location_id, entry in sorted(locations.items()):
        origin, size = entry["origin_cell"], entry["size_cells"]
        bounds = [origin[0], origin[1], origin[0] + size[0], origin[1] + size[1]]
        if entry["global_bounds_cells"] != bounds:
            errors.append(f"{location_id} global_bounds_cells is not origin + size")
        if entry.get("cell_size") != manifest.get("cell_size"):
            errors.append(f"{location_id} cell_size differs from the group")
        if check_sources:
            source = res_path(root, entry.get("package_path", ""))
            if not entry.get("package_path") or not source.exists():
                errors.append(f"{location_id} package {entry.get('package_path')!r} is missing")
            elif hashlib.sha256(source.read_bytes()).hexdigest() != entry.get("source_sha256"):
                errors.append(
                    f"{location_id} source changed since the manifest was built; "
                    "rerun tools/build_world_layout.gd"
                )

    ids = sorted(locations)
    for index, first in enumerate(ids):
        for second in ids[index + 1 :]:
            if _overlap_area(
                locations[first]["global_bounds_cells"], locations[second]["global_bounds_cells"]
            ):
                errors.append(f"{first} and {second} overlap in global bounds")

    root_id = manifest.get("root_location_id", "")
    for location_id in ids:
        cursor, seen = location_id, set()
        while cursor and locations.get(cursor, {}).get("placement_parent"):
            if cursor in seen:
                errors.append(f"placement cycle through {location_id}")
                break
            seen.add(cursor)
            cursor = locations[cursor]["placement_parent"]
            if cursor not in locations:
                errors.append(f"{location_id} placement parent {cursor} is not a location")
                break
        else:
            if cursor != root_id:
                errors.append(f"{location_id} placement tree does not reach {root_id}")

    seam_keys = set()
    for seam in manifest.get("seams", []):
        base, neighbor = seam["base_map_id"], seam["neighbor_map_id"]
        if base not in locations or neighbor not in locations:
            errors.append(f"seam {seam['id']} reaches outside the group")
            continue
        if OPPOSITE.get(seam["base_side"]) != seam["neighbor_side"]:
            errors.append(f"seam {seam['id']} sides are not opposite")
        if not _touches(
            locations[base]["global_bounds_cells"],
            locations[neighbor]["global_bounds_cells"],
            seam["base_side"],
        ):
            errors.append(f"seam {seam['id']} does not join touching edges")
        blocked = bool(seam.get("diagnostics"))
        if (seam.get("status") == "blocked") != blocked:
            errors.append(f"seam {seam['id']} status disagrees with its diagnostics")
        if (seam["base_span_cells"] != seam["neighbor_span_cells"]) and not blocked:
            errors.append(f"seam {seam['id']} has mismatched spans but streams")
        seam_keys.add((base, seam["base_transition_id"], neighbor, seam["neighbor_transition_id"]))

    if check_sources:
        errors.extend(_verify_rrmap_seams(manifest, locations, seam_keys, root))
    return errors


def _verify_rrmap_seams(
    manifest: dict, locations: dict, seam_keys: set, root: Path
) -> list[str]:
    errors: list[str] = []
    scene_of = {entry["scene_id"]: location_id for location_id, entry in locations.items()}
    transitions = {}
    for location_id, entry in locations.items():
        source = res_path(root, entry.get("package_path", ""))
        if source.exists():
            transitions[location_id] = parse_transitions(source.read_text(encoding="utf-8"))

    expected = set()
    for base, base_list in transitions.items():
        for first in base_list:
            neighbor = scene_of.get(first.get("to", ""))
            if neighbor is None or neighbor == base:
                continue
            for second in transitions.get(neighbor, []):
                if scene_of.get(second.get("to", "")) != base:
                    continue
                if first.get("destination_spawn") != second.get("spawn"):
                    continue
                if first.get("spawn") != second.get("destination_spawn"):
                    continue
                if "travel" in (first.get("alignment"), second.get("alignment")):
                    continue
                pair = tuple(sorted([(base, first["id"]), (neighbor, second["id"])]))
                expected.add(pair)

    actual = set()
    for base, base_transition, neighbor, neighbor_transition in seam_keys:
        actual.add(tuple(sorted([(base, base_transition), (neighbor, neighbor_transition)])))
    for pair in sorted(expected - actual):
        errors.append(f"reciprocal physical transition pair {pair} is not a manifest seam")
    for pair in sorted(actual - expected):
        errors.append(f"manifest seam {pair} is not a reciprocal edge pair in the .rrmap sources")

    travel = {
        (location_id, item["id"])
        for location_id, items in transitions.items()
        for item in items
        if item.get("alignment") == "travel" or item.get("to", "") and item["to"] not in scene_of
    }
    for pair in actual:
        for endpoint in pair:
            if endpoint in travel:
                errors.append(f"travel or out-of-group transition {endpoint} is a seam")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--manifest", default=DEFAULT_MANIFEST)
    parser.add_argument("--root", default=str(ROOT))
    args = parser.parse_args(argv)
    root = Path(args.root)
    path = root / args.manifest
    if not path.exists():
        print(f"missing {args.manifest}; run tools/build_world_layout.gd", file=sys.stderr)
        return 1
    manifest = json.loads(path.read_text(encoding="utf-8"))
    errors = verify(manifest, root)
    for warning in manifest.get("warnings", []):
        print(f"warning: {warning}")
    for error in errors:
        print(f"error: {error}", file=sys.stderr)
    if errors:
        return 1
    streamable = sum(1 for seam in manifest["seams"] if seam["status"] == "streamable")
    print(
        f"ok {manifest['world_group_id']}: {len(manifest['locations'])} locations, "
        f"{streamable}/{len(manifest['seams'])} streamable seams, "
        f"{len(manifest['explicit_transitions'])} explicit transitions"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
