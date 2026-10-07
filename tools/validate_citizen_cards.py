#!/usr/bin/env python3
"""Validate citizen cards under docs/CITIZENS/people against the census and the card plan.

  python3 tools/validate_citizen_cards.py                 # check every existing card
  python3 tools/validate_citizen_cards.py --require-all   # also fail on planned cards that are missing
  python3 tools/validate_citizen_cards.py FILE.md ...     # check only these cards (path or slug)

Checks: structure and section order, the field table against the census, the appearance seed
(height, eye colour, hair colour), word counts, relative links and ledger anchors, reciprocal
network links for planned edges, and period vocabulary.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/city"))
CIT = ROOT / "docs/CITIZENS"
PEOPLE = CIT / "people"
CENSUS = ROOT / "docs/data/city_census.json"
PLAN = ROOT / "docs/data/citizen_cards_plan.json"

SECTIONS = ["At a glance", "Appearance", "Biography", "Motivation", "Daily routine", "Work and money", "Relationships", "Faction and belief", "Voice",
            "Knowledge and rumours", "Game hooks"]
FIELDS = ["ID", "Census ID", "Confidence", "Tier", "Household", "Home", "Age / sex", "Ethnicity / segment", "Status", "Trade", "Languages",
          "Literacy", "Faction", "Office"]
APPEARANCE_BULLETS = ["Body", "Face", "Hair and facial hair", "Skin and marks", "Hands", "Clothing and kit", "Portrait prompt", "Model notes"]
CONFIDENCE = {"plausible composite", "invented", "attested", "folklore"}
BANNED = [r"\bartig\b", r"\bokay\b", r"\bpotato", r"\btobacco", r"\bdoublet", r"\bteenager", r"\bspectacle", r"\bmusket", r"\bgunpowder\b",
          r"\bcoffee\b", r"\btea\b", r"\bunderwear\b", r"\bpsycholog", r"\bPTSD\b", r"\bstress(ed)?\b", r"\bcotton\b", r"\bbutton(s|ed)? down\b"]
LINK_RE = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")


def words(text: str) -> int:
    return len(re.findall(r"[A-Za-zÀ-ÿ'’-]+", text))


def load():
    census = json.loads(CENSUS.read_text(encoding="utf-8"))
    plan = json.loads(PLAN.read_text(encoding="utf-8"))
    return census, plan


def ledger_anchors() -> dict[Path, set[str]]:
    out = {}
    for f in (CIT / "ledger").rglob("*.md"):
        out[f] = set(re.findall(r'<a id="([^"]+)">', f.read_text(encoding="utf-8")))
    return out


def check_card(path: Path, P_by_slug, H, anchors, errors, warnings, planned_paths=frozenset()):
    rel = path.relative_to(ROOT).as_posix()
    text = path.read_text(encoding="utf-8")
    slug = path.stem

    def err(msg):
        errors.append(f"{rel}: {msg}")

    def warn(msg):
        warnings.append(f"{rel}: {msg}")

    p = P_by_slug.get(slug)
    if not p:
        err("file name is not a census slug")
        return None
    expected_dir = __import__("build_city_census").DISTRICT_DIR[H[p["household"]]["district"]]
    if path.parent.name != expected_dir:
        err(f"card must live in people/{expected_dir}/")
    lines = text.splitlines()
    if not lines or not lines[0].startswith("# "):
        err("first line must be '# <name>'")
    elif lines[0][2:].strip() != p["name"]:
        err(f"title '{lines[0][2:].strip()}' differs from census name '{p['name']}'")
    if len(lines) < 3 or not lines[2].startswith("> "):
        err("line 3 must be the '> hook' blockquote")
    # field table
    fields = {}
    for m in re.finditer(r"^\|\s*([^|]+?)\s*\|\s*(.+?)\s*\|\s*$", text, re.M):
        fields[m.group(1)] = m.group(2)
    for f in FIELDS:
        if f not in fields:
            err(f"missing field '{f}'")
    if fields.get("ID") != f"`char.{slug}`":
        err("ID must be `char.<slug>`")
    if fields.get("Census ID") != f"`{p['id']}`":
        err(f"Census ID must be `{p['id']}`")
    conf = fields.get("Confidence", "").strip("`")
    if conf not in CONFIDENCE:
        err(f"Confidence '{conf}' not in {sorted(CONFIDENCE)}")
    age_sex = fields.get("Age / sex", "")
    if not re.match(rf"^{p['age']}, {'male' if p['sex'] == 'm' else 'female'}\b", age_sex):
        err(f"Age / sex must start '{p['age']}, {'male' if p['sex'] == 'm' else 'female'}', got '{age_sex}'")
    if p["ethnicity"] not in fields.get("Ethnicity / segment", "") or p["segment"] not in fields.get("Ethnicity / segment", ""):
        err(f"Ethnicity / segment must name {p['ethnicity']} / {p['segment']}")
    h = H[p["household"]]
    if p["household"] not in fields.get("Household", ""):
        err(f"Household must name {p['household']}")
    if "(../../ledger/" not in fields.get("Household", ""):
        err("Household must link to ../../ledger/...")
    if h["street"] not in fields.get("Home", ""):
        warn(f"Home should name the street '{h['street']}'")
    # sections
    heads = re.findall(r"^## (.+?)\s*$", text, re.M)
    if heads != SECTIONS:
        err(f"H2 sections must be exactly, in order: {SECTIONS}; found {heads}")
    for b in APPEARANCE_BULLETS:
        if not re.search(rf"^- \*\*{re.escape(b)}[^*]*:\*\*", text, re.M):
            err(f"Appearance bullet '{b}' missing")
    # seed checks
    ap = p["appearance"]
    if not re.search(rf"\b{ap['height_cm']}\s*cm\b", text):
        err(f"height {ap['height_cm']} cm not stated")
    first_eye = ap["eyes"].split("-")[0].split()[0]
    if first_eye.lower() not in text.lower():
        err(f"eye colour '{ap['eyes']}' not mentioned")
    base = ap["hair"].split(",")[0].split(" with ")[0].replace("mostly grey over ", "")
    if not any(tok in text.lower() for tok in [base.lower(), base.lower().split()[-1]]) and base not in ("white", "iron-grey"):
        warn(f"hair colour '{ap['hair']}' not recognisable")
    for mk in ap["marks"]:
        toks = [t for t in re.findall(r"[a-z]{4,}", mk.lower()) if t not in ("with", "from", "over", "above", "under", "that", "left", "right")]
        if toks and not any(t in text.lower() for t in toks):
            warn(f"seed mark '{mk}' not recognisable")
    # words
    body = re.sub(r"```.*?```", "", text, flags=re.S)
    n = words(body)
    lo, hi = (450, 1500) if p["age"] >= 14 else (250, 900)
    if n < lo or n > hi:
        err(f"{n} words; expected {lo}-{hi}")
    # banned vocabulary
    for rx in BANNED:
        if re.search(rx, text, re.I):
            warn(f"period vocabulary: matches /{rx}/")
    # links
    own_links = set()
    for m in LINK_RE.finditer(text):
        target = m.group(1)
        if target.startswith(("http://", "https://", "mailto:")):
            continue
        base_t, _, frag = target.partition("#")
        if not base_t:
            continue
        dest = (path.parent / base_t).resolve()
        if not dest.exists():
            if dest in planned_paths:
                own_links.add(dest)
                continue
            err(f"broken link {target}")
            continue
        own_links.add(dest)
        if frag and dest.suffix == ".md" and dest.parent.parent.name == "ledger" or (frag and "/ledger/" in dest.as_posix()):
            if dest in anchors and frag not in anchors[dest]:
                err(f"missing ledger anchor {target}")
    return p, own_links


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="*")
    ap.add_argument("--require-all", action="store_true")
    ap.add_argument("--warnings-as-errors", action="store_true")
    args = ap.parse_args(argv)
    census, plan = load()
    P = {p["id"]: p for p in census["persons"]}
    P_by_slug = {p["slug"]: p for p in census["persons"]}
    H = {h["id"]: h for h in census["households"]}
    anchors = ledger_anchors()
    errors, warnings = [], []
    planned = set(plan["cards"])
    DD = __import__("build_city_census").DISTRICT_DIR
    planned_paths = frozenset() if args.require_all else frozenset(
        (PEOPLE / DD[H[P[pid]["household"]]["district"]] / f"{P[pid]['slug']}.md").resolve() for pid in planned)
    if len(P_by_slug) != len(P):
        errors.append("census slugs are not unique")
    if args.files:
        files = []
        for f in args.files:
            pth = Path(f)
            if not pth.exists():
                pth = next(PEOPLE.rglob(f"{Path(f).stem}.md"), pth)
            files.append(pth.resolve())
    else:
        files = sorted(PEOPLE.rglob("*.md"))
    files = [f for f in files if f.name != "README.md"]
    links_by_id = {}
    for f in files:
        res = check_card(f, P_by_slug, H, anchors, errors, warnings, planned_paths)
        if res:
            p, links = res
            links_by_id[p["id"]] = links
            if p["id"] not in planned:
                errors.append(f"{f.relative_to(ROOT).as_posix()}: person is not in the card plan")
            # location in the right district folder
    # reciprocity for planned edges when both cards were checked
    if not args.files:
        have = {p["id"]: P[p["id"]]["slug"] for p in [P[i] for i in links_by_id]}
        for e in plan["edges"]:
            a, b = e["a"], e["b"]
            if a in links_by_id and b in links_by_id:
                fa = next((f for f in files if f.stem == P[a]["slug"]), None)
                fb = next((f for f in files if f.stem == P[b]["slug"]), None)
                if fa and fb:
                    if fb.resolve() not in links_by_id[a]:
                        errors.append(f"{fa.relative_to(ROOT).as_posix()}: planned edge to {P[b]['name']} ({e['kind']}) is not linked")
                    if fa.resolve() not in links_by_id[b]:
                        errors.append(f"{fb.relative_to(ROOT).as_posix()}: planned edge to {P[a]['name']} ({e['kind']}) is not linked")
    if args.require_all and not args.files:
        have_slugs = {f.stem for f in files}
        for pid in sorted(planned):
            if P[pid]["slug"] not in have_slugs:
                errors.append(f"missing card for {P[pid]['name']} ({pid}) -> {P[pid]['slug']}.md")
    for w in warnings:
        print("warning:", w)
    for e in errors:
        print("error:", e)
    print(f"{len(files)} cards checked, {len(errors)} errors, {len(warnings)} warnings")
    if errors or (warnings and args.warnings_as_errors):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
