# P0-101 Clean-Checkout Parse and Load Gate

**Task:** R-562 / P0-101 clean-checkout guard
**Parent:** R-108 / P0-101
**Date:** 2026-08-17
**Snapshot:** `67169bb999859ae1e2c37fd0dd19e428eafe154b`
**Decision:** **BLOCKED - gate implemented and wired; clean load not yet green at HEAD**

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

Command run:

```bash
tools/verify_clean_checkout_load.sh
```

Result on 2026-08-17 at `67169bb9`: **FAIL / BLOCKED**

First failing stage:

```text
restore runtime Git LFS assets
```

First reproducible diagnostic:

```text
Git LFS asset verification failed:
  - LFS-tracked path missing from manifest: history/reference/economy/merchant-cart-and-transport-1340s/economy.merchant-cart-and-transport-1340s.05.jpg
  - LFS-tracked path missing from manifest: history/reference/economy/reval-cart-tolls-and-fuhr-rent-1340s/economy.reval-cart-tolls-and-fuhr-rent-1340s.04.jpg
  - LFS-tracked path missing from manifest: history/reference/language/names-address-and-oaths/language.names-address-and-oaths.03.png
```

Owner for this blocker: research-plate / LFS manifest hygiene outside R-562. The gate correctly stops before import/load while runtime LFS verification is red.

## Expected next clean-checkout blocker after LFS repair

Prior clean detached baselines already record the next parser failure once import/load can proceed:

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
