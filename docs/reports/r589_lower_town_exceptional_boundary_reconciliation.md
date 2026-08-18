# R-589 / P0-101 exceptional landmark boundary reconciliation

**Verification date:** 2026-08-19
**Map:** `lower_town_slice` / Workers' District
**Parent:** R-108 / P0-101
**Decision:** **BLOCKED for final 1343 silhouette acceptance; PASS for source and renderer-boundary reconciliation.**

## Scope and decision

This bounded ledger reconciles the current Lower Town exceptional and fortification boundary. It is verification-only. It does not author meshes, alter stable IDs, change map geometry, weaken boundary assertions, or assign human canon/art approval.

The current source contains 99 authored records with 99 unique stable IDs: 97 `building` records and 2 `landmark gate_arch` records. The 48-row non-ordinary boundary set below remains present exactly once. Eight newer rear/service records are current ordinary/service source additions and are intentionally outside this exceptional ledger:

- `saddlers_rear_workshop`
- `coopers_rear_workshop`
- `sauna_rear_boda`
- `rope_makers_rear_store`
- `karja_rear_boda`
- `brewery_rear_store`
- `smithy_rear_shed`
- `carriers_barn`

The source and focused contracts prove ownership and routing boundaries only. They do not prove a production-complete 1343 silhouette, route-scale readability, matched day/night evidence, or human historical/art approval. R-488 remains `in_progress`, R-492 remains `in_review` with no named human canon or art reviewer, and R-533 is `done` for structural verification while preserving its visual/history blocker.

## Boundary rules

- `st_catherines_church` is a `kind=house` source record, but the exceptional registry resolves it to `church`; `build_exceptional_building()` delegates to the dedicated church renderer. It is not ordinary-house coverage.
- All `kind=wall` records, including the Viru towers and jambs, return an empty category from `MapViewMeshBuilderBuildingRegistry.exceptional_category()`. They stay on the wall-aware building path, with fortification, tower, wall-walk, sealed-wall, and fence semantics owned by that path.
- `viru_gate_arch` and `viru_foregate_arch` are `kind=gate_arch` view landmarks. `build_landmark()` delegates to `_add_gate_arch()`. They add visual bridge, jamb, leaves, and grille geometry only; collision and navigation remain owned by the authored wall/tower/jamb records.
- The nine other special/use-site houses are intentionally listed as non-ordinary boundary records even though they use the default building path. They remain untiered and must not be promoted to ordinary-house visual acceptance without an owning decision.

## Stable-ID reconciliation matrix

`Source artifact` gives the current authored line. `Renderer path` identifies the implementation boundary. `Historical/art state` and `Route-scale evidence` are acceptance states, not claims that source or contract evidence is visual approval. Every row remains blocked until the required matched gameplay-scale evidence and named human review exist.

| Stable ID | Surface class | Renderer path | Source artifact | Historical/art review state | Route-scale evidence state | Owner / next action |
|---|---|---|---|---|---|---|
| `monastery_cloister` | special/use-site house | `MapViewMeshBuilderBuildings.build_building()` -> default untiered house path | `content/maps/lower_town_slice.rrmap:169` | **BLOCKED** - no named 1343 silhouette review | **BLOCKED** - no stable-ID matched day/night approach observation | R-488/R-492; implement, capture, and review without ordinary substitution |
| `monastery_barn` | special/use-site house | `build_building()` -> default untiered house path | `content/maps/lower_town_slice.rrmap:173` | **BLOCKED** - service mass not human-reviewed | **BLOCKED** - no stable-ID route-scale observation | R-488/R-492 |
| `guild_storehouse` | special/use-site house | `build_building()` -> default untiered house path | `content/maps/lower_town_slice.rrmap:187` | **BLOCKED** - storage mass not human-reviewed | **BLOCKED** - no stable-ID route-scale observation | R-488/R-492 |
| `public_bathhouse` | special/use-site house | `build_building()` -> default untiered house path | `content/maps/lower_town_slice.rrmap:204` | **BLOCKED** - bathhouse silhouette not human-reviewed | **BLOCKED** - no stable-ID route-scale observation | R-488/R-492 |
| `karja_gate_house` | special/use-site house | `build_building()` -> default untiered house path | `content/maps/lower_town_slice.rrmap:210` | **BLOCKED** - gate-side use-site not human-reviewed | **BLOCKED** - no stable-ID route-scale observation | R-488/R-492 |
| `foaming_mug_brewery` | special/use-site house | `build_building()` -> default untiered house path | `content/maps/lower_town_slice.rrmap:218` | **BLOCKED** - production mass not human-reviewed | **BLOCKED** - no stable-ID route-scale observation | R-488/R-492 |
| `kalev_smithy` | special/use-site house | `build_building()` -> default untiered house path | `content/maps/lower_town_slice.rrmap:219` | **BLOCKED** - smithy silhouette not human-reviewed | **BLOCKED** - no stable-ID route-scale observation | R-488/R-489/R-492 |
| `muurivahe_house_north` | special/use-site house | `build_building()` -> default untiered house path | `content/maps/lower_town_slice.rrmap:224` | **BLOCKED** - wall-adjacent special boundary not human-reviewed | **BLOCKED** - no stable-ID route-scale observation | R-488/R-492 |
| `south_apron_wall_walk_hut` | special/use-site house | `build_building()` -> default untiered house path | `content/maps/lower_town_slice.rrmap:225` | **BLOCKED** - service/wall-walk relationship not human-reviewed | **BLOCKED** - no stable-ID route-scale observation | R-488/R-492 |
| `st_catherines_church` | exceptional church house | registry `church` -> `build_exceptional_building()` -> `MapViewMeshBuilderChurches.build_st_catherines_church()` | `content/maps/lower_town_slice.rrmap:168`; `scripts/map/view3d/map_view_mesh_builder_churches.gd:21` | **BLOCKED** - R-492 has no named human canon/art reviewer | **BLOCKED** - no church-specific stable-ID day/night approach pair | R-488/R-492; provide dated 1343 silhouette and route-scale review |
| `viru_gate_north_tower` | collision-bearing inner-gate fortification | `build_building()` -> `kind=wall` fortification/round-tower path; excluded by exceptional registry | `content/maps/lower_town_slice.rrmap:133` | **BLOCKED** - no named 1343 fortification review | **BLOCKED** - no stable-ID tower approach observation | R-488/R-492; preserve wall-walk `z` and `tower=false` state |
| `viru_gate_south_tower` | collision-bearing inner-gate fortification | `build_building()` -> `kind=wall` fortification/round-tower path; excluded by exceptional registry | `content/maps/lower_town_slice.rrmap:134` | **BLOCKED** - no named 1343 fortification review | **BLOCKED** - no stable-ID tower approach observation | R-488/R-492; preserve wall-walk `z` and `tower=false` state |
| `viru_gate_north_jamb` | collision-bearing inner-gate jamb | `build_building()` -> wall-aware path; excluded by exceptional registry | `content/maps/lower_town_slice.rrmap:137` | **BLOCKED** - no named gate-opening review | **BLOCKED** - no stable-ID opening/clearance observation | R-488/R-489/R-492 |
| `viru_gate_south_jamb` | collision-bearing inner-gate jamb | `build_building()` -> wall-aware path; excluded by exceptional registry | `content/maps/lower_town_slice.rrmap:139` | **BLOCKED** - no named gate-opening review | **BLOCKED** - no stable-ID opening/clearance observation | R-488/R-489/R-492 |
| `viru_gate_arch` | view-only inner-gate landmark | `MapViewMeshBuilderLandmarks.build_landmark()` -> `_add_gate_arch()`; no collision/navigation | `content/maps/lower_town_slice.rrmap:240`; `scripts/map/view3d/map_view_mesh_builder_landmarks.gd:42` | **BLOCKED** - ironbound/portcullis 1343 presentation not human-reviewed | **BLOCKED** - packet has route context but no stable-ID arch/jamb annotation | R-488/R-489/R-492; review against both inner jambs |
| `foregate_wall_north` | collision-bearing foregate wall | `build_building()` -> wall-aware path; excluded by exceptional registry | `content/maps/lower_town_slice.rrmap:140` | **BLOCKED** - incomplete 1343 foregate state not human-reviewed | **BLOCKED** - no stable-ID foregate observation | R-488/R-492 |
| `foregate_wall_south` | collision-bearing foregate wall | `build_building()` -> wall-aware path; excluded by exceptional registry | `content/maps/lower_town_slice.rrmap:141` | **BLOCKED** - incomplete 1343 foregate state not human-reviewed | **BLOCKED** - no stable-ID foregate observation | R-488/R-492 |
| `foregate_tower_north` | collision-bearing foregate fortification | `build_building()` -> wall-aware round-tower path; excluded by exceptional registry | `content/maps/lower_town_slice.rrmap:144` | **BLOCKED** - subordinate tower state not human-reviewed | **BLOCKED** - no stable-ID tower observation | R-488/R-492 |
| `foregate_tower_south` | collision-bearing foregate fortification | `build_building()` -> wall-aware round-tower path; excluded by exceptional registry | `content/maps/lower_town_slice.rrmap:145` | **BLOCKED** - subordinate tower state not human-reviewed | **BLOCKED** - no stable-ID tower observation | R-488/R-492 |
| `foregate_north_jamb` | collision-bearing foregate jamb | `build_building()` -> wall-aware path; excluded by exceptional registry | `content/maps/lower_town_slice.rrmap:146` | **BLOCKED** - no named foregate-opening review | **BLOCKED** - no stable-ID opening/clearance observation | R-488/R-492 |
| `foregate_south_jamb` | collision-bearing foregate jamb | `build_building()` -> wall-aware path; excluded by exceptional registry | `content/maps/lower_town_slice.rrmap:147` | **BLOCKED** - no named foregate-opening review | **BLOCKED** - no stable-ID opening/clearance observation | R-488/R-492 |
| `viru_foregate_arch` | view-only foregate landmark | `MapViewMeshBuilderLandmarks.build_landmark()` -> `_add_gate_arch()`; no collision/navigation | `content/maps/lower_town_slice.rrmap:242`; `scripts/map/view3d/map_view_mesh_builder_landmarks.gd:42` | **BLOCKED** - oak 1343 foregate presentation not human-reviewed | **BLOCKED** - packet does not separate foregate IDs from inner gate | R-488/R-489/R-492; review against both foregate jambs |
| `city_wall_north` | city-wall fabric | `build_building()` -> wall-aware fortification path | `content/maps/lower_town_slice.rrmap:130` | **BLOCKED** - no named wall-silhouette review | **BLOCKED** - no stable-ID wall-walk observation | R-488/R-489/R-492 |
| `city_wall_gate_south` | city-wall gate-side fabric | `build_building()` -> wall-aware sealed/fortification path | `content/maps/lower_town_slice.rrmap:148` | **BLOCKED** - no named gate-side wall review | **BLOCKED** - no stable-ID route/occlusion observation | R-488/R-489/R-492 |
| `city_wall_south_continuation` | city-wall fabric | `build_building()` -> wall-aware sealed/fortification path | `content/maps/lower_town_slice.rrmap:167` | **BLOCKED** - no named wall-continuity review | **BLOCKED** - no stable-ID district-edge observation | R-488/R-489/R-492 |
| `wall_tower_northeast` | round tower / wall-walk `z` | `build_building()` -> wall-aware round-tower path | `content/maps/lower_town_slice.rrmap:131` | **BLOCKED** - no named 1343 tower review | **BLOCKED** - no stable-ID route-scale tower observation | R-488/R-489/R-492 |
| `wall_tower_north` | round tower / wall-walk `z` | `build_building()` -> wall-aware round-tower path | `content/maps/lower_town_slice.rrmap:132` | **BLOCKED** - no named 1343 tower review | **BLOCKED** - no stable-ID route-scale tower observation | R-488/R-489/R-492 |
| `hinke_tower` | round tower / wall-walk `z` | `build_building()` -> wall-aware round-tower path | `content/maps/lower_town_slice.rrmap:159` | **BLOCKED** - no named 1343 tower review | **BLOCKED** - no stable-ID route-scale tower observation | R-488/R-489/R-492 |
| `wall_tower_southeast` | round tower / wall-walk `x` | `build_building()` -> wall-aware round-tower path | `content/maps/lower_town_slice.rrmap:161` | **BLOCKED** - no named 1343 tower review | **BLOCKED** - no stable-ID route-scale tower observation | R-488/R-489/R-492 |
| `wall_tower_south` | round tower / wall-walk `x` | `build_building()` -> wall-aware round-tower path | `content/maps/lower_town_slice.rrmap:163` | **BLOCKED** - no named 1343 tower review | **BLOCKED** - no stable-ID route-scale tower observation | R-488/R-489/R-492 |
| `wall_tower_southwest` | round tower / wall-walk `x` | `build_building()` -> wall-aware round-tower path | `content/maps/lower_town_slice.rrmap:165` | **BLOCKED** - no named 1343 tower review | **BLOCKED** - no stable-ID route-scale tower observation | R-488/R-489/R-492 |
| `wall_seal_viru_south_join` | sealed city-wall fabric | `build_building()` -> wall-aware sealed-wall path | `content/maps/lower_town_slice.rrmap:151` | **BLOCKED** - no named sealed-join review | **BLOCKED** - no stable-ID closure observation | R-488/R-489/R-492 |
| `wall_seal_viru_south_west` | sealed city-wall fabric | `build_building()` -> wall-aware sealed-wall path | `content/maps/lower_town_slice.rrmap:152` | **BLOCKED** - no named sealed-join review | **BLOCKED** - no stable-ID closure observation | R-488/R-489/R-492 |
| `wall_seal_viru_south_east` | sealed city-wall fabric | `build_building()` -> wall-aware sealed-wall path | `content/maps/lower_town_slice.rrmap:153` | **BLOCKED** - no named sealed-join review | **BLOCKED** - no stable-ID closure observation | R-488/R-489/R-492 |
| `wall_seal_hinke_north` | sealed city-wall fabric | `build_building()` -> wall-aware sealed-wall path | `content/maps/lower_town_slice.rrmap:154` | **BLOCKED** - no named sealed-join review | **BLOCKED** - no stable-ID closure observation | R-488/R-489/R-492 |
| `wall_seal_bend_a_east` | sealed city-wall fabric | `build_building()` -> wall-aware sealed-wall path | `content/maps/lower_town_slice.rrmap:155` | **BLOCKED** - no named sealed-join review | **BLOCKED** - no stable-ID closure observation | R-488/R-489/R-492 |
| `wall_seal_bend_b_north` | sealed city-wall fabric | `build_building()` -> wall-aware sealed-wall path | `content/maps/lower_town_slice.rrmap:156` | **BLOCKED** - no named sealed-join review | **BLOCKED** - no stable-ID closure observation | R-488/R-489/R-492 |
| `wall_seal_bend_c_west` | sealed city-wall fabric | `build_building()` -> wall-aware sealed-wall path | `content/maps/lower_town_slice.rrmap:157` | **BLOCKED** - no named sealed-join review | **BLOCKED** - no stable-ID closure observation | R-488/R-489/R-492 |
| `wall_seal_bend_d_north` | sealed city-wall fabric | `build_building()` -> wall-aware sealed-wall path | `content/maps/lower_town_slice.rrmap:158` | **BLOCKED** - no named sealed-join review | **BLOCKED** - no stable-ID closure observation | R-488/R-489/R-492 |
| `city_wall_bend_a` | city-wall bend | `build_building()` -> wall-aware fortification path | `content/maps/lower_town_slice.rrmap:160` | **BLOCKED** - no named bend review | **BLOCKED** - no stable-ID route/occlusion observation | R-488/R-489/R-492 |
| `city_wall_bend_b` | city-wall bend | `build_building()` -> wall-aware fortification path | `content/maps/lower_town_slice.rrmap:162` | **BLOCKED** - no named bend review | **BLOCKED** - no stable-ID route/occlusion observation | R-488/R-489/R-492 |
| `city_wall_bend_c` | city-wall bend | `build_building()` -> wall-aware fortification path | `content/maps/lower_town_slice.rrmap:164` | **BLOCKED** - no named bend review | **BLOCKED** - no stable-ID route/occlusion observation | R-488/R-489/R-492 |
| `city_wall_bend_d` | city-wall bend | `build_building()` -> wall-aware fortification path | `content/maps/lower_town_slice.rrmap:166` | **BLOCKED** - no named bend review | **BLOCKED** - no stable-ID route/occlusion observation | R-488/R-489/R-492 |
| `monastery_precinct_wall_west` | monastery precinct wall | `build_building()` -> wall-aware path; separate from houses | `content/maps/lower_town_slice.rrmap:170` | **BLOCKED** - no named precinct-boundary review | **BLOCKED** - no stable-ID approach/access observation | R-488/R-489/R-492 |
| `monastery_precinct_wall_south_a` | monastery precinct wall | `build_building()` -> wall-aware path; separate from houses | `content/maps/lower_town_slice.rrmap:171` | **BLOCKED** - no named precinct-boundary review | **BLOCKED** - no stable-ID approach/access observation | R-488/R-489/R-492 |
| `monastery_precinct_wall_south_b` | monastery precinct wall | `build_building()` -> wall-aware path; separate from houses | `content/maps/lower_town_slice.rrmap:172` | **BLOCKED** - no named precinct-boundary review | **BLOCKED** - no stable-ID approach/access observation | R-488/R-489/R-492 |
| `smithy_yard_fence_north` | smithy yard fence | `build_building()` -> wall-aware low-fence path | `content/maps/lower_town_slice.rrmap:222` | **BLOCKED** - no named production-boundary review | **BLOCKED** - no stable-ID localized-yard observation | R-488/R-489/R-492 |
| `smithy_yard_fence_east` | smithy yard fence | `build_building()` -> wall-aware low-fence path | `content/maps/lower_town_slice.rrmap:223` | **BLOCKED** - no named production-boundary review | **BLOCKED** - no stable-ID localized-yard observation | R-488/R-489/R-492 |

## Explicit ordinary-house exclusion proof

The source and registry contracts establish the required negative boundary:

1. `MapViewMeshBuilderBuildingRegistry.exceptional_category()` returns immediately for any record whose `kind` is not `house`. Therefore all Viru towers, jambs, foregate walls/towers/jambs, city-wall segments, seals, bends, precinct walls, and smithy fences cannot enter the exceptional-house registry.
2. `MapViewMeshBuilderBuildings.build_building()` branches `kind=wall` into wall-aware geometry. Fortification height scaling, round drums, wall-walk passages, battlements, covered wall walks, sealed-wall sizing, and low-fence height remain on this path.
3. `st_catherines_church` is the only current Lower Town house record in the 48-row set registered as exceptional. Its dedicated church renderer creates `ChurchNaveRoof`, lancets, buttresses, bell tower, and church metadata; the test suite confirms it does not use the ordinary `Roof` or `Chimney` nodes.
4. The two gate arches are not building records at all. Their view-landmark path creates visual gate geometry without collision or navigation. The collision/opening contract is owned by the matching jamb/tower/wall records, and `test_viru_gate_arch_matches_collision_jamb_span` passes.

Consequently, no wall, jamb, tower, fence, or view-only arch is counted as ordinary-house coverage, and no ordinary house is promoted to an exceptional silhouette by this ledger.

## Verification record

### Source reconciliation

A direct parser over `content/maps/lower_town_slice.rrmap` reported:

```text
records=99 unique_records=99
building_records=97 landmark_records=2
required_nonordinary_ids=48 present=48 missing=0 duplicate_ids=0
```

The current line references in the matrix were checked against the live source. The current source revision differs from the 91-record R-486/R-533 snapshot only by additional ordinary/service records and does not remove or duplicate a required non-ordinary stable ID.

### Focused checks

Commands used the installed Godot 4.7.1 binary and the checked runner with `GODOT_LOG_DIR=/private/tmp`:

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
GODOT_LOG_DIR=/private/tmp tools/run_godot_checked.sh --require-test-summary r589-map -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_lower_town_slice_map

GODOT_LOG_DIR=/private/tmp tools/run_godot_checked.sh --require-test-summary r589-fortification -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_map_view_3d_fortification

GODOT_LOG_DIR=/private/tmp tools/run_godot_checked.sh --require-test-summary r589-mesh -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_map_view_3d_mesh

GODOT_LOG_DIR=/private/tmp tools/run_godot_checked.sh --require-test-summary r589-tiers -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_burgher_house_tiers
```

| Check | Result | Classification |
|---|---|---|
| Direct source extraction | **PASS** | 99 records, 99 unique IDs, all 48 required non-ordinary IDs present exactly once. |
| `test_lower_town_slice_map` | **18 PASS, 1 FAIL, 0 errors** | All boundary, wall blocking, route, navigation, and Viru arch-span assertions pass. The sole failure is canonical parity drift caused by current shared-worktree gameplay WIP; this ledger does not regenerate the fixture. |
| `test_map_view_3d_fortification` | **7 PASS, 0 FAIL, 1 test error** | Fortification, tower, wall-walk, fence, and gate-arch assertions pass. One unrelated neighbor-preview test is interrupted by a shader tokenizer error from `# gdlint` text embedded in `map_view_water_materials.gd`; this is not a boundary assertion failure. |
| `test_map_view_3d_mesh` | **18 PASS, 0 FAIL, 1 test error** | Exceptional-building boundary, church path, ordinary-house exclusion, wall materials, and mesh contracts pass. One unrelated smoke-material test is interrupted by the same water shader tokenizer error. |
| `test_burgher_house_tiers` | **5 PASS, 0 FAIL, 0 errors** | Confirms exceptional registry precedence, untiered special records, and rejection of wall records crossing into exceptional-house routing. |
| Combined boundary run | **53 PASS, 1 FAIL, 2 errors** | Boundary-specific assertions pass; the failure and diagnostics are the scoped parity drift and pre-existing neighboring shader defect described above. |

### Visual and human review boundary

The tracked R-491 capture matrix records the dedicated matched day/night route packet and valid 1280x720 PNG contract, but every required surface row remains pending or blocked and no row identifies the visible stable IDs for these records. The `landmark_approaches` route context therefore does not identify St. Catherine's, each Viru tower/jamb/arch, the foregate, or each wall boundary. R-492 records `Human canon reviewer: Not assigned` and `Human art reviewer: Not assigned`.

Therefore all 48 matrix rows remain **BLOCKED** for final historical/art and route-scale acceptance. Existing packet integrity, orthographic/calibration images, source footprints, and headless contracts must not be promoted to accepted 1343 silhouette evidence.

## Closeout and ownership

**R-589 is complete as a deterministic BLOCKED verification ledger.** The structural boundary is reconciled and passes, but the required accepted 1343 silhouette evidence and named human review are absent for every row. Keep R-108 / P0-101 open.

No follow-up task is created. Existing owners cover the gaps:

- R-488: exceptional implementation and production silhouette handoff.
- R-489: playable-route integration.
- R-491: stable-ID-linked matched day/night evidence.
- R-492: named canon/art review and per-row silhouette decision.

## Sources

- [`content/maps/lower_town_slice.rrmap`](../../content/maps/lower_town_slice.rrmap)
- [`docs/reports/lower_town_p0_101_landmark_inventory.md`](lower_town_p0_101_landmark_inventory.md)
- [`docs/reports/r533_lower_town_landmark_boundary_acceptance.md`](r533_lower_town_landmark_boundary_acceptance.md)
- [`tools/run_godot_checked.sh`](../../tools/run_godot_checked.sh) - checked focused-run wrapper and diagnostic classification
- [`docs/reports/r492_lower_town_1343_landmark_silhouette_review.md`](r492_lower_town_1343_landmark_silhouette_review.md)
- [`docs/reports/lower_town_p0_101_capture_matrix.md`](lower_town_p0_101_capture_matrix.md)
- [`scripts/map/view3d/map_view_mesh_builder_building_registry.gd`](../../scripts/map/view3d/map_view_mesh_builder_building_registry.gd)
- [`scripts/map/view3d/map_view_mesh_builder_buildings.gd`](../../scripts/map/view3d/map_view_mesh_builder_buildings.gd)
- [`scripts/map/view3d/map_view_mesh_builder_churches.gd`](../../scripts/map/view3d/map_view_mesh_builder_churches.gd)
- [`scripts/map/view3d/map_view_mesh_builder_landmarks.gd`](../../scripts/map/view3d/map_view_mesh_builder_landmarks.gd)
- [`tests/godot/test_lower_town_slice_map.gd`](../../tests/godot/test_lower_town_slice_map.gd)
- [`tests/godot/test_map_view_3d_fortification.gd`](../../tests/godot/test_map_view_3d_fortification.gd)
- [`tests/godot/test_map_view_3d_mesh.gd`](../../tests/godot/test_map_view_3d_mesh.gd)
- [`tests/godot/test_burgher_house_tiers.gd`](../../tests/godot/test_burgher_house_tiers.gd)
