#!/usr/bin/env python3
"""Tests for tools/verify_migration_matrix.py (P0-034)."""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS_DIR = ROOT / "tools"
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from verify_migration_matrix import main, required_scene_set, resolve_artifact_paths, validate_migration_matrix  # noqa: E402

MINI_SCENE_INVENTORY = """\
# Scene inventory

| # | Scene path | Class | Notes |
|---|------------|-------|-------|
| 1 | `player.tscn` | working | fixture |
| 2 | `scenes/menu/main_menu.tscn` | working | fixture |
| 3 | `scenes/reval_east/reval_east.tscn` | partial | fixture |
| 4 | `scenes/reval_center/market_civic_quarter/olaf_guild_hall.tscn` | placeholder | fixture |
"""

MINI_ASSET_INVENTORY = """\
# Asset Inventory

## Per-file inventory

| Path | Media | Classification | Imported by Godot | Rationale |
| --- | --- | --- | --- | --- |
| `assets/bandits/woman1.png` | image | prototype | yes | fixture |
| `assets/tiles/greybox_floor.png` | image | prototype | yes | fixture |
"""

MINI_MATRIX = """\
# P0-034 Migration Matrix

## Maps & Scenes

| Artifact | Status | Rationale |
|----------|--------|-----------|
| `player.tscn` | `retain` | fixture |
| `scenes/menu/main_menu.tscn` | `retain` | fixture |
| `scenes/reval_east/reval_east.tscn` | `convert` | fixture |
| `scenes/reval_center/market_civic_quarter/olaf_guild_hall.tscn` | `convert` | fixture |

## TileSets

| Artifact | Status | Rationale |
|----------|--------|-----------|
| `assets/tiles/greybox_floor.png` | `convert` | fixture |

## Collisions

| Artifact | Status | Rationale |
|----------|--------|-----------|
| `player.tscn@collision_shape` | `convert` | fixture |

## Animations

| Artifact | Status | Rationale |
|----------|--------|-----------|
| `player.tscn@greybox_visual` | `convert` | fixture |

## HUD

| Artifact | Status | Rationale |
|----------|--------|-----------|
| `player.tscn@health_stamina_bars` | `retain` | fixture |

## Runtime Assets

| Artifact | Status | Rationale |
|----------|--------|-----------|
| `assets/bandits/woman1.png` | `convert` | fixture |
"""


class VerifyMigrationMatrixTest(unittest.TestCase):
    def test_required_scene_set_includes_working_partial_and_slice_placeholders(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            scene_path = Path(tmp) / "scene_inventory.md"
            scene_path.write_text(MINI_SCENE_INVENTORY, encoding="utf-8")
            scenes = required_scene_set(scene_path)
            self.assertEqual(
                scenes,
                {
                    "player.tscn",
                    "scenes/menu/main_menu.tscn",
                    "scenes/reval_east/reval_east.tscn",
                    "scenes/reval_center/market_civic_quarter/olaf_guild_hall.tscn",
                },
            )

    def test_resolve_glob_pattern_matches_asset_prefix(self) -> None:
        assets = {
            "assets/buildings/a.png",
            "assets/buildings/north/b.png",
            "assets/objects/food/c.png",
        }
        resolved = resolve_artifact_paths("assets/buildings/*", assets)
        self.assertEqual(
            resolved,
            {"assets/buildings/a.png", "assets/buildings/north/b.png"},
        )

    def test_validate_fixture_matrix_passes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self._seed_fixture_tree(root)
            scene_inventory = root / "scene_inventory.md"
            asset_inventory = root / "asset_inventory.md"
            matrix = root / "matrix.md"
            scene_inventory.write_text(MINI_SCENE_INVENTORY, encoding="utf-8")
            asset_inventory.write_text(MINI_ASSET_INVENTORY, encoding="utf-8")
            matrix.write_text(MINI_MATRIX, encoding="utf-8")

            errors = validate_migration_matrix(
                root=root,
                scene_inventory_path=scene_inventory,
                asset_inventory_path=asset_inventory,
                migration_matrix_path=matrix,
            )
            self.assertEqual(errors, [])

    def test_invalid_status_is_reported(self) -> None:
        bad_matrix = MINI_MATRIX.replace("`retain`", "`keep`", 1)
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self._seed_fixture_tree(root)
            scene_inventory = root / "scene_inventory.md"
            asset_inventory = root / "asset_inventory.md"
            matrix = root / "matrix.md"
            scene_inventory.write_text(MINI_SCENE_INVENTORY, encoding="utf-8")
            asset_inventory.write_text(MINI_ASSET_INVENTORY, encoding="utf-8")
            matrix.write_text(bad_matrix, encoding="utf-8")

            errors = validate_migration_matrix(
                root=root,
                scene_inventory_path=scene_inventory,
                asset_inventory_path=asset_inventory,
                migration_matrix_path=matrix,
            )
            self.assertTrue(any("invalid status" in error.message for error in errors))

    def test_missing_scene_coverage_is_reported(self) -> None:
        bad_matrix = MINI_MATRIX.replace(
            "| `scenes/reval_east/reval_east.tscn` | `convert` | fixture |\n", ""
        )
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self._seed_fixture_tree(root)
            scene_inventory = root / "scene_inventory.md"
            asset_inventory = root / "asset_inventory.md"
            matrix = root / "matrix.md"
            scene_inventory.write_text(MINI_SCENE_INVENTORY, encoding="utf-8")
            asset_inventory.write_text(MINI_ASSET_INVENTORY, encoding="utf-8")
            matrix.write_text(bad_matrix, encoding="utf-8")

            errors = validate_migration_matrix(
                root=root,
                scene_inventory_path=scene_inventory,
                asset_inventory_path=asset_inventory,
                migration_matrix_path=matrix,
            )
            self.assertTrue(any("missing scene coverage" in error.message for error in errors))

    def test_extra_asset_coverage_is_reported(self) -> None:
        bad_matrix = MINI_MATRIX.replace(
            "## Runtime Assets",
            "## Runtime Assets\n\n| Artifact | Status | Rationale |\n|----------|--------|-----------|\n| `assets/extra.png` | `convert` | fixture |\n",
        )
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self._seed_fixture_tree(root)
            (root / "assets/extra.png").write_text("fixture", encoding="utf-8")
            scene_inventory = root / "scene_inventory.md"
            asset_inventory = root / "asset_inventory.md"
            matrix = root / "matrix.md"
            scene_inventory.write_text(MINI_SCENE_INVENTORY, encoding="utf-8")
            asset_inventory.write_text(MINI_ASSET_INVENTORY, encoding="utf-8")
            matrix.write_text(bad_matrix, encoding="utf-8")

            errors = validate_migration_matrix(
                root=root,
                scene_inventory_path=scene_inventory,
                asset_inventory_path=asset_inventory,
                migration_matrix_path=matrix,
            )
            self.assertTrue(any("extra asset coverage" in error.message for error in errors))

    def test_repository_matrix_passes_via_main(self) -> None:
        self.assertEqual(main([]), 0)

    def _seed_fixture_tree(self, root: Path) -> None:
        (root / "player.tscn").write_text("fixture", encoding="utf-8")
        menu = root / "scenes/menu"
        menu.mkdir(parents=True)
        (menu / "main_menu.tscn").write_text("fixture", encoding="utf-8")
        east = root / "scenes/reval_east"
        east.mkdir(parents=True)
        (east / "reval_east.tscn").write_text("fixture", encoding="utf-8")
        market_dir = root / "scenes/reval_center/market_civic_quarter"
        market_dir.mkdir(parents=True)
        (market_dir / "olaf_guild_hall.tscn").write_text("fixture", encoding="utf-8")
        (root / "assets/bandits").mkdir(parents=True)
        (root / "assets/bandits/woman1.png").write_text("fixture", encoding="utf-8")
        (root / "assets/tiles").mkdir(parents=True)
        (root / "assets/tiles/greybox_floor.png").write_text("fixture", encoding="utf-8")


if __name__ == "__main__":
    unittest.main()
