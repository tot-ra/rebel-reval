# generated/ classification (2026-09-09)

Status: complete for **P0-201**. Snapshot before this change: **590 tracked files / 132.3 MiB** under `generated/`. That tree is **not** uniformly removable.

## Classes

| Class | Rule | This snapshot |
|------|------|---------------|
| Runtime | Must live under `assets/` (or `music/` / `sounds/`) with provenance and `*.import` sidecars | Forge-cat production GLB, LOD1/LOD2, town coats, shared normal/roughness, Godot-extracted PBR maps. Previously loaded from `generated/comfyui/forge_cat_hunyuan3d_v1/production/` via `cat_rig.tscn` and `cat_coat_variants.gd`. |
| Indispensable rebuild input | Keep under `generated/`; command-line Blender/Python tools keep filesystem access | `pack_horse_v3/pack_horse_candidate.glb` and `pack_horse_v3.glb`; cattle/sheep/pig candidates and Hendrik Reyneke pig source; forge-cat Hunyuan candidate + `production_build.py`; burgher house briefs/reports used by Godot tests; Leonardo hay source. |
| Retained documentation / evidence | Keep; do not delete because a later export-isolation task wants a smaller clone | Bundle README/state/audit JSON, reference sheets, preview plates, licenses, music, rejected-but-cited wader candidates (`grey_heron`, `common_snipe`), `pack_horse_v2` README (checksum of removed candidate), unreferenced ComfyUI UUID PNGs without a canonical duplicate. |
| Disposable intermediate | Delete only when verified as logs, unnamed probes, or exact UUID duplicates | See Removals. |

Largest remaining `generated/` owners after this change: `medieval_animals_v1` (~42.5 MiB, rebuild candidates), forge-cat staging (~11.9 MiB after runtime move), bird reference plates, Blender preview PNGs.

## Runtime migration (forge cat)

Moved, not copied:

- `assets/characters/cat/forge_cat_production_v1.glb` (`uid://25gqsu5pgcvo`)
- `assets/characters/cat/forge_cat_lod1.glb`, `forge_cat_lod2.glb`
- `assets/characters/cat/tex/coats/*.png` and shared `forge_cat_normal.png` / `forge_cat_roughness.png`
- Godot-extracted `forge_cat_production_v1_forge_cat_{albedo,normal,roughness}.png`

`production_build.py` now writes those runtime outputs under `assets/characters/cat/` and keeps staging albedo/AO plus reports in the generated bundle. Import/export boundaries (`generated/.gdignore` or an export exclude) were **not** added: burgher tests still load `res://generated/blender/.../brief.json`, and a concurrent export-isolation task should land after this cut.

## Removals (actual clone savings)

Deleted **26 tracked files / 3,890,117 bytes (3.71 MiB)**:

- Reproducible animal/kit `*.log` under `generated/comfyui/medieval_animals_v1/production/logs/` and two Blender kit `build.log` files
- Unnamed probe dumps `generated/blender/script-e8221ead/`, `script-fd4434b4/`, `render-7d506e66/` (no repository references)
- Exact UUID duplicate of `generated/comfyui/medieval_animals_v1/pig_reference_clean.png`

Tracked `generated/` after the change: **551 files / 119.5 MiB**. The 13.4 MiB drop versus 132.3 MiB is mostly the cat runtime **move** into `assets/` (still in the clone, ~9.09 MiB of cat media). Do not claim 132.3 MiB recovered.

## Retained on purpose

- `generated/comfyui/cat_hunyuan3d/` reference plates (superseded experiment; GLB already gone; README keeps the SHA-256)
- Rejected bird candidate GLBs that audits still cite
- `pack_horse_v2` previews and README
- Unreferenced `generated/comfyui/<uuid>-1.png` dumps that are not byte-identical to a named canonical file
- All music, licenses, and dossier evidence outside this tree

## Commit-hook coverage that this change also had to land

Staging `assets/SOURCES.csv` runs whole-tree provenance and storage hygiene. HEAD already tracked Godot-extracted songbird/house/cart PNGs without manifest rows, and `build/benchmarks/r715-water-minimum.json` despite `/build/` being ignored. This commit adds derived sidecar rows for those 52 PNGs and untracks the benchmark JSON. That is hook hygiene, not a claim that those assets were classified as disposable `generated/` intermediates.

## Follow-up (not this change)

Export isolation can add `generated/.gdignore` and/or an `export_presets.cfg` exclude only after remaining `res://generated/` test loaders are switched to filesystem paths.
