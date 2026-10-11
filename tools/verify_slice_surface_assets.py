#!/usr/bin/env python3
"""Verify P0-053 slice-surface asset and provenance contract.

Checks the eight style-lock reference albedos under ``assets/materials/style_lock/``
against ``docs/MATERIAL_STYLE_LOCK_KIT.md`` and ``assets/SOURCES.csv``. Runtime
slice maps still use procedural pattern textures generated in GDScript; this tool
covers the file-backed textures that P0-053 must keep lint-clean before closeout.

Usage:
    python3 tools/verify_slice_surface_assets.py
"""

from __future__ import annotations

import csv
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STYLE_LOCK_DIR = ROOT / "assets" / "materials" / "style_lock"
SOURCES = ROOT / "assets" / "SOURCES.csv"
KIT_DOC = ROOT / "docs" / "MATERIAL_STYLE_LOCK_KIT.md"

REQUIRED_FAMILIES = (
    "stone",
    "plaster",
    "timber",
    "roof_tile",
    "mud",
    "cobble",
    "hay",
    "water",
)
TEXTURE_SIZE = 512
SOURCE_ID_PREFIX = "assets.materials.style_lock."
PROVENANCE_PLACEHOLDERS = {"unknown", "tbd"}
APPROVED_PROVENANCE_COLUMNS = (
    "creator_or_tool",
    "model_version",
    "prompt_or_url",
    "seed",
    "license",
)


@dataclass(frozen=True)
class SourceRow:
    asset_id: str
    path: str
    approval: str
    creator_or_tool: str
    model_version: str
    prompt_or_url: str
    seed: str
    license: str


def png_dimensions(path: Path) -> tuple[int, int]:
    header = path.read_bytes()[:24]
    if header[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path.relative_to(ROOT)} is not a PNG")
    width = int.from_bytes(header[16:20], "big")
    height = int.from_bytes(header[20:24], "big")
    return width, height


def read_style_lock_sources(*, root: Path = ROOT) -> dict[str, SourceRow]:
    sources = root / SOURCES.relative_to(ROOT)
    if not sources.is_file():
        raise FileNotFoundError(f"missing {sources.relative_to(root)}")

    rows: dict[str, SourceRow] = {}
    with sources.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        for line_number, row in enumerate(reader, start=2):
            asset_id = row.get("asset_id", "")
            if not asset_id.startswith(SOURCE_ID_PREFIX):
                continue
            family = asset_id.removeprefix(SOURCE_ID_PREFIX)
            if family in rows:
                raise ValueError(
                    f"duplicate style-lock asset_id {asset_id!r} first seen earlier in SOURCES.csv"
                )
            rows[family] = SourceRow(
                asset_id=asset_id,
                path=row.get("path", ""),
                approval=row.get("approval", ""),
                creator_or_tool=row.get("creator_or_tool", ""),
                model_version=row.get("model_version", ""),
                prompt_or_url=row.get("prompt_or_url", ""),
                seed=row.get("seed", ""),
                license=row.get("license", ""),
            )
    return rows


def validate(*, root: Path = ROOT) -> list[str]:
    errors: list[str] = []

    if not KIT_DOC.is_file():
        errors.append(f"missing kit doc: {KIT_DOC.relative_to(root)}")

    try:
        source_rows = read_style_lock_sources(root=root)
    except (OSError, ValueError) as exc:
        errors.append(str(exc))
        source_rows = {}

    missing_source_rows = sorted(set(REQUIRED_FAMILIES) - set(source_rows))
    extra_source_rows = sorted(set(source_rows) - set(REQUIRED_FAMILIES))
    if missing_source_rows:
        errors.append(
            "SOURCES.csv missing style-lock rows for: " + ", ".join(missing_source_rows)
        )
    if extra_source_rows:
        errors.append(
            "SOURCES.csv has unexpected style-lock families: " + ", ".join(extra_source_rows)
        )

    for family in REQUIRED_FAMILIES:
        rel_path = Path("assets/materials/style_lock") / f"{family}.png"
        abs_path = root / rel_path
        if not abs_path.is_file():
            errors.append(f"missing style-lock texture: {rel_path.as_posix()}")
            continue

        try:
            width, height = png_dimensions(abs_path)
        except ValueError as exc:
            errors.append(str(exc))
            continue

        if width != TEXTURE_SIZE or height != TEXTURE_SIZE:
            errors.append(
                f"{rel_path.as_posix()}: expected {TEXTURE_SIZE}x{TEXTURE_SIZE}, got {width}x{height}"
            )

        row = source_rows.get(family)
        if row is None:
            continue

        expected_path = rel_path.as_posix()
        if row.path != expected_path:
            errors.append(
                f"{row.asset_id}: SOURCES.csv path {row.path!r} != {expected_path!r}"
            )

        if not row.approval.startswith("approved"):
            errors.append(f"{row.asset_id}: approval must start with 'approved', got {row.approval!r}")

        if row.approval.startswith("approved"):
            for column in APPROVED_PROVENANCE_COLUMNS:
                value = getattr(row, column).strip()
                if value.casefold() in PROVENANCE_PLACEHOLDERS:
                    errors.append(
                        f"{row.asset_id}: approved asset has placeholder {column}: {value!r}"
                    )

    style_lock_dir = root / STYLE_LOCK_DIR.relative_to(ROOT)
    if style_lock_dir.is_dir():
        png_files = sorted(path.name for path in style_lock_dir.glob("*.png"))
        expected_files = [f"{family}.png" for family in REQUIRED_FAMILIES]
        extra_pngs = sorted(set(png_files) - set(expected_files))
        if extra_pngs:
            errors.append(
                "unexpected PNG files in style_lock/: " + ", ".join(extra_pngs)
            )

    return errors


def main() -> int:
    errors = validate()
    if errors:
        print("slice surface asset verification failed:")
        for error in errors:
            print(f"  - {error}")
        return 1

    print(
        f"slice surface asset verification passed "
        f"({len(REQUIRED_FAMILIES)} style-lock textures; provenance ok)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
