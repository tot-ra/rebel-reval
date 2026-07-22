#!/usr/bin/env python3
"""Verify the P0-072 historical environment dossier contract.

The dossier deliberately allows broad bounded reconstructions, but every retained
map still needs a complete, sourced card. Human review remains a separate gate:
structural validation may pass while review is pending, yet P0-072/P1-036 cannot
be marked complete until every review row is signed.
"""

from __future__ import annotations

import re
import sys
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOSSIER = ROOT / "docs" / "HISTORICAL_AUDIT.md"
REGISTRY = ROOT / "scripts" / "map" / "map_blueprint_registry.gd"
TODO = ROOT / "TODO.md"

CARD_START = "### Map-specific target cards"
CARD_END = "### Cross-map exclusions and required corrections"
REVIEW_START = "### Human historical review gate"

REQUIRED_CATEGORIES = (
    "Street/property layout",
    "Density",
    "Ordinary / exceptional buildings",
    "Roof covers",
    "Ground surfaces",
    "Drainage",
    "Fences / plot edges",
    "Vegetation species",
    "Garden / agricultural use",
    "Domestic / wild fauna",
    "Topography",
    "Landmarks",
)
REQUIRED_REVIEW_ITEMS = (
    "Evidence-class separation is clear and no later survival is presented as 1343 fact",
    "Eleven map cards match the registry and cover layout, density, buildings/materials, roofs, ground, drainage, fences, vegetation species, garden/agricultural use, fauna, topography and landmark state",
    "Built/open and surface bands are acceptable as bounded production targets",
    "Landmark exclusions and unknowns are historically conservative",
    "Approved for P1-036 and district quality-pass acceptance thresholds",
)
CONFIDENCE = re.compile(r"\*\*(?:[ABCDU](?:/[ABCDU])*)\*\*")
SOURCE_ID = re.compile(r"\bH\d{2}\b")
REGISTRY_ID = re.compile(r'"id"\s*:\s*&"([a-z0-9_]+)"')
CARD_HEADING = re.compile(r"^#### `([^`]+)`[^\n]*$", re.MULTILINE)
TASK_ROW = re.compile(r"^- \[([ x])\] (P0-072|P1-036)\b", re.MULTILINE)
SIGNED_DECISIONS = frozenset({"accepted", "amended"})


@dataclass(frozen=True)
class ReviewRow:
    item: str
    decision: str
    reviewer: str
    date: str
    notes: str


def _table_cells(line: str) -> list[str]:
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def parse_registry_ids(text: str) -> list[str]:
    return REGISTRY_ID.findall(text)


def parse_source_ids(text: str) -> set[str]:
    register_start = text.find("### Source register")
    register_end = text.find("### Shared 1343 constraints", register_start)
    if register_start < 0 or register_end < 0:
        return set()
    return {
        cells[0]
        for line in text[register_start:register_end].splitlines()
        if line.startswith("| H") and len(cells := _table_cells(line)) >= 4
    }


def parse_cards(text: str) -> list[tuple[str, dict[str, tuple[str, str]]]]:
    start = text.find(CARD_START)
    end = text.find(CARD_END, start)
    if start < 0 or end < 0:
        return []

    section = text[start + len(CARD_START) : end]
    headings = list(CARD_HEADING.finditer(section))
    cards: list[tuple[str, dict[str, tuple[str, str]]]] = []
    for index, heading in enumerate(headings):
        body_start = heading.end()
        body_end = headings[index + 1].start() if index + 1 < len(headings) else len(section)
        rows: dict[str, tuple[str, str]] = {}
        for line in section[body_start:body_end].splitlines():
            if not line.startswith("| ") or line.startswith(("| Category", "|---")):
                continue
            cells = _table_cells(line)
            if len(cells) == 3:
                rows[cells[0]] = (cells[1], cells[2])
        cards.append((heading.group(1), rows))
    return cards


def parse_review_rows(text: str) -> list[ReviewRow]:
    start = text.find(REVIEW_START)
    if start < 0:
        return []
    rows: list[ReviewRow] = []
    for line in text[start:].splitlines():
        if not line.startswith("| ") or line.startswith(("| Review item", "|---")):
            continue
        cells = _table_cells(line)
        if len(cells) != 5:
            continue
        rows.append(ReviewRow(cells[0], cells[1].strip("` ").lower(), *cells[2:]))
    return rows


def completed_gate_tasks(todo_text: str) -> set[str]:
    return {task_id for marker, task_id in TASK_ROW.findall(todo_text) if marker == "x"}


def review_is_signed(rows: list[ReviewRow]) -> bool:
    if {row.item for row in rows} != set(REQUIRED_REVIEW_ITEMS):
        return False
    for row in rows:
        if row.decision not in SIGNED_DECISIONS or not row.reviewer or not row.date:
            return False
        if row.decision == "amended" and not row.notes:
            return False
    return True


def validate(*, dossier_text: str, registry_text: str, todo_text: str) -> list[str]:
    errors: list[str] = []
    registry_ids = parse_registry_ids(registry_text)
    duplicate_registry_ids = sorted(
        map_id for map_id, count in Counter(registry_ids).items() if count > 1
    )
    if duplicate_registry_ids:
        errors.append("duplicate registry IDs: " + ", ".join(duplicate_registry_ids))

    cards = parse_cards(dossier_text)
    card_ids = [map_id for map_id, _rows in cards]
    duplicate_cards = sorted(
        map_id for map_id, count in Counter(card_ids).items() if count > 1
    )
    if duplicate_cards:
        errors.append("duplicate dossier cards: " + ", ".join(duplicate_cards))

    missing_cards = sorted(set(registry_ids) - set(card_ids))
    unknown_cards = sorted(set(card_ids) - set(registry_ids))
    if missing_cards:
        errors.append("registry maps missing dossier cards: " + ", ".join(missing_cards))
    if unknown_cards:
        errors.append("dossier cards absent from registry: " + ", ".join(unknown_cards))

    source_ids = parse_source_ids(dossier_text)
    if not source_ids:
        errors.append("source register is missing or empty")

    for map_id, rows in cards:
        categories = set(rows)
        missing_categories = sorted(set(REQUIRED_CATEGORIES) - categories)
        extra_categories = sorted(categories - set(REQUIRED_CATEGORIES))
        if missing_categories:
            errors.append(
                f"{map_id}: missing categories: {', '.join(missing_categories)}"
            )
        if extra_categories:
            errors.append(
                f"{map_id}: unknown categories: {', '.join(extra_categories)}"
            )
        for category, (target, evidence) in rows.items():
            if not CONFIDENCE.search(target):
                errors.append(f"{map_id}/{category}: target lacks A/B/C/D/U confidence")
            if not evidence:
                errors.append(f"{map_id}/{category}: evidence cell is empty")
            unknown_sources = sorted(set(SOURCE_ID.findall(evidence)) - source_ids)
            if unknown_sources:
                errors.append(
                    f"{map_id}/{category}: unknown source IDs: {', '.join(unknown_sources)}"
                )

    review_rows = parse_review_rows(dossier_text)
    review_items = [row.item for row in review_rows]
    duplicate_review_items = sorted(
        item for item, count in Counter(review_items).items() if count > 1
    )
    if duplicate_review_items:
        errors.append("duplicate human-review rows: " + ", ".join(duplicate_review_items))
    missing_review_items = sorted(set(REQUIRED_REVIEW_ITEMS) - set(review_items))
    unknown_review_items = sorted(set(review_items) - set(REQUIRED_REVIEW_ITEMS))
    if missing_review_items:
        errors.append("missing human-review rows: " + ", ".join(missing_review_items))
    if unknown_review_items:
        errors.append("unknown human-review rows: " + ", ".join(unknown_review_items))

    completed = completed_gate_tasks(todo_text)
    if completed and not review_is_signed(review_rows):
        errors.append(
            "human historical review must be fully signed before completing: "
            + ", ".join(sorted(completed))
        )

    return errors


def main() -> int:
    try:
        dossier_text = DOSSIER.read_text(encoding="utf-8")
        registry_text = REGISTRY.read_text(encoding="utf-8")
        todo_text = TODO.read_text(encoding="utf-8")
    except OSError as exc:
        print(f"historical dossier verification failed: {exc}", file=sys.stderr)
        return 1

    errors = validate(
        dossier_text=dossier_text,
        registry_text=registry_text,
        todo_text=todo_text,
    )
    if errors:
        print("historical dossier verification failed:")
        for error in errors:
            print(f"  - {error}")
        return 1

    cards = parse_cards(dossier_text)
    review_status = "signed" if review_is_signed(parse_review_rows(dossier_text)) else "pending"
    print(
        f"historical dossier verification passed ({len(cards)} registry cards; "
        f"human review {review_status})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
