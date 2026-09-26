"""Refresh the provenance rows for assets/characters/realistic/ (ADR 0022).

Only rows whose asset_id starts with `assets.characters.realistic.` are
rewritten; every other byte of assets/SOURCES.csv is preserved, and the write
retries if another writer changes the file meanwhile.

    python3 tools/assets/realistic_humans/register_sources.py
"""
import csv
import hashlib
import io
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets/characters/realistic"
MANIFEST = ROOT / "assets/SOURCES.csv"
PREFIX = "assets.characters.realistic."
MH_PACK = ("https://files2.makehumancommunity.org/asset_packs/makehuman_system_assets/"
           "makehuman_system_assets_cc0.zip (SHA-256 b542127a8e25547c7c29c19f2d1d2adb9a664c80396ecd694095dbc8028a0107)")
MPFB = "MPFB 2.0.17 (extensions.blender.org, SHA-256 4f0a879d...a87); Blender 5.2"
APPROVAL = "review candidate - ADR 0022 realistic humans; maintainer visual approval pending"


def row(path):
    rel = path.relative_to(ROOT).as_posix()
    asset_id = rel.lower().replace("/", ".").replace(" ", "_")
    digest = "SHA-256 " + hashlib.sha256(path.read_bytes()).hexdigest()
    parts = path.relative_to(OUT).parts
    if parts[0] == "textiles":
        return [asset_id, rel, "project maintainer", "tools/assets/realistic_humans/textiles.py (numpy)",
                f"Tileable {path.stem.split('_')[0]} map; {digest}", "fixed seeds in textiles.py",
                "AGPL-3.0-or-later (project author)",
                "Procedural periodic weave/grain/ring synthesis; regenerate with textiles.py.", APPROVAL]
    if parts[0] == "makehuman":
        return [asset_id, rel, "MakeHuman community (Data Collection AB, Joel Palmius, Jonas Hauquier)",
                "makehuman_system_assets_cc0", f"{MH_PACK}; {digest}", "not applicable", "CC0 1.0",
                "Copied unmodified from the CC0 system asset pack by build_human.py.", APPROVAL]
    if len(parts) > 1 and parts[1] == "textures":
        return [asset_id, rel, "project maintainer; MakeHuman CC0 base texture",
                "tools/assets/realistic_humans/surfaces.py (numpy) over MakeHuman CC0 skin/hair",
                f"{MH_PACK}; {digest}", "fixed seeds in surfaces.py",
                "AGPL-3.0-or-later (project author); derived from CC0 1.0 input",
                "Complexion, pores, wrinkles, beard/scalp strands and hair recolour computed from the "
                "fitted rest mesh; regenerate with build_human.py.", APPROVAL]
    return [asset_id, rel, "project maintainer; MPFB/MakeHuman CC0 base mesh; KayKit CC0 motion",
            MPFB, f"tools/assets/realistic_humans/specs.py; {MH_PACK}; {digest}", "deterministic spec",
            "AGPL-3.0-or-later (project); MakeHuman base mesh, targets, weights CC0 1.0; skeleton/clips CC0 1.0",
            "Body shaped by spec macros/targets, re-rigged onto the shared 41-bone rig; garments generated "
            "and fitted in-repo (garments.py).", APPROVAL]


def main():
    rows = [row(p) for p in sorted(OUT.rglob("*")) if p.suffix.lower() in (".glb", ".png")]
    buf = io.StringIO(newline="")
    csv.writer(buf, lineterminator="\n").writerows(rows)
    for _ in range(5):
        original = MANIFEST.read_bytes()
        lines = original.decode().splitlines(keepends=True)
        retained = "".join(line for line in lines if not line.startswith(PREFIX))
        result = (retained + ("" if retained.endswith("\n") else "\n") + buf.getvalue()).encode()
        if MANIFEST.read_bytes() != original:
            continue
        tmp = MANIFEST.with_name("SOURCES.realistic.tmp")
        tmp.write_bytes(result)
        if MANIFEST.read_bytes() != original:
            tmp.unlink()
            continue
        os.replace(tmp, MANIFEST)
        print("Registered", len(rows), "realistic human source rows; unrelated lines preserved.")
        return
    raise RuntimeError("Concurrent provenance edits; retry after the other writer finishes")


if __name__ == "__main__":
    main()
