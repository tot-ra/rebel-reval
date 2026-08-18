# P0-102f Environment Kit Integration

**Status:** Acceptance verification partially blocked by adjacent Lower Town parity drift
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
| Checked environment-kit suite | **PASS** | Current live checkout: `test_environment_kit_integration`: 5 tests, 0 failures, 0 errors, 0 unexpected diagnostics; R-565's detached gate-leaf runtime blocker is resolved. |
| Checked smithy suite | **PASS** | Current live checkout: `test_kalev_smithy_map`: 16 tests, 0 failures, 0 errors. |
| Checked Lower Town suite | **BLOCKED - adjacent map WIP** | Current live checkout: 19 tests, 18 pass, 1 failure in `test_lower_town_slice_matches_canonical_parity_fixture`; the fixture is unchanged while the dirty `content/maps/lower_town_slice.rrmap` contains adjacent service-yard/rear-workroom authoring. The remaining 18 Lower Town tests pass. |

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

- `/tmp/rebel-reval-r539-rerun/r539-environment-kit-rerun.log` - `1 file, 5 tests, 0 failures, 0 errors`; checked runner status 0.
- `/tmp/rebel-reval-r539-rerun/r539-smithy-rerun.log` - `1 file, 16 tests, 0 failures, 0 errors`; checked runner status 0.
- `/tmp/rebel-reval-r539-rerun/r539-lower-town-rerun.log` - `1 file, 19 tests, 1 failure, 0 errors`; checked runner status 1. The failure is the canonical parity comparison at `test_lower_town_slice_matches_canonical_parity_fixture`; all other 18 tests pass.

The previous detached gate-leaf diagnostic is resolved by completed follow-up R-565. The remaining acceptance blocker is outside R-539's verification allowlist: the live `content/maps/lower_town_slice.rrmap` has adjacent Lower Town authoring changes (rear property lanes, workrooms, service-yard props, and view-only wear), while `tests/fixtures/maps/lower_town_slice.parity.json` remains unchanged. R-539 does not regenerate or edit that fixture. Re-run this acceptance after the owning Lower Town authoring/parity work (R-547 and dependent R-550/R-552/R-553) lands or is explicitly isolated; do not promote the current 18/19 map-suite result to a clean parity pass.

A detached `HEAD` baseline was also checked after Godot import. It is not a valid substitute for the live authored adapter state: the older snapshot rejects current `elevation_area`/`elevation_ramp` map commands and produces cascading missing-definition failures. Those diagnostics are recorded as baseline age, not attributed to the environment-kit modules.

## Boundary

This task does not claim ordinary house-tier authoring, plot dressing, new environment primitives, landmark art quality, map-density work, day/night capture sign-off, or parity regeneration for adjacent Lower Town authoring. Those remain owned by P2-063-P2-067, P0-101, R-547 and the dependent Lower Town closeout tasks. R-539 changed only this acceptance report; no runtime, test, map source, or parity fixture was changed.
