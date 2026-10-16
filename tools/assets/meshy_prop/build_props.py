#!/usr/bin/env python3
"""Normalize every raw Meshy prop in a manifest and render its review sheet.

Skill: agents/rebel-art/skills/meshy-prop/SKILL.md. The raw GLBs live in the
gitignored raw_dir (re-download them from Meshy by task id if missing; the
manifest keeps each SHA-256 to confirm it is the same scan).

    python3 tools/assets/meshy_prop/build_props.py tools/assets/meshy_prop/beds.json
    python3 tools/assets/meshy_prop/build_props.py tools/assets/meshy_prop/beds.json --only cradle_rocking
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
BLENDER = os.environ.get("BLENDER", "/Applications/Blender.app/Contents/MacOS/Blender")


def _blender(script: str, *args: str) -> str:
    cmd = [BLENDER, "-b", "--factory-startup", "--python", str(HERE / script), "--", *args]
    out = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, check=False)
    if out.returncode != 0 or "Traceback" in out.stdout + out.stderr:
        sys.exit(f"{script} failed:\n{out.stdout[-3000:]}\n{out.stderr[-3000:]}")
    return out.stdout


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("manifest")
    p.add_argument("--only", default="")
    a = p.parse_args()
    manifest = json.loads(Path(a.manifest).read_text())
    raw_dir = ROOT / manifest["raw_dir"]
    out_dir = ROOT / manifest["out_dir"]
    for prop in manifest["props"]:
        if a.only and prop["id"] != a.only:
            continue
        raw = raw_dir / f"{prop['id']}.glb"
        sha = hashlib.sha256(raw.read_bytes()).hexdigest()
        if sha != prop["raw_sha256"]:
            sys.exit(f"{raw}: sha256 {sha} != manifest {prop['raw_sha256']}")
        out = out_dir / prop["id"] / f"{prop['id']}.glb"
        log = _blender(
            "normalize_meshy_prop.py",
            "--in", str(raw),
            "--out", str(out),
            "--size", ",".join(str(v) for v in prop["size"]),
            "--yaw", str(prop["yaw"]),
            "--tris", str(prop["tris"]),
        )
        line = next(ln for ln in log.splitlines() if ln.startswith("NORMALIZED "))
        info = json.loads(line.removeprefix("NORMALIZED "))
        _blender(
            "render_prop_views.py",
            "--glb", str(out),
            "--out", str(raw_dir / "views" / f"{prop['id']}_runtime.png"),
            "--px", "300",
        )
        print(
            f"{prop['id']}: tris {info['out_tris']} size {info['godot_size_xyz']} "
            f"top_h {info['top_h']} -> {out.relative_to(ROOT)} ({out.stat().st_size // 1024} KiB)"
        )


main()
