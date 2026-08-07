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

**Status: BLOCKED by one reproducible harbour navigation defect.**

The focused suite now loads and reports **5/6 acceptance tests passing**. The remaining failure is a real navigation blocker on `reval_harbor_east`:

```text
NavigationPolygon polygon convex partition failed. Unable to create a valid navigation mesh polygon layout from provided source geometry.
at res://scripts/map/map_nav_builder.gd:41
FAIL ... test_deep_and_shallow_water_are_excluded_from_navigation - reval_harbor_east navigation must contain polygons
Godot headless tests: 1 file(s), 6 test(s), 1 failure(s), 1 error(s).
```

The five passing checks are canonical RRMap round-trip, evidence-bounded confidence metadata, timber landing/salvage routes, building collision parity, and harbour location/world-state save/reload. The failure is not waived: an empty East navigation polygon cannot prove deep/shallow water exclusion or safe traversal. Follow-up `R-456` owns the navigation bake fix; rerun this acceptance after that fix.

A separate baseline attempt also reached Godot import with an unrelated dirty-tree preload missing:

```text
Parse Error: Preload file "res://assets/materials/pbr/smithy_floor/smithy_floor_albedo.png" has no resource loaders (unrecognized file extension).
at res://scripts/map/view3d/map_view_materials.gd:25
```

That import cascade is outside the R-101 allowed files and is recorded separately from the scoped East navigation finding. The focused test invocation itself ran after the project loaded enough to execute all six methods.

## Severity policy

- **Blocker:** Godot cannot load the project or the focused acceptance suite, or a required harbour route/water exclusion/save identity fails.
- **High:** shore confidence metadata, canonical fingerprint, collision parity, or clean save/reload fails while the project otherwise loads.
- **Medium:** a non-critical presentation or regression assertion fails without invalidating the evidence-bounded route or water boundary.
- **Non-blocking:** only the documented DEF-002 shutdown resource/RID diagnostics appear after an otherwise clean checked run.

The unrelated import blocker is not duplicated into the task board. The scoped East navigation defect is tracked as `R-456` (p1, complexity 2). The parent P0-168 map task remains the source owner, while this QA row should be re-run and only then moved to review/done based on the matrix above.
