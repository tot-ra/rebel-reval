from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _load_verify_module():
    path = ROOT / "tools" / "verify_bird_models.py"
    spec = importlib.util.spec_from_file_location("verify_bird_models", path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class VerifyBirdModelsTests(unittest.TestCase):
  def test_catalog_parses_thirty_species_with_scale(self) -> None:
    verify = _load_verify_module()
    catalog = verify.parse_bird_catalog()
    self.assertEqual(len(catalog), 30)
    self.assertAlmostEqual(catalog["herring_gull"]["scale_m"], 0.60)
    self.assertGreater(catalog["white_tailed_eagle"]["wing_span"], catalog["white_tailed_eagle"]["scale_m"])

  def test_verify_passes_with_empty_birds_root(self) -> None:
    verify = _load_verify_module()
    with tempfile.TemporaryDirectory() as tmp:
      birds_dir = Path(tmp) / "birds"
      birds_dir.mkdir()
      errors = verify.verify(birds_dir=birds_dir, root=ROOT)
      self.assertEqual(errors, [])

  def test_unknown_species_folder_fails(self) -> None:
    verify = _load_verify_module()
    with tempfile.TemporaryDirectory() as tmp:
      birds_dir = Path(tmp) / "birds"
      (birds_dir / "not_a_bird").mkdir(parents=True)
      errors = verify.verify(birds_dir=birds_dir, root=ROOT)
      self.assertTrue(any("unknown species folder" in error for error in errors))

  def test_partial_flap_cycle_fails(self) -> None:
    verify = _load_verify_module()
    with tempfile.TemporaryDirectory() as tmp:
      birds_dir = Path(tmp) / "birds"
      species_dir = birds_dir / "herring_gull"
      species_dir.mkdir(parents=True)
      (species_dir / "gliding_00.glb").write_bytes(b"placeholder")
      errors = verify.verify(birds_dir=birds_dir, root=ROOT)
      self.assertTrue(any("partial flap cycle" in error for error in errors))


if __name__ == "__main__":
  unittest.main()
