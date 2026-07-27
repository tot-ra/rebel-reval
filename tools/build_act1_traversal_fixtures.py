#!/usr/bin/env python3
"""Build or verify Act 1 boundary save fixtures for P4-011."""

from __future__ import annotations

import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE_FIXTURE_PATH = ROOT / "content/saves/released/save.demo_fresh_start.json"
ACT1_DIR = ROOT / "content/saves/act1"
MANIFEST_PATH = ROOT / "content/saves/act1_fixtures_manifest.json"

BOUNDARIES = ("seal", "break", "open")

BOUNDARY_FLAGS = {
    "seal": {
        "flag.act_boundary.viru_seal": True,
        "flag.act_climax_viru_seal": True,
    },
    "break": {
        "flag.act_boundary.viru_break": True,
        "flag.act_climax_viru_break": True,
    },
    "open": {
        "flag.act_boundary.viru_open": True,
        "flag.act_climax_viru_open": True,
    },
}

TERMINAL_QUEST_STATES = {
    "seal": "aftermath_seal",
    "break": "aftermath_break",
    "open": "aftermath_open",
}


def build_act1_transition(boundary: str) -> dict:
    return {
        "version": 1,
        "recorded_at_phase": "phase.act1_climax",
        "act_boundary": boundary,
        "characters": {
            "mart": "respectful",
            "aita": "at_brewery",
            "kaja": "merchant_neutral",
            "henning": "trusting_officer",
            "jurgen": "marginal_trader",
            "ellen": "unmet",
        },
        "forge": {
            "ledger": "preserved",
            "conviction": "duty",
            "technique": "iron",
            "suspicion": 0,
            "solidarity": 0,
            "scarcity": 0,
            "bell_and_chain": boundary,
            "bread_and_iron": "",
        },
        "districts": {
            "district.lower_town": {
                "price_tier": "normal",
                "patrol_speed_scale": 1.0,
            },
            "district.north_merchant": {
                "price_tier": "normal",
                "patrol_speed_scale": 1.0,
            },
        },
    }


def build_fixture(boundary: str) -> dict:
    base = json.loads(BASE_FIXTURE_PATH.read_text(encoding="utf-8"))
    envelope = copy.deepcopy(base)
    game_state = envelope["game_state"]
    game_state["phase"] = "phase.act1_climax"
    game_state["player"]["location_id"] = "reval_east"
    game_state["player"]["spawn_id"] = "street_start"
    game_state.setdefault("flags", {}).update(
        {
            "flag.forge_ledger_preserved": True,
            "flag.act_transition.act1_recorded": True,
            **BOUNDARY_FLAGS[boundary],
        }
    )
    game_state.setdefault("quest_states", {})["quest.st_georges_night"] = TERMINAL_QUEST_STATES[
        boundary
    ]
    game_state["act1_transition"] = build_act1_transition(boundary)
    envelope["saved_at_unix"] = 1754064000
    return envelope


def write_fixtures() -> list[dict]:
    ACT1_DIR.mkdir(parents=True, exist_ok=True)
    fixtures: list[dict] = []
    for boundary in BOUNDARIES:
        filename = f"save.act1_boundary_{boundary}.json"
        path = ACT1_DIR / filename
        payload = build_fixture(boundary)
        path.write_text(json.dumps(payload, indent="\t") + "\n", encoding="utf-8")
        fixtures.append(
            {
                "id": f"save.act1_boundary_{boundary}",
                "path": f"act1/{filename}",
                "description": (
                    f"Act 1 transition fixture after St. George's Night {boundary} family."
                ),
                "act_boundary": boundary,
            }
        )
    manifest = {"fixtures": fixtures}
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return fixtures


def main() -> int:
    fixtures = write_fixtures()
    print(f"Wrote {len(fixtures)} Act 1 boundary fixtures under {ACT1_DIR}")
    for row in fixtures:
        print(f"  - {row['path']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
