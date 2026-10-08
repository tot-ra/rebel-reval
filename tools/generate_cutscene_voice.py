#!/usr/bin/env python3
"""Generate the cutscene narration with ElevenLabs Eleven v4 through OpenRouter.

For every line in content/cutscenes/*.json this writes
assets/audio/cutscene_voice/<sequence>/<shot>_<line>.mp3, sets the line's `voice` field,
and adds an assets/SOURCES.csv row. Existing mp3 files are kept (re-run is free); pass
--force to regenerate, or --only <cutscene id fragment> to limit the run.

The API key comes from OPENROUTER_API_KEY, or from the OpenRouter provider entry in the
Brute/Caesar config (~/.local/share/aagent/config.json). It is never printed or stored.

Tuning lives in the VOICE and audio-tag constants below. Eleven v4 is steered by inline
[audio tags] in the input text (CINEMATIC plus a per-line emotion), not by numeric knobs.
"""
from __future__ import annotations

import argparse
import csv
import json
import os
import sys
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CUTSCENES = ROOT / "content" / "cutscenes"
OUT_ROOT = ROOT / "assets" / "audio" / "cutscene_voice"
SOURCES_CSV = ROOT / "assets" / "SOURCES.csv"
ENDPOINT = "https://openrouter.ai/api/v1/audio/speech"
MODEL = "elevenlabs/eleven-v4"

# WHY short tags: long descriptive tags ([..., a quiet vengeful edge]) made v4 read the words
# aloud and stutter the first phrase, so each tag is one short, standard word.
# WHY audio tags: Eleven v4 is steered by inline [tags] in the input text, not by numeric
# knobs. Every take opens with CINEMATIC (the register: a film-trailer documentary
# narrator with weight), followed by a per-line emotion tag. The tags are sent to the
# model only; the game never shows them (the text on screen stays in the cutscene JSON).
# The story is a hard history of conquest told with a grudge, then turns hopeful once it
# reaches the boy, so the emotion moves from sorrow and restrained vengeance to warmth.
VOICE = "brian"
CINEMATIC = "[dramatic]"
HEAVY = "[sorrowful]"
DEFIANT = "[bitter]"
# (cutscene id, shot, line) -> emotion tag; anything not listed falls back by sequence below.
LINE_OVERRIDES = {
    ("cutscene.prologue.conquest", "s05_tax", "l2"): DEFIANT,
}
# Only these sequences are voiced. The conquest prologue is a narrator telling history; from
# spring 1343 on the story is "now" and plays without a voice-over (maintainer decision).
SEQUENCE_DEFAULTS = {"cutscene.prologue.conquest": HEAVY}


def settings_for(cutscene_id: str, shot_id: str, line_id: str) -> str:
    return LINE_OVERRIDES.get((cutscene_id, shot_id, line_id)) or SEQUENCE_DEFAULTS.get(cutscene_id, HEAVY)


def api_key() -> str:
    key = os.environ.get("OPENROUTER_API_KEY", "")
    if key:
        return key
    config = Path.home() / ".local" / "share" / "aagent" / "config.json"
    try:
        return json.loads(config.read_text(encoding="utf-8"))["providers"]["openrouter"]["api_key"]
    except (OSError, KeyError, ValueError):
        sys.exit("No OpenRouter key: set OPENROUTER_API_KEY or configure it in Brute.")


def synthesize(key: str, text: str, tag: str) -> bytes:
    body = {
        "model": MODEL,
        "input": f"{CINEMATIC} {tag} {text}",
        "voice": VOICE,
        "response_format": "mp3",
    }
    request = urllib.request.Request(
        ENDPOINT,
        json.dumps(body).encode("utf-8"),
        {"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=300) as response:
            data = response.read()
    except urllib.error.HTTPError as error:
        sys.exit(f"OpenRouter {error.code}: {error.read()[:300]!r}")
    if not data.startswith((b"ID3", b"\xff\xfb", b"\xff\xf3", b"\xff\xf2")):
        sys.exit(f"Response is not mp3: {data[:200]!r}")
    return data


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--force", action="store_true", help="regenerate existing files")
    parser.add_argument("--only", default="", help="substring of the cutscene id")
    args = parser.parse_args()
    key = api_key()

    jobs = []  # (record path, record, shot, line, mp3 path)
    records = {}
    for path in sorted(CUTSCENES.glob("cutscene.*.json")):
        record = json.loads(path.read_text(encoding="utf-8"))
        if args.only not in record["id"] or record["id"] not in SEQUENCE_DEFAULTS:
            continue
        records[path] = record
        folder = record["id"].removeprefix("cutscene.").replace(".", "_")
        for shot in record["shots"]:
            for line in shot["lines"]:
                jobs.append((path, shot, line, OUT_ROOT / folder / f"{shot['id']}_{line['id']}.mp3", settings_for(record['id'], shot['id'], line['id'])))

    def run(job):
        _, _, line, target, setting = job
        if target.exists() and not args.force:
            return
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(synthesize(key, line["text"], setting))
        print("generated", target.relative_to(ROOT), flush=True)

    with ThreadPoolExecutor(max_workers=4) as pool:
        list(pool.map(run, jobs))

    for path, shot, line, target, _ in jobs:
        line["voice"] = "res://" + target.relative_to(ROOT).as_posix()
    for path, record in records.items():
        path.write_text(json.dumps(record, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    with SOURCES_CSV.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.reader(handle))
    header = rows[0]
    # Drop stale voice rows so a retune is reflected in the recorded settings.
    regenerated = {t.relative_to(ROOT).as_posix() for _, _, _, t, _ in jobs}
    kept = [r for r in rows if not (len(r) > 1 and r[1] in regenerated)]
    known: set[str] = set()
    added = 0
    with SOURCES_CSV.open("w", encoding="utf-8", newline="") as handle:
        csv.writer(handle, lineterminator="\n").writerows(kept)
    with SOURCES_CSV.open("a", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        for _, shot, line, target, setting in jobs:
            rel = target.relative_to(ROOT).as_posix()
            if rel in known:
                continue
            asset_id = "assets.audio.cutscene_voice." + rel.split("/cutscene_voice/")[1].removesuffix(".mp3").replace("/", ".")
            row = dict.fromkeys(header, "")
            row.update(
                asset_id=asset_id,
                path=rel,
                creator_or_tool="ElevenLabs Eleven v4 via OpenRouter",
                model_version=MODEL,
                prompt_or_url=f"voice={VOICE}; tags={CINEMATIC} {setting}; text: {line['text']}",
                seed="not applicable",
                license="AGPL-3.0-or-later (project author)",
                edits="Generated mp3, unedited.",
                approval="draft - R-1331 narration awaiting maintainer listen-through",
            )
            writer.writerow([row[name] for name in header])
            added += 1
    print(f"{len(jobs)} lines, {added} new SOURCES rows")


if __name__ == "__main__":
    main()
