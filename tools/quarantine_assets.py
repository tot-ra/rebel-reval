#!/usr/bin/env python3
"""Quarantine non-approved runtime assets outside Godot's import tree.

P0-029 keeps commercial-risk assets under quarantine/ with .gdignore so Godot
will not import them, while preserving the original repository-relative path below
that mirror for provenance and later restoration.
"""

from __future__ import annotations

import argparse
import csv
import re
import shutil
import sys
from pathlib import Path

from generate_asset_inventory import ROOT, RUNTIME_EXTENSIONS

SOURCES = ROOT / "assets" / "SOURCES.csv"
QUARANTINE_ROOT = ROOT / "quarantine"
QUARANTINE_GDIGNORE = QUARANTINE_ROOT / ".gdignore"
REFERENCE_FILE_SUFFIXES = {".tscn", ".tres", ".gd", ".godot"}
REFERENCE_RE = re.compile(r"res://((?:assets|music|sounds|img)/[^\"\n\)\]]+)")

# Visual prototype assets can still be required by active scenes.
# They are not approved for commercial builds, but replacing/removing them is
# deferred to P0-040 to avoid breaking current playable scene loading.
# Inconsistent legacy assets are hard-quarantined by P0-030.
SOFT_APPROVAL_MARKERS = (
    "prototype pending provenance/style review",
    "inconsistent prototype pending P0-040",
)
HARD_QUARANTINE_MARKERS = (
    "unknown rights",
    "archive - not active runtime",
    "inconsistent",
)


def read_sources() -> list[dict[str, str]]:
    with SOURCES.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def is_runtime_asset_path(path: str) -> bool:
    return Path(path).suffix.lower() in RUNTIME_EXTENSIONS and path.split("/", 1)[0] in {
        "assets",
        "music",
        "sounds",
        "img",
    }


def referenced_runtime_paths() -> set[str]:
    refs: set[str] = set()
    for path in ROOT.rglob("*"):
        if not path.is_file():
            continue
        if any(part in {".git", ".godot", "quarantine"} for part in path.relative_to(ROOT).parts):
            continue
        if path.name == "project.godot" or path.suffix in REFERENCE_FILE_SUFFIXES:
            text = path.read_text(encoding="utf-8", errors="ignore")
            refs.update(match.group(1) for match in REFERENCE_RE.finditer(text))
    return refs


def quarantine_path(original_path: str) -> Path:
    return QUARANTINE_ROOT / original_path


def approval_bucket(approval: str) -> str:
    if approval.startswith("approved"):
        return "approved"
    if any(marker in approval for marker in HARD_QUARANTINE_MARKERS):
        return "hard"
    if any(marker in approval for marker in SOFT_APPROVAL_MARKERS):
        return "soft"
    return "other_not_approved"


def candidate_paths(rows: list[dict[str, str]], refs: set[str]) -> tuple[set[str], set[str]]:
    """Return (must_quarantine, runtime_exception) original paths."""
    must_quarantine: set[str] = set()
    runtime_exception: set[str] = set()
    for row in rows:
        original = row["path"]
        if not is_runtime_asset_path(original):
            continue
        bucket = approval_bucket(row["approval"])
        if bucket == "approved":
            continue
        if bucket == "hard":
            must_quarantine.add(original)
            continue
        if original in refs:
            runtime_exception.add(original)
        else:
            must_quarantine.add(original)
    return must_quarantine, runtime_exception


def iter_import_sidecars(original: Path) -> list[Path]:
    return [Path(f"{original.as_posix()}.import")]


def move_one(src: Path, dst: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(src.as_posix(), dst.as_posix())


def apply_quarantine(paths: set[str]) -> None:
    QUARANTINE_ROOT.mkdir(parents=True, exist_ok=True)
    QUARANTINE_GDIGNORE.touch(exist_ok=True)
    for original_str in sorted(paths, key=str.casefold):
        original = ROOT / original_str
        target = quarantine_path(original_str)
        if original.exists():
            move_one(original, target)
        for sidecar in iter_import_sidecars(original):
            target_sidecar = Path(f"{target.as_posix()}.import")
            if sidecar.exists():
                move_one(sidecar, target_sidecar)


def check_quarantine(paths: set[str], exceptions: set[str], refs: set[str]) -> list[str]:
    errors: list[str] = []
    if not QUARANTINE_GDIGNORE.is_file():
        errors.append("missing quarantine/.gdignore")
    referenced_quarantined = sorted(paths & refs, key=str.casefold)
    if referenced_quarantined:
        errors.append(
            "runtime files reference quarantined paths: " + ", ".join(referenced_quarantined)
        )
    for original_str in sorted(paths, key=str.casefold):
        original = ROOT / original_str
        target = quarantine_path(original_str)
        if original.exists():
            errors.append(f"not quarantined at original path: {original_str}")
        if not target.is_file():
            errors.append(f"missing quarantined mirror file: quarantine/{original_str}")
        sidecar = Path(f"{original.as_posix()}.import")
        target_sidecar = Path(f"{target.as_posix()}.import")
        if sidecar.exists():
            errors.append(f"import sidecar left in active import path: {original_str}.import")
        if target.is_file() and not target_sidecar.is_file():
            errors.append(f"missing quarantined import sidecar: quarantine/{original_str}.import")
    for original_str in sorted(exceptions, key=str.casefold):
        if not (ROOT / original_str).is_file():
            errors.append(f"runtime exception missing from active path: {original_str}")
        if original_str not in refs:
            errors.append(f"runtime exception is no longer referenced and should be quarantined: {original_str}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description="Apply or verify P0-029 asset quarantine")
    parser.add_argument("--apply", action="store_true", help="move quarantine candidates into quarantine/")
    parser.add_argument("--check", action="store_true", help="verify quarantine state")
    args = parser.parse_args()
    if args.apply == args.check:
        parser.error("choose exactly one of --apply or --check")

    rows = read_sources()
    refs = referenced_runtime_paths()
    paths, exceptions = candidate_paths(rows, refs)

    if args.apply:
        apply_quarantine(paths)
        print(
            f"quarantined candidates: {len(paths)}; "
            f"active visual exceptions: {len(exceptions)}"
        )
        return 0

    errors = check_quarantine(paths, exceptions, refs)
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        print(
            f"checked quarantine candidates: {len(paths)}; "
            f"active visual exceptions: {len(exceptions)}",
            file=sys.stderr,
        )
        return 1
    print(
        f"quarantine ok; {len(paths)} candidates outside Godot import path; "
        f"{len(exceptions)} active visual exceptions documented"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
