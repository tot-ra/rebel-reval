# R-454l - Historical elevation acceptance gate

**Review date:** 2026-08-13
**Task:** R-504 / R-454l
**Status:** **BLOCKED - final gameplay and rendered acceptance evidence remains incomplete**
**Review mode:** reproducible contract-gate run; no human historical, art, or visual sign-off is claimed

## Decision

The final historical-elevation gate cannot close yet. The R-454 source matrix, all nine urban exterior runtime profile sets, and the parser/compiler regression gate now pass. The remaining R-503 gameplay-invariant and R-455 rendered-readability gates still require their dedicated reruns and evidence.

This report records the exact boundary rather than treating a data-only pass as visual acceptance. R-504 should remain open/in review until the remaining blockers below are resolved and the focused suites are rerun from a clean or otherwise attributable worktree.

## Scope checked

- R-454 urban exterior matrix: nine maps, with `viru_gate_foreland` explicitly excluded.
- R-503 gameplay invariants: elevation remains view-only and must not change terrain, navigation, transitions, or gameplay snapshots.
- R-455 readability contract: deterministic height, water/shore adjacency, patrol/camera metadata, and the still-required Metal player-eye/top-down and mesh-alignment evidence.

## Reproduction

Godot 4.7.1 was available at `/Applications/Godot.app/Contents/MacOS/Godot`. R-522 was run through the checked runner with `GODOT_LOG_DIR=/tmp/rebel-reval-r522-logs`:

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
export GODOT_LOG_DIR=/tmp/rebel-reval-r522-logs

tools/run_godot_checked.sh --require-test-summary r522-scope -- \
  "$GODOT_BIN" --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_r454_elevation_scope

tools/run_map_pipeline_ci.sh parser
```

Saved logs are local verification artifacts and are not part of this documentation change.

## Results

| Gate | Result | Evidence boundary |
|---|---|---|
| R-454 scope / R-522 | **PASS** | 1 file, 3 tests: all nine urban exterior maps compile within the matrix; five flat interiors remain flat; `viru_gate_foreland` remains explicitly excluded. |
| RRMap parser regression | **PASS** | 1 file, 16 tests: elevation grammar, compiled metadata, canonical round-trip, and rejection contracts pass. |
| R-503 gameplay invariants | **PENDING R-523** | Dedicated rerun is still required to prove elevation remains view-only and reciprocal harbour seams remain aligned. |
| R-455 readability | **BLOCKED / PENDING R-524** | Dedicated rerun and Metal player-eye/top-down evidence are still required for ditch depth and terrain/object alignment. |

The checked runner reported expected shutdown resource-leak diagnostics. They did not change either R-522 command's zero status and are not the remaining acceptance blocker.

## R-454v1 verification (2026-08-13)

The R-454 scope suite completed with 3/3 tests and 0 failures or errors:

```text
Godot headless tests: 1 file(s), 3 test(s), 0 failure(s), 0 error(s).
```

The parser regression pipeline completed with 16/16 tests and 0 failures or errors:

```text
Godot headless tests: 1 file(s), 16 test(s), 0 failure(s), 0 error(s).
```

This closes the R-454v1 implementation/parser boundary. It does not claim R-503 gameplay invariants or R-455 rendered readability acceptance.

## Runtime profile coverage

The current RRMap inventory contains the complete authored R-454 matrix in all nine urban exterior maps:

- `toompea_quarter`: plateau area, both Jalg ramps, southern slope
- `archbishops_garden`: plateau area, Toompea seam, center-gate taper, south-gate taper
- `reval_harbor_north`: Coastal Gate ramp, quay-to-wet-margin ramp, wet margin, harbour seam
- `reval_harbor_east`: Kalarand shore, shore track, village edge, north seam
- `lower_town_slice`: full Lower Town quartet
- `market_civic_quarter`: full market quartet
- `monastery_quarter`: full monastery quintet
- `north_quarter`: full north quartet
- `south_quarter`: full south quartet

The five previously missing urban profile sets are now present and are covered by the passing R-454 scope test. `viru_gate_foreland` remains intentionally flat and outside the urban relief matrix.

## Acceptance boundary

R-504 is not accepted because:

1. R-503 gameplay-invariant verification remains to be rerun under R-523.
2. R-455 still requires rendered Metal evidence for player-eye/top-down readability, recessed ditch depth, and exact terrain/object alignment.
3. No human historical or art sign-off is recorded by this gate.

The passing R-454 scope and parser gates establish matrix coverage and grammar/compiler integrity only. They do not override the remaining gameplay or visual acceptance requirements.

## Follow-up ownership

The task board contains the serial verification follow-ups:

- **R-523:** rerun the R-503 gameplay-invariant gate after R-522.
- **R-524:** close R-455/R-504 with the readability suite and matched Metal day/night captures after R-523.

After both are complete, rerun the focused suites from a clean attributable snapshot and attach the required captures before changing the decision to accepted.

## References

- [`r454_historical_elevation_profiles.md`](r454_historical_elevation_profiles.md) - frozen historical matrix and source confidence labels.
- [`r455_city_elevation_readability.md`](r455_city_elevation_readability.md) - visual/readability contract and known blockers.
- [`../../tests/godot/test_r454_elevation_scope.gd`](../../tests/godot/test_r454_elevation_scope.gd) - scope regression suite.
- [`../../tests/godot/test_r455_city_elevation_readability.gd`](../../tests/godot/test_r455_city_elevation_readability.gd) - readability/data contract suite.
- [`../../tests/godot/test_r503_elevation_gameplay_invariants.gd`](../../tests/godot/test_r503_elevation_gameplay_invariants.gd) - gameplay invariants and seam checks.
