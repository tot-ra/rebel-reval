from __future__ import annotations

import importlib.util
import json
import re
import struct
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FLORA_FAUNA_PATH = ROOT / "docs" / "FLORA_FAUNA.md"
BIRD_LEDGER_ROW_RE = re.compile(r"^\| .*? \| `bird\.([a-z0-9_]+)` \|", re.MULTILINE)


def _documented_bird_ids() -> set[str]:
    text = FLORA_FAUNA_PATH.read_text(encoding="utf-8")
    start = text.index("## Bird model ledger")
    end = text.index("## Mammal model ledger", start)
    return set(BIRD_LEDGER_ROW_RE.findall(text[start:end]))


def _load_verify_module():
    path = ROOT / "tools" / "verify_bird_models.py"
    spec = importlib.util.spec_from_file_location("verify_bird_models", path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

def _write_glb(path: Path, document: dict) -> None:
  encoded = json.dumps(document, separators=(",", ":")).encode("utf-8")
  padded_json = encoded + b" " * (-len(encoded) % 4)
  payload = b"glTF" + struct.pack("<II", 2, 12 + 8 + len(padded_json) + 8)
  payload += struct.pack("<I4s", len(padded_json), b"JSON") + padded_json
  payload += struct.pack("<I4s", 0, b"BIN\0")
  path.write_bytes(payload)


class VerifyBirdModelsTests(unittest.TestCase):
  def test_reference_ledger_matches_catalog_and_authored_species(self) -> None:
    verify = _load_verify_module()
    catalog_species = set(verify.parse_bird_catalog())
    documented_species = _documented_bird_ids()
    self.assertEqual(documented_species, catalog_species)

    authored_species = {
      path.parent.name
      for path in (ROOT / "assets" / "birds").glob("*/*.glb")
      if path.name in {"standing.glb", "perched.glb", "gliding.glb"}
      or re.fullmatch(r"gliding_\d{2}\.glb", path.name)
    }
    self.assertTrue(
      authored_species <= documented_species,
      "authored bird species missing from FLORA_FAUNA.md: %s"
      % sorted(authored_species - documented_species),
    )

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

  def test_malformed_ambient_glb_returns_diagnostic(self) -> None:
    verify = _load_verify_module()
    with tempfile.TemporaryDirectory() as tmp:
      birds_dir = Path(tmp) / "birds" / "herring_gull"
      birds_dir.mkdir(parents=True)
      _write_glb(
        birds_dir / "standing.glb",
        {
          "asset": {"version": "2.0"},
          "meshes": [{"primitives": [{"indices": 0}]}],
          "accessors": [],
        },
      )
      errors = verify.verify(birds_dir=birds_dir.parent, root=ROOT)
      self.assertTrue(errors)
      self.assertIn("malformed", " ".join(errors).lower())

  def test_malformed_gait_glb_missing_accessor_returns_diagnostic(self) -> None:
    verify = _load_verify_module()
    with tempfile.TemporaryDirectory() as tmp:
      path = Path(tmp) / "chicken" / "walking.glb"
      path.parent.mkdir(parents=True)
      _write_glb(
        path,
        {
          "asset": {"version": "2.0"},
          "meshes": [{"primitives": [{"indices": 0}]}],
          "accessors": [],
        },
      )
      errors = verify.inspect_gait_glb(path, expected_scale_m=0.34)
      self.assertTrue(errors)
      self.assertIn("malformed GLB", " ".join(errors))
      self.assertIn("out of range", " ".join(errors))




if __name__ == "__main__":
  unittest.main()
