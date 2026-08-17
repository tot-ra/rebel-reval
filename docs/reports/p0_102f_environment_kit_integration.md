# P0-102f Environment Kit Integration

**Status:** Acceptance verification blocked by a runtime diagnostic
**Task:** R-539 (verification of P0-102f)
**Scope:** Forge, street/well, brewery, and checkpoint compositions in the Lower Town slice.

## Contract

`tests/godot/test_environment_kit_integration.gd` is the deterministic integration fixture for the four target spaces. It consumes the existing authored RRMap adapters and does not create a parallel scene or map format.

| Target space | Authored source | Shared modules exercised | Stable interfaces checked |
|---|---|---|---|
| Forge | `kalev_smithy.rrmap` | interior wall builder, anvil/furnace/bellows/hand-tool prop builders, shared cell-to-metre bridge | `anvil`, `ledger`, `bed_alcove`, `door_courtyard` |
| Street/well | `lower_town_slice.rrmap` | ordinary building builder, well and wash-tub prop builders, shared cell-to-metre bridge | `street_start`, `checkpoint_east`, `monastery_gate`, cistern props |
| Brewery | `lower_town_slice.rrmap` | ordinary building builder, brewery keg/malt/trade prop builders, shared cell-to-metre bridge | `brewery_door`, brewery storage props |
| Checkpoint | `lower_town_slice.rrmap` | fortification builder, gate stall/cart prop builders, gate landmark path | `checkpoint_west`, `checkpoint_east`, `viru_road_boundary`, `viru_watch`, `iron_convoy` |

The fixture verifies:

- all four spaces retain the shared `cell_size` and `MapViewBridge` pivot convention;
- building wall nodes use the shared material interface and generated pattern texture;
- props resolve through the shared prop builder and expose view geometry;
- view construction does not create collision or navigation nodes;
- authored anchors, routes, transitions, and patrol records remain present and reachable;
- terrain, map, transition, and patrol fingerprints remain unchanged after view construction;
- Viru gate towers remain wall/fortification records and gate arches remain separate view landmarks rather than ordinary-house substitutions.

## Acceptance checklist

| Criterion | Result | Evidence |
|---|---|---|
| Four target spaces represented | **PASS** | `test_four_target_spaces_share_one_deterministic_view_contract` covers forge, street/well, brewery, and checkpoint; 5 integration methods were discovered. |
| Shared prefab/module usage | **PASS** | Integration fixture builds `MODULE_FORGE_INTERIOR`, `MODULE_FORGE_YARD`, `MODULE_STREET_WELL`, `MODULE_BREWERY`, and `MODULE_CHECKPOINT`; shared building/prop builders and module metadata assertions pass. |
| Stable IDs and interfaces | **PASS** | Target building, prop, anchor, transition, and patrol IDs are enumerated in `_space_specs()` and the shared-contract test passes. |
| Route continuity | **PASS** | Forge work triangle, street-to-well/checkpoint/monastery, brewery entrance, and checkpoint through-route assertions pass in the integration and map suites. |
| Collision parity | **PASS** | Smithy `test_kalev_smithy_collision_parity` passes; Lower Town wall/causeway and walkability checks pass. |
| Navigation | **PASS** | Lower Town navigation-region, water exclusion, Viru causeway connectivity, and south-quarter seam tests pass. |
| No scene-specific camera/material overrides | **PASS** | View-only module metadata, deterministic signatures, shared material path, and fingerprint-preservation assertions pass. No camera or bespoke material override is introduced by the acceptance fixture. |
| Checked environment-kit suite | **BLOCKED** | 3/5 integration methods pass; 2 methods are interrupted by 6 engine diagnostics from detached gate-leaf reparenting. No assertion failure occurred. |
| Checked smithy suite | **PASS** | `test_kalev_smithy_map`: 16 tests, 0 failures, 0 errors. |
| Checked Lower Town suite | **PASS** | `test_lower_town_slice_map`: 19 tests, 0 failures, 0 errors. |

## Verification

Runs were made from the project root with Godot 4.7.1 and the checked runner, one suite per process:

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
export GODOT_LOG_DIR=/tmp/rebel-reval-r539
mkdir -p "$GODOT_LOG_DIR"

tools/run_godot_checked.sh --require-test-summary r539-environment-kit -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_environment_kit_integration

tools/run_godot_checked.sh --require-test-summary r539-smithy -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_kalev_smithy_map

tools/run_godot_checked.sh --require-test-summary r539-lower-town -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_lower_town_slice_map
```

Logs:

- `/tmp/rebel-reval-r539/r539-environment-kit.log` - `1 file, 5 tests, 0 failures, 6 errors`; checked runner status 1.
- `/tmp/rebel-reval-r539/r539-smithy.log` - `1 file, 16 tests, 0 failures, 0 errors`; checked runner status 0.
- `/tmp/rebel-reval-r539/r539-lower-town.log` - `1 file, 19 tests, 0 failures, 0 errors`; checked runner status 0.

The environment-kit blocker is emitted at `scripts/map/view3d/map_view_mesh_builder_landmarks.gd:419` while `_expose_authored_gate_leaf_contract()` executes `authored_part.reparent(root, true)` on a module that is not inside the SceneTree. This is runtime code outside R-539's verification-only allowlist and is tracked as follow-up R-565. The acceptance remains blocked until R-565 reruns the environment-kit suite cleanly.

## Boundary

This task does not claim ordinary house-tier authoring, plot dressing, new environment primitives, landmark art quality, map-density work, or day/night capture sign-off. Those remain owned by P2-063-P2-067, P0-101, and the other P0-102 handoff tasks. No runtime, test, or map source was changed by R-539.
