# Executable work

The project task board is the preferred operational queue for claims and progress.
This file remains the durable/legacy ID index expected by `README.md`, `AGENTS.md`, and active-doc link checks.

| Document | Role |
|----------|------|
| Project task board (`tasks` tool) | Claims, WIP, verification evidence |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | Current focus and coordination history |
| [`docs/TASK_ARCHIVE.md`](docs/TASK_ARCHIVE.md) | Completed legacy rows |
| [`docs/STORAGE_SIZE_BACKLOG.md`](docs/STORAGE_SIZE_BACKLOG.md) | Open storage and file-size contracts (**P0-177**..**P0-187**) |
| [`docs/CHARACTER_REALISM_BACKLOG.md`](docs/CHARACTER_REALISM_BACKLOG.md) | Character model/animation realism follow-ups (**P0-188**..**P0-198**) |
| [`docs/LEGACY_REINTRODUCTION.md`](docs/LEGACY_REINTRODUCTION.md) | ADR 0017 / P7 inventory |
<!-- Quick-reference counts updated on every structural change -->
| Priority | Open | Done | Notes |
|----------|-----:|-----:|-------|
| P0 |    14  |     8  | Baseline, storage, materials, historical audit |

## Storage and file-size (active)

See [`docs/STORAGE_SIZE_BACKLOG.md`](docs/STORAGE_SIZE_BACKLOG.md) for full deliverable/verify contracts.

- [x] P0-177 | deps: none | deliverable: repository size audit + claimable follow-ups | verify: report and backlog landed
- [x] P0-178 | deps: P0-177 | deliverable: green storage hygiene for `generated/` >=10 MiB binaries | verify: `python3 tools/verify_storage_hygiene.py`
- [x] P0-179 | deps: P0-178 | deliverable: prune rejected/duplicate `generated/comfyui` candidates | verify: hygiene + asset validators green
- [x] P0-201 | deps: P0-179 | deliverable: classify `generated/` into runtime / rebuild inputs / retained evidence / disposable intermediates; move accepted forge-cat runtime GLB, LODs, and coat maps into `assets/characters/cat/` with provenance and import UIDs; delete only verified logs, unnamed Blender probes, and one UUID duplicate PNG | allowed files: `assets/characters/cat/`, `assets/SOURCES.csv`, `assets/characters/README.md`, `generated/comfyui/forge_cat_hunyuan3d_v1/`, `generated/comfyui/medieval_animals_v1/production/logs/`, `generated/blender/script-e8221ead/`, `generated/blender/script-fd4434b4/`, `generated/blender/render-7d506e66/`, `generated/blender/medieval_lighting_kit_v1/build.log`, `generated/blender/medieval_table_kit_v1/build.log`, `generated/comfyui/893701d5-04fd-48eb-9be9-262640276b38-1-rr_medieval_pig_reference_clean_v1_00001_.png`, `tests/godot/test_cat_rig.gd`, `docs/ASSET_STORAGE_POLICY.md`, `docs/STORAGE_SIZE_BACKLOG.md`, `docs/reports/generated_classification_2026-09-09.md`, `TODO.md`, `agents/playbook.md` | constraints: keep rebuild candidates including `pack_horse_v3`; keep docs/reference/licenses/music; do not add `generated/.gdignore` (export isolation is a follow-up); do not absorb concurrent character WIP | verify: cat/fauna Godot filters; `python3 tools/validate_asset_sources.py`; `python3 tools/verify_storage_hygiene.py`; recorded generated-file and byte counts
- [ ] P0-180 | deps: P0-177 | deliverable: curated music take reduction with MusicDirector proof | verify: soundtrack tests + recorded byte drop
- [x] P0-181 | deps: P0-177 | deliverable: research-plate dimension/byte policy for `history/reference` | verify: plate fetch `--verify`
- [ ] P0-182 | deps: P0-180 | deliverable: runtime audio bitrate/size budget | verify: lint/validator + audio tests
- [ ] P0-183 | deps: P0-177 | deliverable: oversized runtime GLB budgets (oak + shared characters) | verify: asset lint + focused Godot filters
- [x] P0-184 | deps: P0-177 | deliverable: refresh ARCHITECTURE large-file audit to current LOC inventory | verify: table matches `scripts/**/*.gd`
- [ ] P0-185 | deps: P0-184 | deliverable: justified view3d hotspot extractions only | verify: named focused filters
- [x] P0-186 | deps: P0-177 | deliverable: `docs/reports/images` retention/compression rule | verify: acceptance image readers + byte drop
- [x] P0-187 | deps: P0-177 | deliverable: archive aged ROADMAP coordination notes | verify: Current focus intact + active-docs check
- [x] P0-200 | deps: P0-144,P0-145 | deliverable: share palette-neutral humanoid PBR maps across bodies and LODs via generator URI rewrite and Godot import contract without changing approved visuals | allowed files: `tools/share_character_textures.py`, `tools/generate_hero_body.py`, `tools/generate_character_lods.py`, `tools/rebuild_hero_character.sh`, `tools/register_character_texture_sources.py`, `tools/hero_body_textures.py`, `tools/generate_character_textures.py`, `tools/repair_character_orm_normals.py`, `tools/character_fidelity_tiers.py`, `tools/verify_asset_lint.py`, `assets/characters/shared/`, `assets/SOURCES.csv`, `assets/characters/README.md`, `docs/CHARACTER_GENERATION.md`, `docs/reports/character_shared_textures.md`, `tests/python/test_share_character_textures.py`, `tests/godot/test_character_rig.gd`, `tests/godot/test_asset_showcase.gd`, `TODO.md` | constraints: keep distinct AO/UV maps, material parameters, rig/animation clips and all LODs; do not delete extracted PNGs unless GLBs no longer embed them; no music/docs/reference/license removals; no visual style change | verify: `python3 tools/share_character_textures.py --verify`; character fidelity and asset lint; `--filter=test_character_rig,test_character_wardrobe,test_asset_showcase`; recorded before/after file and byte counts

## Character visual realism (active)

See [`docs/CHARACTER_REALISM_BACKLOG.md`](docs/CHARACTER_REALISM_BACKLOG.md) for full deliverable/verify contracts. Review: [`docs/reports/character_visual_realism_review_2026-08-12.md`](docs/reports/character_visual_realism_review_2026-08-12.md).

- [x] P0-188 | deps: none | deliverable: character model/animation realism review + claimable follow-ups | verify: report and backlog landed
- [ ] P0-189 | deps: P0-188 | deliverable: Godot vertex-colour albedo path for head/beard/skin tints | verify: face plates + character rig + asset lint
- [ ] P0-190 | deps: P0-189 | deliverable: soften beard cheek hard edge / fibre continuity | verify: rebuilt bodies + face plates + lint
- [ ] P0-191 | deps: P0-188 | deliverable: fix hair-shell terracing and UV-island blocks | verify: dialogue plates + lint + rig tests
- [ ] P0-192 | deps: P0-189 | deliverable: GL-Compat wrap skin + cornea/iris specular response | verify: day/night face plates + material/rig tests
- [ ] P0-193 | deps: P0-191 | deliverable: hair/beard card or layered shell inside tier caps | verify: hero/townswoman/bearded rebuild + lint
- [ ] P0-194 | deps: P0-189, P0-191 | deliverable: refresh stale full-body character closeup plates | verify: new closeup evidence replaces 2026-07-31 set
- [ ] P0-195 | deps: P0-188 | deliverable: locomotion weight/foot-plant (+ optional cape secondary) | verify: arm-swing audit + walk/run plates + rig tests
- [ ] P0-196 | deps: P0-188 | deliverable: dialogue look-at/blink/talk micro-motion without blendshapes | verify: focused Godot filter + dialogue/showcase capture
- [ ] P0-197 | deps: P0-195 | deliverable: smithy station bespoke animation pack | verify: smithy routine filters + forge station capture
- [ ] P0-198 | deps: P0-196 | deliverable: ambient NPC idle/gesture variety for Witcher-style routines | verify: four role mappings + ambient/rig tests

New major work still requires the task contract in [`AGENTS.md`](AGENTS.md): player-facing goal, allowed files, deps, constraints, deliverable, verify.
