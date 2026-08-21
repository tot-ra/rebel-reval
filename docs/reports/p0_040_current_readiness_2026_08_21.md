# P0-040 current technical-freeze readiness

Recorded: 2026-08-21
Task: `R-111 / P0-040`
Baseline revision tested: `2278c5afd3b002f9fe0c84ae7d08081df2abcc89`
Decision: **BLOCKED - keep the parent in progress**

## Purpose

This is the current parent-level re-verification of the P0-040 technical visual freeze. It does not supersede the detailed value matrices in the linked decomposition reports. It determines whether the previously recorded blockers have cleared on the current `main` revision without treating a dirty shared worktree as a synchronized acceptance snapshot.

The proposed engine, camera, scale, lighting, grade, day/night, value-hierarchy, and `style-lock-v1.1` values remain fully specified in:

- [`p0_040_engine_camera_scale_lock.md`](p0_040_engine_camera_scale_lock.md);
- [`p0_040_lighting_grade_style_lock.md`](p0_040_lighting_grade_style_lock.md); and
- [`p0_040_maintainer_approval_packet.md`](p0_040_maintainer_approval_packet.md).

ADR 0013 continues to cancel the blind-panel gate. P0-040 still requires green technical evidence and an explicit maintainer decision.

## Verification results

| Gate | Command | Result |
|---|---|---|
| P0-038 report | `python3 tools/generate_p038_comparison_report.py --check` | **PASS** - report is current. |
| P0-038 focused unit tests | `python3 -m unittest tests.python.test_generate_p038_comparison_report -v` | **PASS** - 5/5. |
| ADR 0018 calibration | `python3 tools/verify_adr0018_calibration_captures.py` | **PASS** - `ADR0018_CALIBRATION_CAPTURES_PASS`. |
| Camera integration | `tools/run_godot_checked.sh --require-test-summary p0040-camera -- "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_map_camera_modes` | **FAIL** - 11 tests, 6 failures, 0 errors. Failures remain in building pull-out, first-person eye height, third-person boom preservation, and scroll-zoom restoration. |
| Lighting integration | `tools/run_godot_checked.sh --require-test-summary p0040-lighting -- "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_map_view_3d_lighting` | **FAIL** - 15 tests, 2 failures, 2 errors. `st_catherines_church` still lacks the expected `WindowLights` node and glass-pane evidence. |
| Active Markdown consistency | `python3 tools/generate_active_docs_report.py --check` | **FAIL** - `docs/reports/active_markdown_report.md` is stale. |
| Detached clean-checkout load | `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot tools/verify_clean_checkout_load.sh` | **INCONCLUSIVE** - import remained active past the tool's 90-second execution window and its surviving process tree was terminated. No pass or fail is inferred. |
| Declared minimum-hardware GPU evidence | Review of `tools/benchmarks/minimum-hardware.json` and current evidence packet | **MISSING** - the target remains Intel Core i5-8250U / Intel UHD Graphics 620 / 8 GiB / 1920x1080. Headless or Apple M-series measurements do not certify it. |
| Maintainer decision | [`p0_040_maintainer_approval_packet.md`](p0_040_maintainer_approval_packet.md) | **PENDING** - no maintainer identity, date, or `ACCEPT` decision is recorded. |

## Worktree boundary

The shared worktree contained unrelated staged, unstaged, and untracked work, including live changes to `content/maps/lower_town_slice.rrmap`, `scripts/map/view3d/map_view_3d.gd`, and role playbooks. The repository `HEAD` also changed while verification was in progress. This task therefore did not modify camera, lighting, map, generated active-report, or benchmark runtime files and does not claim a single synchronized runtime acceptance snapshot.

## Blocker ownership

1. Repair and independently verify the camera-mode contract until `test_map_camera_modes` passes.
2. Restore the Lower Town landmark window-light contract until `test_map_view_3d_lighting` passes without engine diagnostics.
3. Obtain a non-headless run on the declared Intel UHD 620 minimum target, recording frame time and GPU/texture memory with provenance.
4. Regenerate the active Markdown report in an isolated clean snapshot and pass its check.
5. Rerun the bounded detached clean-checkout load gate after the runtime fixes.
6. Ask the maintainer to review the complete packet and explicitly record `ACCEPT`, `REJECT`, or continued `PENDING`.

Dedicated follow-up board tasks own items 1-4: `R-652` camera, `R-655` lighting, `R-653` minimum-hardware evidence, and `R-654` active documentation. The parent remains `in_progress`; moving it to review or done would misrepresent the required evidence and approval.

## Final decision

**P0-040 is not complete.** The technical value set is fully documented and the P0-038 report plus ADR 0018 calibration checks pass, but two focused runtime suites are red, minimum-hardware GPU evidence is absent, documentation consistency is red, the clean gate is inconclusive, and maintainer acceptance is pending.
