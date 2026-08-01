# R-366 / P0-102 forge-yard grime acceptance

**Date:** 2026-08-01
**Parent:** R-110 / P0-102
**Status:** PASS

## Change

Added the authored view-only decal `decal.grime_courtyard_firewood` to `content/maps/lower_town_slice.rrmap` at the `courtyard_firewood` yard footprint. The decal uses `MapTypes.DECAL_KIND_GRIME` with radius `1.0` and does not add geometry, collision, navigation, or gameplay state.

The existing firewood prop, smithy-door clearance, routes, stable IDs, and map structure were not changed.

## Verification

All scoped checks passed from the repository root:

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT_BIN" --headless --editor --import --path .
tools/run_godot_checked.sh --require-test-summary r366-environment-kit -- "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_environment_kit_integration
tools/run_godot_checked.sh --require-test-summary r366-map-decals -- "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_map_view_decals
tools/run_godot_checked.sh --require-test-summary r366-lower-town -- "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=lower_town
```

Results:

- `test_environment_kit_integration`: 5/5 passed.
- `test_map_view_decals`: 8/8 passed, including the Lower Town wear assertion.
- `test_lower_town_slice_map`: 19/19 passed, including route reachability, parity fixture, and unchanged gameplay fingerprint.
- Godot editor import completed successfully.

Godot emitted the repository's existing shutdown ObjectDB/resource leak diagnostics after successful test summaries; no scoped test or checked-runner failure occurred.

## Decision

The P0-102 forge-yard local grime finding is resolved without changing gameplay geometry or fingerprints. No follow-up task is required for this scoped defect.
