#!/usr/bin/env python3
"""Validate content/factions/faction_identity.json (task R-1565, ADR 0044 section 4).

Every ledger faction (FactionLedger.ACTIVE_FACTIONS) and candidate seat
(FactionCandidateSeats.CANDIDATE_FACTIONS) needs an identity row, plus the
adapt/candidate rows named in the ADR. Shape is the main channel, so emblems
must be distinct files, and the primary/secondary pair must keep contrast.

Usage: python3 tools/validate_faction_identity.py [identity.json]
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from validate_named_npcs import known_factions  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
IDENTITY = ROOT / "content" / "factions" / "faction_identity.json"
CANON = ROOT / "docs" / "CANON.md"

HEX_RE = re.compile(r"^#[0-9A-Fa-f]{6}$")
SEATS = {"launch", "candidate"}
CANON_LABELS = {"attested", "plausible", "folklore", "invented"}
PLACEMENTS = {"chest", "shoulder", "belt", "head", "none"}
ACCENT_KINDS = {
    "tabard_cross", "mantle_cross", "fur_hood_purse", "indigo_belt", "hooded_cloak",
    "straw_ornament", "kaftan_cap", "tarred_cap", "gold_chaperon", "livery_sleeve",
    "hood_red_silver",
}
EXTRA_FACTIONS = {"faction.osel_wiek", "faction.dorpat"}  # ADR 0044 candidates not yet ledger seats
HERO_CRIMSON = "#D9364D"  # reserved for Kalev and priority reads
MIN_PAIR_CONTRAST = 3.0
MIN_TINT_LUMINANCE = 0.25
EMBLEM_SIZE = 128


def luminance(hex_colour: str) -> float:
    channels = [int(hex_colour[i : i + 2], 16) / 255 for i in (1, 3, 5)]
    lin = [c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4 for c in channels]
    return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]


def contrast(a: str, b: str) -> float:
    hi, lo = sorted((luminance(a), luminance(b)), reverse=True)
    return (hi + 0.05) / (lo + 0.05)


def _emblem_problem(res_path: str) -> str | None:
    if not res_path.startswith("res://"):
        return "emblem must be a res:// path"
    path = ROOT / res_path.removeprefix("res://")
    if not path.is_file():
        return f"emblem file missing: {res_path}"
    try:
        from PIL import Image

        with Image.open(path) as image:
            if image.size != (EMBLEM_SIZE, EMBLEM_SIZE) or image.mode != "RGBA":
                return f"emblem must be {EMBLEM_SIZE}x{EMBLEM_SIZE} RGBA, got {image.size} {image.mode}"
    except ImportError:  # Pillow only for the size check; CI without it still checks existence
        pass
    return None


def validate(data: object, *, factions: set[str], canon_text: str = "") -> list[str]:
    errors: list[str] = []
    if not isinstance(data, dict) or data.get("schema_version") != 1:
        return ["top level must be an object with schema_version 1"]
    rows = data.get("factions")
    if not isinstance(rows, list) or not rows:
        return ["`factions` must be a non-empty array"]
    seen: set[str] = set()
    emblems: dict[str, str] = {}
    for index, row in enumerate(rows):
        fid = row.get("id") if isinstance(row, dict) else None
        prefix = f"factions[{index}] {fid}"
        if not isinstance(row, dict) or not isinstance(fid, str):
            errors.append(f"factions[{index}]: must be an object with an id")
            continue
        if fid in seen:
            errors.append(f"{prefix}: duplicate id")
        seen.add(fid)
        if fid not in factions and fid not in EXTRA_FACTIONS:
            errors.append(f"{prefix}: not a ledger faction, candidate seat or ADR 0044 candidate")
        if row.get("seat") not in SEATS:
            errors.append(f"{prefix}: seat must be one of {sorted(SEATS)}")
        if not isinstance(row.get("display_name"), str) or not row["display_name"]:
            errors.append(f"{prefix}: display_name required")
        colours_ok = True
        for key in ("primary", "secondary", "marker_tint"):
            if not isinstance(row.get(key), str) or not HEX_RE.match(row[key]):
                errors.append(f"{prefix}: {key} must be #RRGGBB")
                colours_ok = False
        if colours_ok:
            if HERO_CRIMSON in (row["primary"].upper(), row["secondary"].upper(), row["marker_tint"].upper()):
                errors.append(f"{prefix}: hero crimson {HERO_CRIMSON} is reserved")
            ratio = contrast(row["primary"], row["secondary"])
            if ratio < MIN_PAIR_CONTRAST:
                errors.append(f"{prefix}: primary/secondary contrast {ratio:.2f} < {MIN_PAIR_CONTRAST}")
            if luminance(row["marker_tint"]) < MIN_TINT_LUMINANCE:
                errors.append(f"{prefix}: marker_tint too dark to read over the street")
        emblem = row.get("emblem")
        problem = _emblem_problem(emblem) if isinstance(emblem, str) else "emblem required"
        if problem:
            errors.append(f"{prefix}: {problem}")
        elif emblem in emblems:
            errors.append(f"{prefix}: emblem shared with {emblems[emblem]} (shape must differ)")
        else:
            emblems[emblem] = fid
        accent = row.get("accent")
        if not isinstance(accent, dict):
            errors.append(f"{prefix}: accent object required")
        else:
            if accent.get("kind") not in ACCENT_KINDS:
                errors.append(f"{prefix}: accent.kind must be one of {sorted(ACCENT_KINDS)}")
            if accent.get("placement") not in PLACEMENTS:
                errors.append(f"{prefix}: accent.placement must be one of {sorted(PLACEMENTS)}")
            if not isinstance(accent.get("emblem_on_body"), bool):
                errors.append(f"{prefix}: accent.emblem_on_body must be a boolean")
            elif accent["emblem_on_body"] and accent.get("placement") == "none":
                errors.append(f"{prefix}: emblem_on_body needs a placement")
        if not isinstance(row.get("public_emblem"), bool):
            errors.append(f"{prefix}: public_emblem must be a boolean")
        if row.get("canon") not in CANON_LABELS:
            errors.append(f"{prefix}: canon must be one of {sorted(CANON_LABELS)}")
        if canon_text:
            line = next((l for l in canon_text.splitlines() if l.startswith(f"| `{fid}`")), "")
            if not line:
                errors.append(f"{prefix}: no heraldry row in docs/CANON.md")
            elif f"`{row.get('canon')}`" not in line:
                errors.append(f"{prefix}: CANON.md label differs from canon={row.get('canon')}")
    for missing in sorted(factions - seen):
        errors.append(f"missing identity row for {missing}")
    for missing in sorted(EXTRA_FACTIONS - seen):
        errors.append(f"missing identity row for {missing}")
    return errors


def main(argv: list[str]) -> int:
    path = Path(argv[1]) if len(argv) > 1 else IDENTITY
    data = json.loads(path.read_text(encoding="utf-8"))
    errors = validate(data, factions=known_factions(), canon_text=CANON.read_text(encoding="utf-8"))
    for error in errors:
        print("ERROR:", error)
    if errors:
        return 1
    print(f"{path.relative_to(ROOT)}: {len(data['factions'])} faction identities OK")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
