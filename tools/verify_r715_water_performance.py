#!/usr/bin/env python3
"""Verify the fail-closed R-715 water performance evidence ledger.

The report is intentionally a Markdown artifact with one machine-readable JSON
fence.  This validator checks the evidence contract without turning generic
scene measurements into water measurements.  A blocked report is a valid
artifact in normal mode; ``--strict`` is the acceptance mode used for a real
R-755 handoff and requires measured minimum and recommended rows.

Usage:
    python3 tools/verify_r715_water_performance.py
    python3 tools/verify_r715_water_performance.py --report path/to/report.md
    python3 tools/verify_r715_water_performance.py --strict --report fixture.md
"""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_REPORT = ROOT / "docs/reports/r715_water_performance.md"
REQUIRED_TIERS = ("minimum", "recommended")
WATER_THRESHOLD_KEYS = (
    "detail_layers",
    "reflection_samples",
    "refraction_samples",
    "foam_shore_detail",
    "frame_time_ms_p95",
    "draw_calls_peak",
    "resource_count_peak",
    "memory_delta_mib",
)
GENERIC_SCENE_BUDGET_KEYS = {
    "steady_frame_time_ms_p95",
    "steady_frame_time_ms_p99",
    "resident_node_count",
    "resident_collision_count",
    "resident_memory_delta_mib",
}
METRIC_KEYS = (
    "frame_time_ms_p95",
    "draw_calls_peak",
    "resource_count_peak",
    "memory_delta_mib",
)
MARKDOWN_LINK_RE = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")
JSON_FENCE_RE = re.compile(r"```json\s*(?P<payload>\{.*?\})\s*```", re.DOTALL)


@dataclass
class Verification:
    report_path: Path
    strict: bool = False
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    recommendation: str = ""
    tiers_checked: int = 0

    @property
    def valid(self) -> bool:
        return not self.errors


def _load_json(path: Path, label: str, result: Verification) -> dict[str, Any] | None:
    if not path.is_file():
        result.errors.append(f"missing {label}: {path}")
        return None
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        result.errors.append(f"invalid {label} {path}: {exc}")
        return None
    if not isinstance(payload, dict):
        result.errors.append(f"{label} must be a JSON object: {path}")
        return None
    return payload


def _repo_path(value: Any) -> Path | None:
    if not isinstance(value, str) or not value:
        return None
    candidate = Path(value)
    if candidate.is_absolute():
        return candidate
    return ROOT / candidate


def _number(value: Any) -> bool:
    if not isinstance(value, (int, float)) or isinstance(value, bool):
        return False
    return math.isfinite(float(value))


def _identity_matches(actual: Any, expected: dict[str, Any]) -> bool:
    if not isinstance(actual, dict):
        return False
    for key in ("profile_id", "architecture", "gpu"):
        if str(actual.get(key, "")) != str(expected.get(key, "")):
            return False
    return True


def _check_markdown_links(text: str, result: Verification) -> None:
    for raw_target in MARKDOWN_LINK_RE.findall(text):
        target = raw_target.strip().split("#", 1)[0]
        if not target or "://" in target or target.startswith("mailto:"):
            continue
        resolved = (result.report_path.parent / target).resolve()
        if not resolved.is_file():
            result.errors.append(f"stale report link: {raw_target} -> {resolved}")


def _extract_payload(text: str, result: Verification) -> dict[str, Any] | None:
    matches = JSON_FENCE_RE.findall(text)
    if len(matches) != 1:
        result.errors.append(
            f"expected exactly one JSON evidence fence, found {len(matches)}"
        )
        return None
    try:
        payload = json.loads(matches[0])
    except json.JSONDecodeError as exc:
        result.errors.append(f"invalid evidence JSON: {exc}")
        return None
    if not isinstance(payload, dict):
        result.errors.append("evidence JSON must be an object")
        return None
    return payload


def _validate_benchmark_output(
    expected: Any,
    tier: dict[str, Any],
    result: Verification,
) -> None:
    if not isinstance(expected, dict):
        result.errors.append("R-755 water output entry must be an object")
        return
    output_path = _repo_path(expected.get("path"))
    if expected.get("status") != "available":
        result.errors.append(
            f"strict evidence requires available R-755 output for tier `{tier.get('id')}`"
        )
        return
    if output_path is None or not output_path.is_file():
        result.errors.append(
            f"missing R-755 water benchmark output: {expected.get('path')}"
        )
        return
    output = _load_json(output_path, "R-755 water benchmark output", result)
    if output is None:
        return
    tier_id = str(tier.get("id", ""))
    if output.get("tier") != tier_id:
        result.errors.append(
            f"R-755 output tier mismatch: expected `{tier_id}`, got {output.get('tier')!r}"
        )
    if output.get("task") != "R-755":
        result.errors.append(f"R-755 output for `{tier_id}` must identify task R-755")
    if not _identity_matches(output.get("target_hardware"), tier.get("target_hardware", {})):
        result.errors.append(f"R-755 output for `{tier_id}` has target identity drift")
    if not _identity_matches(output.get("measurement_host"), tier.get("measurement_host", {})):
        result.errors.append(f"R-755 output for `{tier_id}` has measurement-host drift")
    renderer = output.get("renderer")
    if not isinstance(renderer, dict) or renderer.get("headless") is not False:
        result.errors.append(f"R-755 output for `{tier_id}` must be non-headless")
    if not isinstance(output.get("samples"), int) or output.get("samples", 0) < 120:
        result.errors.append(f"R-755 output for `{tier_id}` needs at least 120 samples")
    metrics = output.get("metrics")
    if not isinstance(metrics, dict):
        result.errors.append(f"R-755 output for `{tier_id}` is missing metrics")
        return
    for metric in METRIC_KEYS:
        if not _number(metrics.get(metric)):
            result.errors.append(f"R-755 output for `{tier_id}` is missing metric `{metric}`")


def _validate_tier(
    tier: Any,
    index: int,
    minimum_profile: dict[str, Any] | None,
    recommended_profile: dict[str, Any] | None,
    result: Verification,
) -> None:
    if not isinstance(tier, dict):
        result.errors.append(f"tier {index} must be an object")
        return
    tier_id = str(tier.get("id", ""))
    if tier_id not in REQUIRED_TIERS:
        result.errors.append(f"unknown water tier: {tier_id or '<missing>'}")
        return
    result.tiers_checked += 1

    thresholds = tier.get("thresholds")
    if not isinstance(thresholds, dict):
        result.errors.append(f"tier `{tier_id}` is missing thresholds")
        thresholds = {}
    missing_thresholds = [key for key in WATER_THRESHOLD_KEYS if key not in thresholds]
    if missing_thresholds:
        result.errors.append(
            f"tier `{tier_id}` missing water thresholds: {', '.join(missing_thresholds)}"
        )
    generic_keys = sorted(set(thresholds) & GENERIC_SCENE_BUDGET_KEYS)
    if generic_keys:
        result.errors.append(
            f"tier `{tier_id}` confuses generic scene budgets with water budgets: "
            + ", ".join(generic_keys)
        )
    for key in WATER_THRESHOLD_KEYS:
        value = thresholds.get(key)
        if not _number(value) or float(value) <= 0.0:
            result.errors.append(f"tier `{tier_id}` has invalid threshold `{key}`: {value!r}")

    if tier.get("budget_scope") != "water_only":
        result.errors.append(f"tier `{tier_id}` must declare budget_scope=water_only")

    fallback = tier.get("fallback")
    if not isinstance(fallback, dict) or fallback.get("declared") is not True:
        result.errors.append(f"tier `{tier_id}` has no declared compatibility fallback")
    elif not str(fallback.get("id", "")) or not str(fallback.get("behavior", "")):
        result.errors.append(f"tier `{tier_id}` fallback needs an id and behavior")

    expected_profile = minimum_profile if tier_id == "minimum" else recommended_profile
    target_hardware = tier.get("target_hardware")
    if not _identity_matches(target_hardware, expected_profile or {}):
        result.errors.append(
            f"tier `{tier_id}` target hardware does not match its declared "
            "profile"
        )

    measurement_host = tier.get("measurement_host")
    renderer = tier.get("renderer")
    measurement = tier.get("measurement")
    if not isinstance(measurement_host, dict):
        result.errors.append(f"tier `{tier_id}` must keep measurement_host separate")
        measurement_host = {}
    if not isinstance(renderer, dict):
        result.errors.append(f"tier `{tier_id}` is missing renderer identity")
        renderer = {}
    if not isinstance(measurement, dict):
        result.errors.append(f"tier `{tier_id}` is missing measurement data")
        measurement = {}

    measurement_status = str(measurement.get("status", ""))
    tier_status = str(tier.get("status", ""))
    if measurement_status == "unmeasured":
        if tier_status != "BLOCKED":
            result.errors.append(f"unmeasured tier `{tier_id}` must be BLOCKED")
        if tier_id == "minimum":
            message = "unmeasured minimum row is not acceptable as performance evidence"
            if result.strict:
                result.errors.append(message)
            else:
                result.warnings.append(message)
        if measurement.get("samples") not in (None, 0):
            result.errors.append(f"unmeasured tier `{tier_id}` must not report samples")
        metrics = measurement.get("metrics", {})
        if (
            not isinstance(metrics, dict)
            or any(metrics.get(key) is not None for key in METRIC_KEYS)
        ):
            result.errors.append(f"unmeasured tier `{tier_id}` must keep metrics null")
        if measurement_host.get("status") != "not_measured":
            result.errors.append(f"unmeasured tier `{tier_id}` must label host not_measured")
        if renderer.get("status") != "not_measured":
            result.errors.append(f"unmeasured tier `{tier_id}` must label renderer not_measured")
        return

    if measurement_status != "measured":
        result.errors.append(
            f"tier `{tier_id}` measurement status must be measured or "
            f"unmeasured, got {measurement_status!r}"
        )
        return

    if result.strict and tier_status != "PASS":
        result.errors.append(f"strict evidence requires tier `{tier_id}` status PASS")
    host_matches_target = _identity_matches(
        measurement_host,
        target_hardware if isinstance(target_hardware, dict) else {},
    )
    if not host_matches_target:
        result.errors.append(
            f"tier `{tier_id}` measurement host does not match target hardware"
        )
    if renderer.get("status") != "measured" or renderer.get("headless") is not False:
        result.errors.append(
            f"tier `{tier_id}` needs a measured non-headless renderer identity"
        )
    metrics = measurement.get("metrics")
    if not isinstance(metrics, dict):
        result.errors.append(f"tier `{tier_id}` is missing measured metrics")
        return
    samples = measurement.get("samples")
    if not isinstance(samples, int) or isinstance(samples, bool):
        result.errors.append(f"tier `{tier_id}` samples must be an integer")
    elif samples < 120:
        result.errors.append(f"tier `{tier_id}` needs at least 120 frame samples")
    for key in METRIC_KEYS:
        value = metrics.get(key)
        if not _number(value):
            result.errors.append(f"tier `{tier_id}` metric `{key}` is unavailable")
            continue
        if float(value) > float(thresholds.get(key, math.inf)):
            result.errors.append(
                f"tier `{tier_id}` metric `{key}` exceeds water threshold: "
                f"{value} > {thresholds.get(key)}"
            )
    if tier_status not in {"PASS", "FAIL", "BLOCKED"}:
        result.errors.append(f"tier `{tier_id}` has invalid status {tier_status!r}")


def verify_report(report_path: Path = DEFAULT_REPORT, strict: bool = False) -> Verification:
    result = Verification(report_path=report_path, strict=strict)
    if not report_path.is_file():
        result.errors.append(f"missing water performance report: {report_path}")
        return result
    try:
        text = report_path.read_text(encoding="utf-8")
    except OSError as exc:
        result.errors.append(f"could not read water performance report: {exc}")
        return result
    _check_markdown_links(text, result)
    payload = _extract_payload(text, result)
    if payload is None:
        return result

    if payload.get("schema_version") != 1:
        result.errors.append(f"unsupported report schema: {payload.get('schema_version')!r}")
    if payload.get("report_id") != "r715-water-performance-v1":
        result.errors.append("report_id must be r715-water-performance-v1")
    if payload.get("owner_task") != "R-795":
        result.errors.append("owner_task must identify R-795 independent verification")
    if payload.get("budget_scope") != "water_only":
        result.errors.append("report budget_scope must be water_only")

    source = payload.get("source")
    if not isinstance(source, dict) or source.get("owner_task") != "R-755":
        result.errors.append("report must identify R-755 as the upstream measurement owner")
    else:
        config_path = _repo_path(source.get("generic_scene_config"))
        config = (
            _load_json(config_path, "generic benchmark config", result)
            if config_path
            else None
        )
        if config is not None and source.get("generic_scene_budget_use") != "comparison_only":
            result.errors.append("generic scene budgets must be marked comparison_only")
        expected_outputs = source.get("expected_water_outputs", [])
        if not isinstance(expected_outputs, list) or len(expected_outputs) != 2:
            result.errors.append("source must list minimum and recommended water outputs")
        elif strict:
            for expected in expected_outputs:
                if not isinstance(expected, dict) or expected.get("status") != "available":
                    result.errors.append("strict evidence requires both R-755 water outputs")
                elif (
                    not _repo_path(expected.get("path"))
                    or not _repo_path(expected.get("path")).is_file()
                ):
                    result.errors.append(
                        "missing R-755 water benchmark output: "
                        f"{expected.get('path')}"
                    )

    minimum_profile = _load_json(
        ROOT / "tools/benchmarks/minimum-hardware.json",
        "minimum hardware profile",
        result,
    )
    recommended_profile = _load_json(
        ROOT / "tools/benchmarks/target_hardware.json",
        "recommended hardware profile",
        result,
    )
    tiers = payload.get("tiers")
    if not isinstance(tiers, list):
        result.errors.append("tiers must be an array")
        tiers = []
    seen: set[str] = set()
    for index, tier in enumerate(tiers):
        if isinstance(tier, dict):
            tier_id = str(tier.get("id", ""))
            if tier_id in seen:
                result.errors.append(f"duplicate water tier: {tier_id}")
            seen.add(tier_id)
        _validate_tier(tier, index, minimum_profile, recommended_profile, result)
    missing_tiers = [tier_id for tier_id in REQUIRED_TIERS if tier_id not in seen]
    if missing_tiers:
        result.errors.append("missing water tier(s): " + ", ".join(missing_tiers))

    if strict and not missing_tiers:
        tier_by_id = {
            str(tier.get("id")): tier
            for tier in tiers
            if isinstance(tier, dict)
        }
        source = payload.get("source", {})
        expected_outputs = (
            source.get("expected_water_outputs", [])
            if isinstance(source, dict)
            else []
        )
        for expected in expected_outputs:
            if not isinstance(expected, dict):
                _validate_benchmark_output(expected, {}, result)
                continue
            tier_id = str(expected.get("tier", ""))
            tier = tier_by_id.get(tier_id)
            if tier is None:
                result.errors.append(
                    f"R-755 output references unknown tier `{tier_id}`"
                )
                continue
            _validate_benchmark_output(expected, tier, result)

    recommendation = payload.get("recommendation")
    if recommendation not in {"PASS", "BLOCKED", "FAIL"}:
        result.errors.append(
            f"recommendation must be PASS, BLOCKED, or FAIL, got "
            f"{recommendation!r}"
        )
        recommendation = "INVALID"
    result.recommendation = str(recommendation)
    statuses = {
        str(tier.get("status"))
        for tier in tiers
        if isinstance(tier, dict)
    }
    expected_recommendation = (
        "FAIL"
        if "FAIL" in statuses
        else "BLOCKED"
        if "BLOCKED" in statuses
        else "PASS"
    )
    if recommendation != expected_recommendation:
        result.errors.append(
            f"recommendation {recommendation!r} does not match tier statuses; "
            f"expected {expected_recommendation}"
        )
    if strict and recommendation != "PASS":
        result.errors.append("strict evidence requires overall PASS")
    return result


def format_result(result: Verification) -> str:
    mode = "strict acceptance" if result.strict else "artifact contract"
    lines = [
        "R-715 water performance verification",
        f"  report: {result.report_path}",
        f"  mode: {mode}",
        f"  tiers checked: {result.tiers_checked}",
        f"  recommendation: {result.recommendation or 'UNKNOWN'}",
    ]
    if result.warnings:
        lines.append("  warnings:")
        lines.extend(f"    - {warning}" for warning in result.warnings)
    if result.errors:
        lines.append("  errors:")
        lines.extend(f"    - {error}" for error in result.errors)
    else:
        lines.append("  status: valid fail-closed water evidence artifact")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--report",
        type=Path,
        default=DEFAULT_REPORT,
        help="Markdown report to verify",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Require host-identified non-headless measurements and PASS for every tier",
    )
    args = parser.parse_args(argv)
    result = verify_report(args.report.resolve(), strict=args.strict)
    print(format_result(result))
    return 0 if result.valid else 1


if __name__ == "__main__":
    raise SystemExit(main())
