"""Slice branch consequence manifest helpers for P3-005."""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from pathlib import Path

GDSCRIPT_GROUP_RE = re.compile(
    r'"id":\s*"(?P<id>[^"]+)"\s*,\s*"choices":\s*\[',
)
GDSCRIPT_CHOICE_RE = re.compile(
    r'\{\s*"id":\s*"(?P<id>[^"]+)"\s*,\s*"signature":\s*\[',
)


@dataclass
class SliceBranchConsequenceReport:
    choice_groups: list[str] = field(default_factory=list)
    choice_count: int = 0
    errors: list[str] = field(default_factory=list)

    @property
    def valid(self) -> bool:
        return not self.errors


def load_manifest(manifest_path: Path) -> dict:
    return json.loads(manifest_path.read_text(encoding="utf-8"))


def parse_godot_model(model_path: Path) -> tuple[list[str], int]:
    text = model_path.read_text(encoding="utf-8")
    group_ids = GDSCRIPT_GROUP_RE.findall(text)
    choice_count = len(GDSCRIPT_CHOICE_RE.findall(text))
    return group_ids, choice_count


def verify_manifest_matches_model(root: Path, manifest_path: Path) -> SliceBranchConsequenceReport:
    manifest = load_manifest(manifest_path)
    model_path = root / str(manifest["godot_model"])
    if not model_path.is_file():
        return SliceBranchConsequenceReport(errors=[f"missing godot model: {model_path}"])

    model_groups, model_choice_count = parse_godot_model(model_path)
    report = SliceBranchConsequenceReport(
        choice_groups=list(manifest.get("choice_groups", [])),
        choice_count=int(manifest.get("choice_count", 0)),
    )

    manifest_groups = list(manifest.get("choice_groups", []))
    if manifest_groups != model_groups:
        report.errors.append(
            "choice_groups mismatch: "
            f"manifest={manifest_groups}, model={model_groups}"
        )

    expected_groups = int(manifest.get("choice_group_count", 0))
    if len(model_groups) != expected_groups:
        report.errors.append(
            "choice_group_count mismatch: "
            f"expected {expected_groups}, model has {len(model_groups)}"
        )

    expected_choices = int(manifest.get("choice_count", 0))
    if model_choice_count != expected_choices:
        report.errors.append(
            "choice_count mismatch: "
            f"expected {expected_choices}, model has {model_choice_count}"
        )

    return report


def format_report(report: SliceBranchConsequenceReport) -> str:
    lines = [
        "Slice branch consequence report (P3-005)",
        f"  choice groups: {len(report.choice_groups)}",
        f"  choices: {report.choice_count}",
    ]
    if report.errors:
        lines.append("  errors:")
        for error in report.errors:
            lines.append(f"    - {error}")
    else:
        lines.append("  status: manifest matches authored model")
    return "\n".join(lines)
