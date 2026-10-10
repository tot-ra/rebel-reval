#!/usr/bin/env python3
"""Summarise, compare and budget-check R-1320 vegetation benchmark reports.

The report comes from tools/capture_vegetation_benchmark.gd (schema
rr.vegetation_benchmark.v1, contract in docs/PERFORMANCE_REPORT.md). Counts
(instances, triangles, draw calls) are deterministic for one build; frame times
are measurements and vary run to run, so `compare` checks counts only.

Usage:
  python3 tools/vegetation_performance.py summary build/perf_veg.json
  python3 tools/vegetation_performance.py compare run_a.json run_b.json
  python3 tools/vegetation_performance.py budgets build/perf_veg.json \
      [--baseline docs/reports/vegetation_benchmark_baseline.json]

Budget rule (a ratchet): a count passes when it is at most
max(target budget, the same count in the baseline). Layers already over target
(today the tree crowns) may not grow; layers under target may grow up to it.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

SCHEMA = "rr.vegetation_benchmark.v1"
LAYERS = (
    "grass_near",
    "grass_mid",
    "grain",
    "trees_lod0",
    "trees_lod1",
    "trees_lod2",
    "shrubs",
    "flowers",
    "litter",
    "veg_misc",
    "other",
)
VEGETATION_LAYERS = tuple(layer for layer in LAYERS if layer != "other")
COUNT_FIELDS = ("nodes", "instances", "triangles", "draw_calls", "shadow_draw_calls")
CAMERAS = (
    "meadow_eye_level",
    "meadow_gameplay",
    "grain_field_eye_level",
    "woodland_interior",
    "woodland_distance",
    "lower_town_street",
    # R-1558: densest CityForbs windows, searched by the benchmark itself.
    "forb_hotspot_meadow",
    "forb_hotspot_kalev_smithy",
)

# Target budgets, derived from the 2026-10-08 M5 Pro baseline
# (docs/reports/vegetation_benchmark_baseline.md); the reasoning is in
# docs/SYSTEMS/VEGETATION_REALISM.md section 8. Counts are the hard gate: they
# are deterministic and portable to the Intel UHD 620 floor. Milliseconds are
# measured on the reference machine and only warn (run-to-run noise on the
# tree layer is tens of percent).
BUDGETS: dict[str, Any] = {
    # Whole-frame vegetation caps (main-pass census) for every camera.
    "vegetation_triangles": 2_000_000,
    "vegetation_draw_calls": 250,
    # Per-layer caps for every camera: (triangles, draw_calls).
    "layers": {
        "grass_near": (300_000, 8),
        "grass_mid": (100_000, 24),
        "grain": (250_000, 16),
        "trees_lod0": (1_000_000, 100),
        "trees_lod1": (600_000, 60),
        "trees_lod2": (100_000, 30),
        "shrubs": (150_000, 30),
        # R-1558: holds the CityForbs sub-budget below plus the yarrow accents.
        "flowers": (400_000, 32),
        "litter": (50_000, 8),
        "veg_misc": (100_000, 16),
    },
    # R-1558: CityForbs alone (the `forbs` block of a camera): triangles, draw
    # calls and the advisory CPU milliseconds of one chunk-step update_for.
    "forbs": (350_000, 16),
    "forb_update_ms": 20.0,
    # Frame time one layer may cost on the reference machine (paired
    # shown/hidden median, 1920x1080, GL Compatibility). Advisory.
    "layer_ms": 4.0,
}


def load(path: Path) -> dict[str, Any]:
    report = json.loads(path.read_text(encoding="utf-8"))
    errors = validate(report)
    if errors:
        raise ValueError(f"{path}: " + "; ".join(errors))
    return report


def validate(report: dict[str, Any]) -> list[str]:
    """Schema check: every named camera and layer present with count fields."""
    errors: list[str] = []
    if report.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA!r}, got {report.get('schema')!r}")
        return errors
    if tuple(report.get("layers", ())) != LAYERS:
        errors.append("layers list does not match the R-1320 layer order")
    cameras = report.get("cameras")
    if not isinstance(cameras, list) or not cameras:
        errors.append("cameras must be a non-empty list")
        return errors
    for camera in cameras:
        name = camera.get("name", "?")
        if name not in CAMERAS:
            errors.append(f"unknown camera {name!r}")
        layers = camera.get("layers", {})
        for layer in LAYERS:
            bucket = layers.get(layer)
            if not isinstance(bucket, dict):
                errors.append(f"{name}: missing layer {layer}")
                continue
            for field in COUNT_FIELDS:
                if not isinstance(bucket.get(field), int):
                    errors.append(f"{name}.{layer}: {field} must be an integer")
    return errors


def vegetation_totals(camera: dict[str, Any]) -> dict[str, int]:
    totals = {"instances": 0, "triangles": 0, "draw_calls": 0}
    for layer in VEGETATION_LAYERS:
        for key in totals:
            totals[key] += camera["layers"][layer][key]
    return totals


def counts_signature(report: dict[str, Any]) -> dict[str, dict[str, dict[str, int]]]:
    return {
        camera["name"]: {
            layer: {field: camera["layers"][layer][field] for field in COUNT_FIELDS}
            for layer in LAYERS
        }
        for camera in report["cameras"]
    }


def compare(first: dict[str, Any], second: dict[str, Any]) -> list[str]:
    """Count differences between two runs; empty means the census reproduced."""
    a, b = counts_signature(first), counts_signature(second)
    differences: list[str] = []
    for name in sorted(set(a) | set(b)):
        if name not in a or name not in b:
            differences.append(f"{name}: present in only one report")
            continue
        for layer in LAYERS:
            for field in COUNT_FIELDS:
                left, right = a[name][layer][field], b[name][layer][field]
                if left != right:
                    differences.append(f"{name}.{layer}.{field}: {left} != {right}")
    return differences


def check_budgets(
    report: dict[str, Any],
    baseline: dict[str, Any] | None = None,
    budgets: dict[str, Any] = BUDGETS,
) -> list[str]:
    """Budget violations; with a baseline, each limit is max(target, baseline)."""
    return _budget_findings(report, baseline, budgets)[0]


def check_timing(
    report: dict[str, Any],
    baseline: dict[str, Any] | None = None,
    budgets: dict[str, Any] = BUDGETS,
) -> list[str]:
    """Advisory per-layer millisecond findings (never fail the gate)."""
    return _budget_findings(report, baseline, budgets)[1]


def _budget_findings(
    report: dict[str, Any], baseline: dict[str, Any] | None, budgets: dict[str, Any]
) -> tuple[list[str], list[str]]:
    reference = {camera["name"]: camera for camera in (baseline or {}).get("cameras", [])}
    violations: list[str] = []
    warnings: list[str] = []

    def over(label: str, value: float, target: float, previous: float | None,
             sink: list[str] = violations) -> None:
        limit = target if previous is None else max(target, previous)
        if value > limit:
            sink.append(f"{label}: {value:,} > {limit:,}")

    for camera in report["cameras"]:
        name = camera["name"]
        before = reference.get(name)
        totals = vegetation_totals(camera)
        before_totals = vegetation_totals(before) if before else {}
        over(
            f"{name}: vegetation triangles",
            totals["triangles"],
            budgets["vegetation_triangles"],
            before_totals.get("triangles"),
        )
        over(
            f"{name}: vegetation draw calls",
            totals["draw_calls"],
            budgets["vegetation_draw_calls"],
            before_totals.get("draw_calls"),
        )
        for layer, (max_triangles, max_draws) in budgets["layers"].items():
            bucket = camera["layers"][layer]
            previous = before["layers"][layer] if before else {}
            over(
                f"{name}.{layer} triangles",
                bucket["triangles"],
                max_triangles,
                previous.get("triangles"),
            )
            over(
                f"{name}.{layer} draw calls",
                bucket["draw_calls"],
                max_draws,
                previous.get("draw_calls"),
            )
        forbs = camera.get("forbs")
        if forbs:
            max_triangles, max_draws = budgets["forbs"]
            previous = (before or {}).get("forbs", {})
            over(f"{name}.forbs triangles", forbs["triangles"], max_triangles, previous.get("triangles"))
            over(f"{name}.forbs draw calls", forbs["draw_calls"], max_draws, previous.get("draw_calls"))
            over(
                f"{name}.forbs update_for ms",
                forbs["update_for_step_ms"]["max"],
                budgets["forb_update_ms"],
                None,
                warnings,
            )
        for layer, timing in camera.get("layer_ms", {}).items():
            saved = timing.get("frame_ms_saved", 0.0)
            previous_ms = (before or {}).get("layer_ms", {}).get(layer, {}).get("frame_ms_saved")
            # Frame times are noisy: a baseline layer keeps max(0.5 ms, 25 %).
            tolerance = None if previous_ms is None else previous_ms + max(0.5, previous_ms * 0.25)
            over(f"{name}.{layer} ms", saved, budgets["layer_ms"], tolerance, warnings)
    return violations, warnings


def summary(report: dict[str, Any]) -> str:
    host = report.get("host", {})
    width, height = report.get("resolution", [0, 0])
    lines = [
        f"Vegetation benchmark ({report['schema']}) on {host.get('gpu', '?')}, "
        f"{width}x{height}, {report.get('renderer', '?')}, Godot {report.get('godot', '?')}"
    ]
    for camera in report["cameras"]:
        totals = vegetation_totals(camera)
        share = camera.get("vegetation_share", {})
        gpu = camera.get("gpu", {})
        lines.append(
            f"\n{camera['name']} ({camera['map_id']}, {camera['mode']}): vegetation "
            f"{totals['triangles']:,} tris / {totals['draw_calls']} draws "
            f"(share {share.get('triangles', 0):.0%} tris, {share.get('draw_calls', 0):.0%} draws)"
            + (
                f"; frame {gpu['frame_ms_median']:.1f} ms, GPU {gpu['draw_calls_peak']} draws"
                if gpu
                else ""
            )
        )
        lines.append(
            f"  {'layer':<11} {'nodes':>6} {'instances':>10} {'triangles':>12} "
            f"{'draws':>6} {'shadow':>7} {'ms saved':>9}"
        )
        timing = camera.get("layer_ms", {})
        for layer in LAYERS:
            bucket = camera["layers"][layer]
            if bucket["nodes"] == 0:
                continue
            saved = timing.get(layer, {}).get("frame_ms_saved")
            lines.append(
                f"  {layer:<11} {bucket['nodes']:>6} {bucket['instances']:>10,} "
                f"{bucket['triangles']:>12,} {bucket['draw_calls']:>6} "
                f"{bucket['shadow_draw_calls']:>7} {'' if saved is None else f'{saved:.2f}':>9}"
            )
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("summary").add_argument("report", type=Path)
    compare_parser = sub.add_parser("compare")
    compare_parser.add_argument("first", type=Path)
    compare_parser.add_argument("second", type=Path)
    budgets_parser = sub.add_parser("budgets")
    budgets_parser.add_argument("report", type=Path)
    budgets_parser.add_argument("--baseline", type=Path)
    args = parser.parse_args(argv)
    if args.command == "summary":
        print(summary(load(args.report)))
        return 0
    if args.command == "compare":
        differences = compare(load(args.first), load(args.second))
        for line in differences:
            print(line)
        print("counts identical" if not differences else f"{len(differences)} difference(s)")
        return 1 if differences else 0
    baseline = load(args.baseline) if args.baseline else None
    report = load(args.report)
    violations = check_budgets(report, baseline)
    for line in check_timing(report, baseline):
        print(f"warning (timing, advisory): {line}")
    for line in violations:
        print(line)
    print("within budget" if not violations else f"{len(violations)} budget violation(s)")
    return 1 if violations else 0


if __name__ == "__main__":
    sys.exit(main())
