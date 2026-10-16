#!/usr/bin/env python3
"""Build the belt-gear parts of task R-2033 from belt_gear.json and render their review views.

Parts: buckles (p1 iron, p2 latten, p3 silver-gilt), strap-ends (p2, p3), the p3
belt mount, purses (p1 leather, p2 flap pouch, p3 silk), the key bunch and the
paternoster. Raw Meshy scans live in the gitignored build/belt_gear/ (re-download
by `meshy_task` if missing; the SHA-256 checks it is the same scan). Runtime and
frame conventions: scripts/city/belt_gear.gd, docs/SYSTEMS/EQUIPMENT_VARIANTS.md.

    python3 tools/assets/equipment/belt_gear/build_belt_gear.py
    python3 tools/assets/equipment/belt_gear/build_belt_gear.py --only purse_p2_w1 --no-views
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
BLENDER = os.environ.get("BLENDER", "/Applications/Blender.app/Contents/MacOS/Blender")
VIEWS = ROOT / "tools" / "assets" / "meshy_prop" / "render_prop_views.py"


def _blender(script: Path, *args: str) -> str:
    cmd = [BLENDER, "-b", "--factory-startup", "--python", str(script), "--", *args]
    out = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, check=False)
    if out.returncode != 0 or "Traceback" in out.stdout + out.stderr:
        sys.exit(f"{script.name} failed:\n{out.stdout[-3000:]}\n{out.stderr[-3000:]}")
    return out.stdout


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--only", default="")
    p.add_argument("--no-views", action="store_true")
    a = p.parse_args()
    manifest = json.loads((HERE / "belt_gear.json").read_text())
    for item in manifest["items"]:
        if a.only and item["id"] != a.only:
            continue
        if item["source"] == "meshy":
            raw = ROOT / item["raw"]
            sha = hashlib.sha256(raw.read_bytes()).hexdigest()
            if sha != item["raw_sha256"]:
                sys.exit(f"{raw}: sha256 {sha} != manifest {item['raw_sha256']}")
        log = _blender(HERE / "normalize_belt_gear.py", json.dumps(item))
        info = json.loads(next(ln for ln in log.splitlines() if ln.startswith("BELT_GEAR ")).removeprefix("BELT_GEAR "))
        out = ROOT / item["out"]
        info["out_sha256"] = hashlib.sha256(out.read_bytes()).hexdigest()
        info["out_kib"] = out.stat().st_size // 1024
        if not a.no_views:
            _blender(VIEWS, "--glb", str(out), "--out", str(ROOT / "build" / "belt_gear" / "views" / f"{item['id']}.png"),
                     "--px", "300")
        print(json.dumps(info))


main()
