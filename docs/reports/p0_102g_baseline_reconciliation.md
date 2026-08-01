# P0-102g Baseline Reconciliation

**Task:** R-370 / P0-102g
**Parent:** R-359 / P0-102g, shared environment-kit acceptance
**Date:** 2026-08-02
**Snapshot:** `6a57b3c2638a70436f6bb192d188cf5c7397b609` (`main`, `Add 1343 burgher-house art reference pack`)
**Decision:** **SCOPED ENVIRONMENT-KIT READY; OVERALL BASELINE BLOCKED BY EXTERNAL FINDINGS**

## Scope and method

This report reconciles the clean acceptance baseline for the shared P0-102 environment kit. It is evidence-only. No runtime, map, asset, test, landmark, character, cart, or provenance source was changed to make a check pass.

The live project worktree contained unrelated modified and untracked files. A detached worktree was created from the exact snapshot above at `/tmp/rebel-reval-p0-102g-reconcile-20260802`. Godot 4.7.1 editor import completed before the tests. Generated import sidecars and class-cache files were confined to the detached worktree and were not part of the source snapshot.

Each focused Godot suite ran in its own process through `tools/run_godot_checked.sh --require-test-summary`. Logs are retained under `/tmp/p0_102g_reconcile/checked/` for this verification run.

## Acceptance matrix

| Check | Result | Evidence and classification |
|---|---|---|
| Clean snapshot and Godot editor import | **PASS** | `git worktree add --detach /tmp/rebel-reval-p0-102g-reconcile-20260802 HEAD`; snapshot `6a57b3c2638a70436f6bb192d188cf5c7397b609`. `/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --import --path /tmp/rebel-reval-p0-102g-reconcile-20260802` completed. The only import warning was the known nested `generated/comfyui/forge_cat_hunyuan3d_v1/production/godot_verify/project.godot` skip warning. |
| Environment-kit integration | **PASS** | `test_environment_kit_integration`: **5/5**, 0 failures, 0 errors. The four target spaces retain the shared deterministic view-only contract, clearance, routes, anchors, and exceptional-gate separation. |
| Decal and local-wear regression | **PASS** | `test_map_view_decals`: **8/8**, 0 failures, 0 errors. Lower Town and smithy-courtyard wear assertions pass. |
| Building surface weathering | **PASS** | `test_building_surface_weathering`: **6/6**, 0 failures, 0 errors. |
| Material resolution | **PASS** | `test_map_view_material_resolution`: **4/4**, 0 failures, 0 errors. |
| Core 3D map-view regression | **PASS** | `test_map_view_3d_core`: **17/17**, 0 failures, 0 errors. |
| Mesh-builder regression | **PASS** | `test_map_view_3d_mesh`: **18/18**, 0 failures, 0 errors. |
| Scoped focused-test total | **PASS** | **58/58 tests**, 0 failures, 0 errors across six suites. Every checked runner invocation returned status 0. |
| Exceptional fortification boundary | **BLOCKED - external R-353 / P0-102e** | `test_map_view_3d_fortification`: **7/8 pass, 1 failure, 2 errors**. `test_town_wall_gets_battlements_and_gate_arch_clears_character` fails `Karja Gate needs open metal doors`; the missing `Landmark_karja_gate_arch/GateDoor0` then causes the related null `material_override` diagnostic at `tests/godot/test_map_view_3d_fortification.gd:137`. This is an exceptional-landmark renderer boundary, not an environment-kit failure. |
| Asset lint | **BLOCKED - external character baseline** | `python3 /tmp/rebel-reval-p0-102g-reconcile-20260802/tools/verify_asset_lint.py` reports only `assets/characters/shared/sergeant.glb`: tier-1 named-NPC triangle budget `57168 > 56000`. No environment-kit asset is implicated; no character asset was changed. |
| Asset provenance | **BLOCKED - external Viru Gate and cart baselines** | `python3 /tmp/rebel-reval-p0-102g-reconcile-20260802/tools/validate_asset_sources.py` reports 14 generated albedo sidecars missing from `assets/SOURCES.csv`: eight `viru_gate_*_albedo.png` paths under `assets/props/architecture/gates/` and six `supply_cart_*_albedo.png` paths under `assets/props/trade/`. These are owned by the Viru Gate/cart asset work, not by P0-102g; no provenance rows were added here. |

## Exact verification commands

Run from the repository root:

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
WT=/tmp/rebel-reval-p0-102g-reconcile-20260802

# Create the clean baseline and import it before loading class_name-dependent tests.
git worktree add --detach "$WT" HEAD
"$GODOT_BIN" --headless --editor --import --path "$WT"

export GODOT_LOG_DIR=/tmp/p0_102g_reconcile/checked
mkdir -p "$GODOT_LOG_DIR"
for filter in \
  test_environment_kit_integration \
  test_map_view_decals \
  test_building_surface_weathering \
  test_map_view_material_resolution \
  test_map_view_3d_core \
  test_map_view_3d_mesh; do
  tools/run_godot_checked.sh --require-test-summary "p0-102g-${filter#test_}" -- \
    "$GODOT_BIN" --headless --path "$WT" \
    --script tools/run_godot_tests.gd -- --filter="$filter"
done

# External-boundary classification check.
tools/run_godot_checked.sh --require-test-summary p0-102g-fortification -- \
  "$GODOT_BIN" --headless --path "$WT" \
  --script tools/run_godot_tests.gd -- --filter=test_map_view_3d_fortification

python3 "$WT/tools/verify_asset_lint.py"
python3 "$WT/tools/validate_asset_sources.py"
```

The focused checked logs are:

- `/tmp/p0_102g_reconcile/checked/p0-102g-environment_kit_integration.log`
- `/tmp/p0_102g_reconcile/checked/p0-102g-map_view_decals.log`
- `/tmp/p0_102g_reconcile/checked/p0-102g-building_surface_weathering.log`
- `/tmp/p0_102g_reconcile/checked/p0-102g-map_view_material_resolution.log`
- `/tmp/p0_102g_reconcile/checked/p0-102g-map_view_3d_core.log`
- `/tmp/p0_102g_reconcile/checked/p0-102g-map_view_3d_mesh.log`
- `/tmp/p0_102g_reconcile/checked/p0-102g-fortification.log`

The six green suites emitted only the repository's known shutdown leak diagnostics (`ObjectDB`, resources, and dummy-renderer RIDs) after their clean summaries. The fortification run additionally emitted the missing-node diagnostics described above and returned status 1. The checked runner correctly rejected that external suite failure.

## Ownership and handoff

- **R-353 / P0-102e:** repair the missing `GateDoor0` / open-metal-door Karja Gate contract and rerun the fortification suite. P0-102g does not alter exceptional landmark code.
- **A-003 / Viru Gate asset path:** register the eight Viru Gate generated albedo sidecars or record an approved non-runtime exclusion as part of the asset change.
- **A-004 / R-206 cart asset path:** register the six supply-cart generated albedo sidecars or record an approved non-runtime exclusion as part of the cart asset work.
- **Character asset owner:** resolve or explicitly accept the `sergeant.glb` tier-1 triangle-budget baseline. This is outside the environment-kit scope.
- **R-371:** the broader final independent verification and closeout remains a separate board item; this report supplies the clean baseline reproduction it consumes.

## Decision

The scoped P0-102g environment-kit acceptance is ready: all six required environment-kit and map-view regression suites pass with **58/58** tests green on a detached clean snapshot. The overall clean baseline is **blocked** only by named external fortification, character asset-lint, and Viru Gate/cart provenance findings. None is silently waived or claimed as an environment-kit fix. The parent P0-102 must not claim downstream ordinary-house or landmark deliverables from this report.
