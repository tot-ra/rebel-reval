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

## R-544 current clean-snapshot closeout (2026-08-17)

**Task:** R-544 / P0-102 final closeout
**Snapshot:** `3e46eee323aeaf26a3a67e9b36b0ed349d62e480` (`Document safe fixed-text pre-commit assertions`)
**Worktree:** `/tmp/rebel-reval-r544-20260817` (detached clean worktree created from the snapshot; the live worktree was not used for acceptance)
**Decision:** **BLOCKED - keep R-110 / P0-102 `todo`**

This addendum supersedes the older clean-snapshot classifications above for the current `HEAD`. It records only evidence reproduced from the detached worktree. Godot editor import completed with exit 0 before the focused runs. Import generated local `.uid` cache files in the temporary worktree; no generated cache file was used as acceptance evidence or copied into the project.

### Final acceptance matrix

| Parent P0-102 requirement | Current result | Evidence and owner classification |
|---|---|---|
| Forge, street/well, brewery, and checkpoint use shared modules without bespoke camera, scale, or material exceptions | **BLOCKED** | `test_environment_kit_integration`: 5 tests, 26 failures, 27 engine/script errors. The first clean-baseline diagnostic is `unknown command 'elevation_area'` / `unknown command 'elevation_ramp'` in `content/maps/lower_town_slice.rrmap` lines 14, 17, 20, and 22. Subsequent missing map-definition fields and dictionary access errors are cascade diagnostics. R-453 and R-455 own the elevation parser/acceptance work. |
| Three R-003 tiers (`merchant_stone`, `merchant_timber`, `craft_boda`) coexist in one gameplay capture | **BLOCKED - evidence missing** | The current repository contains the eight environment-kit plates, but no current verified gameplay capture or sign-off demonstrates all three tiers in one frame. The required ordinary-house production and route handoffs remain separate work under R-108 and R-209-R-212. This closeout does not infer tier coexistence from generic environment plates. |
| Ordinary buildings remain separate from churches, guild halls, gates, and civic landmarks | **BLOCKED by baseline test cascade** | `test_map_view_3d_fortification`: 8 tests, 6 failures, 46 engine/script errors. The clean run reaches `Viru Gate needs its arch landmark`, then reports the same elevation parser errors and dependent null/dictionary diagnostics. R-353 and R-413 are already `done`; no new defect is assigned to them here. The boundary cannot be accepted until the current parser/runtime baseline is repaired and the focused suite is rerun. |
| Shared wall/roof material families and deterministic worn/repaired variants | **PARTIAL** | `test_map_view_material_resolution`: 7/7 pass. `test_building_surface_weathering`: 6 tests, 1 failure, 4 errors; its non-map-specific material tests pass, while the Lower Town assertion is interrupted by the elevation parser cascade. |
| Asset lint and provenance | **PASS** | `python3 tools/verify_asset_lint.py`: exit 0, 8 style-lock textures, 9 character GLBs, 29 tier-classified character GLBs, 0 portraits. `python3 tools/validate_asset_sources.py`: exit 0, schema valid, 1,143 rows, 990 inventory paths covered, 984 active runtime assets covered. |
| Pivot, collision, navigation, and stable route/interactable contracts | **BLOCKED** | `test_map_view_3d_core`: 20 tests, 9 failures, 46 errors; `test_map_view_3d_mesh`: 19 tests, 9 failures, 46 errors; `test_environment_kit_integration` is also blocked before its route assertions complete. These are not valid acceptance passes while the authored Lower Town map cannot parse. |
| Day/night gameplay readability for all four spaces | **PASS for plate integrity only; gameplay acceptance remains partial** | `python3 tools/verify_p0_102_environment_kit_evidence.py`: exit 0, 8/8 plates. All eight files exist at 1280x720 RGB and are non-flat: forge, street/well, brewery, and checkpoint, each day/night. The verifier proves evidence-file integrity and metadata, not the missing three-tier coexistence requirement or a human visual sign-off. |
| Full parent closeout with no unresolved P0-102-owned blocker | **BLOCKED** | R-453 and R-455 are `in_progress`, and the required ordinary-house/tier evidence remains owned by R-108 and R-209-R-212. R-544 therefore must not move R-110 to `in_review` or `done`. No new task is needed because each current blocker has an existing owner. |

### Exact current verification commands

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
export GODOT_LOG_DIR=/tmp/r544_checked
WT=/tmp/rebel-reval-r544-20260817

# Snapshot and clean import
# HEAD: 3e46eee323aeaf26a3a67e9b36b0ed349d62e480
git worktree add --detach "$WT" HEAD
"$GODOT_BIN" --headless --editor --import --path "$WT"  # exit 0

# Each command ran in its own Godot process; logs are under /tmp/r544_checked/
for filter in \
  test_environment_kit_integration \
  test_building_surface_weathering \
  test_map_view_3d_core \
  test_map_view_3d_mesh \
  test_map_view_material_resolution \
  test_map_view_decals \
  test_map_view_3d_fortification; do
  tools/run_godot_checked.sh --require-test-summary "r544-${filter#test_}" -- \
    "$GODOT_BIN" --headless --path "$WT" \
    --script tools/run_godot_tests.gd -- --filter="$filter"
done

python3 "$WT/tools/verify_p0_102_environment_kit_evidence.py"  # exit 0, 8/8
python3 "$WT/tools/verify_asset_lint.py"                       # exit 0
python3 "$WT/tools/validate_asset_sources.py"                  # exit 0
```

Focused-suite results retained in `/tmp/r544_checked/`:

- `environment_kit_integration`: 5 tests, 26 failures, 27 errors.
- `building_surface_weathering`: 6 tests, 1 failure, 4 errors.
- `map_view_3d_core`: 20 tests, 9 failures, 46 errors.
- `map_view_3d_mesh`: 19 tests, 9 failures, 46 errors.
- `map_view_material_resolution`: 7/7 pass.
- `map_view_decals`: 8 tests, 5 failures, 6 errors.
- `map_view_3d_fortification`: 8 tests, 6 failures, 46 errors.

The repeated first diagnostic is the clean parser's missing `elevation_area` / `elevation_ramp` support, owned by R-453/R-455. The later failures are dependent diagnostics and are not reclassified as independent environment-kit defects. Existing renderer shutdown ObjectDB/resource diagnostics are non-blocking cleanup noise.

**Closeout decision:** R-544 is complete as a blocked evidence report. Keep R-544 in review and keep R-110 / P0-102 `todo`. Re-run this matrix after R-453/R-455 land and after R-108/R-209-R-212 provide the three-tier gameplay evidence; only then can the parent acceptance decision be reconsidered.

## Lessons learned

- A clean detached snapshot can expose an authored RRMap command that exists in a dirty worktree's `MapBlueprint` helper but is not registered in the clean parser dispatch. Treat the first `unknown command` diagnostic as the blocker and do not accept downstream map/view failures as separate defects until the parser baseline is repaired.
- Eight valid day/night environment plates do not prove the parent requirement for three ordinary house tiers in one gameplay capture. Keep plate integrity, gameplay composition, and human visual sign-off as separate acceptance rows.

## Source

- `docs/reports/p0_102_environment_kit_closeout.md`
- `docs/reports/p0_102_environment_kit_acceptance.md`
- `/tmp/r544_checked/`
- `R-453`, `R-455`, `R-108`, `R-209`-`R-212`

**Updated:** 2026-08-17

**Final decision:** **BLOCKED - R-110 / P0-102 remains `todo`.**

## Current clean-HEAD recheck (2026-08-29)

**Snapshot:** `7dddee2746a5536c6e4f68d7b75a49554a9f33dd` (`Cover DebugOverlay slower time control`)
**Worktree:** `/tmp/rebel-reval-r364-clean-20260829` (detached clean worktree created from the current `HEAD`)
**Status:** **BLOCKED - evidence packet and asset lint pass, but the clean runtime matrix is blocked by the RRMap elevation parser baseline and provenance drift**

This recheck was run outside the dirty shared worktree. Godot 4.7.1 editor import completed with status 0. Each focused suite ran in a separate checked process under `/tmp/r364_clean_checked_20260829/`; the checked runner status matched the summary below.

| Check | Result | Evidence / owner classification |
|---|---|---|
| Clean checkout and editor import | **PASS** | Detached worktree created from the current `HEAD`; headless editor import completed successfully. |
| Shared environment-kit integration | **BLOCKED** | `test_environment_kit_integration`: 5 tests, 26 failures, 34 errors. The first product diagnostics are `unknown command 'elevation_area'` / `unknown command 'elevation_ramp'` in `content/maps/lower_town_slice.rrmap`, followed by invalid-map and typed-array cascades. R-453/R-455 own the elevation parser/acceptance boundary. |
| Shared building surface weathering | **BLOCKED** | `test_building_surface_weathering`: 6 tests, 1 failure, 4 errors; the clean Lower Town path is interrupted by the same elevation parser baseline. |
| Core 3D map-view regression | **BLOCKED** | `test_map_view_3d_core`: 20 tests, 9 failures, 44 errors; the repeated elevation parser diagnostics prevent valid Lower Town runtime acceptance. |
| Mesh-builder regression | **BLOCKED** | `test_map_view_3d_mesh`: 19 tests, 9 failures, 44 errors; failures are downstream of the same clean parser baseline. |
| Material resolution | **PASS** | `test_map_view_material_resolution`: 7 tests, 0 failures, 0 errors. |
| Decal and local-wear regression | **BLOCKED** | `test_map_view_decals`: 8 tests, 4 failures, 4 errors; Lower Town map parsing is the first product blocker. |
| Exceptional fortification regression | **BLOCKED** | `test_map_view_3d_fortification`: 8 tests, 6 failures, 45 errors; this is a clean-baseline cascade, not evidence to reopen the completed R-353 gate-leaf work. |
| Dedicated day/night evidence packet | **PASS** | `python3 tools/verify_p0_102_environment_kit_evidence.py`: 8/8 decodable, paired, non-flat 1280x720 plates. This verifies file integrity and metadata, not three-tier gameplay readability or human sign-off. |
| Asset lint | **PASS** | `python3 tools/verify_asset_lint.py`: 8 style-lock textures, 13 character GLBs, 41 tier-classified character GLBs, 0 portraits. |
| Asset provenance | **BLOCKED - external owner** | `python3 tools/validate_asset_sources.py` reports 10 active plot-dressing albedo paths absent from `assets/SOURCES.csv`; these belong to the active R-212 asset/provenance handoff, not the environment-kit module implementation. |
| Downstream parent closeout | **BLOCKED** | R-453 and R-455 remain `in_progress`; R-601/R-614 own route/runtime follow-up; R-209/R-211/R-212 remain active for ordinary-house and plot-dressing handoffs; R-110 remains `in_progress`. No duplicate follow-up task is needed. |

### Recheck decision

R-364 is complete as a reproducible blocked evidence closeout and should remain in review. The shared environment-kit packet itself has green evidence and asset-lint coverage, but P0-102 cannot be promoted while the clean RRMap parser baseline, plot-dressing provenance rows, and downstream gameplay/runtime handoffs remain unresolved. Re-run this matrix from a new clean revision after R-453/R-455 land, then consume R-601/R-614 and the ordinary-house handoffs before changing the parent decision.

**Current verification logs:** `/tmp/r364_clean_checked_20260829/`

## R-544 clean-HEAD recheck (2026-09-01)

**Snapshot:** `a9d8d3f3e6847ae641554cb1cfd9d22f09e9263c` (`test: cover CR-only TODO summary flow`)
**Worktree:** `/tmp/rebel-reval-r544-clean-20260901` (detached clean worktree created from this revision; the live worktree was not used for acceptance)
**Status:** **BLOCKED - evidence packet, asset lint, and material-resolution regression pass, but authored-map runtime suites and provenance remain blocked**

This recheck was run from a detached clean snapshot after Godot 4.7.1 editor import completed with status 0. The live worktree contains unrelated staged and untracked WIP; none of it is included in this result. Focused checked logs are retained under `/tmp/r544_checked_20260901/`.

| Check | Result | Evidence / owner classification |
|---|---|---|
| Clean checkout and editor import | **PASS** | Detached worktree at `a9d8d3f3e6847ae641554cb1cfd9d22f09e9263c`; `/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --import --path /tmp/rebel-reval-r544-clean-20260901` returned 0. |
| Shared environment-kit integration | **BLOCKED** | `test_environment_kit_integration`: 5 tests, 26 failures, 34 errors. The first repeated product diagnostics are unknown `elevation_area` and `elevation_ramp` commands in `content/maps/lower_town_slice.rrmap` lines 14, 17, 20, and 22, followed by invalid map-definition and dependent fixture cascades. The same log records missing `brewery_door` and checkpoint authored-map validation/anchor failures after the parser cascade. R-453/R-455 own the elevation parser/acceptance boundary; R-601 owns the route/anchor reconciliation. |
| Lower Town authored-map contract | **BLOCKED** | `test_lower_town_slice_map`: 19 tests, 26 failures, 93 errors. The same elevation parser diagnostics interrupt map construction; remaining failures include the smithy courtyard, district seam/navigation, Viru Gate portcullis, water cells, and worker-district seam contracts. R-601 owns route/collision/navigation/transition/runtime reconciliation; do not reclassify the cascade as an environment-kit pass. |
| Burgher-house tier regression | **BLOCKED** | `test_burgher_house_tiers`: 5 tests, 92 failures, 12 errors. The clean fixture cannot resolve the authored Lower Town houses and therefore cannot prove multiple wall/roof/weathering variants. Ordinary-house and tier handoffs remain with the active downstream owners, including R-209/R-211/R-212. |
| Shared building surface weathering | **BLOCKED** | `test_building_surface_weathering`: 6 tests, 1 failure, 4 errors. The generic wall/roof/weathering tests pass, while the Lower Town assertion is interrupted by the elevation parser cascade. |
| Core 3D map-view regression | **BLOCKED** | `test_map_view_3d_core`: 21 tests, 14 failures, 49 errors. The clean authored-map parse failure prevents valid Lower Town resident-object, route, terrain, and definition acceptance. R-601 owns the route/runtime follow-up. |
| Mesh-builder regression | **BLOCKED** | `test_map_view_3d_mesh`: 19 tests, 9 failures, 44 errors. The clean parser cascade prevents valid Lower Town puddle, surroundings, transition-door, and map-driven mesh acceptance; independent parametric mesh checks still pass. |
| Material resolution | **PASS** | `test_map_view_material_resolution`: 7 tests, 0 failures, 0 errors. |
| Decal and local-wear regression | **BLOCKED** | `test_map_view_decals`: 8 tests, 4 failures, 4 errors. The generic decal checks pass; Lower Town threshold/yard, anvil soot, district-door mud, and smithy-threshold wet-wear assertions are not validly accepted while the authored map parser is blocked. |
| Exceptional fortification regression | **BLOCKED** | `test_map_view_3d_fortification`: 8 tests, 6 failures, 45 errors. The first clean fixture failures are missing authored Lower Town wall/neighbor data and `Viru Gate needs its arch landmark`, followed by the same parser-dependent cascade. This does not reopen completed R-353 work. |
| Dedicated day/night evidence packet | **PASS** | `python3 tools/verify_p0_102_environment_kit_evidence.py`: 8/8 plates. The manifest has two `lower_town_slice` plates (`day`, `night`), one shared `three_tier_route` framing key, all three tier labels (`craft_boda`, `merchant_stone`, `merchant_timber`), three material families, and three roof families. Each PNG is 1280x720 RGB and non-flat. This proves packet integrity and metadata only, not gameplay-camera acceptance or human visual sign-off. |
| Asset lint | **PASS** | `python3 tools/verify_asset_lint.py`: 8 style-lock textures, 13 character GLBs, 41 tier-classified character GLBs, 0 portraits. |
| Asset provenance | **BLOCKED - external owner** | `python3 tools/validate_asset_sources.py` returned 1 for 10 active `assets/props/architecture/houses/plot_dressing/*_albedo.png` paths absent from `assets/SOURCES.csv`. R-212 owns the plot-dressing asset/provenance handoff. |
| Downstream parent closeout | **BLOCKED** | R-453 and R-455 remain `in_progress`; R-601, R-614, and R-212 remain active for parser/runtime, playable-route, ordinary-house, and plot-dressing handoffs. R-110/P0-102 remains `in_progress`; no duplicate follow-up task is needed. |

### Exact current verification commands

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
WT=/tmp/rebel-reval-r544-clean-20260901

# Snapshot and clean import
# HEAD: a9d8d3f3e6847ae641554cb1cfd9d22f09e9263c
git worktree add --detach "$WT" HEAD
"$GODOT_BIN" --headless --editor --import --path "$WT"  # exit 0

# Each command ran in its own checked Godot process; logs are under /tmp/r544_checked_20260901/
for filter in \
  test_environment_kit_integration \
  test_lower_town_slice_map \
  test_burgher_house_tiers \
  test_building_surface_weathering \
  test_map_view_3d_core \
  test_map_view_3d_mesh \
  test_map_view_material_resolution \
  test_map_view_decals \
  test_map_view_3d_fortification; do
  tools/run_godot_checked.sh --require-test-summary "r544-${filter#test_}" -- \
    "$GODOT_BIN" --headless --path "$WT" \
    --script tools/run_godot_tests.gd -- --filter="$filter"
done

python3 "$WT/tools/verify_p0_102_environment_kit_evidence.py"  # exit 0, 8/8
python3 "$WT/tools/verify_asset_lint.py"                       # exit 0
python3 "$WT/tools/validate_asset_sources.py"                  # exit 1, 10 missing plot-dressing paths
```

### Recheck decision

R-544 is complete as a reproducible blocked evidence closeout and should remain in review. The dedicated evidence packet, clean import, asset lint, and material-resolution suite are green. The parent P0-102 gate cannot be promoted while the clean RRMap parser baseline blocks authored-map/runtime acceptance, R-212 provenance rows are missing, and R-601/R-614 plus ordinary-house handoffs have not supplied valid route/gameplay evidence. Re-run this matrix from a new clean revision after R-453/R-455 land, then consume the route and tier handoffs before changing the parent decision.

**Current verification logs:** `/tmp/r544_checked_20260901/`
