# R-790 Rentenitorn boss outcomes and durable-state verification

**Task:** R-790 / P4-027d decomposition
**Parent:** R-246 / P4-027d
**Verification date:** 2026-08-28
**Repository:** `main`, shared dirty worktree with unrelated WIP
**Decision:** **PASS for the scoped encounter and persistence verification**

## Scope and boundary

This note verifies only the Rentenitorn encounter outcome contract and its scene-tree-free durable state. No combat, state, content, map, or activation implementation was changed. The package remains developer-only and release-inactive; this verification does not grant historical/art sign-off or release activation.

## Acceptance matrix

| Acceptance clause | Command / test | Result and artifact |
|---|---|---|
| Rentenitorn has the named boss identity and only the authored kill/bypass outcomes | `test_rentenitorn_boss_encounter.gd::test_rentenitorn_content_and_composition_are_distinct`; `tests/python/test_rentenitorn_boss_content.py::test_named_boss_has_only_supported_distinct_outcomes` | **PASS**. Encounter ID is `encounter.rentenitorn_boss`; the boss is the crossbowman composition and differs from Nunnatorn's boss identity. Content exposes `kill` and `bypass`, while surrender is unsupported. Artifact: checked-runner/Python command output. |
| Kill outcome resolves the fought branch | `test_rentenitorn_boss_encounter.gd::test_kill_and_sealed_tally_bypass_produce_distinct_outcomes` | **PASS**. Quest state becomes `night_fought`, `flag.rentenitorn_boss_defeated` is set, the alternate flag stays clear, and both encounter actors are dead. |
| Bypass outcome remains distinct and non-lethal | `test_rentenitorn_boss_encounter.gd::test_kill_and_sealed_tally_bypass_produce_distinct_outcomes` | **PASS**. Quest state becomes `night_bypassed`, the alternate flag is set, the defeated flag stays clear, and both actors remain alive in `DISENGAGE`. |
| Unsupported outcome fails closed without state or enemy mutation | `test_rentenitorn_boss_encounter.gd::test_unsupported_outcome_fails_closed` | **PASS**. The unsupported `ransom` kind returns false; the active quest state, resolved flag, and enemy state remain unchanged. |
| Strongroom stays sealed before resolution and opens exactly once after resolution | `test_rentenitorn_persistence.gd::test_strongroom_stays_sealed_until_the_watcher_is_resolved` | **PASS**. The initial state is `sealed`; opening before an outcome fails; after a kill outcome it opens; a second open attempt fails and the persisted state remains `open`. |
| Loot and evidence are one-shot durable markers | `test_rentenitorn_persistence.gd::test_old_record_migrates_and_one_shot_loot_persists`; `test_rentenitorn_persistence.gd::test_state_round_trips_and_outcome_is_immutable` | **PASS**. `mark_loot_collected()` succeeds once and rejects the second call; `mark_evidence_recorded()` succeeds once and rejects the second call. |
| Save/load preserves the resolved Rentenitorn state and immutable outcome | `test_rentenitorn_persistence.gd::test_state_round_trips_and_outcome_is_immutable` | **PASS**. Entry count, door state, bypass outcome, and evidence marker round-trip through `SaveService` slot data; replacing bypass with kill is rejected. Artifact: checked-runner command output. |
| Legacy Rentenitorn object data migrates to the current state version | `test_rentenitorn_persistence.gd::test_old_record_migrates_and_one_shot_loot_persists` | **PASS**. Legacy aliases (`version`, `door`, `boss`, `strongroom`, `entries`) normalize to `state_version=1` and the current field names without losing values. |
| Failed retry restores the pre-fight payload | `test_rentenitorn_persistence.gd::test_failed_retry_restores_pre_fight_payload_without_nodes` | **PASS**. The checkpoint restores `night_ready` and the unresolved flag after a simulated failed fight, then returns the retry marker to `armed`. |
| Retry/save payload contains no scene nodes | `test_rentenitorn_persistence.gd::test_failed_retry_restores_pre_fight_payload_without_nodes` | **PASS**. Canonical serialization of `GameState.save_payload()` contains `retry_state` and no `Node` value. |
| Stable identity is not reused across completed tower packages | `test_completed_tower_packages.gd::test_catalog_covers_all_completed_1343_towers`; `test_completed_tower_packages.gd::test_catalog_rejects_reused_ids_and_one_way_transitions` | **PASS**. The four-package catalog validates cleanly, and the negative test rejects duplicate stable IDs and one-way transition data. Artifact: checked-runner command output. |
| Rentenitorn content corpus remains valid and the authored boundary stays explicit | `python3 tools/validate_content.py content/examples/valid content/examples/support`; `python3 -m unittest tests/python/test_rentenitorn_boss_content.py -v` | **PASS**. Corpus validator exits 0; all 3 focused Python tests pass. The fixture remains `confidence: invented`, `canon_status: draft`, and the report remains `HUMAN SIGN-OFF PENDING` / developer-only. |

## Exact checked summaries

```text
Godot headless tests: 1 file(s), 3 test(s), 0 failure(s), 0 error(s).
Godot headless tests: 1 file(s), 4 test(s), 0 failure(s), 0 error(s).
Godot headless tests: 1 file(s), 3 test(s), 0 failure(s), 0 error(s).
Ran 3 tests in 0.033s
OK
```

The first exploratory invocation of `tools/validate_content.py` used an individual JSON file and returned the expected schema-reference diagnostic (`unknown quest id 'quest.bitter_brew'`) because this validator's CLI expects content root directories. The corrected corpus invocation above exits 0; this is recorded as an invocation correction, not a content failure.

## Source contract

- `scripts/combat/rentenitorn_boss_encounter.gd` owns Rentenitorn IDs, composition, fail-closed outcome selection, and branch flags.
- `scripts/combat/rentenitorn_state_model.gd` owns versioned object state, strongroom gating, immutable outcome, one-shot markers, and retry lifecycle.
- `scripts/combat/encounter_checkpoint.gd` stores only a duplicated `GameState.save_payload()` and restores it without scene nodes.
- `content/examples/valid/encounter.rentenitorn_boss.json` declares the two supported outcomes and authored/draft confidence boundary.
- `scripts/tower/completed_tower_packages.gd` validates stable IDs across the completed tower catalog and enforces developer-only, inactive descriptors.

## Final status

R-790's focused boss outcome, strongroom, loot/evidence, save/load migration, retry restoration, and serialized-state checks are complete and green. No implementation defect or owning follow-up task was found. Rentenitorn remains developer-only pending the independent historical/art sign-off already tracked by P4-027d.
