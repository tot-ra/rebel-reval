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

## 2026-08-23 rerun addendum

The focused rerun used Godot 4.7.1 with `tools/run_godot_checked.sh` and captured wrapper logs before classifying non-zero exits. Lower Town-specific acceptance remains green:

- `test_lower_town_authoring_contract`: **2/2 PASS**.
- `test_lower_town_slice_map`: **19/19 PASS**.
- The measured Lower Town substrate remains `stone_pct=26.6815536608472`, `earth_pct=45.8722425226688`, `grass_pct=27.446203816484`, `cobblestone_pct=4.52023277845446`, with `elevation_range=1.48229014535609`; these remain within the enforced surface bands and elevation minimum recorded by R-607.

The broader checks preserve the same ownership boundary but expose the current blockers precisely:

| Check | Result | Current blocker / interpretation |
|---|---|---|
| `python3 -m unittest tests.python.test_verify_map_composition -v` | **4/5 PASS** | The four Lower Town enforcement/regression cases pass. Registry coverage fails for missing threshold cards `kuldjala_interior`, `nunnatorn_interior`, and `toompea_small_castle`. |
| `python3 tools/verify_map_composition.py` | **BLOCKED** | Stops at the same three missing registry threshold cards before running the enforced-map audit. |
| `test_r454_elevation_scope` | **2/3 test methods PASS** | The urban matrix method reports the inactive/unknown `kuldjala_interior` transition, plus `r454.north.east_harbour_fall` and `r454.south.karja_causeway` outside the current matrix. R-453/R-455 and the map-package owners already cover these inputs. |
| `test_r503_elevation_gameplay_invariants` | **2/3 test methods PASS** | Finite/scoped values and reciprocal transition identity pass. The geometry/navigation method is blocked while `monastery_quarter` cannot compile through its missing `kuldjala_interior` destination. |

No R-598 follow-up task was created: `R-623/R-251` own Nunnatorn, `R-297` owns Toompea Small Castle, and `R-453/R-455` own the elevation matrix/profile reconciliation. R-598 remains **in review** with Lower Town invariants verified and only those pre-existing cross-map blockers open.

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

## 2026-08-29 current-checkout rerun

The R-598 verification was rerun against the current shared checkout with Godot 4.7.1. The report remains verification-only: no map, threshold, parity fixture, runtime, or focused test source was changed.

Fresh metric probe:

```text
R598_METRICS_20260829 map_id=lower_town_slice
surface_shares={"cobblestone_pct":4.52023277845446,"earth_pct":45.8722425226688,"grass_pct":27.446203816484,"stone_pct":26.6815536608472,"timber_pct":0.0,"unbuilt_cells":14778}
elevation_range=1.48229014535609
profiles=4
```

All enforced Lower Town surface bands and the elevation minimum pass: stone `25..40%`, earth `35..50%`, grass `15..30%`, cobblestone `<=40%`, and elevation range `>=0.3`. The focused Lower Town limit is also `<=5%` cobblestone, and the measured value passes it.

Commands and checked results (logs retained under `/tmp/rebel-reval-r598-logs-20260829/`):

```text
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
export GODOT_LOG_DIR=/tmp/rebel-reval-r598-logs-20260829

# PASS: 1 file, 3 tests, 0 failures, 0 errors
tools/run_godot_checked.sh --require-test-summary r598-authoring-contract -- "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_lower_town_authoring_contract

# PASS: 1 file, 19 tests, 0 failures, 0 errors
tools/run_godot_checked.sh --require-test-summary r598-lower-town-slice -- "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_lower_town_slice_map

# PASS: 1 file, 3 tests, 0 failures, 0 errors
tools/run_godot_checked.sh --require-test-summary r598-r503-elevation -- "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_r503_elevation_gameplay_invariants

# BLOCKED: 1 file, 3 tests, 2 failures, 0 errors
tools/run_godot_checked.sh --require-test-summary r598-r454-elevation -- "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_r454_elevation_scope
 # Failures: north_quarter profile r454.north.east_harbour_fall and
 # south_quarter profile r454.south.karja_causeway are outside the R-454 matrix.

# PASS: 4/5 Python tests; the one failure is registry coverage for
# toompea_small_castle only.
python3 -m unittest tests.python.test_verify_map_composition -v

# BLOCKED: registry maps missing threshold cards: toompea_small_castle
python3 tools/verify_map_composition.py

# PASS: no scoped report whitespace errors
git diff --check -- docs/reports/r598_lower_town_surface_elevation_verification.md
```

The two R-454 failures are outside the Lower Town slice and remain owned by R-453/R-455. The composition blocker is the missing `toompea_small_castle` registry threshold card, owned by the Toompea Small Castle package work (`R-297`/`P4-039`). No new follow-up task is needed because both blockers already have active owners. Lower Town surface shares, elevation access, authoring contract, map routes/parity, and view-only elevation invariants remain **PASS**; the global matrix/composition command remains **BLOCKED** only at those external baselines.

The checked Godot logs contain only the repository's known shutdown ObjectDB/resource-leak diagnostics after clean summaries; no parser, script, shader, or resource-loading errors were reported.

## Updated disposition

R-598 is ready for review as a deterministic verification ledger. Keep P0-100 acceptance open until the existing R-453/R-455 elevation-matrix work and the Toompea threshold-card owner reconcile their inputs. Do not regenerate parity or alter thresholds as part of R-598.

## 2026-08-30 current-checkout rerun

R-598 was rerun against the current shared checkout at `HEAD=3237727fe261f938543c379176a7ae66a6e96c9c` with Godot `4.7.1.stable.official.a13da4feb` and the repository pin `.godot-version=4.7`. The rerun remained verification-only; no map, runtime, threshold, parity fixture, or focused test source changed.

Fresh Lower Town metric probe:

```text
R598_METRICS_20260830 map_id=lower_town_slice
surface_shares={"cobblestone_pct":4.52023277845446,"earth_pct":45.8722425226688,"grass_pct":27.446203816484,"stone_pct":26.6815536608472,"timber_pct":0.0,"unbuilt_cells":14778}
elevation_range=1.48229014535609
profiles=4
```

The enforced Lower Town substrate bands and the `>=0.3` elevation minimum pass. The scoped checks were:

| Check | Result | Interpretation |
|---|---|---|
| `test_lower_town_authoring_contract` | **PASS: 3/3** | Ownership, frontage exceptions, tier coverage, and explicit enforcement resolve. |
| `test_lower_town_slice_map` | **PASS: 19/19** | Map validation, routes, collision, navigation, parity, water exclusion, and transition seams pass. |
| `test_r503_elevation_gameplay_invariants` | **PASS: 3/3** | Elevation values remain finite/view-only; gameplay geometry, navigation, reciprocal identity, and physical seam alignment remain stable. |
| `test_r454_elevation_scope` | **BLOCKED: 1/3** | The two failures are external matrix drift: `north_quarter` profile `r454.north.east_harbour_fall` and `south_quarter` profile `r454.south.karja_causeway` are not in the R-454 allowlists. |
| `python3 -m unittest tests.python.test_verify_map_composition -v` | **BLOCKED: 4/5** | The Lower Town enforcement/regression tests pass; registry coverage fails only because `toompea_small_castle` has no threshold card. |
| `python3 tools/verify_map_composition.py` | **BLOCKED** | Stops at the same missing `toompea_small_castle` threshold card before map metrics are audited. |
| Report link audit | **PASS: 11/11** | Every relative source link resolves. |
| `git diff --check -- docs/reports/r598_lower_town_surface_elevation_verification.md` | **PASS** | No scoped whitespace errors. |

The R-454 failures remain owned by R-453/R-455. The missing composition card remains owned by the Toompea Small Castle package (`R-297`/`P4-039`). No follow-up task was created because both blockers have registered owners. Lower Town surface shares, elevation access, authoring contract, map routes/parity, and view-only elevation invariants are **PASS**; only the external matrix/composition baselines remain **BLOCKED**.

## Current disposition

R-598 has a complete current-checkout verification ledger and remains in review pending maintainer review. Keep P0-100 open until R-453/R-455 and the Toompea threshold-card owner reconcile their inputs. Do not regenerate parity or alter thresholds as part of R-598.

## 2026-08-31 current-checkout rerun

R-598 was rerun against the current shared checkout at `HEAD=d827e089d8ddd02d603052bc6c58cd9c48f6a2a2` with Godot `4.7.1.stable.official.a13da4feb` after a successful headless editor import. The verification remained read-only for map, runtime, threshold, parity, and focused test sources.

Fresh Lower Town metric probe (`tools/_tmp_r598_metrics.gd`, removed after the run) reported:

```text
R598_METRICS_20260831 map_id=lower_town_slice
surface_shares={"cobblestone_pct":4.52023277845446,"earth_pct":45.8722425226688,"grass_pct":27.446203816484,"stone_pct":26.6815536608472,"timber_pct":0.0,"unbuilt_cells":14778}
elevation_range=1.48229014535609
profiles=4
```

The enforced Lower Town substrate bands and the `>=0.3` elevation minimum remain satisfied. Checked focused results were captured under `/tmp/rebel-reval-r598-logs-20260831/`:

| Check | Result | Interpretation |
|---|---|---|
| `test_lower_town_authoring_contract` | **PASS: 3/3** | Ownership, frontage exceptions, tier coverage, and explicit enforcement resolve. |
| `test_lower_town_slice_map` | **PASS: 19/19** | Map validation, routes, collision, navigation, parity, water exclusion, and transition seams pass. |
| `test_r503_elevation_gameplay_invariants` | **PASS: 3/3** | Elevation values remain finite/view-only; gameplay geometry, navigation, reciprocal identity, and physical seam alignment remain stable. |
| `test_r454_elevation_scope` | **BLOCKED: 1/3** | The two failures remain external matrix drift: `north_quarter` profile `r454.north.east_harbour_fall` and `south_quarter` profile `r454.south.karja_causeway` are outside the R-454 allowlists. |
| `python3 -m unittest tests.python.test_verify_map_composition -v` | **BLOCKED: 6/7** | All Lower Town enforcement/regression cases pass; registry coverage fails only because `toompea_small_castle` has no threshold card. |
| `python3 tools/verify_map_composition.py` | **BLOCKED** | Stops at the same missing `toompea_small_castle` threshold card before map metrics are audited. |
| Report link audit | **PASS: 11/11** | Every relative source link resolves. |
| `git diff --check -- docs/reports/r598_lower_town_surface_elevation_verification.md` | **PASS** | No scoped whitespace errors. |

The metric probe's checked wrapper returned non-zero only for the known shutdown leak diagnostics (`92 ObjectDB` instances and `8 resources`); its direct rerun exited 0 and reported no parser, script, shader, or resource-loading errors. The three focused Lower Town test files completed with clean checked summaries; their shutdown leak lines were likewise the known teardown output.

The R-454 failures remain owned by R-453/R-455. The missing composition card remains owned by the Toompea Small Castle package (`R-297`/`P4-039`). No follow-up task was created because both blockers have registered owners. Lower Town surface shares, elevation access, authoring contract, map routes/parity, and view-only elevation invariants remain **PASS**; only the external matrix/composition baselines remain **BLOCKED**.

## Current disposition

R-598 has a complete current-checkout verification ledger and is ready for maintainer review. Keep P0-100 open until R-453/R-455 and the Toompea threshold-card owner reconcile their inputs. Do not regenerate parity or alter thresholds as part of R-598.
