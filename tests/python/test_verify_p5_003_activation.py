from __future__ import annotations

import json
import re
import tempfile
import unittest
from pathlib import Path

from tools.verify_p5_003_activation import verify


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "docs/data/p5_003_activation_manifest.json"
TARGETS = ("world_rebel_kings",)


class TestP5WorldActivationWave(unittest.TestCase):
    def test_repository_records_consistent_blocked_wave(self) -> None:
        self.assertEqual([], verify(ROOT))

    def test_partial_target_activation_is_rejected(self) -> None:
        with self._fixture() as root:
            path = root / "content/maps/world_rebel_kings.rrmap"
            path.write_text(
                path.read_text(encoding="utf-8").replace(
                    "scope=prototype active=false", "scope=production active=true", 1
                ),
                encoding="utf-8",
            )
            errors = verify(root)
            self.assertTrue(
                any("partial activation for world_rebel_kings" in error for error in errors),
                errors,
            )

    def test_catalog_fixture_promotes_multiline_entry(self) -> None:
        with self._fixture() as root:
            self._promote_target(root, "world_rebel_kings", "world.rebel_kings")
            catalog = (root / "scripts/map/map_catalog.gd").read_text(encoding="utf-8")
            multiline_entry = re.search(
                r'"world_rebel_kings":\s*\{[^}]+\}', catalog, re.DOTALL
            )
            self.assertIsNotNone(multiline_entry)
            self.assertRegex(
                multiline_entry.group(),
                r'"scope":\s*"production",\s*"active":\s*true',
            )

    def test_transition_spawn_drift_is_rejected(self) -> None:
        with self._fixture() as root:
            path = root / "content/transitions/active_destinations.json"
            destinations = json.loads(path.read_text(encoding="utf-8"))
            target = next(
                row for row in destinations["scenes"] if row["id"] == "world_rebel_kings"
            )
            target["spawns"].pop()
            path.write_text(json.dumps(destinations), encoding="utf-8")
            errors = verify(root)
            self.assertTrue(
                any("world_rebel_kings transition spawns drift" in error for error in errors),
                errors,
            )

    def test_blocked_wave_requires_world_travel_dependency(self) -> None:
        with self._fixture() as root:
            path = root / MANIFEST.relative_to(ROOT)
            manifest = json.loads(path.read_text(encoding="utf-8"))
            manifest["blockers"].remove("P5-002")
            path.write_text(json.dumps(manifest), encoding="utf-8")
            errors = verify(root)
            self.assertTrue(
                any("missing dependency: P5-002" in error for error in errors), errors
            )

    def test_production_wave_requires_all_runtime_and_parity_gates(self) -> None:
        with self._fixture() as root:
            self._promote_target(root, "world_rebel_kings", "world.rebel_kings")
            errors = verify(root)
            self.assertTrue(any("decision=approved" in error for error in errors), errors)
            self.assertTrue(any("transition_verifier=pass" in error for error in errors), errors)
            self.assertTrue(any("traversal_collision=pass" in error for error in errors), errors)
            self.assertTrue(any("accepted day/night parity gate" in error for error in errors), errors)
            for scene_id in TARGETS:
                self.assertTrue(
                    any(f"accepted parity for {scene_id}" in error for error in errors),
                    errors,
                )

    def _promote_target(self, root: Path, scene_id: str, rrmap_id: str) -> None:
        rrmap = root / "content/maps" / f"{scene_id}.rrmap"
        rrmap.write_text(
            rrmap.read_text(encoding="utf-8").replace(
                "scope=prototype active=false", "scope=production active=true", 1
            ),
            encoding="utf-8",
        )

        catalog = root / "scripts/map/map_catalog.gd"
        text = catalog.read_text(encoding="utf-8")
        match = re.search(
            rf'(?ms)^[ \t]*"{re.escape(scene_id)}":\s*\{{.*?\}}'
            rf'(?=\s*,?\s*\n[ \t]*"|\s*$)',
            text,
        )
        self.assertIsNotNone(match, f"missing catalog entry for {scene_id}")
        if match is None:
            return
        entry = match.group()
        promoted = re.sub(
            r'"scope":\s*"prototype",\s*"active":\s*false',
            '"scope": "production", "active": true',
            entry,
            count=1,
        )
        self.assertNotEqual(entry, promoted, f"failed to promote catalog entry for {scene_id}")
        catalog.write_text(text[: match.start()] + promoted + text[match.end() :], encoding="utf-8")

        destinations_path = root / "content/transitions/active_destinations.json"
        destinations = json.loads(destinations_path.read_text(encoding="utf-8"))
        target = next(row for row in destinations["scenes"] if row["id"] == scene_id)
        target["release"] = True
        destinations_path.write_text(json.dumps(destinations), encoding="utf-8")

    def _fixture(self):
        temporary = tempfile.TemporaryDirectory()
        root = Path(temporary.name)
        paths = [
            "docs/data/p5_003_activation_manifest.json",
            "content/transitions/active_destinations.json",
            "scripts/map/map_catalog.gd",
            "docs/adr/0008-three-act-campaign-and-faction-scope.md",
        ]
        paths.extend(f"content/maps/{scene_id}.rrmap" for scene_id in TARGETS)
        paths.extend(f"scenes/world_travel/{scene_id}.tscn" for scene_id in TARGETS)
        for relative in paths:
            destination = root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes((ROOT / relative).read_bytes())

        class Fixture:
            def __enter__(self):
                return root

            def __exit__(self, exc_type, exc_value, traceback):
                temporary.cleanup()

        return Fixture()


if __name__ == "__main__":
    unittest.main()
