"""Slice dialogue word-count helpers for P2-013."""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

CONTENT_ID_RE = re.compile(r"^[a-z][a-z0-9]*(?:\.[a-z0-9_]+)+$")
GDSCRIPT_STRING_RE = re.compile(r'"((?:\\.|[^"\\])*)"')
GDSCRIPT_CONST_ARRAY_RE = re.compile(
    r"const\s+(?P<name>[A-Z_][A-Z0-9_]*)\s*:\s*Array\[String\]\s*=\s*\[(?P<body>.*?)\]",
    re.DOTALL,
)
GDSCRIPT_CONST_DICT_RE = re.compile(
    r"const\s+(?P<name>[A-Z_][A-Z0-9_]*)\s*:\s*Dictionary\s*=\s*\{(?P<body>.*?)\n\}",
    re.DOTALL,
)


@dataclass
class WordCountLine:
    source: str
    field: str
    text: str
    words: int


@dataclass
class SliceDialogueReport:
    word_budget: int
    total_words: int
    lines: list[WordCountLine] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)

    @property
    def within_budget(self) -> bool:
        return self.total_words <= self.word_budget and not self.errors

    def grouped_totals(self) -> dict[str, int]:
        totals: dict[str, int] = {}
        for line in self.lines:
            totals[line.source] = totals.get(line.source, 0) + line.words
        return totals


def count_words(text: str) -> int:
    if not text:
        return 0
    return len(re.findall(r"[A-Za-z0-9']+(?:-[A-Za-z0-9']+)*", text))


def _append_line(
    lines: list[WordCountLine],
    source: str,
    field: str,
    text: str,
) -> None:
    if not isinstance(text, str) or not text.strip():
        return
    lines.append(WordCountLine(source=source, field=field, text=text, words=count_words(text)))


def _looks_like_content_id(value: str) -> bool:
    return bool(CONTENT_ID_RE.match(value))


def _collect_strings(value: Any, source: str, field: str, lines: list[WordCountLine]) -> None:
    if isinstance(value, str):
        if _looks_like_content_id(value):
            return
        _append_line(lines, source, field, value)
        return
    if isinstance(value, list):
        for index, item in enumerate(value):
            _collect_strings(item, source, f"{field}[{index}]", lines)
        return
    if isinstance(value, dict):
        for key, item in value.items():
            if key in {"id", "type", "speaker_id", "target_node_id", "next_node_id", "kind"}:
                continue
            if isinstance(key, str) and _looks_like_content_id(key):
                continue
            _collect_strings(item, source, f"{field}.{key}", lines)


def extract_dialogue_words(record: dict[str, Any], source: str) -> list[WordCountLine]:
    lines: list[WordCountLine] = []
    for node_index, node in enumerate(record.get("nodes") or []):
        if not isinstance(node, dict):
            continue
        _append_line(lines, source, f"nodes[{node_index}].text", node.get("text", ""))
        for choice_index, choice in enumerate(node.get("choices") or []):
            if not isinstance(choice, dict):
                continue
            _append_line(
                lines,
                source,
                f"nodes[{node_index}].choices[{choice_index}].text",
                choice.get("text", ""),
            )
            _append_line(
                lines,
                source,
                f"nodes[{node_index}].choices[{choice_index}].disabled_reason",
                choice.get("disabled_reason", ""),
            )
    return lines


def extract_bark_words(record: dict[str, Any], source: str) -> list[WordCountLine]:
    lines: list[WordCountLine] = []
    for entry_index, entry in enumerate(record.get("entries") or []):
        if not isinstance(entry, dict):
            continue
        _append_line(lines, source, f"entries[{entry_index}].text", entry.get("text", ""))
    return lines


def extract_commission_words(record: dict[str, Any], source: str) -> list[WordCountLine]:
    lines: list[WordCountLine] = []
    for field in ("title", "concrete_order", "hidden_contradiction", "night_consequence"):
        _append_line(lines, source, field, record.get(field, ""))
    for clue_index, clue in enumerate(record.get("investigation_clues") or []):
        if not isinstance(clue, dict):
            continue
        _append_line(lines, source, f"investigation_clues[{clue_index}].summary", clue.get("summary", ""))
    for option_index, option in enumerate(record.get("forging_options") or []):
        if not isinstance(option, dict):
            continue
        _append_line(lines, source, f"forging_options[{option_index}].label", option.get("label", ""))
    return lines


def extract_quest_words(record: dict[str, Any], source: str) -> list[WordCountLine]:
    lines: list[WordCountLine] = []
    for field in ("title", "summary"):
        _append_line(lines, source, field, record.get(field, ""))
    for objective_index, objective in enumerate(record.get("objectives") or []):
        if not isinstance(objective, dict):
            continue
        _append_line(lines, source, f"objectives[{objective_index}].text", objective.get("text", ""))
    for evidence_index, evidence in enumerate(record.get("journal_evidence") or []):
        if not isinstance(evidence, dict):
            continue
        _append_line(
            lines,
            source,
            f"journal_evidence[{evidence_index}].text",
            evidence.get("text", ""),
        )
    for outcome_index, outcome in enumerate(record.get("outcomes") or []):
        if not isinstance(outcome, dict):
            continue
        _append_line(lines, source, f"outcomes[{outcome_index}].summary", outcome.get("summary", ""))
    return lines


def _strings_from_const_array(source_text: str, const_name: str) -> list[str]:
    match = GDSCRIPT_CONST_ARRAY_RE.search(source_text)
    if match and match.group("name") != const_name:
        for candidate in GDSCRIPT_CONST_ARRAY_RE.finditer(source_text):
            if candidate.group("name") == const_name:
                match = candidate
                break
    if not match or match.group("name") != const_name:
        return []
    return [unescape_gdscript_string(value) for value in GDSCRIPT_STRING_RE.findall(match.group("body"))]


def _strings_from_const_dictionary(source_text: str, const_name: str) -> list[str]:
    for match in GDSCRIPT_CONST_DICT_RE.finditer(source_text):
        if match.group("name") != const_name:
            continue
        return [unescape_gdscript_string(value) for value in GDSCRIPT_STRING_RE.findall(match.group("body"))]
    return []


def unescape_gdscript_string(value: str) -> str:
    return bytes(value, "utf-8").decode("unicode_escape")


def extract_inline_script_words(path: Path) -> list[WordCountLine]:
    source = str(path)
    text = path.read_text(encoding="utf-8")
    lines: list[WordCountLine] = []

    if path.name == "forge_prologue_controller.gd":
        for index, hint in enumerate(_strings_from_const_array(text, "HINTS")):
            _append_line(lines, source, f"HINTS[{index}]", hint)
        for match in re.finditer(r'prompt_label:\s*"([^"]+)"', text):
            _append_line(lines, source, "prompt_label", match.group(1))
        for match in re.finditer(r',\s*\n\s*"([^"]+\[E\])"', text):
            _append_line(lines, source, "interact_prompt", match.group(1))
        return lines

    if path.name == "forge_feedback_sequence.gd":
        for const_name in ("PHASE_HEADINGS", "PHASE_BODY", "OPTION_OBJECT_REVEAL"):
            for index, value in enumerate(_strings_from_const_dictionary(text, const_name)):
                _append_line(lines, source, f"{const_name}[{index}]", value)
        return lines

    if path.name == "reflection_model.gd":
        prose_fields = (
            "title",
            "intro",
            "summary",
            "plain_text",
            "label",
        )
        for match in GDSCRIPT_STRING_RE.finditer(text):
            value = unescape_gdscript_string(match.group(1))
            if _looks_like_content_id(value):
                continue
            if "%" in value and re.search(r"%[dfs]", value):
                _append_line(lines, source, "template", value)
                continue
            if any(token in value for token in prose_fields) and len(value.split()) <= 2:
                continue
            if len(value.split()) < 2 and value not in {"Duty", "Fury", "Mercy", "Hingepuu"}:
                continue
            _append_line(lines, source, "display", value)
        return _dedupe_lines(lines)

    if path.name == "bitter_brew_night_consequence.gd":
        for label in ("Surrender", "Escape", "Bypass", "Retry"):
            _append_line(lines, source, "button", label)
        return lines

    if path.name in {"forge_commission_overlay.gd", "forge_feedback_overlay.gd", "forge_commission_model.gd"}:
        for match in re.finditer(r'\.text\s*=\s*"([^"]+)"', text):
            value = match.group(1)
            if _looks_like_content_id(value):
                continue
            _append_line(lines, source, "ui.text", value)
        for match in re.finditer(r'_add_field_row\([^,]+,\s*"([^"]+)"\)', text):
            _append_line(lines, source, "ui.field", match.group(1))
        for match in re.finditer(r'return\s+"([^"]+)"', text):
            value = match.group(1)
            if _looks_like_content_id(value):
                continue
            _append_line(lines, source, "ui.return", value)
        return _dedupe_lines(lines)

    return lines


def _dedupe_lines(lines: list[WordCountLine]) -> list[WordCountLine]:
    seen: set[tuple[str, str, str]] = set()
    unique: list[WordCountLine] = []
    for line in lines:
        key = (line.source, line.field, line.text)
        if key in seen:
            continue
        seen.add(key)
        unique.append(line)
    return unique


def index_content_records(content_dir: Path) -> dict[str, tuple[Path, dict[str, Any]]]:
    index: dict[str, tuple[Path, dict[str, Any]]] = {}
    for path in sorted(content_dir.rglob("*.json")):
        payload = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(payload, dict):
            continue
        content_id = payload.get("id")
        if isinstance(content_id, str):
            index[content_id] = (path, payload)
    return index


def build_report(root: Path, manifest_path: Path | None = None) -> SliceDialogueReport:
    manifest_file = manifest_path or root / "docs/data/slice_dialogue_manifest.json"
    manifest = json.loads(manifest_file.read_text(encoding="utf-8"))
    content_dir = root / str(manifest["content_directory"])
    index = index_content_records(content_dir)
    report = SliceDialogueReport(
        word_budget=int(manifest.get("word_budget", 2500)),
        total_words=0,
    )

    def require_record(content_id: str) -> tuple[Path, dict[str, Any]] | None:
        entry = index.get(content_id)
        if entry is None:
            report.errors.append(f"missing content record: {content_id}")
            return None
        return entry

    for content_id in manifest.get("dialogue_ids", []):
        entry = require_record(content_id)
        if entry is None:
            continue
        path, record = entry
        report.lines.extend(extract_dialogue_words(record, f"{content_id} ({path.name})"))

    for content_id in manifest.get("bark_pool_ids", []):
        entry = require_record(content_id)
        if entry is None:
            continue
        path, record = entry
        report.lines.extend(extract_bark_words(record, f"{content_id} ({path.name})"))

    for content_id in manifest.get("commission_ids", []):
        entry = require_record(content_id)
        if entry is None:
            continue
        path, record = entry
        report.lines.extend(extract_commission_words(record, f"{content_id} ({path.name})"))

    for content_id in manifest.get("quest_ids", []):
        entry = require_record(content_id)
        if entry is None:
            continue
        path, record = entry
        report.lines.extend(extract_quest_words(record, f"{content_id} ({path.name})"))

    for script_path in manifest.get("inline_scripts", []):
        path = root / script_path
        if not path.is_file():
            report.errors.append(f"missing inline script: {script_path}")
            continue
        report.lines.extend(extract_inline_script_words(path))

    report.lines = _dedupe_lines(report.lines)
    report.total_words = sum(line.words for line in report.lines)
    return report


def format_report(report: SliceDialogueReport) -> str:
    lines = [
        "Slice dialogue word-count report (P2-013)",
        f"Budget: {report.word_budget}",
        f"Total spoken/displayed words: {report.total_words}",
        f"Within budget: {'yes' if report.within_budget else 'no'}",
        "",
        "Totals by source:",
    ]
    for source, total in sorted(report.grouped_totals().items(), key=lambda item: (-item[1], item[0])):
        lines.append(f"  {total:4d}  {source}")
    if report.errors:
        lines.extend(["", "Errors:"])
        lines.extend(f"  - {error}" for error in report.errors)
    return "\n".join(lines)
