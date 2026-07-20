# P0-067c: playable-slice object chunk streaming readiness

Recorded: 2026-07-21  
Task: `P0-067c`  
Maps: `kalev_smithy`, `lower_town_slice`  
Production chunk size: 32x32 cells (`MapTerrainGrid.DEFAULT_CHUNK_SIZE_CELLS`)

## Decision

Object chunk streaming is production-ready on the two active playable slice maps, `kalev_smithy` and `lower_town_slice`.

The retained `MAP_CHUNK_BOUNDARY_AMBIGUOUS` diagnostics remain visible because they deliberately use the more conservative 16x16 planning grid. At the production 32x32 runtime size, every reviewed runtime subject has deterministic ADR 0010 ownership:

- area records enumerate every intersecting half-open consumer chunk;
- the first consumer in `(y, x)` order is the single authoritative owner;
- streamed buildings create one complete instance while any consumer is resident;
- transitions remain persistent and available independent of decorative residency;
- exclusions remain baked static navigation data and never become streamable authority;
- chunk coordinates remain disposable and do not alter stable IDs or save handles.

No geometry was split for this gate. Continuous forge walls, houses, fortifications, and the Workers' District transition retain the layouts accepted by the preceding map reviews and parity tests.

## Reviewed evidence

The readiness review uses the current committed map sources and the existing reviewed captures:

- [`images/map_audit/kalev_smithy.png`](./images/map_audit/kalev_smithy.png)
- [`images/map_audit/lower_town_slice.png`](./images/map_audit/lower_town_slice.png)
- [`images/view3d/lower_town_slice_day.png`](./images/view3d/lower_town_slice_day.png)
- [`images/view3d/lower_town_slice_night.png`](./images/view3d/lower_town_slice_night.png)
- [`reval_district_reshape_p0_068.md`](./reval_district_reshape_p0_068.md), including its reviewed semantic alignment and the shortened Workers' District footprint

The executable ownership inventory is [`tests/fixtures/maps/object_chunk_streaming_readiness_p0_067c.json`](../../tests/fixtures/maps/object_chunk_streaming_readiness_p0_067c.json). It records every current 16x16 warning subject with its authored cell rectangle, runtime kind, 32x32 owner, ordered consumers, and residency. `test_playable_slice_boundary_warnings_have_reviewed_production_ownership` requires exact equality with compiler diagnostics and the runtime index, so a new, removed, resized, or reassigned subject requires an explicit fixture diff and renewed review.

The P0-067b report remains the historical planning-grid decision. Its 54-row Lower Town inventory predates the final P0-068 Workers' District geometry. The current compiler emits 66 Lower Town warnings; the P0-067c fixture is authoritative for production readiness.

## Production inventory summary

| Map | 16x16 warnings | Streamed buildings | Buildings in one 32x32 chunk | Buildings crossing 32x32 chunks | Persistent transitions | Baked exclusions |
|---|---:|---:|---:|---:|---:|---:|
| `kalev_smithy` | 3 | 2 | 2 | 0 | 0 | 1 |
| `lower_town_slice` | 66 | 65 | 27 | 38 | 1 | 0 |

The smithy exclusion is intentionally absent from `MapChunkRuntimeIndex`; the test proves that every cell in its reviewed rectangle remains present in `MapVerification.blocked_cells`. Lower Town's `to_reval_south` is present in both intersecting consumers but uses persistent residency and one owner.

## Lifecycle, parity, and route proof

`test_playable_slice_streaming_preserves_complete_current_renderer_output` now exercises both playable maps. Loading all production terrain chunks must:

- load every building and prop exactly once;
- retain each building's full authored footprint and renderer anchor;
- produce no duplicate stable IDs;
- use the same 32x32 chunk size reviewed by this gate.

Map content and routes remain protected by the existing slice tests:

- `test_kalev_smithy_map.gd` validates the map, collision parity, and routes from spawn to the anvil, ledger, bed alcove, and courtyard door;
- `test_lower_town_slice_map.gd` compares the canonical parity fixture and verifies required street, smithy, brewery, checkpoint, gate, monastery, and district-seam routes;
- the map pipeline audit recompiles registered sources and continues to print retained warnings for review.

Verification commands:

```bash
tools/run_godot_checked.sh --require-test-summary p0-067c-object-streaming \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_map_object_chunk_streaming

tools/run_godot_checked.sh --require-test-summary p0-067c-slice-routes \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- \
  --filter=test_kalev_smithy_map,test_lower_town_slice_map

GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot tools/run_map_pipeline_ci.sh audit
```

## Scope boundary

This gate approves the implemented object residency/index lifecycle on the two playable slice maps. It does not approve seamless-world streaming, production coarse A*, or activation of prototype maps. `market_civic_quarter` and the P0-067a prototype set remain blocked by their own activation reviews.
