# P0-067b: retained MAP_CHUNK_BOUNDARY_AMBIGUOUS decisions (slice and remaining registry maps)

Recorded: 2026-07-20  
Task: `P0-067b`  
Maps: `kalev_smithy`, `lower_town_slice`, `market_civic_quarter`  
Audit evidence: `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot tools/run_map_pipeline_ci.sh audit` (0 errors; warnings retained below)

## Decision

Retain every listed `MAP_CHUNK_BOUNDARY_AMBIGUOUS` warning on these maps. Do not suppress the diagnostic code, and do not rewrite continuous forge walls, city-wall runs, gate houses, brewery/smithy footprints, or civic landmarks solely to quiet the 16x16 planning-grid review.

Ownership when object chunk streaming is used follows [ADR 0010](../adr/0010-large-map-runtime-chunking.md) section 4 and `MapChunkRuntimeIndex`:

- Area subjects (buildings, exclusions, transitions) are owned by the lexicographically smallest intersecting chunk under half-open bounds, ordered as `(y, x)`.
- Transitions remain `RESIDENCY_PERSISTENT` so gameplay doors stay available independent of decorative residency.
- Stable IDs are unchanged; chunk coordinates are disposable runtime hints, never save identity.

Rationale:

1. `kalev_smithy` and `lower_town_slice` are the approved playable demo/slice maps. They already load as complete compiled maps. Object chunk streaming is not yet treated as production-ready on them; these warnings are an ownership record before that readiness gate, not a layout defect.
2. `market_civic_quarter` remains an inactive/dev-gated prototype (`active=false`) that still emits planning-grid warnings after P0-067a; it is owned here so the registry has no undocumented `MAP_CHUNK_BOUNDARY_AMBIGUOUS` subjects.
3. The semantic warning uses a fixed 16x16-cell planning grid (`MapBlueprintSemanticValidator.FUTURE_CHUNK_SIZE_CELLS`). Runtime terrain/object chunking defaults to 32x32 cells (`MapTerrainGrid.DEFAULT_CHUNK_SIZE_CELLS`). Crossing the planning grid is a review signal, not proof that ownership is undefined at runtime.
4. Splitting continuous walls, foregate runs, smithy shells, brewery massing, or Town Hall footprints would risk spawn, patrol, transition, and slice-parity regressions without a ticket that names allowed geometry edits and re-runs parity/route checks.

Production gate: do not treat object chunk streaming as production-ready on `kalev_smithy` or `lower_town_slice` until a later task either (a) splits the listed subjects into single-owner footprints with parity/route proof, or (b) re-asserts this ownership decision against the production 32x32 chunk size after a human map review. Keep `market_civic_quarter` activation blocked until its own activation ticket revisits this list.

Related owned decisions: prototype maps under P0-067a / [`map_chunk_boundary_review_p0_067a.md`](./map_chunk_boundary_review_p0_067a.md).

## Subject inventory

Planning-grid chunk spans are `(first_chunk)-(last_chunk)` at 16x16 cells, copied from the audit line for each subject.

### `kalev_smithy` (3 retained warnings)

| Subject | Kind | Planning chunks (16x16) | Owner policy |
|---|---|---|---|
| `excluded.000` | excluded_area | `(0, 0)-(1, 0)` | ADR 0010 lex-smallest intersecting chunk |
| `wall.north_forge/segment.000` | building | `(0, 0)-(1, 0)` | ADR 0010 lex-smallest intersecting chunk |
| `wall.south_forge` | building | `(0, 0)-(1, 0)` | ADR 0010 lex-smallest intersecting chunk |

### `lower_town_slice` (54 retained warnings)

| Subject | Kind | Planning chunks (16x16) | Owner policy |
|---|---|---|---|
| `city_wall_bend_a` | building | `(6, 3)-(7, 3)` | ADR 0010 lex-smallest intersecting chunk |
| `city_wall_bend_c` | building | `(5, 4)-(6, 4)` | ADR 0010 lex-smallest intersecting chunk |
| `city_wall_gate_south` | building | `(7, 3)-(8, 3)` | ADR 0010 lex-smallest intersecting chunk |
| `city_wall_north` | building | `(8, 0)-(8, 1)` | ADR 0010 lex-smallest intersecting chunk |
| `city_wall_southwest` | building | `(0, 6)-(3, 6)` | ADR 0010 lex-smallest intersecting chunk |
| `coopers_house` | building | `(1, 2)-(2, 3)` | ADR 0010 lex-smallest intersecting chunk |
| `corner_house_muurivahe` | building | `(6, 1)-(7, 1)` | ADR 0010 lex-smallest intersecting chunk |
| `foaming_mug_brewery` | building | `(5, 2)-(6, 3)` | ADR 0010 lex-smallest intersecting chunk |
| `foregate_tower_south` | building | `(9, 2)-(9, 3)` | ADR 0010 lex-smallest intersecting chunk |
| `foregate_wall_north` | building | `(8, 2)-(9, 2)` | ADR 0010 lex-smallest intersecting chunk |
| `foregate_wall_south` | building | `(8, 2)-(9, 2)` | ADR 0010 lex-smallest intersecting chunk |
| `glassblowers_house` | building | `(4, 2)-(5, 3)` | ADR 0010 lex-smallest intersecting chunk |
| `hedge_house` | building | `(0, 4)-(0, 5)` | ADR 0010 lex-smallest intersecting chunk |
| `hinke_tower` | building | `(7, 3)-(7, 4)` | ADR 0010 lex-smallest intersecting chunk |
| `kalev_smithy` | building | `(6, 2)-(6, 3)` | ADR 0010 lex-smallest intersecting chunk |
| `karja_corner_house` | building | `(3, 2)-(4, 3)` | ADR 0010 lex-smallest intersecting chunk |
| `karja_gate_east_tower` | building | `(4, 5)-(5, 6)` | ADR 0010 lex-smallest intersecting chunk |
| `karja_gate_west_tower` | building | `(4, 5)-(4, 6)` | ADR 0010 lex-smallest intersecting chunk |
| `kuninga_house_mid` | building | `(1, 3)-(2, 3)` | ADR 0010 lex-smallest intersecting chunk |
| `laundress_house` | building | `(1, 4)-(2, 4)` | ADR 0010 lex-smallest intersecting chunk |
| `market_row_house` | building | `(0, 0)-(0, 1)` | ADR 0010 lex-smallest intersecting chunk |
| `merchants_house` | building | `(5, 1)-(5, 2)` | ADR 0010 lex-smallest intersecting chunk |
| `monastery_barn` | building | `(5, 0)-(6, 0)` | ADR 0010 lex-smallest intersecting chunk |
| `monastery_cloister` | building | `(4, 0)-(5, 0)` | ADR 0010 lex-smallest intersecting chunk |
| `monastery_precinct_wall_south_a` | building | `(2, 0)-(3, 0)` | ADR 0010 lex-smallest intersecting chunk |
| `monastery_precinct_wall_south_b` | building | `(3, 0)-(5, 0)` | ADR 0010 lex-smallest intersecting chunk |
| `rope_makers_house` | building | `(3, 2)-(3, 3)` | ADR 0010 lex-smallest intersecting chunk |
| `saddlers_house` | building | `(1, 2)-(1, 3)` | ADR 0010 lex-smallest intersecting chunk |
| `saiakang_house` | building | `(0, 0)-(1, 1)` | ADR 0010 lex-smallest intersecting chunk |
| `sauna_corner_house` | building | `(2, 2)-(2, 3)` | ADR 0010 lex-smallest intersecting chunk |
| `smithy_yard_fence_east` | building | `(7, 2)-(7, 3)` | ADR 0010 lex-smallest intersecting chunk |
| `smithy_yard_fence_north` | building | `(6, 2)-(7, 2)` | ADR 0010 lex-smallest intersecting chunk |
| `st_catherines_church` | building | `(2, 0)-(3, 0)` | ADR 0010 lex-smallest intersecting chunk |
| `to_reval_south` | transition | `(0, 4)-(0, 5)` | ADR 0010 lex-smallest intersecting chunk |
| `turg_house_north` | building | `(0, 1)-(1, 1)` | ADR 0010 lex-smallest intersecting chunk |
| `vaike_karja_house` | building | `(3, 3)-(4, 3)` | ADR 0010 lex-smallest intersecting chunk |
| `vanaturu_kael_house` | building | `(1, 1)-(1, 2)` | ADR 0010 lex-smallest intersecting chunk |
| `vene_gate_house` | building | `(1, 0)-(1, 1)` | ADR 0010 lex-smallest intersecting chunk |
| `vene_row_house` | building | `(0, 0)-(1, 0)` | ADR 0010 lex-smallest intersecting chunk |
| `viru_gate_north_tower` | building | `(7, 1)-(8, 2)` | ADR 0010 lex-smallest intersecting chunk |
| `viru_gate_south_tower` | building | `(7, 2)-(8, 3)` | ADR 0010 lex-smallest intersecting chunk |
| `viru_house_east` | building | `(6, 1)-(6, 2)` | ADR 0010 lex-smallest intersecting chunk |
| `viru_house_mid` | building | `(3, 1)-(3, 2)` | ADR 0010 lex-smallest intersecting chunk |
| `viru_house_stone` | building | `(4, 1)-(4, 2)` | ADR 0010 lex-smallest intersecting chunk |
| `viru_house_west` | building | `(2, 1)-(2, 2)` | ADR 0010 lex-smallest intersecting chunk |
| `wall_seal_bend_b_north` | building | `(6, 3)-(6, 4)` | ADR 0010 lex-smallest intersecting chunk |
| `wall_seal_bend_d_north` | building | `(5, 4)-(5, 5)` | ADR 0010 lex-smallest intersecting chunk |
| `wall_tower_north` | building | `(7, 1)-(8, 1)` | ADR 0010 lex-smallest intersecting chunk |
| `wall_tower_northeast` | building | `(7, 0)-(8, 0)` | ADR 0010 lex-smallest intersecting chunk |
| `wall_tower_south` | building | `(6, 4)-(6, 5)` | ADR 0010 lex-smallest intersecting chunk |
| `wall_tower_southeast` | building | `(6, 3)-(6, 4)` | ADR 0010 lex-smallest intersecting chunk |
| `wall_tower_southwest` | building | `(5, 4)-(5, 5)` | ADR 0010 lex-smallest intersecting chunk |
| `weary_traveler_inn` | building | `(6, 1)-(7, 2)` | ADR 0010 lex-smallest intersecting chunk |
| `widows_house` | building | `(2, 4)-(3, 4)` | ADR 0010 lex-smallest intersecting chunk |

### `market_civic_quarter` (10 retained warnings)

| Subject | Kind | Planning chunks (16x16) | Owner policy |
|---|---|---|---|
| `church_silhouette` | building | `(2, 0)-(3, 0)` | ADR 0010 lex-smallest intersecting chunk |
| `council_chancery` | building | `(3, 2)-(4, 2)` | ADR 0010 lex-smallest intersecting chunk |
| `east_merchant_row` | building | `(4, 1)-(4, 2)` | ADR 0010 lex-smallest intersecting chunk |
| `guild_frontage` | building | `(0, 0)-(0, 1)` | ADR 0010 lex-smallest intersecting chunk |
| `holy_spirit_hospital` | building | `(3, 0)-(4, 0)` | ADR 0010 lex-smallest intersecting chunk |
| `king_street_house` | building | `(0, 2)-(1, 2)` | ADR 0010 lex-smallest intersecting chunk |
| `merchant_gabled_house` | building | `(1, 0)-(2, 0)` | ADR 0010 lex-smallest intersecting chunk |
| `north_merchant_row_mid` | building | `(1, 0)-(2, 0)` | ADR 0010 lex-smallest intersecting chunk |
| `to_reval_south` | transition | `(0, 2)-(1, 2)` | ADR 0010 lex-smallest intersecting chunk |
| `town_hall_mass` | building | `(1, 2)-(3, 2)` | ADR 0010 lex-smallest intersecting chunk |

## Verification

```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot tools/run_map_pipeline_ci.sh audit
```

Expected: audit stays green on errors; each `MAP_CHUNK_BOUNDARY_AMBIGUOUS` subject for the three maps appears in this report; `docs/MAP_AUTHORING.md` and `docs/MAP_CONVERSION_PLAN.md` cite this owned decision.
