"""Act 1 content-budget helpers for P4-010."""

from __future__ import annotations

import fnmatch
import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from slice_dialogue_words import (  # noqa: E402
    SliceDialogueReport,
    extract_bark_words,
    extract_commission_words,
    extract_dialogue_words,
    extract_inline_script_words,
    extract_quest_words,
    index_content_records,
)
from slice_soundtrack import probe_duration_seconds  # noqa: E402


@dataclass
class Act1ContentBudgetReport:
    district_count: int = 0
    core_character_count: int = 0
    cycle_quest_count: int = 0
    climax_quest_count: int = 0
    substantial_quest_count: int = 0
    faction_line_count: int = 0
    dialogue_words: int = 0
    dialogue_word_budget: int = 0
    audio_duration_seconds: float = 0.0
    audio_duration_budget_seconds: int = 0
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)

    @property
    def within_budget(self) -> bool:
        return not self.errors


def load_manifest(manifest_path: Path) -> dict[str, Any]:
    return json.loads(manifest_path.read_text(encoding="utf-8"))


def build_act1_dialogue_report(root: Path, dialogue_manifest_path: Path) -> SliceDialogueReport:
    dialogue_manifest = load_manifest(dialogue_manifest_path)
    index = _index_act1_content(root, dialogue_manifest)
    report = SliceDialogueReport(
        word_budget=int(dialogue_manifest.get("word_budget", 0)),
        total_words=0,
    )

    def require_record(content_id: str) -> tuple[Path, dict[str, Any]] | None:
        entry = index.get(content_id)
        if entry is None:
            report.errors.append(f"missing content record: {content_id}")
            return None
        return entry

    for content_id in dialogue_manifest.get("dialogue_ids", []):
        entry = require_record(content_id)
        if entry is None:
            continue
        path, record = entry
        report.lines.extend(extract_dialogue_words(record, f"{content_id} ({path.name})"))

    for content_id in dialogue_manifest.get("bark_pool_ids", []):
        entry = require_record(content_id)
        if entry is None:
            continue
        path, record = entry
        report.lines.extend(extract_bark_words(record, f"{content_id} ({path.name})"))

    for content_id in dialogue_manifest.get("commission_ids", []):
        entry = require_record(content_id)
        if entry is None:
            continue
        path, record = entry
        report.lines.extend(extract_commission_words(record, f"{content_id} ({path.name})"))

    for content_id in dialogue_manifest.get("quest_ids", []):
        entry = require_record(content_id)
        if entry is None:
            continue
        path, record = entry
        report.lines.extend(extract_quest_words(record, f"{content_id} ({path.name})"))

    for script_path in dialogue_manifest.get("inline_scripts", []):
        path = root / script_path
        if not path.is_file():
            report.errors.append(f"missing inline script: {script_path}")
            continue
        report.lines.extend(extract_inline_script_words(path))

    from slice_dialogue_words import _dedupe_lines  # noqa: E402

    report.lines = _dedupe_lines(report.lines)
    report.total_words = sum(line.words for line in report.lines)
    return report


def _index_act1_content(root: Path, dialogue_manifest: dict[str, Any]) -> dict[str, tuple[Path, dict[str, Any]]]:
    index: dict[str, tuple[Path, dict[str, Any]]] = {}
    for directory in dialogue_manifest.get("content_directories", []):
        content_dir = root / str(directory)
        if not content_dir.is_dir():
            continue
        index.update(index_content_records(content_dir))
    return index


def _quest_record_exists(root: Path, quest_id: str, manifest: dict[str, Any]) -> bool:
    search_dirs = [
        root / "content/examples/valid",
        root / "content/examples/support",
    ]
    search_dirs.extend(root / str(path) for path in manifest.get("quest_package_directories", []))
    for directory in search_dirs:
        if not directory.is_dir():
            continue
        for path in directory.rglob("quest*.json"):
            payload = json.loads(path.read_text(encoding="utf-8"))
            if isinstance(payload, dict) and payload.get("id") == quest_id:
                return True
    return False


def _collect_audio_tracks(root: Path, audio_manifest: dict[str, Any]) -> tuple[list[Path], list[str]]:
    tracks: list[Path] = []
    errors: list[str] = []
    excluded = list(audio_manifest.get("excluded_globs", []))
    for directory_rel in audio_manifest.get("track_directories", []):
        directory = root / str(directory_rel)
        if not directory.is_dir():
            errors.append(f"missing audio directory: {directory_rel}")
            continue
        for path in sorted(directory.rglob("*.mp3")):
            relative = str(path.relative_to(root)).replace("\\", "/")
            if any(fnmatch.fnmatch(relative, pattern) for pattern in excluded):
                continue
            tracks.append(path)
    return tracks, errors


def build_report(root: Path, manifest_path: Path | None = None) -> Act1ContentBudgetReport:
    manifest_file = manifest_path or root / "docs/data/act1_content_budget_manifest.json"
    manifest = load_manifest(manifest_file)
    report = Act1ContentBudgetReport(
        dialogue_word_budget=int(manifest.get("dialogue_word_budget", 0)),
        audio_duration_budget_seconds=int(manifest.get("audio_duration_budget_seconds", 0)),
    )

    district_ids = list(manifest.get("district_ids", []))
    report.district_count = len(district_ids)
    district_budget = int(manifest.get("district_budget", 0))
    if report.district_count != district_budget:
        report.errors.append(
            f"district count {report.district_count} must equal budget cap {district_budget}"
        )

    core_ids = list(manifest.get("core_character_ids", []))
    report.core_character_count = len(core_ids)
    core_budget = int(manifest.get("core_character_budget", 0))
    if report.core_character_count != core_budget:
        report.errors.append(
            f"core character count {report.core_character_count} must equal budget cap {core_budget}"
        )

    faction_cast_ids = list(manifest.get("faction_cast_ids", []))
    faction_cast_budget = int(manifest.get("faction_cast_budget", 0))
    if len(faction_cast_ids) != faction_cast_budget:
        report.errors.append(
            f"faction cast count {len(faction_cast_ids)} must equal budget cap {faction_cast_budget}"
        )

    cycle_ids = list(manifest.get("cycle_quest_ids", []))
    report.cycle_quest_count = len(cycle_ids)
    cycle_budget = int(manifest.get("cycle_budget", 0))
    if report.cycle_quest_count != cycle_budget:
        report.errors.append(
            f"cycle quest count {report.cycle_quest_count} must equal budget cap {cycle_budget}"
        )
    for quest_id in cycle_ids:
        if not _quest_record_exists(root, quest_id, manifest):
            report.errors.append(f"missing authored cycle quest: {quest_id}")

    climax_ids = list(manifest.get("climax_quest_ids", []))
    report.climax_quest_count = len(climax_ids)
    if report.climax_quest_count != 1:
        report.errors.append(f"Act 1 must ship exactly one climax quest, got {report.climax_quest_count}")
    for quest_id in climax_ids:
        if not _quest_record_exists(root, quest_id, manifest):
            report.errors.append(f"missing authored climax quest: {quest_id}")

    substantial_ids = list(manifest.get("substantial_quest_ids", []))
    report.substantial_quest_count = len(substantial_ids)
    substantial_budget = int(manifest.get("substantial_quest_budget", 0))
    if report.substantial_quest_count != substantial_budget:
        report.errors.append(
            "substantial quest count "
            f"{report.substantial_quest_count} must equal budget cap {substantial_budget}"
        )
    for quest_id in substantial_ids:
        if not _quest_record_exists(root, quest_id, manifest):
            report.errors.append(f"missing authored substantial quest: {quest_id}")

    planned_lines = list(manifest.get("planned_faction_lines", []))
    report.faction_line_count = len(planned_lines)
    line_budget = int(manifest.get("faction_quest_line_budget", 0))
    quests_per_line = int(manifest.get("faction_quests_per_line", 0))
    if report.faction_line_count != line_budget:
        report.errors.append(
            f"faction quest line count {report.faction_line_count} must equal budget cap {line_budget}"
        )
    for line in planned_lines:
        status = str(line.get("status", ""))
        quest_ids = list(line.get("quest_ids", []))
        if status == "planned" and quest_ids:
            report.errors.append(
                f"planned faction line {line.get('line_id')} must not list quest_ids until authored"
            )
        if status == "authored" and len(quest_ids) != quests_per_line:
            report.errors.append(
                f"authored faction line {line.get('line_id')} must list {quests_per_line} quests"
            )
        if status == "planned":
            report.warnings.append(
                f"faction line {line.get('line_id')} remains planned for P4-021 ({quests_per_line} quests each)"
            )

    dialogue_manifest_path = root / str(manifest.get("dialogue_manifest", ""))
    if not dialogue_manifest_path.is_file():
        report.errors.append(f"missing dialogue manifest: {dialogue_manifest_path}")
    else:
        dialogue_manifest = load_manifest(dialogue_manifest_path)
        dialogue_report = build_act1_dialogue_report(root, dialogue_manifest_path)
        report.dialogue_words = dialogue_report.total_words
        report.errors.extend(dialogue_report.errors)
        if report.dialogue_words > report.dialogue_word_budget:
            report.errors.append(
                "dialogue word count "
                f"{report.dialogue_words} exceeds budget {report.dialogue_word_budget}"
            )

        content_index = _index_act1_content(root, dialogue_manifest)
        for content_id in (
            list(dialogue_manifest.get("dialogue_ids", []))
            + list(dialogue_manifest.get("bark_pool_ids", []))
            + list(dialogue_manifest.get("commission_ids", []))
            + list(dialogue_manifest.get("quest_ids", []))
        ):
            if content_id not in content_index:
                report.errors.append(f"dialogue manifest references missing content record: {content_id}")

    audio_manifest_path = root / str(manifest.get("audio_manifest", ""))
    if not audio_manifest_path.is_file():
        report.errors.append(f"missing audio manifest: {audio_manifest_path}")
    else:
        audio_manifest = load_manifest(audio_manifest_path)
        tracks, audio_errors = _collect_audio_tracks(root, audio_manifest)
        report.errors.extend(audio_errors)
        unique_paths = sorted({str(path.resolve()) for path in tracks})
        total_duration = 0.0
        for track_path in unique_paths:
            try:
                total_duration += probe_duration_seconds(Path(track_path))
            except RuntimeError as exc:
                report.errors.append(str(exc))
        report.audio_duration_seconds = total_duration
        if report.audio_duration_seconds > report.audio_duration_budget_seconds:
            report.errors.append(
                "audio duration "
                f"{report.audio_duration_seconds:.1f}s exceeds budget "
                f"{report.audio_duration_budget_seconds}s"
            )

    return report


def format_report(report: Act1ContentBudgetReport) -> str:
    lines = [
        "Act 1 content-budget report (P4-010)",
        f"  districts: {report.district_count}",
        f"  core characters: {report.core_character_count}",
        f"  day/night cycles: {report.cycle_quest_count}",
        f"  climax quests: {report.climax_quest_count}",
        f"  substantial quests: {report.substantial_quest_count}",
        f"  faction quest lines: {report.faction_line_count}",
        f"  dialogue words: {report.dialogue_words} / {report.dialogue_word_budget}",
        (
            "  unique audio duration: "
            f"{report.audio_duration_seconds:.1f}s / {report.audio_duration_budget_seconds}s"
        ),
    ]
    if report.warnings:
        lines.append("Warnings:")
        lines.extend(f"  - {warning}" for warning in report.warnings)
    if report.errors:
        lines.append("Errors:")
        lines.extend(f"  - {error}" for error in report.errors)
    else:
        lines.append("Act 1 remains within the approved content budget.")
    return "\n".join(lines)
