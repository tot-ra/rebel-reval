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


class MissingPortraitTests(unittest.TestCase):
    def test_reports_null_and_dangling_portraits(self):
        registry = {"npcs": [
            {"id": "char.a", "portrait": None},
            {"id": "char.b", "portrait": "res://no/such/file.png"},
            {"id": "char.c", "portrait": "res://assets/characters/portraits/npc/martin.png"},
        ]}
        self.assertEqual(imp.missing_portraits(registry), ["char.a", "char.b"])


class SourceGlobTests(unittest.TestCase):
    def test_promoted_sheets_stay_portrait_sources(self):
        # Promotion moves a sheet into docs/CHARACTERS/img/sheets/; its avatar must still be built.
        found = {p.relative_to(imp.ROOT).as_posix() for pattern in imp.SRC_GLOBS for p in imp.ROOT.glob(pattern)}
        self.assertIn("docs/CHARACTERS/img/sheets/martin.jpg", found)
        self.assertIn("characters/tavern/adelheid/img/adelheid.jpg", found)


if __name__ == "__main__":
    unittest.main()
