# Agent file readability split plan (2026-08-13)

Goal: make EE-agent sessions cheaper and safer by shrinking the files agents must load when changing one concern. This is a **readability and ownership** plan, not a byte-storage plan. Binary/storage work remains in [`docs/STORAGE_SIZE_BACKLOG.md`](../STORAGE_SIZE_BACKLOG.md). Runtime keep/extract decisions live in [`docs/ARCHITECTURE.md`](../ARCHITECTURE.md) (P0-184).

Line counts from `wc -l` on 2026-08-13. Soft target for new/extracted helpers: under 600 lines (ideally under 400) unless the file is intentionally a pure data catalog or one facade.

## Decision rules (do not skip)

1. Over 400 lines is an **audit trigger**, not an automatic split.
2. Prefer the architecture extraction criteria (mixed change axes, second caller, merge pain).
3. Keep public facades, stable IDs, and focused regression gates in the same change.
4. Do not split parity fixtures, LFS manifests, or generated dumps just to reduce LOC.
5. Prefer the star-catalog pattern already in-tree: small data shards + thin accessor facade.

## Priority queue for EE agents

### P0 - claim as P0-185 (runtime, highest agent pain)

| Priority | File | Lines | Suggested split | Why agents struggle |
| --- | --- | --- | --- | --- |
| 1 | `scripts/map/view3d/map_view_bird_species.gd` | 1076 | Keep `MapViewBirdSpecies` accessors; move group profile tables into `map_view_bird_species_<group>.gd` shards | Almost all of the file is table data; any bird tweak loads the whole catalog |
| 2 | `scripts/map/view3d/map_view_mammal_species.gd` | 870 | Same group-table shard pattern as birds | Parallel catalog; same read cost |
| 3 | `scripts/map/view3d/map_view_tree_meshes.gd` | 1143 | Extract `_profile_for` / species profiles from wood/canopy/fruit emitters | Profile edits force agents through mesh math |
| 4 | `scripts/map/view3d/map_view_mesh_builder_prop_models.gd` | 986 | Keep `build_prop`; extract smithy kit builders and outdoor/boat/fauna branches | Unrelated prop families share one edit surface |
| 5 | `scripts/map/view3d/map_view_material_shaders.gd` | 919 | Move large inline shaders to `*.gdshader` resources; leave a thin cache loader in GDScript | Shader edits drown in multi-surface string constants (~42 KiB) |
| 6 | `scripts/map/view3d/map_view_runtime.gd` | 830 | Extract ambient installers and/or time-flow controls; keep install facade | Installers for birds/fauna/insects/crowd/music mix with time controls |

Suggested implementation order for P0-185: **1 → 2 → 5 → 3 → 4 → 6**. Data-table splits are lowest behavior risk; runtime installer peels need the strongest integration gates.

### P1 - docs agents must open often

| File | Lines / bytes | Suggested reduction | Notes |
| --- | --- | --- | --- |
| `docs/MAP_AUTHORING.md` | 948 / ~80 KiB | Split into core contract + topic annexes (`props`, `streaming`, `migration`, `rrmap`) with a short index at the top | Agents already instructed to read the head of this file; annexes keep the mandatory contract short |
| `docs/ROADMAP.md` | 366 / ~121 KiB | Execute **P0-187**: move aged coordination history into `docs/TASK_ARCHIVE.md` or a dated archive | Line count is modest; **byte size** is the problem (very long history lines) |
| `docs/HISTORICAL_AUDIT.md` | 650 | Keep as research ledger, or shard by district/year if researchers keep reloading the whole file | Not a runtime blocker |
| `docs/ARCHITECTURE.md` | refreshed | Keep the 800+ decision table hot; leave 400-599 as a compact list | Done in P0-184 |

### P2 - offline tools (edit only when regenerating assets)

| File | Lines | Suggested split |
| --- | --- | --- |
| `tools/generate_waterfowl.py` | 1173 | Shared mesh/material helpers + per-species builders |
| `tools/hero_body_head_builder.py` | 1122 | Body vs head vs material stages |
| `tools/burgher_house_kit_common.py` | 1031 | Kit vocabulary vs mesh emitters |
| `tools/generate_reval_writing_kit.py` | 960 | Shared export helpers vs prop families |
| `tools/generate_medieval_hand_tools.py` | 803 | One tool family per module |

Do not prioritize tools ahead of P0-185 unless an art pipeline task already owns that generator.

### P3 - tests that drag agent context

| File | Lines | Suggestion |
| --- | --- | --- |
| `tests/godot/test_urban_population_controller.gd` | 667 | Split by scenario family when the next population feature lands |
| `tests/python/test_validate_content.py` | 656 | Group by validator concern if adding large new cases |
| `tests/godot/test_character_rig.gd` | 654 | Pose/equipment vs locomotion suites |
| `tests/godot/test_map_view_3d_mesh.gd` | 649 | Keep as broad mesh gate; add focused sibling files for new families instead of growing this one |
| `tests/godot/test_market_prototype_maps.gd` | 609 | Per-map or per-prop-family filters |

### Explicit non-splits

- `tests/fixtures/maps/*.parity.json`, `docs/lfs_assets.json`, `docs/data/landmark_integrations.json`
- `history/**` research dumps (read via dossier index, do not fragment for agents)
- Cohesive facades/vocabularies in the 600-799 band marked **Keep** in Architecture (parser statements, `map_types`, materials facade, house catalog, etc.)

## Suggested follow-up sessions (step by step)

1. **Claim P0-185 / bird species shard** - extract one bird group table behind `MapViewBirdSpecies`; run bird mesh/audio/flight filters.
2. **Mirror mammal species shard** - same pattern; run mammal/fauna filters.
3. **Relocate material shaders** - one surface family to `*.gdshader`; keep cache API; run material + lighting filters.
4. **Tree profile extract** - profiles vs emitters; run mesh/foliage filters.
5. **Prop model peel** - smithy kits first (strong forge tests), then boats/outdoor.
6. **Runtime ambient peel** - installers behind `MapViewRuntime`; run runtime/camera/crowd/fauna filters.
7. **P0-187 ROADMAP slim** - archive coordination history to cut the ~121 KiB agent load.
8. **MAP_AUTHORING annexes** - after P0-185, split topic annexes without changing the authoring contract.

## Verification for this documentation refresh (P0-184)

```bash
# inventory matches Architecture counts
python3 - <<'PY'
from pathlib import Path
rows=[sum(1 for _ in open(p,'rb')) for p in Path('scripts').rglob('*.gd')]
print(sum(1 for n in rows if n>=400), sum(1 for n in rows if n>=600), sum(1 for n in rows if n>=800))
PY
# expect: 60 23 6  (600-band includes the six 800+ files => 17 in 600-799)

python3 tools/generate_active_docs_report.py --check
git diff --check -- docs/ARCHITECTURE.md docs/STORAGE_SIZE_BACKLOG.md docs/ROADMAP.md
```
