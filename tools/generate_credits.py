#!/usr/bin/env python3
"""Generate CREDITS.md from the audio attribution manifests.

Why: every field recording we ship is Creative Commons licensed and therefore
carries an attribution (BY) obligation. This script is the single source of
truth that turns the machine-readable manifests (sounds/birds/manifest.csv and
sounds/insects/manifest.csv) into the human-readable CREDITS.md that is both
committed to the repo and displayed in-game (Main Menu -> Credits).

Re-run after adding/removing any audio asset:
    python3 tools/generate_credits.py
"""
import csv
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Map the license URL stored in the manifests to a friendly display name.
LICENSE_NAMES = {
    "https://creativecommons.org/publicdomain/zero/1.0/": "CC0 1.0 (Public Domain)",
    "https://creativecommons.org/licenses/by/4.0/": "CC BY 4.0",
    "https://creativecommons.org/licenses/by/3.0/": "CC BY 3.0",
    "https://creativecommons.org/licenses/by-sa/4.0/": "CC BY-SA 4.0",
    "https://creativecommons.org/licenses/by-sa/3.0/": "CC BY-SA 3.0",
}


def license_name(url: str) -> str:
    return LICENSE_NAMES.get(url.strip(), url.strip())


def titleize(slug: str) -> str:
    return " ".join(w.capitalize() for w in slug.split("_"))


def read_csv(path: str):
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def main() -> None:
    birds = read_csv(os.path.join(ROOT, "sounds/birds/manifest.csv"))
    insects_path = os.path.join(ROOT, "sounds/insects/manifest.csv")
    insects = read_csv(insects_path) if os.path.exists(insects_path) else []

    lines = []
    lines.append("# Credits")
    lines.append("")
    lines.append(
        "Rebel Reval uses real-world wildlife field recordings released under "
        "Creative Commons licenses. Every recording below is used within the "
        "terms of its license, which for commercial use requires attribution "
        "(and, for ShareAlike works, that any recording we edited stays under "
        "the same license). Recordings were trimmed/normalised for in-game use."
    )
    lines.append("")

    # --- Bird sounds -----------------------------------------------------
    lines.append("## Bird sounds")
    lines.append("")
    lines.append("Source: xeno-canto.org and iNaturalist.org.")
    lines.append("")
    for r in sorted(birds, key=lambda x: titleize(x["bird_id"])):
        name = titleize(r["bird_id"])
        sci = r["scientific"]
        rec = r["recordist"]
        lic = license_name(r["license"])
        src = r["page"]
        lines.append(f"- {name} (*{sci}*) - recorded by {rec}. {lic}. Source: {src}")
    lines.append("")

    # --- Insect / Orthoptera ambient ------------------------------------
    if insects:
        lines.append("## Insect ambience (Orthoptera)")
        lines.append("")
        lines.append(
            "Source: eBiodiversity / elurikkus.ee (PlutoF), University of Tartu. "
            "Used for ambient insect stridulation layers."
        )
        lines.append("")
        for r in sorted(insects, key=lambda x: x["scientific"]):
            sci = r["scientific"]
            common = (r.get("common_en") or "").strip()
            label = f"{common} (*{sci}*)" if common else f"*{sci}*"
            rec = r["recordist"] or "Unknown recordist"
            lic = license_name(r["license"])
            src = r["source"]
            lines.append(
                f"- {label} - recorded by {rec}. {lic}. "
                f"eBiodiversity occurrence {r['elu_id']}. Source: {src}"
            )
        lines.append("")

    # --- License references ---------------------------------------------
    lines.append("## Licenses")
    lines.append("")
    lines.append("- CC0 1.0: https://creativecommons.org/publicdomain/zero/1.0/")
    lines.append("- CC BY 4.0: https://creativecommons.org/licenses/by/4.0/")
    lines.append("- CC BY-SA 4.0: https://creativecommons.org/licenses/by-sa/4.0/")
    lines.append("- CC BY-SA 3.0: https://creativecommons.org/licenses/by-sa/3.0/")
    lines.append("")
    lines.append(
        "ShareAlike note: recordings under a CC BY-SA license that we edited "
        "remain available under the same CC BY-SA license; this does not affect "
        "the licensing of the rest of the game."
    )
    lines.append("")

    out = os.path.join(ROOT, "CREDITS.md")
    with open(out, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"Wrote {out} ({len(birds)} birds, {len(insects)} insects)")


if __name__ == "__main__":
    main()
