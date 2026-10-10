# R-1110 Godot gate triage (R-1154)

Status: report only. No runtime or test changes were made. Date: 2026-10-10.

## Command and result

```
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd
```

- Wall time 208 s, exit code 1, no watchdog involved. The R-1110 exit124 (600 s) did not reproduce.
- `discovered 402 file(s)`, ran 400 files, 2439 tests, **362 failures, 1175 errors**. 56 files report at least one FAIL/ERROR. The 2-file gap between discovered and run was not investigated.
- Worktree was dirty (about 353 modified/untracked paths from other sessions), so this is not a clean-checkout baseline. A clean checkout was not attempted (needs a fresh `--import`).

## R-1110 observations

| R-1110 observation | Result now |
|---|---|
| `test_building_surface_pbr`, `test_capture_lower_town_p0_101`, `test_character_rig` | Files no longer exist: deleted in commit 22811a3c (retired Lower Town scenes, 2026-10-08). Stale observation. |
| `test_combat_room` | Passes alone: 9 tests, 0 failures. |
| 600 s runtime | Full suite now 208 s. |

## Reproducible failures (alone and in the full run)

Re-run individually with `-- --filter=<stem>`; all reproduce, so they are not order contamination.

| File | Alone | Cause |
|---|---|---|
| `test_world_seam_crossing` | 96 fail, 2 err (99 in full run) | "world layout requires at least one map"; retired maps missing |
| `test_map_view_plant_species` | 55 fail | `content/maps/archbishops_garden.rrmap`, `monastery_quarter.rrmap` do not exist (HEAD has only 11 `.rrmap` files) |
| `test_world_map_overlay` | 19 fail, 203 err | same family |
| `test_burgher_house_craft_boda` (also `_merchant_stone`, `_merchant_timber`) | 18 fail | `generated/blender/burgher_house_*_v1/{brief,report,state}.json` not in HEAD |
| `test_map_alignment_math` | 18 fail, 1 err | map content missing |
| `test_bitter_brew_commission` | 1 fail alone (2 in full) | bed stays locked after commission resolves; possible real regression |

Other failing files (see `build/r1154/full.log`, local and ignored): `test_r454_elevation_scope`, `test_map_quality_audit`, `test_r503_elevation_gameplay_invariants`, `test_world_items`, `test_toompea_1343_fabric_contract`, `test_relief_traversal`, `test_map_relief_field`, `test_map_composition_audit`, `test_world_host_*`, the input-binding pair `test_act1_packaged_acceptance` / `test_act1_release_acceptance` (`ui_shift` has no gamepad binding), and about 35 smaller ones. These were not individually reproduced.

## Attribution

The dominant cause is committed state: tests still reference maps and generated Blender evidence that HEAD no longer contains after 22811a3c. This is stale tests, not WIP contamination. The gamepad binding failure and `test_bitter_brew_commission` look like real behavior defects and need Dev triage.

## Follow-ups

Dev tasks are listed on the task board under R-1154. R-874 (broad acceptance) keeps ownership of map visual gates.
