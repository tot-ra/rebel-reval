#!/usr/bin/env python3
"""P1-029 automated asset lint for shipped runtime art.

Checks texture dimensions and seamless tiling (style-lock kit), character scale
contract constants, runtime character mesh presence, portrait dimensions when
present, asset naming, and provenance rows for lint-scoped assets.

Usage:
    python3 tools/verify_asset_lint.py
"""

from __future__ import annotations

import csv
import importlib.util
import re
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STYLE_LOCK_DIR = ROOT / "assets" / "materials" / "style_lock"
SOURCES = ROOT / "assets" / "SOURCES.csv"
CHARACTER_SCALE_GD = ROOT / "assets" / "characters" / "shared" / "character_scale.gd"
SHARED_RIG_GD = ROOT / "assets" / "characters" / "shared" / "shared_character_rig.gd"
PORTRAIT_RESOLVER_GD = ROOT / "scripts" / "dialogue" / "dialogue_portrait_resolver.gd"
CHARACTER_SPECS = ROOT / "tools" / "character_specs.py"
EQUIPMENT_SCENES = (
    "assets/characters/shared/hammer.tscn",
    "assets/characters/shared/spear.tscn",
)

TEXTURE_SIZE = 512
PORTRAIT_DISPLAY_PX = 96
PORTRAIT_ALLOWED_SIDES = frozenset({96, 192, 384, 512})
ASSET_ID_RE = re.compile(r"^[a-z0-9][a-z0-9._-]*$")
SNAKE_CASE_RE = re.compile(r"^[a-z0-9_]+$")
APPROVED_PROVENANCE_COLUMNS = (
    "creator_or_tool",
    "model_version",
    "prompt_or_url",
    "seed",
    "license",
)
PROVENANCE_PLACEHOLDERS = {"unknown", "tbd"}
MIN_CHARACTER_GLB_BYTES = 10_000

try:
    from PIL import Image
except ImportError:  # pragma: no cover - exercised only when Pillow is absent
    Image = None  # type: ignore[assignment,misc]

from verify_slice_surface_assets import (  # noqa: E402
    REQUIRED_FAMILIES,
    read_style_lock_sources,
    validate as validate_style_lock_assets,
)
from character_fidelity_tiers import (  # noqa: E402
    BUILD_INPUT_GLBS,
    GARMENT_GLBS,
    GARMENT_TEXTURE_MAX_PX,
    GARMENT_TRIANGLE_CAP,
    TIER_BUDGETS,
    classify_character_glb,
    inspect_glb,
    iter_runtime_character_glbs,
)
from fauna_glb_inspect import validate_fauna_glb_pbr  # noqa: E402


@dataclass(frozen=True)
class LintIssue:
    rule: str
    message: str

    def format(self) -> str:
        return f"[{self.rule}] {self.message}"


def _parse_gd_export_float(path: Path, name: str) -> float | None:
    if not path.is_file():
        return None
    pattern = re.compile(
        rf"@export[^\n]*\bvar\s+{re.escape(name)}\s*:\s*float\s*=\s*([0-9.]+)",
        re.MULTILINE,
    )
    match = pattern.search(path.read_text(encoding="utf-8"))
    if not match:
        return None
    return float(match.group(1))


def _character_outputs(root: Path) -> list[dict[str, str]]:
    specs_path = root / "tools" / "character_specs.py"
    if not specs_path.is_file():
        specs_path = CHARACTER_SPECS
    spec = importlib.util.spec_from_file_location("character_specs", specs_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"could not import {specs_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return list(module.CHARACTERS.values())


def _known_portrait_paths(root: Path) -> list[str]:
    resolver = root / "scripts" / "dialogue" / "dialogue_portrait_resolver.gd"
    if not resolver.is_file():
        return []
    text = resolver.read_text(encoding="utf-8")
    return re.findall(r'res://([^"]+\.(?:png|webp))', text)


def _rel_path(path: Path, root: Path) -> str:
    try:
        return path.relative_to(root).as_posix()
    except ValueError:
        return path.as_posix()


def _seamless_rgba(path: Path, root: Path) -> tuple[bool, str]:
    if Image is None:
        return True, ""
    image = Image.open(path).convert("RGBA")
    width, height = image.size
    pixels = image.load()
    rel = _rel_path(path, root)
    for y in range(height):
        for channel in range(4):
            if pixels[0, y][channel] != pixels[width - 1, y][channel]:
                return False, f"{rel}: left/right edge mismatch at y={y}"
    for x in range(width):
        for channel in range(4):
            if pixels[x, 0][channel] != pixels[x, height - 1][channel]:
                return False, f"{rel}: top/bottom edge mismatch at x={x}"
    return True, ""


def _parse_gd_float_constant(path: Path, name: str) -> float | None:
    if not path.is_file():
        return None
    pattern = re.compile(rf"^\s*const\s+{re.escape(name)}\s*:=\s*([0-9.]+)", re.MULTILINE)
    match = pattern.search(path.read_text(encoding="utf-8"))
    if not match:
        return None
    return float(match.group(1))


def _read_sources(root: Path) -> list[dict[str, str]]:
    sources = root / SOURCES.relative_to(ROOT)
    if not sources.is_file():
        raise FileNotFoundError(f"missing {sources.relative_to(root)}")
    with sources.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def validate(*, root: Path = ROOT) -> list[LintIssue]:
    issues: list[LintIssue] = []

    for message in validate_style_lock_assets(root=root):
        if "expected 512x512" in message or "missing style-lock texture" in message:
            issues.append(LintIssue("ASSET_LINT_TEXTURE_DIMENSION", message))
        elif "unexpected PNG files" in message or "path" in message and "style-lock" in message:
            issues.append(LintIssue("ASSET_LINT_NAMING", message))
        elif "placeholder" in message or "approval must start" in message:
            issues.append(LintIssue("ASSET_LINT_PROVENANCE", message))
        elif "SOURCES.csv" in message:
            issues.append(LintIssue("ASSET_LINT_PROVENANCE", message))
        else:
            issues.append(LintIssue("ASSET_LINT_TEXTURE_DIMENSION", message))

    if Image is not None:
        for family in REQUIRED_FAMILIES:
            path = root / STYLE_LOCK_DIR.relative_to(ROOT) / f"{family}.png"
            if not path.is_file():
                continue
            ok, detail = _seamless_rgba(path, root)
            if not ok:
                issues.append(LintIssue("ASSET_LINT_SEAMLESS_TILE", detail))
    else:
        issues.append(
            LintIssue(
                "ASSET_LINT_SEAMLESS_TILE",
                "Pillow is required for seamless tiling checks; install Pillow in CI",
            )
        )

    target_height = _parse_gd_float_constant(root / CHARACTER_SCALE_GD.relative_to(ROOT), "TARGET_VISIBLE_HEIGHT_PX")
    visible_world = _parse_gd_float_constant(root / CHARACTER_SCALE_GD.relative_to(ROOT), "VISIBLE_HEIGHT_WORLD")
    rig_visible_world = _parse_gd_export_float(root / SHARED_RIG_GD.relative_to(ROOT), "visible_height_world")
    if target_height != 64.0:
        issues.append(
            LintIssue(
                "ASSET_LINT_CHARACTER_SCALE",
                f"CharacterScale.TARGET_VISIBLE_HEIGHT_PX must be 64.0, got {target_height!r}",
            )
        )
    if visible_world != 2.0:
        issues.append(
            LintIssue(
                "ASSET_LINT_CHARACTER_SCALE",
                f"CharacterScale.VISIBLE_HEIGHT_WORLD must be 2.0, got {visible_world!r}",
            )
        )
    if rig_visible_world != 2.0:
        issues.append(
            LintIssue(
                "ASSET_LINT_CHARACTER_SCALE",
                f"SharedCharacterRig.visible_height_world must be 2.0, got {rig_visible_world!r}",
            )
        )

    try:
        specs = _character_outputs(root)
    except (OSError, SyntaxError, AttributeError) as exc:
        issues.append(LintIssue("ASSET_LINT_CHARACTER_MESH", str(exc)))
        specs = []

    for entry in specs:
        rel_output = entry.get("output", "")
        if not rel_output:
            continue
        basename = Path(rel_output).name
        stem = Path(rel_output).stem
        if not SNAKE_CASE_RE.fullmatch(stem):
            issues.append(
                LintIssue(
                    "ASSET_LINT_NAMING",
                    f"{rel_output}: runtime character glb filename must be snake_case",
                )
            )
        glb_path = root / rel_output
        if not glb_path.is_file():
            issues.append(
                LintIssue("ASSET_LINT_CHARACTER_MESH", f"missing runtime character glb: {rel_output}")
            )
            continue
        if glb_path.stat().st_size < MIN_CHARACTER_GLB_BYTES:
            issues.append(
                LintIssue(
                    "ASSET_LINT_CHARACTER_MESH",
                    f"{rel_output}: file is too small to be a generated body glb",
                )
            )
        if basename != f"{stem}.glb":
            issues.append(
                LintIssue(
                    "ASSET_LINT_NAMING",
                    f"{rel_output}: character glb basename must match snake_case stem",
                )
            )

    for rel_scene in EQUIPMENT_SCENES:
        scene_path = root / rel_scene
        if not scene_path.is_file():
            issues.append(
                LintIssue("ASSET_LINT_CHARACTER_MESH", f"missing equipment prop scene: {rel_scene}")
            )
            continue
        text = scene_path.read_text(encoding="utf-8")
        first_node = next(
            (line for line in text.splitlines() if line.startswith("[node ")),
            "",
        )
        if "type=\"Node3D\"" not in first_node:
            issues.append(
                LintIssue(
                    "ASSET_LINT_CHARACTER_MESH",
                    f"{rel_scene}: equipment prop root must be a Node3D grip mount",
                )
            )

    for rel_path in _known_portrait_paths(root):
        portrait_path = root / rel_path
        if not portrait_path.is_file():
            continue
        if Image is None:
            continue
        with Image.open(portrait_path) as image:
            width, height = image.size
        if width != height:
            issues.append(
                LintIssue(
                    "ASSET_LINT_PORTRAIT_DIMENSION",
                    f"{rel_path}: portrait must be square, got {width}x{height}",
                )
            )
            continue
        if width not in PORTRAIT_ALLOWED_SIDES:
            issues.append(
                LintIssue(
                    "ASSET_LINT_PORTRAIT_DIMENSION",
                    f"{rel_path}: portrait side must be one of {sorted(PORTRAIT_ALLOWED_SIDES)}, got {width}",
                )
            )
        if width % PORTRAIT_DISPLAY_PX != 0:
            issues.append(
                LintIssue(
                    "ASSET_LINT_PORTRAIT_DIMENSION",
                    f"{rel_path}: portrait side must be a multiple of {PORTRAIT_DISPLAY_PX}px",
                )
            )

    try:
        source_rows = _read_sources(root)
    except OSError as exc:
        issues.append(LintIssue("ASSET_LINT_PROVENANCE", str(exc)))
        source_rows = []

    rows_by_path = {row.get("path", ""): row for row in source_rows}
    for entry in specs:
        rel_output = entry.get("output", "")
        row = rows_by_path.get(rel_output)
        if row is None:
            issues.append(
                LintIssue(
                    "ASSET_LINT_PROVENANCE",
                    f"SOURCES.csv missing provenance row for runtime character glb: {rel_output}",
                )
            )
            continue
        asset_id = row.get("asset_id", "")
        if not ASSET_ID_RE.fullmatch(asset_id):
            issues.append(
                LintIssue(
                    "ASSET_LINT_NAMING",
                    f"{asset_id!r}: asset_id must match {ASSET_ID_RE.pattern}",
                )
            )
        if not row.get("approval", "").strip():
            issues.append(
                LintIssue(
                    "ASSET_LINT_PROVENANCE",
                    f"{asset_id}: character glb missing approval note in SOURCES.csv",
                )
            )
        for column in APPROVED_PROVENANCE_COLUMNS:
            value = row.get(column, "").strip()
            if value.casefold() in PROVENANCE_PLACEHOLDERS:
                issues.append(
                    LintIssue(
                        "ASSET_LINT_PROVENANCE",
                        f"{asset_id}: character glb has placeholder {column}: {value!r}",
                    )
                )

    try:
        style_rows = read_style_lock_sources(root=root)
    except (OSError, ValueError):
        style_rows = {}
    for family in REQUIRED_FAMILIES:
        row = style_rows.get(family)
        if row is None:
            continue
        if not ASSET_ID_RE.fullmatch(row.asset_id):
            issues.append(
                LintIssue(
                    "ASSET_LINT_NAMING",
                    f"{row.asset_id!r}: style-lock asset_id must match {ASSET_ID_RE.pattern}",
                )
            )

    for glb_path in iter_runtime_character_glbs(root=root):
        rel = _rel_path(glb_path, root)
        tier = classify_character_glb(rel, root=root)
        if tier is None:
            if rel.replace("\\", "/") in BUILD_INPUT_GLBS:
                continue
            issues.append(
                LintIssue(
                    "ASSET_LINT_CHARACTER_TIER",
                    f"{rel}: runtime character glb has no fidelity tier assignment",
                )
            )
            continue
        try:
            stats = inspect_glb(glb_path)
        except (OSError, ValueError, KeyError) as exc:
            issues.append(
                LintIssue(
                    "ASSET_LINT_CHARACTER_TIER",
                    f"{rel}: could not inspect GLB for tier budget ({exc})",
                )
            )
            continue

        triangles = int(stats["triangles"])
        max_texture_px = int(stats["max_texture_px"])
        normalized = rel.replace("\\", "/")
        if normalized in GARMENT_GLBS:
            if triangles > GARMENT_TRIANGLE_CAP:
                issues.append(
                    LintIssue(
                        "ASSET_LINT_CHARACTER_TIER",
                        f"{rel}: garment triangle budget exceeded "
                        f"({triangles}>{GARMENT_TRIANGLE_CAP})",
                    )
                )
            if max_texture_px > GARMENT_TEXTURE_MAX_PX:
                issues.append(
                    LintIssue(
                        "ASSET_LINT_CHARACTER_TIER",
                        f"{rel}: garment texture budget exceeded "
                        f"({max_texture_px}px>{GARMENT_TEXTURE_MAX_PX}px)",
                    )
                )
            continue

        budget = TIER_BUDGETS[tier]
        if triangles > budget.triangle_cap:
            issues.append(
                LintIssue(
                    "ASSET_LINT_CHARACTER_TIER",
                    f"{rel}: tier {tier} ({budget.label}) triangle budget exceeded "
                    f"({triangles}>{budget.triangle_cap})",
                )
            )
        if max_texture_px > budget.texture_max_px:
            issues.append(
                LintIssue(
                    "ASSET_LINT_CHARACTER_TIER",
                    f"{rel}: tier {tier} ({budget.label}) texture budget exceeded "
                    f"({max_texture_px}px>{budget.texture_max_px}px)",
                )
            )

    for message in validate_fauna_glb_pbr(root=root):
        issues.append(LintIssue("ASSET_LINT_FAUNA_PBR", message))

    return issues


def main() -> int:
    issues = validate()
    if issues:
        print("asset lint failed:")
        for issue in issues:
            print(f"  - {issue.format()}")
        return 1

    portrait_count = sum(
        1 for rel_path in _known_portrait_paths(ROOT) if (ROOT / rel_path).is_file()
    )
    tier_count = sum(
        1
        for glb_path in iter_runtime_character_glbs(root=ROOT)
        if classify_character_glb(glb_path.relative_to(ROOT).as_posix(), root=ROOT) is not None
    )
    print(
        "asset lint passed "
        f"({len(REQUIRED_FAMILIES)} style-lock textures, "
        f"{len(_character_outputs(ROOT))} character glbs, "
        f"{tier_count} tier-classified character glb(s), "
        f"{portrait_count} portrait(s) checked)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
