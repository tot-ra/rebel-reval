#!/usr/bin/env python3
"""Recompress oversized historical reference plates under ``history/reference/``.

Applies the byte and dimension caps from ``docs/data/reference_plate_retention.json``
(P0-181). Fetched JPEG plates are downscaled to the configured long edge and saved at
the configured quality; ``history/reference/plates.csv`` checksum rows are refreshed.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError as exc:  # pragma: no cover - environment guard
    raise SystemExit("Pillow is required: pip install pillow") from exc

ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "docs" / "data" / "reference_plate_retention.json"
RASTER_SUFFIXES = {".jpg", ".jpeg", ".png", ".webp"}

PLATES_CSV = ROOT / "history" / "reference" / "plates.csv"
PLATE_FIELDNAMES = [
    "plate_id",
    "domain",
    "slug",
    "shows",
    "source",
    "dated",
    "origin",
    "page_url",
    "image_url",
    "creator",
    "license",
    "license_url",
    "status",
    "local_path",
    "sha256",
    "notes",
]


def load_policy(path: Path = MANIFEST_PATH) -> dict:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError("reference plate retention manifest root must be an object")
    return payload


def load_plate_rows(path: Path = PLATES_CSV) -> list[dict[str, str]]:
    if not path.is_file():
        return []
    import csv

    with path.open(newline="", encoding="utf-8") as handle:
        return [dict(row) for row in csv.DictReader(handle)]


def save_plate_rows(path: Path, rows: list[dict[str, str]]) -> None:
    import csv

    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=PLATE_FIELDNAMES)
        writer.writeheader()
        for row in rows:
            writer.writerow({key: row.get(key, "") for key in PLATE_FIELDNAMES})


def needs_optimization(
    path: Path,
    *,
    max_bytes: int,
    max_long_edge: int,
    exceptions: set[str],
) -> bool:
    rel = path.relative_to(ROOT).as_posix()
    if rel in exceptions:
        return False
    if path.stat().st_size > max_bytes:
        return True
    if path.suffix.lower() not in {".jpg", ".jpeg", ".png", ".webp"}:
        return False
    with Image.open(path) as image:
        width, height = image.size
    return max(width, height) > max_long_edge


def optimize_raster(
    path: Path,
    *,
    max_long_edge: int,
    jpeg_quality: int,
) -> tuple[int, int]:
    before = path.stat().st_size
    with Image.open(path) as image:
        width, height = image.size
        long_edge = max(width, height)
        if long_edge > max_long_edge:
            scale = max_long_edge / long_edge
            image = image.resize(
                (int(width * scale), int(height * scale)),
                Image.Resampling.LANCZOS,
            )
        if path.suffix.lower() in {".jpg", ".jpeg"}:
            image.save(path, format="JPEG", quality=jpeg_quality, optimize=True)
        elif path.suffix.lower() == ".png":
            image.save(path, format="PNG", optimize=True, compress_level=9)
        else:
            image.save(path)
    after = path.stat().st_size
    return before, after


def refresh_plate_checksums(rows: list[dict[str, str]], touched: set[str]) -> int:
    updated = 0
    for row in rows:
        local = row.get("local_path", "").strip()
        if not local or local not in touched:
            continue
        path = ROOT / local
        if not path.is_file():
            continue
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if digest != row.get("sha256", "").strip():
            row["sha256"] = digest
            updated += 1
    return updated


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="report candidates only")
    args = parser.parse_args(argv)

    policy_doc = load_policy()
    budget = policy_doc.get("budget", {})
    max_bytes = int(budget.get("max_raster_bytes", 8_388_608))
    max_long_edge = int(budget.get("max_long_edge_pixels", 2400))
    jpeg_quality = int(budget.get("jpeg_quality", 85))
    policy = policy_doc.get("policy", {})
    root = ROOT / policy.get("root", "history/reference")
    exceptions = {
        item.strip()
        for item in policy_doc.get("exceptions", [])
        if isinstance(item, str) and item.strip()
    }

    candidates: list[Path] = []
    for path in sorted(root.rglob("*")):
        if not path.is_file() or path.suffix.lower() not in RASTER_SUFFIXES:
            continue
        if needs_optimization(
            path,
            max_bytes=max_bytes,
            max_long_edge=max_long_edge,
            exceptions=exceptions,
        ):
            candidates.append(path)

    if not candidates:
        print("no oversized reference plates found")
        return 0

    total_before = sum(path.stat().st_size for path in candidates)
    if args.dry_run:
        for path in candidates:
            print(f"would optimize {path.relative_to(ROOT)} ({path.stat().st_size} bytes)")
        print(f"dry-run: {len(candidates)} file(s), {total_before} bytes")
        return 0

    touched: set[str] = set()
    total_after = 0
    for path in candidates:
        before, after = optimize_raster(
            path,
            max_long_edge=max_long_edge,
            jpeg_quality=jpeg_quality,
        )
        rel = path.relative_to(ROOT).as_posix()
        touched.add(rel)
        total_after += after
        print(
            f"optimized {rel}: {before} -> {after} bytes ({before - after} saved)"
        )

    rows = load_plate_rows()
    checksum_updates = refresh_plate_checksums(rows, touched)
    if checksum_updates:
        save_plate_rows(PLATES_CSV, rows)
        print(f"updated {checksum_updates} plates.csv checksum row(s)")

    saved = total_before - total_after
    print(
        f"optimized {len(candidates)} plate(s); {total_before} -> {total_after} bytes "
        f"({saved} saved)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
