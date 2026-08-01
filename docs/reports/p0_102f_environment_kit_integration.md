# P0-102f Environment Kit Integration

**Status:** Implemented acceptance fixture
**Task:** R-355 / P0-102f
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

## Verification

Run the focused suite from the project root:

```sh
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_environment_kit_integration
```

The harness filter selects the test file, so both acceptance methods in the fixture run. The broader map/view suites should continue to provide the existing per-system regression coverage.

## Boundary

This task does not claim ordinary house-tier authoring, plot dressing, new environment primitives, landmark art quality, map-density work, or day/night capture sign-off. Those remain owned by P2-063-P2-067, P0-101, and the other P0-102 handoff tasks.
