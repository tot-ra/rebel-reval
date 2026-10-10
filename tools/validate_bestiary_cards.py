#!/usr/bin/env python3
"""Validate the bestiary roster and creature cards under docs/BESTIARY.

  python3 tools/validate_bestiary_cards.py              # roster + every card in docs/BESTIARY/cards
  python3 tools/validate_bestiary_cards.py FILE.md ...  # roster + only these cards

Checks: roster table shape, unique `bst.` IDs, layer and tier enums, a reason on every row,
card links that exist and carry the same ID, rejected rows without cards, orphan card files,
and per card: section order, field table, ID/layer/tier agreeing with the roster.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BEST = ROOT / "docs/BESTIARY"
ROSTER = BEST / "README.md"
CARDS = BEST / "cards"

LAYERS = {"spirit", "physical", "hybrid", "rejected"}
TIERS = {"slice", "act1", "act2", "act3", "backlog"}
CONFIDENCE = {"folklore", "invented", "attested", "plausible composite"}
ROSTER_COLUMNS = ["ID", "Name", "Layer", "Tier", "Habitat", "Factions", "Basis", "Images", "Card", "Reasoning"]
FIELDS = ["ID", "Layer", "Tier", "Confidence", "Habitat", "Faction ties", "Archive reference images"]
SECTIONS = ["At a glance", "Folklore origin", "Appearance", "Motivation", "Manifestation", "Combat profile", "Voice",
            "Relationships and factions", "Game hooks"]
APPEARANCE_BULLETS = ["Body", "Materials and colours", "What a model must get right", "Concept-art prompt", "Model notes"]
ID_RE = re.compile(r"^bst\.[a-z0-9_]+$")
LINK_RE = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")


def cells(line: str) -> list[str]:
    return [c.strip() for c in line.strip().strip("|").split("|")]


def parse_roster(errors: list[str]) -> list[dict]:
    rel = ROSTER.relative_to(ROOT).as_posix()
    lines = ROSTER.read_text(encoding="utf-8").splitlines()
    start = next((i for i, l in enumerate(lines) if cells(l)[:2] == ["ID", "Name"]), None)
    if start is None:
        errors.append(f"{rel}: roster table (header 'ID | Name | ...') not found")
        return []
    if cells(lines[start]) != ROSTER_COLUMNS:
        errors.append(f"{rel}: roster columns must be {ROSTER_COLUMNS}")
        return []
    rows = []
    for l in lines[start + 2:]:
        if not l.startswith("|"):
            break
        c = cells(l)
        if len(c) != len(ROSTER_COLUMNS):
            errors.append(f"{rel}: row has {len(c)} cells, expected {len(ROSTER_COLUMNS)}: {l[:60]}")
            continue
        rows.append(dict(zip(ROSTER_COLUMNS, c)))
    return rows


def check_roster(rows: list[dict], errors: list[str]) -> dict[str, dict]:
    rel = ROSTER.relative_to(ROOT).as_posix()
    by_id: dict[str, dict] = {}
    for r in rows:
        rid = r["ID"].strip("`")
        r["ID"] = rid
        if not ID_RE.match(rid):
            errors.append(f"{rel}: bad ID '{rid}' (want bst.<lower_snake>)")
        if rid in by_id:
            errors.append(f"{rel}: duplicate ID {rid}")
        by_id[rid] = r
        layer, tier = r["Layer"], r["Tier"]
        if layer not in LAYERS:
            errors.append(f"{rel}: {rid} layer '{layer}' not in {sorted(LAYERS)}")
        if layer == "rejected":
            if tier != "-":
                errors.append(f"{rel}: {rid} is rejected, tier must be '-'")
            if r["Card"] != "-":
                errors.append(f"{rel}: {rid} is rejected, Card must be '-'")
        elif tier not in TIERS:
            errors.append(f"{rel}: {rid} tier '{tier}' not in {sorted(TIERS)}")
        if len(r["Reasoning"]) < 20:
            errors.append(f"{rel}: {rid} needs a reasoning sentence")
        link = LINK_RE.search(r["Card"])
        if link:
            target = (ROSTER.parent / link.group(1)).resolve()
            if not target.exists():
                errors.append(f"{rel}: {rid} card link {link.group(1)} does not exist")
            elif target.stem != rid.removeprefix("bst."):
                errors.append(f"{rel}: {rid} card file must be named {rid.removeprefix('bst.')}.md")
        elif layer != "rejected" and r["Card"] != "planned":
            errors.append(f"{rel}: {rid} Card must be a link or 'planned'")
    return by_id


def check_card(path: Path, by_id: dict[str, dict], errors: list[str]) -> None:
    rel = path.relative_to(ROOT).as_posix()
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()

    def err(msg: str) -> None:
        errors.append(f"{rel}: {msg}")

    if not lines or not lines[0].startswith("# "):
        err("first line must be '# <name>'")
    if len(lines) < 3 or not lines[2].startswith("> "):
        err("line 3 must be the '> hook' blockquote")
    fields = {}
    for l in lines:
        c = cells(l) if l.startswith("|") else []
        if len(c) == 2 and c[0] in FIELDS:
            fields[c[0]] = c[1]
    for f in FIELDS:
        if f not in fields:
            err(f"missing field '{f}'")
    cid = fields.get("ID", "").strip("`")
    if cid != f"bst.{path.stem}":
        err(f"ID '{cid}' must be bst.{path.stem}")
    row = by_id.get(cid)
    if row is None:
        err(f"{cid} is not in the roster")
    else:
        if fields.get("Layer", "").strip("`") != row["Layer"]:
            err("Layer differs from the roster")
        if fields.get("Tier", "").strip("`") != row["Tier"]:
            err("Tier differs from the roster")
        if row["Layer"] == "rejected":
            err("rejected roster rows have no card")
    if fields.get("Confidence", "").strip("`") not in CONFIDENCE:
        err(f"Confidence must be one of {sorted(CONFIDENCE)}")
    headings = [l[3:].strip() for l in lines if l.startswith("## ")]
    if headings != SECTIONS:
        err(f"sections must be exactly {SECTIONS}, got {headings}")
    for b in APPEARANCE_BULLETS:
        if f"- **{b}:**" not in text:
            err(f"Appearance bullet '{b}' missing")
    if "<" in text and re.search(r"<[A-Za-z][^>\n]*>", re.sub(r"`[^`]*`", "", text)):
        err("unreplaced <placeholder> left in the card")
    for target in LINK_RE.findall(text):
        if re.match(r"^[a-z]+:", target) or target.startswith("#"):
            continue
        if not (path.parent / target.split("#")[0]).exists():
            err(f"broken link {target}")


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="*")
    args = ap.parse_args(argv)
    errors: list[str] = []
    by_id = check_roster(parse_roster(errors), errors)
    if args.files:
        paths = [Path(f) if Path(f).exists() else CARDS / (Path(f).stem + ".md") for f in args.files]
    else:
        paths = sorted(CARDS.glob("*.md"))
    for p in paths:
        check_card(p.resolve(), by_id, errors)
    if not args.files:
        # A card file must be linked from its roster row, otherwise it is an orphan.
        linked = {LINK_RE.search(r["Card"]).group(1).split("/")[-1] for r in by_id.values() if LINK_RE.search(r["Card"])}
        for p in paths:
            if p.name not in linked:
                errors.append(f"{p.relative_to(ROOT).as_posix()}: card is not linked from the roster")
    for e in errors:
        print(e)
    print(f"{len(by_id)} roster rows, {len(paths)} cards, {len(errors)} errors")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
