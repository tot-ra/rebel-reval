#!/usr/bin/env python3
"""Verify the P0-113 tourist landmarks catalog contract."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LANDMARKS = ROOT / "docs" / "TOURIST_LANDMARKS.md"
CANON = ROOT / "docs" / "CANON.md"
GENERATOR = ROOT / "tools" / "generate_tourist_landmarks.py"

MIN_LANDMARKS = 10
MIN_FEATURED = 10
STATUS_LINE = re.compile(r"^\* \*\*1343 Status:\*\* ", re.MULTILINE)
MAP_LINE = re.compile(r"^\* \*\*Map Location:\*\* ", re.MULTILINE)
FEATURED_ROW = re.compile(r"^\| [^|]+ \| [^|]+ \| `", re.MULTILINE)
TASK_ROW = re.compile(r"^- \[([ x])\] (P0-113)\b", re.MULTILINE)


def validate(
    *,
    landmarks_text: str | None = None,
    canon_text: str | None = None,
    todo_text: str | None = None,
) -> list[str]:
    errors: list[str] = []

    if landmarks_text is None:
        if not LANDMARKS.is_file():
            return [f"missing catalog: {LANDMARKS.relative_to(ROOT)}"]
        landmarks_text = LANDMARKS.read_text(encoding="utf-8")

    if canon_text is None:
        if not CANON.is_file():
            errors.append(f"missing canon: {CANON.relative_to(ROOT)}")
            canon_text = ""
        else:
            canon_text = CANON.read_text(encoding="utf-8")

    status_count = len(STATUS_LINE.findall(landmarks_text))
    if status_count < MIN_LANDMARKS:
        errors.append(
            f"need at least {MIN_LANDMARKS} landmarks with 1343 status, found {status_count}"
        )

    map_count = len(MAP_LINE.findall(landmarks_text))
    if map_count < MIN_LANDMARKS:
        errors.append(
            f"need at least {MIN_LANDMARKS} map location bindings, found {map_count}"
        )

    if "CANON.md" not in landmarks_text:
        errors.append("TOURIST_LANDMARKS.md must link to docs/CANON.md")

    if "TOURIST_LANDMARKS" not in canon_text:
        errors.append("CANON.md must link back to TOURIST_LANDMARKS.md")

    if "## Featured tourist landmarks" not in landmarks_text:
        errors.append("missing featured tourist landmarks section")

    featured_count = len(FEATURED_ROW.findall(landmarks_text))
    if featured_count < MIN_FEATURED:
        errors.append(
            f"need at least {MIN_FEATURED} featured landmark rows, found {featured_count}"
        )

    if "# Appendix: Excluded Modern Landmarks" not in landmarks_text:
        errors.append("missing excluded-landmarks appendix")

    if todo_text is not None:
        match = TASK_ROW.search(todo_text)
        if match and match.group(1) != "x":
            errors.append("P0-113 is still open in TODO.md")

    return errors


def main() -> int:
    errors = validate()
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print(
        f"OK: tourist landmarks catalog satisfies P0-113 ({LANDMARKS.relative_to(ROOT)})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
