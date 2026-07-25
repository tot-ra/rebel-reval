#!/usr/bin/env python3
"""Build or verify the P3-015 published slice save fixture."""

from __future__ import annotations

import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIXTURE_PATH = ROOT / "content/saves/released/save.slice_prologue_complete.json"
BASE_FIXTURE_PATH = ROOT / "content/saves/released/save.demo_fresh_start.json"


def build_slice_release_fixture() -> dict:
    base = json.loads(BASE_FIXTURE_PATH.read_text(encoding="utf-8"))
    envelope = copy.deepcopy(base)
    game_state = envelope["game_state"]
    game_state["flags"] = {
        "flag.prologue_maker_mark_incident": True,
        "flag.forge_ledger_preserved": True,
        "flag.mart_missing": True,
    }
    game_state["relationships"] = {
        "rel.henning_trust": 1,
        "rel.mart_trust": 0,
    }
    game_state["quest_states"] = {
        "quest.makers_mark": "ledger_committed",
    }
    game_state["forged_records"] = [
        {
            "record_id": "forged.watch_buckle_repair.honest_work",
            "commission_id": "commission.watch_buckle_repair",
            "item_id": "item.watch_buckle",
            "modification_id": "honest_work",
        }
    ]
    envelope["saved_at_unix"] = 1753459200
    return envelope


def write_fixture(path: Path = FIXTURE_PATH) -> dict:
    payload = build_slice_release_fixture()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent="\t") + "\n", encoding="utf-8")
    return payload


def main() -> int:
    payload = write_fixture()
    print(f"Wrote {FIXTURE_PATH}")
    print(
        "  quest.makers_mark:",
        payload["game_state"]["quest_states"]["quest.makers_mark"],
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
