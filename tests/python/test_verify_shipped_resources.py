#!/usr/bin/env python3
"""Tests for PCK inventory parsing and the shipped-resource export contract."""

from __future__ import annotations

import contextlib
import io
import json
import struct
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import pck_inventory  # noqa: E402
import verify_shipped_resources as shipped  # noqa: E402


PACK_MAGIC = 0x43504447


def write_test_pck(path: Path, files: dict[str, bytes]) -> None:
    """Write a Godot 4 pack-version-2 PCK with the given path/bytes map."""
    records: list[tuple[bytes, int, int]] = []
    payload = bytearray()
    # Directory size is computed first so file offsets can be absolute.
    directory_size = 0
    encoded_paths: list[bytes] = []
    for raw_path in files:
        encoded = raw_path.encode("utf-8")
        encoded_paths.append(encoded)
        directory_size += 4 + len(encoded) + 8 + 8 + 16 + 4
    file_base = 32 + 64 + 4 + directory_size
    offset = file_base
    for encoded, data in zip(encoded_paths, files.values()):
        records.append((encoded, offset, len(data)))
        payload.extend(data)
        offset += len(data)

    header = struct.pack("<6I", PACK_MAGIC, 2, 4, 7, 1, 0)
    header += struct.pack("<Q", 0)
    header += b"\x00" * 64
    header += struct.pack("<I", len(files))
    directory = bytearray()
    for encoded, file_offset, size in records:
        directory.extend(struct.pack("<I", len(encoded)))
        directory.extend(encoded)
        directory.extend(struct.pack("<QQ", file_offset, size))
        directory.extend(b"\x00" * 16)
        directory.extend(struct.pack("<I", 0))
    path.write_bytes(header + directory + payload)


class PckInventoryTest(unittest.TestCase):
    def test_parse_pck_reads_paths_and_sizes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            pck = Path(temp_dir) / "fixture.pck"
            write_test_pck(
                pck,
                {
                    "res://scripts/player.gd": b"extends Node\n",
                    "res://tests/godot/test_demo.gd": b"extends RefCounted\n",
                    "CREDITS.md": b"# Credits\n",
                },
            )
            index = pck_inventory.parse_pck(pck)

        paths = {item.path: item.size for item in index.files}
        self.assertEqual(index.godot_version, "4.7.1")
        self.assertEqual(index.file_count, 3)
        self.assertEqual(paths["res://scripts/player.gd"], len(b"extends Node\n"))
        self.assertEqual(paths["res://tests/godot/test_demo.gd"], len(b"extends RefCounted\n"))
        self.assertEqual(paths["res://CREDITS.md"], len(b"# Credits\n"))
        self.assertEqual(index.total_bytes, sum(paths.values()))

    def test_cli_writes_selected_json_basename(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            pck = Path(temp_dir) / "fixture.pck"
            report = Path(temp_dir) / "alternate-pck-report.json"
            write_test_pck(pck, {"res://music/menu/Menu.mp3": b"ID3"})
            stdout = io.StringIO()
            with contextlib.redirect_stdout(stdout):
                exit_code = pck_inventory.main([str(pck), "--json", str(report), "--no-files"])
            self.assertEqual(exit_code, 0)
            payload = json.loads(report.read_text(encoding="utf-8"))
            self.assertEqual(payload["file_count"], 1)
            self.assertEqual(payload["total_bytes"], 3)
            self.assertNotIn("files", payload)
            self.assertIn(f"JSON report written: {report.name}", stdout.getvalue())


class ShippedResourceContractTest(unittest.TestCase):
    def test_repository_export_presets_match_manifest(self) -> None:
        report = shipped.build_report(ROOT)
        self.assertTrue(report.valid, msg="\n".join(report.errors))

    def test_release_pck_rejects_tests_and_keeps_notices(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            pck = Path(temp_dir) / "release.pck"
            write_test_pck(
                pck,
                {
                    "res://LICENSE": b"AGPL",
                    "res://CREDITS.md": b"credits",
                    "res://docs/THIRD_PARTY_NOTICES.md": b"notices",
                    "res://assets/fonts/NotoSans-OFL-1.1.txt": b"OFL",
                    "res://assets/characters/shared/KAYKIT_CC0_LICENSE.txt": b"CC0",
                    "res://scripts/map/view3d/third_party/d3_celestial_BSD_3_CLAUSE.txt": b"BSD",
                    "res://content/transitions/active_destinations.json": b"{}",
                    "res://assets/characters/cat/cat_rig.tscn": b"[gd_scene]",
                    "res://assets/storybook/forge_cat.glb": b"glTF",
                    "res://characters/rebels/martin.png": b"png",
                    "res://character/image.png": b"png",
                    "res://music/menu/Menu.mp3": b"ID3",
                    "res://music/forge/Fireside Tale.mp3": b"ID3",
                    "res://scripts/global/music_director.gd": b"extends Node",
                    "res://scripts/dialogue/dialogue_portrait_resolver.gd": b"extends RefCounted",
                    "res://scripts/global/door_navigator.gd": b"extends Node",
                    "res://scenes/menu/main_menu.tscn": b"[gd_scene]",
                    "res://scenes/reval_east/forge/forge.tscn": b"[gd_scene]",
                    "res://scenes/reval_east/reval_east.tscn": b"[gd_scene]",
                    "res://sounds/door.wav": b"RIFF",
                    "res://content/demo/items.json": b"[]",
                    "res://content/packages/bell_and_chain/content/quest.json": b"{}",
                    "res://content/examples/valid/item.json": b"{}",
                    "res://docs/data/act1_aftermath_manifest.json": b"{}",
                    "res://audio/default_bus_layout.tres": b"[gd_resource]",
                    "res://tests/godot/test_demo.gd": b"extends RefCounted",
                    "res://.godot/imported/cat_hunyuan3d_local.glb-8d8384f41ad8820cd055bd3b891fbf5c.scn": b"scn",
                },
            )
            report = shipped.build_report(ROOT, pck_path=pck, preset="rr")

        self.assertFalse(report.valid)
        self.assertTrue(any("res://tests/" in error for error in report.errors))
        self.assertTrue(any("cat_hunyuan3d_local.glb" in error for error in report.errors))

    def test_release_pck_accepts_required_runtime_set(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            pck = Path(temp_dir) / "release.pck"
            write_test_pck(pck, self._required_release_files())
            report = shipped.build_report(ROOT, pck_path=pck, preset="rr")

        self.assertTrue(report.valid, msg="\n".join(report.errors))
        self.assertEqual(report.file_count, len(self._required_release_files()))

    def test_diagnostic_pck_may_include_tests(self) -> None:
        files = self._required_release_files()
        files["res://tests/godot/test_act1_packaged_acceptance.gd"] = b"extends RefCounted"
        files["res://tools/run_godot_tests.gd"] = b"extends SceneTree"
        with tempfile.TemporaryDirectory() as temp_dir:
            pck = Path(temp_dir) / "diagnostic.pck"
            write_test_pck(pck, files)
            report = shipped.build_report(ROOT, pck_path=pck, preset="rr-diagnostic")

        self.assertTrue(report.valid, msg="\n".join(report.errors))

    def test_cli_confirms_selected_json_basename(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            output = Path(temp_dir) / "alternate-shipped-check.json"
            stdout = io.StringIO()
            with contextlib.redirect_stdout(stdout):
                exit_code = shipped.main(["--json", str(output)])
            self.assertEqual(exit_code, 0)
            payload = json.loads(output.read_text(encoding="utf-8"))
            self.assertTrue(payload["valid"])
            self.assertIn(f"JSON report written: {output.name}", stdout.getvalue())

    def _required_release_files(self) -> dict[str, bytes]:
        return {
            "res://LICENSE": b"AGPL",
            "res://CREDITS.md": b"credits",
            "res://docs/THIRD_PARTY_NOTICES.md": b"notices",
            "res://assets/fonts/NotoSans-OFL-1.1.txt": b"OFL",
            "res://assets/characters/shared/KAYKIT_CC0_LICENSE.txt": b"CC0",
            "res://scripts/map/view3d/third_party/d3_celestial_BSD_3_CLAUSE.txt": b"BSD",
            "res://content/transitions/active_destinations.json": b"{}",
            "res://assets/characters/cat/cat_rig.tscn": b"[gd_scene]",
            "res://assets/storybook/forge_cat.glb": b"glTF",
            "res://characters/rebels/martin.png": b"png",
            "res://character/image.png": b"png",
            "res://music/menu/Menu.mp3": b"ID3",
            "res://music/forge/Fireside Tale.mp3": b"ID3",
            "res://scripts/global/music_director.gd": b"extends Node",
            "res://scripts/dialogue/dialogue_portrait_resolver.gd": b"extends RefCounted",
            "res://scripts/global/door_navigator.gd": b"extends Node",
            "res://scenes/menu/main_menu.tscn": b"[gd_scene]",
            "res://scenes/reval_east/forge/forge.tscn": b"[gd_scene]",
            "res://scenes/reval_east/reval_east.tscn": b"[gd_scene]",
            "res://sounds/door.wav": b"RIFF",
            "res://content/demo/items.json": b"[]",
            "res://content/packages/bell_and_chain/content/quest.json": b"{}",
            "res://content/examples/valid/item.json": b"{}",
            "res://docs/data/act1_aftermath_manifest.json": b"{}",
            "res://audio/default_bus_layout.tres": b"[gd_resource]",
        }


if __name__ == "__main__":
    unittest.main()
