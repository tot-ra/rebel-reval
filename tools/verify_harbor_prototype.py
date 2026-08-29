#!/usr/bin/env python3
"""Verify the inactive split Trade and Fishing Harbour prototype contract."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

MAPS = {
    "reval_harbor_north": {
        "path": Path("content/maps/reval_harbor_north.rrmap"),
        "dimensions": (160, 108),
        "scene": 'source "scenes/harbor/harbor_north.tscn"',
        "transition": (
            "to_harbor_east",
            "reval_harbor_east",
            "from_harbor_north",
        ),
    },
    "reval_harbor_east": {
        "path": Path("content/maps/reval_harbor_east.rrmap"),
        "dimensions": (144, 80),
        "scene": 'source "scenes/harbor/harbor_east.tscn"',
        "transition": (
            "to_harbor_north",
            "reval_harbor_north",
            "from_harbor_east",
        ),
    },
}

RESEARCH_SOURCE = 'source "docs/reports/reval_harbour_1343_research.md"'
MAP_DECLARATION = re.compile(
    r"^map\s+(?P<map_id>\S+)\s+\S+\s+(?P<width>\d+)\s+(?P<height>\d+)\s+"
    r"\S+\s+scope=(?P<scope>\S+)\s+active=(?P<active>true|false)\b"
)
TRANSITION = re.compile(
    r"^transition\s+(?P<transition_id>\S+)\s+.*\bto=(?P<destination>\S+)\s+"
    r"destination_spawn=(?P<destination_spawn>\S+)\b"
)


def _read_map(root: Path, map_id: str, config: dict) -> tuple[list[str], list[str]]:
    path = root / config["path"]
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as exc:
        return [], [f"{map_id}: cannot read RRMap: {exc}"]

    errors: list[str] = []
    declaration = next(
        (match for match in (MAP_DECLARATION.match(line) for line in lines) if match),
        None,
    )
    if declaration is None:
        errors.append(f"{map_id}: map declaration must include ID, dimensions, scope, and active state")
    else:
        if declaration.group("map_id") != map_id:
            errors.append(
                f"{map_id}: stable map ID drifted to {declaration.group('map_id')}"
            )
        expected_width, expected_height = config["dimensions"]
        dimensions = (int(declaration.group("width")), int(declaration.group("height")))
        if dimensions != (expected_width, expected_height):
            errors.append(
                f"{map_id}: expected dimensions {expected_width}x{expected_height}, "
                f"got {dimensions[0]}x{dimensions[1]}"
            )
        if declaration.group("scope") != "prototype" or declaration.group("active") != "false":
            errors.append(f"{map_id}: split harbour prototypes must remain scope=prototype active=false")

    if config["scene"] not in lines:
        errors.append(f"{map_id}: missing split scene reference {config['scene']}")
    if RESEARCH_SOURCE not in lines:
        errors.append(f"{map_id}: missing 1343 harbour research reference")

    expected_transition, destination, destination_spawn = config["transition"]
    transition = next(
        (
            match
            for match in (TRANSITION.match(line) for line in lines)
            if match and match.group("transition_id") == expected_transition
        ),
        None,
    )
    if transition is None:
        errors.append(f"{map_id}: missing reciprocal transition {expected_transition}")
    else:
        if transition.group("destination") != destination:
            errors.append(
                f"{map_id}: {expected_transition} must target {destination}, "
                f"got {transition.group('destination')}"
            )
        if transition.group("destination_spawn") != destination_spawn:
            errors.append(
                f"{map_id}: {expected_transition} must use spawn {destination_spawn}, "
                f"got {transition.group('destination_spawn')}"
            )

    return lines, errors


def validate(root: Path = ROOT) -> list[str]:
    """Return contract violations for the two split harbour RRMaps."""
    errors: list[str] = []
    for map_id, config in MAPS.items():
        _lines, map_errors = _read_map(root, map_id, config)
        errors.extend(map_errors)
    return errors


def main() -> int:
    errors = validate()
    if errors:
        print("harbour prototype verification failed:")
        for error in errors:
            print(f"  - {error}")
        return 1
    print("harbour prototype verification passed (2 inactive reciprocal maps)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
