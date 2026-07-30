# P4-043 Act 1 packaged-candidate preflight

Task: **P4-043**  
Slice: `act1-standalone-candidate`  
Role: QA  
Date: 2026-07-30  
Environment: macOS arm64, Godot 4.7.1 (`/Applications/Godot.app/Contents/MacOS/Godot`)

Independent packaged-candidate preflight for supported input, accessibility, Act 1 content budget, third-party licences, and macOS launch/save/load/exit smoke. This row does not repair runtime, content, assets, export settings, or P4-012 review evidence.

Note on sequencing: **P4-042** advised waiting on **P4-042-F01** / **P0-172** before starting this row, while Current focus still listed **P4-043** as claimable. This preflight ran under the Current focus claim and records the packaging blocker as an in-scope high finding rather than editing runtime.

## Verdict

**Conditional pass for repository-side packaged-candidate contracts; packaged binary / checked-runner smoke blocked.** Keyboard/mouse and gamepad catalog completion, accessibility checklist, Act 1 content-budget, third-party licence surfaces, and repository launch/save/load/exit menu + Act 1 boundary save contracts are green. In-binary macOS install/start/save/load/exit smoke and `tools/run_godot_checked.sh` remain blocked by the open MapViewRuntime parse defect (**P4-043-F01**, same root as **P4-042-F01** / **P0-172**).

## Commands

```bash
export GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
python3 tools/report_accessibility_checklist.py --check
python3 tools/report_act1_content_budget.py --check
python3 tools/report_slice_third_party.py --check
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_act1_packaged_acceptance
tools/run_godot_checked.sh --require-test-summary p4-043-packaged-acceptance -- "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_act1_packaged_acceptance
SKIP_EXPORT=1 tools/verify_supported_platform.sh
```

| Check | Result | Evidence |
|-------|--------|----------|
| Accessibility checklist | pass | `python3 tools/report_accessibility_checklist.py --check` |
| Act 1 content budget / dialogue / audio | pass | `python3 tools/report_act1_content_budget.py --check` - 3658/12000 words, 8269.6s/9000s audio; planned faction-line warnings only |
| Third-party / licence report | pass | `python3 tools/report_slice_third_party.py --check` - 92 assets OK |
| Packaged acceptance suite | pass | `--filter=test_act1_packaged_acceptance` - 8/8, 0 failures |
| Checked runner over the same suite | fail | Suite summary green (8/8) but runner rejects ambient `SCRIPT ERROR` from MapViewRuntime cascade |
| Packaged platform verify (`SKIP_EXPORT=1`) | fail | Stops at `--filter=test_packaged_platform_smoke` when instantiating `main_menu.tscn` (MapViewRuntime -> DoorNavigator / PackagedDemoWalkthrough) |

## Coverage matrix

| Area | Assertion | Result |
|------|-----------|--------|
| Keyboard/mouse + gamepad bindings | Every shipped catalog action has both device bindings | pass |
| Supported-input completion | SliceInputDriver taps every catalog action on both device profiles without `Input.action_press` fallback | pass |
| Accessibility | Checklist required options + settings/overlays present | pass |
| Audio / dialogue budgets | Caps and manifests hold; Python report within budget | pass |
| Asset licences | THIRD_PARTY_NOTICES, CREDITS, slice third-party manifest entries/bundles | pass |
| macOS menu contract | Platform model, export preset files, `build/rr.dmg`, authored Start/Load/Exit + PackagedPlatformSmoke nodes in `main_menu.tscn` | pass |
| Act 1 save/load/exit identity | Clean-start -> seal boundary -> SaveService reload keeps boundary envelope | pass |
| In-binary packaged smoke | `tools/verify_supported_platform.sh` install/start/save/load/exit | fail (**P4-043-F01**) |

## Severity-ranked findings

| ID | Severity | Area | Status | Reproduction | Expected | Actual | Owner |
|----|----------|------|--------|--------------|----------|--------|-------|
| P4-043-F01 | high | runtime parse / packaged smoke | open | `SKIP_EXPORT=1 tools/verify_supported_platform.sh` or `tools/run_godot_checked.sh --require-test-summary p4-043-packaged-acceptance -- "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_act1_packaged_acceptance` | Packaged entrypoint and checked runner exit 0 with a clean summary | `scripts/map/view3d/map_view_runtime.gd:286` uses `_crowd_renderer.configure(max_instances = 200, ...)`; GDScript 4.7 rejects assignment-in-expression, cascading into MapViewRuntime / DoorNavigator / main-menu walkthrough load failures. Focused suite can still report 8/8 while checked runner fails on ambient SCRIPT ERROR. Same root as **P4-042-F01**. | Dev (**P0-172**) |

No critical finding was found inside the repository-side input, accessibility, budget, or licence contracts covered by this row.

## Artifacts

- `tests/godot/test_act1_packaged_acceptance.gd`
- `docs/reports/p4_043_act1_packaged_preflight.md`

## Handoff

- **P4-012** may consume this report for input/accessibility/budget/licence evidence, but must not treat packaged binary smoke as green while **P4-043-F01** / **P0-172** remains open.
- **P0-172** remains the Dev fix that unblocks checked-runner and in-binary macOS smoke before **P4-013** / **P4-044**.
