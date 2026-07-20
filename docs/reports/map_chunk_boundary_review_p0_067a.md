# P0-067a: retained MAP_CHUNK_BOUNDARY_AMBIGUOUS decisions

Recorded: 2026-07-20  
Task: `P0-067a`  
Maps: `north_quarter`, `monastery_quarter`, `south_quarter`, `toompea_quarter`, `reval_harbor_north`, `reval_harbor_east`
Audit evidence: `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot tools/run_map_pipeline_ci.sh audit` (0 errors; warnings retained below)

P0-068 re-audit note (2026-07-20): the Tallinn district reshape split the old
northern ward, widened both harbours and Toompea, and replaced the southern
rectangular wall with a stepped circuit. Blueprint validation completed with
zero errors and reviewable warnings still visible. Every newly emitted
`MAP_CHUNK_BOUNDARY_AMBIGUOUS` subject on the six maps named above inherits the
ADR 0010 lexicographically-smallest intersecting-chunk ownership decision below.
The older subject inventory is retained as change history, not as the current
warning count; no prototype may be activated on that inventory alone.

## Decision

Retain every listed `MAP_CHUNK_BOUNDARY_AMBIGUOUS` warning on these six maps. Do not suppress the diagnostic code, and do not rewrite historically grounded continuous footprints solely to quiet the 16x16 planning-grid review.

Ownership when object chunk streaming is used follows [ADR 0010](../adr/0010-large-map-runtime-chunking.md) section 4 and `MapChunkRuntimeIndex`:

- Area subjects (buildings, exclusions, transitions) are owned by the lexicographically smallest intersecting chunk under half-open bounds, ordered as `(y, x)`.
- Transitions remain `RESIDENCY_PERSISTENT` so gameplay doors stay available independent of decorative residency.
- Stable IDs are unchanged; chunk coordinates are disposable runtime hints, never save identity.

Rationale:

1. All four maps stay outside the approved playable slice activation gate (`active=false` prototypes; `reval_harbor` remains release-gated developer traversal per the conversion plan).
2. The semantic warning uses a fixed 16x16-cell planning grid (`MapBlueprintSemanticValidator.FUTURE_CHUNK_SIZE_CELLS`). Runtime terrain/object chunking defaults to 32x32 cells (`MapTerrainGrid.DEFAULT_CHUNK_SIZE_CELLS`). Crossing the planning grid is a review signal, not proof that ownership is undefined at runtime.
3. Splitting continuous city walls, quay runs, gate houses, and landmark silhouettes would change layout research fidelity and risk spawn, patrol, and parity regressions without an activation ticket that names allowed geometry edits.

Activation gate: do not promote any of these maps to chunk-streaming-dependent playable content until a later task either (a) splits the listed subjects into single-owner footprints, or (b) re-asserts this ownership decision against the production chunk size after a human map review.

Out of scope for P0-067a: `kalev_smithy` and `lower_town_slice` also emit planning-grid warnings; track them as follow-up `P0-067b`.

## Subject inventory

Planning-grid chunk spans are `(first_chunk)-(last_chunk)` at 16x16 cells, copied from the audit line for each subject.

### `north_quarter` (39 retained warnings)

| Subject | Kind | Planning chunks (16x16) | Owner policy |
|---|---|---|---|
| `blackheads_corner` | building | `(1, 2)-(2, 3)` | ADR 0010 lex-smallest intersecting chunk |
| `brotherhood_wing` | building | `(0, 3)-(1, 4)` | ADR 0010 lex-smallest intersecting chunk |
| `city_wall_north_east` | building | `(4, 0)-(6, 0)` | ADR 0010 lex-smallest intersecting chunk |
| `city_wall_north_west` | building | `(0, 0)-(2, 0)` | ADR 0010 lex-smallest intersecting chunk |
| `coast_gate_west_tower` | building | `(2, 0)-(3, 0)` | ADR 0010 lex-smallest intersecting chunk |
| `cooperage_shed` | building | `(3, 0)-(4, 0)` | ADR 0010 lex-smallest intersecting chunk |
| `excluded.000` | excluded_area | `(2, 3)-(3, 3)` | ADR 0010 lex-smallest intersecting chunk |
| `great_guild_front` | building | `(0, 2)-(1, 3)` | ADR 0010 lex-smallest intersecting chunk |
| `guild_annex` | building | `(0, 3)-(1, 3)` | ADR 0010 lex-smallest intersecting chunk |
| `guild_storehouse` | building | `(1, 3)-(2, 3)` | ADR 0010 lex-smallest intersecting chunk |
| `lai_corner_tenement` | building | `(5, 3)-(6, 3)` | ADR 0010 lex-smallest intersecting chunk |
| `lai_east_row_mid` | building | `(5, 2)-(6, 3)` | ADR 0010 lex-smallest intersecting chunk |
| `lai_east_row_north` | building | `(5, 1)-(6, 2)` | ADR 0010 lex-smallest intersecting chunk |
| `lai_east_row_south` | building | `(5, 3)-(6, 4)` | ADR 0010 lex-smallest intersecting chunk |
| `lai_merchant_mid` | building | `(4, 2)-(5, 3)` | ADR 0010 lex-smallest intersecting chunk |
| `lai_merchant_north` | building | `(5, 1)-(5, 2)` | ADR 0010 lex-smallest intersecting chunk |
| `lai_merchant_south` | building | `(4, 3)-(5, 4)` | ADR 0010 lex-smallest intersecting chunk |
| `olaf_precinct_east` | building | `(3, 3)-(4, 4)` | ADR 0010 lex-smallest intersecting chunk |
| `olaf_precinct_west` | building | `(1, 3)-(2, 4)` | ADR 0010 lex-smallest intersecting chunk |
| `painters_guild` | building | `(5, 1)-(6, 1)` | ADR 0010 lex-smallest intersecting chunk |
| `pikk_merchant_mid_east` | building | `(3, 2)-(3, 3)` | ADR 0010 lex-smallest intersecting chunk |
| `pikk_merchant_mid_west` | building | `(2, 2)-(2, 3)` | ADR 0010 lex-smallest intersecting chunk |
| `pikk_merchant_south_east` | building | `(3, 3)-(3, 4)` | ADR 0010 lex-smallest intersecting chunk |
| `pikk_merchant_south_west` | building | `(2, 3)-(2, 4)` | ADR 0010 lex-smallest intersecting chunk |
| `ropemakers_shed` | building | `(4, 0)-(5, 0)` | ADR 0010 lex-smallest intersecting chunk |
| `sailmakers_loft` | building | `(2, 0)-(3, 0)` | ADR 0010 lex-smallest intersecting chunk |
| `shipwright_yard` | building | `(5, 0)-(6, 0)` | ADR 0010 lex-smallest intersecting chunk |
| `shoemakers_guild` | building | `(5, 2)-(6, 3)` | ADR 0010 lex-smallest intersecting chunk |
| `south_entry_house_east` | building | `(3, 4)-(4, 4)` | ADR 0010 lex-smallest intersecting chunk |
| `south_entry_house_west` | building | `(1, 4)-(2, 4)` | ADR 0010 lex-smallest intersecting chunk |
| `st_olaf_silhouette` | building | `(2, 3)-(3, 4)` | ADR 0010 lex-smallest intersecting chunk |
| `stonemasons_lodge` | building | `(0, 1)-(0, 2)` | ADR 0010 lex-smallest intersecting chunk |
| `tailors_guild` | building | `(4, 1)-(5, 1)` | ADR 0010 lex-smallest intersecting chunk |
| `to_reval_center` | transition | `(2, 4)-(3, 4)` | ADR 0010 lex-smallest intersecting chunk |
| `to_reval_east` | transition | `(4, 4)-(5, 4)` | ADR 0010 lex-smallest intersecting chunk |
| `to_reval_toompea` | transition | `(0, 4)-(1, 4)` | ADR 0010 lex-smallest intersecting chunk |
| `warehouse_north_west` | building | `(1, 0)-(2, 0)` | ADR 0010 lex-smallest intersecting chunk |
| `west_lane_house_south` | building | `(0, 3)-(0, 4)` | ADR 0010 lex-smallest intersecting chunk |
| `workshop_row_east` | building | `(4, 0)-(4, 1)` | ADR 0010 lex-smallest intersecting chunk |

### `south_quarter` (12 retained warnings)

| Subject | Kind | Planning chunks (16x16) | Owner policy |
|---|---|---|---|
| `city_wall_south_east` | building | `(2, 2)-(4, 2)` | ADR 0010 lex-smallest intersecting chunk |
| `city_wall_south_west` | building | `(0, 2)-(1, 2)` | ADR 0010 lex-smallest intersecting chunk |
| `city_wall_west_south` | building | `(0, 0)-(0, 2)` | ADR 0010 lex-smallest intersecting chunk |
| `dunkri_row_east` | building | `(2, 0)-(3, 1)` | ADR 0010 lex-smallest intersecting chunk |
| `dunkri_row_west` | building | `(1, 0)-(1, 1)` | ADR 0010 lex-smallest intersecting chunk |
| `karja_gate_house` | building | `(1, 1)-(2, 2)` | ADR 0010 lex-smallest intersecting chunk |
| `karja_gate_west_tower` | building | `(1, 2)-(2, 2)` | ADR 0010 lex-smallest intersecting chunk |
| `king_street_house` | building | `(0, 0)-(1, 0)` | ADR 0010 lex-smallest intersecting chunk |
| `knights_quarters` | building | `(3, 0)-(4, 1)` | ADR 0010 lex-smallest intersecting chunk |
| `south_merchant_row` | building | `(3, 1)-(4, 1)` | ADR 0010 lex-smallest intersecting chunk |
| `to_reval_center` | transition | `(1, 0)-(2, 0)` | ADR 0010 lex-smallest intersecting chunk |
| `to_reval_east` | transition | `(4, 1)-(4, 2)` | ADR 0010 lex-smallest intersecting chunk |

### `toompea_quarter` (21 retained warnings)

| Subject | Kind | Planning chunks (16x16) | Owner policy |
|---|---|---|---|
| `bishop_house` | building | `(1, 0)-(1, 1)` | ADR 0010 lex-smallest intersecting chunk |
| `castle_curtain_north` | building | `(0, 2)-(2, 2)` | ADR 0010 lex-smallest intersecting chunk |
| `castle_curtain_south_west` | building | `(0, 3)-(1, 3)` | ADR 0010 lex-smallest intersecting chunk |
| `castle_curtain_west` | building | `(0, 2)-(0, 3)` | ADR 0010 lex-smallest intersecting chunk |
| `castle_keep_tower` | building | `(1, 2)-(2, 2)` | ADR 0010 lex-smallest intersecting chunk |
| `castle_mass` | building | `(0, 2)-(1, 3)` | ADR 0010 lex-smallest intersecting chunk |
| `castle_stables` | building | `(3, 3)-(4, 3)` | ADR 0010 lex-smallest intersecting chunk |
| `cathedral_silhouette` | building | `(2, 1)-(3, 1)` | ADR 0010 lex-smallest intersecting chunk |
| `chancery_wing` | building | `(2, 2)-(3, 2)` | ADR 0010 lex-smallest intersecting chunk |
| `city_wall_east_south` | building | `(6, 2)-(6, 3)` | ADR 0010 lex-smallest intersecting chunk |
| `city_wall_north_east` | building | `(6, 0)-(6, 2)` | ADR 0010 lex-smallest intersecting chunk |
| `city_wall_north_west` | building | `(0, 0)-(5, 0)` | ADR 0010 lex-smallest intersecting chunk |
| `city_wall_south_east` | building | `(5, 3)-(6, 3)` | ADR 0010 lex-smallest intersecting chunk |
| `city_wall_south_mid_west` | building | `(2, 3)-(3, 3)` | ADR 0010 lex-smallest intersecting chunk |
| `city_wall_south_west` | building | `(0, 3)-(1, 3)` | ADR 0010 lex-smallest intersecting chunk |
| `city_wall_west` | building | `(0, 0)-(0, 3)` | ADR 0010 lex-smallest intersecting chunk |
| `luhike_gate_guardhouse` | building | `(5, 2)-(6, 3)` | ADR 0010 lex-smallest intersecting chunk |
| `luhike_gate_tower` | building | `(5, 2)-(6, 2)` | ADR 0010 lex-smallest intersecting chunk |
| `noble_residence` | building | `(4, 2)-(4, 3)` | ADR 0010 lex-smallest intersecting chunk |
| `order_barracks` | building | `(0, 3)-(1, 3)` | ADR 0010 lex-smallest intersecting chunk |
| `to_reval_south` | transition | `(1, 3)-(2, 3)` | ADR 0010 lex-smallest intersecting chunk |

### `reval_harbor` (8 retained warnings)

| Subject | Kind | Planning chunks (16x16) | Owner policy |
|---|---|---|---|
| `excluded.000` | excluded_area | `(0, 0)-(4, 0)` | ADR 0010 lex-smallest intersecting chunk |
| `great_coast_gate` | building | `(3, 1)-(4, 1)` | ADR 0010 lex-smallest intersecting chunk |
| `pier_east` | building | `(1, 0)-(2, 0)` | ADR 0010 lex-smallest intersecting chunk |
| `seamens_inn` | building | `(2, 1)-(3, 1)` | ADR 0010 lex-smallest intersecting chunk |
| `stone_quay` | building | `(0, 0)-(4, 0)` | ADR 0010 lex-smallest intersecting chunk |
| `warehouse_east` | building | `(2, 0)-(2, 1)` | ADR 0010 lex-smallest intersecting chunk |
| `warehouse_mid` | building | `(1, 0)-(1, 1)` | ADR 0010 lex-smallest intersecting chunk |
| `warehouse_west` | building | `(0, 0)-(0, 1)` | ADR 0010 lex-smallest intersecting chunk |

## Verification

```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot tools/run_map_pipeline_ci.sh audit
```

Expected: audit stays green on errors; each `MAP_CHUNK_BOUNDARY_AMBIGUOUS` subject for the four maps appears in this report; `docs/MAP_AUTHORING.md` and `docs/MAP_CONVERSION_PLAN.md` cite this owned decision.
