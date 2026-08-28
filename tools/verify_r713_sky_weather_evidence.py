#!/usr/bin/env python3
"""Fail-closed verifier for the R-738 adjacent-map sky/weather packet.

The capture helper may be planned on a headless machine, but a packet is accepted
only after a real renderer/Metal run writes every plate, records checksums, and
proves an unchanged weather snapshot across the handoff. Missing evidence is a
BLOCKED result, never a pass-by-default.

Usage:
    python3 tools/verify_r713_sky_weather_evidence.py
"""

from __future__ import annotations

import hashlib
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOOLS_PATH = ROOT / "tools"
if str(TOOLS_PATH) not in sys.path:
    sys.path.insert(0, str(TOOLS_PATH))
from verify_slice_surface_captures import capture_stats  # noqa: E402

MANIFEST_PATH = ROOT / "docs" / "reports" / "images" / "r713_sky_weather" / "capture_manifest.json"
REPORT_PATH = ROOT / "docs" / "reports" / "r713_sky_weather_continuity.md"
EXPECTED_CAPTURE_ID = "r713-sky-weather-continuity-v1"
EXPECTED_MAPS = ("lower_town_slice", "monastery_quarter")
EXPECTED_SCENARIOS = ("clear", "overcast", "rain", "storm", "rain_shelter_pair")
EXPECTED_WEATHER_BY_SCENARIO = {
    "clear": "clear",
    "overcast": "overcast",
    "rain": "rain",
    "storm": "storm",
    "rain_shelter_pair": "rain",
}
EXPECTED_TIMES = ("day", "night")
EXPECTED_SHELTERS = ("exterior", "sheltered")
EXPECTED_WIDTH = 1280
EXPECTED_HEIGHT = 720
REQUIRED_REPORT_TERMS = (
    "capture identity",
    "commit",
    "engine",
    "hardware host",
    "expected visual invariants",
    "limitations",
    "day/night",
    "clear",
    "overcast",
    "rain",
    "storm",
    "wind direction",
    "fog/haze",
    "sheltered interior/exterior",
    "no duplicate environment owner",
    "manifest checksums",
    "Metal",
)


def _load_manifest() -> tuple[dict | None, list[str]]:
    if not MANIFEST_PATH.is_file():
        return None, [f"missing manifest: {MANIFEST_PATH.relative_to(ROOT)}"]
    try:
        value = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return None, [f"invalid manifest: {exc}"]
    if not isinstance(value, dict):
        return None, ["manifest root must be an object"]
    return value, []


def _safe_output_path(value: object) -> Path | None:
    if not isinstance(value, str) or not value:
        return None
    relative = value.removeprefix("res://")
    path = (ROOT / relative).resolve()
    try:
        path.relative_to(ROOT)
    except ValueError:
        return None
    return path


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _plate_key(plate: dict) -> tuple[str, str, str, str]:
    return (
        str(plate.get("map_id", "")),
        str(plate.get("scenario_id", "")),
        str(plate.get("time_of_day", "")),
        str(plate.get("shelter", "")),
    )


def _handoff_key(handoff: dict) -> tuple[str, str, str, str, str]:
    return (
        str(handoff.get("source_map", "")),
        str(handoff.get("target_map", "")),
        str(handoff.get("scenario_id", "")),
        str(handoff.get("time_of_day", "")),
        str(handoff.get("shelter", "")),
    )


def _expected_handoff_keys() -> set[tuple[str, str, str, str, str]]:
    return {
        (EXPECTED_MAPS[0], EXPECTED_MAPS[1], scenario, time_of_day, shelter)
        for scenario in EXPECTED_SCENARIOS
        for time_of_day in EXPECTED_TIMES
        for shelter in EXPECTED_SHELTERS
    }


def _expected_keys() -> set[tuple[str, str, str, str]]:
    return {
        (map_id, scenario, time_of_day, shelter)
        for map_id in EXPECTED_MAPS
        for scenario in EXPECTED_SCENARIOS
        for time_of_day in EXPECTED_TIMES
        for shelter in EXPECTED_SHELTERS
    }


def _verify_manifest(manifest: dict) -> list[str]:
    errors: list[str] = []
    if manifest.get("schema_version") != 1:
        errors.append("manifest schema_version must be 1")
    if manifest.get("capture_id") != EXPECTED_CAPTURE_ID:
        errors.append(f"manifest capture_id must be {EXPECTED_CAPTURE_ID}")
    if tuple(manifest.get("maps", [])) != EXPECTED_MAPS:
        errors.append(f"manifest maps must be {EXPECTED_MAPS}")
    viewport = manifest.get("viewport")
    if not isinstance(viewport, dict) or viewport.get("width") != EXPECTED_WIDTH or viewport.get("height") != EXPECTED_HEIGHT:
        errors.append(f"manifest viewport must be {EXPECTED_WIDTH}x{EXPECTED_HEIGHT}")
    if manifest.get("renderer_expected") != "metal":
        errors.append("manifest renderer_expected must be metal")
    if manifest.get("capture_status") != "captured_pending_review":
        errors.append("capture_status is not captured_pending_review; packet remains BLOCKED")

    report_text = ""
    if not REPORT_PATH.is_file():
        errors.append(f"missing continuity report: {REPORT_PATH.relative_to(ROOT)}")
    else:
        try:
            report_text = REPORT_PATH.read_text(encoding="utf-8").lower()
        except OSError as exc:
            errors.append(f"cannot read continuity report: {exc}")
    for term in REQUIRED_REPORT_TERMS:
        if term.lower() not in report_text:
            errors.append(f"report is missing required evidence term: {term}")

    raw_plates = manifest.get("plates")
    if not isinstance(raw_plates, list):
        errors.append("manifest plates must be an array")
        raw_plates = []
    plates: list[dict] = [plate for plate in raw_plates if isinstance(plate, dict)]
    if len(plates) != len(raw_plates):
        errors.append("manifest plates must contain only objects")
    by_key: dict[tuple[str, str, str, str], dict] = {}
    for plate in plates:
        key = _plate_key(plate)
        if key in by_key:
            errors.append(f"duplicate plate identity: {'/'.join(key)}")
        by_key[key] = plate
        if plate.get("status") != "captured":
            errors.append(f"plate is not captured: {'/'.join(key)}")
            continue
        output = _safe_output_path(plate.get("output"))
        if output is None:
            errors.append(f"invalid plate output path: {'/'.join(key)}")
            continue
        if not output.is_file():
            errors.append(f"missing plate: {output.relative_to(ROOT)}")
            continue
        if plate.get("width") != EXPECTED_WIDTH or plate.get("height") != EXPECTED_HEIGHT:
            errors.append(f"plate metadata dimensions are not {EXPECTED_WIDTH}x{EXPECTED_HEIGHT}: {'/'.join(key)}")
        try:
            from verify_slice_surface_captures import capture_stats

            stats = capture_stats(output)
        except (OSError, ValueError) as exc:
            errors.append(f"invalid PNG {output.relative_to(ROOT)}: {exc}")
            continue
        if stats.width != EXPECTED_WIDTH or stats.height != EXPECTED_HEIGHT:
            errors.append(f"PNG dimensions are not {EXPECTED_WIDTH}x{EXPECTED_HEIGHT}: {output.relative_to(ROOT)}")
        if stats.luminance_stdev < 1.0:
            errors.append(f"PNG is blank or flat: {output.relative_to(ROOT)}")
        expected_hash = plate.get("sha256")
        if not isinstance(expected_hash, str) or len(expected_hash) != 64:
            errors.append(f"plate checksum must be a 64-character SHA-256: {'/'.join(key)}")
        elif _sha256(output) != expected_hash:
            errors.append(f"manifest checksum mismatch: {output.relative_to(ROOT)}")

    missing = sorted(_expected_keys() - set(by_key))
    unexpected = sorted(set(by_key) - _expected_keys())
    if missing:
        errors.append("missing plate identities: " + ", ".join("/".join(key) for key in missing))
    if unexpected:
        errors.append("unexpected plate identities: " + ", ".join("/".join(key) for key in unexpected))

    handoff = manifest.get("physical_handoff")
    if not isinstance(handoff, dict):
        errors.append("physical_handoff must be an object")
    else:
        if handoff.get("source_map") != EXPECTED_MAPS[0] or handoff.get("target_map") != EXPECTED_MAPS[1]:
            errors.append("physical_handoff must cover the representative two-map traversal")
        if handoff.get("scene_swap") is not False:
            errors.append("physical_handoff.scene_swap must be false")
        if handoff.get("environment_owner") != "SessionState":
            errors.append("physical_handoff.environment_owner must be SessionState")
        if handoff.get("expected_active_environment_owners") != 1:
            errors.append("physical_handoff must expect exactly one active environment owner")
        if handoff.get("status") != "captured":
            errors.append("physical_handoff status is not captured")

    raw_handoffs = manifest.get("handoffs")
    handoffs_by_key: dict[tuple[str, str, str, str, str], dict] = {}
    if not isinstance(raw_handoffs, list) or not raw_handoffs:
        errors.append("manifest must contain at least one captured handoff")
    else:
        expected_handoff_keys = _expected_handoff_keys()
        if len(raw_handoffs) != len(expected_handoff_keys):
            errors.append(
                "manifest handoff count must be "
                f"{len(expected_handoff_keys)}"
            )
        for handoff_entry in raw_handoffs:
            if not isinstance(handoff_entry, dict):
                errors.append("handoffs must contain only objects")
                continue
            key = _handoff_key(handoff_entry)
            if key in handoffs_by_key:
                errors.append(f"duplicate handoff identity: {'/'.join(key)}")
            handoffs_by_key[key] = handoff_entry
            if handoff_entry.get("status") != "captured":
                errors.append("handoff entry is not captured")
            if handoff_entry.get("scene_swap") is not False:
                errors.append("handoff entry must not use a scene swap")
            if (
                handoff_entry.get("environment_owner_count_source") != 1
                or handoff_entry.get("environment_owner_count_target") != 1
            ):
                errors.append("handoff entry must record one environment owner on both sides")
            if handoff_entry.get("state_hash_source") != handoff_entry.get("state_hash_target"):
                errors.append("handoff entry weather state hashes differ")
            state_hash = handoff_entry.get("state_hash_source")
            if not isinstance(state_hash, str) or len(state_hash) != 64:
                errors.append(f"handoff state hash must be a 64-character SHA-256: {'/'.join(key)}")
            expected_weather = EXPECTED_WEATHER_BY_SCENARIO.get(key[2])
            if expected_weather is None:
                errors.append(f"unexpected handoff scenario: {'/'.join(key)}")
            elif handoff_entry.get("weather") != expected_weather:
                errors.append(
                    f"handoff weather does not match scenario: {'/'.join(key)}"
                )
            for map_id in key[:2]:
                plate_key = (map_id, key[2], key[3], key[4])
                if plate_key not in by_key:
                    errors.append(
                        "handoff has no matching captured plate: "
                        + "/".join(plate_key)
                    )
        missing_handoffs = sorted(expected_handoff_keys - set(handoffs_by_key))
        unexpected_handoffs = sorted(set(handoffs_by_key) - expected_handoff_keys)
        if missing_handoffs:
            errors.append(
                "missing handoff identities: "
                + ", ".join("/".join(key) for key in missing_handoffs)
            )
        if unexpected_handoffs:
            errors.append(
                "unexpected handoff identities: "
                + ", ".join("/".join(key) for key in unexpected_handoffs)
            )

    if isinstance(handoff, dict):
        physical_hash = handoff.get("state_hash")
        if not isinstance(physical_hash, str) or len(physical_hash) != 64:
            errors.append("physical_handoff state_hash must be a 64-character SHA-256")
        elif not any(
            entry.get("state_hash_source") == physical_hash
            for entry in handoffs_by_key.values()
        ):
            errors.append("physical_handoff state_hash does not match a captured handoff")
    return errors


def validate() -> list[str]:
    manifest, errors = _load_manifest()
    if manifest is not None:
        errors.extend(_verify_manifest(manifest))
    return errors


def main() -> int:
    # The imports above are deliberately local to the packet check so that a
    # missing image helper is reported as an evidence error, not at module load.
    tools = str(ROOT / "tools")
    if tools not in sys.path:
        sys.path.insert(0, tools)
    errors = validate()
    if errors:
        print("R-738 sky/weather continuity verification BLOCKED:")
        for error in errors:
            print(f"  - {error}")
        return 1
    print("R713_SKY_WEATHER_CONTINUITY_PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
