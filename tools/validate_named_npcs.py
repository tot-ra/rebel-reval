#!/usr/bin/env python3
"""Validate the named-NPC registry content/npcs/named_npcs.json (task R-1562).

Rules come from ADR 0044 and docs/SYSTEMS/NAMED_NPCS.md. The faction set is read
from the GDScript ledger constants (FactionLedger.ACTIVE_FACTIONS plus
FactionCandidateSeats.CANDIDATE_FACTIONS) so Python and the runtime cannot drift.
Anchors are the `points_of_interest` and `gates` ids of the Reval city plan.

Usage: python3 tools/validate_named_npcs.py [registry.json]
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "content" / "npcs" / "named_npcs.json"
PLAN = ROOT / "content" / "world" / "reval_city" / "plan.json"
CENSUS = ROOT / "content" / "world" / "reval_city" / "citizens.json"
LEDGER = ROOT / "scripts" / "faction" / "faction_ledger.gd"
CANDIDATES = ROOT / "scripts" / "state" / "faction_candidate_seats.gd"
VARIANTS_DIR = "res://assets/characters/variants/%s.tscn"

ID_RE = re.compile(r"^char\.[a-z0-9_]+$")
CENSUS_RE = re.compile(r"^cit\.[a-z0-9_.]+$")
REQUIRED = (
    "id", "display_name", "title", "faction", "source_sheet", "portrait", "model_scene",
    "census_id", "census_mode", "home_anchor", "schedule", "body", "act_gate", "wave", "marker",
)
CENSUS_MODES = {"replaces", "extra"}
MARKERS = {"available", "none"}
WAVES = {"A", "B", "C"}
HOME = "home"


def _const_list(path: Path, const_name: str) -> list[str]:
    """Names inside `const <const_name>: Array[StringName] = [...]`, resolved via `const X := &"x"`."""
    text = path.read_text(encoding="utf-8")
    values = dict(re.findall(r'^const ([A-Z_]+) := &"([a-z_]+)"', text, re.M))
    block = re.search(r"const %s[^=]*= \[(.*?)\]" % const_name, text, re.S)
    if block is None:
        raise SystemExit(f"cannot find {const_name} in {path}")
    names = re.findall(r"[A-Z_]+", block.group(1))
    return [values[n] for n in names if n in values]


def known_factions() -> set[str]:
    ids = _const_list(LEDGER, "ACTIVE_FACTIONS") + _const_list(CANDIDATES, "CANDIDATE_FACTIONS")
    return {"faction." + i for i in ids}


def known_anchors(plan_path: Path = PLAN) -> set[str]:
    plan = json.loads(plan_path.read_text(encoding="utf-8"))
    return {p["id"] for p in plan.get("points_of_interest", [])} | {g["id"] for g in plan.get("gates", [])}


def census_index(census_path: Path = CENSUS) -> tuple[set[str], set[str]]:
    """(resident ids, char.<slug> ids taken by census deep cards)."""
    census = json.loads(census_path.read_text(encoding="utf-8"))
    ids = {r["id"] for r in census["residents"]}
    card_slugs = {"char." + Path(r["card"]).stem for r in census["residents"] if r.get("card")}
    return ids, card_slugs


def _res_exists(res_path: str) -> bool:
    return res_path.startswith("res://") and (ROOT / res_path[len("res://"):]).is_file()


def _check_schedule(prefix: str, schedule: object, anchors: set[str], errors: list[str]) -> None:
    if not isinstance(schedule, list) or not schedule:
        errors.append(f"{prefix}: schedule must be a non-empty list")
        return
    t = 0.0
    for i, post in enumerate(schedule):
        if not isinstance(post, dict) or set(post) != {"from", "to", "anchor"}:
            errors.append(f"{prefix}: schedule[{i}] needs exactly from, to, anchor")
            return
        start, end, anchor = post["from"], post["to"], post["anchor"]
        if not all(isinstance(h, (int, float)) for h in (start, end)) or not 0 <= start < end <= 24:
            errors.append(f"{prefix}: schedule[{i}] hours must satisfy 0 <= from < to <= 24")
            return
        if abs(start - t) > 1e-6:
            errors.append(f"{prefix}: schedule[{i}] starts at {start}, expected {t} (gap or overlap)")
        if anchor != HOME and anchor not in anchors:
            errors.append(f"{prefix}: schedule[{i}] anchor {anchor!r} is not a city anchor")
        t = end
    if abs(t - 24.0) > 1e-6:
        errors.append(f"{prefix}: schedule ends at {t}, must cover the day to 24")


def _check_body(prefix: str, body: object, errors: list[str]) -> None:
    if not isinstance(body, dict):
        errors.append(f"{prefix}: body must be an object")
        return
    for key in ("variant", "height_scale", "head_scale", "cloth", "under"):
        if key not in body:
            errors.append(f"{prefix}: body.{key} missing")
            return
    if not _res_exists(VARIANTS_DIR % body["variant"]):
        errors.append(f"{prefix}: body.variant {body['variant']!r} has no census blank scene")
    for key in ("cloth", "under"):
        colour = body[key]
        if not (isinstance(colour, list) and len(colour) == 3 and all(0 <= c <= 1 for c in colour)):
            errors.append(f"{prefix}: body.{key} must be three 0..1 numbers")
    for key in ("height_scale", "head_scale"):
        if not 0.8 <= float(body[key]) <= 1.2:
            errors.append(f"{prefix}: body.{key} out of 0.8..1.2")


def validate(data: object, *, factions: set[str], anchors: set[str], census_ids: set[str],
             card_slugs: set[str]) -> list[str]:
    errors: list[str] = []
    if not isinstance(data, dict) or data.get("schema_version") != 1 or not isinstance(data.get("npcs"), list):
        return ["registry must be {schema_version: 1, npcs: [...]}"]
    seen: set[str] = set()
    linked: dict[str, str] = {}
    for n, npc in enumerate(data["npcs"]):
        prefix = f"npcs[{n}]"
        if not isinstance(npc, dict):
            errors.append(f"{prefix}: entry must be an object")
            continue
        missing = [k for k in REQUIRED if k not in npc]
        if missing:
            errors.append(f"{prefix}: missing {', '.join(missing)}")
            continue
        npc_id = npc["id"]
        prefix = f"{npc_id}"
        if not isinstance(npc_id, str) or not ID_RE.match(npc_id):
            errors.append(f"{prefix}: id must match char.<slug>")
        if npc_id in seen:
            errors.append(f"{prefix}: duplicate id")
        seen.add(npc_id)
        for key in ("display_name", "title"):
            if not isinstance(npc[key], str) or not npc[key].strip():
                errors.append(f"{prefix}: {key} must be a non-empty string")
        if npc["faction"] is not None and npc["faction"] not in factions:
            errors.append(f"{prefix}: unknown faction {npc['faction']!r}")
        sheet = npc["source_sheet"]
        if not isinstance(sheet, str) or not sheet.endswith(".md") or not (ROOT / sheet).is_file():
            errors.append(f"{prefix}: source_sheet {sheet!r} does not exist")
        for key in ("portrait", "model_scene"):
            value = npc[key]
            if value is not None and not (isinstance(value, str) and _res_exists(value)):
                errors.append(f"{prefix}: {key} {value!r} does not exist")
        mode, census_id = npc["census_mode"], npc["census_id"]
        if mode not in CENSUS_MODES:
            errors.append(f"{prefix}: census_mode must be one of {sorted(CENSUS_MODES)}")
        elif mode == "replaces":
            if not isinstance(census_id, str) or not CENSUS_RE.match(census_id):
                errors.append(f"{prefix}: census_mode replaces needs a cit.* census_id")
            elif census_id not in census_ids:
                errors.append(f"{prefix}: census_id {census_id} is not in the census")
            elif census_id in linked:
                errors.append(f"{prefix}: census_id {census_id} already linked by {linked[census_id]}")
            else:
                linked[census_id] = npc_id
        elif census_id is not None:
            errors.append(f"{prefix}: census_mode extra must have census_id null")
        # ADR 0044 s.5: a census deep card already owns this char.<slug>; only a replaces link may reuse it.
        if npc_id in card_slugs and mode != "replaces":
            errors.append(f"{prefix}: slug belongs to a census deep card; link it (replaces) or pick a new slug")
        if npc["home_anchor"] not in anchors:
            errors.append(f"{prefix}: home_anchor {npc['home_anchor']!r} is not a city anchor")
        _check_schedule(prefix, npc["schedule"], anchors, errors)
        _check_body(prefix, npc["body"], errors)
        if not isinstance(npc["act_gate"], int) or not 1 <= npc["act_gate"] <= 3:
            errors.append(f"{prefix}: act_gate must be 1..3")
        if npc["wave"] not in WAVES:
            errors.append(f"{prefix}: wave must be one of {sorted(WAVES)}")
        if npc["marker"] not in MARKERS:
            errors.append(f"{prefix}: marker must be one of {sorted(MARKERS)}")
    return errors


def main(argv: list[str]) -> int:
    path = Path(argv[1]) if len(argv) > 1 else REGISTRY
    data = json.loads(path.read_text(encoding="utf-8"))
    census_ids, card_slugs = census_index()
    errors = validate(data, factions=known_factions(), anchors=known_anchors(),
                      census_ids=census_ids, card_slugs=card_slugs)
    for error in errors:
        print(f"named_npcs: {error}", file=sys.stderr)
    if errors:
        return 1
    print(f"named_npcs: OK ({len(data['npcs'])} NPCs)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
