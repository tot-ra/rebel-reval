#!/usr/bin/env python3
"""Losslessly optimize tracked evidence PNGs under docs/reports/images.

Used by P0-186 to shrink closed-task captures without changing dimensions or
pixel values accepted by the existing capture verifiers.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

try:
    from PIL import Image
except ImportError as exc:  # pragma: no cover - environment guard
    raise SystemExit("Pillow is required: pip install pillow") from exc

ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "docs" / "data" / "evidence_image_retention.json"
RASTER_SUFFIXES = {".png"}


def _listed_directories(manifest: dict) -> list[Path]:
    directories: list[Path] = []
    for key in ("active_directories", "archived_directories"):
        for row in manifest.get(key, []):
            rel_path = row.get("path")
            if isinstance(rel_path, str) and rel_path:
                directories.append(ROOT / rel_path)
    return directories


def optimize_png(path: Path) -> tuple[int, int]:
    before = path.stat().st_size
    with Image.open(path) as image:
        image.save(path, format="PNG", optimize=True, compress_level=9)
    after = path.stat().st_size
    return before, after


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--directory",
        action="append",
        default=[],
        help="optional repo-relative directory; defaults to all manifest directories",
    )
    parser.add_argument("--dry-run", action="store_true", help="report savings without writing")
    args = parser.parse_args(argv)

    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    if args.directory:
        directories = [ROOT / item for item in args.directory]
    else:
        directories = _listed_directories(manifest)

    total_before = 0
    total_after = 0
    touched = 0
    for directory in directories:
        if not directory.is_dir():
            print(f"skip missing directory: {directory.relative_to(ROOT)}")
            continue
        for path in sorted(directory.rglob("*.png")):
            if not path.is_file():
                continue
            before = path.stat().st_size
            total_before += before
            if args.dry_run:
                total_after += before
                continue
            _, after = optimize_png(path)
            total_after += after
            if after < before:
                touched += 1
                print(
                    f"optimized {path.relative_to(ROOT)}: "
                    f"{before} -> {after} bytes ({before - after} saved)"
                )

    if args.dry_run:
        print(f"dry-run: {total_before} bytes across scanned PNGs")
        return 0

    saved = total_before - total_after
    print(
        f"optimized {touched} PNG(s); {total_before} -> {total_after} bytes "
        f"({saved} saved)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
