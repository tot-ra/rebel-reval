"""CLI compatibility and module boundaries for the vegetation atlas generator."""

from __future__ import annotations

import contextlib
import importlib
import io
import runpy
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/assets"))

import generate_vegetation_atlases as gen  # noqa: E402
from vegetation_atlases import foliage, grain, raster, species, surfaces  # noqa: E402


class EntryPointTests(unittest.TestCase):
    def test_script_entry_point_works_outside_the_repository(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            result = subprocess.run(
                [sys.executable, str(ROOT / "tools/assets/generate_vegetation_atlases.py"),
                 "--help"],
                cwd=directory, capture_output=True, text=True, check=True, timeout=30,
            )
        self.assertIn("--out-root", result.stdout)
        self.assertIn("--compare-old", result.stdout)
        self.assertIn("--tune", result.stdout)

    def test_legacy_wrapper_keeps_its_no_arguments_contract(self) -> None:
        # The legacy wrapper discards flags, even --help. Mock generation so this
        # compatibility check cannot rewrite the repository's textures.
        with patch.object(gen, "main", return_value=0) as main, \
                patch.object(sys, "argv", ["legacy", "--ignored"]):
            with self.assertRaises(SystemExit) as exit_result:
                runpy.run_path(str(ROOT / "tools/assets/build_leaf_card_atlas.py"),
                               run_name="__main__")
            self.assertEqual(exit_result.exception.code, 0)
            self.assertEqual(sys.argv, ["legacy"])
        main.assert_called_once_with()

    def test_module_entry_point_works(self) -> None:
        result = subprocess.run(
            [sys.executable, "-m", "tools.assets.generate_vegetation_atlases", "--help"],
            cwd=ROOT, capture_output=True, text=True, check=True, timeout=30,
        )
        self.assertIn("--out-root", result.stdout)

    def test_package_import_can_render_without_script_path_setup(self) -> None:
        result = subprocess.run(
            [sys.executable, "-c",
             "from tools.assets.vegetation_atlases import foliage, grain, surfaces; "
             "assert foliage.draw_broadleaf_tile('birch', size=64).w == 64; "
             "assert callable(grain.build_ear_atlas); assert callable(surfaces.bark_plate)"],
            cwd=ROOT, capture_output=True, text=True, check=True, timeout=30,
        )
        self.assertEqual(result.stderr, "")

    def test_cli_writes_requested_root_and_review_sheets(self) -> None:
        args = ["generator", "--out-root", "/tmp/atlas-output", "--compare-old",
                "/tmp/old-atlas.png", "--sheets", "/tmp/atlas-sheets"]
        with patch.object(sys, "argv", args), \
                patch.object(gen, "generate", return_value={"leaf.png": "abc"}) as generate, \
                patch.object(gen, "review_sheets", return_value=[Path("sheet.png")]) as review, \
                contextlib.redirect_stdout(io.StringIO()) as output:
            self.assertEqual(gen.main(), 0)
        generate.assert_called_once_with(Path("/tmp/atlas-output"))
        review.assert_called_once_with(
            Path("/tmp/old-atlas.png"),
            Path("/tmp/atlas-output") / gen.LEAF_DIR / "leaf_card_atlas.png",
            Path("/tmp/atlas-sheets"),
        )
        self.assertEqual(output.getvalue(), "leaf.png SHA-256 abc\nreview sheet sheet.png\n")

    def test_tune_does_not_generate_or_write_review_sheets(self) -> None:
        with patch.object(sys, "argv", ["generator", "--tune"]), \
                patch.object(gen, "tune", return_value=(1.5, 0.4)) as tune, \
                patch.object(gen, "generate") as generate, \
                patch.object(gen, "review_sheets") as review, \
                contextlib.redirect_stdout(io.StringIO()) as output:
            self.assertEqual(gen.main(), 0)
        self.assertEqual([call.args[0] for call in tune.call_args_list], gen.TILES)
        self.assertEqual(len(output.getvalue().splitlines()), len(gen.TILES))
        generate.assert_not_called()
        review.assert_not_called()

    def test_entry_point_reuses_modules_and_stable_layout(self) -> None:
        self.assertIs(gen.LEAVES, species.LEAVES)
        self.assertIs(gen.NEEDLES, species.NEEDLES)
        self.assertIs(gen.TILES, species.TILES)
        self.assertIs(gen.build_leaf_atlas, foliage.build_leaf_atlas)
        self.assertIs(gen.build_ear_atlas, grain.build_ear_atlas)
        self.assertIs(gen.species_rng, raster.species_rng)
        self.assertIs(gen.bark_plate, surfaces.bark_plate)
        module = importlib.import_module("tools.assets.generate_vegetation_atlases")
        self.assertEqual(module.ROOT, ROOT)
        self.assertEqual(module.TILES, gen.TILES)


if __name__ == "__main__":
    unittest.main()
