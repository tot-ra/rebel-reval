#!/usr/bin/env python3
"""Tests for the P0-153 seeded crowd body variation generator."""

from __future__ import annotations

import json
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import character_specs  # noqa: E402
from character_specs import (  # noqa: E402
    CHARACTERS,
    CROWD_DYES,
    CROWD_MANIFEST,
    CROWD_ROSTER,
    CROWD_TEMPLATES,
    crowd_manifest,
    crowd_variant_entry,
    crowd_variant_name,
    spec,
)


class CrowdVariationTests(unittest.TestCase):
    def test_same_seed_yields_the_same_body(self) -> None:
        for template in CROWD_TEMPLATES:
            self.assertEqual(crowd_variant_entry(template, 7), crowd_variant_entry(template, 7))

    def test_seed_is_stable_across_processes(self) -> None:
        # String-seeded random.Random must not depend on PYTHONHASHSEED.
        code = (
            "import json,sys; sys.path.insert(0, 'tools'); "
            "import character_specs as c; "
            "print(json.dumps(c.crowd_variant_entry('townsman', 3), sort_keys=True))"
        )
        outputs = {
            subprocess.check_output(
                [sys.executable, "-c", code],
                cwd=ROOT,
                env={"PYTHONHASHSEED": hash_seed},
                text=True,
            )
            for hash_seed in ("0", "12345")
        }
        self.assertEqual(len(outputs), 1)

    def test_different_seeds_vary_height_build_skin_and_garments(self) -> None:
        for template in CROWD_TEMPLATES:
            entries = [crowd_variant_entry(template, seed) for seed in range(1, 13)]
            statures = {entry["crowd"]["stature_factor"] for entry in entries}
            builds = {entry["shape"]["bulk"] for entry in entries}
            skins = {entry["palette"]["skin"] for entry in entries}
            tunics = {entry["crowd"]["dyes"]["tunic"] for entry in entries}
            self.assertEqual(len(statures), len(entries), template)
            self.assertEqual(len(builds), len(entries), template)
            self.assertEqual(len(skins), len(entries), template)
            self.assertGreaterEqual(len(tunics), 4, template)
            low, high = CROWD_TEMPLATES[template]["stature_range"]
            self.assertTrue(all(low <= value <= high for value in statures))

    def test_garments_use_the_period_dye_palette(self) -> None:
        for template, seed in CROWD_ROSTER:
            dyes = crowd_variant_entry(template, seed)["crowd"]["dyes"]
            for slot in ("tunic", "outerwear", "pants", "accent"):
                self.assertIn(dyes[slot], CROWD_DYES)

    def test_apron_is_never_paired_with_a_long_hem(self) -> None:
        for seed in range(1, 40):
            features = crowd_variant_entry("townsman", seed)["features"]
            if features["outerwear"] == "apron":
                self.assertEqual(features["tunic_length"], "short")

    def test_roster_is_registered_as_tier_one_specs(self) -> None:
        for template, seed in CROWD_ROSTER:
            name = crowd_variant_name(template, seed)
            self.assertIn(name, CHARACTERS)
            resolved = spec(name)
            self.assertEqual(resolved["fidelity_tier"], 1)
            self.assertEqual(resolved["output"], f"assets/characters/shared/{name}.glb")
            self.assertTrue((ROOT / resolved["output"]).is_file(), name)
            self.assertTrue((ROOT / f"assets/characters/variants/{name}.tscn").is_file(), name)
            self.assertTrue(set(resolved["material_response"]) == {"cloth", "leather"})

    def test_authored_specs_have_no_material_response(self) -> None:
        # Keeps authored bodies byte-for-byte rebuild compatible.
        for name in ("hero", "mart", "townswoman", "innkeeper"):
            self.assertEqual(spec(name)["material_response"], {})

    def test_committed_manifest_matches_the_generator(self) -> None:
        committed = json.loads((ROOT / CROWD_MANIFEST).read_text(encoding="utf-8"))
        self.assertEqual(committed, json.loads(json.dumps(crowd_manifest())))
        self.assertEqual(character_specs._main(["--check-crowd-manifest"]), 0)


if __name__ == "__main__":
    unittest.main()
