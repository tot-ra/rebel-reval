# R-492 / P0-101g Lower Town 1343 landmark silhouette review

**Review date:** 2026-08-12
**Historical target:** Spring 1343 Reval, Lower Town / Workers' District
**Task:** R-492 / P0-101g
**Inputs:** R-486 `lower_town_p0_101_landmark_inventory.md`, R-491 `lower_town_p0_101_capture_matrix.md`, R-488 exceptional-landmark implementation row, R-489 route integration row, R-490 runtime/route/occlusion/budget QA row
**Review mode:** Evidence pre-review only; no human canon or art sign-off was performed
**Human canon reviewer:** Not assigned
**Human art reviewer:** Not assigned
**Status:** **BLOCKED - no silhouette may be approved from the current evidence set**

## Decision

**FINAL 1343 LANDMARK SILHOUETTE SIGN-OFF: BLOCKED.**

The current repository proves that the Lower Town source contains the required stable records and that the renderer keeps exceptional houses, fortification walls, and view-only gate arches on separate boundaries. It does not prove that the required landmark models are production-complete, integrated on a playable route, readable at gameplay scale, or accepted by a human canon/art reviewer.

R-491 records every required day/night capture as `pending` and states that the existing whole-map orthographic smoke images are supplementary only. R-488, which owns the exceptional landmark implementation, remains `todo`. Therefore this report records a per-silhouette **BLOCKED** disposition for every required non-ordinary visible record. It must not be read as historical approval, art approval, runtime acceptance, or a waiver of the missing captures.

The source inventory also covers 43 ordinary tiered houses. Their family-level presentation remains blocked separately below; no individual ordinary-house ID is visually approved by this report.

## Evidence boundary

| Evidence item | Result | Interpretation |
|---|---|---|
| R-486 authored inventory | **PASS as source inventory only** | 91 stable records are enumerated: 53 houses, 36 walls, and 2 view-only gate arches. Stable IDs and authored categories are not visual acceptance evidence. |
| R-491 capture matrix | **BLOCKED** | No dedicated gameplay-scale route or landmark-approach day/night capture exists. Every required row remains pending. |
| R-488 exceptional landmark implementation | **BLOCKED** | Board status is `todo`; required exceptional models/silhouettes and focused landmark evidence are not claimed complete. |
| R-489 Lower Town art integration | **BLOCKED** | Route integration and playable-slice presentation remain an upstream handoff, not evidence for this review. |
| R-490 runtime/route/occlusion/budget QA | **IN PROGRESS** | Runtime and budget checks cannot close this visual gate while the required captures and implementation handoffs are absent. |
| Existing whole-map `view3d` day/night images | **Supplementary only** | Fixed orthographic whole-map framing has no gameplay-scale route/approach metadata and cannot be promoted to R-492 evidence. |
| Human canon/art review | **Missing** | No named human reviewer, signed verdict, or amendment record is present. |

## Acceptance rules

A future review may replace a row's disposition only when the row has a matched day/night gameplay-scale capture from the same camera pose and map revision, a production implementation or authored geometry reference, and an explicit human canon/art observation. The observation must check silhouette, period boundary, material/value readability, route/occlusion behavior, and the relevant collision or view-only semantics.

The Spring 1343 exclusion boundary remains authoritative: do not introduce later barbicans, post-1346 Order/convent massing, later stone hill-gate forms, tourist Gothic enrichment, or an enlarged ordinary-house substitute. A plausible reconstruction must remain labelled as such and must not be presented as measured archaeological proof.

## Ordinary-fabric family disposition

These rows are included because P0-101's final art gate must distinguish ordinary fabric from exceptional landmarks. They are not landmark approvals.

| Family | Required IDs | Verdict | Missing acceptance evidence |
|---|---|---|---|
| `merchant_stone` | 14 IDs listed in R-486 section 1.1 | **BLOCKED** | No gameplay-scale day/night frontage pair; no verified tile-forward material hierarchy, merchant massing, variation, or negative check against landmark treatment. |
| `merchant_timber` | 14 IDs listed in R-486 section 1.1 | **BLOCKED** | No gameplay-scale day/night frontage pair; no verified timber/plaster frontage, shingle-forward roof read, variation, or negative check against stone-Gothic drift. |
| `craft_boda` | 15 IDs listed in R-486 section 1.1 | **BLOCKED** | No gameplay-scale day/night frontage pair; no verified compact workshop-dwelling massing, roof read, or absence of a default merchant hoist. |

The 43 ordinary IDs remain owned by the ordinary-fabric and integration rows. This report does not approve any of them individually.

## Per-silhouette verdicts

All 48 rows below are required non-ordinary visible records from the R-486 inventory. The repeated `BLOCKED` verdict is intentional: it prevents a source-ID inventory from being mistaken for a completed art review.

### Special and exceptional buildings

| Stable ID | Surface class | Required 1343/readability check | Verdict |
|---|---|---|---|
| `monastery_cloister` | special/use-site house | Precinct mass must read as monastery fabric, not a scaled ordinary house; route-scale day/night legibility | **BLOCKED** |
| `monastery_barn` | special/use-site house | Service/agricultural mass must remain distinct from ordinary tier frontage; route-scale day/night legibility | **BLOCKED** |
| `guild_storehouse` | special/use-site house | Storage/use-site identity and enlarged mass must not collapse into an ordinary merchant tier | **BLOCKED** |
| `public_bathhouse` | special/use-site house | Bathhouse identity and frontage must remain distinct from generic ordinary fabric | **BLOCKED** |
| `karja_gate_house` | special/use-site house | Gate-side use-site boundary and approach must read without an enlarged-house silhouette | **BLOCKED** |
| `foaming_mug_brewery` | special/use-site house | Production building, entrance, and working-yard relationship must remain readable at route scale | **BLOCKED** |
| `kalev_smithy` | special/use-site house | Smithy mass and production approach must remain a special use-site, not a tier substitute | **BLOCKED** |
| `muurivahe_house_north` | special/use-site house | Wall-adjacent special boundary must remain legible and not become ordinary frontage | **BLOCKED** |
| `south_apron_wall_walk_hut` | special/use-site house | Wall-walk/service relationship and modest scale must remain readable | **BLOCKED** |
| `st_catherines_church` | exceptional `church` house | Dated 1343 church silhouette and exceptional renderer path; no ordinary-house substitution or unsupported later enrichment | **BLOCKED** |

### Inner Viru Gate

| Stable ID | Surface class | Required 1343/readability check | Verdict |
|---|---|---|---|
| `viru_gate_north_tower` | collision-bearing fortification | Inner-gate tower mass, wall-walk `z`, opening clearance, and 1343 state must read as fortification | **BLOCKED** |
| `viru_gate_south_tower` | collision-bearing fortification | Inner-gate tower mass, wall-walk `z`, opening clearance, and 1343 state must read as fortification | **BLOCKED** |
| `viru_gate_north_jamb` | collision-bearing gate jamb | Jamb must meet the arch span while preserving the authored road opening and collision boundary | **BLOCKED** |
| `viru_gate_south_jamb` | collision-bearing gate jamb | Jamb must meet the arch span while preserving the authored road opening and collision boundary | **BLOCKED** |
| `viru_gate_arch` | view-only gate landmark | Ironbound arch and raised portcullis must align visually with the jambs; it must not provide collision/navigation | **BLOCKED** |

### Viru foregate

| Stable ID | Surface class | Required 1343/readability check | Verdict |
|---|---|---|---|
| `foregate_wall_north` | collision-bearing foregate wall | Incomplete 1343 foregate state and wall opening must remain distinct from the inner gate | **BLOCKED** |
| `foregate_wall_south` | collision-bearing foregate wall | Incomplete 1343 foregate state and wall opening must remain distinct from the inner gate | **BLOCKED** |
| `foregate_tower_north` | collision-bearing fortification | Foregate round-tower stub must remain subordinate to the dated incomplete state | **BLOCKED** |
| `foregate_tower_south` | collision-bearing fortification | Foregate round-tower stub must remain subordinate to the dated incomplete state | **BLOCKED** |
| `foregate_north_jamb` | collision-bearing gate jamb | Jamb must preserve the authored foregate opening and route clearance | **BLOCKED** |
| `foregate_south_jamb` | collision-bearing gate jamb | Jamb must preserve the authored foregate opening and route clearance | **BLOCKED** |
| `viru_foregate_arch` | view-only gate landmark | Oak arch must fit the foregate opening, preserve route readability, and remain distinct from the inner ironbound arch | **BLOCKED** |

### City-wall continuity and gate-side fabric

| Stable ID | Surface class | Required 1343/readability check | Verdict |
|---|---|---|---|
| `city_wall_north` | city-wall fabric | Continuous fortification surface must not read as ordinary house frontage or an invented later skyline | **BLOCKED** |
| `city_wall_gate_south` | city-wall fabric | Gate-side wall mass and authored non-tower state must preserve route and fortification readability | **BLOCKED** |
| `city_wall_south_continuation` | city-wall fabric | Continuation must preserve the authored city-wall silhouette and route-scale occlusion | **BLOCKED** |

### Round towers and wall-walk silhouettes

| Stable ID | Surface class | Required 1343/readability check | Verdict |
|---|---|---|---|
| `wall_tower_northeast` | round tower / wall-walk `z` | Round-tower silhouette and wall-walk continuity; no later or unowned tower invention | **BLOCKED** |
| `wall_tower_north` | round tower / wall-walk `z` | Round-tower silhouette and wall-walk continuity; no later or unowned tower invention | **BLOCKED** |
| `hinke_tower` | round tower / wall-walk `z` | Round-tower silhouette and wall-walk continuity; no later or unowned tower invention | **BLOCKED** |
| `wall_tower_southeast` | round tower / wall-walk `x` | Round-tower silhouette and wall-walk continuity; no later or unowned tower invention | **BLOCKED** |
| `wall_tower_south` | round tower / wall-walk `x` | Round-tower silhouette and wall-walk continuity; no later or unowned tower invention | **BLOCKED** |
| `wall_tower_southwest` | round tower / wall-walk `x` | Round-tower silhouette and wall-walk continuity; no later or unowned tower invention | **BLOCKED** |

### Sealed wall joins

| Stable ID | Surface class | Required 1343/readability check | Verdict |
|---|---|---|---|
| `wall_seal_viru_south_join` | sealed city-wall fabric | Join must remain closed, preserve wall continuity, and not create accidental ordinary frontage | **BLOCKED** |
| `wall_seal_viru_south_west` | sealed city-wall fabric | Join must remain closed, preserve wall continuity, and not create accidental ordinary frontage | **BLOCKED** |
| `wall_seal_viru_south_east` | sealed city-wall fabric | Join must remain closed, preserve wall continuity, and not create accidental ordinary frontage | **BLOCKED** |
| `wall_seal_hinke_north` | sealed city-wall fabric | Join must remain closed, preserve wall continuity, and not create accidental ordinary frontage | **BLOCKED** |
| `wall_seal_bend_a_east` | sealed city-wall fabric | Join must remain closed, preserve wall continuity, and not create accidental ordinary frontage | **BLOCKED** |
| `wall_seal_bend_b_north` | sealed city-wall fabric | Join must remain closed, preserve wall continuity, and not create accidental ordinary frontage | **BLOCKED** |
| `wall_seal_bend_c_west` | sealed city-wall fabric | Join must remain closed, preserve wall continuity, and not create accidental ordinary frontage | **BLOCKED** |
| `wall_seal_bend_d_north` | sealed city-wall fabric | Join must remain closed, preserve wall continuity, and not create accidental ordinary frontage | **BLOCKED** |

### City-wall bends and precinct/fence boundaries

| Stable ID | Surface class | Required 1343/readability check | Verdict |
|---|---|---|---|
| `city_wall_bend_a` | city-wall bend | Bend must preserve fortification silhouette, route clearance, and intended occlusion | **BLOCKED** |
| `city_wall_bend_b` | city-wall bend | Bend must preserve fortification silhouette, route clearance, and intended occlusion | **BLOCKED** |
| `city_wall_bend_c` | city-wall bend | Bend must preserve fortification silhouette, route clearance, and intended occlusion | **BLOCKED** |
| `city_wall_bend_d` | city-wall bend | Bend must preserve fortification silhouette, route clearance, and intended occlusion | **BLOCKED** |
| `monastery_precinct_wall_west` | monastery precinct wall | Precinct boundary must read separately from house rows and remain traversable only at authored routes | **BLOCKED** |
| `monastery_precinct_wall_south_a` | monastery precinct wall | Precinct boundary must read separately from house rows and remain traversable only at authored routes | **BLOCKED** |
| `monastery_precinct_wall_south_b` | monastery precinct wall | Precinct boundary must read separately from house rows and remain traversable only at authored routes | **BLOCKED** |
| `smithy_yard_fence_north` | smithy yard fence | Local production boundary must remain modest and localized, not monumental or house-like | **BLOCKED** |
| `smithy_yard_fence_east` | smithy yard fence | Local production boundary must remain modest and localized, not monumental or house-like | **BLOCKED** |

## Why no row is approved

The blocked disposition is shared by all rows for the same evidence reasons, not because the source inventory is rejected:

1. **No required capture pair exists.** R-491 marks day and night plates as pending for every acceptance surface. Existing orthographic smoke and calibration plates do not satisfy the gameplay-scale route/approach contract.
2. **Exceptional implementation is not complete.** R-488 is still `todo`, so this review cannot claim production-ready landmark silhouettes for the special buildings, St. Catherine's, or the 1343 gate presentation.
3. **Route integration and QA are open.** R-489 and R-490 still own playable route integration and runtime/occlusion/budget evidence.
4. **No human reviewer is recorded.** A source-backed static check cannot substitute for the required canon/art decision on period silhouette and visual readability.
5. **Source records are not visual proof.** Stable IDs, footprints, `round_tower`, `wall_walk_axis`, gate variants, and exceptional registry membership establish ownership and routing boundaries only.

## Required closeout evidence

R-492 can move from `BLOCKED` to a reviewable state only after the following are attached or linked:

1. Production or reviewed exceptional implementations for all R-488-required records, with stable IDs preserved.
2. A dedicated `lower_town_p0_101` capture set with matched gameplay-scale day/night poses and map revision metadata.
3. Coverage of the 43 ordinary IDs by representative and repeated frontage captures, plus the ten untiered house records listed in R-486.
4. Landmark approach/opening captures for St. Catherine's, inner Viru Gate, Viru foregate, monastery/special buildings, fortification continuity, precinct boundaries, and smithy fence.
5. Explicit proof that `viru_gate_arch` and `viru_foregate_arch` remain view-only, while their jambs/towers/walls own collision and navigation.
6. A named human canon reviewer and named human art reviewer, with per-row observations and either `PASS`, `PASS WITH AMENDMENTS`, or a specific blocker.
7. Focused runtime, route, occlusion, navigation, and performance results from R-490/R-489 without silently promoting supplementary images.

## Ownership and handoff

No new follow-up task is created by this report because the blockers already have owning board rows:

- **R-487 / P0-101b:** ordinary frontage variation and worn-material gaps.
- **R-488 / P0-101c:** exceptional landmark implementation and non-ordinary silhouettes.
- **R-489 / P0-101d:** Lower Town art integration on playable routes.
- **R-490 / P0-101e:** runtime, route, occlusion, and budget QA.
- **R-491 / P0-101f:** dedicated matched day/night capture set.
- **R-108 / P0-101:** parent final art and human acceptance gate.

R-492 should remain open/in review until the implementation, capture, QA, and human review evidence are available. This report intentionally does not change map data, renderer code, assets, tests, or historical audit decisions.

## Reproduction and source references

The evidence boundary is reproducible from the repository and board state with:

```sh
# Current task-board ownership is recorded by the task tool:
# R-487, R-488, R-489, R-490, R-491, and R-108.

# Focused contract baselines recorded by R-486/R-491:
tools/run_godot_checked.sh --require-test-summary r491-lower-map \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_lower_town_slice_map

tools/run_godot_checked.sh --require-test-summary r491-house-tiers \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_burgher_house_tiers
```

These focused suites are source/contract checks only. Their recorded `19/19` and `3/3` results do not promote a missing visual capture set or create a human art/canon verdict.

- [`lower_town_p0_101_landmark_inventory.md`](lower_town_p0_101_landmark_inventory.md) - R-486 source inventory, renderer boundaries, and acceptance scope.
- [`lower_town_p0_101_capture_matrix.md`](lower_town_p0_101_capture_matrix.md) - R-491 capture contract and pending evidence matrix.
- [`content/maps/lower_town_slice.rrmap`](../../content/maps/lower_town_slice.rrmap) - authored stable records and footprints.
- [`scripts/map/view3d/map_view_mesh_builder_building_registry.gd`](../../scripts/map/view3d/map_view_mesh_builder_building_registry.gd) - exceptional-house routing.
- [`scripts/map/view3d/map_view_mesh_builder_buildings.gd`](../../scripts/map/view3d/map_view_mesh_builder_buildings.gd) - ordinary and wall-aware building paths.
- [`scripts/map/view3d/map_view_mesh_builder_landmarks.gd`](../../scripts/map/view3d/map_view_mesh_builder_landmarks.gd) - view-only gate landmark path.
- [`tests/godot/test_lower_town_slice_map.gd`](../../tests/godot/test_lower_town_slice_map.gd) - map and Viru arch contract checks.
- [`tests/godot/test_burgher_house_tiers.gd`](../../tests/godot/test_burgher_house_tiers.gd) - ordinary-tier and untiered boundary checks.
