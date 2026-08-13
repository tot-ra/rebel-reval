# R-454 task decomposition (2026-08-13)

## Parent task

| Field | Value |
|---|---|
| Board ref | **R-454** |
| Priority | 1 (high) |
| Complexity | 5 (hard) |
| Status | `in_progress` |
| Title | Author historical elevation across Reval city maps |

## Investigation summary

The parent task spans nine urban exterior RRMaps with a frozen historical matrix (`docs/reports/r454_historical_elevation_profiles.md`, task **R-474** done). Runtime inventory on 2026-08-13:

| Map | Matrix profiles | Runtime state |
|---|---|---|
| `toompea_quarter` | 4 | 3 authored; missing `r454.toompea.southern_slope` |
| `archbishops_garden` | 4 | 1 authored; missing seam/taper trio |
| `reval_harbor_north` | 4 | complete (**R-478**) |
| `reval_harbor_east` | 4 | complete (**R-478**) |
| `lower_town_slice` | 4 | none |
| `market_civic_quarter` | 4 | none |
| `monastery_quarter` | 5 | none |
| `north_quarter` | 4 | none |
| `south_quarter` | 4 | none |

Broad in-flight rows (**R-475**, **R-476**, **R-479**, **R-481**, stub **R-506**) overlapped multiple maps at complexity 2 and blocked parallel claiming. Duplicate matrix row **R-477** duplicated done **R-474**. Gate rows **R-482**..**R-504** lacked explicit dependencies on per-map completion.

## Decomposition decision

Split remaining implementation into **one map per task** at complexity **1**, then a linear verification chain at complexity **1**:

### Map authoring (claimable in parallel after **R-474**)

| Ref | Map | Profiles to author |
|---|---|---|
| **R-515** | `toompea_quarter` | `r454.toompea.southern_slope` |
| **R-516** | `archbishops_garden` | `r454.garden.toompea_seam`, `center_gate_taper`, `south_gate_taper` |
| **R-517** | `lower_town_slice` | full LT quartet |
| **R-518** | `market_civic_quarter` | full market quartet |
| **R-519** | `monastery_quarter` | full monastery quintet incl. ditch/causeway |
| **R-520** | `north_quarter` | full north quartet |
| **R-521** | `south_quarter` | full south quartet |

Each row includes: `role: map`, exact `allowed files`, matrix-bound profile IDs, and verify `tools/run_godot_checked.sh ... --filter=test_r454_elevation_scope`.

### Verification chain (serial)

| Ref | Gate | Depends on | Verify |
|---|---|---|---|
| **R-522** | R-454 scope + parser | R-515..R-521, R-478 | `test_r454_elevation_scope` 3/3; map parser green |
| **R-523** | R-503 gameplay invariants | R-522 | `test_r503_elevation_gameplay_invariants` 3/3 |
| **R-524** | R-455/R-504 acceptance | R-523 | `test_r455_city_elevation_readability` 4/4 + Metal captures |

Parent **R-454** closes only after **R-524** passes.

### Cancelled / superseded rows

| Ref | Reason |
|---|---|
| R-475, R-476, R-479, R-481, R-506 | merged into R-515..R-521 |
| R-477 | duplicate of done R-474 |
| R-482, R-483, R-484, R-503, R-504 | merged into R-522..R-524 |

## References

- [`r454_historical_elevation_profiles.md`](r454_historical_elevation_profiles.md)
- [`r454l_historical_elevation_acceptance.md`](r454l_historical_elevation_acceptance.md)
- [`../../tests/godot/test_r454_elevation_scope.gd`](../../tests/godot/test_r454_elevation_scope.gd)
