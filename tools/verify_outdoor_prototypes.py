#!/usr/bin/env python3
"""Verify inactive outdoor prototype coverage and activation isolation."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFINITION_DIR = ROOT / "scripts/map/definitions/outdoor"
CAPTURE_DIR = ROOT / "docs/reports/images/outdoor"
ACTIVE_DESTINATIONS = ROOT / "content/transitions/active_destinations.json"
START_FLOW = ROOT / "scenes/intro/start_label.gd"

EXPECTED_IDS = {
    "reval_harbor_surroundings",
    "paldiski_coastal_outpost",
    "harju_village",
    "padise_monastery",
    "haapsalu_castle",
    "paide_castle",
    "viljandi_castle",
    "poide_castle",
    "maasilinna_castle",
    "karja_fortress",
    "sacred_grove",
    "pernau",
    "pskov_arrival_battle",
    "rebel_kings_camp",
    "saaremaa",
    "swedish_outpost",
    "swedish_arrival",
}


def definition_text() -> str:
    return "\n".join(path.read_text(encoding="utf-8") for path in sorted(DEFINITION_DIR.glob("*.gd")))


def validate() -> list[str]:
    errors: list[str] = []
    text = definition_text()
    declared = set(re.findall(r'"map_id"\s*:\s*(?:StringName\()?&?"prototype\.([^"%]+)"', text))
    # Generated castle/event IDs are verified by their slug literals.
    for slug in EXPECTED_IDS:
        if slug not in text and f'&"{slug.split("_")[0]}"' not in text:
            errors.append(f"missing outdoor definition evidence: {slug}")

    forbidden = ACTIVE_DESTINATIONS.read_text(encoding="utf-8") + START_FLOW.read_text(encoding="utf-8")
    for prototype_id in EXPECTED_IDS:
        if prototype_id in forbidden:
            errors.append(f"outdoor prototype leaked into active flow: {prototype_id}")

    if 'definition.scope = &"prototype"' not in text:
        errors.append("shared outdoor factory does not force prototype scope")
    if "definition.active = false" not in text:
        errors.append("shared outdoor factory does not force active=false")
    if "definition.transitions" in text and "transitions.is_empty" not in text:
        # No location file should assign gameplay transitions.
        for path in DEFINITION_DIR.glob("*_definitions.gd"):
            if ".transitions" in path.read_text(encoding="utf-8"):
                errors.append(f"outdoor location assigns transitions: {path.name}")

    if CAPTURE_DIR.exists():
        captures = {path.stem for path in CAPTURE_DIR.glob("*.png")}
        missing = EXPECTED_IDS - captures
        if missing:
            errors.append("missing outdoor captures: " + ", ".join(sorted(missing)))
    else:
        errors.append("outdoor capture directory is missing")

    return errors


def main() -> int:
    errors = validate()
    if errors:
        print("outdoor prototype verification failed:")
        for error in errors:
            print(f"  - {error}")
        return 1
    print(f"outdoor prototype verification passed ({len(EXPECTED_IDS)} inactive maps)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
