#!/usr/bin/env python3
"""Generate docs/TOURIST_LANDMARKS.md from the geographic data modules."""

from __future__ import annotations

import sys
from pathlib import Path

from tourist_landmarks import (
    DISTRICT_MAP_LOCATION,
    ESTONIA,
    EXCLUDED,
    FEATURED_LANDMARKS,
    REGION_MAP_LOCATION,
    TALLINN,
)

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "TOURIST_LANDMARKS.md"


def count_entries() -> tuple[int, int]:
    t = sum(len(v) for v in TALLINN.values())
    e = sum(len(v) for v in ESTONIA.values())
    return t, e


def render_featured_section() -> list[str]:
    lines = [
        "## Featured tourist landmarks",
        "",
        "Quick reference for the most-visited Tallinn sites and campaign-adjacent",
        "Estonia locations. Full district catalogs follow in Parts I and II.",
        "",
        "| Landmark | 1343 snapshot | Map binding | Canon / lore |",
        "| --- | --- | --- | --- |",
    ]
    for name, snapshot, map_binding, canon in FEATURED_LANDMARKS:
        lines.append(f"| {name} | {snapshot} | {map_binding} | {canon} |")
    lines.append("")
    return lines


def _table_cell(value: str) -> str:
    return value.replace("|", "\\|").replace("\n", " ")


def render_catalog_table(
    items: list[tuple[str, str, str, str]],
    map_location: str,
    start_number: int,
) -> tuple[list[str], int]:
    lines = [
        "| Landmark | Modern Status | 1343 Status | Map Location | Lore Tie-in |",
        "|---|---|---|---|---|",
    ]
    number = start_number
    for name, modern, status, lore in items:
        cells = (
            f"{number}. {name}",
            modern,
            status,
            map_location,
            lore,
        )
        lines.append("| " + " | ".join(_table_cell(cell) for cell in cells) + " |")
        number += 1
    return lines, number


def render() -> str:
    t_count, e_count = count_entries()
    lines: list[str] = [
        "# Tourist Landmarks: Modern Estonia vs. 1343 Reval",
        "",
        "This document catalogs notable tourist landmarks in modern Tallinn and Estonia,",
        "mapping each to its **1343 status** during the events of *Reval Rebel*.",
        "Landmarks that did not exist in 1343 are listed only in the exclusion appendix.",
        "",
        "## Overview",
        "",
        "Each landmark includes:",
        "- **Modern Status**: Current state as a tourist destination",
        "- **1343 Status**: Historical context during the game's setting",
        "- **Map Location**: Blueprint map id, stable anchor or landmark id when authored",
        "- **Lore Tie-in**: Connection to in-game factions, characters, and map locations",
        "",
        f"**Counts:** {t_count} Tallinn landmarks grouped by district; {e_count} elsewhere in Estonia.",
        "",
        "For historical context, factions, and characters see [`docs/CANON.md`](CANON.md).",
        "For map authoring boundaries see [`docs/HISTORICAL_AUDIT.md`](HISTORICAL_AUDIT.md).",
        "",
        "---",
        "",
    ]
    lines.extend(render_featured_section())
    lines.extend(
        [
            "---",
            "",
            "# Part I: Tallinn (Reval) by District",
            "",
        ]
    )

    n = 1
    for district, items in TALLINN.items():
        map_location = DISTRICT_MAP_LOCATION[district]
        lines.append(f"## {district}")
        lines.append("")
        lines.append(f"*District map binding:* {map_location}")
        lines.append("")
        table, n = render_catalog_table(items, map_location, n)
        lines.extend(table)

    lines.extend(
        [
            "---",
            "",
            "# Part II: Rest of Estonia",
            "",
        ]
    )

    m = 1
    for region, items in ESTONIA.items():
        map_location = REGION_MAP_LOCATION[region]
        lines.append(f"## {region}")
        lines.append("")
        lines.append(f"*Region map binding:* {map_location}")
        lines.append("")
        table, m = render_catalog_table(items, map_location, m)
        lines.extend(table)

    lines.extend(
        [
            "---",
            "",
            "# Appendix: Excluded Modern Landmarks (not present in 1343)",
            "",
            "These popular tourist sites are **omitted** from the main catalog because",
            "their current buildings or uses did not exist in 1343. Where a guild or",
            "institution existed in simpler form, see the district entries above.",
            "",
        ]
    )
    for name, modern, status in EXCLUDED:
        lines.append(f"- **{name}** - {modern} **1343:** {status}")
        lines.append("")

    return "\n".join(lines)


def rendered_catalog() -> str:
    t, e = count_entries()
    if t < 95:
        raise SystemExit(f"Tallinn count too low: {t}")
    if e < 95:
        raise SystemExit(f"Estonia count too low: {e}")
    return render()


def main() -> int:
    check = "--check" in sys.argv[1:]
    unknown = [arg for arg in sys.argv[1:] if arg != "--check"]
    if unknown:
        print(f"unknown argument(s): {' '.join(unknown)}", file=sys.stderr)
        return 2

    catalog = rendered_catalog()
    if check:
        actual = OUT.read_text(encoding="utf-8") if OUT.is_file() else ""
        if actual != catalog:
            print(
                f"stale generated tourist landmarks catalog: {OUT.relative_to(ROOT)}",
                file=sys.stderr,
            )
            return 1
        print("tourist landmarks catalog is up to date")
        return 0

    OUT.write_text(catalog, encoding="utf-8")
    t, e = count_entries()
    print(f"Wrote {OUT} ({t} Tallinn + {e} Estonia landmarks)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
