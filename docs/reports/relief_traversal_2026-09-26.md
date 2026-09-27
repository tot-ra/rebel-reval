# Relief traversal (WB-03, R-975)

Date: 2026-09-27 (file name keeps the contract's planned date). Contract:
[`WB-03`](../tasks/world/WB-03_relief_drives_gameplay.md). Rules:
[ADR 0023](../adr/0023-terrain-relief-as-gameplay.md) and
[`MAP_AUTHORING.md`](../MAP_AUTHORING.md) "Relief is authoritative for gameplay".

## What changed

| Area | Change |
|---|---|
| `MapTerrainMovement` | `slope_speed_multiplier()` (`cos(slope)`, clamped at 35 degrees), `is_relief_blocked_cell()` (steep 4-neighbour face or `relief_cliff` face), `relief_can_block()` fast path, single-cell `is_cliff_lowered()` |
| `MapVerification.is_walkable_cell` | Rejects relief-blocked cells, so every flood-fill audit agrees with navigation |
| `MapNavBuilder` | `relief_obstruction_rects()` obstructs the bake (thread-safe, runs on the WB-07 worker) |
| `MapSceneBootstrap` | `ReliefBlocks` static body from the same rects for keyboard and gamepad movement |
| `MapViewRuntimeCameraSafety` | A bank between camera and the player's chest counts as occlusion and triggers the existing pull-in |

Actor height needed no code change: `MapView3D.sync_actor`, the urban crowd and
the fauna already read `MapViewMeshBuilder.ground_height()`, whose base has been
the compiled relief since WB-02. `test_relief_traversal` now pins that the view
field minus the same map's flat field equals `height_at_world()` to `1e-4`.

## Walkable-cell census

Computed headlessly over every registered map with the base rule (map bounds,
water, building collision, excluded areas) and then with the relief rule. The
relief rule removed **0 cells on every map**, so navigation input, 2D collision
and every audit are unchanged. `relief_can_block()` is false for all 28 maps:
none authors `relief_*`, and the steepest datum (`elevation=2.8`) rises at most
`0.42` per cell against the `0.70` limit.

| Map | Size | Datum | Walkable before | Walkable after | Largest region |
|---|---|---|---|---|---|
| `kalev_smithy` | 26x14 | 0.0 | 271 | 271 | 271 |
| `lower_town_slice` | 152x128 | 0.0 | 13982 | 13982 | 13710 |
| `market_civic_quarter` | 114x128 | 0.0 | 7590 | 7590 | 7590 |
| `north_quarter` | 260x140 | 0.0 | 23808 | 23808 | 18876 |
| `monastery_quarter` | 260x112 | 0.0 | 24554 | 24554 | 21338 |
| `nunnatorn_interior` | 18x18 | 0.0 | 227 | 227 | 227 |
| `kuldjala_interior` | 18x16 | 0.0 | 212 | 212 | 212 |
| `rentenitorn_interior` | 18x18 | 0.0 | 252 | 252 | 252 |
| `archbishops_garden` | 144x48 | 2.8 | 5502 | 5502 | 5377 |
| `toompea_quarter` | 144x192 | 2.8 | 22974 | 22974 | 22974 |
| `south_quarter` | 336x96 | 0.0 | 26785 | 26785 | 26303 |
| `viru_gate_foreland` | 168x120 | 0.0 | 12923 | 12923 | 12923 |
| `reval_harbor_north` | 160x108 | 0.0 | 6382 | 6382 | 6333 |
| `reval_harbor_east` | 144x80 | 0.0 | 4354 | 4354 | 4326 |
| `st_olafs_guild_hall` | 32x20 | 0.0 | 540 | 540 | 540 |
| `oleviste_church` | 36x24 | 0.0 | 744 | 744 | 744 |
| `holy_spirit_church` | 30x22 | 0.0 | 564 | 564 | 564 |
| `town_hall` | 40x24 | 0.0 | 788 | 788 | 788 |
| `world.sacred_grove` | 64x36 | 0.0 | 2031 | 2031 | 2031 |
| `world.harju` | 52x30 | 0.0 | 1415 | 1415 | 1415 |
| `world.padise` | 140x90 | 0.0 | 9719 | 9719 | 9719 |
| `world.saaremaa` | 104x60 | 0.0 | 2610 | 2610 | 2606 |
| `world.rebel_kings` | 50x28 | 0.0 | 1268 | 1268 | 1268 |
| `world.kanavere` | 54x30 | 0.0 | 1566 | 1566 | 1566 |
| `world.sojamae` | 54x30 | 0.0 | 1566 | 1566 | 1566 |
| `world.paide` | 50x30 | 0.0 | 1137 | 1137 | 1137 |
| `world.parnu` | 50x28 | 0.0 | 1268 | 1268 | 1268 |
| `world.poide` | 50x30 | 0.0 | 1137 | 1137 | 1137 |

Because no cell changed, every transition, spawn and anchor keeps the
walkability and reachability the existing map suites assert
(`test_lower_town_slice_map`, the map audit and activation gates).

One deliberate runtime change on flat maps: on `toompea_quarter` and
`archbishops_garden` the `elevation=2.8` edge taper is a real visible slope, so
walking across the outer 10 cells now runs at `cos(slope)`, at worst `~0.92`.
Maps with a zero datum and no relief return a multiplier of exactly `1.0`.

## Verification run

| Check | Result |
|---|---|
| `--filter=test_relief_traversal` (11 tests: height parity, no step at cell boundaries, monotonic cost, steep cell blocked, cliff nav and collision, terrace edge walkable, cliff predicate parity, determinism, save round trip, camera bank occlusion, census) | pass |
| `test_map_relief_field`, `test_map_scene_bootstrap`, `test_map_terrain_movement`, `test_mud_weather`, `test_map_view_runtime_camera`, `test_map_camera_modes`, `test_async_location_assembly`, `test_harbor_merchant_navigation`, `test_lower_town_slice_map` | 80/80 pass together with the new suite |
| `tools/validate_map_blueprints.gd` | 28 registered, 0 errors |
| `verify_map_audit.py`, `verify_map_activation.py`, `verify_map_conversion_plan.py`, `verify_map_composition.py` | pass |

## Not done here

- **Walk clips and camera plates on an authored ramp** (keyboard and gamepad),
  and the quick performance report. No registered map authors relief until WB-04
  (R-976), and a Godot editor held the shared worktree during this change, so no
  GPU capture was taken. Tracked as a follow-up board row.
- Save/load: the save stores `location_id` and `spawn_id` only. The test proves
  the player record carries no height and that a recompiled map derives the
  same height at the same slope position.
