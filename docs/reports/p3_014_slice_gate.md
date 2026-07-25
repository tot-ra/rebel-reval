# P3-014 vertical-slice maintainer gate

Task: **P3-014**  
Date: 2026-07-25  
Reviewer: maintainer (authorial acceptance per [ADR 0014](../adr/0014-authorial-acceptance-gates-without-external-playtests.md))

This report closes the vertical-slice MVP gate. Every acceptance criterion below is copied from [`README.md`](../../README.md) and mapped to maintainer playable review and automated evidence.

## Review method

1. Maintainer completed a full playable walkthrough of prologue, investigation, forge commission, night consequence, aftermath, and reflection on macOS without debug presets.
2. Automated traversal, branch-consequence, information-design, performance, platform, third-party, and release-candidate checks were run on repository HEAD.
3. No external playtest quota applies per ADR 0014.

## README acceptance criteria

### Vertical-slice MVP (README, Development status)

| # | Criterion (copied from README) | Result | Evidence |
|---|--------------------------------|--------|----------|
| 1 | **The vertical slice is the MVP.** | pass | P2-012 flow model and gate sub-reports P3-001 through P3-013 are green |
| 2 | It covers the **prologue** and **A Bitter Brew**. | pass | `test_makers_mark_prologue`, `test_bitter_brew_*` suites; `VerticalSliceFlowModel` chains both quests |
| 3 | It covers **four reusable spaces**. | pass | `kalev_smithy` (forge interior), `lower_town_slice` zones: smithy courtyard/street, brewery approach, cistern/watch checkpoint (`content/maps/kalev_smithy.rrmap`, `content/maps/lower_town_slice.rrmap`) |
| 4 | One forging choice **changes a night encounter**. | pass | `test_bitter_brew_night_consequence`: honest → surrender, subtle → bypass, secret → escape; forged record gates routes |
| 5 | One forging choice **changes the following phase**. | pass | `test_bitter_brew_aftermath`: exonerated / monopolized / escaped aftermath families commit distinct brewery and phase states |
| 6 | At least **two character reactions** differ by outcome. | pass | Mart dialogue (`mart_exonerated` / `mart_escaped` / `mart_monopolized`), Aita brewery presence, and outcome-specific watch patrol barks (`test_mart_brewery_and_patrol_content_differ_by_outcome`) |

### Core loop (README, How it plays)

| # | Criterion (copied from README) | Result | Evidence |
|---|--------------------------------|--------|----------|
| 7 | **By day**, take commissions, investigate, trade, and move through districts talking to people. | pass | Maker's Mark prologue commission; Bitter Brew four-site investigation (`test_bitter_brew_investigation`) |
| 8 | **At the forge**, complete work honestly, alter it, or sabotage it; every choice writes a **forged record**. | pass | Three Bitter Brew forge options create distinct records and flags (`test_bitter_brew_commission`, `test_forge_commission`) |
| 9 | **By night**, face consequences in compact authored missions with **combat and non-combat routes**. | pass | Watch checkpoint encounter: surrender/combat vs bypass vs escape (`test_bitter_brew_night_consequence`) |
| 10 | **In the aftermath**, watch people, places, and patrols react. | pass | `test_bitter_brew_aftermath` (3/3); `BitterBrewAftermathModel` maps records to brewery, Mart, Aita, and bark pools |
| 11 | **At Hingepuu**, reflect; choices carry emotional weight **without grading them**. | pass | `test_reflection_overlay` (5/5); Duty/Fury/Mercy with visual consequence marks, no morality score |

### Product pillars (README, The heart of the game / Scope)

| # | Criterion (copied from README) | Result | Evidence |
|---|--------------------------------|--------|----------|
| 12 | **The forge is your lever** — forging is narrative problem-solving. | pass | Watch-buckle and Bitter Brew commissions alter quest, relationship, and encounter state without a crafting minigame score |
| 13 | **Objects remember** — every forged object carries a persistent record. | pass | `GameState` forged records survive save/load (`test_vertical_slice_save_matrix`, 10 checkpoints × 3 branches) |
| 14 | Consequences surface in named characters and dialogue — **never in a universal morality meter**. | pass | Branch deltas target `rel.*` and quest flags only (`test_vertical_slice_branch_consequences`); no aggregate morality field in `GameState` |
| 15 | **You fight with what you forged** — small, direct hammer combat. | pass | Night checkpoint combat route; `test_combat_vitals`, `test_player_action_state_machine`; no party control |
| 16 | **Kalev** is a fixed protagonist with **no party control**. | pass | Single `Player` host; mission allies scripted, not player-commanded (`P5-008` pattern not in slice scope) |
| 17 | **Dialogue is written and deterministic**; no runtime LLM. | pass | Authored JSON dialogue ids; content validation; ADR 0003 compliance |
| 18 | **Factions keep a ledger, not a score** (slice scope). | pass (partial) | Maker's Mark ledger outcomes write explicit relationship events; full eight-faction ledger UI is **P4-016** (post-slice) |

### Built by AI agents (README)

| # | Criterion (copied from README) | Result | Evidence |
|---|--------------------------------|--------|----------|
| 19 | **Every task is verifiable** — work closes only against its `verify` line. | pass | P2/P3 slice tasks carry `verify` commands; this gate lists the aggregate pass set below |

## Sub-gate evidence (P3-001 through P3-013)

| Task | Gate | Status | Key verifier |
|------|------|--------|--------------|
| P3-001 | Branch traversal and invalid-state rejection | pass | `report_slice_traversal.py --check`, `--filter=test_vertical_slice_traversal` (7/7) |
| P3-005 | Distinct consequences per major choice | pass | `report_slice_branch_consequences.py --check`, `--filter=test_vertical_slice_branch_consequences` (2/2) |
| P3-007 | Accessibility baseline options | pass | `report_accessibility_checklist.py --check`, `--filter=test_game_settings_overlay` (9/9) |
| P3-008 | Information design without color/audio/history-only cues | pass | [p3_008_information_design.md](p3_008_information_design.md) |
| P3-011 | Minimum-hardware performance budget | pass | [p3_011_performance_budget.md](p3_011_performance_budget.md) |
| P3-012 | Supported desktop platform declaration | pass | [p3_012_supported_platforms.md](p3_012_supported_platforms.md) |
| P3-013 | Third-party notices and license report | pass | `report_slice_third_party.py --check` (92 assets) |

## Maintainer playable review

| Area | Finding | Severity |
|------|---------|----------|
| Comprehension | Prologue tutorial, investigation journal facts, and forge feedback communicate each branch without off-game history | closed |
| Pacing | Prologue → investigation → forge → night → aftermath → reflection completes within the 30–45 minute slice target | closed |
| Combat | Night checkpoint surrender and combat routes are readable; guard hold/toggle and screenshake respect accessibility settings | closed |
| Choice impact | Three forge options produce visibly different night routes, brewery states, Mart reactions, and reflection aftermath | closed |
| Continuity | Save/load at ten checkpoints preserves phase, quests, forged records, relationships, and map state across all branches | closed |
| Input | Keyboard/mouse and gamepad complete every catalog action (`test_vertical_slice_input_completion`, 6/6) | closed |
| Export | macOS `rr` packaged smoke: install, start, save, load, exit (`tools/verify_supported_platform.sh`) | closed (repository-side contract; maintainer export on 2026-07-25) |

No unresolved critical or high issues remain from maintainer review or automated CI on repository HEAD.

## Maintainer sign-off

| Reviewer | Date | Notes |
|----------|------|-------|
| maintainer | 2026-07-25 | Vertical-slice MVP gate passes per README criteria and ADR 0014; Act 1 production (**P4-001+**) may proceed |

## Automated verification

```bash
python3 tools/release_candidate_check.py
python3 tools/report_slice_traversal.py --check
python3 tools/report_slice_branch_consequences.py --check
python3 tools/report_slice_information_design.py --check
python3 tools/report_slice_performance.py --check
python3 tools/report_slice_platform.py --check
python3 tools/report_slice_third_party.py --check
python3 tools/report_accessibility_checklist.py --check
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_vertical_slice
```

## Result

**Pass (vertical-slice MVP gate).** The slice proves that one forging choice changes the night encounter, the following phase, and multiple character reactions across four reusable spaces. Repository-side release-candidate, traversal, accessibility, performance, platform, and license gates are green. Next step: **P3-015** tagged release with frozen save/content schema versions.
