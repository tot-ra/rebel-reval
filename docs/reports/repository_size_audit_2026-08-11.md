# Repository size audit (2026-08-11)

Status: complete inventory for claimable follow-ups **P0-177** through **P0-187**.
Executable contracts live in [`docs/STORAGE_SIZE_BACKLOG.md`](../STORAGE_SIZE_BACKLOG.md).
Policy baseline remains [`docs/ASSET_STORAGE_POLICY.md`](../ASSET_STORAGE_POLICY.md).

## Snapshot

Working tree walk (excluding `.git`, `.godot`, `bin/`, `build/`):

| Metric | Value |
|--------|------:|
| Total files | 7,579 |
| Total bytes | 2.11 GiB |
| Tracked `generated/` | 498 files / 200.1 MiB |
| Tracked `docs/reports/` | 547 files / 103.0 MiB |
| `python3 tools/verify_storage_hygiene.py` | **FAIL** (see Critical) |

### Top-level owners (all files on disk)

| Path | Approx size |
|------|------------:|
| `music/` | 722 MiB |
| `history/` | 509 MiB |
| `archive/` | 201 MiB |
| `generated/` | 200 MiB |
| `assets/` | 200 MiB |
| `docs/` | 105 MiB |
| `sounds/` | 76 MiB |
| `story/` | 45 MiB |
| `scripts/` | 2.7 MiB |

Binary extensions with individual files over 500 KiB dominate clone cost: `.mp3` (~928 MiB across 200 files), `.jpg` (~356 MiB), `.png` (~286 MiB), `.glb` (~272 MiB), `.pdf` (~135 MiB).

## Critical findings

1. **Storage hygiene is red today.** `verify_storage_hygiene.py` rejects `generated/comfyui/bird_wader_v1/candidates/northern_lapwing_hunyuan_candidate.glb` (12.67 MiB) as a standard-Git binary at least 10 MiB without an exception. `generated/` has **zero** rows in `docs/lfs_assets.json`.
2. **Rejected Hunyuan candidates remain tracked.** Audits already reject wader/waterfowl/gull candidates for production, yet large candidate GLBs stay in Git under `generated/comfyui/**`.
3. **Exact duplicate candidate pairs** (same byte size, UUID-named copy plus canonical name) waste at least ~27 MiB before deeper content hashing.
4. **Architecture line-count audit is stale.** `docs/ARCHITECTURE.md` still describes 18 runtime scripts over 400 lines (2026-07-21). Current `scripts/**/*.gd` count is **60** over 400, **22** over 600, **6** over 800.

## Binary hotspots (reduce clone / LFS cost)

### Music (`music/` ~722 MiB)

- 131 MP3 files; many district playlists keep alternate takes named `Track (1).mp3`, `Track (2).mp3`, etc. (48 files / ~272 MiB with `(N)` in the filename).
- Runtime does use some numbered takes (`MusicDirector` hard-codes `Apothecary (8).mp3`; theme dirs scan whole folders). Prune must be reference-aware, not filename-regex-only.
- Duplicate archive copies also live under `archive/music/` (~147 MiB of large files).

### History research (`history/` ~509 MiB)

- Root AVE PDFs (~134 MiB) plus `history/reference/` plates (~345 MiB).
- Several plates are 12-26 MiB JPEGs (for example `power.jurisdictions-of-reval.02.jpg` at 25.67 MiB). LFS skip-by-default already limits normal clone fetch, but working trees that restore research scope still pay full cost.
- Need a max dimension / JPEG quality policy before mass recompression.

### Generated art pipeline (`generated/` ~200 MiB tracked)

- Not ignored by `.gitignore` (only `generated/**/*.import` is ignored).
- Contains rejected Hunyuan candidates, UUID-prefixed ComfyUI dumps, and Blender previews.
- Highest leverage cleanup after hygiene fix: drop rejected candidates and UUID duplicates; keep only provenance-needed manifests and one retained candidate per accepted experiment when still required for audit reproduction.

### Runtime assets (`assets/` large GLBs)

| File | Size | Note |
|------|-----:|------|
| `assets/props/environment/sacred_grove_ancient_oak.glb` | 9.52 MiB | Landmark hingepuu; near 10 MiB LFS threshold |
| `assets/characters/shared/*.glb` (heroic set) | ~5.2-5.5 MiB each | Multiple named NPC / shared rig exports |
| `assets/UI/estonia_world_map.png` | 2.95 MiB | UI raster |

### Evidence captures (`docs/reports/` ~103 MiB)

- Almost all weight is PNG evidence under `docs/reports/images/` (~101 MiB). Useful for acceptance, but old closed tasks can move to LFS-skip or compressed WebP/JPEG with a retention rule.

### Sounds

- One outlier raw bird take: `sounds/birds/great_spotted_woodpecker/great_spotted_woodpecker_XC995604.mp3` at 10.02 MiB (already at/above LFS threshold class).

## Source / doc hotspots (reduce edit friction, not clone GiB)

These are small in bytes but expensive for agents and reviewers.

| File | Lines | Class |
|------|------:|-------|
| `docs/data/landmark_integrations.json` | 4376 | Generated-ish data table |
| `docs/lfs_assets.json` | 3102 | Manifest (expected to grow with LFS) |
| `tests/fixtures/maps/lower_town_slice.parity.json` | 3045 | Parity fixture (do not hand-trim) |
| `assets/SOURCES.csv` | 1143 / 547 KiB | Provenance manifest |
| `docs/ROADMAP.md` | 360 / 119 KiB | Coordination history dominates |
| `docs/MAP_AUTHORING.md` | 938 | Active contract |
| `docs/HISTORICAL_AUDIT.md` | 650 | Active audit |
| `scripts/map/view3d/map_view_tree_meshes.gd` | 1143 | Runtime catalog |
| `scripts/map/view3d/map_view_bird_species.gd` | 1076 | Runtime catalog |
| `scripts/map/view3d/map_view_mesh_builder_prop_models.gd` | 986 | Runtime builder |
| `scripts/map/view3d/map_view_material_shaders.gd` | 919 | Shader/string catalog |
| `scripts/map/view3d/map_view_mammal_species.gd` | 870 | Runtime catalog |
| `scripts/map/view3d/map_view_runtime.gd` | 830 | Integration facade |
| `tools/generate_waterfowl.py` | 1173 | Offline generator |
| `tools/hero_body_head_builder.py` | 1122 | Offline builder |

`scripts/map/view3d/` alone is ~35k lines across 121 GDScript files.

Per [`docs/ARCHITECTURE.md`](../ARCHITECTURE.md), a line count over 400 is an **audit trigger**, not an automatic split. Prefer extraction only when a file mixes independent reasons to change or when a second caller needs a pure table/helper.

## What not to do

- Do not rewrite Git history to reclaim old blobs unless a maintainer explicitly opens that ADR-backed task.
- Do not delete research plates or soundtrack takes without provenance/`SOURCES.csv` and runtime reference checks.
- Do not hand-edit parity fixtures or giant `MapDefinition` factories to "make LOC look better".
- Do not invent a second storage policy; extend `ASSET_STORAGE_POLICY.md` and the existing validators.

## Recommended delivery order

1. **P0-178** - make storage hygiene green (unblock CI honesty).
2. **P0-179** - prune rejected/duplicate `generated/comfyui` candidates.
3. **P0-180** - curated music take reduction with MusicDirector/manifest proof.
4. **P0-181** / **P0-182** - research plate and runtime audio byte budgets.
5. **P0-183** - oversized runtime GLB budgets (art + lint).
6. **P0-184** / **P0-185** - refresh architecture audit, then justified view3d splits.
7. **P0-186** / **P0-187** - evidence-image and ROADMAP history slim-downs.

## Verification used for this report

```bash
python3 tools/verify_storage_hygiene.py
# failed on generated/comfyui/.../northern_lapwing_hunyuan_candidate.glb

python3 - <<'PY'
# working-tree size rollups and line-count inventories (session script)
PY
```

Exact task contracts and verify lines: [`docs/STORAGE_SIZE_BACKLOG.md`](../STORAGE_SIZE_BACKLOG.md).
