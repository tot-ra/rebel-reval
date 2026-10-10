import sys
import unittest
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools" / "assets"))
import import_npc_portraits as imp  # noqa: E402


class CropTests(unittest.TestCase):
    def test_tall_sheet_becomes_capped_square(self):
        out = imp.crop_portrait(Image.new("RGB", (682, 1024)))
        self.assertEqual(out.size, (imp.MAX_SIDE, imp.MAX_SIDE))

    def test_small_image_not_upscaled(self):
        out = imp.crop_portrait(Image.new("RGB", (100, 150)))
        self.assertEqual(out.size, (100, 100))


if __name__ == "__main__":
    unittest.main()
