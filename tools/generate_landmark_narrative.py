#!/usr/bin/env python3
"""Generate the P1-037 landmark narrative manifest and readable design matrix."""

from __future__ import annotations

import json
import sys
from collections import Counter
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from tourist_landmarks import ESTONIA, TALLINN, build_integrations  # noqa: E402

ROOT = TOOLS.parent
MANIFEST = ROOT / "docs" / "data" / "landmark_integrations.json"
DOCUMENT = ROOT / "docs" / "LANDMARK_NARRATIVE_INTEGRATION.md"


def build_manifest() -> dict[str, object]:
    integrations = build_integrations(TALLINN, ESTONIA)
    return {
        "schema_version": 1,
        "task": "P1-037",
        "source_catalog": "docs/TOURIST_LANDMARKS.md",
        "activation_policy": (
            "Narrative beats are design bindings only. Their owner tasks author runtime "
            "content and activate maps through the existing campaign gates."
        ),
        "integrations": integrations,
    }


def render_document(manifest: dict[str, object]) -> str:
    rows = manifest["integrations"]
    assert isinstance(rows, list)
    task_id = str(manifest["task"])
    channels = Counter(str(row["delivery_channel"]) for row in rows)
    kinds = Counter(str(row["integration_kind"]) for row in rows)
    maps = Counter(str(row["map_anchor"]["map_id"]) for row in rows)

    lines = [
        "# Landmark Narrative Integration",
        "",
        "This is the readable design view of `docs/data/landmark_integrations.json`.",
        "It binds every non-excluded P0-113 tourist landmark to an authored quest, event,",
        "or lore-fragment parent, one concrete narrative beat, and an existing map anchor.",
        "",
        f"Task: **{task_id}**. The bindings do not activate prototype maps or ship campaign content early.",
        "`owner task` identifies the existing TODO gate that must turn each design beat into",
        "runtime content. Stable beat and delivery IDs let those tasks reference the plan",
        "without renaming landmarks or creating a parallel quest framework.",
        "",
        "## Coverage summary",
        "",
        f"- Catalog landmarks covered: `{len(rows)}`",
        f"- Quest bindings: `{kinds['quest']}`",
        f"- Event bindings: `{kinds['event']}`",
        f"- Lore-fragment bindings: `{kinds['lore_fragment']}`",
        f"- NPC dialogue beats: `{channels['npc_dialogue']}`",
        f"- Discovery-event beats: `{channels['discovery_event']}`",
        f"- Lore-fragment deliveries: `{channels['lore_fragment']}`",
        f"- Authored delivery maps: `{len(maps)}`",
        "",
        "## Verification",
        "",
        "```bash",
        "python3 tools/generate_landmark_narrative.py --check",
        "python3 tools/verify_landmark_narrative.py",
        "python3 -m unittest tests.python.test_landmark_narrative -v",
        "```",
        "",
        "## Narrative matrix",
        "",
        "| Landmark | Parent | Delivery | Stable beat | Narrative beat | Map anchor | Owner task |",
        "| --- | --- | --- | --- | --- | --- | --- |",
    ]
    for row in rows:
        anchor = row["map_anchor"]
        beat = str(row["beat"]).replace("|", "\\|")
        lines.append(
            "| {landmark} | `{parent}` ({kind}) | `{delivery}` ({channel}) | `{beat_id}` | {beat} | "
            "`{map_id}::{anchor_id}` | **{owner}** |".format(
                landmark=str(row["landmark"]).replace("|", "\\|"),
                parent=row["parent_id"],
                kind=row["integration_kind"],
                delivery=row["delivery_id"],
                channel=row["delivery_channel"],
                beat_id=row["beat_id"],
                beat=beat,
                map_id=anchor["map_id"],
                anchor_id=anchor["anchor_id"],
                owner=row["owner_task"],
            )
        )
    lines.append("")
    return "\n".join(lines)


def _serialized_outputs() -> tuple[str, str]:
    manifest = build_manifest()
    manifest_text = json.dumps(manifest, ensure_ascii=False, indent=2) + "\n"
    document_text = render_document(manifest)
    return manifest_text, document_text


def main() -> int:
    check = "--check" in sys.argv[1:]
    unknown = [arg for arg in sys.argv[1:] if arg != "--check"]
    if unknown:
        print(f"unknown argument(s): {' '.join(unknown)}", file=sys.stderr)
        return 2

    manifest_text, document_text = _serialized_outputs()
    if check:
        stale = []
        for path, expected in ((MANIFEST, manifest_text), (DOCUMENT, document_text)):
            actual = path.read_text(encoding="utf-8") if path.exists() else ""
            if actual != expected:
                stale.append(str(path.relative_to(ROOT)))
        if stale:
            print(f"stale generated landmark narrative output: {', '.join(stale)}", file=sys.stderr)
            return 1
        print("landmark narrative manifest and design matrix are up to date")
        return 0

    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(manifest_text, encoding="utf-8")
    DOCUMENT.write_text(document_text, encoding="utf-8")
    print(f"wrote {MANIFEST.relative_to(ROOT)} and {DOCUMENT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
