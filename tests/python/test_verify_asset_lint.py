#!/usr/bin/env python3
"""Tests for P1-029 asset lint."""

from __future__ import annotations

import csv
import struct
import sys
import tempfile
import unittest
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from verify_asset_lint import (  # noqa: E402
    LintIssue,
    main,
    validate,
)
from verify_slice_surface_assets import REQUIRED_FAMILIES, TEXTURE_SIZE  # noqa: E402


def _write_png(path: Path, width: int, height: int, rgba: tuple[int, int, int, int]) -> None:
    def chunk(chunk_type: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + chunk_type
            + data
            + struct.pack(">I", zlib.crc32(chunk_type + data) & 0xFFFFFFFF)
        )

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    raw = b"".join(b"\x00" + bytes(rgba) * width for _ in range(height))
    idat = zlib.compress(raw, 9)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", idat)
        + chunk(b"IEND", b"")
    )
    path.write_bytes(png)


def _write_seamless_png(path: Path, size: int, rgba: tuple[int, int, int, int]) -> None:
    _write_png(path, size, size, rgba)


def _write_sources(root: Path, rows: list[dict[str, str]]) -> None:
    sources = root / "assets" / "SOURCES.csv"
    sources.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "asset_id",
        "path",
        "creator_or_tool",
        "model_version",
        "prompt_or_url",
        "seed",
        "license",
        "edits",
        "approval",
    ]
    with sources.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def _write_minimal_contract_files(root: Path) -> None:
    (root / "docs").mkdir(parents=True, exist_ok=True)
    (root / "docs" / "MATERIAL_STYLE_LOCK_KIT.md").write_text("kit", encoding="utf-8")
    (root / "assets" / "characters" / "shared").mkdir(parents=True, exist_ok=True)
    (root / "assets" / "characters" / "shared" / "character_scale.gd").write_text(
        "\n".join(
            [
                "const VISIBLE_HEIGHT_WORLD := 2.0",
                "const TARGET_VISIBLE_HEIGHT_PX := 64.0",
            ]
        ),
        encoding="utf-8",
    )
    (root / "assets" / "characters" / "shared" / "shared_character_rig.gd").write_text(
        '@export_range(0.1, 5.0, 0.01) var visible_height_world: float = 2.0\n',
        encoding="utf-8",
    )
    (root / "scripts" / "dialogue").mkdir(parents=True, exist_ok=True)
    (root / "scripts" / "dialogue" / "dialogue_portrait_resolver.gd").write_text(
        'const KNOWN_PORTRAITS := {\n\t&"char.kalev": "res://portraits/kalev.png",\n}\n',
        encoding="utf-8",
    )
    (root / "tools").mkdir(parents=True, exist_ok=True)
    (root / "tools" / "character_specs.py").write_text(
        "\n".join(
            [
                "CHARACTERS = {",
                '    "hero": {"output": "assets/characters/shared/heroic_humanoid.glb"},',
                "}",
            ]
        ),
        encoding="utf-8",
    )
    for rel_scene in (
        "assets/characters/shared/hammer.tscn",
        "assets/characters/shared/spear.tscn",
    ):
        scene_path = root / rel_scene
        scene_path.parent.mkdir(parents=True, exist_ok=True)
        scene_path.write_text('[node name="Prop" type="Node3D"]\n', encoding="utf-8")


def _write_valid_fixture(root: Path) -> None:
    _write_minimal_contract_files(root)
    style_lock = root / "assets" / "materials" / "style_lock"
    style_lock.mkdir(parents=True, exist_ok=True)
    for family in REQUIRED_FAMILIES:
        _write_seamless_png(style_lock / f"{family}.png", TEXTURE_SIZE, (120, 120, 120, 255))
    glb = root / "assets" / "characters" / "shared" / "heroic_humanoid.glb"
    glb.write_bytes(b"glb-fixture" * 2_000)
    _write_sources(
        root,
        [
            {
                "asset_id": f"assets.materials.style_lock.{family}",
                "path": f"assets/materials/style_lock/{family}.png",
                "creator_or_tool": "maintainer",
                "model_version": "style-lock-v1.0",
                "prompt_or_url": "fixture",
                "seed": "1",
                "license": "AGPL-3.0-or-later",
                "edits": "fixture",
                "approval": "approved - fixture",
            }
            for family in REQUIRED_FAMILIES
        ]
        + [
            {
                "asset_id": "assets.characters.shared.heroic_humanoid",
                "path": "assets/characters/shared/heroic_humanoid.glb",
                "creator_or_tool": "project maintainer",
                "model_version": "fixture",
                "prompt_or_url": "generated in-repo",
                "seed": "not applicable",
                "license": "original work",
                "edits": "fixture",
                "approval": "generated body for rig contract",
            }
        ],
    )
    portrait = root / "portraits" / "kalev.png"
    portrait.parent.mkdir(parents=True, exist_ok=True)
    _write_seamless_png(portrait, 192, (200, 180, 160, 255))


def _issue_rules(issues: list[LintIssue]) -> set[str]:
    return {issue.rule for issue in issues}


class VerifyAssetLintTest(unittest.TestCase):
    def test_current_repository_passes(self) -> None:
        self.assertEqual(validate(root=ROOT), [])

    def test_valid_fixture_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            _write_valid_fixture(root)
            self.assertEqual(validate(root=root), [])

    def test_texture_dimension_rule_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            _write_valid_fixture(root)
            _write_seamless_png(
                root / "assets/materials/style_lock/stone.png",
                256,
                (120, 120, 120, 255),
            )
            rules = _issue_rules(validate(root=root))
            self.assertIn("ASSET_LINT_TEXTURE_DIMENSION", rules)

    def test_seamless_tile_rule_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            _write_valid_fixture(root)
            from PIL import Image

            path = root / "assets/materials/style_lock/stone.png"
            image = Image.open(path).convert("RGBA")
            pixels = image.load()
            left = pixels[0, 0]
            pixels[image.size[0] - 1, 0] = (
                (left[0] + 40) % 256,
                left[1],
                left[2],
                left[3],
            )
            image.save(path)
            rules = _issue_rules(validate(root=root))
            self.assertIn("ASSET_LINT_SEAMLESS_TILE", rules)

    def test_character_scale_rule_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            _write_valid_fixture(root)
            scale_path = root / "assets/characters/shared/character_scale.gd"
            scale_path.write_text("const TARGET_VISIBLE_HEIGHT_PX := 48.0\n", encoding="utf-8")
            rules = _issue_rules(validate(root=root))
            self.assertIn("ASSET_LINT_CHARACTER_SCALE", rules)

    def test_character_mesh_rule_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            _write_valid_fixture(root)
            (root / "assets/characters/shared/heroic_humanoid.glb").unlink()
            rules = _issue_rules(validate(root=root))
            self.assertIn("ASSET_LINT_CHARACTER_MESH", rules)

    def test_portrait_dimension_rule_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            _write_valid_fixture(root)
            _write_png(root / "portraits/kalev.png", 200, 192, (10, 20, 30, 255))
            rules = _issue_rules(validate(root=root))
            self.assertIn("ASSET_LINT_PORTRAIT_DIMENSION", rules)

    def test_naming_rule_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            _write_valid_fixture(root)
            specs = root / "tools" / "character_specs.py"
            specs.write_text(
                'CHARACTERS = {"hero": {"output": "assets/characters/shared/BadName.glb"}}\n',
                encoding="utf-8",
            )
            rules = _issue_rules(validate(root=root))
            self.assertIn("ASSET_LINT_NAMING", rules)

    def test_provenance_rule_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            _write_valid_fixture(root)
            sources = root / "assets" / "SOURCES.csv"
            lines = sources.read_text(encoding="utf-8").splitlines()
            lines[-1] = lines[-1].replace("project maintainer", "unknown")
            sources.write_text("\n".join(lines) + "\n", encoding="utf-8")
            rules = _issue_rules(validate(root=root))
            self.assertIn("ASSET_LINT_PROVENANCE", rules)

    def test_main_exits_zero_on_repository(self) -> None:
        self.assertEqual(main(), 0)


if __name__ == "__main__":
    unittest.main()
