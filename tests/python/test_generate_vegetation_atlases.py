"""R-1329 procedural vegetation textures: determinism, layout, alpha and tiling."""

from __future__ import annotations

import hashlib
import re
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/assets"))

import generate_vegetation_atlases as gen  # noqa: E402

LEAF_GEOMETRY = ROOT / "scripts/map/view3d/map_view_leaf_geometry.gd"


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _load(path: Path) -> np.ndarray:
    return np.asarray(Image.open(path))


class GeneratedSetTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls._dirs = [tempfile.TemporaryDirectory(), tempfile.TemporaryDirectory()]
        cls.first = Path(cls._dirs[0].name)
        cls.second = Path(cls._dirs[1].name)
        cls.digests = gen.generate(cls.first)
        cls.repeat = gen.generate(cls.second)

    @classmethod
    def tearDownClass(cls) -> None:
        for directory in cls._dirs:
            directory.cleanup()

    def tile(self, name: str, key: str = "leaf_card_atlas.png") -> np.ndarray:
        atlas = _load(self.first / gen.LEAF_DIR / key)
        index = gen.TILES.index(name)
        col, row = index % gen.GRID[0], index // gen.GRID[0]
        return atlas[row * gen.TILE:(row + 1) * gen.TILE, col * gen.TILE:(col + 1) * gen.TILE]

    def test_two_runs_are_byte_identical(self) -> None:
        self.assertEqual(self.digests, self.repeat)
        for relative, digest in self.digests.items():
            self.assertEqual(_sha(self.first / relative), digest)

    def test_committed_textures_match_the_generator(self) -> None:
        for relative, digest in self.digests.items():
            committed = ROOT / relative
            self.assertTrue(committed.is_file(), relative)
            self.assertEqual(_sha(committed), digest, f"{relative} is stale; rerun the generator")
            self.assertTrue(Path(f"{committed}.import").is_file(), f"{relative} has no .import")

    def test_every_output_is_power_of_two(self) -> None:
        for relative in self.digests:
            width, height = Image.open(self.first / relative).size
            for side in (width, height):
                self.assertEqual(side & (side - 1), 0, f"{relative} is {width}x{height}")

    def test_expected_output_set(self) -> None:
        names = {Path(relative).name for relative in self.digests}
        self.assertTrue({"leaf_card_atlas.png", "leaf_card_normal.png", "leaf_card_surface.png",
                         "grain_ear_atlas.png"} <= names)
        for kind in gen.BARK_KINDS:
            self.assertIn(f"bark_{kind}_albedo.png", names)
            self.assertIn(f"bark_{kind}_normal.png", names)
        for kind in gen.GROUND_KINDS:
            self.assertIn(f"ground_{kind}_normal.png", names)

    def test_tiles_cover_every_species_the_leaf_geometry_maps(self) -> None:
        source = LEAF_GEOMETRY.read_text(encoding="utf-8")
        block = source.split("const CARD_TILES := {", 1)[1].split("}", 1)[0]
        tiles = {tuple(map(int, match)) for match in re.findall(r"Vector2\((\d), (\d)\)", block)}
        self.assertGreater(len(tiles), 5)
        used = {(index % gen.GRID[0], index // gen.GRID[0]) for index in range(len(gen.TILES))}
        self.assertTrue(tiles <= used, f"leaf geometry references empty tiles {tiles - used}")
        self.assertEqual(gen.TILES[:5], ["birch", "oak", "maple", "linden", "apple"])
        self.assertEqual(gen.TILES[5:], ["spruce", "pine"])

    def test_alpha_coverage_stays_near_the_replaced_tiles(self) -> None:
        for species in gen.TILES:
            target = (gen.NEEDLES.get(species) or gen.LEAVES[species]).coverage
            coverage = float((self.tile(species)[..., 3] >= 128).mean())
            # Density may drop at most 0.16 below the R-1194 tile and never exceed it much.
            self.assertGreater(coverage, target - 0.16, species)
            self.assertLess(coverage, target + 0.05, species)

    def test_relative_detail_contract(self) -> None:
        for species in gen.TILES:
            tile = self.tile(species).astype(np.float64)
            opaque = tile[..., 3] >= 128
            mean = tile[opaque][:, :3].mean(axis=0) / 255.0
            np.testing.assert_allclose(mean, [0.5, 0.5, 0.5], atol=0.04, err_msg=species)

    def test_petiole_end_is_at_the_bottom_edge(self) -> None:
        for species in gen.TILES:
            alpha = self.tile(species)[..., 3] >= 128
            self.assertTrue(alpha[-6:, 200:312].any(), f"{species} twig does not reach the bottom")
            self.assertFalse(alpha[:2].any() or alpha[:, :2].any() or alpha[:, -2:].any(),
                             f"{species} touches the top or side edge")

    def test_transparent_texels_carry_leaf_colour(self) -> None:
        # Mip safety: empty texels must not be black or white, or edges halo.
        for species in gen.TILES:
            tile = self.tile(species).astype(np.float64)
            empty = tile[..., 3] == 0
            self.assertTrue(empty.any())
            colour = tile[empty][:, :3]
            self.assertGreater(colour.min(), 20.0, species)
            self.assertLess(colour.max(), 235.0, species)

    def test_normal_and_surface_maps_are_valid(self) -> None:
        normal = _load(self.first / gen.LEAF_DIR / "leaf_card_normal.png").astype(np.float64)
        vectors = normal / 255.0 * 2.0 - 1.0
        lengths = np.linalg.norm(vectors, axis=2)
        self.assertLess(np.abs(lengths - 1.0).max(), 0.03)
        self.assertTrue((vectors[..., 2] > 0.0).all())
        surface = _load(self.first / gen.LEAF_DIR / "leaf_card_surface.png")
        self.assertEqual(surface.shape[2], 3)
        opaque = self.tile("oak")[..., 3] >= 128
        oak_surface = self.tile("oak", "leaf_card_surface.png")
        self.assertGreater(oak_surface[opaque][:, 1].mean(), 60)  # leaves transmit light

    def test_plates_tile_seamlessly(self) -> None:
        for relative in self.digests:
            if "/bark/" not in relative and "/ground/" not in relative:
                continue
            plate = _load(self.first / relative).astype(np.float64)
            wrap = np.abs(plate[0] - plate[-1]).mean() + np.abs(plate[:, 0] - plate[:, -1]).mean()
            inner = np.abs(plate[0] - plate[1]).mean() + np.abs(plate[:, 0] - plate[:, 1]).mean()
            # The wrap seam is no rougher than an ordinary neighbouring row.
            self.assertLess(wrap, inner * 1.6 + 2.0, relative)

    def test_grain_atlas_has_four_ears(self) -> None:
        atlas = _load(self.first / gen.VEG_DIR / "grain" / "grain_ear_atlas.png")
        self.assertEqual(atlas.shape, (512, 1024, 4))
        for index, kind in enumerate(gen.EARS):
            tile = atlas[:, index * 256:(index + 1) * 256, 3] >= 128
            self.assertTrue(tile.any(), kind)
            self.assertFalse(tile[:2].any(), f"{kind} ear is clipped at the top")


class ReviewSheetTests(unittest.TestCase):
    def test_review_sheets_compare_each_species(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            out = Path(directory)
            atlas = ROOT / gen.LEAF_DIR / "leaf_card_atlas.png"
            sheets = gen.review_sheets(atlas, atlas, out)
            self.assertEqual([path.name for path in sheets],
                             [f"{species}_before_after.png" for species in gen.TILES])
            self.assertEqual(Image.open(sheets[0]).size, (1024, 256))


if __name__ == "__main__":
    unittest.main()
