"""Slice performance manifest helpers for P3-011."""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from pathlib import Path

GDSCRIPT_CONST_RE = re.compile(
    r"const\s+(?P<name>[A-Z0-9_]+)\s*:=\s*(?P<value>[\d.]+)"
)

BUDGET_KEY_MAP = {
    "STEADY_FRAME_TIME_MS_P95": "steady_frame_time_ms_p95",
    "RESIDENT_MEMORY_DELTA_MIB": "resident_memory_delta_mib",
    "RESIDENT_NODE_COUNT": "resident_node_count",
    "RESIDENT_COLLISION_COUNT": "resident_collision_count",
    "BIRD_AUDIO_PEAK": "bird_audio_peak",
    "BIRD_FLIGHT_PEAK": "bird_flight_peak",
}

PROFILE_METRIC_MAP = {
    "frame_time_ms_p95": "steady_frame_time_ms_p95",
    "memory_delta_mib": "resident_memory_delta_mib",
    "node_count": "resident_node_count",
    "collision_count": "resident_collision_count",
    "bird_audio_peak": "bird_audio_peak",
    "bird_flight_peak": "bird_flight_peak",
}


@dataclass
class SlicePerformanceReport:
    busiest_scene_profile_id: str = ""
    budget_count: int = 0
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)

    @property
    def valid(self) -> bool:
        return not self.errors


def load_manifest(manifest_path: Path) -> dict:
    return json.loads(manifest_path.read_text(encoding="utf-8"))


def parse_godot_budgets(model_path: Path) -> dict[str, float]:
    text = model_path.read_text(encoding="utf-8")
    budgets: dict[str, float] = {}
    for match in GDSCRIPT_CONST_RE.finditer(text):
        key = BUDGET_KEY_MAP.get(match.group("name"))
        if key is None:
            continue
        budgets[key] = float(match.group("value"))
    return budgets


def load_benchmark_config_budgets(root: Path, manifest: dict) -> dict[str, float]:
    config_path = root / str(manifest["benchmark_config"])
    if not config_path.is_file():
        return {}
    payload = json.loads(config_path.read_text(encoding="utf-8"))
    return {str(key): float(value) for key, value in payload.get("budgets", {}).items()}


def verify_manifest_matches_model(root: Path, manifest_path: Path) -> SlicePerformanceReport:
    manifest = load_manifest(manifest_path)
    report = SlicePerformanceReport(
        busiest_scene_profile_id=str(manifest.get("busiest_scene_profile_id", "")),
        budget_count=len(manifest.get("budgets", {})),
    )

    model_path = root / str(manifest["godot_model"])
    if not model_path.is_file():
        report.errors.append(f"missing godot model: {model_path}")
        return report

    model_budgets = parse_godot_budgets(model_path)
    manifest_budgets = {
        str(key): float(value) for key, value in manifest.get("budgets", {}).items()
    }
    config_budgets = load_benchmark_config_budgets(root, manifest)

    for key, expected in manifest_budgets.items():
        if model_budgets.get(key) != expected:
            report.errors.append(
                f"model budget mismatch for {key}: manifest {expected}, model {model_budgets.get(key)}"
            )
        if config_budgets.get(key) != expected:
            report.errors.append(
                f"benchmark config mismatch for {key}: manifest {expected}, config {config_budgets.get(key)}"
            )

    minimum_hardware = root / str(manifest["minimum_hardware_profile"])
    if not minimum_hardware.is_file():
        report.errors.append(f"missing minimum hardware profile: {minimum_hardware}")

    maintainer_report = root / str(manifest.get("maintainer_report", ""))
    if not maintainer_report.is_file():
        report.errors.append(f"missing maintainer report: {maintainer_report}")

    busiest_scene = root / str(manifest.get("busiest_scene_path", ""))
    if not busiest_scene.is_file():
        report.errors.append(f"missing busiest scene: {busiest_scene}")

    return report


def verify_performance_report(
    root: Path,
    manifest_path: Path,
    report_path: Path,
) -> SlicePerformanceReport:
    manifest_report = verify_manifest_matches_model(root, manifest_path)
    if not manifest_report.valid:
        return manifest_report

    manifest = load_manifest(manifest_path)
    profile_id = str(manifest["busiest_scene_profile_id"])
    if not report_path.is_file():
        manifest_report.errors.append(f"missing performance report: {report_path}")
        return manifest_report

    payload = json.loads(report_path.read_text(encoding="utf-8"))
    budget_summary = payload.get("budget_summary", {})
    profiles = budget_summary.get("profiles", {})
    profile = profiles.get(profile_id)
    if not isinstance(profile, dict):
        manifest_report.errors.append(
            f"performance report missing profile `{profile_id}` in budget_summary.profiles"
        )
        return manifest_report

    manifest_budgets = {
        str(key): float(value) for key, value in manifest.get("budgets", {}).items()
    }
    for metric in manifest.get("slice_gate_metrics", []):
        metric_name = str(metric)
        check = profile.get(metric_name)
        if not isinstance(check, dict):
            manifest_report.errors.append(f"profile `{profile_id}` missing metric `{metric_name}`")
            continue
        if not check.get("available", False):
            manifest_report.errors.append(
                f"profile `{profile_id}` metric `{metric_name}` is unavailable in report"
            )
            continue
        if not check.get("pass", False):
            manifest_report.errors.append(
                f"profile `{profile_id}` metric `{metric_name}` failed: "
                f"observed {check.get('observed')} > limit {check.get('limit')}"
            )
            continue
        budget_key = PROFILE_METRIC_MAP.get(metric_name, metric_name)
        limit = manifest_budgets.get(budget_key)
        if limit is not None and float(check.get("limit", -1.0)) != float(limit):
            manifest_report.errors.append(
                f"profile `{profile_id}` metric `{metric_name}` limit drift: "
                f"report {check.get('limit')} vs manifest {limit}"
            )

    headline = payload.get("headline", {})
    if headline:
        frame_p95 = float(headline.get("frame_time_ms_p95", 0.0))
        frame_limit = manifest_budgets["steady_frame_time_ms_p95"]
        if frame_p95 > frame_limit:
            manifest_report.errors.append(
                f"headline frame_time_ms_p95 {frame_p95} exceeds budget {frame_limit}"
            )

    return manifest_report


def format_report(report: SlicePerformanceReport) -> str:
    lines = [
        "Slice performance report (P3-011)",
        f"  busiest scene profile: {report.busiest_scene_profile_id}",
        f"  authored budgets: {report.budget_count}",
    ]
    if report.warnings:
        lines.append("  warnings:")
        for warning in report.warnings:
            lines.append(f"    - {warning}")
    if report.errors:
        lines.append("  errors:")
        for error in report.errors:
            lines.append(f"    - {error}")
    else:
        lines.append("  status: manifest and slice gates are valid")
    return "\n".join(lines)
