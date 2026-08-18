# R-587 Lower Town playable-route integration verification

**Task:** R-587 / P0-101 decomposition: verify playable-route integration
**Parent:** R-108 / P0-101
**Dependencies:** R-489 (`in_progress`), R-534 (`in_review`)
**Verification date:** 2026-08-19
**Checkout:** `e3e04e8dfe82e72ee1c15bcab6165ad03a6b2915`, shared worktree dirty with unrelated staged, modified, and untracked WIP
**Decision:** **BLOCKED - structural route contracts are mostly green, but current authored-map parity and reviewed chunk ownership are not reconciled; gameplay-scale visual acceptance remains separate and open.**

## Scope and evidence boundary

This is a verification-only pass. No map geometry, stable ID, runtime builder, camera behavior, collision/navigation rule, parity fixture, or asset was changed for R-587. The current checkout already contains an uncommitted Lower Town source change marked `R-547` and a changed capture packet; those files are recorded as inputs, not modified by this task.

A structural `PASS` below means that the named focused contract passed in the current checkout. It does not prove an R-489 before/after comparison, visual occlusion review, historical/art sign-off, or minimum-hardware performance acceptance. The canonical parity fixture is a reference contract, not an archived pre-integration baseline.

## Route matrix

The map source currently exposes 17 anchors, one playable spawn, seven transitions, and two patrol routes. The route endpoint test starts at `street_start` and checks every required Lower Town approach listed below.

| Route / approach | Stable anchors and interaction context | Transition / patrol context | Collision and navigation | Parity / visual result |
|---|---|---|---|---|
| Playable spawn -> Kalev smithy | `street_start` -> `smithy_door`; `workers_yard`; smithy door is attached to `kalev_smithy` south facade | `smithy_door_transition` -> `forge`, destination spawn `door_courtyard`; `viru_watch` covers the central east-west and south route | **PASS**: route endpoint, facade attachment, readable courtyard apron, wall blocking, and navigation connectivity assertions pass | **BLOCKED** by Lower Town canonical parity drift; `service_yard` day/night packet pair is valid capture evidence only |
| Playable spawn -> brewery / craft lane | `brewery_door`, `customers_street`, `mart_street`; brewery approach is represented by the `merchant_craft_lane` packet preset | No additional scene transition; `iron_convoy` includes the market spine and `viru_watch` continues through the working district | **PASS** through `test_lower_town_required_route_endpoints_reachable`; service-yard and route-dressing tests pass | **PASS for packet integrity only**: matched day/night output exists; no stable-ID visual review of every visible tier/material |
| Playable spawn -> west checkpoint and Viru Gate approach | `checkpoint_west`, `watch_west_checkpoint`, `merchants_market`; gate approach target is `checkpoint_east` | `viru_road_boundary` leads to `viru_gate_foreland`; `viru_watch` patrol includes `110,53 -> 80,53 -> 65,53` | **PASS**: wall exclusion, Viru causeway opening, route connectivity, water exclusion, and arch-to-jamb span assertions pass | **PASS for packet integrity only**: `landmark_approaches` has matched day/night plates; inner/foregate surface-by-surface review is **BLOCKED** |
| Playable spawn -> east checkpoint / cistern margin | `checkpoint_east`, `watch_east_checkpoint`; `cistern` prop at authored cell `(104,60)` with `wet_cistern` view-only decal | `viru_watch` continues through `65,75 -> 65,88 -> 65,116`; `to_reval_south` remains the southern external transition | **PASS** for endpoint, water, wall, and navigation contracts; no separate direct cistern interaction assertion exists in the focused route suite | **BLOCKED** for final acceptance: `eastern_artisan_wet_margin` packet pair is present, but does not provide per-surface visual sign-off |
| Playable spawn -> `katariina_kaik` and `monastery_gate` | `katariina_kaik`, `monastery_gate`, `vene_street_north` | `vene_district_boundary` leads to `reval_monastery`; `vana_turg_boundary` leads to `reval_center` | **PASS**: all required endpoint routes are reported reachable by `test_lower_town_required_route_endpoints_reachable` | **BLOCKED** by the same current parity drift; `market_primary_spine` packet pair proves reproducible framing only |
| Playable spawn -> Karja / south seam | `karja_gate_south`, `south_quarter_lane`, `carriers_lane` | `to_reval_south` leads to `reval_south`; Karja remains an internal district seam rather than an invented gate shortcut | **PASS**: south seam walkability and navigation connectivity assertions pass; service-yard route suite is 3/3 | **BLOCKED** for final art acceptance; `eastern_artisan_wet_margin` is non-blank matched evidence, not human visual review |
| Smithy interior continuation | Exterior `smithy_door` -> interior `anvil`, `ledger`, `bed_alcove`; `smithy_start` spawn remains centered | `forge` scene exposes `door_courtyard` and `smithy_start` stable spawns | **PASS**: `test_kalev_smithy_map` is 16/16, including collision parity, protected routes, domestic/forge separation, and door alignment | **PASS** for the focused interior contract; not a substitute for exterior Lower Town parity or visual handoff |

## Focused verification results

All commands used Godot 4.7.1 and `tools/run_godot_checked.sh` with the documented DEF-002 shutdown-only allowance.

| Check | Result | Evidence |
|---|---|---|
| Lower Town map contract | **BLOCKED: 18/19** | `test_lower_town_slice_map`: all route, collision, navigation, wall, water, anchor, and view-only decal tests pass; `test_lower_town_slice_matches_canonical_parity_fixture` fails at line 185 because current serialized data has `door_side` where the fixture expects `footprint`. |
| Kalev Smithy contract | **PASS: 16/16** | `test_kalev_smithy_map`: zero failures and zero errors. |
| Transition manifest | **PASS: 3/3** | Release/development scene IDs and Lower Town / forge stable spawns resolve. |
| Lower Town service-yard route dressing | **PASS: 3/3** | Routes and interaction approaches stay open; drainage is view-only; authored fences, sheds, fuel, and greenery are present. |
| Terrain chunk residency | **PASS: 6/6** | `test_map_terrain_chunks` passes all residency, reload, overlay-order, and resident-bound checks. |
| Object chunk ownership / streaming | **BLOCKED: 6/7** | Lifecycle, duplicate-ID, reload, state-delta, and complete-renderer-output checks pass. Reviewed production ownership fails because current Lower Town adds boundary records such as `coopers_rear_workshop`, `rope_makers_rear_store`, and `smithy_rear_shed` while `object_chunk_streaming_readiness_p0_067c.json` remains unchanged. |
| Conversion parity | **BLOCKED** | `lower_town_slice` anchor accounting is 11/11 and Kalev Smithy is 3/3, but the command exits 1 because its focused Lower Town parity filter reproduces the 18/19 failure. |
| Capture packet contract | **PASS: 5/5** | `test_capture_lower_town_p0_101` passes. Current manifest has 10 plates across five presets, all five have matched day/night framing keys, and all listed outputs exist. |

Known Godot shutdown `ObjectDB` and resource-leak diagnostics occur after green focused summaries. They were allowed by the checked runner and are not counted as test failures.

## Current authored and packet drift

The current working tree is not a before/after baseline for R-489. The uncommitted `content/maps/lower_town_slice.rrmap` change adds rear property lanes, eight rear/workroom building records, service-yard props, and view-only decals. The current source inventory is 97 building records and 45 props, compared with the older fixture's 89 buildings and 37 props. The parity fixture itself is not modified by this task.

The current capture manifest also differs from the older R-534 packet: it records five presets and ten plates, including `market_primary_spine`, `merchant_craft_lane`, `service_yard`, `eastern_artisan_wet_margin`, and `landmark_approaches`. All ten current output paths exist and pass the focused packet contract. The manifest fingerprint is `8aaad06a1d88bce339ae1ccf809e303a0d31707e52bd6f53d67eb43f289e525c`; this is packet metadata, not proof that the canonical gameplay fixture matches.

The current authored RRMap SHA-256 is `5e4f42eb3ec45b7e7796404e38904bfbb33792cea91e58b7981544f9aa104b1c`; the parity fixture SHA-256 is `c194ea00ab01e81d5d3deea98139677e66e5dc6803747c2bd450c692ef8fa709`. These hashes use different file formats and are included only to identify the verified inputs, not as interchangeable fingerprints.

## Visual and baseline acceptance boundary

The route packet is structurally valid and reproducible, but it does not close the visual clause:

- no independent archived R-489 pre-integration baseline was found;
- the route manifest identifies anchors and camera presets, but not every visible house tier, material, roof, wear state, special building, or wall surface;
- no surface-by-surface gameplay-scale occlusion review or named canon/art sign-off is present;
- the current dirty source and deleted/replaced older packet files prevent claiming a clean historical before/after comparison.

Therefore the result is **structural partial PASS / final acceptance BLOCKED**. Keep R-489 and R-108 open. Existing owners R-489, R-534, the map-source owner responsible for the current R-547 changes, and the visual-review owners remain sufficient; no duplicate follow-up task is created.

## Reproduction commands

```bash
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
export GODOT_LOG_DIR=/tmp/r587_lower_town

bash tools/run_godot_checked.sh --require-test-summary r587-lower-town-map -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_lower_town_slice_map

bash tools/run_godot_checked.sh --require-test-summary r587-kalev-smithy -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_kalev_smithy_map

bash tools/run_godot_checked.sh --require-test-summary r587-transition-manifest -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_transition_manifest

bash tools/run_godot_checked.sh --require-test-summary r587-capture-contract -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_capture_lower_town_p0_101

python3 tools/verify_map_conversion_parity.py
```

## Sources

- [`content/maps/lower_town_slice.rrmap`](../../content/maps/lower_town_slice.rrmap)
- [`tests/fixtures/maps/lower_town_slice.parity.json`](../../tests/fixtures/maps/lower_town_slice.parity.json)
- [`tests/fixtures/maps/object_chunk_streaming_readiness_p0_067c.json`](../../tests/fixtures/maps/object_chunk_streaming_readiness_p0_067c.json)
- [`tests/godot/test_lower_town_slice_map.gd`](../../tests/godot/test_lower_town_slice_map.gd)
- [`tests/godot/test_kalev_smithy_map.gd`](../../tests/godot/test_kalev_smithy_map.gd)
- [`tests/godot/test_transition_manifest.gd`](../../tests/godot/test_transition_manifest.gd)
- [`tests/godot/test_capture_lower_town_p0_101.gd`](../../tests/godot/test_capture_lower_town_p0_101.gd)
- [`tests/godot/test_lower_town_service_yards.gd`](../../tests/godot/test_lower_town_service_yards.gd)
- [`tests/godot/test_map_terrain_chunks.gd`](../../tests/godot/test_map_terrain_chunks.gd)
- [`tests/godot/test_map_object_chunk_streaming.gd`](../../tests/godot/test_map_object_chunk_streaming.gd)
- [`tools/verify_map_conversion_parity.py`](../../tools/verify_map_conversion_parity.py)
- [`docs/reports/images/lower_town_p0_101/capture_manifest.json`](images/lower_town_p0_101/capture_manifest.json)
- [`docs/reports/r534_lower_town_route_integration_verification.md`](r534_lower_town_route_integration_verification.md)
- [`docs/reports/lower_town_p0_101_capture_matrix.md`](lower_town_p0_101_capture_matrix.md)
- [`docs/reports/lower_town_p0_101_runtime_qa.md`](lower_town_p0_101_runtime_qa.md)
