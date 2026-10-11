#!/usr/bin/env python3
"""Fail-closed activation readiness gate for the Central District.

P4-019 cannot promote the unified market/civic district in isolation: the
rrmap declaration, map catalog, transition manifest, approval ledger, and
visual evidence must agree. The inactive state is checked explicitly so
blocked dependencies cannot drift into an accidental partial release.
"""

from __future__ import annotations

import argparse
import json
import re
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RRMAP_PATH = Path("content/maps/market_civic_quarter.rrmap")
CATALOG_PATH = Path("scripts/map/map_catalog.gd")
DESTINATIONS_PATH = Path("content/transitions/active_destinations.json")
LEDGER_PATH = Path("docs/data/p4_019_central_district_activation.json")
EXPECTED_APPROVAL = "docs/adr/0008-three-act-campaign-and-faction-scope.md"
REQUIRED_BLOCKERS = {"P0-040", "P2-021", "P3-014", "P4-022"}


def _rrmap_state(path: Path) -> tuple[str, bool]:
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.startswith("map market_civic_quarter "):
            continue
        scope = re.search(r"\bscope=(\w+)", line)
        active = re.search(r"\bactive=(true|false)", line)
        if scope and active:
            return scope.group(1), active.group(1) == "true"
    raise ValueError("market_civic_quarter map declaration must include scope and active")


def _catalog_state(path: Path) -> tuple[str, bool]:
    text = path.read_text(encoding="utf-8")
    match = re.search(
        r'"reval_center"\s*:\s*\{(?P<body>.*?)\}', text, re.DOTALL
    )
    if not match:
        raise ValueError("map catalog is missing reval_center")
    body = match.group("body")
    scope = re.search(r'"scope"\s*:\s*"([^"]+)"', body)
    active = re.search(r'"active"\s*:\s*(true|false)', body)
    if not scope or not active:
        raise ValueError("reval_center catalog entry must include scope and active")
    return scope.group(1), active.group(1) == "true"


def _destination_state(path: Path) -> tuple[bool, bool]:
    data = json.loads(path.read_text(encoding="utf-8"))
    matches = [
        row for row in data.get("scenes", []) if row.get("id") == "reval_center"
    ]
    if len(matches) != 1:
        raise ValueError("transition manifest must contain exactly one reval_center entry")
    row = matches[0]
    return bool(row.get("active", False)), bool(row.get("release", True))


def _png_size(path: Path) -> tuple[int, int]:
    data = path.read_bytes()
    if len(data) < 24 or data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"capture is not a PNG: {path}")
    return struct.unpack(">II", data[16:24])


def verify(root: Path) -> list[str]:
    errors: list[str] = []
    try:
        rrmap_scope, rrmap_active = _rrmap_state(root / RRMAP_PATH)
        catalog_scope, catalog_active = _catalog_state(root / CATALOG_PATH)
        destination_active, destination_release = _destination_state(
            root / DESTINATIONS_PATH
        )
        ledger = json.loads((root / LEDGER_PATH).read_text(encoding="utf-8"))
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        return [str(exc)]

    if ledger.get("approval_artifact") != EXPECTED_APPROVAL:
        errors.append(f"approval_artifact must be {EXPECTED_APPROVAL}")
    if not (root / EXPECTED_APPROVAL).is_file():
        errors.append(f"missing approval artifact: {EXPECTED_APPROVAL}")

    production_states = (
        rrmap_scope == "production" and rrmap_active,
        catalog_scope == "production" and catalog_active,
        destination_active and destination_release,
    )
    if any(production_states) and not all(production_states):
        errors.append(
            "partial activation: rrmap, map catalog, and transition release state must switch together"
        )

    decision = ledger.get("decision")
    if all(production_states):
        if decision != "approved":
            errors.append("production activation requires ledger decision=approved")
        if ledger.get("blockers"):
            errors.append("approved activation ledger must have no blockers")
        review = ledger.get("parity_review", {})
        if review.get("status") != "accepted":
            errors.append("production activation requires accepted day/night parity review")
        capture_paths = [review.get("day_capture"), review.get("night_capture")]
        if not all(isinstance(value, str) and value for value in capture_paths):
            errors.append("accepted parity review must name day and night captures")
        else:
            day_path, night_path = (root / value for value in capture_paths)
            try:
                if _png_size(day_path) != _png_size(night_path):
                    errors.append("day/night captures must use identical framing dimensions")
                if day_path.read_bytes() == night_path.read_bytes():
                    errors.append("day/night captures must not be byte-identical")
            except (OSError, ValueError) as exc:
                errors.append(str(exc))
    else:
        if (rrmap_scope, rrmap_active) != ("prototype", False):
            errors.append(
                "blocked Central District rrmap must remain scope=prototype active=false"
            )
        if (catalog_scope, catalog_active) != ("prototype", False):
            errors.append("blocked reval_center catalog entry must remain prototype/inactive")
        if not destination_active or destination_release:
            errors.append("blocked reval_center must remain active developer traversal with release=false")
        if decision != "blocked":
            errors.append("inactive activation ledger must use decision=blocked")
        blockers = set(ledger.get("blockers", []))
        missing = sorted(REQUIRED_BLOCKERS - blockers)
        if missing:
            errors.append("blocked activation ledger is missing dependencies: " + ", ".join(missing))
        if ledger.get("parity_review", {}).get("status") == "accepted":
            errors.append("blocked activation cannot claim accepted parity review")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=ROOT)
    args = parser.parse_args()
    errors = verify(args.root.resolve())
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print("P4-019 Central District activation readiness guard passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
