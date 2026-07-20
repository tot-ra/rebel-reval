"""Canonical name, date, and source checks for active Markdown documentation."""

from __future__ import annotations

import re
from collections import defaultdict
from pathlib import Path

from active_docs_report_common import (
    CHARACTER_BULLET_RE,
    DATE_LINE_RE,
    HEADING_RE,
    MONTH_DAY_YEAR_RE,
    MONTH_YEAR_RE,
    REFERENCE_MARKER_RE,
    YEAR_RANGE_RE,
    YEAR_RE,
    Issue,
    read_text,
    rel,
    strip_code_spans,
)


def normalize_character_name(name: str) -> str:
    cleaned = re.sub(r"\s+", " ", name).strip()
    cleaned = re.sub(r"^(captain|master|brother|sister|viceroy|prince|bishop|king|queen)\s+", "", cleaned, flags=re.IGNORECASE)
    return cleaned.casefold()


def check_duplicate_character_names(active_docs: list[Path], root: Path) -> list[Issue]:
    occurrences: dict[str, list[tuple[Path, int, str]]] = defaultdict(list)
    for path in active_docs:
        in_character_section = False
        section_level = 0
        for line_number, raw_line in enumerate(read_text(path).splitlines(), start=1):
            heading = HEADING_RE.match(raw_line)
            if heading:
                level = len(heading.group(1))
                title = heading.group(2).strip().casefold()
                if title in {"characters", "main cast", "historical figures (mentioned/background)"}:
                    in_character_section = True
                    section_level = level
                elif in_character_section and level <= section_level:
                    in_character_section = False
            if not in_character_section:
                continue
            match = CHARACTER_BULLET_RE.match(raw_line)
            if not match:
                continue
            name = match.group(1).strip()
            key = normalize_character_name(name)
            if key:
                occurrences[key].append((path, line_number, name))

    issues: list[Issue] = []
    for _key, hits in sorted(occurrences.items()):
        unique_locations = {(path, line_number) for path, line_number, _name in hits}
        if len(unique_locations) <= 1:
            continue
        names = ", ".join(f"`{name}` at `{rel(path, root)}:{line_number}`" for path, line_number, name in hits)
        first_path, first_line, first_name = hits[0]
        issues.append(
            Issue(
                "DUPLICATE_CHARACTER_NAME",
                rel(first_path, root),
                first_line,
                f"Character name `{first_name}` appears more than once in active character lists: {names}",
            )
        )
    return issues


def normalize_event_label(label: str) -> str:
    # Parenthetical event names are common in timeline labels, for example
    # `April 23, 1343 (St. George's Night)`. Keep the parenthetical text so
    # the date can change while the event key remains comparable.
    label = re.sub(r"\(([^)]*)\)", r" \1 ", label)
    label = re.sub(r"\b(1[0-9]{3}|20[0-9]{2})\b", "", label)
    label = re.sub(r"\b(January|February|March|April|May|June|July|August|September|October|November|December)\b", "", label, flags=re.IGNORECASE)
    label = re.sub(r"\b[0-9]{1,2}\b", "", label)
    label = re.sub(r"\b(pre|late|early|mid|c\.?|ca\.?|circa)\b", "", label, flags=re.IGNORECASE)
    label = re.sub(r"[^\w\sõäöüÕÄÖÜ-]", " ", label, flags=re.UNICODE)
    return re.sub(r"\s+", " ", label).strip().casefold()


def extract_date_values(text: str) -> set[str]:
    values: set[str] = set()
    for month, day, year in MONTH_DAY_YEAR_RE.findall(text):
        values.add(f"{month.casefold()} {int(day)} {year}")
    for month, year in MONTH_YEAR_RE.findall(text):
        values.add(f"{month.casefold()} {year}")
    without_ranges = YEAR_RANGE_RE.sub("", text)
    for year in YEAR_RE.findall(without_ranges):
        values.add(year)
    for start, end in YEAR_RANGE_RE.findall(text):
        values.add(f"{start}-{end}")
    return values


def check_contradictory_dates(active_docs: list[Path], root: Path) -> list[Issue]:
    events: dict[str, list[tuple[Path, int, str, set[str]]]] = defaultdict(list)
    for path in active_docs:
        for line_number, line in enumerate(read_text(path).splitlines(), start=1):
            match = DATE_LINE_RE.match(line)
            if not match:
                continue
            label = match.group(1)
            event_key = normalize_event_label(label)
            dates = extract_date_values(label)
            if event_key and dates:
                events[event_key].append((path, line_number, label, dates))

    issues: list[Issue] = []
    for _event, hits in sorted(events.items()):
        unique_date_sets = {tuple(sorted(dates)) for _path, _line, _label, dates in hits}
        if len(unique_date_sets) <= 1:
            continue
        details = "; ".join(
            f"`{label}` at `{rel(path, root)}:{line_number}`"
            for path, line_number, label, _dates in hits
        )
        first_path, first_line, first_label, _dates = hits[0]
        issues.append(
            Issue(
                "CONTRADICTORY_DATE",
                rel(first_path, root),
                first_line,
                f"Event/date label `{first_label}` conflicts with another active date label: {details}",
            )
        )
    return issues


def check_missing_references(active_docs: list[Path], root: Path) -> list[Issue]:
    issues: list[Issue] = []
    for path in active_docs:
        for line_number, raw_line in enumerate(read_text(path).splitlines(), start=1):
            line = strip_code_spans(raw_line)
            if REFERENCE_MARKER_RE.search(line):
                issues.append(
                    Issue(
                        "MISSING_REFERENCE",
                        rel(path, root),
                        line_number,
                        "Active doc contains an explicit missing-reference marker.",
                    )
                )
    return issues
