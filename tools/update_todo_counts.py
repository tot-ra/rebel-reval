#!/usr/bin/env python3
"""Regenerate the TODO.md priority summary table from actual task rows.

Usage:
    python3 tools/update_todo_counts.py                         # show root counts
    python3 tools/update_todo_counts.py --path /tmp/TODO.md   # show selected counts
    python3 tools/update_todo_counts.py --write               # rewrite root table
    python3 tools/update_todo_counts.py --path /tmp/TODO.md --write
                                                              # rewrite selected table

Scans every `- [ ]` row in the selected TODO.md, extracts its priority (P0..P9, D),
counts open / done rows per bucket. The existing summary block right after
the header is replaced with a freshly computed Markdown table; everything else
in the file is left untouched.

Exit codes: 0 = success, 1 = TODO.md missing or unparseable. `scan_todo()` raises
`ValueError` when a task-like checklist row is missing required task fields.
"""
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
    "P3": ("P3", "Validation, accessibility, performance"),
    "P4": ("P4", "Act 1: The Simmering City"),
    "P5": ("P5", "Act 2: The Fire of Rebellion"),
    "P6": ("P6", "Act 3: The Iron Harvest and full release"),
    # Cross-cutting, worker-managed bands; listed last because they have no campaign order.
    "R": ("R ", "Historical research backlog (researcher-managed, cross-cutting)"),
    "A": ("A ", "Art and animation backlog (art-managed, cross-cutting)"),
}

# Everything above P6 collapses into one bucket.
OTHER_PREFIX = "P7+"


def _bucket_for(priority: str) -> str:
    if priority in PRIORITY_MAP:
        return priority
    # Strip numeric suffix letter (e.g. "P4-027a" → "P4") to map correctly.
    import re as _re
    base = _re.sub(r"\d+[a-z]*$", "", priority) if len(priority) > 2 else priority
    return _bucket_for(base) if base in PRIORITY_MAP or base == "D" else OTHER_PREFIX


def scan_todo(path: Path) -> dict[str, Counters]:
    text = path.read_text(encoding="utf-8")
    counts: dict[str, Counters] = {}

    # Match task rows: "- [ ]" or "- [x]"/"- [X]" followed by an ID like D-001 or P2-045.
    row_pattern = re.compile(r"^-\s+\[(?:[ xX])\]\s+(D|R|A|P\d+)-\d+[a-z]*\b(.*)$")
    fields_pattern = re.compile(r"\bdeps:\s*.*?\|\s*deliverable:")
    valid_pattern = re.compile(
        r"^-(?:\s+)\[(?:[ xX])\]\s+(D|R|A|P\d+)-\d+[a-z]*\b.*?deps:\s*(.*?)\s*\|\s*deliverable:"
    )

    for line_number, line in enumerate(text.splitlines(), start=1):
        stripped = line.strip()
        row_match = row_pattern.match(stripped)
        if not row_match:
            continue
        if not fields_pattern.search(row_match.group(2)):
            raise ValueError(
                f"line {line_number}: task row is missing `deps:` and `deliverable:` fields"
            )
        match = valid_pattern.match(stripped)
        if match is None:
            raise ValueError(f"line {line_number}: task row fields are malformed")
        priority = match.group(1)
        bucket = _bucket_for(priority)
        counters = counts.setdefault(bucket, Counters())
        is_done = stripped.lower().startswith("- [x]")
        if is_done:
            counters.done_count += 1
        else:
            counters.open_count += 1

    return counts


def build_table(counts: dict[str, Counters]) -> str:
    lines = ["| Priority | Open | Done | Notes |", "|----------|-----:|-----:|-------|"]
    for prefix in PRIORITY_MAP:
        c = counts.get(prefix)
        if not c:
            continue
        label, note = PRIORITY_MAP[prefix]
        lines.append(f"| {label} |  {c.open_count:>4}  |  {c.done_count:>4}  | {note} |")

    other = counts.get(OTHER_PREFIX)
    if other and (other.open_count or other.done_count):
        lines.append(
            f"| P7+ |  {other.open_count:>4}  |  {other.done_count:>4}  | "
            "Reserved for future priority bands |"
        )

    return "\n".join(lines)


def _read_preserving_newlines(path: Path) -> str:
    """Read text without normalizing newline sequences."""
    with path.open("r", encoding="utf-8", newline="") as handle:
        return handle.read()


def _newline_for(text: str) -> str:
    """Use the file's existing newline convention for generated content."""
    first_newline = re.search(r"\r\n|\r|\n", text)
    return first_newline.group(0) if first_newline else "\n"


def _write_preserving_newlines(path: Path, text: str) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        handle.write(text)


def rewrite_table(path: Path, new_table: str) -> bool:
    text = _read_preserving_newlines(path)
    newline = _newline_for(text)
    new_table = new_table.replace("\n", newline)
    comment = "<!-- Quick-reference counts updated on every structural change -->"

    # Match line boundaries independently from the file's preferred output newline.
    # `re.MULTILINE` only recognizes LF as a line start, so a CR-only file would
    # otherwise pass `_newline_for()` but fail to find its summary table.
    line_break = r"(?:\r\n|\r|\n)"
    table_pattern = re.compile(
        rf"(?<![^\r\n])<!-- Quick-reference counts.*?-->\s*{line_break}"
        rf"(?:\|[^\r\n]*(?:{line_break}|$))+"
    )
    m = table_pattern.search(text)
    if m:
        separator = newline * 2 if text.endswith(("\n", "\r")) or text[m.end() :] else ""
        new_text = (
            text[: m.start()]
            + comment
            + newline
            + new_table
            + separator
            + text[m.end() :]
        )
        _write_preserving_newlines(path, new_text)
        return True

    # Fallback when the comment anchor was removed but the summary table remains.
    bare_table = re.compile(
        rf"(?<![^\r\n])(?:\|[^\r\n]*(?:{line_break}|$))+"
    )
    for candidate in bare_table.finditer(text):
        if not candidate.group().startswith("| Priority |"):
            continue
        separator = newline * 2 if text.endswith(("\n", "\r")) or text[candidate.end() :] else ""
        new_text = (
            text[: candidate.start()]
            + comment
            + newline
            + new_table
            + separator
            + text[candidate.end() :]
        )
        _write_preserving_newlines(path, new_text)
        return True

    print("ERROR: existing priority summary table not found", file=sys.stderr)
    return False


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true", help="rewrite the table in TODO.md")
    parser.add_argument(
        "--path",
        type=Path,
        help="TODO.md path to scan (defaults to the repository root)",
    )
    args = parser.parse_args()

    root = Path(__file__).resolve().parent.parent
    todo_path = args.path or (root / "TODO.md")
    if not todo_path.exists():
        print(f"ERROR: {todo_path} not found", file=sys.stderr)
        return 1

    try:
        counts = scan_todo(todo_path)
    except ValueError as error:
        print(f"ERROR: {todo_path} is unparseable: {error}", file=sys.stderr)
        return 1
    except OSError as error:
        print(f"ERROR: {todo_path} could not be read: {error}", file=sys.stderr)
        return 1
    table = build_table(counts)
    print(table)

    if args.write:
        if rewrite_table(todo_path, table):
            print(f"\n-> {todo_path.name} summary table rewritten.")
        else:
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
