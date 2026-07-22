#!/usr/bin/env python3
"""Condense TODO.md: archive completed work, move notes to ROADMAP, reorder open tasks."""
from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TODO = ROOT / "TODO.md"
ARCHIVE = ROOT / "docs" / "TASK_ARCHIVE.md"
ROADMAP = ROOT / "docs" / "ROADMAP.md"

TASK_RE = re.compile(
    r"^- \[([ xX])\] ([^ |]+) \| deps: ([^|]+) \| deliverable: (.*)$"
)

REQUIRED_DONE = {
    *(f"P0-{n:03d}" for n in range(43, 47)),
    *(f"P2-{n:03d}" for n in range(18, 21)),
    "P4-014",
    "P4-015",
}

# Low campaign priority first; P0 baseline last.
PRIORITY_ORDER = ["P6", "P5", "P4", "P3", "P2", "P1", "P0"]


@dataclass
class Task:
    done: bool
    task_id: str
    deps: str
    raw: str


def priority_of(task_id: str) -> str:
    if task_id.startswith("D-"):
        return "D"
    match = re.match(r"^(P\d+)", task_id)
    return match.group(1) if match else "P9"


def complexity_score(task: Task) -> int:
    match = TASK_RE.match(task.raw)
    return len(match.group(4)) if match else 9999


def clean_deps(deps: str, done_ids: set[str]) -> str:
    if deps.strip() == "none":
        return "none"
    unresolved = [part.strip() for part in deps.split(",") if part.strip() not in done_ids]
    return "none" if not unresolved else ",".join(unresolved)


def rebuild_line(task: Task, done_ids: set[str]) -> str:
    match = TASK_RE.match(task.raw)
    if not match:
        return task.raw
    state = "x" if task.done else " "
    deps = clean_deps(match.group(3).strip(), done_ids) if not task.done else match.group(3).strip()
    return f"- [{state}] {match.group(2)} | deps: {deps} | deliverable: {match.group(4)}"


def parse_todo(text: str) -> tuple[list[str], list[str], list[str], list[Task]]:
    prefix: list[str] = []
    coord: list[str] = []
    section_notes: list[str] = []
    tasks: list[Task] = []
    in_coord = False
    header_done = False

    for line in text.splitlines():
        if line.startswith("## Immediate priorities"):
            in_coord = True
            continue
        if in_coord and line.startswith("## "):
            in_coord = False
        if in_coord:
            if line.startswith("Coordination note"):
                coord.append(line)
            elif line.strip():
                section_notes.append(line)
            continue
        match = TASK_RE.match(line)
        if match:
            tasks.append(
                Task(
                    done=match.group(1).lower() == "x",
                    task_id=match.group(2),
                    deps=match.group(3).strip(),
                    raw=line,
                )
            )
        elif not header_done and not line.startswith("## Completed"):
            if line.startswith("## "):
                header_done = True
            else:
                prefix.append(line)

    return prefix, coord, section_notes, tasks


def sort_open_tasks(open_tasks: list[Task]) -> list[Task]:
    def sort_key(task: Task) -> tuple[int, int, str]:
        priority = priority_of(task.task_id)
        try:
            priority_index = PRIORITY_ORDER.index(priority)
        except ValueError:
            priority_index = len(PRIORITY_ORDER)
        return (priority_index, complexity_score(task), task.task_id)

    return sorted(open_tasks, key=sort_key)


def complexity_label(task: Task) -> str:
    score = complexity_score(task)
    if score < 200:
        return "small"
    if score < 450:
        return "medium"
    return "large"


def build_archive(done_tasks: list[Task]) -> str:
    lines = [
        "# Task archive",
        "",
        "Completed tasks moved out of [`TODO.md`](../TODO.md) during the 2026-07-22 backlog cleanup.",
        "Git history remains the source of truth for exact closeout evidence.",
        "",
    ]
    current = ""
    for task in sorted(done_tasks, key=lambda t: t.task_id):
        priority = priority_of(task.task_id)
        if priority != current:
            current = priority
            lines.extend(["", f"## {current}", ""])
        lines.append(task.raw)
    lines.append("")
    return "\n".join(lines)


def build_roadmap(coord: list[str], section_notes: list[str]) -> str:
    lines = [
        "# Production roadmap",
        "",
        "Coordination notes, delivery order, and planning context formerly embedded in `TODO.md`.",
        "Executable open work stays in [`TODO.md`](../TODO.md).",
        "",
        "## Current focus (2026-07-22)",
        "",
        "1. **P0-078** - green clean-clone Godot baseline.",
        "2. **P0-072** - sourced 1343 Reval environment dossier per retained map.",
        "3. **P0-053** - slice surface and weathering kit.",
        "4. **P0-038 / P0-039 / P0-040** - measure, blind-read, and freeze ART_BIBLE v2.",
        "5. **P2-003 / P1-029 / P1-036** - modular environment kit, asset lint, composition audit.",
        "6. **P2-022 / P2-023 / P2-021** - Lower Town realism, landmark pass, parity gate.",
        "7. **P2-025 through P2-031** - district-life dressing, vegetation, fauna.",
        "8. Slice quest authoring (**P2-006** through **P2-012**) stays below environment realism until Lower Town reads as historically grounded Reval.",
        "",
        "Maintainer decision: environmental realism is the top production priority after **P0-078**.",
        "Sky/weather (**P0-075**) is accepted; do not reopen unless fixing a defect.",
        "",
        "Delivery order remains strict: playable demo, vertical-slice MVP, Act 1, Act 2, Act 3.",
        "Demo packaging (**D-003** through **D-004c**) is closed.",
        "",
        "Player-facing discoverability is part of every feature's definition of done.",
        "Any new player action, screen, or overlay must add a visible quick-access or contextual entry point;",
        "a hotkey alone is not sufficient.",
        "",
        "## Coordination history",
        "",
    ]
    lines.extend(coord)
    if section_notes:
        lines.extend(["", "## Archived planning notes", ""])
        lines.extend(section_notes)
    lines.append("")
    return "\n".join(lines)


def build_todo(prefix: list[str], open_tasks: list[Task], validator_done: list[Task], done_ids: set[str]) -> str:
    lines = [
        "# TODO",
        "",
        "Quick grab list for **open** work only. Order: low campaign priority first, then higher;",
        "within each band: small complexity before large.",
        "",
        "Format: `- [ ] ID | deps: unresolved ID,ID or none | deliverable: ... | verify: ...`",
        "",
        "References:",
        "- [`docs/ROADMAP.md`](docs/ROADMAP.md) - delivery order, coordination notes, current focus",
        "- [`docs/TASK_ARCHIVE.md`](docs/TASK_ARCHIVE.md) - completed tasks removed from this file",
        "",
        "<!-- Quick-reference counts updated on every structural change -->",
        "| Priority | Open | Done | Notes |",
        "|----------|-----:|-----:|-------|",
        "| PLACEHOLDER |",
        "",
    ]

    current_priority = ""
    current_complexity = ""
    for task in sort_open_tasks(open_tasks):
        priority = priority_of(task.task_id)
        complexity = complexity_label(task)
        if priority != current_priority:
            current_priority = priority
            current_complexity = ""
            title = {
                "P0": "P0 - Baseline, storage, materials, historical audit (highest priority)",
                "P1": "P1 - Runtime systems and content foundation",
                "P2": "P2 - Vertical-slice production (playable MVP)",
                "P3": "P3 - Slice validation, accessibility, performance, release",
                "P4": "P4 - Act 1: The Simmering City",
                "P5": "P5 - Act 2: The Fire of Rebellion",
                "P6": "P6 - Act 3: The Iron Harvest and full release (lowest priority)",
            }.get(priority, priority)
            lines.extend(["", f"## {title}", ""])
        if complexity != current_complexity:
            current_complexity = complexity
            lines.extend([f"### {complexity.title()}", ""])

        lines.append(rebuild_line(task, done_ids))

    lines.extend(
        [
            "",
            "## Completed (retained for plan verification)",
            "",
            "These rows stay here because `tools/verify_map_conversion_plan.py` requires their exact contracts.",
            "",
        ]
    )
    for task in sorted(validator_done, key=lambda t: t.task_id):
        lines.append(task.raw)

    lines.append("")
    return "\n".join(lines)


def main() -> None:
    text = TODO.read_text(encoding="utf-8")
    prefix, coord, section_notes, tasks = parse_todo(text)
    done_ids = {task.task_id for task in tasks if task.done}
    open_tasks = [task for task in tasks if not task.done]
    validator_done = [task for task in tasks if task.done and task.task_id in REQUIRED_DONE]
    archive_done = [task for task in tasks if task.done and task.task_id not in REQUIRED_DONE]

    ARCHIVE.write_text(build_archive(archive_done), encoding="utf-8")
    ROADMAP.write_text(build_roadmap(coord, section_notes), encoding="utf-8")

    new_todo = build_todo(prefix, open_tasks, validator_done, done_ids)
    TODO.write_text(new_todo, encoding="utf-8")

    import subprocess

    subprocess.run(["python3", str(ROOT / "tools" / "update_todo_counts.py"), "--write"], check=True)

    print(f"Open tasks: {len(open_tasks)}")
    print(f"Archived done: {len(archive_done)}")
    print(f"Validator-retained done: {len(validator_done)}")
    print(f"Wrote {ARCHIVE.relative_to(ROOT)} and {ROADMAP.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
