# P0-102i Exceptional Renderer Boundary Reverification

**Task:** R-363 / P0-102i
**Parent:** R-110 / P0-102
**Related implementation:** R-353 / P0-102e
**Date:** 2026-08-01
**Status:** **BLOCKED - R-353 implementation and focused regression are not ready for acceptance**

## Scope and decision

This is an independent QA re-verification of the ordinary-versus-exceptional renderer boundary. It checks the clean repository baseline and the current dirty R-353 worktree without claiming or modifying R-353's implementation. The boundary must keep churches, civic and guild buildings, institutions, and gatehouses out of the ordinary house renderer while preserving the existing fortification and gate-landmark paths.

The result is not an acceptance of R-353 or P0-102. The clean baseline still has one reproducible gate-landmark failure, and the current R-353 worktree has an additional test-fixture parse failure. Both findings remain with R-353.

## Verification matrix

| Check | Result | Evidence |
|---|---|---|
| Clean HEAD import | **PASS** | Detached worktree at `7d68c853fa2f1e717645fd60ef2e5a7617479105`; `Godot --headless --editor --import` completed successfully. The existing nested `generated/comfyui/forge_cat_hunyuan3d_v1/production/godot_verify/project.godot` skip warning is non-blocking. |
| Clean exceptional/fortification suite | **BLOCKED** | `test_map_view_3d_fortification`: 7/8 test methods pass. `test_town_wall_gets_battlements_and_gate_arch_clears_character` fails because `Landmark_karja_gate_arch` has no `GateDoor0`; the subsequent lookup produces null `material_override` diagnostics at `tests/godot/test_map_view_3d_fortification.gd:135-137`. |
| Clean ordinary house regression | **PASS** within the same suite | `test_houses_get_facade_doors_and_windows` passes on clean HEAD. This confirms the baseline ordinary-house assertions do not fail until the current R-353 exceptional record is introduced. |
| Clean route and wall-walk regression | **PASS** within the same suite | `test_city_wall_base_arcades_and_timber_gallery_are_character_scale`, `test_district_boundaries_use_ground_markers_and_real_neighbor_previews`, `test_district_wall_towers_render_as_circular_drums`, `test_fortification_walls_render_150_percent_taller_than_authored`, `test_viru_gate_wall_walk_access_is_visible_and_traversable`, and `test_workers_district_wall_walk_crosses_round_towers_to_the_wall_end` pass. |
| Current R-353 source boundary | **PARTIAL** | The dirty worktree adds `MapViewMeshBuilderBuildingRegistry`, routes `build_building()` through `is_exceptional()`, and tags ordinary/exceptional roots with `renderer_boundary`. The source shape is directionally correct, but it is not acceptance evidence while the focused tests fail. |
| Current R-353 fortification suite | **BLOCKED** | `test_map_view_3d_fortification` reports `st_catherines_church` failing house-only door/window/roof assertions because the test iterates every `BUILDING_KIND_HOUSE` without skipping exceptional records. It also retains the clean `karja_gate_arch` `GateDoor0` failure. |
| Current R-353 mesh suite | **BLOCKED - parse error** | `test_map_view_3d_mesh` cannot load: `MarketCivicQuarter` is undeclared and `_building_by_id()` is missing at the newly added boundary test (`tests/godot/test_map_view_3d_mesh.gd:567-569`). This is a test-fixture dependency/helper defect, not a clean-baseline result. |
| View-only and stable-ID scope | **NOT ACCEPTED** | No collision/navigation or map source changes were made by this QA task. Stable-ID and route-opening acceptance must be rerun after R-353 fixes the gate asset/node contract and test fixture. |

## Exact commands

Run from the repository root:

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT_BIN" --headless --editor --import --path .
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_map_view_3d_fortification
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_map_view_3d_mesh
```

For a clean baseline, the focused fortification command was run from a detached worktree at `/tmp/rebel-reval-p0-102i` created from the snapshot above. The captured clean log was `/tmp/r363-clean-fortification.log` during verification.

The current dirty worktree produced these diagnostic reproductions:

- `test_map_view_3d_fortification`: `st_catherines_church` house-only assertions and missing `karja_gate_arch/GateDoor0`.
- `test_map_view_3d_mesh`: parse errors for `MarketCivicQuarter` and `_building_by_id()`.

## Handoff and close decision

1. **R-353 / P0-102e:** add or expose the expected open metal Karja gate-door node (or update the focused test and renderer contract together), then rerun the fortification suite.
2. **R-353 / P0-102e:** make the new mesh boundary fixture self-contained by adding its intended market-civic fixture/helper imports or replacing them with existing fixtures; rerun `test_map_view_3d_mesh` after import.
3. **R-353 / P0-102e:** update ordinary-house assertions to skip records accepted by the exceptional registry, or provide a separate exceptional assertion path; do not weaken the boundary by routing landmarks through the ordinary house kit.
4. **R-364 / P0-102l:** consume this report together with P0-102j and P0-102k. Do not close P0-102 while this owned prerequisite remains blocked.

**Decision:** keep R-363 in `in_review`. The clean baseline and current-WIP failures are independently reproducible, but the exceptional renderer boundary is not ready to accept.
