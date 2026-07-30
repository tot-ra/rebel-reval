# P4-042 Act 1 candidate preflight

Task: **P4-042**  
Slice: `act1-standalone-candidate`  
Role: QA  
Date: 2026-07-30  
Environment: macOS arm64, Godot 4.7.1 (`/Applications/Godot.app/Contents/MacOS/Godot`)

Independent clean-save / branch / migration preflight for the Act 1 standalone candidate. This row does not repair runtime or content and does not add a branch.

## Verdict

**Pass for P4-042 scope.** Every Act 1 candidate acceptance check below is green. One ambient high-severity runtime parse defect is recorded for Dev follow-up because it makes `tools/run_godot_checked.sh` fail on otherwise green focused suites and will block packaged acceptance (**P4-043**).

## Commands

```bash
export GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
python3 tools/report_act1_traversal.py --check
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_act1_candidate_acceptance
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_act1_traversal
```

| Check | Result | Evidence |
|-------|--------|----------|
| Act 1 traversal manifest | pass | `python3 tools/report_act1_traversal.py --check` - manifest matches model |
| Candidate acceptance suite | pass | `--filter=test_act1_candidate_acceptance` - 7/7, 0 failures |
| Traversal suite | pass | `--filter=test_act1_traversal` - 8/8, 0 failures |

## Coverage matrix

| Area | Assertion | Result |
|------|-----------|--------|
| Eight-quest / one-climax budget | `act1_content_budget_manifest.json` keeps `substantial_quest_budget=8`, eight IDs, one climax; three boundary endings only | pass |
| Clean start | `tests/fixtures/act1_candidate/clean_start.json` loads with no `act1_transition` | pass |
| Clean-save branch replay | From clean start, each `seal` / `break` / `open` boundary commits, saves through `SaveService`, reloads with matching boundary, quest state, flag, and phase | pass |
| Published fixtures | Every path in `content/saves/act1_fixtures_manifest.json` loads, validates, and round-trips | pass |
| Invalid transitions | All five P4-011 invalid IDs remain rejected | pass |
| Save migration | `tests/fixtures/act1_candidate/game_state_v1_boundary_seal.json` migrates to current game-state version and keeps `act_boundary=seal` | pass |

## Severity-ranked findings

| ID | Severity | Area | Status | Reproduction | Expected | Actual | Owner |
|----|----------|------|--------|--------------|----------|--------|-------|
| P4-042-F01 | high | runtime parse / packaging gate | open | Run `tools/run_godot_checked.sh p4-042-repro -- "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_act1_traversal` after any focused Godot suite | Focused suite exit 0 and checked runner accepts the clean test summary | Suite reports `8/8` / `0 failure(s)` but checked runner fails on ambient `SCRIPT ERROR` from `scripts/map/view3d/map_view_runtime.gd:286` (`Assignment is not allowed inside an expression` in `_crowd_renderer.configure(max_instances = 200, ...)`) cascading into `MapViewRuntime` / `DoorNavigator` load failures | Dev (**P0-172**) |

No critical or high finding remains inside the P4-042 Act 1 branch/save contract itself. **P4-012** should treat **P4-042-F01** as a packaging/runtime blocker owned by Dev before or during **P4-043**.

## Artifacts

- `tests/godot/test_act1_candidate_acceptance.gd`
- `tests/fixtures/act1_candidate/clean_start.json`
- `tests/fixtures/act1_candidate/game_state_v1_boundary_seal.json`

## Handoff

- **P4-012** maintainer gate may consume this report for clean-save / branch / migration evidence.
- **P4-043** remains the packaged input/accessibility/release preflight and should not start until **P4-042-F01** is fixed or explicitly waived by Producer with a typed blocker.
