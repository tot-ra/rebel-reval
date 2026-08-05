#!/usr/bin/env python3
"""Verify R-446 Lower Town population profile evidence captures.

Checks the three PNGs written by ``tools/capture_lower_town_population.gd`` plus the
published manifest at ``docs/reports/population_clusters_r419.json``. This is an
evidence-only gate for readable profile clusters; it does not assert runtime
crowd behaviour.

Usage:
    python3 tools/verify_lower_town_population_profiles.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "docs/reports/population_clusters_r419.json"
EXPECTED_WIDTH = 1280
EXPECTED_HEIGHT = 720
EXPECTED_SCENARIO_IDS = ("day", "market_day", "night_checkpoint")
MIN_LUMINANCE_STDEV = 5.0
MIN_READABLE_CLUSTER_ZONES = 3

TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from verify_slice_surface_captures import capture_stats  # noqa: E402


def _load_manifest(*, root: Path = ROOT) -> dict:
    source = (root / MANIFEST_PATH.relative_to(ROOT)).read_text(encoding="utf-8")
    parsed = json.loads(source)
    if not isinstance(parsed, dict):
        raise ValueError("population manifest must be a JSON object")
    return parsed


def validate(*, root: Path = ROOT) -> list[str]:
    errors: list[str] = []
    manifest_path = root / MANIFEST_PATH.relative_to(ROOT)
    if not manifest_path.is_file():
        return [f"missing population manifest: {manifest_path.relative_to(root).as_posix()}"]

    try:
        manifest = _load_manifest(root=root)
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        return [str(exc)]

    if manifest.get("map_id") != "lower_town_slice":
        errors.append("manifest map_id must be lower_town_slice")
    if manifest.get("source") != "res://content/maps/lower_town_slice.rrmap":
        errors.append("manifest source must point at lower_town_slice.rrmap")

    scenarios = manifest.get("scenarios", [])
    if not isinstance(scenarios, list):
        return errors + ["manifest scenarios must be an array"]

    scenario_ids = [str(item.get("id", "")) for item in scenarios if isinstance(item, dict)]
    if scenario_ids != list(EXPECTED_SCENARIO_IDS):
        errors.append(
            "manifest scenarios must list day, market_day, and night_checkpoint in order "
            f"(got {scenario_ids})"
        )

    digests: set[str] = set()
    for raw_scenario in scenarios:
        if not isinstance(raw_scenario, dict):
            errors.append("each manifest scenario must be an object")
            continue
        scenario: dict = raw_scenario
        scenario_id = str(scenario.get("id", ""))
        capture_ref = str(scenario.get("capture", ""))
        if not capture_ref.startswith("res://"):
            errors.append(f"{scenario_id}: capture path must use res://")
            continue

        capture_path = root / capture_ref.removeprefix("res://")
        rel = capture_path.relative_to(root)
        if not capture_path.is_file():
            errors.append(f"missing population capture: {rel.as_posix()}")
            continue

        try:
            stats = capture_stats(capture_path)
        except ValueError as exc:
            errors.append(str(exc))
            continue

        digests.add(stats.digest)
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

        viewport_px = scenario.get("viewport_px", [])
        if viewport_px != [EXPECTED_WIDTH, EXPECTED_HEIGHT]:
            errors.append(
                f"{scenario_id}: viewport_px must be [{EXPECTED_WIDTH}, {EXPECTED_HEIGHT}]"
            )

        civilian_count = int(scenario.get("civilian_count", -1))
        watch_count = int(scenario.get("watch_count", -1))
        total_count = int(scenario.get("total_count", -1))
        active_count = int(scenario.get("active_count", -1))
        if civilian_count < 0 or watch_count < 0 or total_count < 0 or active_count < 0:
            errors.append(f"{scenario_id}: manifest actor counts must be non-negative integers")
            continue
        if civilian_count + watch_count != total_count:
            errors.append(
                f"{scenario_id}: civilian_count + watch_count must equal total_count"
            )
        if active_count != total_count:
            errors.append(f"{scenario_id}: active_count must match total_count")

        zone_counts = scenario.get("placement_zone_counts", {})
        if not isinstance(zone_counts, dict):
            errors.append(f"{scenario_id}: placement_zone_counts must be an object")
            continue
        if len(zone_counts) < MIN_READABLE_CLUSTER_ZONES:
            errors.append(
                f"{scenario_id}: expected at least {MIN_READABLE_CLUSTER_ZONES} readable "
                f"placement zones, got {len(zone_counts)}"
            )
        if sum(int(value) for value in zone_counts.values()) != total_count:
            errors.append(
                f"{scenario_id}: placement_zone_counts must sum to total_count"
            )

        seed = int(scenario.get("seed", -1))
        if seed < 0:
            errors.append(f"{scenario_id}: seed must be recorded in the manifest")

    if len(digests) < len(EXPECTED_SCENARIO_IDS):
        errors.append("day, market_day, and night captures must not be identical")

    return errors


def main() -> int:
    errors = validate()
    if errors:
        print("lower town population profile verification failed:")
        for error in errors:
            print(f"  - {error}")
        return 1

    print(
        "lower town population profile verification passed "
        f"({len(EXPECTED_SCENARIO_IDS)} scenarios)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
