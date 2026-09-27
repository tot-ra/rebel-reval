#!/usr/bin/env python3
"""Tests for tools/verify_map_audit.py."""

from __future__ import annotations

import copy
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from verify_map_audit import MANIFEST, _declarative_scene_links, validate_map_audit  # noqa: E402
from verify_map_conversion_plan import PLAN, SCENE_INVENTORY, TODO  # noqa: E402


class VerifyMapAuditTest(unittest.TestCase):
    def test_repository_audit_manifest_passes(self) -> None:
        self.assertEqual(self._validate(), [])

    def test_missing_entry_fails(self) -> None:
        payload = self._payload()
        payload["maps"] = [row for row in payload["maps"] if row["id"] != "kalev_smithy"]
        errors = self._validate(payload)
        self.assertTrue(any("converted plan scenes missing audit entries" in error.message for error in errors))

    def test_duplicate_entry_fails(self) -> None:
        payload = self._payload()
        payload["maps"].append(copy.deepcopy(payload["maps"][0]))
        errors = self._validate(payload)
        self.assertTrue(any("duplicate map audit id entries" in error.message for error in errors))
        self.assertTrue(any("duplicate map audit scene entries" in error.message for error in errors))

    def test_stale_definition_fails(self) -> None:
        payload = self._payload()
        payload["maps"][0]["definition"] = "scripts/map/definitions/stale.gd"
        errors = self._validate(payload)
        self.assertTrue(any("stale definition" in error.message for error in errors))

    def test_missing_capture_fails(self) -> None:
        payload = self._payload()
        payload["maps"][0]["capture"] = "missing.png"
        errors = self._validate(payload, require_captures=True)
        self.assertTrue(any("missing visual capture" in error.message for error in errors))

    def test_empty_named_archive_reports_missing_strict_tasks(self) -> None:
        errors = self._validate(archive="# empty custom_task_archive\n")
        self.assertTrue(any("missing strict TODO task `P2-020`" in error.message for error in errors))

    def test_worktree_root_still_discovers_declarative_links(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            worktree_root = Path(tmp) / ".worktrees" / "probe"
            self._write_declarative_scene(
                worktree_root,
                scene_rel="scenes/probe.tscn",
                script_rel="scenes/probe.gd",
                definition_rel="scripts/map/definitions/probe_definition.gd",
            )
            self._write_declarative_scene(
                worktree_root,
                scene_rel=".worktrees/mirror/scenes/hidden.tscn",
                script_rel=".worktrees/mirror/scenes/hidden.gd",
                definition_rel="scripts/map/definitions/hidden_definition.gd",
            )
            self.assertEqual(
                _declarative_scene_links(worktree_root),
                {"scenes/probe.tscn": "scripts/map/definitions/probe_definition.gd"},
            )

    def test_nested_worktree_mirrors_stay_skipped_from_primary_root(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            primary = Path(tmp)
            self._write_declarative_scene(
                primary,
                scene_rel="scenes/live.tscn",
                script_rel="scenes/live.gd",
                definition_rel="scripts/map/definitions/live_definition.gd",
            )
            self._write_declarative_scene(
                primary,
                scene_rel=".worktrees/mirror/scenes/hidden.tscn",
                script_rel=".worktrees/mirror/scenes/hidden.gd",
                definition_rel="scripts/map/definitions/hidden_definition.gd",
            )
            self.assertEqual(
                _declarative_scene_links(primary),
                {"scenes/live.tscn": "scripts/map/definitions/live_definition.gd"},
            )

    def test_multiline_definition_preload_is_counted(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self._write_declarative_scene(
                root,
                scene_rel="scenes/harbor.tscn",
                script_rel="scenes/harbor.gd",
                definition_rel="scripts/map/definitions/outdoor/harbor_definition.gd",
                multiline=True,
            )
            self._write_declarative_scene(
                root,
                scene_rel="scenes/other.tscn",
                script_rel="scenes/other.gd",
                definition_rel="scripts/map/view3d/map_view_3d.gd",
                multiline=True,
            )
            self.assertEqual(
                _declarative_scene_links(root),
                {"scenes/harbor.tscn": "scripts/map/definitions/outdoor/harbor_definition.gd"},
            )

    @staticmethod
    def _write_declarative_scene(
        root: Path,
        *,
        scene_rel: str,
        script_rel: str,
        definition_rel: str,
        multiline: bool = False,
    ) -> None:
        scene_path = root / scene_rel
        script_path = root / script_rel
        definition_path = root / definition_rel
        scene_path.parent.mkdir(parents=True, exist_ok=True)
        script_path.parent.mkdir(parents=True, exist_ok=True)
        definition_path.parent.mkdir(parents=True, exist_ok=True)
        scene_path.write_text(
            f'[gd_scene load_steps=2 format=3]\n\n'
            f'[ext_resource type="Script" path="res://{script_rel}" id="1"]\n',
            encoding="utf-8",
        )
        if multiline:
            preload = (
                f'const DEFINITION_SCRIPT := preload(\n'
                f'\t"res://{definition_rel}"\n'
                f')\n'
            )
        else:
            preload = f'const DEFINITION_SCRIPT := preload("res://{definition_rel}")\n'
        script_path.write_text(preload, encoding="utf-8")
        definition_path.write_text("class_name ProbeDefinition\n", encoding="utf-8")

    @staticmethod
    def _payload() -> dict:
        return json.loads(MANIFEST.read_text(encoding="utf-8"))

    def _validate(
        self,
        payload: dict | None = None,
        *,
        require_captures: bool = False,
        archive: str | None = None,
    ) -> list:
        with tempfile.TemporaryDirectory() as temp_dir:
            manifest = Path(temp_dir) / "manifest.json"
            manifest.write_text(json.dumps(payload or self._payload()), encoding="utf-8")
            archive_path = None
            if archive is not None:
                archive_path = Path(temp_dir) / "custom_task_archive.md"
                archive_path.write_text(archive, encoding="utf-8")
            return validate_map_audit(
                root=ROOT,
                manifest_path=manifest,
                plan_path=PLAN,
                inventory_path=SCENE_INVENTORY,
                todo_path=TODO,
                archive_path=archive_path,
                require_captures=require_captures,
            )


if __name__ == "__main__":
    unittest.main()
