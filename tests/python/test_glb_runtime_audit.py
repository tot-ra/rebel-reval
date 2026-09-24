"""JSON-first helper detection for runtime GLB cleanup."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.assets.glb_runtime_audit import authored_helper_names, is_helper_name  # noqa: E402


class GlbRuntimeAuditTests(unittest.TestCase):
    def test_helper_names_keep_kaykit_cubes_and_drop_icospheres(self) -> None:
        self.assertTrue(is_helper_name("Icosphere"))
        self.assertTrue(is_helper_name("Icosphere.001"))
        self.assertTrue(is_helper_name("Camera"))
        self.assertTrue(is_helper_name("Light.002"))
        self.assertTrue(is_helper_name("Cube"))
        self.assertTrue(is_helper_name("Plane"))
        self.assertFalse(is_helper_name("Cube.001"))
        self.assertFalse(is_helper_name("Cube.160"))
        self.assertFalse(is_helper_name("Plane.006"))
        self.assertFalse(is_helper_name("Cylinder.404"))
        self.assertFalse(is_helper_name("AnimalMesh"))
        self.assertFalse(is_helper_name("Anatomy_SkinTorso.001"))

    def test_reviewed_runtime_glbs_have_no_authored_helpers(self) -> None:
        samples = [
            ROOT / "assets/storybook/cow/cow.glb",
            ROOT / "assets/storybook/dog/dog.glb",
            ROOT / "assets/storybook/goose/goose.glb",
            ROOT / "assets/storybook/hen/hen.glb",
            ROOT / "assets/storybook/forge_cat/forge_cat.glb",
            ROOT / "assets/characters/shared/kaykit_barbarian.glb",
            ROOT / "assets/characters/shared/watchman.glb",
            ROOT / "assets/characters/shared/watchman_lod1.glb",
            ROOT / "assets/characters/shared/mart_lod2.glb",
        ]
        for path in samples:
            self.assertTrue(path.is_file(), path.name)
            self.assertEqual(authored_helper_names(path), [], path.name)


if __name__ == "__main__":
    unittest.main()
