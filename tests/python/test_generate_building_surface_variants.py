"""AR-03 (R-961): the building surface library generator is deterministic and
emits albedo, normal and packed ORM maps for every stem."""

from __future__ import annotations

import importlib.util
import io
import sys
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
GENERATOR = ROOT / "tools" / "generate_building_surface_variants.py"


def _load_generator():
    spec = importlib.util.spec_from_file_location("generate_building_surface_variants", GENERATOR)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


GEN = _load_generator()
KIT = GEN._load_kit()


class BuildingSurfaceVariantsTest(unittest.TestCase):
    def test_every_stem_has_a_roughness_profile_and_unique_name(self) -> None:
        stems = [stem for _, stem, _ in GEN.VARIANTS]
        self.assertEqual(len(stems), len(set(stems)))
        for kind, stem, _ in GEN.VARIANTS:
            self.assertIn(kind, GEN.ROUGHNESS_PROFILES, stem)

    def test_every_stem_ships_full_channel_set_on_disk(self) -> None:
        for _, stem, _ in GEN.VARIANTS:
            for channel in ("albedo", "normal", "orm"):
                path = GEN.OUT_DIR / f"{stem}_{channel}.png"
                self.assertTrue(path.is_file(), f"missing {path.name}")
        self.assertTrue((GEN.OUT_DIR / GEN.MACRO_NAME).is_file())

    def test_surfaces_and_orm_are_deterministic_for_every_kind(self) -> None:
        size = 64
        for kind in sorted({kind for kind, _, _ in GEN.VARIANTS}):
            first_rgb, first_height = KIT.surface_texture(kind, KIT._np_rng(f"t:{kind}"), size)
            again_rgb, again_height = KIT.surface_texture(kind, KIT._np_rng(f"t:{kind}"), size)
            np.testing.assert_array_equal(first_rgb, again_rgb, err_msg=kind)
            np.testing.assert_array_equal(first_height, again_height, err_msg=kind)
            orm = GEN.orm_from_height(KIT, kind, f"t_{kind}", first_height, first_height.shape[0])
            self.assertEqual(orm.shape[-1], 3, kind)
            self.assertTrue(np.all(orm[..., 2] == 0.0), f"{kind} must stay non-metallic")
            roughness = orm[..., 1]
            self.assertGreater(float(roughness.max() - roughness.min()), 0.01, f"{kind} roughness varies")
            self.assertLess(float(roughness.mean()), 0.99, f"{kind} is not constant 1.0")

    def test_tar_finishes_read_glossier_than_bare_timber(self) -> None:
        height = KIT.surface_texture("log_course", KIT._np_rng("t:tar"), 64)[1]
        tar = GEN.orm_from_height(KIT, "log_course", "logwall_tar", height, 64)[..., 1].mean()
        bare = GEN.orm_from_height(KIT, "log_course", "logwall_weathered", height, 64)[..., 1].mean()
        self.assertLess(tar + 0.2, bare)

    def test_committed_orm_bytes_reproduce(self) -> None:
        kind, stem, _ = next(v for v in GEN.VARIANTS if v[1] == "brick_red")
        _, height = KIT.surface_texture(kind, KIT._np_rng(f"building_variant:{stem}"), GEN.SIZE)
        orm = GEN.orm_from_height(KIT, kind, stem, height, height.shape[0])
        buffer = io.BytesIO()
        GEN._to_image(orm).save(buffer, format="PNG", optimize=True)
        self.assertEqual(buffer.getvalue(), (GEN.OUT_DIR / f"{stem}_orm.png").read_bytes())

    def test_macro_plate_only_shades(self) -> None:
        plate = np.asarray(Image.open(GEN.OUT_DIR / GEN.MACRO_NAME).convert("L"), dtype=np.float32) / 255.0
        self.assertGreaterEqual(float(plate.min()), 0.85)
        self.assertLessEqual(float(plate.max()), 1.0)
        self.assertAlmostEqual(float(plate.mean()), 0.93, delta=0.02)


if __name__ == "__main__":
    unittest.main()
