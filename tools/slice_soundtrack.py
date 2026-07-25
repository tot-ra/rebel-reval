"""Slice soundtrack budget helpers for P2-014."""

from __future__ import annotations

import csv
import json
import re
import subprocess
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

GDSCRIPT_TRACK_ARRAY_RE = re.compile(
    r"const\s+(?P<name>MENU_TRACK|FORGE_TRACKS|TOWN_TRACKS)\b(?P<body>.*?)(?=const\s|\nfunc\s|\Z)",
    re.DOTALL,
)
GDSCRIPT_STRING_RE = re.compile(r'"((?:\\.|[^"\\])*)"')


@dataclass
class TrackReport:
    path: str
    sources_id: str
    duration_seconds: float
    rights_status: str
    license: str
    owner: str
    themes: list[str] = field(default_factory=list)
    stream_modes: list[str] = field(default_factory=list)


@dataclass
class SliceSoundtrackReport:
    duration_budget_seconds: int
    budgeted_duration_seconds: float
    total_unique_duration_seconds: float
    tracks: list[TrackReport] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)

    @property
    def within_budget(self) -> bool:
        return (
            self.budgeted_duration_seconds <= self.duration_budget_seconds
            and not self.errors
        )

    def unique_track_count(self) -> int:
        return len({track.path for track in self.tracks})


def probe_duration_seconds(path: Path) -> float:
    result = subprocess.run(
        [
            "ffprobe",
            "-v",
            "error",
            "-show_entries",
            "format=duration",
            "-of",
            "default=noprint_wrappers=1:nokey=1",
            str(path),
        ],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0 or not result.stdout.strip():
        raise RuntimeError(f"ffprobe failed for {path}: {result.stderr.strip()}")
    return float(result.stdout.strip())


def load_sources_index(sources_csv: Path) -> dict[str, dict[str, str]]:
    index: dict[str, dict[str, str]] = {}
    with sources_csv.open(encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            asset_id = row.get("asset_id", "").strip()
            asset_path = row.get("path", "").strip()
            if asset_id:
                index[asset_id] = row
            if asset_path:
                index[asset_path] = row
    return index


def _theme_stream_label(theme: dict[str, Any]) -> str:
    mode = str(theme.get("stream_mode", "unknown"))
    shuffle = bool(theme.get("shuffle", False))
    if mode == "loop":
        return "loop"
    if mode == "randomizer":
        return "randomizer(shuffle)" if shuffle else "randomizer"
    if mode == "playlist":
        return "playlist(shuffle)" if shuffle else "playlist"
    return mode


def build_report(root: Path, manifest_path: Path | None = None) -> SliceSoundtrackReport:
    manifest_file = manifest_path or root / "docs/data/slice_soundtrack_manifest.json"
    manifest = json.loads(manifest_file.read_text(encoding="utf-8"))
    sources_index = load_sources_index(root / "assets/SOURCES.csv")
    report = SliceSoundtrackReport(
        duration_budget_seconds=int(manifest.get("duration_budget_seconds", 720)),
        budgeted_duration_seconds=0.0,
        total_unique_duration_seconds=0.0,
    )

    track_map: dict[str, TrackReport] = {}
    themes: dict[str, Any] = manifest.get("themes", {})
    if not isinstance(themes, dict):
        report.errors.append("manifest themes must be an object")
        return report

    for theme_id, theme in themes.items():
        if not isinstance(theme, dict):
            report.errors.append(f"theme {theme_id} must be an object")
            continue
        stream_label = _theme_stream_label(theme)
        counts_toward_budget = bool(theme.get("counts_toward_budget", True))
        for entry in theme.get("tracks", []):
            if not isinstance(entry, dict):
                report.errors.append(f"theme {theme_id} has a non-object track entry")
                continue
            rel_path = str(entry.get("path", "")).strip()
            sources_id = str(entry.get("sources_id", "")).strip()
            if not rel_path:
                report.errors.append(f"theme {theme_id} has a track without path")
                continue
            abs_path = root / rel_path
            if not abs_path.is_file():
                report.errors.append(f"missing track file: {rel_path}")
                continue

            if rel_path not in track_map:
                sources_row = sources_index.get(sources_id) or sources_index.get(rel_path)
                if sources_row is None:
                    report.errors.append(
                        f"missing SOURCES.csv row for {rel_path} ({sources_id})"
                    )
                    rights_status = "missing"
                    license_name = ""
                    owner = ""
                else:
                    rights_status = sources_row.get("approval", "").strip()
                    license_name = sources_row.get("license", "").strip()
                    owner = sources_row.get("creator_or_tool", "").strip()
                    if not rights_status.startswith("approved"):
                        report.errors.append(
                            f"track not approved in SOURCES.csv: {rel_path}"
                        )
                try:
                    duration = probe_duration_seconds(abs_path)
                except RuntimeError as error:
                    report.errors.append(str(error))
                    duration = 0.0
                track_map[rel_path] = TrackReport(
                    path=rel_path,
                    sources_id=sources_id,
                    duration_seconds=duration,
                    rights_status=rights_status,
                    license=license_name,
                    owner=owner,
                )

            track = track_map[rel_path]
            if theme_id not in track.themes:
                track.themes.append(theme_id)
            if stream_label not in track.stream_modes:
                track.stream_modes.append(stream_label)
            if counts_toward_budget:
                report.budgeted_duration_seconds += track.duration_seconds

    report.tracks = sorted(track_map.values(), key=lambda item: item.path)
    report.total_unique_duration_seconds = sum(
        track.duration_seconds for track in report.tracks
    )
    return report


def _strings_from_gdscript_array(source_text: str, const_name: str) -> list[str]:
    match = GDSCRIPT_TRACK_ARRAY_RE.search(source_text)
    if match is None or match.group("name") != const_name:
        for candidate in GDSCRIPT_TRACK_ARRAY_RE.finditer(source_text):
            if candidate.group("name") == const_name:
                match = candidate
                break
    if match is None or match.group("name") != const_name:
        return []
    return [
        value.replace("\\'", "'")
        for value in GDSCRIPT_STRING_RE.findall(match.group("body"))
    ]


def music_director_slice_track_paths(root: Path) -> dict[str, list[str]]:
    script_path = root / "scripts/global/music_director.gd"
    source = script_path.read_text(encoding="utf-8")
    menu_track = _strings_from_gdscript_array(source, "MENU_TRACK")
    forge_tracks = _strings_from_gdscript_array(source, "FORGE_TRACKS")
    town_tracks = _strings_from_gdscript_array(source, "TOWN_TRACKS")
    return {
        "menu": [path.removeprefix("res://") for path in menu_track],
        "forge": [path.removeprefix("res://") for path in forge_tracks],
        "town": [path.removeprefix("res://") for path in town_tracks],
    }


def verify_music_director_matches_manifest(
    root: Path,
    manifest_path: Path | None = None,
) -> list[str]:
    manifest_file = manifest_path or root / "docs/data/slice_soundtrack_manifest.json"
    manifest = json.loads(manifest_file.read_text(encoding="utf-8"))
    wired = music_director_slice_track_paths(root)
    errors: list[str] = []
    themes: dict[str, Any] = manifest.get("themes", {})
    for theme_id in manifest.get("release_theme_ids", []):
        theme = themes.get(theme_id)
        if not isinstance(theme, dict):
            errors.append(f"manifest missing release theme: {theme_id}")
            continue
        expected = [str(entry["path"]) for entry in theme.get("tracks", []) if "path" in entry]
        actual = wired.get(theme_id, [])
        if actual != expected:
            errors.append(
                f"MusicDirector {theme_id} tracks {actual!r} do not match manifest {expected!r}"
            )
    return errors


def format_report(report: SliceSoundtrackReport) -> str:
    lines = [
        "Slice soundtrack report (P2-014)",
        f"Budget (gameplay): {report.duration_budget_seconds}s ({report.duration_budget_seconds / 60:.1f} min)",
        f"Budgeted unique duration: {report.budgeted_duration_seconds:.1f}s ({report.budgeted_duration_seconds / 60:.2f} min)",
        f"All approved unique duration: {report.total_unique_duration_seconds:.1f}s ({report.total_unique_duration_seconds / 60:.2f} min)",
        f"Unique tracks: {report.unique_track_count()}",
        f"Within budget: {'yes' if report.within_budget else 'no'}",
        "",
        "Tracks:",
    ]
    for track in report.tracks:
        theme_list = ", ".join(track.themes)
        mode_list = ", ".join(track.stream_modes)
        lines.append(
            f"  {track.duration_seconds:6.1f}s  {track.path}  [{theme_list}; {mode_list}]"
        )
        lines.append(
            f"           rights={track.rights_status or 'missing'}  license={track.license or 'n/a'}"
        )
    if report.errors:
        lines.extend(["", "Errors:"])
        lines.extend(f"  - {error}" for error in report.errors)
    return "\n".join(lines)
