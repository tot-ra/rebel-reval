#!/usr/bin/env python3
"""Audit the dedicated P0-102 environment-kit day/night evidence set.

This verifier is intentionally separate from the generic P0-053 view3d audit:
the environment-kit acceptance set has four spaces and eight dedicated plates.
It checks the evidence files and the report metadata without touching runtime,
map semantics, or capture assets.
"""

from __future__ import annotations

import re
import zlib
from pathlib import Path

from verify_slice_surface_captures import capture_stats

ROOT = Path(__file__).resolve().parents[1]
CAPTURE_DIR = ROOT / "docs" / "reports" / "images" / "p0_102_environment_kit"
REPORT_PATH = ROOT / "docs" / "reports" / "p0_102_environment_kit_acceptance.md"
EXPECTED_WIDTH = 1280
EXPECTED_HEIGHT = 720
MIN_LUMINANCE_STDEV = 5.0

PLATES = {
    "forge": {
        "map": "kalev_smithy",
        "day": "forge_day.png",
        "night": "forge_night.png",
    },
    "street/well": {
        "map": "lower_town_slice",
        "day": "street_well_day.png",
        "night": "street_well_night.png",
    },
    "brewery": {
        "map": "lower_town_slice",
        "day": "brewery_day.png",
        "night": "brewery_night.png",
    },
    "checkpoint": {
        "map": "lower_town_slice",
        "day": "checkpoint_day.png",
        "night": "checkpoint_night.png",
    },
}


def _plate_row(report: str, state: str, filename: str) -> tuple[str, str] | None:
    escaped = re.escape(filename)
    match = re.search(
        rf"^\| {state.title()} \| \[`?{escaped}`?\]\([^)]*\) \| `[^`]+` \| ([^|]+) \|$",
        report,
        re.MULTILINE,
    )
    if not match:
        return None
    return match.group(0), " ".join(match.group(1).split())


def validate(*, root: Path = ROOT) -> list[str]:
    errors: list[str] = []
    capture_dir = root / CAPTURE_DIR.relative_to(ROOT)
    report_path = root / REPORT_PATH.relative_to(ROOT)

    if not report_path.is_file():
        return [f"missing acceptance report: {report_path.relative_to(root)}"]
    report = report_path.read_text(encoding="utf-8")

    checked = 0
    for space, metadata in PLATES.items():
        rows: dict[str, str] = {}
        stats = {}
        for state in ("day", "night"):
            filename = metadata[state]
            path = capture_dir / filename
            link = f"](images/p0_102_environment_kit/{filename})"
            if report.count(link) != 1:
                errors.append(
                    f"{filename}: expected exactly one report link, found {report.count(link)}"
                )
            row = _plate_row(report, state, filename)
            if row is None:
                errors.append(f"{filename}: missing labelled {state} metadata row")
            else:
                rows[state] = row[1]
                expected_light = f"MapView3D.TIME_{state.upper()}"
                if expected_light not in row[0]:
                    errors.append(f"{filename}: missing {expected_light} lighting label")
                if metadata["map"] not in row[0]:
                    errors.append(f"{filename}: missing map identity {metadata['map']}")
                if "orthographic size" not in row[0] or "focus logic cell" not in row[0]:
                    errors.append(f"{filename}: missing camera/framing metadata")

            if not path.is_file():
                errors.append(f"missing P0-102 environment-kit plate: {path.relative_to(root)}")
                continue
            try:
                captured = capture_stats(path)
            except (OSError, ValueError, zlib.error) as exc:
                errors.append(str(exc))
                continue
            checked += 1
            stats[state] = captured
            if (captured.width, captured.height) != (EXPECTED_WIDTH, EXPECTED_HEIGHT):
                errors.append(
                    f"{filename}: expected {EXPECTED_WIDTH}x{EXPECTED_HEIGHT}, "
                    f"got {captured.width}x{captured.height}"
                )
            if captured.luminance_stdev < MIN_LUMINANCE_STDEV:
                errors.append(
                    f"{filename}: capture looks blank or flat "
                    f"(luminance stdev {captured.luminance_stdev:.2f} < {MIN_LUMINANCE_STDEV})"
                )

        if "day" in rows and "night" in rows and rows["day"] != rows["night"]:
            errors.append(f"{space}: day/night framing metadata does not match")
        if "day" in stats and "night" in stats:
            if (stats["day"].width, stats["day"].height) != (
                stats["night"].width,
                stats["night"].height,
            ):
                errors.append(f"{space}: day/night resolution does not match")
            if stats["day"].digest == stats["night"].digest:
                errors.append(f"{space}: day/night plates are byte-identical")

    required_report_terms = (
        "routes",
        "doors",
        "player approach areas",
        "interactables",
        "capture limitations",
    )
    for term in required_report_terms:
        if term not in report.lower():
            errors.append(f"acceptance report does not explicitly record {term}")

    if checked != 8:
        errors.append(f"expected 8 decodable plates, checked {checked}")
    return errors


def main() -> int:
    errors = validate()
    if errors:
        print("P0-102 environment-kit evidence verification failed:")
        for error in errors:
            print(f"  - {error}")
        return 1

    print("P0-102 environment-kit evidence verification passed (8/8 plates)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
