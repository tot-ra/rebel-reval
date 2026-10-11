#!/usr/bin/env python3
"""Tests for the R-446 Lower Town population profile capture verifier."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from verify_lower_town_population_profiles import (  # noqa: E402
    EXPECTED_HEIGHT,
    EXPECTED_WIDTH,
    main,
    validate,
)


class VerifyLowerTownPopulationProfilesTest(unittest.TestCase):
    def test_current_repository_passes(self) -> None:
        self.assertEqual(validate(root=ROOT), [])

    def test_missing_capture_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            manifest = {
                "map_id": "lower_town_slice",
                "source": "res://content/maps/lower_town_slice.rrmap",
                "scenarios": [
                    {
                        "id": "day",
                        "capture": "res://docs/reports/images/population/lower_town_population_day.png",
                        "civilian_count": 18,
                        "watch_count": 3,
                        "total_count": 21,
                        "active_count": 21,
                        "seed": 1343,
                        "viewport_px": [EXPECTED_WIDTH, EXPECTED_HEIGHT],
                        "placement_zone_counts": {
                            "street_frontage": 7,
                            "work_yard": 7,
                            "residential_yard": 7,
                        },
                    }
                ],
            }
            manifest_path = root / "docs/reports/population_clusters_r419.json"
            manifest_path.parent.mkdir(parents=True)
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")

            errors = validate(root=root)
            self.assertTrue(any("missing population capture" in error for error in errors))

    def test_main_returns_zero_on_current_repository(self) -> None:
        self.assertEqual(main(), 0)


if __name__ == "__main__":
    unittest.main()
