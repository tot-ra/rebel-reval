# R-454l - Historical elevation acceptance gate

**Review date:** 2026-08-13
**Task:** R-504 / R-454l
**Status:** **BLOCKED - implementation and acceptance evidence are incomplete**
**Review mode:** reproducible contract-gate run; no human historical, art, or visual sign-off is claimed

## Decision

The final historical-elevation gate cannot close yet. The repository contains a valid R-454 source matrix and a partial runtime implementation, but the focused acceptance suites are not green in the current worktree and the required rendered readability evidence is still absent.

This report records the exact boundary rather than treating a data-only pass as visual acceptance. R-504 should remain open/in review until the blockers below are resolved and the focused suites are rerun from a clean or otherwise attributable worktree.

## Scope checked

- R-454 urban exterior matrix: nine maps, with `viru_gate_foreland` explicitly excluded.
- R-503 gameplay invariants: elevation remains view-only and must not change terrain, navigation, transitions, or gameplay snapshots.
- R-455 readability contract: deterministic height, water/shore adjacency, patrol/camera metadata, and the still-required Metal player-eye/top-down and mesh-alignment evidence.

## Reproduction

Godot 4.7.1 was available at `/Applications/Godot.app/Contents/MacOS/Godot`. Each suite was run independently through the checked runner with `GODOT_LOG_DIR=/tmp/rebel-reval-r504-logs`:

```sh
export GODOT_LOG_DIR=/tmp/rebel-reval-r504-logs

tools/run_godot_checked.sh --require-test-summary r504-r454-scope -- \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_r454_elevation_scope

tools/run_godot_checked.sh --require-test-summary r504-r503-invariants -- \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_r503_elevation_gameplay_invariants

tools/run_godot_checked.sh --require-test-summary r504-r455-readability -- \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_r455_city_elevation_readability
```

Saved logs are local verification artifacts and are not part of this documentation change:

- `/tmp/rebel-reval-r504-logs/r504-r454-scope.log`
- `/tmp/rebel-reval-r504-logs/r504-r503-invariants.log`
- `/tmp/rebel-reval-r504-logs/r504-r455-readability.log`

## Results

| Gate | Result | Evidence boundary |
|---|---|---|
| R-454 scope | **BLOCKED** | 1 file, 3 tests: 2 passed; the urban-matrix test could not compile `reval_harbor_north` and `reval_harbor_east` because both current RRMaps reference the unknown style `reed.shore`. |
| R-503 gameplay invariants | **PARTIAL / BLOCKED** | 1 file, 3 tests: finite/scoped elevation and reciprocal-transition checks passed; the gameplay-snapshot test could not load the same two harbour maps because of `MAP_STYLE_UNKNOWN`. |
| R-455 readability | **BLOCKED** | 1 file, 4 tests: patrol/camera contracts passed, but the harbour-water test failed after the harbour definition was invalidated by `reed.shore`; the suite still reports missing rendered player-eye/top-down and exact terrain/object alignment evidence. |

The checked runner also reported expected shutdown resource-leak diagnostics. They are not the acceptance blocker. The actionable blocker is the parser error:

```text
error[MAP_STYLE_UNKNOWN]: primitives[4] references unknown style: reed.shore
```

## Runtime profile coverage

The current RRMap inventory contains authored R-454 profiles in:

- `toompea_quarter`: plateau area and both Jalg ramps
- `archbishops_garden`: plateau area
- `reval_harbor_north`: Coastal Gate ramp, quay-to-wet-margin ramp, wet margin, harbour seam
- `reval_harbor_east`: Kalarand shore, shore track, village edge, north seam

The remaining five urban exterior maps are still represented by the frozen historical matrix but do not yet contain authored `elevation_area`/`elevation_ramp` rows:

- `lower_town_slice`
- `market_civic_quarter`
- `monastery_quarter`
- `north_quarter`
- `south_quarter`

This is an implementation gap, not permission to invent unsupported metre readings. New rows must use the existing typed RRMap elevation grammar, preserve stable IDs, stay within the documented world-unit bounds, and keep transition seams aligned.

## Acceptance boundary

R-504 is not accepted because:

1. Two in-scope harbour maps do not compile in the focused suites due to an unknown style reference.
2. Five matrix maps still lack their authored runtime profiles.
3. R-455 still requires rendered Metal evidence for player-eye/top-down readability, recessed ditch depth, and exact terrain/object alignment.
4. No human historical or art sign-off is recorded by this gate.

The passing R-503 subtests are retained as useful evidence for finite values, scope bounds, reciprocal identities, and the physical harbour seam. They do not override the failed map-load path or the missing visual evidence.

## Follow-up ownership

The task board contains dedicated follow-ups for the two actionable implementation blockers:

- Register or replace the `reed.shore` map style reference and rerun the R-454/R-455/R-503 focused suites.
- Author the remaining five R-454 runtime profile sets through the typed RRMap grammar, then rerun this gate.

After both are complete, rerun the focused suites from a clean attributable snapshot and attach matched Metal day/night captures before changing the decision to accepted.

## References

- [`r454_historical_elevation_profiles.md`](r454_historical_elevation_profiles.md) - frozen historical matrix and source confidence labels.
- [`r455_city_elevation_readability.md`](r455_city_elevation_readability.md) - visual/readability contract and known blockers.
- [`../../tests/godot/test_r454_elevation_scope.gd`](../../tests/godot/test_r454_elevation_scope.gd) - scope regression suite.
- [`../../tests/godot/test_r455_city_elevation_readability.gd`](../../tests/godot/test_r455_city_elevation_readability.gd) - readability/data contract suite.
- [`../../tests/godot/test_r503_elevation_gameplay_invariants.gd`](../../tests/godot/test_r503_elevation_gameplay_invariants.gd) - gameplay invariants and seam checks.
