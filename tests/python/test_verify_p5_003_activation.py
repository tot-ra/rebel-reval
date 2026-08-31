from __future__ import annotations

import json
import re
import tempfile
import unittest
from pathlib import Path

from tools.verify_p5_003_activation import verify


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "docs/data/p5_003_activation_manifest.json"
TARGETS = ("world_harju", "world_rebel_kings", "world_sacred_grove")


class TestP5WorldActivationWave(unittest.TestCase):
    def test_repository_records_consistent_blocked_wave(self) -> None:
        self.assertEqual([], verify(ROOT))

    def test_partial_target_activation_is_rejected(self) -> None:
        with self._fixture() as root:
            path = root / "content/maps/world_harju.rrmap"
            path.write_text(
                path.read_text(encoding="utf-8").replace(
                    "scope=prototype active=false", "scope=production active=true", 1
                ),
                encoding="utf-8",
            )
            errors = verify(root)
            self.assertTrue(
                any("partial activation for world_harju" in error for error in errors),
                errors,
            )

    def test_partial_wave_promotion_is_rejected(self) -> None:
        with self._fixture() as root:
            self._promote_target(root, "world_harju", "world.harju")
            errors = verify(root)
            self.assertTrue(
                any("partial wave activation" in error for error in errors), errors
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
            rrmap_ids = {
                "world_harju": "world.harju",
                "world_rebel_kings": "world.rebel_kings",
                "world_sacred_grove": "world.sacred_grove",
            }
            for scene_id, rrmap_id in rrmap_ids.items():
                self._promote_target(root, scene_id, rrmap_id)
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
        entry_start = text.index(f'\t"{scene_id}":')
        entry_end = text.index("\n\t\"", entry_start + 2)
        entry = text[entry_start:entry_end]
        promoted = re.sub(
            r'"scope":\s*"prototype",\s*"active":\s*false',
            '"scope": "production", "active": true',
            entry,
            count=1,
        )
        self.assertNotEqual(entry, promoted, f"failed to promote catalog entry for {scene_id}")
        catalog.write_text(text[:entry_start] + promoted + text[entry_end:], encoding="utf-8")

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
