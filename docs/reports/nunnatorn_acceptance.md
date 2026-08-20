# R-629: Nunnatorn independent acceptance

- Status: **BLOCKED**
- Parent: R-251 / P4-027b
- Verification owner: R-629 independent QA gate
- Run timestamp: `2026-08-20T14:27:00.189036+00:00`
- Scope: verification only; no runtime implementation files are changed by this gate

## Decision

The gate is fail-closed. Core contract defects are **FAIL**. Missing downstream evidence is **BLOCKED** and is not treated as approval. Historical and art review language is checked separately from the final presentation packet.

## Acceptance matrix

| Clause | Result | Evidence or blocker |
|---|---|---|
| historical/art review | **PASS** | R-622 is accepted with bounded reconstruction; later horseshoe and post-1343 forms are explicitly excluded. |
| exact stable IDs | **PASS** | R-621 table contains exactly 23 reserved IDs. |
| open-backed interior form | **PASS** | Dedicated 18x18 prototype retains two south boundary returns and no rejected later-form token. |
| floor and wall-walk reachability | **PASS** | Focused map test routes from the safe entry to all three floors and the wall-walk anchors. |
| collision/navigation/camera | **PASS** | Authored wall boundaries and bounded scene camera are present; map suite builds navigation geometry. |
| reciprocal exterior/interior transitions | **PASS** | Both directions have stable destination and spawn IDs. |
| dedicated interior scene | **PASS** | Packed scene has a dedicated script, map root, actors, and player. |
| activation isolation | **PASS** | Catalog remains inactive while developer traversal manifest is release=false. |
| boss outcomes and loot/evidence | **PASS** | Kill and bypass branches, separate evidence item, and two journal facts are authored. |
| persistence, save/load, and retry | **PASS** | Stable map state, one-shot collection, migration, and transient retry are covered by source and tests. |
| lighting/audio/readability and day/night captures | **BLOCKED** | R-628 presentation packet is incomplete; missing=scripts/map/view3d/map_view_nunnatorn_interior.gd, scripts/audio/nunnatorn_audio_controller.gd, tests/godot/test_nunnatorn_presentation.gd, day_captures=0, night_captures=0, capture_errors=none. |
| packaged artifact discovery | **PASS** | build/rr.dmg is available for packaged smoke execution. |
| existing Nunnatorn Python content suites | **PASS** | exit=0 |
| focused Godot Nunnatorn suites | **PASS** | exit=0 |
| focused Nunnatorn presentation suite | **BLOCKED** | R-628 presentation test is not available. |
| packaged install/start/save/load/exit smoke | **PASS** | exit=0 |

## Reproducible command record

The command output below is captured from this run. Shutdown-only Godot resource/RID leak lines are allowed by `tools/run_godot_checked.sh`; parser, renderer, resource-loading, and test-summary failures are not waived.

### existing Nunnatorn Python content suites: PASS

```text
$ /Applications/Xcode.app/Contents/Developer/usr/bin/python3 -m unittest tests.python.test_nunnatorn_boss_content tests.python.test_nunnatorn_evidence_content -v
exit=0
test_content_corpus_accepts_encounter_and_preserves_historical_boundary (tests.python.test_nunnatorn_boss_content.NunnatornBossContentTests) ... ok
test_named_boss_and_reserved_route_contract (tests.python.test_nunnatorn_boss_content.NunnatornBossContentTests) ... ok
test_unsupported_outcome_is_not_authored (tests.python.test_nunnatorn_boss_content.NunnatornBossContentTests) ... ok
test_authored_item_and_separate_journal_records_are_stable (tests.python.test_nunnatorn_evidence_content.NunnatornEvidenceContentTests) ... ok
test_collection_transitions_are_outcome_aware_and_idempotent (tests.python.test_nunnatorn_evidence_content.NunnatornEvidenceContentTests) ... ok
test_scoped_content_corpus_is_valid (tests.python.test_nunnatorn_evidence_content.NunnatornEvidenceContentTests) ... ok

----------------------------------------------------------------------
Ran 6 tests in 0.029s

OK
```

### focused Godot Nunnatorn suites: PASS

```text
$ /Users/artjomkurapov/git/rebel-reval/tools/run_godot_checked.sh --require-test-summary nunnatorn-acceptance -- /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_nunnatorn_interior_map,test_nunnatorn_transitions,test_nunnatorn_boss_encounter,test_nunnatorn_evidence,test_nunnatorn_persistence
exit=0
Godot Engine v4.7.1.stable.official.a13da4feb - https://godotengine.org

Godot headless tests: discovered 5 file(s).
RUN res://tests/godot/test_nunnatorn_boss_encounter.gd (5 test(s))
  PASS test_alternate_bypass_resolves_and_keeps_boss_and_guard_alive
  PASS test_content_definition_exposes_named_boss_outcomes
  PASS test_deterministic_composition_and_readable_anchors
  PASS test_lethal_kill_marks_boss_dead_and_keeps_lethal_branch_distinct
  PASS test_unsupported_outcome_fails_closed_without_state_or_enemy_mutation
RUN res://tests/godot/test_nunnatorn_evidence.gd (4 test(s))
  PASS test_alternate_resolution_records_witness_without_lethal_loot
  PASS test_content_exposes_loot_and_two_journal_records
  PASS test_lethal_resolution_collects_item_and_ledger_fact_once
  PASS test_mixed_outcome_flags_fail_closed_without_starting_collection
RUN res://tests/godot/test_nunnatorn_interior_map.gd (1 test(s))
  PASS test_nunnatorn_interior_map
RUN res://tests/godot/test_nunnatorn_persistence.gd (5 test(s))
  PASS test_failed_encounter_retry_restores_pre_fight_state_and_keeps_checkpoint_transient
  PASS test_fresh_entry_creates_stable_state_and_round_trips_through_save_service
  PASS test_lethal_and_alternate_outcomes_persist_without_being_overwritten_on_reentry
  PASS test_nunnatorn_evidence_flags_and_stable_state_survive_save_load
  PASS test_older_nunnatorn_record_migrates_with_safe_defaults
RUN res://tests/godot/test_nunnatorn_transitions.gd (1 test(s))
  PASS test_nunnatorn_transition_ids_are_reciprocal
Godot headless tests: 5 file(s), 16 test(s), 0 failure(s), 0 error(s).
WARNING: 118 ObjectDB instances were leaked at exit (run with `--verbose` for details).
   at: cleanup (core/object/object.cpp:2536)
ERROR: 8 resources still in use at exit (run with --verbose for details).
   at: clear (core/io/resource.cpp:822)
```

### packaged install/start/save/load/exit smoke: PASS

```text
$ /Users/artjomkurapov/git/rebel-reval/tools/verify_supported_platform.sh
exit=0
==> P3-012 repository-side platform contract
Slice platform report (P3-012)
  supported platforms: 1
  status: manifest and export contract are valid
test_manifest_matches_authored_model (tests.python.test_report_slice_platform.TestReportSlicePlatform) ... ok

----------------------------------------------------------------------
Ran 1 test in 0.000s

OK
==> P3-012 packaged platform smoke entrypoint contract
Godot Engine v4.7.1.stable.official.a13da4feb - https://godotengine.org

Godot headless tests: discovered 1 file(s).
RUN res://tests/godot/test_packaged_platform_smoke.gd (2 test(s))
  PASS test_main_menu_ships_packaged_platform_smoke_entrypoint
  PASS test_packaged_platform_smoke_requires_explicit_user_argument
Godot headless tests: 1 file(s), 2 test(s), 0 failure(s), 0 error(s).
==> Mounting DMG and extracting Reval Rebel.app
==> Running packaged install/start/save/load/exit smoke
UNSUPPORTED (log once): POSSIBLE ISSUE: unit 0 GLD_TEXTURE_INDEX_2D is unloadable and bound to sampler type (Float) - using zero texture because texture unloadable
WARNING: 257 ObjectDB instances were leaked at exit (run with `--verbose` for details).
   at: cleanup (core/object/object.cpp:2536)
ERROR: 8 resources still in use at exit (run with --verbose for details).
   at: clear (core/io/resource.cpp:822)
Godot Engine v4.7.1.stable.official.a13da4feb - https://godotengine.org
OpenGL API 4.1 Metal - 90.5 - Compatibility - Using Device: Apple - Apple M5 Pro

P3-012_PACKAGED_PLATFORM_START
P3-012_PACKAGED_PLATFORM_PASS steps=install,start,save,load,exit
P3-012 supported-platform smoke passed: /Users/artjomkurapov/git/rebel-reval/build/Reval Rebel.app
Maintainer report: docs/reports/p3_012_supported_platforms.md
```

## External and downstream blockers

- R-628 presentation dependency: R-628 presentation packet is incomplete; missing=scripts/map/view3d/map_view_nunnatorn_interior.gd, scripts/audio/nunnatorn_audio_controller.gd, tests/godot/test_nunnatorn_presentation.gd, day_captures=0, night_captures=0, capture_errors=none.
- Packaged build: packaged smoke was executed; see command record above.
- No human visual approval is inferred from automated traversal, content, or save tests.

## Artifact paths

- Contract: `docs/reports/nunnatorn_interior_contract.md`
- Historical/art review: `docs/reports/nunnatorn_historical_art_review.md`
- Interior map: `content/maps/nunnatorn_interior.rrmap`
- Dedicated scene: `scenes/reval_monastery/nunnatorn_interior.tscn`
- Acceptance verifier: `tools/verify_nunnatorn_acceptance.py`
- Acceptance unittest: `tests/python/test_nunnatorn_acceptance.py`

## Closeout rule

R-251 and R-629 must remain open until every matrix row is PASS, R-628 presentation evidence exists and passes, and packaged smoke is green. This report does not approve an incomplete package.
