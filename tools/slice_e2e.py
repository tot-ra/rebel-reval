"""Slice end-to-end manifest helpers for P3-016."""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from pathlib import Path

GDSCRIPT_STRING_CONST_RE = re.compile(
    r"const\s+(?P<name>[A-Z0-9_]+)\s*:=\s*\"(?P<value>[^\"]*)\""
)


@dataclass
class SliceE2EReport:
    task_id: str = ""
    errors: list[str] = field(default_factory=list)

    @property
    def valid(self) -> bool:
        return not self.errors


def load_manifest(manifest_path: Path) -> dict:
    return json.loads(manifest_path.read_text(encoding="utf-8"))


def parse_godot_string_constants(model_path: Path) -> dict[str, str]:
    text = model_path.read_text(encoding="utf-8")
    return {
        match.group("name"): match.group("value")
        for match in GDSCRIPT_STRING_CONST_RE.finditer(text)
    }


def verify_manifest_matches_model(root: Path, manifest_path: Path) -> SliceE2EReport:
    manifest = load_manifest(manifest_path)
    report = SliceE2EReport(task_id=str(manifest.get("task_id", "")))

    model_path = root / str(manifest["godot_model"])
    if not model_path.is_file():
        report.errors.append(f"missing godot model: {model_path}")
        return report

    constants = parse_godot_string_constants(model_path)
    pairs = {
        "verify_script": "VERIFY_SCRIPT_PATH",
        "maintainer_report": "MAINTAINER_REPORT_PATH",
        "traversal_manifest": "TRAVERSAL_MANIFEST_PATH",
        "release_manifest": "RELEASE_MANIFEST_PATH",
        "platform_manifest": "PLATFORM_MANIFEST_PATH",
        "released_saves_manifest": "RELEASED_SAVES_MANIFEST_PATH",
    }
    for manifest_key, constant_name in pairs.items():
        expected = constants.get(constant_name, "").removeprefix("res://")
        actual = str(manifest.get(manifest_key, ""))
        if actual != expected:
            report.errors.append(
                f"{manifest_key} mismatch: manifest {actual!r}, model {expected!r}"
            )

    for script_name in ("TRAVERSAL_REPORT_SCRIPT", "RELEASE_REPORT_SCRIPT", "PLATFORM_REPORT_SCRIPT"):
        script_path = constants.get(script_name, "")
        if script_path and not (root / script_path).is_file():
            report.errors.append(f"missing python report script: {script_path}")

    for manifest_key in (
        "traversal_manifest",
        "release_manifest",
        "platform_manifest",
        "released_saves_manifest",
    ):
        path = root / str(manifest.get(manifest_key, ""))
        if not path.is_file():
            report.errors.append(f"missing referenced manifest: {path}")

    filters = manifest.get("godot_test_filters", [])
    if not isinstance(filters, list) or not filters:
        report.errors.append("godot_test_filters must be a non-empty list")
    else:
        required_filters = {
            "test_vertical_slice_traversal",
            "test_vertical_slice_flow",
            "test_vertical_slice_save_matrix",
            "test_vertical_slice_release",
            "test_save_envelope",
            "test_vertical_slice_e2e",
        }
        missing_filters = sorted(required_filters - {str(item) for item in filters})
        if missing_filters:
            report.errors.append(f"godot_test_filters missing required entries: {missing_filters}")

    scripts = manifest.get("python_report_scripts", [])
    if not isinstance(scripts, list) or not scripts:
        report.errors.append("python_report_scripts must be a non-empty list")

    traversal_manifest = root / str(manifest.get("traversal_manifest", ""))
    if traversal_manifest.is_file():
        traversal = load_manifest(traversal_manifest)
        expected_endings = int(manifest.get("intended_ending_count", 0))
        actual_endings = int(traversal.get("intended_ending_count", 0))
        if expected_endings != actual_endings:
            report.errors.append(
                "intended_ending_count mismatch with traversal manifest: "
                f"e2e {expected_endings}, traversal {actual_endings}"
            )
        expected_invalid = int(manifest.get("invalid_transition_count", 0))
        actual_invalid = int(traversal.get("invalid_transition_count", 0))
        if expected_invalid != actual_invalid:
            report.errors.append(
                "invalid_transition_count mismatch with traversal manifest: "
                f"e2e {expected_invalid}, traversal {actual_invalid}"
            )

    platform_manifest = root / str(manifest.get("platform_manifest", ""))
    if platform_manifest.is_file():
        platform = load_manifest(platform_manifest)
        expected_platforms = int(manifest.get("supported_platform_count", 0))
        actual_platforms = int(platform.get("supported_platform_count", 0))
        if expected_platforms != actual_platforms:
            report.errors.append(
                "supported_platform_count mismatch with platform manifest: "
                f"e2e {expected_platforms}, platform {actual_platforms}"
            )

    released_manifest = root / str(manifest.get("released_saves_manifest", ""))
    if released_manifest.is_file():
        released = load_manifest(released_manifest)
        fixtures = released.get("fixtures", [])
        if not isinstance(fixtures, list) or not fixtures:
            report.errors.append("released_manifest.json must list at least one fixture")
        else:
            for row in fixtures:
                if not isinstance(row, dict):
                    report.errors.append("released_manifest.json fixture rows must be objects")
                    break
                relative_path = str(row.get("path", ""))
                fixture_path = root / "content/saves" / relative_path
                if not fixture_path.is_file():
                    report.errors.append(f"missing published save fixture: {fixture_path}")

    maintainer_report = root / str(manifest.get("maintainer_report", ""))
    if not maintainer_report.is_file():
        report.errors.append(f"missing maintainer report: {maintainer_report}")

    verify_script = root / str(manifest.get("verify_script", ""))
    if not verify_script.is_file():
        report.errors.append(f"missing verify script: {verify_script}")

    return report


def format_report(report: SliceE2EReport) -> str:
    lines = [
        "Slice end-to-end manifest (P3-016)",
        f"  task id: {report.task_id or '<missing>'}",
    ]
    if report.errors:
        lines.append("Errors:")
        lines.extend(f"  - {error}" for error in report.errors)
    else:
        lines.append("Manifest matches authored end-to-end model.")
    return "\n".join(lines)
