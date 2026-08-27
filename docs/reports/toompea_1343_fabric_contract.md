# Toompea 1343 ordinary fabric contract

**Owner:** P4-025d / R-293
**Historical target:** Danish-ruled Toompea, Spring 1343, before the 16 May 1343 castle handover
**Evidence inputs:** R-006 `toompea-castle-and-upper-town.md`, R-035 `toompea-small-castle-interior.md`, A-012 `toompea_1343_art_brief.md`, and the `toompea_quarter` map audit row.

## Decision

The inactive `toompea_quarter` prototype uses sparse hill compounds rather than Lower Town merchant strip rows. Ordinary hill houses are authored with the closed `house_tier` vocabulary below. These keys are semantic art-direction inputs and do not activate the prototype map.

| Key | Use in the 1343 slice | Confidence |
|---|---|---|
| `vassal_curia` | Sober limestone or stone-timber noble house, steep tile roof, high chimney, few street-facing openings, and a yard wall where the plot meets the cliff edge. | plausible composite |
| `canon_lodging` | Smaller plastered or stone canonical lodging around the cathedral close, with shingle or tile cover and restrained domestic openings. | plausible composite |
| `service_wing` | Plank or stone-timber service range for chancery, stable, and chapter support, with shingle/thatch cover and no monumental facade. | plausible composite |

The shared ordinary-house renderer supplies a high chimney and weathered material variation. Toompea hill houses use a reduced facade pass: one entry and one upper opening per visible face. The implementation deliberately does not reuse Lower Town diele-dornse facade defaults, dense merchant window rhythms, loading hatches, or projecting hoist beams.

## Plot and density rules

- The plateau remains a sparse precinct: target built share is 20-35%, with 65-80% open compounds, garden, cliff, or route ground as recorded in `docs/HISTORICAL_AUDIT.md`.
- Castle and cathedral plots may be locally dense inside their walls, but ordinary hill curiae remain separated by open yards and service space.
- Low `wall.yard` records are allowed on cliff-edge service plots. They are yard boundaries, not city walls, gatehouses, or monumental landmark masses.
- No ordinary hill house may be assigned `merchant_stone`, `merchant_timber`, or `craft_boda`; those are Lower Town R-003 tiers.
- No `hoist_beam` or `loading_hatch` may occur on a Toompea hill plot. Merchant hoist hardware remains restricted to merchant house tiers by the shared validator.

## Closed surrounding vocabulary

The map keeps three location zones: `small_castle`, `great_castle`, and `outer_ward`. The jurisdiction boundary is `toompea_danish` on the hill and `all_linn_lubeck` below the Pikk Jalg and Lühike Jalg descents.

Spring-1343 hill-gate styles are limited to `hill_gate.pikk_jalg.timber` and `hill_gate.luhike_jalg.timber`. A stone-tower interpretation is rejected with the stable diagnostic `gate_variant is unknown: stone_tower`. The exact carpentry and guard shelter are **unknown** / bounded reconstruction, not a measured survey.

## Explicit exclusions

- No Pikk Hermann silhouette: it is a later landmark and is outside the Spring-1343 target.
- No Order convent silhouette: the later Order-convent reading is excluded from this Danish-phase prototype.
- No later palace, baroque, Swedish, or modern cathedral facade.
- No finished modern or later Gothic skyline is inferred from the under-construction St Mary's record.

The R-006 and R-035 evidence supports the plateau, Danish-phase compound relationship, and the contrast with Lower Town merchant fabric as **attested** source direction. Exact ordinary-house footprints, opening counts, wall positions, and material assignment remain **plausible composite** or **unknown** and must stay reversible. This contract therefore accepts authored keys and guarded renderer behavior, not an archaeological reconstruction claim.
