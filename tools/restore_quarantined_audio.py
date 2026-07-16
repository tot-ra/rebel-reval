#!/usr/bin/env python3
"""Restore maintainer-attested music and sounds from quarantine or archive to active paths."""

from __future__ import annotations

import csv
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
QUARANTINE = ROOT / "quarantine"
ARCHIVE = ROOT / "archive"
SOURCES = ROOT / "assets" / "SOURCES.csv"
RESTORE_ROOTS = ("music", "sounds")
RESTORE_MIRRORS = (QUARANTINE, ARCHIVE)

APPROVAL = "approved - maintainer AI generation"
CREATOR = "project maintainer"
MODEL = "AI music generation pipeline"
PROMPT = "music/README.md"
SEED = "n/a"
LICENSE = "AGPL-3.0-or-later (project author)"
EDITS = (
    "Maintainer-attested AI-generated soundtrack or SFX; "
    "prompts documented in music/README.md where applicable."
)


def restore_files() -> list[str]:
    restored: list[str] = []
    for mirror_root in RESTORE_MIRRORS:
        for root_name in RESTORE_ROOTS:
            source_root = mirror_root / root_name
            if not source_root.exists():
                continue
            for path in sorted(source_root.rglob("*")):
                if not path.is_file():
                    continue
                relative = path.relative_to(mirror_root)
                target = ROOT / relative
                if target.exists():
                    continue
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(path.as_posix(), target.as_posix())
                restored.append(relative.as_posix())
    return restored


def update_sources() -> int:
    rows: list[dict[str, str]] = []
    updated = 0
    with SOURCES.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        fieldnames = reader.fieldnames or []
        for row in reader:
            path = row.get("path", "")
            if path.startswith("music/") or path.startswith("sounds/"):
                row["creator_or_tool"] = CREATOR
                row["model_version"] = MODEL
                row["prompt_or_url"] = PROMPT
                row["seed"] = SEED
                row["license"] = LICENSE
                row["edits"] = EDITS
                row["approval"] = APPROVAL
                updated += 1
            rows.append(row)
    with SOURCES.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    return updated


def main() -> int:
    restored = restore_files()
    updated = update_sources()
    print(f"restored {len(restored)} file(s) from quarantine")
    print(f"updated {updated} SOURCES.csv row(s) to {APPROVAL}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
