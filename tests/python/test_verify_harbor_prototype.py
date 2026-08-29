#!/usr/bin/env python3
"""Tests for the static split harbour prototype contract verifier."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from tools.verify_harbor_prototype import validate

ROOT = Path(__file__).resolve().parents[2]
MAP_PATHS = (
    Path("content/maps/reval_harbor_north.rrmap"),
    Path("content/maps/reval_harbor_east.rrmap"),
)


class VerifyHarborPrototypeTest(unittest.TestCase):
    def test_repository_maps_pass(self) -> None:
        self.assertEqual(validate(ROOT), [])

    def test_stable_id_and_dimensions_are_rejected(self) -> None:
        with self._fixture() as root:
            path = root / MAP_PATHS[0]
            path.write_text(
                path.read_text(encoding="utf-8").replace(
                    "map reval_harbor_north loc.reval_harbor.north 160 108",
                    "map renamed_harbor loc.reval_harbor.north 161 109",
                    1,
                ),
                encoding="utf-8",
            )
            errors = validate(root)
            self.assertTrue(any("stable map ID" in error for error in errors), errors)
            self.assertTrue(any("expected dimensions 160x108" in error for error in errors), errors)

    def test_split_scene_and_research_references_are_required(self) -> None:
        with self._fixture() as root:
            path = root / MAP_PATHS[1]
            text = path.read_text(encoding="utf-8")
            text = text.replace('source "scenes/harbor/harbor_east.tscn"\n', "", 1)
            text = text.replace('source "docs/reports/reval_harbour_1343_research.md"\n', "", 1)
            path.write_text(text, encoding="utf-8")
            errors = validate(root)
            self.assertTrue(any("missing split scene reference" in error for error in errors), errors)
            self.assertTrue(any("missing 1343 harbour research reference" in error for error in errors), errors)

    def test_activation_drift_is_rejected(self) -> None:
        with self._fixture() as root:
            path = root / MAP_PATHS[0]
            path.write_text(
                path.read_text(encoding="utf-8").replace(
                    "scope=prototype active=false", "scope=production active=true", 1
                ),
                encoding="utf-8",
            )
            errors = validate(root)
            self.assertTrue(any("scope=prototype active=false" in error for error in errors), errors)

    def test_missing_reciprocal_transition_is_rejected(self) -> None:
        with self._fixture() as root:
            path = root / MAP_PATHS[1]
            path.write_text(
                "\n".join(
                    line
                    for line in path.read_text(encoding="utf-8").splitlines()
                    if not line.startswith("transition to_harbor_north ")
                )
                + "\n",
                encoding="utf-8",
            )
            errors = validate(root)
            self.assertTrue(any("to_harbor_north" in error for error in errors), errors)

    def _fixture(self):
        temporary = tempfile.TemporaryDirectory()
        root = Path(temporary.name)
        for relative in MAP_PATHS:
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
