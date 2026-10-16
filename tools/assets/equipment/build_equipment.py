#!/usr/bin/env python3
"""Build equipment variants from their manifests and render the review turntables.

Pipeline: docs/SYSTEMS/EQUIPMENT_VARIANTS.md (task R-2003). The raw Meshy GLB
lives in a gitignored build/ folder; the manifest keeps its SHA-256 so a
re-download from Meshy (by task id) is checked to be the same scan.

    python3 tools/assets/equipment/build_equipment.py tools/assets/equipment/items/spear_p1_w1.json
    python3 tools/assets/equipment/build_equipment.py tools/assets/equipment/items/*.json --no-turntable

Turntables go to docs/reports/images/equipment/<variant>_turntable.png (whole
item) and, with "turntable_detail_y" in the manifest, <variant>_detail.png.
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
SHEETS = ROOT / "docs" / "reports" / "images" / "equipment"


def _blender(script: str, *args: str) -> str:
    cmd = [BLENDER, "-b", "--factory-startup", "--python", str(HERE / script), "--", *args]
    out = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, check=False)
    if out.returncode != 0 or "Traceback" in out.stdout + out.stderr:
        sys.exit(f"{script} failed:\n{out.stdout[-3000:]}\n{out.stderr[-3000:]}")
    return out.stdout


def build(manifest_path: Path, turntable: bool) -> dict:
    m = json.loads(manifest_path.read_text())
    raw = ROOT / m["raw"]
    sha = hashlib.sha256(raw.read_bytes()).hexdigest()
    if sha != m["raw_sha256"]:
        sys.exit(f"{raw}: sha256 {sha} != manifest {m['raw_sha256']}")
    log = _blender("cleanup_equipment.py", "--manifest", str(manifest_path))
    info = json.loads(next(ln for ln in log.splitlines() if ln.startswith("EQUIPMENT ")).removeprefix("EQUIPMENT "))
    out = ROOT / m["out"]
    info["out_sha256"] = hashlib.sha256(out.read_bytes()).hexdigest()
    info["out_kib"] = out.stat().st_size // 1024
    if turntable:
        _blender("render_turntable.py", "--glb", str(out), "--out", str(SHEETS / f"{m['variant']}_turntable.png"))
        if m.get("turntable_detail_y"):
            lo, hi = m["turntable_detail_y"]
            _blender(
                "render_turntable.py", "--glb", str(out),
                "--out", str(SHEETS / f"{m['variant']}_detail.png"),
                "--frame-y", f"{lo},{hi}", "--tile", "220x420",
            )
    return info


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("manifests", nargs="+")
    p.add_argument("--no-turntable", action="store_true")
    a = p.parse_args()
    for path in a.manifests:
        print(json.dumps(build(Path(path), not a.no_turntable)))


main()
