import json
import tempfile
import unittest
from pathlib import Path

from tools.verify_north_quarter_activation import verify


ROOT = Path(__file__).resolve().parents[2]


class TestNorthQuarterActivation(unittest.TestCase):
    def test_repository_records_consistent_blocked_state(self):
        self.assertEqual([], verify(ROOT))

    def test_ledger_identity_must_match_north_quarter_activation(self):
        with self._fixture() as root:
            ledger_path = root / "docs/data/p4_020_north_quarter_activation.json"
            ledger = json.loads(ledger_path.read_text(encoding="utf-8"))
            ledger["task"] = "P4-019"
            ledger["map_id"] = "market_civic_quarter"
            ledger["scene_id"] = "reval_center"
            ledger_path.write_text(json.dumps(ledger), encoding="utf-8")
            errors = verify(root)
            self.assertTrue(any("ledger task must be P4-020" in error for error in errors), errors)
            self.assertTrue(
                any("ledger map_id must be north_quarter" in error for error in errors),
                errors,
            )
            self.assertTrue(
                any("ledger scene_id must be reval_north" in error for error in errors),
                errors,
            )

    def test_partial_activation_is_rejected(self):
        with self._fixture() as root:
            rrmap = root / "content/maps/north_quarter.rrmap"
            rrmap.write_text(
                rrmap.read_text(encoding="utf-8").replace(
                    "scope=prototype active=false", "scope=production active=true"
                ),
                encoding="utf-8",
            )
            errors = verify(root)
            self.assertTrue(any("partial activation" in error for error in errors), errors)

    def test_production_activation_requires_approval_and_parity_evidence(self):
        with self._fixture() as root:
            rrmap = root / "content/maps/north_quarter.rrmap"
            rrmap.write_text(
                rrmap.read_text(encoding="utf-8").replace(
                    "scope=prototype active=false", "scope=production active=true"
                ),
                encoding="utf-8",
            )
            catalog = root / "scripts/map/map_catalog.gd"
            catalog_text = catalog.read_text(encoding="utf-8")
            prototype_entry = (
                '"reval_north":\n\t'
                '{"path": "res://scenes/reval_north/reval_north.tscn", '
                '"scope": "prototype", "active": false}'
            )
            production_entry = prototype_entry.replace(
                '"scope": "prototype", "active": false',
                '"scope": "production", "active": true',
            )
            catalog_text = catalog_text.replace(prototype_entry, production_entry)
            self.assertNotEqual(prototype_entry, production_entry)
            self.assertIn(production_entry, catalog_text)
            catalog.write_text(catalog_text, encoding="utf-8")
            destinations_path = root / "content/transitions/active_destinations.json"
            destinations = json.loads(destinations_path.read_text(encoding="utf-8"))
            north = next(row for row in destinations["scenes"] if row["id"] == "reval_north")
            north["release"] = True
            destinations_path.write_text(json.dumps(destinations), encoding="utf-8")
            errors = verify(root)
            self.assertTrue(any("decision=approved" in error for error in errors), errors)
            self.assertTrue(any("accepted day/night parity" in error for error in errors), errors)

    def test_blocked_state_requires_all_named_dependencies(self):
        with self._fixture() as root:
            ledger_path = root / "docs/data/p4_020_north_quarter_activation.json"
            ledger = json.loads(ledger_path.read_text(encoding="utf-8"))
            ledger["blockers"].remove("P4-019")
            ledger_path.write_text(json.dumps(ledger), encoding="utf-8")
            errors = verify(root)
            self.assertTrue(any("P4-019" in error for error in errors), errors)

    def _fixture(self):
        temporary = tempfile.TemporaryDirectory()
        root = Path(temporary.name)
        paths = [
            "content/maps/north_quarter.rrmap",
            "scripts/map/map_catalog.gd",
            "content/transitions/active_destinations.json",
            "docs/data/p4_020_north_quarter_activation.json",
            "docs/adr/0008-three-act-campaign-and-faction-scope.md",
        ]
        for relative in paths:
            destination = root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes((ROOT / relative).read_bytes())

        class Fixture:
            def __enter__(self):
                return root

            def __exit__(self, exc_type, exc_value, traceback):
                temporary.cleanup()

        return Fixture()


if __name__ == "__main__":
    unittest.main()
