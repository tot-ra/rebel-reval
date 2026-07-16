#!/usr/bin/env python3
"""Apply legacy-status archive headers to speculative scene and NPC markdown.

P0-032 keeps historical location and character prose in place but marks every
file under scenes/ and characters/ (except index README files that already
declare legacy status) as archived research outside the vertical-slice scope.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

INDEX_READMES = {
    ROOT / "scenes" / "README.md",
    ROOT / "characters" / "README.md",
}

SCENE_DIRS = (ROOT / "scenes",)
CHARACTER_DIRS = (ROOT / "characters",)

LEGACY_STATUS_RE = re.compile(
    r"(?:^> \*\*Legacy status:\*\*|^legacy-status:)",
    re.IGNORECASE | re.MULTILINE,
)

SCENE_HEADER_TEMPLATE = """> **Legacy status:** `archive`  
> **Reason:** Speculative location design outside the approved vertical-slice scope.  
> **Current source of truth:** [`README.md`]({readme_rel}) - Vertical slice and scope boundaries; active prologue outline in [`docs/SCENES/the-makers-mark.md`]({scene_outline_rel}).

"""

CHARACTER_HEADER_TEMPLATE = """> **Legacy status:** `archive`  
> **Reason:** NPC roster entry outside the seven-character vertical-slice scope.  
> **Current source of truth:** [`README.md`]({readme_rel}) - Main cast; approved character briefs in [`docs/CHARACTERS/`]({characters_rel}).

"""


def os_relpath(from_dir: Path, to_path: Path) -> str:
    import os

    return os.path.relpath(to_path, from_dir)


def header_for(file_path: Path, kind: str) -> str:
    readme_rel = os_relpath(file_path.parent, ROOT / "README.md")
    if kind == "scene":
        outline_rel = os_relpath(file_path.parent, ROOT / "docs" / "SCENES" / "the-makers-mark.md")
        return SCENE_HEADER_TEMPLATE.format(readme_rel=readme_rel, scene_outline_rel=outline_rel)
    characters_rel = os_relpath(file_path.parent, ROOT / "docs" / "CHARACTERS")
    if not characters_rel.endswith("/"):
        characters_rel = f"{characters_rel}/"
    return CHARACTER_HEADER_TEMPLATE.format(readme_rel=readme_rel, characters_rel=characters_rel)


def should_skip(path: Path) -> bool:
    return path.resolve() in {index.resolve() for index in INDEX_READMES}


def has_legacy_status(text: str) -> bool:
    return bool(LEGACY_STATUS_RE.search(text))


def archive_file(path: Path, kind: str, dry_run: bool) -> bool:
    text = path.read_text(encoding="utf-8")
    if has_legacy_status(text):
        return False
    updated = header_for(path, kind) + text
    if dry_run:
        print(f"would archive: {path.relative_to(ROOT)}")
    else:
        path.write_text(updated, encoding="utf-8")
        print(f"archived: {path.relative_to(ROOT)}")
    return True


def iter_targets() -> list[tuple[Path, str]]:
    targets: list[tuple[Path, str]] = []
    for base, kind in ((SCENE_DIRS[0], "scene"), (CHARACTER_DIRS[0], "character")):
        if not base.exists():
            continue
        for path in sorted(base.rglob("*.md")):
            if should_skip(path):
                continue
            targets.append((path, kind))
    return targets


def main() -> int:
    parser = argparse.ArgumentParser(description="Apply P0-032 archive headers to scenes/ and characters/ markdown")
    parser.add_argument("--dry-run", action="store_true", help="print files that would be updated")
    args = parser.parse_args()

    changed = 0
    for path, kind in iter_targets():
        if archive_file(path, kind, args.dry_run):
            changed += 1

    action = "would update" if args.dry_run else "updated"
    print(f"{action} {changed} file(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
