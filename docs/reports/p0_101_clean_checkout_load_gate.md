# P0-101 Clean-Checkout Parse and Load Gate

**Task:** R-562 / P0-101 clean-checkout guard
**Parent:** R-108 / P0-101
**Date:** 2026-08-18
**Snapshot:** `f7ceaaedcbf5d86bb10e6b0ba70b7bd04e0eaa7d`
**Decision:** **BLOCKED - runtime LFS restore and clean import pass; load remains blocked by R-453 / R-455 map parser work**

## Scope and method

R-562 adds the missing CI/local guard requested by R-490 so clean-checkout parser and resource regressions cannot hide behind a dirty worktree. The gate creates a detached Git worktree at `HEAD`, restores runtime Git LFS inputs, imports the checkout headlessly, then runs a bounded MapView3D load smoke through `tools/run_godot_checked.sh`.

The gate does not repair runtime code, change acceptance thresholds, or reinterpret dirty-worktree greens as clean-checkout evidence.

## Command contract

Local or CI command:

```bash
tools/verify_clean_checkout_load.sh
```

CI step name: `Clean-checkout Lower Town parser and MapView3D load gate` in [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml).

Focused Godot filter:

```text
test_lower_town_slice_map,test_map_view_3d_core,test_map_view_3d_mesh,test_map_view_3d_runtime
```

Failure policy:

- `tools/run_godot_checked.sh` rejects nonzero commands, `SCRIPT ERROR`, `Parse Error`, missing resources, and unexpected `ERROR:` lines.
- Only the documented shutdown-only DEF-002 leak family is allowlisted.
- The load stage requires a non-empty clean harness summary via `--require-test-summary clean-checkout-mapview`.
- Gate cleanup removes only the temporary worktree and temp directory; it does not mutate the caller worktree.

## Contract verification

Python contract tests:

```bash
python3 -m unittest tests.python.test_verify_clean_checkout_load -v
```

Result on 2026-08-17: **PASS** (gate script, workflow reference, cleanup behavior, checked-runner contract, parse-error probe, and report contract).

## Live gate execution

Command run with the repository's installed Godot 4.7.1 binary:

```bash
GODOT_BIN=/Users/artjomkurapov/.local/share/mise/installs/godot/4.7.1-stable/Godot.app/Contents/MacOS/Godot \
  tools/verify_clean_checkout_load.sh
```

Result on 2026-08-18 at `f7ceaaed`: **FAIL / BLOCKED after LFS restore and clean import**

Stage results:

| Stage | Result |
|---|---|
| Detached clean checkout | **PASS** |
| Restore runtime Git LFS assets | **PASS** - 37 materialized objects; the three fetched research plates are reconciled from `history/reference/plates.csv` by `tools/manage_lfs_assets.py` |
| Import clean checkout | **PASS** |
| Load Lower Town and MapView3D dependencies | **BLOCKED** - upstream map parser/runtime failures |

The first product blocker is the existing RRMap parser contract:

```text
res://content/maps/lower_town_slice.rrmap:14:1: error[unknown_command]: unknown command 'elevation_area'
res://content/maps/lower_town_slice.rrmap:17:1: error[unknown_command]: unknown command 'elevation_ramp'
res://content/maps/lower_town_slice.rrmap:20:1: error[unknown_command]: unknown command 'elevation_area'
res://content/maps/lower_town_slice.rrmap:22:1: error[unknown_command]: unknown command 'elevation_area'
```

The bounded load run also reports the dependent MapView3D failures (`41 failure(s), 193 error(s)`), including the existing `Dictionary.id` and null-node diagnostics in `map_view_mesh_builder_landmarks.gd`. These are downstream of the map-definition/parser blocker, not LFS manifest failures.

An initial gate invocation without `GODOT_BIN` stopped at `godot: command not found`; this is an environment/PATH limitation, not a clean-checkout result. The installed Godot binary was then supplied explicitly and reached the owned load-stage blocker.

Owner for the load blocker: **R-453 / R-455** (`Add authored elevation profiles to RRMap`, `Accept city elevation and ditch readability`).

## Confirmed upstream load blocker

The live clean-checkout run confirms the parser failure previously recorded by earlier detached baselines:

```text
res://content/maps/lower_town_slice.rrmap:14:1: error[unknown_command]: unknown command 'elevation_area'
res://content/maps/lower_town_slice.rrmap:17:1: error[unknown_command]: unknown command 'elevation_ramp'
res://content/maps/lower_town_slice.rrmap:20:1: error[unknown_command]: unknown command 'elevation_area'
res://content/maps/lower_town_slice.rrmap:22:1: error[unknown_command]: unknown command 'elevation_area'
```

Owner: **R-453 / R-455** (`Add authored elevation profiles to RRMap`, `Accept city elevation and ditch readability`).

## Temporary failure detection proof

Without modifying tracked repository files:

1. `tests/python/test_verify_clean_checkout_load.py` runs the gate with `GODOT_BIN=/definitely/missing/godot` and proves nonzero exit plus cleanup-only failure messaging.
2. The same suite runs `tools/run_godot_checked.sh` against a temporary Godot project containing a deliberate parse error and proves `SCRIPT ERROR` / `Parse Error` is rejected.

## Closeout decision

R-562 deliverable status:

| Item | Result |
|---|---|
| Gate script | **PASS** |
| CI workflow reference | **PASS** |
| Python contract tests | **PASS** |
| Clean detached import/load at HEAD | **BLOCKED** |

Keep R-562 at `in_review` until a clean HEAD run is green or the first blocker is explicitly owned and accepted as an upstream dependency. Do not treat dirty-worktree MapView3D greens as satisfying this gate.

## Sources

- [`tools/verify_clean_checkout_load.sh`](../../tools/verify_clean_checkout_load.sh)
- [`tests/python/test_verify_clean_checkout_load.py`](../../tests/python/test_verify_clean_checkout_load.py)
- [`docs/reports/lower_town_p0_101_acceptance.md`](lower_town_p0_101_acceptance.md)
- [`docs/reports/p0_102_environment_kit_clean_baseline.md`](p0_102_environment_kit_clean_baseline.md)
.md)
- [`docs/reports/p0_102_environment_kit_clean_baseline.md`](p0_102_environment_kit_clean_baseline.md)
