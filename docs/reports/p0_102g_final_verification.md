# P0-102g Final Independent Verification

**Task:** R-371 / P0-102g
**Parent:** R-110 / P0-102
**Date:** 2026-08-02
**Snapshot:** `b4a0b4bfb292eeab90a5ef8171c9867b107bb774` (`main`, `docs: reconcile P0-102g clean baseline`)
**Decision:** **BLOCK P0-102g closeout**

## Scope and method

This is the final independent verification for the shared P0-102 environment kit. It is evidence-only. No runtime, map, asset, test, landmark, house-tier, or downstream implementation was changed to force a pass.

The live project worktree contains unrelated modified and untracked files. Verification therefore used a detached clean worktree created from the exact snapshot above:

`/tmp/rebel-reval-p0-102g-final-20260802`

Godot 4.7.1 editor import completed before testing. Each focused suite ran in its own Godot process through `tools/run_godot_checked.sh --require-test-summary`, with logs retained under `/tmp/p0_102g_final_checked/`. The first six scoped suites completed successfully. The exceptional fortification suite was also run, but its known external failure correctly made the checked runner return status 1.

## Acceptance matrix

| Acceptance clause | Result | Evidence and classification |
|---|---|---|
| Clean reproducible snapshot and import | **PASS** | Detached worktree at `/tmp/rebel-reval-p0-102g-final-20260802`, snapshot `b4a0b4bfb292eeab90a5ef8171c9867b107bb774`. `/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --import --path "$WT"` completed before tests. |
| Four target spaces use one cell/metre scale and shared view-only builders | **PASS** | `test_environment_kit_integration`: **5/5**, including `test_four_target_spaces_share_one_deterministic_view_contract` and `test_forge_and_street_well_modules_are_deterministic_view_only_assemblies`. |
| Routes, anchors, patrols, transitions, collision/navigation boundary, and fingerprints remain safe | **PASS** | The same integration suite passes route, anchor, transition, patrol, clearance, view-only node, and terrain/map/transition/patrol fingerprint assertions. View construction does not create gameplay collision/navigation nodes or mutate authored fingerprints. |
| Decals and local wear | **PASS** | `test_map_view_decals`: **8/8**, including Lower Town, Kalev smithy, and smithy-courtyard wear assertions. This consumes the R-369/R-370 evidence refreshes. |
| Building weathering and shared surface families | **PASS** | `test_building_surface_weathering`: **6/6**. Log, plank, plaster, limestone, tile, shingle, and thatch pattern identity checks pass. |
| Material resolution | **PASS** | `test_map_view_material_resolution`: **4/4**. |
| Core 3D map-view regression | **PASS** | `test_map_view_3d_core`: **17/17**. |
| Mesh-builder regression | **PASS** | `test_map_view_3d_mesh`: **18/18**. |
| Scoped focused-test total | **PASS** | **58/58 tests**, 0 failures and 0 errors across the six scoped suites. Each checked invocation returned status 0. |
| Ordinary versus exceptional geometry boundary | **BLOCKED - external R-353 / P0-102e** | `test_map_view_3d_fortification`: **8 tests, 1 failure, 2 errors**. `test_town_wall_gets_battlements_and_gate_arch_clears_character` fails `Karja Gate needs open metal doors`; `Landmark_karja_gate_arch/GateDoor0` is absent, then `material_override` is accessed on the resulting null instance at `tests/godot/test_map_view_3d_fortification.gd:135-137`. The ordinary-house check in the same suite passes, but the exceptional gate contract is not accepted. |
| Asset lint baseline | **BLOCKED - external character owner** | `python3 tools/verify_asset_lint.py` reports only `assets/characters/shared/sergeant.glb`: tier-1 named-NPC triangle budget `57168 > 56000`. No environment-kit asset is implicated. |
| Asset provenance baseline | **BLOCKED - external Viru Gate/cart owners** | `python3 tools/validate_asset_sources.py` reports 14 missing generated albedo paths: eight `viru_gate_*_albedo.png` files and six `supply_cart_*_albedo.png` files. They are outside this evidence-only task and are not silently waived. |
| Matched gameplay-scale day/night evidence for the four spaces | **BLOCKED - downstream P0-101 / R-108** | The repository has no dedicated final matched acceptance capture set for forge, street/well, brewery, and checkpoint. Existing view3d/calibration images are insufficient to claim the required four-space gameplay-scale day/night sign-off. P0-101 owns the final visual acceptance and this task does not invent substitute evidence. |
| Downstream ordinary-house and landmark handoffs | **BLOCKED - separate existing owners** | Board status remains `todo` for R-108/P0-101 and R-209 through R-213/P2-063 through P2-067. Required house kits, plot dressing, Lower Town tier wiring/parity, and final landmark sign-off are not complete. |

## Exact verification commands

Run from the repository root:

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
WT=/tmp/rebel-reval-p0-102g-final-20260802
LOG_DIR=/tmp/p0_102g_final_checked

git worktree add --detach "$WT" HEAD
"$GODOT_BIN" --headless --editor --import --path "$WT"
mkdir -p "$LOG_DIR"
export GODOT_LOG_DIR="$LOG_DIR"

for filter in \
  test_environment_kit_integration \
  test_map_view_decals \
  test_building_surface_weathering \
  test_map_view_material_resolution \
  test_map_view_3d_core \
  test_map_view_3d_mesh \
  test_map_view_3d_fortification; do
  tools/run_godot_checked.sh --require-test-summary "p0-102g-${filter#test_}" -- \
    "$GODOT_BIN" --headless --path "$WT" \
    --script tools/run_godot_tests.gd -- --filter="$filter"
done

python3 "$WT/tools/verify_asset_lint.py"
python3 "$WT/tools/validate_asset_sources.py"
```

The six scoped green logs are:

- `/tmp/p0_102g_final_checked/p0-102g-environment_kit_integration.log` - 5/5
- `/tmp/p0_102g_final_checked/p0-102g-map_view_decals.log` - 8/8
- `/tmp/p0_102g_final_checked/p0-102g-building_surface_weathering.log` - 6/6
- `/tmp/p0_102g_final_checked/p0-102g-map_view_material_resolution.log` - 4/4
- `/tmp/p0_102g_final_checked/p0-102g-map_view_3d_core.log` - 17/17
- `/tmp/p0_102g_final_checked/p0-102g-map_view_3d_mesh.log` - 18/18

The exceptional log is `/tmp/p0_102g_final_checked/p0-102g-map_view_3d_fortification.log` and records the one failure and two errors above. The checked runner allowlists only documented shutdown leak diagnostics; it correctly rejects this non-shutdown failure.

## Evidence consumed and ownership decisions

- [R-369 follow-up acceptance evidence](p0_102g_followup_evidence.md): six scoped suites green after wear fixes.
- [R-370 baseline reconciliation](p0_102g_baseline_reconciliation.md): clean baseline reproduction and external fortification, character-lint, and Viru Gate/cart provenance classifications.
- [R-368 scope-boundary recheck](p0_102g_scope_boundary_recheck.md): downstream house and landmark handoffs remain external and incomplete.
- [R-363 exceptional renderer reverification](p0_102i_exceptional_renderer_reverification.md): the Karja Gate contract remains an R-353 acceptance blocker.
- [R-364 environment-kit closeout gate](p0_102l_environment_kit_closeout.md): shared environment-kit checks are green, but parent closeout remains blocked by separate boundaries.
- [R-362 downstream handoff evidence](p0_102j_downstream_handoff.md): production assets, tier wiring, provenance, parity, and visual acceptance are not substitutes for the shared kit contract.

The relevant board state at verification time is:

- R-369: `done`
- R-370: `done`
- R-368: `done`
- R-353: `in_progress`
- R-363: `in_review`
- R-364: `in_review`
- R-108, R-209, R-210, R-211, R-212, R-213: `todo`

## Final decision and handoff

**BLOCK P0-102g closeout.** The shared environment-kit implementation itself is green on the six scoped suites with 58/58 tests passing. Full acceptance cannot be claimed while the following independently reproducible blockers remain:

1. **R-353 / P0-102e:** add or expose `Landmark_karja_gate_arch/GateDoor0` and rerun the exceptional fortification suite. Keep the ordinary and exceptional renderer paths separate.
2. **Character asset owner:** resolve or explicitly accept the `sergeant.glb` tier-1 triangle-budget finding.
3. **Viru Gate/cart asset owners:** register the 14 generated albedo paths in `assets/SOURCES.csv` or record an approved non-runtime exclusion.
4. **R-108 / P0-101 and R-209 through R-213 / P2-063 through P2-067:** complete the existing house, plot-dressing, tier-wiring, landmark, parity, and gameplay-scale day/night handoffs.

No new follow-up task is required: every blocker already has an owning task-board row. P0-102 must not claim P0-101 or P2-063 through P2-067 deliverables from this report.
