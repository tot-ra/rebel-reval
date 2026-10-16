"""Worn coarse linen grades (task R-2024, docs/SYSTEMS/CITIZEN_WARDROBE.md#linen-that-shows-r-2024)."""
import sys
import unittest
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/assets/realistic_humans"))
import textiles  # noqa: E402


class LinenWearTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.coarse = textiles.linen_coarse()[0]
        cls.worn = {level: textiles.linen_coarse_worn(level) for level in (1, 2)}

    def test_maps_tile(self):
        """The wrap-around step is no larger than the largest step between neighbouring rows or columns."""
        for level, albedo in self.worn.items():
            for axis in (0, 1):
                steps = np.abs(np.diff(albedo, axis=axis))
                inner = steps.mean(axis=tuple(a for a in range(steps.ndim) if a != axis)).max()
                seam = np.abs(np.take(albedo, 0, axis=axis) - np.take(albedo, -1, axis=axis)).mean()
                self.assertLessEqual(seam, inner * 1.05, f"w{level} seam on axis {axis}")

    def test_wear_yellows_and_darkens(self):
        def yellowness(img):
            return float((img[..., 0] - img[..., 2]).mean())
        self.assertGreater(yellowness(self.worn[1]), yellowness(self.coarse))
        self.assertGreater(yellowness(self.worn[2]), yellowness(self.worn[1]))
        self.assertLess(self.worn[2].mean(), self.worn[1].mean())

    def test_sweat_stains_are_uneven(self):
        """w2 carries blotches: its tone varies more than the evenly yellowed w1."""
        def spread(img):
            return float(img[..., 2].std())
        self.assertGreater(spread(self.worn[2]), spread(self.worn[1]) * 1.2)

    def test_worn_grades_are_crowd_grades_with_shipped_albedo(self):
        for grade in textiles.LINEN_WEAR:
            self.assertEqual(textiles.GRADE_TILE_METRES[grade], textiles.GRADE_TILE_METRES["linen_coarse"])
            self.assertTrue(textiles.texture_paths(grade, textiles.GRADE_SIZE)["albedo"].exists(), grade)


if __name__ == "__main__":
    unittest.main()
