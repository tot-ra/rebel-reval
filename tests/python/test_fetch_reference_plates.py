#!/usr/bin/env python3
"""Tests for tools/research/fetch_reference_plates.py retention checks."""

from __future__ import annotations

import argparse
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS_RESEARCH = ROOT / "tools" / "research"
if str(TOOLS_RESEARCH) not in sys.path:
    sys.path.insert(0, str(TOOLS_RESEARCH))

import fetch_reference_plates as plates  # noqa: E402


class FetchReferencePlatesRetentionTest(unittest.TestCase):
    def test_repository_verify_passes(self) -> None:
        rows = plates.load_rows(plates.MANIFEST)
        args = argparse.Namespace(
            manifest=plates.MANIFEST,
            domain=None,
            slug=None,
            plate=None,
        )
        self.assertEqual(plates.verify(rows, args), 0)

    def test_over_cap_raster_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            reference_root = root / "history" / "reference" / "crafts" / "sample"
            reference_root.mkdir(parents=True)
            image_path = reference_root / "crafts.sample.01.jpg"
            from PIL import Image

            image = Image.new("RGB", (4000, 4000), color=(128, 64, 32))
            image.save(image_path, format="JPEG", quality=95)

            policy_path = root / "docs" / "data" / "reference_plate_retention.json"
            policy_path.parent.mkdir(parents=True)
            policy_path.write_text(
                json.dumps(
                    {
                        "budget": {
                            "max_raster_bytes": 8_388_608,
                            "max_long_edge_pixels": 2400,
                        },
                        "policy": {"root": "history/reference"},
                        "exceptions": [],
                    }
                ),
                encoding="utf-8",
            )

            original_root = plates.REPO_ROOT
            original_manifest = plates.RETENTION_MANIFEST
            plates.REPO_ROOT = root
            plates.RETENTION_MANIFEST = policy_path
            try:
                policy_doc, errors = plates.load_retention_policy()
                self.assertEqual(errors, [])
                problems = plates.verify_retention_caps(policy_doc, exceptions=set())
            finally:
                plates.REPO_ROOT = original_root
                plates.RETENTION_MANIFEST = original_manifest

        self.assertTrue(
            any("crafts/sample/crafts.sample.01.jpg" in problem for problem in problems)
        )


if __name__ == "__main__":
    unittest.main()
