# P0-102 Decomposition Verification

**Task:** R-558
**Parent:** R-110 / P0-102
**Date:** 2026-08-17
**Live workspace HEAD:** `259eff8576ac9fb2e3a79c3638a3a03f9efd0a58`
**Live worktree:** shared worktree with unrelated staged, unstaged, and untracked WIP
**Decision:** **BLOCKED - do not advance or close R-110 / P0-102**

## Scope and decision rule

This is the final evidence-only verification of the decomposed P0-102 work. It reconciles the four low-complexity evidence subtasks, checks every parent acceptance clause, and records whether the parent may advance.

No runtime, map, asset, provenance, shader, test, or acceptance-threshold source was changed for R-558. The live worktree is not a clean acceptance snapshot. The evidence reports below were produced at different historical revisions and in different detached or dirty worktrees; their passing counts must not be added together as if they were one synchronized build. The clean-baseline reports are authoritative for parent acceptance. Later scoped reports are retained for the narrower facts they explicitly verify.

The decision rule is strict: implementation wiring, source inventories, valid evidence-file pairs, or a passing subordinate test do not waive a failed clean runtime gate, a missing production handoff, or a missing gameplay-scale visual review.

## Decomposed-subtask reconciliation

All four required report artifacts exist, but the board does not show all four subtasks as closed acceptance gates. Their results remain partial or blocked and therefore do not make R-110 ready.

| Subtask | Board status | Evidence output | Result used by this verification |
|---|---|---|---|
| R-554 - ordinary/exceptional handoff audit | `in_review` | [`p0_102_handoff_audit.md`](p0_102_handoff_audit.md) | Ordinary tier wiring is present, but R-209-R-212 production handoffs remain `todo`; exceptional ownership is preserved; final gameplay-scale and landmark acceptance are missing. |
| R-555 - focused environment-kit regression | `done` | [`p0_102_focused_regression.md`](p0_102_focused_regression.md) | Clean detached regression is **BLOCKED / PARTIAL**: 73 methods, 56 failures, 175 engine/script errors; only material resolution is fully green. |
| R-556 - implementation coverage ledger | `in_review` | [`p0_102_scope_ledger.md`](p0_102_scope_ledger.md) | Five parent clauses are reconciled as **BLOCKED / PARTIAL**. R-453/R-455 own the clean parser blocker; R-209-R-212 and P0-101/R-108 own downstream production and visual evidence. |
| R-557 - asset and visual acceptance audit | `in_review` | [`p0_102_evidence_audit.md`](p0_102_evidence_audit.md) | Later scoped audit verifies 8/8 environment plates, asset lint, provenance, and 91/92 focused methods, but independently reproduces the decal ground-clearance failure owned by R-571. |

## Evidence snapshots and authority

| Evidence source | Revision / worktree | What it establishes | Authority boundary |
|---|---|---|---|
| R-544 addendum in [`p0_102l_environment_kit_closeout.md`](p0_102l_environment_kit_closeout.md) | `3e46eee323aeaf26a3a67e9b36b0ed349d62e480`; detached `/tmp/rebel-reval-r544-20260817` | Current clean closeout classification: import, asset lint, provenance, and 8/8 plate integrity pass; focused runtime matrix is blocked by the elevation parser cascade. | Primary clean-baseline decision for the parent. |
| R-540 [`p0_102_environment_kit_clean_baseline.md`](p0_102_environment_kit_clean_baseline.md) | `356c9721d548689ee59f5e12b80f649780d0fa7f`; detached `/tmp/rebel-reval-r540-20260817` | Reproduces the parser blocker and records exact clean focused-suite counts. | Clean-baseline reproduction and diagnostic classification. |
| R-555 [`p0_102_focused_regression.md`](p0_102_focused_regression.md) | `266b3eeaba87c1f49b17059105f4c8261c3f7d68`; detached `/tmp/rebel-reval-r555-20260817` | Independent clean regression with the same primary parser diagnosis plus separate shader/decal/fixture findings. | Confirms the blocker is not caused only by the live dirty worktree. |
| R-557 [`p0_102_evidence_audit.md`](p0_102_evidence_audit.md) | `a40d4f86d6508ff5379bbd93d09808568e21532e`; live dirty worktree | Scoped later evidence: 8/8 plates, asset lint/provenance, and 91/92 methods; decal failure is reproducible. | Narrow evidence only; not a clean parent acceptance run. |
| R-558 live workspace | `259eff8576ac9fb2e3a79c3638a3a03f9efd0a58`; shared dirty worktree | Path and current-board context for this report. | Not used as a clean runtime acceptance snapshot. |

## Parent acceptance matrix

The five clauses below are the complete parent-level decomposition used by R-556 and cover the R-110 deliverable and verification text.

| R-110 / P0-102 clause | Implementation coverage | Acceptance result | Exact blocker and owner |
|---|---|---|---|
| **1. Four-space modular environment kit:** forge, street/well, brewery, and checkpoint use shared modules without bespoke camera, scale, or material exceptions. | [`map_view_environment_kit.gd`](../../scripts/map/view3d/map_view_environment_kit.gd) defines the target modules. [`test_environment_kit_integration.gd`](../../tests/godot/test_environment_kit_integration.gd) covers shared assembly, routes, anchors, patrols, transitions, fingerprints, pivots, and view-only behavior. | **BLOCKED / implementation boundary present.** R-557's later dirty-worktree audit records 5/5, but the clean R-544 matrix records 5 methods, 26 failures, and 27 engine/script errors. The later result cannot replace the clean baseline because the revisions differ. | First clean diagnostic is missing `elevation_area` / `elevation_ramp` parser dispatch in authored RRMap data. Owner: **R-453 / R-455**, both `in_progress`. Rerun the complete matrix after repair. |
| **2. Ordinary Reval building families:** historically grounded `merchant_stone`, `merchant_timber`, and `craft_boda`, with varied forms and roof bands; all three coexist in one gameplay capture. | Current source records 43 tiered ordinary buildings: `merchant_stone=14`, `merchant_timber=14`, `craft_boda=15`. R-213 wiring is `done`; [`test_burgher_house_tiers.gd`](../../tests/godot/test_burgher_house_tiers.gd) covers assignment, mixed-tier minimums, fallback/material precedence, variation, and exceptional exclusions. | **PARTIAL / BLOCKED.** Source wiring is present, but authored production kits, GLB/PBR/LOD/collision output, focused per-tier tests, plot dressing, provenance handoffs, and the required gameplay-scale visual proof are not complete. R-209-R-212 remain `todo`; R-6/A-009 is conditional; R-108 remains `todo`. | Missing production handoffs and missing gameplay-scale proof that all three tiers read together. Owners: **R-209, R-210, R-211, R-212**, with final visual acceptance by **R-6/A-009 and R-108/P0-101**. |
| **3. Shared materials, wear, and required prop families:** log/plank/plaster/limestone, tile/shingle/thatch, local wear, trade/yard/drainage/vegetation/fence/workshop/cart/barrel/crate/sign families, without gameplay-data mutation. | Shared procedural/rendering paths and [`test_building_surface_weathering.gd`](../../tests/godot/test_building_surface_weathering.gd), [`test_map_view_material_resolution.gd`](../../tests/godot/test_map_view_material_resolution.gd), and environment-kit integration cover the implemented families. | **PARTIAL / BLOCKED.** Clean material resolution is 7/7 and clean asset lint/provenance checks pass in R-544. However, weathering is 1 failure plus 4 errors, and integration/decal/core/mesh suites are blocked by the clean map/parser baseline. The later R-557 pass is scoped to a different revision and does not prove the complete parent gate. No dedicated P0-102 vegetation/tree acceptance report was found. | Runtime acceptance is blocked first by **R-453/R-455** parser work; authored decal clearance is independently blocked by **R-571** (`todo`). Remaining family completeness and visual review stay with **R-542**, R-209-R-212, and P0-101/R-108. |
| **4. Separate exceptional-landmark path:** churches, guild halls, gates, and civic buildings must not be assembled as ordinary houses. | [`map_view_mesh_builder_buildings.gd`](../../scripts/map/view3d/map_view_mesh_builder_buildings.gd) routes exceptional records separately. The handoff audit confirms Viru towers remain wall/fortification records, gate arches remain separate view landmarks, and ordinary tier metadata cannot override the exceptional registry. | **STRUCTURAL PASS / ACCEPTANCE BLOCKED.** The boundary is implemented and not silently substituted, but the clean fortification suite is 8 methods, 6 failures, and 46 engine/script errors after the parser cascade. This report does not promote historical fortification findings from older snapshots or reopen completed R-565 work. | Repair the clean parser baseline under **R-453/R-455**, then rerun the fortification/boundary suite. Final landmark silhouette, historical, and gameplay-scale review remains owned by **R-108/P0-101** and the relevant exceptional-landmark work. |
| **5. Full verification gate:** asset lint, provenance, pivot/scale, collision/navigation, route/parity, and matched day/night readability, including a gameplay capture proving three-tier coexistence. | Clean evidence records import, asset lint, provenance, pivot/view-only contracts, route/parity assertions, and 8/8 environment-kit plate integrity at separate snapshots. The tests and reports are linked in the source list below. | **BLOCKED / NOT READY.** Asset lint, provenance, and 8/8 plate-file integrity are individually evidenced. The clean focused runtime matrix is not green; collision/navigation and route/parity assertions cannot be accepted through a parser cascade; and no reviewed gameplay capture proves all three ordinary tiers together. R-543 remains `todo`, and the capture matrix keeps tier/material/landmark review rows pending or blocked. | **R-453/R-455** own parser/elevation acceptance; **R-571** owns decal clearance; **R-209-R-212** own production kit evidence; **R-543**, **R-6/A-009**, and **R-108/P0-101** own the missing matched gameplay-scale and visual sign-off gates. |

## Exact verification commands and recorded results

These are the commands recorded by the evidence owners. They are reproduced here rather than rerun against the dirty live worktree as a substitute for a clean parent gate.

### Clean baseline and focused suites

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
export WT=/tmp/rebel-reval-r544-20260817
export GODOT_LOG_DIR=/tmp/r544_checked

git worktree add --detach "$WT" 3e46eee323aeaf26a3a67e9b36b0ed349d62e480
"$GODOT_BIN" --headless --editor --import --path "$WT"

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
```

Recorded result in R-544:

| Suite | Result |
|---|---:|
| `test_environment_kit_integration` | 5 methods, 26 failures, 27 engine/script errors |
| `test_building_surface_weathering` | 6 methods, 1 failure, 4 engine/script errors |
| `test_map_view_3d_core` | 20 methods, 9 failures, 46 engine/script errors |
| `test_map_view_3d_mesh` | 19 methods, 9 failures, 46 engine/script errors |
| `test_map_view_material_resolution` | 7/7 pass |
| `test_map_view_decals` | 8 methods, 5 failures, 6 engine/script errors |
| `test_map_view_3d_fortification` | 8 methods, 6 failures, 46 engine/script errors |

The first substantive clean diagnostic is:

```text
res://content/maps/lower_town_slice.rrmap:14:1: error[unknown_command]: unknown command 'elevation_area'
res://content/maps/lower_town_slice.rrmap:17:1: error[unknown_command]: unknown command 'elevation_ramp'
res://content/maps/lower_town_slice.rrmap:20:1: error[unknown_command]: unknown command 'elevation_area'
res://content/maps/lower_town_slice.rrmap:22:1: error[unknown_command]: unknown command 'elevation_area'
```

The same parser-dispatch gap is reproduced in R-555 and is assigned to R-453/R-455. Invalid map definitions and missing map/view records that follow are treated as cascade diagnostics until the parser path is repaired.

### Asset, provenance, and evidence-file checks

```sh
python3 "$WT/tools/verify_asset_lint.py"
python3 "$WT/tools/validate_asset_sources.py"
python3 "$WT/tools/verify_p0_102_environment_kit_evidence.py"
```

Recorded R-544 result: all three checks pass on that clean snapshot. The evidence verifier reports **8/8** forge, street/well, brewery, and checkpoint day/night plates. This proves file integrity, dimensions, non-flat content, and matched metadata; it does not prove tier coexistence, visual quality, or human sign-off.

R-557 independently recorded the same scoped pass class on its later revision: asset lint pass, provenance pass, and 8/8 plates. Those results remain useful but are not merged with R-544's runtime counts.

### Decal blocker reproduction

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
export GODOT_LOG_DIR=/tmp/rebel-reval-decal-ground-clearance
mkdir -p "$GODOT_LOG_DIR"
tools/run_godot_checked.sh --require-test-summary p0-102-decal-ground-clearance -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_map_view_decals
```

R-557 records **7/8** in its scoped run. `test_decals_placed_from_map_data` fails `Decal Y must clear ground lift` for the authored `decal_test` soot decal at logic position `(16,16)`. The follow-up **R-571** is still `todo`; it must define the clearance contract, preserve sampled rolling-ground relief and view-only behavior, rerun the decal suite, and rerun the complete P0-102 matrix. The assertion must not be weakened.

### Ordinary-tier and handoff checks

```sh
python3 - <<'PY'
from collections import Counter
from pathlib import Path

counts = Counter()
for line in Path("content/maps/lower_town_slice.rrmap").read_text().splitlines():
    if line.startswith("building ") and "house_tier=" in line:
        counts[line.split("house_tier=", 1)[1].split()[0]] += 1
print(dict(counts), "total=", sum(counts.values()))
PY

# Focused source/contract checks recorded by R-554/R-556.
tools/run_godot_checked.sh --require-test-summary r554-lower-map -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_lower_town_slice_map
tools/run_godot_checked.sh --require-test-summary r554-house-tiers -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_burgher_house_tiers
```

Recorded source count: `merchant_stone=14`, `merchant_timber=14`, `craft_boda=15`, total `43`. The reports record the focused source contracts as green in their respective worktree, but explicitly do not promote them to production-kit delivery or gameplay-scale visual acceptance. R-209-R-212 remain `todo`.

### Gameplay-scale evidence boundary

The P0-102 environment-kit verifier covers the eight dedicated environment plates:

- [`forge_day.png`](images/p0_102_environment_kit/forge_day.png) / [`forge_night.png`](images/p0_102_environment_kit/forge_night.png)
- [`street_well_day.png`](images/p0_102_environment_kit/street_well_day.png) / [`street_well_night.png`](images/p0_102_environment_kit/street_well_night.png)
- [`brewery_day.png`](images/p0_102_environment_kit/brewery_day.png) / [`brewery_night.png`](images/p0_102_environment_kit/brewery_night.png)
- [`checkpoint_day.png`](images/p0_102_environment_kit/checkpoint_day.png) / [`checkpoint_night.png`](images/p0_102_environment_kit/checkpoint_night.png)

The separate Lower Town capture packet has a reproducible command and non-blank matched route plates, but its matrix keeps the three tier rows, roof/material readability, wear, and landmark review rows pending or blocked:

```sh
/Applications/Godot.app/Contents/MacOS/Godot \
  --path . --rendering-method gl_compatibility --rendering-driver opengl3 \
  --script tools/capture_lower_town_p0_101.gd
```

See [`lower_town_p0_101_capture_matrix.md`](lower_town_p0_101_capture_matrix.md), [`burgher_house_art_signoff.md`](burgher_house_art_signoff.md), and the board contracts for R-6, R-108, and R-209-R-213. A valid capture packet is not itself a visual sign-off and cannot replace missing authored tier production evidence.

## Blocker ownership register

| Blocker | Current status | Owner | Required next action |
|---|---|---|---|
| RRMap `elevation_area` / `elevation_ramp` parser dispatch | Reproduced in detached clean baselines | R-453 / R-455, both `in_progress` | Repair/validate parser and elevation acceptance path, then rerun all focused suites from one clean snapshot. |
| Decal ground clearance on rolling terrain | Reproduced independently; 7/8 in R-557 | R-571, `todo` | Define the correct `GROUND_LIFT`/terrain contract, implement the narrow fix, rerun `test_map_view_decals`, then rerun P0-102. |
| Authored ordinary production kits | Not delivered | R-209/R-210/R-211, all `todo` | Deliver the three tier kits, focused tests, lint/provenance, and gameplay-readable outputs. |
| Plot/threshold dressing and tier restrictions | Not delivered | R-212, `todo` | Deliver dressing kit, parser/test coverage, and provenance/lint evidence. |
| Three-tier gameplay-scale capture and final ordinary/landmark review | Evidence packet exists, required review rows remain pending/blocked | R-543 `todo`, R-6 `in_review`, R-108 `todo` | Reconcile matched captures after upstream production handoffs; complete art/canon review without promoting source counts as visual evidence. |
| Shared module coverage recheck | In progress | R-542 `in_progress` | Keep subordinate to the clean-baseline result; do not use a dirty-worktree pass to close R-110. |
| Parent P0-102 readiness | `todo` | R-110 | Keep open until all required gates pass in a synchronized clean rerun. |

No new follow-up task is created by R-558. Existing board rows already own each identified blocker, and creating duplicates would blur the handoff boundaries.

## Final recommendation

**BLOCKED. R-110 / P0-102 must remain `todo`.**

The decomposition is useful and the shared implementation boundaries are present, but the parent is not ready for review or closure because:

1. the clean focused runtime matrix is reproducibly blocked by the R-453/R-455 parser/elevation path;
2. the decal ground-clearance assertion remains independently red under R-571;
3. R-209-R-212 have not delivered the ordinary production kits and plot dressing;
4. no accepted gameplay-scale evidence proves all three R-003 tiers together with the required material, roof, wear, route, collision/navigation, and day/night interpretation; and
5. the exceptional boundary is structurally separated but cannot be declared accepted through a failed clean fortification/runtime matrix or substituted ordinary-house evidence.

The parent may be reconsidered only after the existing owners complete their work and one synchronized clean snapshot reruns the full matrix, including import, asset lint, provenance, shared module integration, material/weathering, decals, core/mesh, fortification, pivot/scale, collision/navigation, route/parity, matched day/night evidence, and three-tier gameplay review.

## Source links

- [`p0_102_handoff_audit.md`](p0_102_handoff_audit.md) - R-554 ordinary/exceptional handoff audit.
- [`p0_102_focused_regression.md`](p0_102_focused_regression.md) - R-555 clean focused regression.
- [`p0_102_scope_ledger.md`](p0_102_scope_ledger.md) - R-556 five-clause implementation ledger.
- [`p0_102_evidence_audit.md`](p0_102_evidence_audit.md) - R-557 asset/visual evidence audit and R-571 decal blocker.
- [`p0_102_environment_kit_clean_baseline.md`](p0_102_environment_kit_clean_baseline.md) - R-540 clean baseline.
- [`p0_102l_environment_kit_closeout.md`](p0_102l_environment_kit_closeout.md) - R-544 current clean closeout addendum.
- [`p0_102_environment_kit_acceptance.md`](p0_102_environment_kit_acceptance.md) - historical four-space evidence packet and scope boundary.
- [`lower_town_p0_101_capture_matrix.md`](lower_town_p0_101_capture_matrix.md) - gameplay-scale capture contract and pending visual rows.
- [`burgher_house_art_signoff.md`](burgher_house_art_signoff.md) - conditional A-009 ordinary-house art review.
- [`test_environment_kit_integration.gd`](../../tests/godot/test_environment_kit_integration.gd) - shared four-space integration contract.
- [`test_burgher_house_tiers.gd`](../../tests/godot/test_burgher_house_tiers.gd) - ordinary tier assignment and exceptional exclusion contract.
- [`map_view_environment_kit.gd`](../../scripts/map/view3d/map_view_environment_kit.gd) - shared environment-kit module assembly.
- [`map_view_mesh_builder_buildings.gd`](../../scripts/map/view3d/map_view_mesh_builder_buildings.gd) - ordinary/exceptional renderer routing.
- [`lower_town_slice.rrmap`](../../content/maps/lower_town_slice.rrmap) - authored tier IDs and map records.
