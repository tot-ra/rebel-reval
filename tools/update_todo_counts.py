#!/usr/bin/env python3
"""Regenerate the TODO.md priority summary table from actual task rows.

Usage:
    python3 tools/update_todo_counts.py              # show counts only
    python3 tools/update_todo_counts.py --write      # rewrite the table in-place

Scans every `- [ ]` row in `TODO.md`, extracts its priority (P0..P9, D), and
counts open / done rows per bucket. The existing summary block right after
the header is replaced with a freshly computed Markdown table; everything else
in the file is left untouched.

Exit codes: 0 = success, 1 = TODO.md missing or unparseable."""
from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path


@dataclass
class Counters:
    open_count: int = 0
    done_count: int = 0
    notes: list[str] = field(default_factory=list)


# Map priority prefixes to display buckets and human-readable notes.
PRIORITY_MAP: dict[str, tuple[str, str]] = {
    "D": ("D", "Demo / packaging"),
    "P0": ("P0", "Baseline, storage, materials, historical audit"),
    "P1": ("P1", "Runtime systems, content foundation"),
    "P2": ("P2", "Vertical-slice production (playable MVP)"),
}

# Everything else (P3..P9) collapses into one bucket.
OTHER_PREFIX = "P"


def _bucket_for(priority: str) -> str:
    if priority in PRIORITY_MAP:
        return priority
    return OTHER_PREFIX


def scan_todo(path: Path) -> dict[str, Counters]:
    text = path.read_text(encoding="utf-8")
    counts: dict[str, Counters] = {}

    # Match task rows: "- [ ]" or "- [x]" followed by an ID like D-001 or P2-045.
    pattern = re.compile(
        r"^-\s+\[(?:[ x])\]\s+(D|P\d+)-\d+[a-z]*\b.*?deps:\s*(.*?)\s*\|\s*deliverable:"
    )

    for line in text.splitlines():
        m = pattern.match(line.strip())
        if not m:
            continue
        priority, deps = m.group(1), m.group(2)
        bucket = _bucket_for(priority)
        counters = counts.setdefault(bucket, Counters())
        is_done = line.lstrip().startswith("- [x]")
        if is_done:
            counters.done_count += 1
        else:
            counters.open_count += 1

    return counts


def build_table(counts: dict[str, Counters]) -> str:
    lines = ["| Priority | Open | Done | Notes |", "|----------|-----:|-----:|-------|"]
    # Print in the canonical order, then any leftover buckets.
    for prefix in ("D", "P0", "P1", "P2"):
        c = counts.get(prefix)
        if not c:
            continue
        label, note = PRIORITY_MAP[prefix]
        lines.append(f"| {label} |  {c.open_count:>4}  |  {c.done_count:>4}  | {note} |")

    other = counts.get(OTHER_PREFIX)
    if other and (other.open_count or other.done_count):
        lines.append(
            f"| P3+ |  {other.open_count:>4}  |  {other.done_count:>4}  | "
            f"{'Reserved for future tasks; add items when created' if not other.open_count else 'Validation, accessibility, performance'} |"
        )

    return "\n".join(lines)


def rewrite_table(path: Path, new_table: str) -> bool:
    text = path.read_text(encoding="utf-8")
    comment = "<!-- Quick-reference counts updated on every structural change -->"

    table_pattern = re.compile(
        r"^<!-- Quick-reference counts.*?-->\s*\n(?:^\|[^\n]+\n)+",
        re.MULTILINE | re.DOTALL,
    )
    m = table_pattern.search(text)
    if m:
        new_text = (
            text[: m.start()]
            + comment
            + "\n"
            + new_table
            + "\n\n"
            + text[m.end() :]
        )
        path.write_text(new_text, encoding="utf-8")
        return True

    # Fallback when the comment anchor was removed but the summary table remains.
    bare_table = re.compile(r"^(?:^\|[^\n]+\n)+", re.MULTILINE)
    for candidate in bare_table.finditer(text):
        if not candidate.group().startswith("| Priority |"):
            continue
        new_text = (
            text[: candidate.start()]
            + comment
            + "\n"
            + new_table
            + "\n\n"
            + text[candidate.end() :]
        )
        path.write_text(new_text, encoding="utf-8")
        return True

    print("ERROR: existing priority summary table not found", file=sys.stderr)
    return False


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true", help="rewrite the table in TODO.md")
    args = parser.parse_args()

    root = Path(__file__).resolve().parent.parent
    todo_path = root / "TODO.md"
    if not todo_path.exists():
        print(f"ERROR: {todo_path} not found", file=sys.stderr)
        return 1

    counts = scan_todo(todo_path)
    table = build_table(counts)
    print(table)

    if args.write:
        if rewrite_table(todo_path, table):
            print("\n-> TODO.md summary table rewritten.")
        else:
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
