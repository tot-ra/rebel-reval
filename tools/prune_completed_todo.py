#!/usr/bin/env python3
"""Move completed TODO rows to TASK_ARCHIVE.md while keeping validator-retained contracts."""
from __future__ import annotations

import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TODO = ROOT / "TODO.md"
ARCHIVE = ROOT / "docs" / "TASK_ARCHIVE.md"

TASK_RE = re.compile(
    r"^- \[([ xX])\] ([^ |]+) \|(?: role: ([^|]+) \|)? deps: ([^|]+) \| deliverable: (.*)$"
)
ID_RE = re.compile(r"^(D|P\d+)-\d+[a-z]*$")

REQUIRED_DONE = {
    *(f"P0-{n:03d}" for n in range(43, 47)),
    *(f"P2-{n:03d}" for n in range(18, 21)),
    "P4-014",
    "P4-015",
}


@dataclass
class TaskRow:
    done: bool
    task_id: str
    raw: str


def priority_of(task_id: str) -> str:
    if task_id.startswith("D-"):
        return "D"
    match = re.match(r"^(P\d+)", task_id)
    return match.group(1) if match else "P9"


def parse_task(line: str) -> TaskRow | None:
    match = TASK_RE.match(line)
    if not match:
        return None
    task_id = match.group(2)
    if not ID_RE.match(task_id):
        return None
    return TaskRow(done=match.group(1).lower() == "x", task_id=task_id, raw=line)


def archive_ids(text: str) -> set[str]:
    ids: set[str] = set()
    for line in text.splitlines():
        task = parse_task(line)
        if task:
            ids.add(task.task_id)
    return ids


def append_to_archive(new_rows: list[TaskRow]) -> None:
    if not new_rows:
        return
    archive_text = ARCHIVE.read_text(encoding="utf-8")
    existing = archive_ids(archive_text)
    to_add = [row for row in new_rows if row.task_id not in existing]
    if not to_add:
        return

    lines = archive_text.rstrip().splitlines()
    if "2026-09-25" not in archive_text:
        for index, line in enumerate(lines):
            if line.startswith("Git history remains"):
                lines.insert(
                    index + 1,
                    "Additional batches were appended on 2026-09-25 and later cleanups.",
                )
                break

    by_priority: dict[str, list[TaskRow]] = {}
    for row in sorted(to_add, key=lambda r: r.task_id):
        by_priority.setdefault(priority_of(row.task_id), []).append(row)

    for priority in sorted(by_priority.keys()):
        section = f"## {priority}"
        if section not in archive_text:
            lines.extend(["", section, ""])
        for row in by_priority[priority]:
            lines.append(row.raw)

    lines.append("")
    ARCHIVE.write_text("\n".join(lines), encoding="utf-8")


def should_keep_line(line: str, task: TaskRow | None) -> bool:
    if task is None:
        return True
    if not task.done:
        return True
    return task.task_id in REQUIRED_DONE


def prune_section_blocks(lines: list[str]) -> list[str]:
    """Drop empty ## sections (header with no task rows or substantive notes)."""
    out: list[str] = []
    index = 0
    while index < len(lines):
        line = lines[index]
        if line.startswith("## "):
            section_start = index
            index += 1
            body: list[str] = []
            while index < len(lines) and not lines[index].startswith("## "):
                body.append(lines[index])
                index += 1
            has_task = any(parse_task(row) for row in body if TASK_RE.match(row.strip()) or row.strip().startswith("- ["))
            has_note = any(
                row.strip()
                and not row.strip().startswith("- [")
                and not row.strip().startswith("See ")
                and not row.strip().startswith("Reference:")
                for row in body
            )
            if has_task or has_note:
                out.append(line)
                out.extend(body)
            continue
        out.append(line)
        index += 1
    return out


def collapse_blank_runs(lines: list[str]) -> list[str]:
    out: list[str] = []
    blank = False
    for line in lines:
        if not line.strip():
            if blank:
                continue
            blank = True
            out.append("")
        else:
            blank = False
            out.append(line)
    while out and not out[-1].strip():
        out.pop()
    out.append("")
    return out


def main() -> int:
    if not TODO.is_file():
        print("TODO.md missing", file=sys.stderr)
        return 1

    text = TODO.read_text(encoding="utf-8")
    to_archive: list[TaskRow] = []
    kept: list[str] = []

    for line in text.splitlines():
        task = parse_task(line)
        if task and task.done and task.task_id not in REQUIRED_DONE:
            to_archive.append(task)
            continue
        if should_keep_line(line, task):
            kept.append(line)

    kept = prune_section_blocks(kept)
    kept = collapse_blank_runs(kept)
    TODO.write_text("\n".join(kept), encoding="utf-8")
    append_to_archive(to_archive)

    subprocess.run(
        [sys.executable, str(ROOT / "tools" / "update_todo_counts.py"), "--write"],
        check=True,
    )

    print(f"Archived {len(to_archive)} completed rows")
    print(f"Retained validator contracts: {len(REQUIRED_DONE)} IDs")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
