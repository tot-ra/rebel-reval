# R-1021 second-reviewer sign-off of R-1003 shore-relative water recess

**Review date:** 2026-09-27
**Task:** R-1021 / independent review of commit `3140df2a`
**Parent:** R-1003 (WB-03/WB-04 prerequisite)
**Reviewer:** independent Cursor Agent CLI pass against the four R-1021 checks
**Status:** **ACCEPT** - close R-1003. No new leftover row.

## Decision

`MapViewMeshBuilderTerrain` measures the still-water recess from the lowest dry
4-neighbour on maps that author `relief_*`, and keeps the historic world-zero
`-WATER_RECESS` path when `relief_heights` is empty. Harbor North stays on that
historic bed. The leftover named in the R-1021 contract (probe and surroundings
hard-coded to world zero) is already closed by R-1022 (`4e367282`). BoatFloat3D
and OceanFftSampler were not in `3140df2a` and still use their own FFT /
`height_at` call sites.

This is a contract and test review, not a GPU harbour recapture. R-1003 already
recorded that plate skip while a Godot editor held the shared worktree. Current
authored maps still have empty `relief_heights`, so Harbor North bit-identity is
the production proof.

## Contract checks

| Check | Evidence | Result |
|---|---|---|
| 1. Empty `relief_heights` skips `water_surface_bases`; Harbor North gameplay bed stays at `-WATER_RECESS` | `_bake_water_surface_bases` returns before writing the key when `heights.is_empty()`. `test_maps_without_relief_keep_the_world_zero_recess` and `test_harbor_north_gameplay_bed_stays_on_the_historic_recess` assert the missing key and bed `-0.08`. | **PASS** |
| 2. Terrace-plus-ditch moat fills from the lowest dry neighbour; surface below both banks; bed below surface, not world zero | `_bake_water_surface_bases` flood-fills each water body, takes `min` dry 4-neighbour compiled height, and keeps that base when `water_min > 0`. `test_moat_water_sits_inside_the_ditch_below_both_banks` asserts banks `> 1.5`, surface below both, bed `> 1.0`, and every water vertex on the terrace. | **PASS** |
| 3. Open sea at or below datum stays at datum when a quay is raised (`min(shore, 0)`) | After the flood fill, `water_min <= 0.0` forces `surface_base = minf(shore, 0.0)`. `test_raised_quay_does_not_lift_datum_sea` keeps the left-hand sea bed at `-WATER_RECESS` while the quay terrace stays at `+2`. | **PASS** |
| 4. BoatFloat3D and FFT call sites unchanged in `3140df2a`; probe/surroundings leftover | `git show 3140df2a` touches only the terrain/water builders, `MAP_AUTHORING.md`, and `test_map_relief_water.gd`. `boat_float_3d.gd` still samples `OceanFftSampler.height_at`. The named leftover is R-1022, already `done`; current `_underwater_probe` and surroundings rest Y sample `water_gameplay_bed_y`. | **PASS** |

## Explicit rejection checks

| Rejected form | Review result |
|---|---|
| Flat maps grow a `water_surface_bases` key | **No rejection.** Empty relief returns before the bake writes the array. |
| Moat water drops to world-zero recess | **No rejection.** Fixture bed and vertices stay above `1.0` on the terrace. |
| Raised quay lifts the adjoining sea | **No rejection.** Datum sea keeps `-WATER_RECESS`. |
| Review re-files the probe/surroundings leftover | **No rejection.** R-1022 already landed that fix; do not open a duplicate. |

## Verification

Commands run from an isolated worktree at `origin/main` (`c52bfed4`) on 2026-09-27
because the shared checkout had Godot `--editor`. Cache came from an `rsync` of
the imported `.godot/` directory, not from `--editor --quit`.

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
git worktree add /tmp/rr-r1021-review origin/main
rsync -a --delete .godot/ /tmp/rr-r1021-review/.godot/
cd /tmp/rr-r1021-review
./tools/run_godot_checked.sh --require-test-summary r1021-review -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_map_relief_water,test_map_relief_field,test_ws13b_sea_basin_depth
# Godot 4.7.1: 3 file(s), 32 test(s), 0 failure(s), 0 error(s).
```

Checked runner accepted the known DEF-002 exit leak (`8 resources still in use`).

## Handoff

- R-1021: move to done.
- R-1003: move to done. Second-reviewer acceptance is this report.
- R-1022: already done. No further leftover row.
- GPU harbour recapture remains optional and is not required to close these rows
  while every production map still has empty `relief_heights`.
