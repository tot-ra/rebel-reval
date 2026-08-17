# P0-040 Decomposition Verification

**Task:** R-570
**Parent:** R-111 / P0-040
**Date:** 2026-08-17
**Live workspace HEAD:** `5aa5d75caf1b8ffd7e46c8036279cbe8d0e8bd8d`
**Live worktree:** shared worktree with unrelated staged, unstaged, and untracked WIP
**Decision:** **BLOCKED - do not advance R-111 / P0-040 to review or closure**

## Scope and decision rule

This report independently verifies the P0-040 decomposition and determines whether the parent is ready for maintainer review. R-570 is evidence-only: no runtime code, camera code, renderer settings, map data, assets, tests, generated active-doc output, or unrelated report was changed.

The decision rule is strict. A reconciled source contract, a passing headless development check, or a valid calibration packet does not waive a red focused suite, a failed clean-checkout runtime gate, missing minimum-hardware/GPU evidence, stale active documentation, or missing maintainer acceptance. Results from historical reports and the current dirty checkout are kept in their stated evidence boundaries and are not added together as one synchronized acceptance run.

The untracked `docs/reports/p0_040_engine_camera_scale_lock.md` belongs to R-567. It is referenced as live evidence where relevant, but it is not part of the R-570 deliverable or commit.

## Decomposed-subtask reconciliation

| Subtask | Board status | Evidence output | Result used by this verification |
|---|---|---|---|
| R-566 - P0-038 baseline reconciliation | `done` | [`p0_040_baseline_reconciliation.md`](p0_040_baseline_reconciliation.md) | Baseline values are reconciled and the P0-038 headless development baseline is current. GPU texture-memory and minimum-hardware frame-time evidence remain absent, so the report explicitly keeps the technical freeze blocked. |
| R-567 - engine, camera, and world-scale lock | `in_progress` | [`p0_040_engine_camera_scale_lock.md`](p0_040_engine_camera_scale_lock.md) in the shared worktree, currently untracked | Source contract is reconciled, but the focused camera suite is red with 6 assertion failures. The artifact is not a completed board deliverable and does not establish parent readiness. |
| R-568 - lighting, grade, and material style-lock | `done` | [`p0_040_lighting_grade_style_lock.md`](p0_040_lighting_grade_style_lock.md) | Lighting/material contract and calibration evidence are recorded, but the current lighting suite has 2 failures and 2 engine errors. GPU/minimum-hardware evidence and maintainer sign-off remain blockers. |
| R-569 - maintainer technical-freeze approval packet | `todo` | No approval packet or acceptance decision recorded | The required explicit maintainer accept/reject/pending decision is missing. No approval can be inferred from R-566 or R-568. |
| R-570 - decomposition verification | `in_progress` | This report | Verification result is **BLOCKED** because the subordinate evidence and parent acceptance gates are incomplete or red. |
| R-111 / P0-040 parent | `todo` | Parent task contract | Must remain `todo`; it is not ready for review or closure. |

## Evidence snapshots and authority boundaries

| Evidence source | Revision / worktree | What it establishes | Authority boundary |
|---|---|---|---|
| R-566 baseline reconciliation | Report records historical P0-038 measurements and current source reconciliation | The freeze fields have one reconciled implementation value each, and the headless development baseline is within its reference budget | Does not prove current-checkout GPU usage, minimum-hardware frame time, or maintainer approval |
| R-567 engine/camera/scale lock | Live shared worktree, untracked report; task remains `in_progress` | Renderer, viewport, projection, camera modes, world scale, pivots, and view-only invariants are documented | The report itself records 6 camera-suite failures and missing hardware evidence; it is not a completed acceptance gate |
| R-568 lighting/style lock | Completed report in the current repository | Lighting, grade, day/night, value hierarchy, and `style-lock-v1.1` are reconciled; ADR 0018 calibration passes | Current 3D lighting integration is not green, and the report explicitly excludes GPU/minimum-hardware acceptance and maintainer sign-off |
| Current dirty checkout | `5aa5d75caf1b8ffd7e46c8036279cbe8d0e8bd8d`; shared worktree | Current command results and board state for this verification | Not a clean acceptance snapshot; unrelated WIP was not cleaned, staged, or absorbed |
| Detached clean-checkout gate | Detached clean worktree at current `HEAD`, with runtime LFS assets restored | Import passed when the explicit Godot binary was supplied; the clean Lower Town/MapView runtime gate failed with parser and downstream runtime diagnostics | Establishes that the parent cannot claim a clean runtime gate from this revision; it does not assign ownership of unrelated implementation defects to R-570 |

## Parent acceptance matrix

| P0-040 acceptance area | Reconciled evidence | Acceptance result | Blocker and owner |
|---|---|---|---|
| Engine, renderer, viewport, projection, and world scale | R-566 and R-567 document Godot 4.7, GL Compatibility, `1920x1080` design viewport, perspective gameplay modes, orthographic top-down alternate, one logic cell per world unit, character scale, and mesh-builder height/pivot rules | **SOURCE CONTRACT PASS / PARENT BLOCKED** | R-567 remains `in_progress`; focused camera integration is red. R-567 must complete its own task and rerun the relevant contract evidence. |
| Camera behavior and integration | R-567 records the current contract and the separate runtime-camera suite passes 1/1 | **BLOCKED** | `test_map_camera_modes`: 11 tests, 6 assertion failures covering building collision pull-out, first-person eye height, third-person boom distance, and scroll-zoom restoration. Owner remains the camera/runtime task, not R-570. |
| Lighting, grade, day/night, and material style-lock | R-568 reconciles live constants with ART_BIBLE v2, ADR 0018, and `style-lock-v1.1`; calibration verifier passes | **CONTRACT PASS / INTEGRATION BLOCKED** | `test_map_view_3d_lighting`: 15 tests, 13 passed, 2 failed, 2 engine errors. `st_catherines_church` is missing `WindowLights`; the follow-on `apply_cycle_progress` call receives `Nil`. Owner remains the existing lighting/view test or runtime task, not R-570. |
| P0-038 performance and GPU evidence | P0-038 generator and its 5/5 Python unit tests pass; historical headless Lower Town p95 is `7.346 ms` against `16.67 ms`; headless renderer reports zero texture/video memory | **BLOCKED** | A non-headless benchmark on the declared minimum-supported-hardware profile is missing. Zero-byte dummy-renderer readings cannot establish GPU texture memory. Owners: R-569/R-570 follow-up approval/evidence packet. |
| Current clean runtime/load gate | Detached checkout import passed after restoring runtime LFS assets and supplying `/Applications/Godot.app/Contents/MacOS/Godot`; the subsequent clean filter failed with `67 tests, 41 failures, 193 errors` | **BLOCKED** | First substantive diagnostics include unknown RRMap commands `elevation_area` and `elevation_ramp`, followed by map/view cascade failures such as transition-door dictionary access and invalid map definitions. Preserve the existing parser/map owners; do not repair them in R-570. |
| Documentation and active-report consistency | Scoped report whitespace checks pass; P0-038 report is current | **BLOCKED** | `python3 tools/generate_active_docs_report.py --check` reports `docs/reports/active_markdown_report.md is not up to date`. Updating that generated repository-wide report is outside the R-570 allowlist. |
| Maintainer approval | ADR 0013 requires maintainer sign-off plus P0-038 technical evidence; R-569 is still `todo` | **BLOCKED** | No explicit accept/reject/pending decision is recorded. R-569 owns the approval packet and any permitted ART_BIBLE/coordination update. |

## Exact verification commands and recorded results

All commands below were run against the live checkout unless the command explicitly creates a detached clean worktree. A non-zero result is recorded as a blocker and is not waived.

### Baseline and calibration evidence

```bash
python3 tools/generate_p038_comparison_report.py --check
# PASS: P0-038 comparison report is up to date

python3 -m unittest tests.python.test_generate_p038_comparison_report -v
# PASS: 5/5 tests

python3 tools/verify_adr0018_calibration_captures.py
# PASS: ADR0018_CALIBRATION_CAPTURES_PASS
```

These are valid development/calibration checks. They do not establish a minimum-hardware GPU capture or maintainer acceptance.

### Active documentation

```bash
python3 tools/generate_active_docs_report.py --check
# FAIL (exit 1): docs/reports/active_markdown_report.md is not up to date
```

The generated report was not modified because R-570 permits only this verification report.

### Focused camera suite

```bash
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_map_camera_modes
# FAIL: 11 tests, 6 failures, 0 errors
```

Recorded failures:

- `test_building_collision_pulls_camera_out`: camera is not pulled out of the building AABB after follow.
- `test_c_cycles_third_person_first_person_and_top_down`: first-person camera does not sit at eye height.
- `test_mouse_drag_pitch_orbits_perspective_modes_and_yaw_turns_character`: third-person pitch does not keep the follow boom distance.
- `test_third_person_scroll_zoom_clamps_and_enters_first_person`: restored boom distances do not meet the max/min follow positions, and the zoom-entered first-person camera does not sit at eye height.

### Focused lighting suite

```bash
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_map_view_3d_lighting
# FAIL: 15 tests, 13 passed, 2 failures, 2 engine errors
```

The failing test is `test_houses_get_evening_window_lights_with_per_building_variation`. Godot reports `Node not found: "WindowLights"` relative to `Building_st_catherines_church`; the test then reports `Invalid call. Nonexistent function 'apply_cycle_progress' in base 'Nil'`. The two assertion failures are that `st_catherines_church` needs evening window lights and participating houses still need glass panes. No runtime or test repair is permitted by R-570.

### Clean-checkout load gate

```bash
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
bash tools/verify_clean_checkout_load.sh
# FAIL during clean Lower Town/MapView runtime load
```

The gate created a detached checkout at the live `HEAD`, restored 37 runtime LFS objects, and completed clean import with the explicit Godot binary. The focused clean load/test stage then failed with `67 tests, 41 failures, 193 errors`. The first substantive diagnostics were:

```text
res://content/maps/lower_town_slice.rrmap:14:1: error[unknown_command]: unknown command 'elevation_area'
res://content/maps/lower_town_slice.rrmap:17:1: error[unknown_command]: unknown command 'elevation_ramp'
res://content/maps/lower_town_slice.rrmap:20:1: error[unknown_command]: unknown command 'elevation_area'
res://content/maps/lower_town_slice.rrmap:22:1: error[unknown_command]: unknown command 'elevation_area'
```

Downstream diagnostics include a transition-door dictionary `id` access error and invalid map-definition errors. These are recorded as clean-checkout blockers and remain owned by the relevant parser/map/view tasks. R-570 does not classify them as defects introduced by this documentation change.

### Scoped report hygiene

```bash
git diff --check -- \
  docs/reports/p0_040_baseline_reconciliation.md \
  docs/reports/p0_040_engine_camera_scale_lock.md \
  docs/reports/p0_040_lighting_grade_style_lock.md \
  docs/reports/p0_038_3d_view_comparison.md
# PASS
```

The repository-wide worktree is intentionally dirty. Only `docs/reports/p0_040_decomposition_verification.md` is in the R-570 allowlist; R-567's untracked report and all other WIP must remain outside the R-570 commit.

## Blocker ownership register

| Blocker | Status | Owner | Required next action |
|---|---|---|---|
| Camera integration failures | Reproduced: 6 failures in 11 tests | R-567 / camera-runtime owner | Resolve or explicitly accept the camera behavior, then rerun `test_map_camera_modes` and complete R-567. |
| Missing `WindowLights` / glass-pane evidence for `st_catherines_church` | Reproduced: 2 failures and 2 engine errors | Existing lighting/view task; outside R-570 | Repair the authored/runtime contract or update the owning acceptance artifact, then rerun `test_map_view_3d_lighting`. |
| GPU texture-memory evidence | Missing; headless values are zero | R-569/R-570 follow-up | Run `BENCHMARK_HEADLESS=0 tools/run_performance_report.sh` on the declared target and retain evidence. |
| Minimum-supported-hardware frame-time evidence | Missing; `7.346 ms` is a historical development/headless baseline | R-569/R-570 follow-up | Run the benchmark against `tools/benchmarks/minimum-hardware.json` on the declared minimum profile. |
| Clean parser/map/view runtime gate | Reproduced in detached current-HEAD checkout | Existing parser/map/view owners | Repair the first parser diagnostic and rerun the full clean focused matrix; do not treat downstream cascade counts as independent defects until then. |
| Active Markdown report stale | Reproduced by `generate_active_docs_report.py --check` | Documentation/coordination owner | Regenerate and validate the repository-wide active report in its own scoped task. |
| Maintainer technical-freeze decision | Missing; R-569 is `todo` | R-569 | Produce the approval packet with an explicit pending/accept/reject record. |

No duplicate follow-up task is created by R-570. Existing task-board rows already own the unresolved camera, lighting, parser/runtime, hardware-evidence, and approval boundaries.

## Final recommendation

**BLOCKED. R-111 / P0-040 must remain `todo` and must not advance to review or closure.**

The decomposition has useful source-level coverage, and the P0-038 development/calibration checks are reproducible. It is not ready for parent review because:

1. R-567 is still `in_progress`, its report is untracked, and the focused camera suite has 6 assertion failures;
2. the focused lighting suite has 2 assertion failures and 2 engine errors around missing `WindowLights` on `st_catherines_church`;
3. the clean current-HEAD runtime gate fails with parser and downstream map/view diagnostics;
4. non-headless GPU texture-memory and minimum-supported-hardware frame-time evidence are absent;
5. the active Markdown report is stale; and
6. R-569 has not recorded the explicit maintainer decision required by ADR 0013.

The parent may be reconsidered only after the existing owners complete their work, the required hardware evidence is captured, the approval packet records a maintainer decision, active documentation is regenerated, and one synchronized clean snapshot reruns the relevant P0-040 evidence without red focused gates.

## Source links

- [`p0_040_baseline_reconciliation.md`](p0_040_baseline_reconciliation.md) - R-566 P0-038 baseline and freeze-gap reconciliation.
- [`p0_040_engine_camera_scale_lock.md`](p0_040_engine_camera_scale_lock.md) - R-567 engine/camera/world-scale lock; live untracked artifact, not part of this commit.
- [`p0_040_lighting_grade_style_lock.md`](p0_040_lighting_grade_style_lock.md) - R-568 lighting, grade, and material contract.
- [`p0_038_3d_view_comparison.md`](p0_038_3d_view_comparison.md) - P0-038 development performance comparison.
- [`adr/0013-authorial-visual-direction-without-blind-ux-panels.md`](../adr/0013-authorial-visual-direction-without-blind-ux-panels.md) - maintainer acceptance path.
- [`adr/0018-saturated-hdr-fantasy-anime-visual-direction.md`](../adr/0018-saturated-hdr-fantasy-anime-visual-direction.md) - accepted visual direction and evidence boundary.
- [`test_map_camera_modes.gd`](../../tests/godot/test_map_camera_modes.gd) - camera integration contract.
- [`test_map_view_3d_lighting.gd`](../../tests/godot/test_map_view_3d_lighting.gd) - lighting integration contract.
- [`generate_active_docs_report.py`](../../tools/generate_active_docs_report.py) - active-document consistency check.
- [`verify_clean_checkout_load.sh`](../../tools/verify_clean_checkout_load.sh) - detached clean runtime gate.
