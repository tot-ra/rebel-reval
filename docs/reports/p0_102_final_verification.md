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

## R-397 exceptional-boundary recheck addendum (2026-08-02)

This bounded recheck used a fresh detached clean worktree at `/tmp/rebel-reval-r397-20260802` from `HEAD=94ea0de5980af5b66c68c2b4ca051c228484c840`. The live worktree was not used for acceptance because it contains unrelated modified and untracked WIP. Godot 4.7.1 editor import completed successfully before the focused run.

Exact verification command:

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
export GODOT_LOG_DIR=/tmp/r397_checked
tools/run_godot_checked.sh --require-test-summary p0-102-r397-boundary -- \
  "$GODOT_BIN" --headless --path /tmp/rebel-reval-r397-20260802 \
  --script tools/run_godot_tests.gd -- --filter=test_map_view_3d_fortification
```

Result: **BLOCKED**. The checked command returned exit status 1. The saved log `/tmp/r397_checked/p0-102-r397-boundary.log` reports 8 test methods, 2 failures, and 6 engine/script errors:

- `test_town_wall_gets_battlements_and_gate_arch_clears_character` still fails because `Landmark_karja_gate_arch/GateDoor0` is absent; the follow-up `material_override` access is null at `tests/godot/test_map_view_3d_fortification.gd:137`.
- `test_district_boundaries_use_ground_markers_and_real_neighbor_previews` is also blocked by `MAP_ID_DUPLICATE` for `outer_wall_road` at `content/maps/monastery_quarter.rrmap:162`, followed by the missing `Surroundings/Neighbor_north/Buildings` node. This is a separate map-source defect, not an exceptional-renderer assertion. Follow-up task **R-413** owns the fix.
- The remaining six methods pass, including `test_houses_get_facade_doors_and_windows`, the tower regressions, and the wall-walk checks.

No runtime, test, landmark, or map source was changed by R-397. The exceptional renderer boundary therefore remains **not accepted** until R-353 resolves `GateDoor0` and R-413 resolves the monastery stable-ID collision. Existing shutdown renderer leak diagnostics are retained as non-blocking noise; the two named test failures are the acceptance blockers.

## R-398 provenance reconciliation addendum (2026-08-03)

Task R-398 reconciled the 14 generated albedo sidecars that were missing from the clean-snapshot provenance check above:

- Eight `viru_gate_*_albedo.png` paths under `assets/props/architecture/gates/`.
- Six `supply_cart_*_albedo.png` paths under `assets/props/trade/`.

Each row is now present in `assets/SOURCES.csv` with its generator, parent GLB, AGPL-3.0-or-later project-author license, task-authorized review status, and exact PNG SHA-256. A direct file check confirms all 14 paths exist and all 14 recorded hashes match.

The original matrix row and handoff item 3 remain historical results from the detached snapshot. This addendum supersedes only that 14-path provenance blocker for the current manifest. `python3 tools/validate_asset_sources.py` still exits 1 for six separate animal sidecars owned outside R-398: `medieval_dog` albedo/normal/roughness and `medieval_horse_pack` albedo/normal/roughness. The full environment-kit gate therefore remains blocked by the other findings listed above, not by the reconciled Viru Gate/cart paths.

## R-399 final acceptance verification addendum (2026-08-03)

Task **R-399 / P0-102** ran the final acceptance gate against a detached clean worktree at `/tmp/rebel-reval-r399-20260803` from `HEAD=fb85c559` (`Reconcile Viru Gate and supply cart provenance`). The live worktree was not used for acceptance because it contains unrelated modified and untracked WIP. Godot 4.7.1 editor import completed with status 0.

| Acceptance clause | Result | Evidence and classification |
|---|---|---|
| Clean import | **PASS** | `godot --headless --editor --import --path /tmp/rebel-reval-r399-20260803` returned 0. |
| Shared environment-kit and focused regressions | **PASS** | The six scoped suites passed: `test_environment_kit_integration` 5/5, `test_map_view_decals` 8/8, `test_building_surface_weathering` 6/6, `test_map_view_material_resolution` 4/4, `test_map_view_3d_core` 17/17, and `test_map_view_3d_mesh` 18/18. Total: **58/58**, 0 failures and 0 errors. |
| Dedicated day/night evidence | **PASS** | `python3 tools/verify_p0_102_environment_kit_evidence.py` passed with **8/8 plates**. The forge, street/well, brewery, and checkpoint pairs are present, linked once, decodable at 1280x720, non-flat, and use matching day/night framing metadata. Routes, doors, player approach areas, and interactables remain explicitly covered; capture limitations remain documented. |
| Asset lint | **PASS** | `python3 tools/verify_asset_lint.py` passed: 8 style-lock textures, 8 character GLBs, 26 tier-classified character GLBs, and 0 portraits checked. This supersedes the older clean-snapshot `sergeant.glb` baseline finding recorded above. |
| Asset provenance | **PASS** | `python3 tools/validate_asset_sources.py` passed: schema valid, 994 rows, 843 inventory paths covered, and 837 active runtime assets covered. This supersedes the older Viru Gate/cart and animal-sidecar findings recorded above for prior snapshots. |
| Exceptional fortification boundary | **BLOCKED - external R-353 / R-413 ownership** | `test_map_view_3d_fortification` remains red: 8 tests, 2 failures, and 2 engine errors. `Landmark_karja_gate_arch/GateDoor0` is absent, causing the open-metal-door assertion and subsequent null `material_override` diagnostic. The district-boundary check also reports 5 ground cues where 4 are expected. No environment-kit runtime, map, landmark, or test source was changed by R-399. |

Exact checked commands and logs:

```text
Worktree: /tmp/rebel-reval-r399-20260803
Logs: /tmp/r399_checked/

Import: godot --headless --editor --import --path /tmp/rebel-reval-r399-20260803 (exit 0)
Scoped suites: tools/run_godot_checked.sh --require-test-summary p0-102-r399-<suite> -- godot --headless --path /tmp/rebel-reval-r399-20260803 --script tools/run_godot_tests.gd -- --filter=<suite>
Evidence: python3 tools/verify_p0_102_environment_kit_evidence.py (exit 0)
Asset lint: python3 tools/verify_asset_lint.py (exit 0)
Provenance: python3 tools/validate_asset_sources.py (exit 0)
Fortification: test_map_view_3d_fortification (exit 1; 2 failures, 2 engine errors)
```

The expected renderer teardown ObjectDB/resource/RID diagnostics are retained as non-blocking shutdown noise. The shared environment-kit implementation and its dedicated evidence set are green, but the full P0-102 acceptance gate remains **BLOCKED** and must not promote the parent task to done or ready for review until the fortification findings are resolved by their owners. No new follow-up task was created because R-353 and R-413 already own the outstanding boundary findings.

## R-385 independent acceptance recheck addendum (2026-08-14)

Task **R-385 / P0-102o** re-ran the evidence-only acceptance gate against the clean detached worktree `/private/tmp/rebel-reval-r385-20260814` at `HEAD=523a0d163b14270338ed4bbef69355adcca34808` (`Add reproducible character texture generator`). The live worktree was not used for baseline asset/provenance classification because it contains unrelated modified and untracked WIP. Godot 4.7.1 editor import completed successfully before the focused runs.

| Acceptance clause | Result | Evidence and classification |
|---|---|---|
| Clean import | **PASS** | `godot --headless --editor --import --path /private/tmp/rebel-reval-r385-20260814` completed with status 0; retained log: `/tmp/r385_checked/import.log`. |
| Dedicated day/night environment-kit evidence | **PASS** | `python3 tools/verify_p0_102_environment_kit_evidence.py` passed with **8/8 plates**; retained log: `/tmp/r385_checked/evidence.log`. |
| Asset lint | **PASS** | `python3 tools/verify_asset_lint.py` passed with 8 style-lock textures, 9 character GLBs, 29 tier-classified character GLBs, and 0 portraits; retained log: `/tmp/r385_checked/asset_lint.log`. |
| Asset provenance | **BLOCKED - external manifest ownership** | `python3 tools/validate_asset_sources.py` reports one missing inventory/runtime path: `assets/props/environment/sacred_grove_ancient_oak_ancient_oak_heartwood_albedo.png`; retained log: `/tmp/r385_checked/provenance.log`. The file exists in the dirty worktree and has a concurrent `SOURCES.csv` candidate, but that change is not part of this clean baseline and was not adopted by R-385. Follow-up **R-530** owns the manifest reconciliation. |
| Material-resolution regression | **PASS** | `test_map_view_material_resolution`: **7/7**, 0 failures, 0 errors; retained log: `/tmp/r385_checked/p0-102o-map_view_material_resolution.log`. |
| Remaining focused Godot suites | **BLOCKED - external baseline/runtime findings** | The other six suites ran **66 tests** and returned **56 failures plus 175 engine/script errors**: building surface weathering **1/6 + 4 errors**; environment-kit integration **26/5 + 27 errors**; map-view 3D core **9/20 + 46 errors**; fortification **6/8 + 46 errors**; mesh **9/19 + 46 errors**; decals **5/8 + 6 errors**. Logs are retained under `/tmp/r385_checked/`. |

The focused suite failures are not accepted as environment-kit implementation failures without first clearing the shared baseline diagnostics. The recurring first parser diagnostic is `unknown command 'elevation_area'` / `unknown command 'elevation_ramp'` in `content/maps/lower_town_slice.rrmap` at lines 14, 17, 20, and 22; the authored elevation work and acceptance chain are already owned by **R-453 / R-455**. Dependent diagnostics include invalid map-definition validation, empty module assembly, and `Dictionary` key access for `position` / `id` in the environment and landmark builders. The decals suite additionally reports the independent `water_surface` shader tokenizer failure caused by `# gdlint: ignore=max-line-length` inside the inline shader and a decal-ground-lift assertion failure. These findings are recorded as clean-baseline blockers, not repaired in this evidence-only task.

R-385 therefore has a **split result**: the dedicated P0-102 evidence set, import, material-resolution suite, and scoped asset lint pass, but the full environment-kit acceptance gate remains **BLOCKED** by the clean-baseline runtime/parser findings and the one provenance gap. Do not promote P0-102g to ready or done until R-453/R-455 and R-530 are resolved and the focused suites are rerun from a clean snapshot. No runtime, map, asset, shader, test, or concurrent provenance source was changed by R-385.

Exact command families and retained logs:

```text
Worktree: /private/tmp/rebel-reval-r385-20260814
Logs: /tmp/r385_checked/
Import: godot --headless --editor --import --path /private/tmp/rebel-reval-r385-20260814 (exit 0)
Evidence: python3 tools/verify_p0_102_environment_kit_evidence.py (exit 0; 8/8)
Asset lint: python3 tools/verify_asset_lint.py (exit 0)
Provenance: python3 tools/validate_asset_sources.py (exit 1; one missing heartwood sidecar row)
Focused suites: tools/run_godot_checked.sh --require-test-summary <log-basename> -- godot --headless --path /private/tmp/rebel-reval-r385-20260814 --script tools/run_godot_tests.gd -- --filter=<suite>
```

The expected ObjectDB/resource/RID cleanup diagnostics are retained in the logs as non-blocking shutdown noise. The acceptance decision remains **BLOCKED**, while the dedicated environment evidence remains independently green.

## R-397 current-HEAD recheck addendum (2026-08-29)

A fresh detached checkout at `/tmp/rebel-reval-r397-20260829` from `HEAD=d2bb1d24da4fe00d2efa6b0c92d4f846e9cbf814` (`Add static harbour prototype contract verifier`) was used for this recheck. The live worktree was not used because it contains unrelated modified and untracked WIP. Godot 4.7.1 editor import completed successfully with status 0.

Exact verification command:

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
export GODOT_LOG_DIR=/tmp/r397_checked_20260829
/tmp/rebel-reval-r397-20260829/tools/run_godot_checked.sh --require-test-summary p0-102-r397-boundary -- \
  "$GODOT_BIN" --headless --path /tmp/rebel-reval-r397-20260829 \
  --script tools/run_godot_tests.gd -- --filter=test_map_view_3d_fortification
```

Result: **BLOCKED**. The checked command returned exit status 1. The saved log `/tmp/r397_checked_20260829/p0-102-r397-boundary.log` reports 8 tests, 6 failures, and 45 engine/script errors.

- The first repeated diagnostics are `unknown command 'elevation_area'` and `unknown command 'elevation_ramp'` while loading the authored elevation statements in `lower_town_slice.rrmap` and related map definitions. The resulting invalid definitions produce dependent missing-fixture, null-builder, and assertion diagnostics, including `MapViewMeshBuilder` dictionary access and null `has_node` calls.
- The prior R-353 `GateDoor0` and R-413 `outer_wall_road` findings were not emitted before the elevation/parser cascade interrupted the suite. Board records show R-353 and R-413 as `done`, but this run does not independently certify either owner; a clean rerun is required after R-453/R-455 land the elevation parser/authoring handoff.
- No runtime, map, landmark, test, or asset source was changed by R-397. The exceptional renderer boundary remains **not accepted** because the required focused suite did not complete cleanly.

The current ownership boundary is therefore R-453/R-455 for the clean-HEAD elevation/parser blocker, followed by a fresh `test_map_view_3d_fortification` run to verify the exceptional renderer contract itself.

## R-397 latest clean-HEAD recheck addendum (2026-09-01)

A fresh detached checkout at `/tmp/rebel-reval-r397-20260901` from `HEAD=15634e77559e1c5a1af3de9233baea56989a0abc` (`test: cover Harju blocked activation contract`) was used for the latest recheck. The live worktree was not used because it contains unrelated modified and untracked WIP. Godot 4.7.1 editor import completed successfully with status 0 before the focused run.

Exact verification command:

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
export GODOT_LOG_DIR=/tmp/r397_checked_20260901
/tmp/rebel-reval-r397-20260901/tools/run_godot_checked.sh --require-test-summary p0-102-r397-boundary -- \
  "$GODOT_BIN" --headless --path /tmp/rebel-reval-r397-20260901 \
  --script tools/run_godot_tests.gd -- --filter=test_map_view_3d_fortification
```

Result: **BLOCKED**. The checked command returned exit status 1. The saved log `/tmp/r397_checked_20260901/p0-102-r397-boundary.log` reports 8 test methods, 6 failures, and 45 engine/script errors.

- The first repeated diagnostics are `unknown command 'elevation_area'` and `unknown command 'elevation_ramp'` while loading authored elevation statements, including `lower_town_slice.rrmap` lines 14, 17, 20, and 22 and related statements in `south_quarter.rrmap`. The clean snapshot's parser dispatch still does not register these commands, so invalid map definitions and dependent missing-fixture, null-builder, and assertion diagnostics prevent a clean exceptional-boundary result.
- The earlier R-353 `GateDoor0` and R-413 `outer_wall_road` findings were not reached or emitted in this run. They must not be reported as the current root cause. A fresh fortification rerun is required after the active R-453/R-455 elevation parser/authoring handoff lands.
- No runtime, map, landmark, test, or asset source was changed by R-397. The exceptional renderer boundary remains **not accepted** because the required focused suite did not complete cleanly.

The current ownership boundary is R-453/R-455 for the clean-HEAD elevation/parser blocker, followed by a fresh `test_map_view_3d_fortification` run to verify the exceptional renderer contract itself.
