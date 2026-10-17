"""Quilted aketon textiles (task R-2019, docs/SYSTEMS/EQUIPMENT_VARIANTS.md)."""
import sys
import unittest
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools/assets/realistic_humans"))
import textiles  # noqa: E402


class QuiltedTextileTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.maps = {"quilted": textiles.quilted(), "quilted_silk": textiles.quilted_silk()}

    def test_maps_tile(self):
        """The wrap-around step is no larger than the largest step between neighbouring rows or columns."""
        for name, (albedo, normal, orm) in self.maps.items():
            for image in (albedo, normal, orm):
                for axis in (0, 1):
                    steps = np.abs(np.diff(image, axis=axis))
                    inner = steps.mean(axis=tuple(a for a in range(steps.ndim) if a != axis)).max()
                    seam = np.abs(np.take(image, 0, axis=axis) - np.take(image, -1, axis=axis)).mean()
                    self.assertLessEqual(seam, inner * 1.05, f"{name} seam on axis {axis}")

    def test_channels_run_along_v(self):
        """Stitch grooves are dark columns: QUILT_CHANNELS of them across U, none along V."""
        albedo = self.maps["quilted"][0][..., 0]
        across_u = albedo.mean(axis=0)  # one value per column
        dark = across_u < across_u.mean() - 2 * across_u.std()
        runs = np.count_nonzero(dark & ~np.roll(dark, 1))
        self.assertEqual(runs, textiles.QUILT_CHANNELS)
        along_v = albedo.mean(axis=1)
        self.assertLess(along_v.std(), across_u.std() / 3)

    def test_silk_is_smoother_than_linen(self):
        self.assertLess(self.maps["quilted_silk"][2][..., 1].mean(), self.maps["quilted"][2][..., 1].mean() - 0.15)

    def test_silk_is_a_crowd_grade(self):
        self.assertIn("quilted_silk", textiles.GRADES)
        self.assertEqual(textiles.GRADE_TILE_METRES["quilted_silk"], textiles.TILE_METRES["quilted"])


if __name__ == "__main__":
    unittest.main()
