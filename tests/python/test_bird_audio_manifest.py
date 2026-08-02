#!/usr/bin/env python3
"""Tests for bird audio fetch helpers and manifest verification."""

from __future__ import annotations

import contextlib
import csv
import io
import json
import sys
import tempfile
import unittest
from unittest import mock
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
AUDIO_TOOLS = ROOT / "tools" / "audio"
TOOLS = ROOT / "tools"
for path in (str(AUDIO_TOOLS), str(TOOLS)):
    if path not in sys.path:
        sys.path.insert(0, path)

import fetch_bird_songs as fetch  # noqa: E402
import verify_bird_audio_manifest as verify  # noqa: E402


SAMPLE_RECORDING_HTML = """
<tr><td>Country</td><td>Estonia</td></tr>
<tr><td>Length</td><td>42.0 (s)</td></tr>
<p><a href='https://creativecommons.org/licenses/by/4.0/'>license</a></p>
<li id='rating-12345-1' class='selected'><span>A</span></li>
contributor/TEST'><span itemprop='name'>Test Recordist</span>
"""


class FetchBirdSongsTest(unittest.TestCase):
    def test_is_commercial_license_accepts_by_and_rejects_nc(self) -> None:
        self.assertTrue(fetch.is_commercial_license("https://creativecommons.org/licenses/by/4.0/"))
        self.assertTrue(fetch.is_commercial_license("https://creativecommons.org/publicdomain/zero/1.0/"))
        self.assertTrue(fetch.is_commercial_license("https://creativecommons.org/licenses/by-sa/3.0/"))
        self.assertFalse(fetch.is_commercial_license("https://creativecommons.org/licenses/by-nc-sa/4.0/"))
        self.assertFalse(fetch.is_commercial_license("https://creativecommons.org/licenses/by-nc-nd/2.5/"))

    def test_parse_len_seconds_handles_mm_ss_and_scrape_format(self) -> None:
        self.assertEqual(fetch.parse_len_seconds("1:05"), 65)
        self.assertEqual(fetch.parse_len_seconds("42.0 (s)"), 42)
        self.assertEqual(fetch.parse_len_seconds("18"), 18)
        self.assertEqual(fetch.parse_len_seconds(""), -1)

    def test_parse_recording_page_extracts_metadata(self) -> None:
        rec = fetch.parse_recording_page(SAMPLE_RECORDING_HTML, "12345")
        self.assertEqual(rec["id"], "12345")
        self.assertEqual(rec["cnt"], "Estonia")
        self.assertEqual(rec["length"], "42")
        self.assertEqual(rec["q"], "A")
        self.assertEqual(rec["rec"], "Test Recordist")
        self.assertIn("/by/4.0/", rec["lic"])

    def test_build_explore_queries_prefers_country_before_global(self) -> None:
        queries = fetch.build_explore_queries(
            "Fringilla coelebs",
            preferred_countries=["Estonia"],
            len_range="15-90",
            global_fallback=True,
        )
        self.assertTrue(queries[0].startswith('sp:"Fringilla coelebs" cnt:"Estonia"'))
        self.assertTrue(any('cnt:"Estonia"' not in q for q in queries))
        self.assertTrue(all(" q:" not in q for q in queries))

    def test_recording_matches_filters_rejects_nc(self) -> None:
        reason = fetch.recording_matches_filters(
            {"lic": "https://creativecommons.org/licenses/by-nc-sa/4.0/", "q": "A", "length": "30", "cnt": "Estonia"},
            min_q="A",
            lo=15,
            hi=90,
            preferred_countries={"Estonia"},
            global_fallback=True,
        )
        self.assertEqual(reason, "license")

    def test_compatibility_facade_reexports_toolchain_helpers(self) -> None:
        import bird_audio_catalog as catalog
        import bird_audio_curated as curated
        import xeno_canto

        expected_exports = {
            "API", "BALTIC_COUNTRIES", "COMMERCIAL_LICENSE_TAGS", "LICENSE_RE",
            "QUALITY_GRADES", "QUALITY_RE", "RECORDING_ID_RE", "RECORDIST_RE",
            "REPO_ROOT", "SONGBIRDS", "SPECIES", "TABLE_ROW_RE", "USER_AGENT",
            "XC_BASE", "build_explore_queries", "collect_recordings", "country_rank",
            "download", "download_curated", "explore_recording_ids",
            "fetch_freesound_preview_url", "fetch_html", "is_commercial_license",
            "iterate_species_recording_ids", "list_species_pages",
            "list_species_recording_ids", "load_curated", "main", "manifest_row",
            "parse_len_seconds", "parse_recording_page", "query", "rank",
            "recording_matches_filters", "scrape_explore_recordings",
            "scrape_species_recordings", "species_slug", "trim_mp3_to_window",
        }
        self.assertTrue(all(hasattr(fetch, name) for name in expected_exports))
        self.assertIs(fetch.SPECIES, catalog.SPECIES)
        self.assertIs(fetch.parse_recording_page, xeno_canto.parse_recording_page)
        self.assertIs(fetch.download_curated, curated.download_curated)
        self.assertEqual(fetch.REPO_ROOT, curated.REPO_ROOT)

    def test_download_curated_dry_run_returns_complete_manifest_rows(self) -> None:
        curated_path = AUDIO_TOOLS / "curated_bird_recordings.json"
        with tempfile.TemporaryDirectory() as temp_dir, contextlib.redirect_stdout(io.StringIO()):
            rows = fetch.download_curated(
                curated_path,
                Path(temp_dir) / "birds",
                dry_run=True,
            )

        self.assertEqual([row["bird_id"] for row in rows], list(fetch.SPECIES))
        self.assertEqual(
            next(row for row in rows if row["bird_id"] == "great_cormorant")["file"].split("/")[-1],
            "great_cormorant_IN367008.wav",
        )

    def test_main_rejects_missing_api_key_without_creating_output(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            output_dir = Path(temp_dir) / "birds"
            with (
                mock.patch.object(sys, "argv", ["fetch_bird_songs.py", "--out", str(output_dir)]),
                contextlib.redirect_stderr(io.StringIO()),
            ):
                self.assertEqual(fetch.main(), 2)
            self.assertFalse(output_dir.exists())


class VerifyBirdAudioManifestTest(unittest.TestCase):
    def test_verify_reports_missing_species(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            birds_dir = Path(temp_dir)
            bird_dir = birds_dir / "house_sparrow"
            bird_dir.mkdir()
            clip = bird_dir / "house_sparrow_XC1.mp3"
            clip.write_bytes(b"fake")

            manifest = birds_dir / "manifest.csv"
            with open(manifest, "w", newline="", encoding="utf-8") as fh:
                writer = csv.DictWriter(
                    fh,
                    fieldnames=[
                        "bird_id", "scientific", "xc_id", "recordist", "license",
                        "page", "length", "quality", "country", "file",
                    ],
                )
                writer.writeheader()
                writer.writerow(
                    {
                        "bird_id": "house_sparrow",
                        "scientific": "Passer domesticus",
                        "xc_id": "1",
                        "recordist": "Test",
                        "license": "https://creativecommons.org/licenses/by/4.0/",
                        "page": "https://xeno-canto.org/1",
                        "length": "30",
                        "quality": "A",
                        "country": "Estonia",
                        "file": str(clip),
                    }
                )

            errors = verify.verify(birds_dir)
            self.assertTrue(any("mallard: no manifest row" in err for err in errors))

    def test_verify_passes_for_valid_fixture(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            birds_dir = Path(temp_dir)
            clip = birds_dir / "shared_clip.mp3"
            clip.write_bytes(b"fake")
            rows = []
            for bird_id in fetch.SPECIES:
                rows.append(
                    {
                        "bird_id": bird_id,
                        "scientific": fetch.SPECIES[bird_id],
                        "xc_id": "1",
                        "recordist": "Test",
                        "license": "https://creativecommons.org/licenses/by/4.0/",
                        "page": "https://xeno-canto.org/1",
                        "length": "30",
                        "quality": "A",
                        "country": "Estonia",
                        "file": str(clip),
                    }
                )

            manifest = birds_dir / "manifest.csv"
            with open(manifest, "w", newline="", encoding="utf-8") as fh:
                writer = csv.DictWriter(fh, fieldnames=rows[0].keys())
                writer.writeheader()
                writer.writerows(rows)

            self.assertEqual(verify.verify(birds_dir), [])

    def test_verify_rejects_nc_license(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            birds_dir = Path(temp_dir)
            clip = birds_dir / "clip.mp3"
            clip.write_bytes(b"x")
            manifest = birds_dir / "manifest.csv"
            with open(manifest, "w", newline="", encoding="utf-8") as fh:
                writer = csv.DictWriter(
                    fh,
                    fieldnames=[
                        "bird_id", "scientific", "xc_id", "recordist", "license",
                        "page", "length", "quality", "country", "file",
                    ],
                )
                writer.writeheader()
                for bird_id in fetch.SPECIES:
                    writer.writerow(
                        {
                            "bird_id": bird_id,
                            "scientific": fetch.SPECIES[bird_id],
                            "xc_id": "9",
                            "recordist": "Test",
                            "license": "https://creativecommons.org/licenses/by-nc-sa/4.0/",
                            "page": "https://xeno-canto.org/9",
                            "length": "30",
                            "quality": "A",
                            "country": "Estonia",
                            "file": str(clip),
                        }
                    )

            errors = verify.verify(birds_dir)
            self.assertTrue(errors)
            self.assertIn("non-commercial", errors[0])


if __name__ == "__main__":
    unittest.main()
