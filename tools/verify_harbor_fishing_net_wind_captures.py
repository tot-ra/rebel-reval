#!/usr/bin/env python3
"""Verify Kalamaja fishing-net weather-wind review captures.

Checks the 12 PNGs written by ``tools/capture_harbor_east_fishing_net_wind.gd``:
three weather regimes (clear, coastal, storm) with four temporal frames each at
1280x720, non-blank detail, and visible temporal or weather variation.

Usage:
    python3 tools/verify_harbor_fishing_net_wind_captures.py
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CAPTURE_DIR = ROOT / "docs" / "reports" / "images" / "view3d" / "harbor_east_fishing_nets"
WEATHER_GROUPS = ("clear", "coastal", "storm")
FRAME_COUNT = 4
EXPECTED_WIDTH = 1280
EXPECTED_HEIGHT = 720
MIN_LUMINANCE_STDEV = 5.0

TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from verify_slice_surface_captures import capture_stats  # noqa: E402


def expected_paths(*, root: Path = ROOT) -> list[Path]:
    capture_dir = root / CAPTURE_DIR.relative_to(ROOT)
    paths: list[Path] = []
    for weather in WEATHER_GROUPS:
        for frame_index in range(FRAME_COUNT):
            paths.append(capture_dir / f"{weather}_{frame_index:02d}.png")
    return paths


def validate(*, root: Path = ROOT) -> list[str]:
    errors: list[str] = []
    stats_by_path: dict[Path, object] = {}

    for path in expected_paths(root=root):
        rel = path.relative_to(root)
        if not path.is_file():
            errors.append(f"missing harbor fishing-net wind capture: {rel.as_posix()}")
            continue
        try:
            stats = capture_stats(path)
        except ValueError as exc:
            errors.append(str(exc))
            continue
        stats_by_path[path] = stats
        if stats.width != EXPECTED_WIDTH or stats.height != EXPECTED_HEIGHT:
            errors.append(
                f"{rel.as_posix()}: expected {EXPECTED_WIDTH}x{EXPECTED_HEIGHT}, "
                f"got {stats.width}x{stats.height}"
            )
        if stats.luminance_stdev < MIN_LUMINANCE_STDEV:
            errors.append(
                f"{rel.as_posix()}: capture looks flat or blank "
                f"(luminance stdev {stats.luminance_stdev:.2f} < {MIN_LUMINANCE_STDEV})"
            )

    capture_dir = root / CAPTURE_DIR.relative_to(ROOT)
    for weather in WEATHER_GROUPS:
        group_paths = [capture_dir / f"{weather}_{index:02d}.png" for index in range(FRAME_COUNT)]
        group_stats = [stats_by_path.get(path) for path in group_paths]
        if any(item is None for item in group_stats):
            continue
        digests = {item.digest for item in group_stats}
        if len(digests) < 2:
            errors.append(f"{weather}: expected temporal variation across {FRAME_COUNT} frames")

    clear_path = capture_dir / "clear_00.png"
    storm_path = capture_dir / "storm_00.png"
    if clear_path in stats_by_path and storm_path in stats_by_path:
        if stats_by_path[clear_path].digest == stats_by_path[storm_path].digest:
            errors.append("clear and storm captures must not be identical at frame 00")

    return errors


def main() -> int:
    errors = validate()
    if errors:
        print("harbor fishing-net wind capture verification failed:")
        for error in errors:
            print(f"  - {error}")
        return 1

    print(
        "harbor fishing-net wind capture verification passed "
        f"({len(WEATHER_GROUPS)} weather regimes x {FRAME_COUNT} frames)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
