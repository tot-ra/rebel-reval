# P4-012 Act 1 maintainer gate

Task: **P4-012**  
Slice: `act1-standalone-candidate`  
Role: QA / maintainer (authorial acceptance per [ADR 0014](../adr/0014-authorial-acceptance-gates-without-external-playtests.md))  
Date: 2026-07-30  
Environment: macOS arm64, Godot 4.7.1 (`/Applications/Godot.app/Contents/MacOS/Godot`)

This report closes the Act 1 standalone-candidate maintainer gate. Scope is the accepted eight-quest / one-climax Act 1 budget only. No external playtest quota applies. No new quest scope was added. Failed automation was not waived.

## Review method

1. Consumed independent QA preflights [p4_042_act1_candidate_preflight.md](p4_042_act1_candidate_preflight.md) and [p4_043_act1_packaged_preflight.md](p4_043_act1_packaged_preflight.md).
2. Re-ran Act 1 traversal, candidate acceptance, packaged acceptance, all six cycle filters, and macOS packaged install/start/save/load/exit smoke on repository HEAD after **P0-172** cleared the MapViewRuntime parse chain.
3. Maintainer playable review covered completion, comprehension, pacing, combat, choice impact, continuity, and supported inputs against automated branch evidence (ADR 0014).

## Verdict

**Pass.** Act 1 stands as a coherent standalone chapter: intended Seal / Break / Open boundaries are reachable from a clean save, invalid transitions stay rejected, consequences reload cleanly, supported inputs and release-facing safeguards hold, and every critical/high finding from P4-042 / P4-043 is closed.

## Closure of P4-042 / P4-043 critical and high findings

| Finding | Severity | Preflight status | Gate status | Evidence |
|---------|----------|------------------|-------------|----------|
| P4-042-F01 | high | open (MapViewRuntime assignment-in-expression at crowd `configure`) | **closed** | **P0-172** shipped positional `configure(200, hash(...))`; `tools/run_godot_checked.sh --require-test-summary` exits 0 for `test_act1_traversal` (8/8) and `test_act1_candidate_acceptance` (7/7) with no ambient SCRIPT ERROR |
| P4-043-F01 | high | open (same root; blocked checked runner and in-binary packaged smoke) | **closed** | Checked runner green for `test_act1_packaged_acceptance` (8/8) and `test_packaged_platform_smoke` (2/2); `SKIP_EXPORT=1 tools/verify_supported_platform.sh` reports `P3-012_PACKAGED_PLATFORM_PASS steps=install,start,save,load,exit` |

No other critical or high findings were recorded in either preflight. No silent waiver was used.

## Maintainer playable review

| Area | Finding | Severity | Status |
|------|---------|----------|--------|
| Completion | Clean start reaches each act-boundary family (`seal` / `break` / `open`); climax records `flag.act_transition.act1_recorded` and the Act 1 transition envelope | none | closed |
| Comprehension | Investigation facts, forge commissions, night installs, and St. George's Night Seal/Break/Open choices communicate branch outcomes without off-game history or a morality meter | none | closed |
| Pacing | Five day/night cycles plus climax stay inside the approved Act 1 budget (3 districts, 7 core characters, 8 substantial quests, 1 climax); dialogue 3658/12000 words; unique audio 8269.6s/9000s | none | closed |
| Combat | Watch/night routes remain readable through existing slice combat contracts; climax gate choice is non-combat with forge-bias mapping; accessibility combat toggles stay available | none | closed |
| Choice impact | Each cycle maps three forging/technique branches to distinct flags, aftermath barks, and (for climax) distinct act-boundary families; envelope aggregates named characters without aggregate morality | none | closed |
| Continuity | Clean-save replay, published Act 1 fixtures, and legacy game-state v1 migration keep boundary, quest, flag, and phase identity across SaveService reload | none | closed |
| Supported inputs | Every shipped catalog action has keyboard/mouse and gamepad bindings; SliceInputDriver completes both device profiles without `Input.action_press` fallbacks | none | closed |
| Packaged smoke | macOS `rr` DMG install/start/save/load/exit passes through `tools/verify_supported_platform.sh` after P0-172 | none | closed |

### Non-blocking observations (not gate failures)

| ID | Severity | Note |
|----|----------|------|
| P4-012-N01 | low | Headless cycle hosts still log Compatibility-renderer warnings for auto-exposure / DoF and ObjectDB/resource-leak messages at process exit. Suites and checked runner remain green. Optional Dev hygiene if leaks grow. |
| P4-012-N02 | info | Act 1 content-budget report still warns that faction lines `faction_line.livonian_order` and `faction_line.black_cloaks` remain planned for **P4-021**; within approved budget, not a gate defect. |

## Sub-gate evidence

| Source | Gate | Status | Key verifier |
|--------|------|--------|--------------|
| P4-042 | Clean-save / branch / migration preflight | pass (F01 closed at gate) | `--filter=test_act1_candidate_acceptance` 7/7; `--filter=test_act1_traversal` 8/8; `report_act1_traversal.py --check` |
| P4-043 | Packaged input / accessibility / licence / smoke preflight | pass (F01 closed at gate) | `--filter=test_act1_packaged_acceptance` 8/8; accessibility / content-budget / third-party reports; `verify_supported_platform.sh` |
| P4-011 | Intended endings and invalid transitions | pass | traversal manifest + suite |
| P4-010 | Content / dialogue / audio budget | pass | `report_act1_content_budget.py --check` |
| P0-172 | MapViewRuntime parse fix | pass | positional crowd `configure`; checked runner green |
| Cycle filters | Bell and Chain, Bread and Iron, Price of a Name, Root and Ember, St. George's Night, Act 1 aftermath | pass | 4/4 each via checked runner |

## Automated verification

```bash
export GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"

python3 tools/report_act1_traversal.py --check
python3 tools/report_act1_content_budget.py --check
python3 tools/report_accessibility_checklist.py --check
python3 tools/report_slice_third_party.py --check
python3 tools/report_slice_platform.py --check
python3 tools/release_candidate_check.py

tools/run_godot_checked.sh --require-test-summary p4-012-act1-traversal -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_act1_traversal
tools/run_godot_checked.sh --require-test-summary p4-012-candidate -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_act1_candidate_acceptance
tools/run_godot_checked.sh --require-test-summary p4-012-packaged-acceptance -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_act1_packaged_acceptance

for f in test_bell_and_chain_cycle test_bread_and_iron_cycle test_price_of_a_name_cycle \
         test_root_and_ember_cycle test_st_georges_night_cycle test_act1_aftermath; do
  tools/run_godot_checked.sh --require-test-summary "p4-012-$f" -- \
    "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter="$f"
done

SKIP_EXPORT=1 tools/verify_supported_platform.sh
```

All commands above exited 0 on 2026-07-30 gate evidence.

## Maintainer sign-off

| Reviewer | Date | Notes |
|----------|------|-------|
| maintainer | 2026-07-30 | Act 1 standalone-candidate gate passes per ADR 0014; P4-042-F01 and P4-043-F01 closed by P0-172 re-check; packaging may proceed |

## Result

**Pass (Act 1 standalone-candidate gate).** Next step: **P4-013** export the accepted candidate to `build/act1/**` with frozen save/content contracts, then **P4-044** independent release acceptance over that exact package.
