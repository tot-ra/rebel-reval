# P0-102l Environment-Kit Closeout Gate

**Task:** R-364 / P0-102l
**Parent:** R-110 / P0-102
**Date:** 2026-08-01
**Snapshot:** `05a42b02` (`docs: record exceptional renderer boundary reverification`)
**Status:** **PARTIAL - environment-kit gate passes; parent close remains blocked by separate ownership boundaries**

## Scope and method

This is an evidence-only final closeout gate for the shared P0-102 environment kit. It does not modify map/runtime/art assets, repair the R-353 exceptional landmark implementation, or claim the P0-101 / P2-063-P2-067 production handoffs.

The acceptance-critical checks were run from a detached clean worktree at `/tmp/rebel-reval-p0-102l-clean`, created from the snapshot above. Godot editor import completed before testing. The live worktree contains unrelated R-353 mesh-builder/test edits and untracked horse/fauna/cart imports; those files were excluded from the baseline.

## Acceptance matrix

| Check | Result | Evidence / reproduction |
|---|---|---|
| Clean snapshot and Godot editor import | **PASS** | `git worktree add --detach /tmp/rebel-reval-p0-102l-clean HEAD`; `/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --import --path /tmp/rebel-reval-p0-102l-clean` completed. |
| Shared environment-kit integration | **PASS** | `test_environment_kit_integration`: 5/5. Forge, street/well, brewery, and checkpoint share deterministic view-only assembly, preserve clearance/routes/anchors, and keep exceptional gate context outside the ordinary house kit. |
| Checked acceptance runner | **PASS** | `GODOT_LOG_DIR=/tmp/p0_102l_checked tools/run_godot_checked.sh --require-test-summary p0-102l-environment-kit -- ... --filter=test_environment_kit_integration` returned 0 with a clean 5-test summary. Shutdown ObjectDB/resource leak diagnostics are the documented non-blocking DEF-002 baseline. |
| Shared building surface weathering | **PASS** | `test_building_surface_weathering`: 6/6 on the clean baseline. |
| Core 3D map-view regression | **PASS** | `test_map_view_3d_core`: 17/17. |
| Mesh-builder regression | **PASS** | `test_map_view_3d_mesh`: 18/18. The clean baseline completes successfully; the dirty worktree's additional boundary fixture remains owned by R-353. |
| Material resolution | **PASS** | `test_map_view_material_resolution`: 4/4. |
| Decal and local-wear regression | **PASS** | `test_map_view_decals`: 8/8, including Lower Town and smithy courtyard wear assertions. The R-366 forge-yard grime finding is resolved. |
| Exceptional fortification regression | **BLOCKED - external R-353 / P0-102e** | `test_map_view_3d_fortification` reproduces the pre-existing `Karja Gate needs open metal doors` failure and missing `Landmark_karja_gate_arch/GateDoor0`, followed by the null `material_override` diagnostic at `tests/godot/test_map_view_3d_fortification.gd:135-137`. P0-102l does not change this landmark path. |
| Asset lint | **BLOCKED - external baseline** | Clean HEAD `python3 tools/verify_asset_lint.py` reports only `assets/characters/shared/sergeant.glb`: tier-1 budget `57168>56000`. This is outside the environment-kit scope. |
| Asset provenance | **BLOCKED - external cart baseline** | Clean HEAD `python3 tools/validate_asset_sources.py` reports six missing generated cart albedo sidecars: `supply_cart_{aged_cart_iron,ash_timber,linen_sacks,merchant_barrel,weathered_oak_planks,willow_wicker_lattice}_albedo.png`. Dirty WIP additionally has medieval horse sidecars, but they are not part of the clean baseline or this task. |
| Downstream ordinary-house / landmark handoffs | **BLOCKED - separate owners** | P0-101, P2-063, P2-064, P2-065, P2-066, and P2-067 remain `todo`; P0-102j documents that their production assets, tier wiring, parity, and visual sign-off are not complete. P0-102 must not claim them. |

## Exact verification commands

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot

# Clean baseline
WT=/tmp/rebel-reval-p0-102l-clean
git worktree add --detach "$WT" HEAD
"$GODOT_BIN" --headless --editor --import --path "$WT"
"$GODOT_BIN" --headless --path "$WT" --script tools/run_godot_tests.gd -- --filter=test_environment_kit_integration
"$GODOT_BIN" --headless --path "$WT" --script tools/run_godot_tests.gd -- --filter=test_building_surface_weathering
"$GODOT_BIN" --headless --path "$WT" --script tools/run_godot_tests.gd -- --filter=test_map_view_3d_core
"$GODOT_BIN" --headless --path "$WT" --script tools/run_godot_tests.gd -- --filter=test_map_view_3d_mesh
"$GODOT_BIN" --headless --path "$WT" --script tools/run_godot_tests.gd -- --filter=test_map_view_material_resolution
"$GODOT_BIN" --headless --path "$WT" --script tools/run_godot_tests.gd -- --filter=test_map_view_decals
"$GODOT_BIN" --headless --path "$WT" --script tools/run_godot_tests.gd -- --filter=test_map_view_3d_fortification
python3 "$WT/tools/verify_asset_lint.py"
python3 "$WT/tools/validate_asset_sources.py"
```

The acceptance-critical checked command also passed:

```sh
GODOT_LOG_DIR=/tmp/p0_102l_checked \
tools/run_godot_checked.sh --require-test-summary p0-102l-environment-kit -- \
  "$GODOT_BIN" --headless --path "$WT" \
  --script tools/run_godot_tests.gd -- --filter=test_environment_kit_integration
```

## Handoffs and close decision

1. **R-353 / P0-102e:** add or expose the expected open metal `GateDoor0` contract and rerun the fortification suite. The current dirty renderer-boundary changes are not accepted by this report.
2. **Cart asset owner / provenance:** register the six generated cart albedo sidecars or record an approved non-runtime exclusion. This is not an environment-kit failure.
3. **Character asset owner:** resolve or explicitly accept the `sergeant.glb` tier-1 triangle budget finding.
4. **P0-101 and P2-063-P2-067:** complete their existing ordinary-house, plot-dressing, tier-wiring, landmark, and gameplay-scale visual handoffs before the parent P0-102 can satisfy its full deliverable.

**Decision:** The shared P0-102 environment-kit implementation is green on its scoped integration, regression, material, wear, and view-only checks. Keep R-364 as an evidence closeout in review rather than marking parent P0-102 done: external fortification, asset-baseline, and downstream production gates remain open.
