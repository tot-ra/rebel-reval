"""WS-03 contract tests for tools/bake_ocean_fft.py (small N so the suite stays fast)."""

from __future__ import annotations

import math
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

import bake_ocean_fft as bake  # noqa: E402

SEA = bake.PROFILES["baltic_reference"]["sea"]
SMALL = bake.CascadeSpec("t0", 32.0, 32, 32.0, 4.0, 12.8, 64)
SMALL_NODISP = bake.CascadeSpec("t1", 8.0, 32, 4.0, 1.0, 6.4, 64, False)


def small_field(seed: int = 7, *, unit_amplitude: bool = False) -> bake.CascadeField:
    return bake.build_cascade(SMALL, SEA, np.random.default_rng(seed), unit_amplitude=unit_amplitude)


class OceanFftPhysicsTests(unittest.TestCase):
    def test_time_periodicity(self) -> None:
        field = small_field()
        start = bake.evaluate_complex(field, 0.0)
        end = bake.evaluate_complex(field, SMALL.period_s)
        for name in start:
            self.assertLess(float(np.max(np.abs(end[name] - start[name]))), 1e-6, name)

    def test_ifft_matches_direct_fourier_sum_and_wraps(self) -> None:
        field = small_field()
        dy = bake.evaluate(field, 1.3)["dy"]
        h = bake.spectrum_at(field, 1.3)
        dx = SMALL.patch_m / SMALL.n
        # Direct synthesis at a few texels pins down the sign/scale convention of ifft2.
        for zi, xi in ((0, 0), (5, 17), (31, 3)):
            direct = np.sum(h * np.exp(1j * (field.kx * xi * dx + field.kz * zi * dx)))
            self.assertAlmostEqual(float(direct.real), float(dy[zi, xi]), places=9)
        # One patch further along either axis is the same point, so the last row/column must
        # continue into the first without a seam.
        step = max(float(np.max(np.abs(np.diff(dy, axis=1)))), float(np.max(np.abs(np.diff(dy, axis=0)))))
        self.assertLessEqual(float(np.max(np.abs(dy[:, -1] - dy[:, 0]))), step + 1e-12)
        self.assertLessEqual(float(np.max(np.abs(dy[-1, :] - dy[0, :]))), step + 1e-12)
        wrapped = np.sum(h * np.exp(1j * field.kx * SMALL.patch_m))
        self.assertAlmostEqual(float(wrapped.real), float(dy[0, 0]), places=9)

    def test_output_is_real(self) -> None:
        field = small_field()
        for t in (0.0, 0.77, 5.5):
            for name, value in bake.evaluate_complex(field, t).items():
                peak = float(np.max(np.abs(value.real)))
                self.assertLess(float(np.max(np.abs(value.imag))), 1e-5 * peak, name)

    def test_unit_amplitude_energy_matches_spectrum(self) -> None:
        field = small_field(unit_amplitude=True)
        dt = SMALL.period_s / SMALL.frames
        # Averaging over the loop cancels the h0(k)*h0(-k) cross terms exactly.
        variance = float(np.mean([np.var(bake.evaluate(field, f * dt)["dy"]) for f in range(SMALL.frames)]))
        expected_hs = 4.0 * math.sqrt(bake.band_energy(field))
        self.assertGreater(expected_hs, 0.0)
        self.assertAlmostEqual(4.0 * math.sqrt(variance) / expected_hs, 1.0, delta=0.02)

    def test_directional_spreading_is_normalised(self) -> None:
        theta = np.linspace(-math.pi, math.pi, 20001)
        for omega in (0.8, 1.4, 3.0, 6.0):
            integral = np.trapezoid(bake.direction_spectrum(theta, np.full_like(theta, omega), SEA), theta)
            self.assertAlmostEqual(float(integral), 1.0, delta=0.02)

    def test_crests_compress(self) -> None:
        field = small_field()
        frames = [bake.evaluate(field, f * 0.2) for f in range(20)]
        dy = np.stack([f["dy"] for f in frames])
        jac = np.stack([bake.jacobian(f) for f in frames])
        self.assertLess(float(jac[dy > 0].mean()), float(jac[dy < 0].mean()))

    def test_band_cut_excludes_other_cascades(self) -> None:
        field = small_field()
        kept = field.energy > 0.0
        self.assertTrue(np.all(field.k[kept] >= SMALL.k_low))
        self.assertTrue(np.all(field.k[kept] < SMALL.k_high))
        self.assertTrue(np.all(field.h0[~kept] == 0.0))


class OceanFftBakeTests(unittest.TestCase):
    def test_frame_rate_guard(self) -> None:
        too_few = bake.CascadeSpec("slow", 32.0, 32, 32.0, 4.0, 12.8, 32)
        with self.assertRaises(SystemExit) as ctx:
            bake.check_frame_rate(too_few, SEA.depth)
        self.assertIn("frames per period", str(ctx.exception.code))
        bake.check_frame_rate(SMALL, SEA.depth)  # the reference 8-frames layout passes

    def test_bake_is_deterministic_and_foam_loops(self) -> None:
        with tempfile.TemporaryDirectory() as a, tempfile.TemporaryDirectory() as b:
            first = bake.bake(SEA, (SMALL, SMALL_NODISP), 1343, Path(a), profile_name="test")
            bake.bake(SEA, (SMALL, SMALL_NODISP), 1343, Path(b), profile_name="test")
            names = sorted(p.name for p in Path(a).iterdir())
            self.assertEqual(names, ["ocean_fft_profile.json", "t0_deriv.png", "t0_disp.png", "t1_deriv.png"])
            for name in names:
                self.assertEqual((Path(a) / name).read_bytes(), (Path(b) / name).read_bytes(), name)

        for result in first["_bakes"]:
            dt = result.spec.period_s / result.spec.frames
            gen0 = np.clip((bake.FOAM_BIAS - bake.jacobian(result.frames[0], result.foam_lambda)) * bake.FOAM_GAIN, 0.0, 1.0)
            wrap = np.clip(result.foam[-1] * math.exp(-bake.FOAM_DECAY * dt) + gen0 * bake.FOAM_ADD * dt, 0.0, 1.0)
            self.assertLess(float(np.max(np.abs(wrap - result.foam[0]))), 1.0 / 255.0, result.spec.name)

    def test_seed_changes_output(self) -> None:
        with tempfile.TemporaryDirectory() as a, tempfile.TemporaryDirectory() as b:
            bake.bake(SEA, (SMALL,), 1, Path(a), profile_name="test")
            bake.bake(SEA, (SMALL,), 2, Path(b), profile_name="test")
            self.assertNotEqual((Path(a) / "t0_disp.png").read_bytes(), (Path(b) / "t0_disp.png").read_bytes())

    def test_committed_reference_bake_has_not_drifted(self) -> None:
        committed = ROOT / "assets" / "water" / "ocean_fft" / "baltic_reference"
        if not (committed / "ocean_fft_profile.json").is_file():
            self.skipTest("reference bake not committed yet")
        self.assertEqual(bake.main(["--profile", "baltic_reference", "--check"]), 0)
        for path in committed.glob("*.png"):
            self.assertLess(path.stat().st_size, bake.MAX_OUTPUT_BYTES, path.name)


class FoamTileTests(unittest.TestCase):
    """WS-06 foam detail tile: seamless wrap, determinism, channel layout, size budget."""

    def test_edges_wrap_within_one_byte(self) -> None:
        # The tile is the function sampled at i/N; its next sample past the edge (u = 1)
        # must reproduce column 0 so a repeat sampler shows no seam.
        size = 64
        coords = np.arange(size + 1, dtype=np.float64) / size
        u, v = np.meshgrid(coords, coords)
        encoded = bake.encode_unit(bake.foam_tile_channels(u, v, 1343)).astype(np.int16)
        self.assertLessEqual(int(np.max(np.abs(encoded[:, -1] - encoded[:, 0]))), 1, "u wrap")
        self.assertLessEqual(int(np.max(np.abs(encoded[-1, :] - encoded[0, :]))), 1, "v wrap")

    def test_tile_is_deterministic_and_seeded(self) -> None:
        first = bake.foam_tile_image(1343, 64)
        self.assertTrue(np.array_equal(first, bake.foam_tile_image(1343, 64)))
        self.assertFalse(np.array_equal(first, bake.foam_tile_image(7, 64)))
        self.assertEqual(first.shape, (64, 64, 4))
        self.assertTrue(np.all(first[..., 3] == 255), "alpha is constant 1")
        for channel in range(3):
            self.assertGreater(int(first[..., channel].max()) - int(first[..., channel].min()), 128, channel)

    def test_streak_channel_is_stretched_along_x(self) -> None:
        tile = bake.foam_tile_image(1343).astype(np.float64)[..., 2]
        along = float(np.mean(np.abs(np.diff(tile, axis=1))))
        across = float(np.mean(np.abs(np.diff(tile, axis=0))))
        self.assertGreater(across, along * 3.0, "streaks vary much faster across the wind than along it")

    def test_committed_tile_matches_generator_and_budget(self) -> None:
        committed = ROOT / "assets" / "water" / "ocean_fft" / "foam_tile.png"
        if not committed.is_file():
            self.skipTest("foam tile not committed yet")
        with tempfile.TemporaryDirectory() as tmp:
            fresh = Path(tmp) / "foam_tile.png"
            self.assertEqual(bake.main(["foam-tile", "--out", str(fresh), "--seed", "1343"]), 0)
            self.assertEqual(fresh.read_bytes(), committed.read_bytes())
        self.assertLess(committed.stat().st_size, 300 * 1024)


class CausticTileTests(unittest.TestCase):
    """WS-07 photon-splat caustic tiles (small N; the committed tiles are checked by bytes)."""

    SPEC = bake.CascadeSpec("caustics_test", 4.0, 64, 4.0, 0.25, 1.0, 1, False)

    def tile(self, seed: int = 1343) -> bake.CausticTile:
        return bake.bake_caustic_tile(self.SPEC, SEA, np.random.default_rng(seed), 1.2)

    def test_splat_conserves_energy(self) -> None:
        tile = self.tile()
        # One unit per surface texel before splatting; bilinear weights sum to 1 per texel.
        self.assertAlmostEqual(float(np.sum(tile.histogram)), self.SPEC.n**2, places=6)
        blurred = bake.blur_periodic(tile.histogram, bake.CAUSTICS_BLUR_SIGMA_TEXELS)
        self.assertAlmostEqual(float(np.sum(blurred)), self.SPEC.n**2, places=6)

    def test_flat_surface_gives_uniform_light(self) -> None:
        flat = np.zeros((16, 16))
        offsets = bake.caustic_landing_offsets(flat, flat, 1.2)
        self.assertLess(float(np.max(np.abs(offsets))), 1e-12)
        self.assertTrue(np.allclose(bake.splat_periodic(offsets), 1.0))

    def test_refraction_bends_toward_the_normal(self) -> None:
        # Height rising toward +X tilts the normal to -X; the transmitted ray bends between the
        # incident ray and -N, so it lands downslope (+X). The offset scales with depth.
        slope = np.full((2, 2), 0.2)
        zero = np.zeros((2, 2))
        shallow = bake.caustic_landing_offsets(slope, zero, 1.0)
        deep = bake.caustic_landing_offsets(slope, zero, 2.0)
        self.assertTrue(np.all(shallow[..., 0] > 0.0))
        self.assertTrue(np.allclose(deep, 2.0 * shallow))
        self.assertTrue(np.allclose(shallow[..., 1], 0.0))

    def test_mean_is_one_and_values_fit_the_encoding(self) -> None:
        values = self.tile().values
        self.assertAlmostEqual(float(np.mean(values)), 1.0, delta=0.01)
        self.assertGreaterEqual(float(np.min(values)), 0.0)
        self.assertLessEqual(float(np.max(values)), bake.CAUSTICS_ENCODE_SCALE)
        decoded = bake.encode_caustics(values).astype(np.float64) / 255.0 * bake.CAUSTICS_ENCODE_SCALE
        self.assertAlmostEqual(float(np.mean(decoded)), 1.0, delta=0.01)

    def test_tile_wraps_without_a_seam(self) -> None:
        values = self.tile().values
        step = max(float(np.max(np.abs(np.diff(values, axis=1)))), float(np.max(np.abs(np.diff(values, axis=0)))))
        self.assertLessEqual(float(np.max(np.abs(values[:, -1] - values[:, 0]))), step + 1e-9)
        self.assertLessEqual(float(np.max(np.abs(values[-1, :] - values[0, :]))), step + 1e-9)
        # A shifted copy is the same periodic field: rolling must not change the statistics.
        rolled = np.roll(values, (17, 29), (0, 1))
        self.assertAlmostEqual(float(np.std(rolled)), float(np.std(values)), places=12)

    def test_bake_is_deterministic_and_forms_a_net(self) -> None:
        first = self.tile().values
        self.assertTrue(np.array_equal(first, self.tile().values))
        self.assertFalse(np.array_equal(first, self.tile(7).values))
        self.assertGreater(float(np.std(first)), 0.15)

    def test_reference_tiles_focus_into_a_net(self) -> None:
        # A focused net, not a faint mottle: the committed bands and depths must keep bright
        # lines well above the mean (the contract's 0.5 m / 2 m cut-offs gave std < 0.2).
        with tempfile.TemporaryDirectory() as tmp:
            profile = bake.bake_caustics(SEA, 1343, Path(tmp))
        for entry in profile["tiles"]:
            self.assertGreater(entry["stored_std"], 0.5, entry["name"])
            self.assertTrue(0.5 < entry["min_pair_mean"] < 1.0, entry["name"])

    def test_committed_tiles_match_generator_and_budget(self) -> None:
        out = ROOT / "assets" / "water" / "ocean_fft"
        if not (out / "caustics_fine.png").is_file():
            self.skipTest("caustic tiles not committed yet")
        self.assertEqual(bake.main(["caustics", "--check", "--out", str(out)]), 0)
        for name in ("caustics_fine.png", "caustics_broad.png"):
            self.assertLess((out / name).stat().st_size, 1024 * 1024, name)


if __name__ == "__main__":
    unittest.main()
