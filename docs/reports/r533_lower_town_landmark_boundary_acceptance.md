# R-533 / P0-101 landmark boundary acceptance

**Review date:** 2026-08-17
**Map:** `lower_town_slice`
**Historical target:** Spring 1343 Reval, Lower Town / Workers' District
**Status:** **BLOCKED for final visual and historical acceptance; PASS for authored boundary and runtime contracts**

## Decision

The Lower Town landmark boundary is structurally sound in the current worktree:

- all 48 required non-ordinary stable IDs are present exactly once in `content/maps/lower_town_slice.rrmap`;
- `st_catherines_church` resolves to the dedicated exceptional `church` renderer and does not use the ordinary-house `Roof` or `Chimney` nodes;
- Viru Gate towers and jambs remain collision-bearing `building ... wall` records, outside the exceptional-house registry;
- `viru_gate_arch` and `viru_foregate_arch` remain `gate_arch` view landmarks, and the focused tests verify their route/opening relationship without adding collision;
- fortification, wall-walk, checkpoint dressing, ordinary-tier exclusion, and Lower Town route contracts pass.

This does **not** close the final P0-101 art gate. Gameplay-scale matched day/night landmark approaches and named canon/art sign-off are still absent, and upstream implementation/integration rows R-488 and R-489 remain open. The final visual/historical disposition is therefore **BLOCKED**, not PASS.

## Evidence and verification

### Source inventory check - PASS

A source-level extraction of `content/maps/lower_town_slice.rrmap` found **91 authored records with 91 unique IDs**. The expected non-ordinary acceptance set contains **48 IDs; all 48 are present exactly once**:

- 10 special/exceptional buildings, including `st_catherines_church`;
- 7 inner/foregate collision and view landmark records for Viru Gate;
- 9 additional foregate/city-wall tower and gate records;
- 8 sealed wall joins;
- 4 city-wall bends;
- 3 monastery precinct walls;
- 2 smithy yard fence walls.

The source categories are preserved: the two arches are `landmark gate_arch`; collision-bearing structures are `building wall`; St. Catherine's and the nine other use-site records are `building house` records, with only St. Catherine's registered as exceptional.

### Focused contract run - PASS

Command:

```sh
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot \
  tools/run_godot_checked.sh --require-test-summary landmark-boundary-contracts \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- \
  --filter=test_lower_town_slice_map,test_map_view_3d_fortification,test_map_view_3d_mesh,test_environment_kit_integration,test_burgher_house_tiers
```

Result: **5 files, 56 tests, 0 failures, 0 errors**.

Passed contract coverage includes:

- Lower Town validation, canonical parity, boundary exits, required routes, wall blocking, Viru causeway reachability, and navigation build;
- `test_viru_gate_arch_matches_collision_jamb_span`;
- fortification tower/wall-walk rendering and character-scale gate clearance;
- checkpoint module containing both towers and exactly two view-only arches;
- exceptional renderer boundary for St. Catherine's, including dedicated church roof/details and no ordinary roof/chimney;
- ordinary house tiers and explicit rejection of wall records crossing into the exceptional-house registry.

A broader six-file run also included `test_map_composition_audit`; its 62-test result had one unrelated pre-existing failure for `monastery_quarter` (`MAP_COMPOSITION_EMPTY_REGION`, measured 25,774 vs 0-22,000). That failure is outside `lower_town_slice` and is not used to overturn the clean five-file boundary result.

### Boundary matrix - structural disposition
Every required stable ID is listed separately below. **Structural result** covers source ownership and the focused automated contracts. **Final art/history** remains blocked for every row because the required gameplay-scale day/night approach packet and named human review are not present.
| Stable ID | Surface class | Boundary contract | Structural result | Final art/history |
|---|---|---|---:|---:|
| `monastery_cloister` | special/use-site house | Untiered special mass; never ordinary tier | **PASS** | **BLOCKED** |
| `monastery_barn` | special/use-site house | Untiered service mass; never ordinary tier | **PASS** | **BLOCKED** |
| `guild_storehouse` | special/use-site house | Untiered storage mass; never ordinary tier | **PASS** | **BLOCKED** |
| `public_bathhouse` | special/use-site house | Untiered bathhouse mass; never ordinary tier | **PASS** | **BLOCKED** |
| `karja_gate_house` | special/use-site house | Untiered gate-side use-site; never ordinary tier | **PASS** | **BLOCKED** |
| `foaming_mug_brewery` | special/use-site house | Untiered production mass and approach; never ordinary tier | **PASS** | **BLOCKED** |
| `kalev_smithy` | special/use-site house | Untiered production mass and approach; never ordinary tier | **PASS** | **BLOCKED** |
| `muurivahe_house_north` | special/use-site house | Untiered wall-adjacent special boundary; never ordinary tier | **PASS** | **BLOCKED** |
| `south_apron_wall_walk_hut` | special/use-site house | Untiered wall-walk service boundary; never ordinary tier | **PASS** | **BLOCKED** |
| `st_catherines_church` | exceptional church house | Dedicated church renderer; no ordinary roof/chimney kit | **PASS** | **BLOCKED** |
| `viru_gate_north_tower` | collision-bearing fortification | Wall-kind round tower with wall-walk z | **PASS** | **BLOCKED** |
| `viru_gate_south_tower` | collision-bearing fortification | Wall-kind round tower with wall-walk z | **PASS** | **BLOCKED** |
| `viru_gate_north_jamb` | collision-bearing gate jamb | Wall-kind jamb owns inner opening boundary | **PASS** | **BLOCKED** |
| `viru_gate_south_jamb` | collision-bearing gate jamb | Wall-kind jamb owns inner opening boundary | **PASS** | **BLOCKED** |
| `viru_gate_arch` | view-only gate landmark | Gate arch aligns with jambs and adds no collision/navigation | **PASS** | **BLOCKED** |
| `foregate_wall_north` | collision-bearing foregate wall | Wall-kind incomplete foregate wall | **PASS** | **BLOCKED** |
| `foregate_wall_south` | collision-bearing foregate wall | Wall-kind incomplete foregate wall | **PASS** | **BLOCKED** |
| `foregate_tower_north` | collision-bearing fortification | Wall-kind subordinate round-tower stub | **PASS** | **BLOCKED** |
| `foregate_tower_south` | collision-bearing fortification | Wall-kind subordinate round-tower stub | **PASS** | **BLOCKED** |
| `foregate_north_jamb` | collision-bearing gate jamb | Wall-kind foregate opening boundary | **PASS** | **BLOCKED** |
| `foregate_south_jamb` | collision-bearing gate jamb | Wall-kind foregate opening boundary | **PASS** | **BLOCKED** |
| `viru_foregate_arch` | view-only gate landmark | Oak gate arch adds no collision/navigation | **PASS** | **BLOCKED** |
| `city_wall_north` | city-wall fabric | Continuous wall-kind fortification surface | **PASS** | **BLOCKED** |
| `city_wall_gate_south` | city-wall fabric | Wall-kind gate-side mass preserves route boundary | **PASS** | **BLOCKED** |
| `city_wall_south_continuation` | city-wall fabric | Wall-kind continuation preserves district edge | **PASS** | **BLOCKED** |
| `wall_tower_northeast` | round tower / wall-walk z | Round wall-kind tower and wall-walk continuity | **PASS** | **BLOCKED** |
| `wall_tower_north` | round tower / wall-walk z | Round wall-kind tower and wall-walk continuity | **PASS** | **BLOCKED** |
| `hinke_tower` | round tower / wall-walk z | Round wall-kind tower and wall-walk continuity | **PASS** | **BLOCKED** |
| `wall_tower_southeast` | round tower / wall-walk x | Round wall-kind tower and wall-walk continuity | **PASS** | **BLOCKED** |
| `wall_tower_south` | round tower / wall-walk x | Round wall-kind tower and wall-walk continuity | **PASS** | **BLOCKED** |
| `wall_tower_southwest` | round tower / wall-walk x | Round wall-kind tower and wall-walk continuity | **PASS** | **BLOCKED** |
| `wall_seal_viru_south_join` | sealed city-wall fabric | Closed wall-kind join; no route breach | **PASS** | **BLOCKED** |
| `wall_seal_viru_south_west` | sealed city-wall fabric | Closed wall-kind join; no route breach | **PASS** | **BLOCKED** |
| `wall_seal_viru_south_east` | sealed city-wall fabric | Closed wall-kind join; no route breach | **PASS** | **BLOCKED** |
| `wall_seal_hinke_north` | sealed city-wall fabric | Closed wall-kind join; no route breach | **PASS** | **BLOCKED** |
| `wall_seal_bend_a_east` | sealed city-wall fabric | Closed wall-kind join; no route breach | **PASS** | **BLOCKED** |
| `wall_seal_bend_b_north` | sealed city-wall fabric | Closed wall-kind join; no route breach | **PASS** | **BLOCKED** |
| `wall_seal_bend_c_west` | sealed city-wall fabric | Closed wall-kind join; no route breach | **PASS** | **BLOCKED** |
| `wall_seal_bend_d_north` | sealed city-wall fabric | Closed wall-kind join; no route breach | **PASS** | **BLOCKED** |
| `city_wall_bend_a` | city-wall bend | Wall-kind bend preserves fortification boundary | **PASS** | **BLOCKED** |
| `city_wall_bend_b` | city-wall bend | Wall-kind bend preserves fortification boundary | **PASS** | **BLOCKED** |
| `city_wall_bend_c` | city-wall bend | Wall-kind bend preserves fortification boundary | **PASS** | **BLOCKED** |
| `city_wall_bend_d` | city-wall bend | Wall-kind bend preserves fortification boundary | **PASS** | **BLOCKED** |
| `monastery_precinct_wall_west` | monastery precinct wall | Wall-kind precinct boundary remains separate from houses | **PASS** | **BLOCKED** |
| `monastery_precinct_wall_south_a` | monastery precinct wall | Wall-kind precinct boundary remains separate from houses | **PASS** | **BLOCKED** |
| `monastery_precinct_wall_south_b` | monastery precinct wall | Wall-kind precinct boundary remains separate from houses | **PASS** | **BLOCKED** |
| `smithy_yard_fence_north` | smithy yard fence | Wall-kind localized production boundary | **PASS** | **BLOCKED** |
| `smithy_yard_fence_east` | smithy yard fence | Wall-kind localized production boundary | **PASS** | **BLOCKED** |

### Final art/history disposition - BLOCKED

The following acceptance requirements are not proven by the structural tests:

- gameplay-scale approach captures for day and night;
- route-scale readability of every special building, tower, jamb, wall join, precinct boundary, and fence;
- proof that every silhouette is historically acceptable for Spring 1343 and contains no unsupported post-1343 form;
- named human canon and art review with per-ID observations;
- final R-488 exceptional-landmark implementation and R-489 playable-route integration handoff.

Existing whole-map, audit, and calibration images are supplementary evidence only. They do not satisfy the dedicated gameplay-scale approach contract. Keep the per-ID visual verdict **BLOCKED** until R-488/R-489 and the capture/review handoffs are complete.

## Follow-up ownership

No duplicate task is created. The blockers already have owners:

- R-488 / P0-101c: exceptional landmark implementation;
- R-489 / P0-101d: playable-route art integration;
- R-490 / P0-101e: runtime, occlusion, route, and budget QA;
- R-491 / P0-101f: matched day/night capture packet;
- R-492 / P0-101g: canon/art silhouette review;
- R-108 / P0-101: parent Lower Town art acceptance.

## References

- [`content/maps/lower_town_slice.rrmap`](../../content/maps/lower_town_slice.rrmap)
- [`docs/reports/lower_town_p0_101_landmark_inventory.md`](lower_town_p0_101_landmark_inventory.md)
- [`docs/reports/lower_town_p0_101_capture_matrix.md`](lower_town_p0_101_capture_matrix.md)
- [`docs/reports/r492_lower_town_1343_landmark_silhouette_review.md`](r492_lower_town_1343_landmark_silhouette_review.md)
- [`scripts/map/view3d/map_view_mesh_builder_building_registry.gd`](../../scripts/map/view3d/map_view_mesh_builder_building_registry.gd)
- [`scripts/map/view3d/map_view_mesh_builder_churches.gd`](../../scripts/map/view3d/map_view_mesh_builder_churches.gd)
- [`scripts/map/view3d/map_view_mesh_builder_landmarks.gd`](../../scripts/map/view3d/map_view_mesh_builder_landmarks.gd)
- [`tests/godot/test_lower_town_slice_map.gd`](../../tests/godot/test_lower_town_slice_map.gd)
- [`tests/godot/test_map_view_3d_fortification.gd`](../../tests/godot/test_map_view_3d_fortification.gd)
- [`tests/godot/test_map_view_3d_mesh.gd`](../../tests/godot/test_map_view_3d_mesh.gd)
- [`tests/godot/test_environment_kit_integration.gd`](../../tests/godot/test_environment_kit_integration.gd)
- [`tests/godot/test_burgher_house_tiers.gd`](../../tests/godot/test_burgher_house_tiers.gd)
