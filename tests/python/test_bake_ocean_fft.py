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


if __name__ == "__main__":
    unittest.main()
