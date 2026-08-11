# Lower Town P0-101 landmark and ordinary-fabric inventory

**Task:** R-486 / P0-101a, c1
**Map:** `lower_town_slice` / Workers' District
**Source snapshot:** current shared worktree, 2026-08-12
**Status:** **INVENTORY COMPLETE - FINAL VISUAL ACCEPTANCE BLOCKED**

## Decision

The authored Lower Town source contains 91 stable records:

- 53 `building ... house` records.
- 36 `building ... wall` records, including city-wall fabric, Viru Gate and foregate structures, monastery precinct walls, and the smithy yard fence.
- 2 `landmark ... gate_arch` view landmarks.

The ordinary-fabric scope is the 43 tiered house records: 14 `merchant_stone`, 14 `merchant_timber`, and 15 `craft_boda`. Ten house records intentionally omit `house_tier`; one of those, `st_catherines_church`, is recognized by the exceptional-house registry, while the other nine are named special/use-site records that remain on the default building path. The 36 wall records are not exceptional houses and must remain on the fortification-capable building path. The two gate arches are view-only and do not provide collision or navigation.

This report is evidence-only. It does not change authored map data, renderer code, assets, or tests.

## 1. Authored source inventory

Source lines below refer to [`content/maps/lower_town_slice.rrmap`](../../content/maps/lower_town_slice.rrmap).
Coordinates are cell coordinates and `w x h` is the authored footprint in cells.

### 1.1 Tiered ordinary houses: 43 records

#### `merchant_stone`: 14

| ID | Position / footprint | Source |
|---|---:|---:|
| `pikk_corner_house` | `0,0` / `9 x 8` | 160 |
| `vene_row_house` | `10,0` / `8 x 8` | 161 |
| `vene_corner_house` | `19,0` / `6 x 8` | 162 |
| `market_row_house` | `0,14` / `8 x 10` | 163 |
| `saiakang_house` | `9,14` / `9 x 10` | 164 |
| `vene_gate_house` | `19,14` / `6 x 10` | 165 |
| `apothecary_house` | `0,27` / `8 x 8` | 166 |
| `moneychangers_house` | `17,27` / `8 x 8` | 168 |
| `kaik_house_west` | `31,27` / `11 x 8` | 170 |
| `kaik_house_mid` | `43,27` / `12 x 8` | 171 |
| `kaik_house_east` | `59,27` / `11 x 8` | 172 |
| `glovers_house` | `83,27` / `9 x 8` | 174 |
| `viru_house_stone` | `59,41` / `11 x 8` | 178 |
| `merchants_house` | `71,38` / `11 x 10` | 179 |

#### `merchant_timber`: 14

| ID | Position / footprint | Source |
|---|---:|---:|
| `turg_house_north` | `9,27` / `7 x 8` | 167 |
| `vanaturu_kael_house` | `16,41` / `10 x 8` | 169 |
| `corner_house_muurivahe` | `93,27` / `10 x 8` | 175 |
| `viru_house_west` | `31,41` / `11 x 8` | 176 |
| `viru_house_mid` | `43,38` / `14 x 10` | 177 |
| `viru_house_east` | `83,41` / `9 x 8` | 180 |
| `weary_traveler_inn` | `93,41` / `10 x 8` | 181 |
| `saddlers_house` | `16,62` / `9 x 8` | 182 |
| `coopers_house` | `26,62` / `8 x 8` | 183 |
| `rope_makers_house` | `45,62` / `8 x 8` | 185 |
| `karja_corner_house` | `54,62` / `10 x 8` | 186 |
| `turg_south_house` | `7,73` / `8 x 8` | 197 |
| `west_lane_house` | `7,87` / `8 x 8` | 198 |
| `glassblowers_house` | `67,62` / `8 x 8` | 203 |

#### `craft_boda`: 15

| ID | Position / footprint | Source |
|---|---:|---:|
| `sauna_corner_house` | `35,62` / `8 x 8` | 184 |
| `kuninga_house_west` | `16,79` / `9 x 6` | 187 |
| `kuninga_house_mid` | `26,79` / `8 x 6` | 188 |
| `kuninga_house_east` | `35,79` / `8 x 6` | 189 |
| `vaike_karja_house` | `54,79` / `10 x 6` | 191 |
| `tenement_row` | `16,92` / `9 x 8` | 192 |
| `laundress_house` | `26,92` / `9 x 8` | 193 |
| `widows_house` | `36,92` / `10 x 8` | 194 |
| `dyers_house` | `47,92` / `9 x 8` | 195 |
| `hedge_house` | `7,100` / `8 x 8` | 199 |
| `wall_side_house` | `7,114` / `8 x 8` | 200 |
| `artisan_shed` | `76,79` / `8 x 6` | 201 |
| `potters_house` | `76,89` / `8 x 6` | 202 |
| `south_apron_timber_house` | `81,114` / `8 x 6` | 212 |
| `south_apron_far_roofs` | `100,118` / `10 x 6` | 213 |

### 1.2 Untiered houses: 10 records

Omitting `house_tier` is legal in the compiler contract. These records are kept separate from the 43-record ordinary tier inventory. The focused tier test explicitly keeps seven named exceptional/special IDs outside ordinary tiers; the remaining three untiered records are retained here as additional legacy or use-site records and are not silently counted as ordinary fabric.

| ID | Position / footprint | Boundary classification | Source |
|---|---:|---|---:|
| `st_catherines_church` | `35,3` / `21 x 10` | Exceptional registry: `church` | 154 |
| `monastery_cloister` | `57,0` / `18 x 12` | Special/use-site; default building path | 155 |
| `monastery_barn` | `79,5` / `8 x 6` | Special/use-site; default building path | 159 |
| `guild_storehouse` | `71,27` / `11 x 8` | Special/use-site; default building path | 173 |
| `public_bathhouse` | `45,79` / `8 x 6` | Special/use-site; default building path | 190 |
| `karja_gate_house` | `57,92` / `6 x 8` | Special/use-site; default building path | 196 |
| `foaming_mug_brewery` | `76,62` / `9 x 8` | Special/use-site; default building path | 204 |
| `kalev_smithy` | `86,62` / `10 x 8` | Special/use-site; default building path | 205 |
| `muurivahe_house_north` | `100,0` / `8 x 6` | Special/use-site; default building path | 210 |
| `south_apron_wall_walk_hut` | `50,116` / `8 x 6` | Special/use-site; default building path | 211 |

### 1.3 Wall and fortification surface: 36 records

All records in this table are `building ... wall`. They are collision-bearing authored geometry, not exceptional houses. `round_tower=true` and `wall_walk_axis` are retained as authored renderer inputs. `tower=false` keeps the historical incomplete/doorless state where authored.

| ID | Position / footprint | Surface role / authored flags | Source |
|---|---:|---|---:|
| `city_wall_north` | `111,0` / `4 x 41` | City-wall fabric | 116 |
| `wall_tower_northeast` | `109,5` / `8 x 6` | Round tower; wall-walk `z` | 117 |
| `wall_tower_north` | `109,24` / `8 x 6` | Round tower; wall-walk `z` | 118 |
| `viru_gate_north_tower` | `107,41` / `10 x 8` | Viru Gate throat; round tower; wall-walk `z` | 119 |
| `viru_gate_south_tower` | `107,60` / `10 x 8` | Viru Gate throat; round tower; wall-walk `z` | 120 |
| `viru_gate_north_jamb` | `107,49` / `10 x 3` | Viru Gate throat; `tower=false` | 123 |
| `viru_gate_south_jamb` | `110,56` / `7 x 4` | Viru Gate throat; `tower=false` | 125 |
| `foregate_wall_north` | `116,49` / `10 x 2` | Foregate wall | 126 |
| `foregate_wall_south` | `116,60` / `10 x 2` | Foregate wall | 127 |
| `foregate_tower_north` | `124,43` / `6 x 6` | Foregate round tower | 130 |
| `foregate_tower_south` | `124,60` / `6 x 6` | Foregate round tower | 131 |
| `foregate_north_jamb` | `124,49` / `6 x 3` | Foregate jamb | 132 |
| `foregate_south_jamb` | `124,56` / `6 x 4` | Foregate jamb | 133 |
| `city_wall_gate_south` | `109,70` / `4 x 11` | City-wall fabric; `tower=false` | 134 |
| `wall_seal_viru_south_join` | `109,68` / `4 x 2` | City-wall fabric | 137 |
| `wall_seal_viru_south_west` | `107,70` / `2 x 11` | City-wall fabric | 138 |
| `wall_seal_viru_south_east` | `112,70` / `4 x 11` | City-wall fabric | 139 |
| `wall_seal_hinke_north` | `104,70` / `5 x 6` | City-wall fabric | 140 |
| `wall_seal_bend_a_east` | `104,81` / `2 x 6` | City-wall fabric | 141 |
| `wall_seal_bend_b_north` | `90,81` / `4 x 11` | City-wall fabric | 142 |
| `wall_seal_bend_c_west` | `76,103` / `3 x 4` | City-wall fabric | 143 |
| `wall_seal_bend_d_north` | `73,103` / `4 x 11` | City-wall fabric | 144 |
| `hinke_tower` | `104,79` / `8 x 8` | Round tower; wall-walk `z` | 145 |
| `city_wall_bend_a` | `95,81` / `9 x 4` | City-wall fabric | 146 |
| `wall_tower_southeast` | `90,81` / `6 x 8` | Round tower; wall-walk `x` | 147 |
| `city_wall_bend_b` | `90,92` / `4 x 14` | City-wall fabric | 148 |
| `wall_tower_south` | `86,100` / `8 x 8` | Round tower; wall-walk `x` | 149 |
| `city_wall_bend_c` | `76,103` / `10 x 4` | City-wall fabric | 150 |
| `wall_tower_southwest` | `73,103` / `6 x 8` | Round tower; wall-walk `x` | 151 |
| `city_wall_bend_d` | `73,107` / `4 x 14` | City-wall fabric | 152 |
| `city_wall_south_continuation` | `73,121` / `4 x 7` | City-wall fabric | 153 |
| `monastery_precinct_wall_west` | `31,0` / `2 x 19` | Monastery precinct wall | 156 |
| `monastery_precinct_wall_south_a` | `31,19` / `16 x 2` | Monastery precinct wall | 157 |
| `monastery_precinct_wall_south_b` | `52,19` / `24 x 2` | Monastery precinct wall | 158 |
| `smithy_yard_fence_north` | `95,62` / `3 x 2` | Smithy yard fence | 208 |
| `smithy_yard_fence_east` | `102,62` / `2 x 14` | Smithy yard fence | 209 |

### 1.4 View-only gate arches: 2 records

| ID | Position / footprint | Authored visual fields | Source |
|---|---:|---|---:|
| `viru_gate_arch` | `110,51` / `7 x 6` | `gate_variant=ironbound`, `grille_variant=portcullis`, `top_px=256` | 217 |
| `viru_foregate_arch` | `124,51` / `6 x 6` | `gate_variant=oak`, `top_px=176` | 219 |

The source comments explicitly state that gate arches are view-only and that collision-bearing throat walls must meet their jambs while leaving the road open.

## 2. Renderer and gameplay boundaries

### 2.1 Exceptional house registry

Evidence: [`scripts/map/view3d/map_view_mesh_builder_building_registry.gd`](../../scripts/map/view3d/map_view_mesh_builder_building_registry.gd), lines 8-60.

The registry checks only `kind=house`. It resolves exceptional category in this order:

1. Stable ID (`EXCEPTIONAL_IDS`).
2. Authored style (`EXCEPTIONAL_STYLES`).
3. Authored primitive (`EXCEPTIONAL_PRIMITIVES`).

For this map, `st_catherines_church` is the only house ID that matches the registry by stable ID and resolves to `church`. None of the 36 wall records can cross this exceptional-house boundary, including `viru_gate_north_tower` and `viru_gate_south_tower`, because the registry returns an empty category for non-house kinds.

### 2.2 Ordinary building and fortification path

Evidence: [`scripts/map/view3d/map_view_mesh_builder_buildings.gd`](../../scripts/map/view3d/map_view_mesh_builder_buildings.gd), lines 11-60 and 90-120.

`build_building()` dispatches registry-positive houses to `build_exceptional_building()`. All other records enter the default building path and receive `renderer_boundary=ordinary` metadata. This metadata names the broad default building entry point; it does not mean that a `kind=wall` record is an ordinary house.

Within that path, `kind=wall` records remain on the wall-aware default building path. Records whose authored height meets the battlement threshold enter the fortification branch; lower wall and fence records still retain wall material and wall-specific semantics without being treated as houses. Authored height, tower flags, round-tower flags, wall-walk axis, sealed-wall sizing, limestone material, battlements, and wall-walk details remain owned by the fortification-capable builder. The Lower Town wall inventory must therefore be accepted as fortification surface, not reclassified as landmark houses.

The 43 tiered houses use the ordinary house style and roof selection contract. `house_tier` is a closed allowlist of `merchant_stone`, `merchant_timber`, and `craft_boda`; omitted values remain legal for legacy or special records. The compiler rejects unknown values with `house_tier is unknown`.

### 2.3 View-landmark path

Evidence:

- [`scripts/map/map_definition.gd`](../../scripts/map/map_definition.gd), lines 4-6 and 47-49.
- [`scripts/map/view3d/map_view_mesh_builder_landmarks.gd`](../../scripts/map/view3d/map_view_mesh_builder_landmarks.gd), lines 39-72.

`gate_arch` is a member of `VIEW_LANDMARK_KINDS`. `MapDefinition` documents view landmarks as non-blocking and non-contributing to collision or navigation. `build_landmark()` creates the visual arch and gate assets only. Therefore:

- `viru_gate_arch` is not a collision wall and must be evaluated against `viru_gate_north_jamb` and `viru_gate_south_jamb`.
- `viru_foregate_arch` is not a collision wall and must be evaluated against the foregate jambs.
- Arch span, gate asset fit, opening readability, and visual occlusion are view acceptance surfaces; collision and navigation remain wall/map acceptance surfaces.

## 3. Ordinary-fabric acceptance scope

The final ordinary-fabric review should cover the 43 tiered IDs, with all three closed tiers represented on the playable Lower Town route:

| Tier | Count | Acceptance focus |
|---|---:|---|
| `merchant_stone` | 14 | Affluent stone or mixed street frontage, tile-forward material bias, readable diele/dornse massing where the kit provides it |
| `merchant_timber` | 14 | Timber or plastered-timber frontage, shingle-forward roof bias, readable merchant/craft frontage without stone landmark treatment |
| `craft_boda` | 15 | Compact workshop-dwelling massing, log/thatch or shingle bias, no merchant hoist default |

The typology contract is documented in [`docs/reports/burgher_house_typology_contract.md`](burgher_house_typology_contract.md) and [`docs/MAP_AUTHORING.md`](../MAP_AUTHORING.md). The inventory proves that all three tiers are authored and that the counts are mixed rather than single-family. It does not by itself prove:

- production-quality tier-specific mesh kits;
- plot dressing and rear-yard readability;
- repeated-facade variation under matched gameplay camera framing;
- day/night value hierarchy at gameplay scale;
- absence of ordinary-house visual drift into exceptional landmark silhouettes.

The nine untiered special/use-site houses should be reviewed separately from the 43-record ordinary tier matrix. They must not be counted as missing tier assignments unless the owning task explicitly decides that a given special record should become ordinary fabric.

## 4. Gate and fortification acceptance surfaces

### Viru Gate

The authored collision throat is represented by two tower records and two jamb records:

- `viru_gate_north_tower`, `107,41`, `10 x 8`, round tower, wall-walk `z`;
- `viru_gate_south_tower`, `107,60`, `10 x 8`, round tower, wall-walk `z`;
- `viru_gate_north_jamb`, `107,49`, `10 x 3`;
- `viru_gate_south_jamb`, `110,56`, `7 x 4`.

The view arch `viru_gate_arch` is `110,51`, `7 x 6`, with ironbound leaves and a raised portcullis. The focused map test checks that the arch longitudinal span matches the south jamb and is contained by the north jamb's span. The same test family covers wall openings, route reachability, and navigation construction.

### Foregate

The foregate has two collision-bearing wall runs, two round-tower stubs, and two jamb records. The view arch `viru_foregate_arch` is `124,51`, `6 x 6`, with an oak gate variant and `top_px=176`. The source comment records the incomplete 1343 state and the simpler oak leaves. This is a separate acceptance surface from the inner Viru Gate and must not be collapsed into one landmark record.

### Remaining wall fabric

The city-wall seals, bends, continuation, monastery precinct walls, and smithy yard fence are all authored `wall` records. They preserve stable IDs and must be checked for sealed geometry, intended embedded fence joint, wall-walk continuity where authored, and no accidental ordinary-house tier assignment.

## 5. Evidence and validation matrix

| Check | Result | Evidence / limitation |
|---|---|---|
| Authored source record extraction | **PASS** | Independent parser counted 91 records: 53 houses, 36 walls, 2 gate arches; all stable IDs are unique. |
| Tier inventory | **PASS as source evidence** | 14 `merchant_stone`, 14 `merchant_timber`, 15 `craft_boda`, 10 untiered. |
| Registry boundary review | **PASS as static evidence** | `st_catherines_church` resolves to exceptional `church`; wall-kind Viru tower IDs remain outside exceptional-house routing. |
| `test_lower_town_slice_map` focused run | **BLOCKED in current rerun** | The earlier focused baseline recorded 19/19 map-contract tests. The current checked rerun fails during dependent script loading at `map_view_3d.gd:82` because `MapViewRuntime.ZOOM_MAX_ORTHOGRAPHIC_SIZE` cannot be resolved, before map methods execute. |
| `test_burgher_house_tiers` focused run | **BLOCKED** | Current checked run executes 0 tests and reports unrelated parse errors in `map_view_monastic_models.gd:185,187,189,218` (`run`, `long_face`, and `gable_offset` scope/type cascade). |
| `test_burgher_house_typology_contract` | **Contract evidence only** | The repository contract names the closed tiers, fallback rules, and rejection diagnostic. This report does not treat contract text as visual kit acceptance. |
| Composition audit | **NOT an acceptance gate for this map** | `docs/data/map_composition_thresholds.json` sets `lower_town_slice.enforce=false`; `tools/audit_map_composition.gd` explicitly prints `SKIP` for such cards. The threshold card remains useful as review context, not a passing runtime result. |
| Final gameplay-scale day/night landmark and ordinary-fabric sign-off | **OPEN / BLOCKED** | No dedicated evidence in this audit proves the final 43-house tier presentation, all special records, St. Catherine's silhouette, and both gate arches under matched gameplay-scale day/night framing. |

Reproduction commands for the blocked focused suites:

```text
tools/run_godot_checked.sh --require-test-summary r486-lower-map \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_lower_town_slice_map

tools/run_godot_checked.sh --require-test-summary r486-house-tiers \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_burgher_house_tiers
```

The parse diagnostics are recorded as baseline blockers, not as authored-map failures. No runtime source was modified to bypass them.

## 6. Gaps and next acceptance steps

1. Clear the shared `map_view_3d.gd:82` / runtime-camera parse cascade, then rerun `test_lower_town_slice_map` and require a clean non-empty summary.
2. Repair the independent `map_view_monastic_models.gd` scope/type parse errors, then rerun `test_burgher_house_tiers`. Confirm the 43 expected ordinary IDs and the seven named untiered exceptional/special IDs covered by that focused test; review the remaining three untiered source records separately.
3. Capture matched gameplay-scale day/night views covering representative and repeated frontage from all three tiers, the nine default-path special records, `st_catherines_church`, `viru_gate_arch`, and `viru_foregate_arch`.
4. Review ordinary-fabric repetition, material hierarchy, roof readability, occlusion, gate opening readability, and route/collision clearance from those captures.
5. Keep all 36 wall IDs in the fortification acceptance set. Do not use the exceptional-house registry as a shortcut for walls or gate arches.
6. Revisit the composition threshold only when the Lower Town composition owner enables its card; a skipped `enforce=false` card must not be reported as a completed acceptance result.

## Sources

- [`content/maps/lower_town_slice.rrmap`](../../content/maps/lower_town_slice.rrmap), lines 116-219.
- [`scripts/map/view3d/map_view_mesh_builder_building_registry.gd`](../../scripts/map/view3d/map_view_mesh_builder_building_registry.gd), lines 8-60.
- [`scripts/map/view3d/map_view_mesh_builder_buildings.gd`](../../scripts/map/view3d/map_view_mesh_builder_buildings.gd), lines 11-60 and 90-120.
- [`scripts/map/view3d/map_view_mesh_builder_landmarks.gd`](../../scripts/map/view3d/map_view_mesh_builder_landmarks.gd), lines 39-72 and gate-arch builder.
- [`scripts/map/map_definition.gd`](../../scripts/map/map_definition.gd), lines 4-6 and 47-49.
- [`tests/godot/test_lower_town_slice_map.gd`](../../tests/godot/test_lower_town_slice_map.gd), including the Viru arch span test.
- [`tests/godot/test_burgher_house_tiers.gd`](../../tests/godot/test_burgher_house_tiers.gd), expected tier inventory and untiered boundary list.
- [`docs/reports/burgher_house_typology_contract.md`](burgher_house_typology_contract.md).
- [`docs/data/map_composition_thresholds.json`](../data/map_composition_thresholds.json), `lower_town_slice.enforce=false`.
