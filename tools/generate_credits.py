#!/usr/bin/env python3
"""Generate CREDITS.md from the audio and 3D model attribution manifests.

Why: every field recording we ship is Creative Commons licensed and therefore
carries an attribution (BY) obligation. This script is the single source of
truth that turns the machine-readable manifests (sounds/birds/manifest.csv,
sounds/insects/manifest.csv, and sounds/water/manifest.csv) and the CC BY animal
model manifest (assets/storybook/mammal_sources.json) into the human-readable
CREDITS.md that is both committed to the repo and displayed in-game
(Main Menu -> Credits).

Re-run after adding/removing any audio asset or licensed animal model:
    python3 tools/generate_credits.py
"""
import csv
import json
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

# Runtime ids that differ from the in-game animal name.
MODEL_LABELS = {
    "forge_cat": "Cat",
    "boar": "Wild boar",
    "cow": "Cow (brown coat)",
    "cow_holstein": "Cow (pied coat)",
}

# Licensed models imported before mammal_sources.json existed. Keep their
# attribution here so regenerating CREDITS.md never drops an obligation.
LEGACY_MODEL_CREDITS = [
    ("Chicken", "Chicken", "hendrikReyneke",
     "https://sketchfab.com/3d-models/chicken-ce17aabc51ba47bfbc7342a963b095e9"),
    ("Duck", "Duck", "hendrikReyneke",
     "https://sketchfab.com/3d-models/duck-74d6f61c73fd4dcd9607694fc3241e06"),
    ("House sparrow", "Sparrow", "hendrikReyneke",
     "https://sketchfab.com/3d-models/sparrow-fc347fa4d3b84a3c99df887a36c4e2fe"),
]


def license_name(url: str) -> str:
    return LICENSE_NAMES.get(url.strip(), url.strip())


def titleize(slug: str) -> str:
    return " ".join(w.capitalize() for w in slug.split("_"))


def read_csv(path: str):
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def model_title(model: dict) -> str:
    # Older manifest rows predate the title field; recover it from the page slug.
    if model.get("title"):
        return model["title"]
    slug = model["url"].rstrip("/").rsplit("/", 1)[-1].rsplit("-", 1)[0]
    return " ".join(w.capitalize() for w in slug.split("-"))


def model_lines() -> list:
    path = os.path.join(ROOT, "assets/storybook/mammal_sources.json")
    if not os.path.exists(path):
        return []
    with open(path, encoding="utf-8") as f:
        models = json.load(f)["models"]
    lines = ["## 3D animal models", ""]
    lines.append(
        "Source: Sketchfab. Each model was rescaled, reoriented, re-rigged and "
        "animated for the game; textures were resized and materials adjusted."
    )
    lines.append("")
    entries = [
        (
            MODEL_LABELS.get(model_id, model_id.replace("_", " ").capitalize()),
            model_title(m),
            m["author"],
            license_name(m.get("license_url", "")),
            m["url"],
        )
        for model_id, m in models.items()
    ]
    entries += [(label, title, author, "CC BY 4.0", url) for label, title, author, url in LEGACY_MODEL_CREDITS]
    for label, title, author, lic, url in sorted(entries, key=lambda e: e[0].lower()):
        lines.append(f"- {label} - \"{title}\" by {author}. {lic}. Source: {url}")
    lines.append("")
    return lines


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

    lines.extend(model_lines())

    # --- Water-crossing one-shots (WS-13c) ------------------------------
    water_path = os.path.join(ROOT, "sounds/water/manifest.csv")
    water = read_csv(water_path) if os.path.exists(water_path) else []
    if water:
        lines.append("## Water crossing sound effects")
        lines.append("")
        lines.append(
            "In-house one-shots for the underwater camera pass. Synthesized "
            "Foley, not wildlife field recordings."
        )
        lines.append("")
        for row in sorted(water, key=lambda item: item.get("title") or item.get("clip_id") or ""):
            title = (row.get("title") or row.get("clip_id") or "Untitled clip").strip()
            author = (row.get("author") or "Unknown author").strip()
            lic = license_name(row.get("license") or "")
            src = (row.get("page") or "").strip()
            line = f"- {title} - synthesized by {author}. {lic}."
            if src:
                line += f" Source: {src}"
            lines.append(line)
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
    print(
        f"Wrote {out} ({len(birds)} birds, {len(insects)} insects, "
        f"{len(water)} water clips, 3D model credits)"
    )


if __name__ == "__main__":
    main()
