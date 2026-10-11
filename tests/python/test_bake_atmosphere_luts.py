"""WS-09: analytic oracles for the offline Hillaire atmosphere LUT bake."""

from __future__ import annotations

import contextlib
import io
import struct
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

import bake_atmosphere_luts as bake  # noqa: E402

SCALES = bake.AtmosphereScales()


def read_exr(data: bytes) -> dict[str, np.ndarray]:
    """Pure-Python reader for the single-part, uncompressed, HALF scanline subset."""
    magic, version = struct.unpack_from("<ii", data, 0)
    assert magic == 20000630 and version == 2, (magic, version)
    pos = 8
    attributes: dict[str, tuple[str, bytes]] = {}
    while data[pos] != 0:
        name_end = data.index(b"\0", pos)
        kind_end = data.index(b"\0", name_end + 1)
        size = struct.unpack_from("<i", data, kind_end + 1)[0]
        payload = data[kind_end + 5:kind_end + 5 + size]
        attributes[data[pos:name_end].decode()] = (data[name_end + 1:kind_end].decode(), payload)
        pos = kind_end + 5 + size
    pos += 1
    assert attributes["compression"] == ("compression", b"\0")
    assert attributes["lineOrder"] == ("lineOrder", b"\0")
    kind, chlist = attributes["channels"]
    assert kind == "chlist"
    channels = []
    cpos = 0
    while chlist[cpos] != 0:
        end = chlist.index(b"\0", cpos)
        pixel_type, _linear, x_sampling, y_sampling = struct.unpack_from("<iB3xii", chlist, end + 1)
        assert (pixel_type, x_sampling, y_sampling) == (1, 1, 1)
        channels.append(chlist[cpos:end].decode())
        cpos = end + 17
    xmin, ymin, xmax, ymax = struct.unpack("<4i", attributes["dataWindow"][1])
    width, height = xmax - xmin + 1, ymax - ymin + 1
    offsets = struct.unpack_from(f"<{height}Q", data, pos)
    planes = {name: np.zeros((height, width)) for name in channels}
    for offset in offsets:
        y, size = struct.unpack_from("<ii", data, offset)
        assert size == len(channels) * width * 2
        line = np.frombuffer(data, dtype="<f2", count=len(channels) * width, offset=offset + 8)
        for index, name in enumerate(channels):
            planes[name][y - ymin] = line[index * width:(index + 1) * width]
    return planes


class AtmosphereLutTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.transmittance = bake.bake_transmittance(SCALES)
        cls.multiscatter = bake.bake_multiscatter(cls.transmittance, SCALES)

    def test_zenith_transmittance_matches_column_optical_depth(self) -> None:
        oracle = np.exp(-(
            np.asarray(bake.RAYLEIGH_SCATTERING) * 8.0
            + bake.MIE_EXTINCTION * 1.2
            + np.asarray(bake.OZONE_ABSORPTION) * 15.0
        ))
        np.testing.assert_allclose(oracle, (0.940, 0.868, 0.762), atol=0.001)
        # Texel (0, 0) is exactly r = R_ground, mu = 1 under the sub-UV mapping.
        r, mu = bake.transmittance_r_mu(0.5 / bake.TRANSMITTANCE_WIDTH, 0.5 / bake.TRANSMITTANCE_HEIGHT)
        self.assertAlmostEqual(float(r), bake.R_GROUND, places=9)
        self.assertAlmostEqual(float(mu), 1.0, places=12)
        np.testing.assert_allclose(self.transmittance[0, 0], (0.940, 0.868, 0.762), atol=0.005)

    def test_horizon_is_darker_than_zenith_and_redder(self) -> None:
        horizon = self.transmittance[0, -1]
        zenith = self.transmittance[0, 0]
        self.assertTrue(np.all(horizon < 0.2 * zenith), horizon)
        self.assertLess(horizon[2], horizon[0])

    def test_transmittance_is_monotonic_in_mu(self) -> None:
        # Columns run from mu = 1 to the ground horizon, so T must never increase along a row.
        self.assertTrue(np.all(np.diff(self.transmittance, axis=1) <= 1e-12))
        _, mu = bake.transmittance_r_mu(*np.meshgrid(
            bake.texel_centres(bake.TRANSMITTANCE_WIDTH), bake.texel_centres(bake.TRANSMITTANCE_HEIGHT)))
        self.assertTrue(np.all(np.diff(mu, axis=1) < 0.0))
        self.assertTrue(np.all((self.transmittance > 0.0) & (self.transmittance <= 1.0)))

    def test_transmittance_uv_round_trips(self) -> None:
        rng = np.random.default_rng(9)
        r = bake.R_GROUND + rng.uniform(0.0, bake.R_TOP - bake.R_GROUND, 4096)
        mu_horizon = -np.sqrt(np.maximum(1.0 - (bake.R_GROUND / r) ** 2, 0.0))
        mu = rng.uniform(mu_horizon, 1.0)
        r_back, mu_back = bake.transmittance_r_mu(*bake.transmittance_uv(r, mu))
        np.testing.assert_allclose(r_back, r, atol=1e-4)
        np.testing.assert_allclose(mu_back, mu, atol=1e-4)
        u, v = rng.uniform(0.0, 1.0, (2, 4096)) * [[1.0 - 1.0 / bake.TRANSMITTANCE_WIDTH], [1.0 - 1.0 / bake.TRANSMITTANCE_HEIGHT]]
        u += 0.5 / bake.TRANSMITTANCE_WIDTH
        v += 0.5 / bake.TRANSMITTANCE_HEIGHT
        u_back, v_back = bake.transmittance_uv(*bake.transmittance_r_mu(u, v))
        np.testing.assert_allclose(u_back, u, atol=1e-4)
        np.testing.assert_allclose(v_back, v, atol=1e-4)

    def test_multiscatter_is_non_negative_and_in_sanity_band(self) -> None:
        psi = self.multiscatter.psi_ms
        self.assertTrue(np.all(psi >= 0.0))
        self.assertTrue(np.all(np.isfinite(psi)))
        # Psi_ms replaces the sun term T_sun * phase in the higher-order source (Hillaire eq. 10).
        # At the ground with the sun at the zenith it must be 1-10 % of the single-scattering
        # order, i.e. of the unit-illuminance sun transmittance.
        ground_zenith_sun = psi[0, bake.MULTISCATTER_SIZE - 1]
        ratio = ground_zenith_sun / self.transmittance[0, 0]
        self.assertTrue(np.all((ratio > 0.01) & (ratio < 0.1)), ratio)
        # Shorter wavelengths scatter more, so blue multi-scattering dominates.
        self.assertLess(ground_zenith_sun[0], ground_zenith_sun[2])
        # The transfer factor is a proper energy fraction, so the geometric series converges.
        self.assertTrue(np.all((self.multiscatter.transfer > 0.0) & (self.multiscatter.transfer < 1.0)))
        # The sun far below the horizon lights nothing near the ground.
        np.testing.assert_allclose(psi[0, 0], 0.0, atol=1e-6)

    def test_multiscatter_uv_hits_texel_centres(self) -> None:
        n = bake.MULTISCATTER_SIZE
        u, v = bake.multiscatter_uv(bake.R_GROUND, 1.0)
        self.assertAlmostEqual(float(u), (n - 0.5) / n)
        self.assertAlmostEqual(float(v), 0.5 / n)

    def test_fibonacci_sphere_is_unit_and_balanced(self) -> None:
        dirs = bake.fibonacci_sphere(bake.MULTISCATTER_DIRECTIONS)
        np.testing.assert_allclose(np.linalg.norm(dirs, axis=1), 1.0, atol=1e-12)
        np.testing.assert_allclose(dirs.mean(axis=0), 0.0, atol=0.02)

    def test_scales_are_bake_arguments(self) -> None:
        hazy = bake.bake_transmittance(bake.AtmosphereScales(mie=1.5))
        self.assertTrue(np.all(hazy[0, 0] < self.transmittance[0, 0]))

    def test_bake_is_deterministic_and_matches_committed_assets(self) -> None:
        first = bake.bake_bytes(SCALES)
        second = bake.bake_bytes(SCALES)
        self.assertEqual(first, second)
        for name, data in first.items():
            self.assertLess(len(data), bake.MAX_OUTPUT_BYTES, name)
            self.assertEqual((bake.DEFAULT_OUT / name).read_bytes(), data, f"{name} is stale; re-run the bake")

    def test_exr_writer_parses_back(self) -> None:
        planes = read_exr(bake.encode_exr(self.transmittance))
        self.assertEqual(sorted(planes), ["A", "B", "G", "R"])
        self.assertEqual(planes["R"].shape, (bake.TRANSMITTANCE_HEIGHT, bake.TRANSMITTANCE_WIDTH))
        rgb = np.stack([planes["R"], planes["G"], planes["B"]], axis=-1)
        np.testing.assert_array_equal(rgb, bake.quantize_half(self.transmittance))
        np.testing.assert_array_equal(planes["A"], 1.0)
        ms = read_exr(bake.encode_exr(self.multiscatter.psi_ms))
        np.testing.assert_allclose(ms["B"], self.multiscatter.psi_ms[..., 2], rtol=1e-3, atol=1e-7)

    def test_check_mode_detects_stale_output(self) -> None:
        with tempfile.TemporaryDirectory() as tmp, contextlib.redirect_stdout(io.StringIO()), \
                contextlib.redirect_stderr(io.StringIO()):
            out = Path(tmp)
            self.assertEqual(bake.main(["--out", str(out)]), 0)
            self.assertEqual(bake.main(["--out", str(out), "--check"]), 0)
            (out / bake.MULTISCATTER_FILE).write_bytes(b"stale")
            self.assertEqual(bake.main(["--out", str(out), "--check"]), 1)


if __name__ == "__main__":
    unittest.main()
