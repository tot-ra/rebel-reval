# P0-102o Final Environment-Kit Verification

**Task:** R-385 / P0-102o
**Parent:** R-359 / P0-102g / R-110 / P0-102
**Date:** 2026-08-02
**Snapshot:** `a77526936c495c8f4928ccffd37e74293da4a786` (`main`, `Document rights-blocked regional audio handling`)
**Decision:** **BLOCKED - do not mark P0-102g ready**

## Scope and method

This is an independent evidence-only closeout gate for the shared P0-102 environment kit. It checks the four target spaces - forge, street/well, brewery, and checkpoint - without changing runtime, map semantics, environment assets, landmark implementation, or tests to force acceptance.

The live project worktree contains unrelated modified and untracked WIP. Verification therefore used a detached clean worktree at `/tmp/rebel-reval-p0-102o-20260802`, created from the snapshot above. Godot 4.7.1 editor import completed with status 0 before the focused suites. Git reported two existing non-pointer audio files while constructing the detached worktree; this did not prevent import or the scoped test runs.

Each focused suite ran in its own Godot process through `tools/run_godot_checked.sh --require-test-summary`. Logs were retained under `/tmp/p0_102o_checked/`.

## Acceptance matrix

| Acceptance clause | Result | Evidence and classification |
|---|---|---|
| Clean snapshot and import | **PASS** | Detached worktree `/tmp/rebel-reval-p0-102o-20260802` at snapshot `a77526936c495c8f4928ccffd37e74293da4a786`; `/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --import --path "$WT"` returned 0. |
| Four target spaces use one deterministic view-only contract | **PASS** | `test_environment_kit_integration`: **5/5**. Shared cell scale, builders, routes, anchors, patrol/transition records, view-only assembly, and stable fingerprints pass. |
| Shared surface families and local wear resolve | **PASS** | `test_building_surface_weathering`: **6/6**; `test_map_view_material_resolution`: **4/4**; `test_map_view_decals`: **8/8**. Shared wall/roof patterns, deterministic weathering, material resolution, and authored wear cues pass. |
| Core 3D map-view regression | **PASS** | `test_map_view_3d_core`: **17/17**. |
| Mesh-builder regression | **PASS** | `test_map_view_3d_mesh`: **18/18**. |
| Scoped focused-test total | **PASS** | Six scoped suites: **58/58 tests**, 0 failures and 0 errors. All six checked invocations returned status 0. Shutdown ObjectDB/resource/RID diagnostics were the existing non-blocking renderer cleanup noise. |
| Exceptional landmark boundary and gate opening | **BLOCKED - external R-353 / P0-102e** | `test_map_view_3d_fortification`: **8 tests, 1 failure, 2 errors**. `test_town_wall_gets_battlements_and_gate_arch_clears_character` fails `Karja Gate needs open metal doors`; `Landmark_karja_gate_arch/GateDoor0` is absent, followed by null `material_override` access at `tests/godot/test_map_view_3d_fortification.gd:137`. Other fortification tests pass. This is the exceptional-landmark renderer boundary owned by R-353, not an ordinary environment-kit assembly failure. |
| Asset lint | **BLOCKED - external character owner; R-396 disposition recorded** | Clean snapshot `e998d0772f0b04f728efe70e0f34f04f40655749` (2026-08-02) ran `python3 tools/verify_asset_lint.py` and returned status 1 with the single finding `assets/characters/shared/sergeant.glb: tier 1 (named_npc) triangle budget exceeded (57168>56000)`. No environment-kit asset failure was reported. This is the completed P2-005 character-variant baseline; disposition is **DEFERRED, not maintainer-accepted**, to the character asset owner. No character asset or lint threshold was changed here.
| Asset provenance | **BLOCKED - external Viru Gate/cart owners** | `python3 tools/validate_asset_sources.py` reports **14** missing generated albedo paths: eight `viru_gate_*_albedo.png` paths and six `supply_cart_*_albedo.png` paths. These are outside this evidence-only task and were not modified. |
| Matched gameplay-scale day/night evidence | **BLOCKED - R-384 / P0-102m and downstream P0-101** | `docs/reports/images/p0_102_environment_kit/` has no dedicated plates in the clean snapshot. The required evidence is eight non-blank matched plates covering forge, street/well, brewery, and checkpoint in day and night. Existing generic view3d/calibration images cannot substitute for this acceptance set. R-384 already owns the capture task; P0-101/R-108 owns final gameplay-scale visual sign-off. |
| Ordinary-house and exceptional-building handoffs | **BLOCKED - separate owners** | R-108/P0-101 and P2-063 through P2-067 remain separate production and visual handoffs. This gate confirms the boundary but does not claim house-tier assets, plot dressing, tier wiring, landmark art, or parity sign-off. |


### R-396 asset-lint disposition

The clean-snapshot lint result is an external character baseline, not an environment-kit failure. The owner is the character asset owner for completed **P2-005** (`watchman and sergeant visual variants`), with the maintainer as the acceptance authority if the owner proposes a documented exception. This report records the finding as **DEFERRED**: no maintainer acceptance of the 56,000-triangle tier-1 limit was found, and no new task-board owner was available to claim the fix during this verification. The owner must either reduce `sergeant.glb` to at most 56,000 triangles or record an explicit maintainer-approved exception before the asset-lint gate can become green.

Exact clean-snapshot reproduction:

```text
Snapshot: e998d0772f0b04f728efe70e0f34f04f40655749
Command: python3 tools/verify_asset_lint.py
Exit: 1
Output: asset lint failed:
  - [ASSET_LINT_CHARACTER_TIER] assets/characters/shared/sergeant.glb: tier 1 (named_npc) triangle budget exceeded (57168>56000)
```

This R-396 disposition changes documentation only. It does not edit `assets/characters/shared/sergeant.glb`, lower the lint threshold, or classify the external finding as an environment-kit asset failure.
## Exact verification commands

Run from the repository root:

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
WT=/tmp/rebel-reval-p0-102o-20260802
LOG_DIR=/tmp/p0_102o_checked

# Detached clean baseline and import
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
  tools/run_godot_checked.sh --require-test-summary "p0-102o-${filter#test_}" -- \
    "$GODOT_BIN" --headless --path "$WT" \
    --script tools/run_godot_tests.gd -- --filter="$filter"
done

python3 "$WT/tools/verify_asset_lint.py"
python3 "$WT/tools/validate_asset_sources.py"
find "$WT/docs/reports/images/p0_102_environment_kit" -maxdepth 1 -type f -print
```

## Reproduction logs

- `/tmp/p0_102o_checked/p0-102o-environment_kit_integration.log` - 5/5
- `/tmp/p0_102o_checked/p0-102o-map_view_decals.log` - 8/8
- `/tmp/p0_102o_checked/p0-102o-building_surface_weathering.log` - 6/6
- `/tmp/p0_102o_checked/p0-102o-map_view_material_resolution.log` - 4/4
- `/tmp/p0_102o_checked/p0-102o-map_view_3d_core.log` - 17/17
- `/tmp/p0_102o_checked/p0-102o-map_view_3d_mesh.log` - 18/18
- `/tmp/p0_102o_checked/p0-102o-map_view_3d_fortification.log` - 8 tests, 1 failure, 2 errors
- `/tmp/p0_102o_checked/asset-lint.log` - one external character budget finding
- `/tmp/p0_102o_checked/asset-provenance.log` - 14 external missing-source findings

## Handoff and close decision

Keep R-385 in review or blocked until the existing owners resolve the following:

1. **R-353 / P0-102e:** add or expose `Landmark_karja_gate_arch/GateDoor0` with the expected open-metal-door contract, then rerun `test_map_view_3d_fortification`.
2. **Character asset owner:** resolve or explicitly accept the `sergeant.glb` tier-1 triangle-budget finding.
3. **Viru Gate/cart asset owners:** register the 14 generated albedo paths in `assets/SOURCES.csv` or record an approved non-runtime exclusion.
4. **R-384 / P0-102m:** capture and link the eight matched day/night environment-kit plates. Do not infer gameplay-scale readability from generic calibration plates.
5. **R-108 / P0-101 and P2-063 through P2-067:** complete the existing ordinary-house, plot-dressing, tier-wiring, landmark, parity, and gameplay-scale visual handoffs.

No new follow-up task was created: each blocker already has an owning task-board row. The shared environment-kit implementation is green on its six scoped suites, but the full acceptance gate is **BLOCKED** and must not promote parent P0-102g to ready.
