# R-598 P0-100 Lower Town surface/elevation verification

**Task:** R-598 / P0-100 surface shares and elevation access
**Verification date:** 2026-08-22
**Map:** `lower_town_slice` / Workers' District
**Checkout:** shared worktree; unrelated WIP was preserved and excluded from this report change
**Decision:** **PASS for Lower Town surface and elevation invariants; BLOCKED only by unrelated matrix and global composition baselines.**

## Scope and decision rule

This verification checks the existing Lower Town authoring contract, composition metrics, and elevation runtime invariants. It is verification-only: no map geometry, threshold, parity fixture, parser, runtime, camera, asset, or review decision was changed by R-598. The Lower Town composition card is explicitly enforced, so the signed surface bands must be measured from the authored map rather than treated as advisory evidence.

## Contract baseline

`docs/data/map_composition_thresholds.json` defines the following `lower_town_slice` ranges:

| Metric | Documented range / cap | Enforcement | Source |
|---|---:|---|---|
| `stone_pct` | `25..40%` | enforced (`enforce=true`) | `H04-H05`, `H09-H10` |
| `earth_pct` | `35..50%` | enforced (`enforce=true`) | `H04-H05`, `H09-H10` |
| `grass_pct` | `15..30%` | enforced (`enforce=true`) | `H04-H05`, `H09-H10` |
| `max_cobblestone_pct` | `40%` | enforced (`enforce=true`) | `H04-H05`, `H09-H10` |
| `elevation_range_min` | `0.3` | enforced (`enforce=true`) | `H04-H05`, `H09-H10` |

The threshold card and `docs/data/lower_town_authoring_contract.json` both name the ownership contract and explicit composition enforcement. Intentional open regions remain excluded through ownership data, not by weakening the global empty-region rule.

## Measured result

The current authored map was loaded and measured through `MapCompositionAudit.measure` using the Lower Town authoring contract. R-607's named terrain-only overlays reconcile the substrate without changing building, prop, anchor, transition, route, or elevation records:

```text
surface_shares:
  stone_pct=26.6815536608472
  earth_pct=45.8722425226688
  grass_pct=27.446203816484
  cobblestone_pct=4.52023277845446
elevation_range=1.48229014535609
profiles=4
```

All four surface bands/caps and the elevation minimum pass. The R-607 report separately records `built_density_pct=21.9622960342187`, `max_style_share_pct=47.5409836065574`, and `largest_empty_region_cells=14778`; those are separate P0-100 composition work owned by R-600 and were not changed or waived by R-598.

## Focused checks

| Check | Result | Interpretation |
|---|---|---|
| `python3 -m unittest tests.python.test_verify_map_composition -v` | **4/5 PASS** | The Lower Town enforcement and regression contracts pass. The one failure is the registry-wide missing threshold-card baseline for `nunnatorn_interior` and `toompea_small_castle`. |
| `test_lower_town_authoring_contract` | **PASS: 2/2** | Lower Town source/runtime ownership, stable IDs, frontage rules, and enforcement flag resolve. |
| `test_lower_town_slice_map` | **PASS: 19/19** | Map validation, routes, collision, navigation, parity, water exclusion, and transition seams pass. |
| `test_r454_elevation_scope` | **BLOCKED: 2/3** | Lower Town-relevant elevation checks pass; the independent matrix check rejects `north_quarter` profile `r454.north.east_harbour_fall`, owned by the active R-453/R-455 elevation work. |
| `test_r503_elevation_gameplay_invariants` | **PASS: 3/3** | Elevation values are finite/scoped, remain view-only, and do not change gameplay geometry, navigation, or reciprocal transition identity. |
| `python3 tools/verify_map_composition.py` | **BLOCKED by baseline** | Validation stops before map metrics because registry threshold cards are missing for `nunnatorn_interior` and `toompea_small_castle`; those map packages are owned by R-623/R-251 and R-297/P4-039. |

The Godot run produced 27 tests with 26 passes, one failure, and zero errors. The only failure was the unrelated `north_quarter` elevation-matrix membership check. Shutdown ObjectDB/resource-leak diagnostics were the known teardown output and did not alter the scoped assertions.

## Existing follow-ups and blockers

- **R-600** owns the remaining Lower Town built-density, style-repetition, and empty-region composition bands. R-598 does not weaken those enforced checks.
- **R-453 / R-455** own the `north_quarter` elevation profile/matrix mismatch reported by `test_r454_elevation_scope`.
- **R-623 / R-251** own the Nunnatorn interior package whose registry threshold card is absent from the current global composition baseline.
- **R-297 / P4-039** owns the Toompea Small Castle package whose registry threshold card is absent from the current global composition baseline.
- No duplicate follow-up task was created: each actionable blocker already has an active board owner.

## Final disposition

**R-598 verification is complete as a deterministic ledger.** Lower Town surface shares, elevation access, gameplay invariants, map contracts, and canonical parity pass in the current checkout. The combined verification command remains globally blocked by unrelated elevation-matrix and registry-card baselines owned by existing tasks. Keep P0-100 parent acceptance open until those owners reconcile their inputs; do not regenerate parity or alter thresholds as part of R-598.

## Sources

- [`Lower Town RRMap`](../../content/maps/lower_town_slice.rrmap)
- [`Lower Town authoring contract`](../data/lower_town_authoring_contract.json)
- [`Composition thresholds`](../data/map_composition_thresholds.json)
- [`R-607 surface reconciliation`](r607_lower_town_surface_reconciliation.md)
- [`test_lower_town_authoring_contract.gd`](../../tests/godot/test_lower_town_authoring_contract.gd)
- [`test_lower_town_slice_map.gd`](../../tests/godot/test_lower_town_slice_map.gd)
- [`test_r454_elevation_scope.gd`](../../tests/godot/test_r454_elevation_scope.gd)
- [`test_r503_elevation_gameplay_invariants.gd`](../../tests/godot/test_r503_elevation_gameplay_invariants.gd)
- [`verify_map_composition.py`](../../tools/verify_map_composition.py)
- [`r454_historical_elevation_profiles.md`](r454_historical_elevation_profiles.md)
- [`r454l_historical_elevation_acceptance.md`](r454l_historical_elevation_acceptance.md)
