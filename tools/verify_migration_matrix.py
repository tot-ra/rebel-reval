#!/usr/bin/env python3
"""Verify P0-034 migration matrix completeness and consistency."""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCENE_INVENTORY = ROOT / "docs" / "reports" / "scene_inventory.md"
ASSET_INVENTORY = ROOT / "docs" / "ASSET_INVENTORY.md"
MIGRATION_MATRIX = ROOT / "docs" / "reports" / "migration_matrix_p0_034.md"

REQUIRED_SECTIONS = (
    "Maps & Scenes",
    "TileSets",
    "Collisions",
    "Animations",
    "HUD",
    "Runtime Assets",
)
VALID_STATUSES = frozenset({"retain", "convert", "archive"})
# market.tscn was unified into reval_center and removed; keep only the guild hall stub.
SLICE_PLACEHOLDER_SCENES = frozenset(
    {
        "scenes/reval_center/market_civic_quarter/olaf_guild_hall.tscn",
    }
)
ASSET_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".svg", ".bmp", ".tga"}


@dataclass(frozen=True)
class MatrixRow:
    section: str
    artifact: str
    status: str


@dataclass(frozen=True)
class ValidationError:
    message: str


def _strip_inline_code(value: str) -> str:
    value = value.strip()
    match = re.match(r"`([^`]+)`", value)
    if match:
        return match.group(1).strip()
    return value.strip("`").strip()


def _normalize_status(raw: str) -> str:
    return _strip_inline_code(raw)


def parse_scene_inventory(path: Path) -> dict[str, str]:
    """Return scene path -> classification from the inventory table."""
    text = path.read_text(encoding="utf-8")
    scenes: dict[str, str] = {}
    for line in text.splitlines():
        match = re.match(
            r"^\| \d+ \| `([^`]+)` \| `?(working|partial|placeholder|archive)`? \|",
            line,
        )
        if match:
            scenes[match.group(1)] = match.group(2)
    return scenes


def required_scene_set(scene_inventory_path: Path) -> set[str]:
    scenes = parse_scene_inventory(scene_inventory_path)
    required = {
        scene
        for scene, classification in scenes.items()
        if classification in {"working", "partial"}
    }
    required.update(SLICE_PLACEHOLDER_SCENES)
    return required


def parse_asset_inventory(path: Path) -> list[str]:
    """Return ordered image asset paths from ASSET_INVENTORY per-file table."""
    text = path.read_text(encoding="utf-8")
    assets: list[str] = []
    in_section = False
    for line in text.splitlines():
        if line.startswith("## Per-file inventory"):
            in_section = True
            continue
        if in_section and line.startswith("## "):
            break
        match = re.match(r"^\| `([^`]+)` \| (image|audio) \|", line)
        if match and match.group(2) == "image":
            assets.append(match.group(1))
    return assets


def parse_migration_matrix(path: Path) -> tuple[dict[str, list[MatrixRow]], list[str]]:
    """Parse section headings and matrix rows."""
    text = path.read_text(encoding="utf-8")
    sections: dict[str, list[MatrixRow]] = {name: [] for name in REQUIRED_SECTIONS}
    found_sections: list[str] = []
    current: str | None = None

    for line in text.splitlines():
        heading = re.match(r"^## (.+)$", line)
        if heading:
            title = heading.group(1).strip()
            if title in sections:
                current = title
                found_sections.append(title)
            else:
                current = None
            continue
        if current is None:
            continue
        if not line.startswith("| `"):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) < 2:
            continue
        if cells[0] == "Artifact":
            continue
        if set(cell.replace("-", "").strip() for cell in cells) == {""}:
            continue
        artifact = _strip_inline_code(cells[0])
        status = _normalize_status(cells[1])
        sections[current].append(MatrixRow(current, artifact, status))
    return sections, found_sections


def artifact_base_path(artifact: str) -> str:
    """Strip count annotations and component suffixes for filesystem checks."""
    base = re.sub(r"\s+\(\d+\s+items?\)\s*$", "", artifact.strip())
    for sep in ("@", "#"):
        if sep in base:
            base = base.split(sep, 1)[0]
    return base


def is_scene_artifact(artifact: str) -> bool:
    return artifact_base_path(artifact).endswith(".tscn")


def is_asset_artifact(artifact: str) -> bool:
    base = artifact_base_path(artifact)
    if base.endswith("/*"):
        return True
    return Path(base).suffix.lower() in ASSET_EXTENSIONS


def resolve_glob_pattern(pattern: str, asset_paths: set[str]) -> set[str]:
    if not pattern.endswith("/*"):
        raise ValueError(f"unsupported glob pattern: {pattern}")
    prefix = pattern[:-1]
    if prefix.endswith("/"):
        prefix = prefix[:-1]
    return {path for path in asset_paths if path.startswith(prefix + "/")}


def resolve_artifact_paths(artifact: str, asset_paths: set[str]) -> set[str]:
    base = artifact_base_path(artifact)
    if base.endswith("/*"):
        return resolve_glob_pattern(base, asset_paths)
    return {base}


def validate_migration_matrix(
    *,
    root: Path,
    scene_inventory_path: Path,
    asset_inventory_path: Path,
    migration_matrix_path: Path,
) -> list[ValidationError]:
    errors: list[ValidationError] = []
    required_scenes = required_scene_set(scene_inventory_path)
    asset_list = parse_asset_inventory(asset_inventory_path)
    asset_paths = set(asset_list)
    sections, found_sections = parse_migration_matrix(migration_matrix_path)

    for section in REQUIRED_SECTIONS:
        if section not in found_sections:
            errors.append(ValidationError(f"missing required section: {section}"))

    seen_artifacts: dict[str, str] = {}
    covered_scenes: set[str] = set()
    covered_assets: set[str] = set()
    all_rows: list[MatrixRow] = []

    for section in REQUIRED_SECTIONS:
        all_rows.extend(sections.get(section, []))

    if not all_rows:
        errors.append(ValidationError("migration matrix contains no data rows"))
        return errors

    for row in all_rows:
        if row.status not in VALID_STATUSES:
            errors.append(
                ValidationError(
                    f"invalid status `{row.status}` for artifact `{row.artifact}` in {row.section}"
                )
            )

        if row.artifact in seen_artifacts:
            errors.append(
                ValidationError(
                    f"duplicate artifact `{row.artifact}` ({seen_artifacts[row.artifact]} and {row.section})"
                )
            )
        else:
            seen_artifacts[row.artifact] = row.section

        base = artifact_base_path(row.artifact)
        if base.endswith("/*"):
            resolved = resolve_artifact_paths(row.artifact, asset_paths)
            if not resolved:
                errors.append(ValidationError(f"glob resolves to zero assets: `{row.artifact}`"))
            covered_assets.update(resolved)
        else:
            path = root / base
            if is_scene_artifact(row.artifact) or base.endswith((".tscn", ".tres", ".gd")):
                if not path.exists():
                    errors.append(ValidationError(f"missing path for artifact `{row.artifact}`"))
            elif is_asset_artifact(row.artifact):
                if base not in asset_paths:
                    errors.append(
                        ValidationError(f"asset artifact not in ASSET_INVENTORY: `{row.artifact}`")
                    )
                covered_assets.add(base)
            else:
                if not path.exists():
                    errors.append(ValidationError(f"missing path for artifact `{row.artifact}`"))

        if row.section == "Maps & Scenes" and is_scene_artifact(row.artifact):
            covered_scenes.add(base)

    missing_scenes = sorted(required_scenes - covered_scenes)
    extra_scenes = sorted(covered_scenes - required_scenes)
    if missing_scenes:
        errors.append(
            ValidationError(
                "missing scene coverage: " + ", ".join(f"`{scene}`" for scene in missing_scenes)
            )
        )
    if extra_scenes:
        errors.append(
            ValidationError(
                "unexpected scene coverage: " + ", ".join(f"`{scene}`" for scene in extra_scenes)
            )
        )

    missing_assets = sorted(asset_paths - covered_assets)
    extra_assets = sorted(covered_assets - asset_paths)
    if missing_assets:
        errors.append(
            ValidationError(
                "missing asset coverage: " + ", ".join(f"`{asset}`" for asset in missing_assets)
            )
        )
    if extra_assets:
        errors.append(
            ValidationError(
                "extra asset coverage: " + ", ".join(f"`{asset}`" for asset in extra_assets)
            )
        )

    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--scene-inventory", type=Path, default=SCENE_INVENTORY)
    parser.add_argument("--asset-inventory", type=Path, default=ASSET_INVENTORY)
    parser.add_argument("--matrix", type=Path, default=MIGRATION_MATRIX)
    args = parser.parse_args(argv)

    errors = validate_migration_matrix(
        root=args.root,
        scene_inventory_path=args.scene_inventory,
        asset_inventory_path=args.asset_inventory,
        migration_matrix_path=args.matrix,
    )
    if errors:
        print("migration matrix verification failed:", file=sys.stderr)
        for error in errors:
            print(f"  - {error.message}", file=sys.stderr)
        return 1

    print("migration matrix verification passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
