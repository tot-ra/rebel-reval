"""Slice information design manifest helpers for P3-008."""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from pathlib import Path

GDSCRIPT_BEAT_RE = re.compile(
    r'"id":\s*"(?P<id>[^"]+)"\s*,\s*"phase":\s*"(?P<phase>[^"]+)"\s*,\s*"channels":\s*\[',
)
GDSCRIPT_CONCEPT_RE = re.compile(
    r'"id":\s*"(?P<id>[^"]+)"\s*,\s*"term":\s*"(?P<term>[^"]+)"\s*,\s*"context_beat_id":\s*"(?P<context>[^"]+)"',
)


@dataclass
class SliceInformationDesignReport:
    beat_count: int = 0
    historical_concept_count: int = 0
    errors: list[str] = field(default_factory=list)

    @property
    def valid(self) -> bool:
        return not self.errors


def load_manifest(manifest_path: Path) -> dict:
    return json.loads(manifest_path.read_text(encoding="utf-8"))


def parse_godot_model(model_path: Path) -> tuple[int, int]:
    text = model_path.read_text(encoding="utf-8")
    beat_count = len(GDSCRIPT_BEAT_RE.findall(text))
    concept_count = len(GDSCRIPT_CONCEPT_RE.findall(text))
    return beat_count, concept_count


def verify_manifest_matches_model(root: Path, manifest_path: Path) -> SliceInformationDesignReport:
    manifest = load_manifest(manifest_path)
    model_path = root / str(manifest["godot_model"])
    if not model_path.is_file():
        return SliceInformationDesignReport(errors=[f"missing godot model: {model_path}"])

    model_beats, model_concepts = parse_godot_model(model_path)
    report = SliceInformationDesignReport(
        beat_count=int(manifest.get("beat_count", 0)),
        historical_concept_count=int(manifest.get("historical_concept_count", 0)),
    )

    expected_beats = int(manifest.get("beat_count", 0))
    if model_beats != expected_beats:
        report.errors.append(
            f"beat_count mismatch: expected {expected_beats}, model has {model_beats}"
        )

    expected_concepts = int(manifest.get("historical_concept_count", 0))
    if model_concepts != expected_concepts:
        report.errors.append(
            f"historical_concept_count mismatch: expected {expected_concepts}, "
            f"model has {model_concepts}"
        )

    maintainer_report = root / str(manifest.get("maintainer_report", ""))
    if not maintainer_report.is_file():
        report.errors.append(f"missing maintainer report: {maintainer_report}")

    return report


def format_report(report: SliceInformationDesignReport) -> str:
    lines = [
        "Slice information design report (P3-008)",
        f"  information beats: {report.beat_count}",
        f"  historical concepts: {report.historical_concept_count}",
    ]
    if report.errors:
        lines.append("  errors:")
        for error in report.errors:
            lines.append(f"    - {error}")
    else:
        lines.append("  status: manifest matches authored model")
    return "\n".join(lines)
