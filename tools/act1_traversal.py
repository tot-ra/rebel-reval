"""Act 1 traversal manifest helpers for P4-011."""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from pathlib import Path

GDSCRIPT_INVALID_RE = re.compile(
    r'"id":\s*"(?P<id>invalid\.(?:climax|act1)\.[^"]+)"',
)
GDSCRIPT_INTENDED_BOUNDARY_RE = re.compile(
    r'endings\.append\("act_boundary:%s"\s*%\s*boundary\)',
)


@dataclass
class Act1TraversalReport:
    intended_endings: list[str] = field(default_factory=list)
    invalid_transition_ids: list[str] = field(default_factory=list)
    cycle_test_filters: list[str] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)

    @property
    def valid(self) -> bool:
        return not self.errors


def load_manifest(manifest_path: Path) -> dict:
    return json.loads(manifest_path.read_text(encoding="utf-8"))


def parse_godot_model(model_path: Path) -> tuple[list[str], list[str]]:
    text = model_path.read_text(encoding="utf-8")
    invalid_ids = GDSCRIPT_INVALID_RE.findall(text)
    return [], invalid_ids


def verify_manifest_matches_model(root: Path, manifest_path: Path) -> Act1TraversalReport:
    manifest = load_manifest(manifest_path)
    model_path = root / str(manifest["godot_model"])
    if not model_path.is_file():
        return Act1TraversalReport(errors=[f"missing godot model: {model_path}"])

    _, model_invalid_ids = parse_godot_model(model_path)
    report = Act1TraversalReport(
        intended_endings=list(manifest.get("intended_endings", [])),
        invalid_transition_ids=list(manifest.get("invalid_transition_ids", [])),
        cycle_test_filters=list(manifest.get("cycle_test_filters", [])),
    )

    manifest_invalid = set(report.invalid_transition_ids)
    model_invalid = set(model_invalid_ids)
    if manifest_invalid != model_invalid:
        missing = sorted(manifest_invalid - model_invalid)
        extra = sorted(model_invalid - manifest_invalid)
        if missing:
            report.errors.append(f"manifest lists invalid ids missing from model: {missing}")
        if extra:
            report.errors.append(f"model defines invalid ids missing from manifest: {extra}")

    expected_endings = int(manifest.get("intended_ending_count", 0))
    if len(report.intended_endings) != expected_endings:
        report.errors.append(
            "intended_ending_count mismatch: "
            f"expected {expected_endings}, got {len(report.intended_endings)}"
        )

    expected_invalid = int(manifest.get("invalid_transition_count", 0))
    if len(report.invalid_transition_ids) != expected_invalid:
        report.errors.append(
            "invalid_transition_count mismatch: "
            f"expected {expected_invalid}, got {len(report.invalid_transition_ids)}"
        )

    fixtures_manifest = root / str(manifest.get("fixtures_manifest", ""))
    if not fixtures_manifest.is_file():
        report.errors.append(f"missing fixtures manifest: {fixtures_manifest}")
    else:
        fixtures = load_manifest(fixtures_manifest).get("fixtures", [])
        if len(fixtures) != expected_endings:
            report.errors.append(
                f"fixtures manifest must list {expected_endings} boundary saves, got {len(fixtures)}"
            )

    return report


def format_report(report: Act1TraversalReport) -> str:
    lines = [
        "Act 1 traversal manifest (P4-011)",
        f"  intended endings: {len(report.intended_endings)}",
        f"  invalid transitions: {len(report.invalid_transition_ids)}",
        f"  cycle test filters: {len(report.cycle_test_filters)}",
    ]
    if report.errors:
        lines.append("Errors:")
        lines.extend(f"  - {error}" for error in report.errors)
    else:
        lines.append("Manifest matches authored traversal model.")
    return "\n".join(lines)
