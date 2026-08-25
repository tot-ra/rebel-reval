from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from tools.verify_p6_002_activation import verify


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "docs/data/p6_002_activation_manifest.json"
TARGETS = ("world_padise", "world_paide", "world_saaremaa", "world_poide")


class TestP6Act3Activation(unittest.TestCase):
    def test_repository_records_consistent_blocked_wave(self) -> None:
        self.assertEqual([], verify(ROOT))

    def test_partial_rrmap_activation_is_rejected(self) -> None:
        with self._fixture() as root:
            path = root / "content/maps/world_padise.rrmap"
            path.write_text(
                path.read_text(encoding="utf-8").replace(
                    "scope=prototype active=false", "scope=production active=true", 1
                ),
                encoding="utf-8",
            )
            errors = verify(root)
            self.assertTrue(
                any("world_padise RRMap must remain scope=prototype active=false" in error for error in errors),
                errors,
            )

    def test_release_promotion_is_rejected_until_dependencies_are_done(self) -> None:
        with self._fixture() as root:
            destinations_path = root / "content/transitions/active_destinations.json"
            destinations = json.loads(destinations_path.read_text(encoding="utf-8"))
            padise = next(row for row in destinations["scenes"] if row["id"] == "world_padise")
            padise["release"] = True
            destinations_path.write_text(json.dumps(destinations), encoding="utf-8")
            errors = verify(root)
            self.assertTrue(
                any("world_padise must remain active developer traversal with release=false" in error for error in errors),
                errors,
            )

    def test_transition_spawn_drift_is_rejected(self) -> None:
        with self._fixture() as root:
            destinations_path = root / "content/transitions/active_destinations.json"
            destinations = json.loads(destinations_path.read_text(encoding="utf-8"))
            paide = next(row for row in destinations["scenes"] if row["id"] == "world_paide")
            paide["spawns"].pop()
            destinations_path.write_text(json.dumps(destinations), encoding="utf-8")
            errors = verify(root)
            self.assertTrue(any("world_paide transition spawns drift" in error for error in errors), errors)

    def test_blocked_wave_requires_each_dependency(self) -> None:
        with self._fixture() as root:
            manifest_path = root / MANIFEST.relative_to(ROOT)
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["blockers"].remove("P6-009")
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            errors = verify(root)
            self.assertTrue(any("missing dependency: P6-009" in error for error in errors), errors)

    def _fixture(self):
        temporary = tempfile.TemporaryDirectory()
        root = Path(temporary.name)
        paths = [
            "docs/data/p6_002_activation_manifest.json",
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
