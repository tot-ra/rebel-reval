# P0-169 Harbour Shoreline Acceptance

## Scope

R-101 / P0-169 is an independent QA acceptance for the evidence-bounded shoreline authored by R-100 / P0-168. The acceptance does not change GIS evidence, RRMap sources, runtime movement, collision code, navigation code, or canon. Its only production files are the focused Godot suite and this report.

## Acceptance matrix

| Area | Test coverage | Acceptance rule |
|---|---|---|
| GeoJSON-bounded authoring contract | `test_rrmaps_preserve_evidence_bounded_shore_contract` | Both inactive harbour RRMaps parse, retain `shore.reconstructed_water` and `shore.reconstructed_reed`, label them `reconstructed`, use shallow-water/mud terrain, and keep an open deep-water sample separate. |
| RRMap serializer stability | `test_rrmap_canonical_round_trip_preserves_shore_fingerprint_and_metadata` | Canonical print and parse preserve the map fingerprint and all shore-confidence zone records. |
| Shore readability and traversal | `test_harbour_landings_and_salvage_routes_stay_walkable` | Authored timber landings remain walkable and exact routes reach the landing tips and quay/shore anchors. No wet-margin record may erase the required salvage approach. |
| Collision and navigation | `test_deep_and_shallow_water_are_excluded_from_navigation`, `test_harbour_buildings_keep_collision_parity` | Deep and shallow water are outside baked navigation polygons, navigation retains the player capsule radius, terrain fingerprints remain unchanged, and building collision rectangles match authored footprints. |
| Clean save/reload | `test_harbour_location_and_world_state_survive_clean_save_reload` | Harbour location/spawn, phase, acceptance flag, and stable map world-state metadata survive a SaveService file round-trip. |

## Evidence and commands

The intended focused commands are:

```text
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --editor --import
tools/run_godot_checked.sh --require-test-summary p0-169-harbour-shoreline -- /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_harbour_shoreline_acceptance
tools/run_godot_checked.sh --require-test-summary p0-169-harbour-regression -- /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_reval_harbor_map,test_coastal_sea_3d
```

Each command must be run from the repository root. The checked runner must report a non-empty final summary with zero failures and zero errors; shutdown-only resource/RID leak lines remain the documented DEF-002 noise.

## Current result

**Status: PASS (2026-09-25).**

The focused suite reports **6/6 acceptance tests passing** on Godot 4.7.1 headless:

```text
tools/run_godot_checked.sh --require-test-summary p0-169-harbour-shoreline -- /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_harbour_shoreline_acceptance
Godot headless tests: 1 file(s), 6 test(s), 0 failure(s), 0 error(s).
```

The save/reload row now seeds default `magic_resources` before snapshotting the expected payload so the check stays scoped to harbour `map_world_state` rather than serializer hydration defaults.

## Severity policy

- **Blocker:** Godot cannot load the project or the focused acceptance suite, or a required harbour route/water exclusion/save identity fails.
- **High:** shore confidence metadata, canonical fingerprint, collision parity, or clean save/reload fails while the project otherwise loads.
- **Medium:** a non-critical presentation or regression assertion fails without invalidating the evidence-bounded route or water boundary.
- **Non-blocking:** only the documented DEF-002 shutdown resource/RID diagnostics appear after an otherwise clean checked run.

R-101 may close on this matrix. Parent shoreline authoring remains `R-100` / P0-168 until map owners sign visual evidence.
