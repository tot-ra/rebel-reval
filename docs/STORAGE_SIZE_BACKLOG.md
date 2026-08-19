# Storage and file-size backlog

Durable claimable contracts produced by the 2026-08-11 repository size audit.
Promote each open row to the project task board before claiming implementation.
ID index also listed in [`TODO.md`](../TODO.md).
Evidence report: [`docs/reports/repository_size_audit_2026-08-11.md`](reports/repository_size_audit_2026-08-11.md).

Format matches the legacy `TODO.md` contract: `ID | deps | deliverable | verify`.

## Closed in this audit

- [x] P0-177 | deps: none | deliverable: repository size audit report listing binary and source hotspots, hygiene failure evidence, and claimable follow-ups P0-178..P0-187 without deleting assets in-row | verify: `docs/reports/repository_size_audit_2026-08-11.md` and this backlog exist; `python3 tools/generate_active_docs_report.py --check` passes after active-doc registration if required

## Open - storage / binary size

- [ ] P0-178 | deps: P0-177 | role: production/dev | deliverable: restore green `python3 tools/verify_storage_hygiene.py` by removing, LFS-migrating, or externally relocating every tracked standard-Git binary at least 10 MiB under `generated/` (first offender: `generated/comfyui/bird_wader_v1/candidates/northern_lapwing_hunyuan_candidate.glb`); update `docs/lfs_assets.json` / policy text if LFS is chosen; do not add a new standard-Git exception | verify: `python3 tools/verify_storage_hygiene.py` exits 0; `python3 tools/manage_lfs_assets.py verify` exits 0 if LFS rows changed; rejected candidate audits still cite reachable evidence or an explicit external retrieval path

- [ ] P0-179 | deps: P0-178 | role: art/production | deliverable: prune tracked `generated/comfyui/**` rejected Hunyuan candidates and exact UUID duplicate dumps already marked rejected in fauna audits; keep only manifests, scripts, and one retained artifact per experiment when still required for reproduction; document retention rule in `docs/ASSET_STORAGE_POLICY.md` or art pipeline doc | verify: no rejected candidate GLB over 5 MiB remains tracked without LFS/external row; duplicate same-size UUID pairs listed in the audit are gone; `python3 tools/validate_asset_sources.py` and hygiene validators stay green; runtime `assets/**` unchanged

- [ ] P0-180 | deps: P0-177 | role: art/dev | deliverable: curated soundtrack take list - for each MusicDirector theme directory and hard-coded track, keep only the authored playlist set; move unused alternate takes (including unreferenced `(N)` files) to `archive/music/` LFS-skip or delete with provenance updates; sync `assets/SOURCES.csv` and `docs/data/slice_soundtrack_manifest.json` | verify: `MusicDirector` / soundtrack tests pass; every remaining `music/**/*.mp3` is referenced by code, a theme directory scan used in runtime, or an explicit retained-library note; working-tree `music/` byte total drops versus the 2026-08-11 baseline (~722 MiB) with a recorded before/after figure

- [ ] P0-181 | deps: P0-177 | role: research/production | deliverable: research-plate byte policy (max long edge and JPEG quality) applied to `history/reference/**` outliers over 8 MiB; re-fetch or recompress while preserving dossier readability; update `plates.csv` checksums/bytes and LFS manifest rows | verify: `python3 tools/research/fetch_reference_plates.py --verify` passes; no `history/reference/**` raster over the new byte/dimension cap remains without an owned exception; dossier solid statuses unchanged

- [ ] P0-182 | deps: P0-180 | role: art/dev | deliverable: runtime audio bitrate/size budget for `music/` and `sounds/` (encode ceiling plus per-file soft cap); recompress or replace outliers including `sounds/birds/great_spotted_woodpecker/great_spotted_woodpecker_XC995604.mp3`; refresh LFS manifests and provenance | verify: budget documented and enforced by a validator or lint hook; no runtime audio file exceeds the cap without exception; bird audio and music director tests pass

- [ ] P0-183 | deps: P0-177 | role: art | deliverable: runtime mesh byte and triangle budgets for oversized GLBs, starting with `assets/props/environment/sacred_grove_ancient_oak.glb` (~9.5 MiB) and the ~5 MiB `assets/characters/shared/*.glb` set; reduce or LOD without breaking silhouette contracts; enforce through `tools/verify_asset_lint.py` / fidelity tiers | verify: `python3 tools/verify_asset_lint.py` green for touched assets; focused bird/character/prop Godot filters covering those assets pass; sizes recorded before/after

- [ ] P0-186 | deps: P0-177 | role: qa/production | deliverable: evidence-image retention rule for `docs/reports/images/**` (~101 MiB PNG today) - compress closed-task captures, convert where lossless is unnecessary, or LFS-skip archival plates while keeping current-slice acceptance images local | verify: current-slice acceptance commands that read report images still pass; docs/reports byte total drops with a recorded before/after; `.gdignore` / LFS policy remains coherent

## Closed - source / documentation size

- [x] P0-184 | deps: P0-177 | role: dev | deliverable: refresh `docs/ARCHITECTURE.md` large-runtime-file audit table to the current inventory (61 scripts over 400 lines, list every file over 800 lines) with keep/extract decisions and regression gates; no behavior change required in-row | verify: architecture section matches `wc -l` on `scripts/**/*.gd`; `python3 tools/generate_active_docs_report.py --check` passes | closed: 2026-08-19 inventory 61 / 18 / 6 over 400 / 600 / 800; EE-agent split queue in `docs/reports/agent_file_readability_split_plan_2026-08-13.md`

## Open - source / documentation size

- [ ] P0-185 | deps: P0-184 | role: dev | deliverable: justified extractions only for view3d hotspots that fail the architecture extraction criteria, prioritized among `map_view_bird_species.gd`, `map_view_mammal_species.gd`, `map_view_material_shaders.gd`, `map_view_tree_meshes.gd`, `map_view_mesh_builder_prop_models.gd`, and `map_view_runtime.gd` (see readability report order); keep public facades and stable IDs | verify: focused Godot filters named in the architecture row pass; full map/view suites relevant to touched files pass; each extracted file is under the agreed soft cap or has an explicit keep decision

- [x] P0-187 | deps: P0-177 | role: production | deliverable: move aged `docs/ROADMAP.md` coordination-history notes into `docs/TASK_ARCHIVE.md` or a dated ROADMAP archive so the live roadmap stays focused on Current focus plus recent notes; do not drop open dependency pointers | verify: Current focus section remains accurate; archived notes remain linkable; `python3 tools/generate_active_docs_report.py --check` passes; `docs/ROADMAP.md` shrinks versus the 119 KiB / 360-line 2026-08-11 baseline

## Non-goals for this backlog

- History rewrite / `git filter-repo` to purge old blobs (needs a separate maintainer ADR).
- Deleting research PDFs without an external retrieval contract.
- Splitting parity fixtures or generated LFS manifests purely to reduce line count.
- Broad refactors unrelated to the named hotspots.
