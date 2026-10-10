#!/usr/bin/env python3
"""P0-180 / R-1576: every runtime music/ track is hard-coded, directory-scanned, or battle library.

R-1576 restored the numbered takes from archive/music/ into the scanned theme
folders, so takes are allowed as long as a MusicDirector playlist reaches them.
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MUSIC = ROOT / "music"
DIRECTOR = ROOT / "scripts" / "global" / "music_director.gd"
MANIFEST = ROOT / "docs" / "data" / "slice_soundtrack_manifest.json"

HARD_CODED = {
    "music/menu/Menu.mp3",
    "music/forge/Fireside Tale.mp3",
    "music/revel_east/Apothecary (8).mp3",
    "music/revel_east/Apothecary.mp3",
    # Prologue cutscene underscore, loaded by the cutscene player, not MusicDirector.
    "music/intro/The Weight of Centuries.mp3",
}
DIR_CONST_RE = re.compile(
    r'const THEME_(?:DAY|NIGHT)_DIRS: Dictionary = \{(?P<body>.*?)\}',
    re.DOTALL,
)
RES_DIR_RE = re.compile(r'"res://(music/[^"]+/)"')


def _scanned_dirs(source: str) -> set[Path]:
    dirs: set[Path] = set()
    for match in DIR_CONST_RE.finditer(source):
        for rel in RES_DIR_RE.findall(match.group("body")):
            dirs.add(ROOT / rel.rstrip("/"))
    return dirs


class MusicTakeInventoryTest(unittest.TestCase):
    def test_runtime_mp3s_are_hardcoded_scanned_or_retained_battle(self) -> None:
        source = DIRECTOR.read_text(encoding="utf-8")
        scanned = _scanned_dirs(source)
        self.assertTrue(scanned, "MusicDirector theme directories should parse")
        battle = MUSIC / "battle"
        leftover: list[str] = []
        for path in sorted(MUSIC.rglob("*.mp3")):
            rel = path.relative_to(ROOT).as_posix()
            if rel in HARD_CODED:
                continue
            if path.parent == battle:
                continue
            if path.parent in scanned:
                continue
            leftover.append(rel)
        self.assertEqual(leftover, [], msg="unreferenced runtime tracks:\n" + "\n".join(leftover))

    def test_slice_manifest_names_the_battle_retained_library(self) -> None:
        payload = MANIFEST.read_text(encoding="utf-8")
        self.assertIn("music/battle", payload)
        self.assertIn("retained_libraries", payload)


if __name__ == "__main__":
    unittest.main()
