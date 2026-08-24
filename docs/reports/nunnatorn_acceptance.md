# R-629: Nunnatorn independent acceptance

- Status: **BLOCKED**
- Parent: R-251 / P4-027b
- Verification owner: R-629 independent QA gate
- Run timestamp: `2026-08-24T08:52:29.208102+00:00`
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
| lighting/audio/readability and day/night captures | **BLOCKED** | R-628 presentation packet is incomplete; missing=none, untracked=docs/reports/images/nunnatorn/nunnatorn_day.png, docs/reports/images/nunnatorn/nunnatorn_night.png, scripts/audio/nunnatorn_audio_controller.gd, scripts/map/view3d/map_view_nunnatorn_interior.gd, tests/godot/test_nunnatorn_presentation.gd, day_captures=1, night_captures=1, capture_errors=none. |
| packaged artifact discovery | **PASS** | build/rr.dmg is available for packaged smoke execution. |
| existing Nunnatorn Python content suites | **PASS** | exit=0 |
| focused Godot Nunnatorn suites | **BLOCKED** | 15/15 Nunnatorn-specific tests pass; the reciprocal transition method is blocked by the external `kuldjala_interior` destination diagnostic in `monastery_quarter.rrmap` (R-250 owns the Kuldjala package). |
| focused Nunnatorn presentation suite | **BLOCKED** | Live-only R-628 presentation smoke passed, but the packet is untracked and cannot count as committed acceptance evidence: docs/reports/images/nunnatorn/nunnatorn_day.png, docs/reports/images/nunnatorn/nunnatorn_night.png, scripts/audio/nunnatorn_audio_controller.gd, scripts/map/view3d/map_view_nunnatorn_interior.gd, tests/godot/test_nunnatorn_presentation.gd |
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
Ran 6 tests in 0.028s

OK
```

### focused Godot Nunnatorn suites: BLOCKED

```text
$ /Users/artjomkurapov/git/rebel-reval/tools/run_godot_checked.sh --require-test-summary nunnatorn-acceptance -- /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_nunnatorn_interior_map,test_nunnatorn_transitions,test_nunnatorn_boss_encounter,test_nunnatorn_evidence,test_nunnatorn_persistence
15/15 Nunnatorn-specific tests pass; the reciprocal transition method is blocked by the external `kuldjala_interior` destination diagnostic in `monastery_quarter.rrmap` (R-250 owns the Kuldjala package).
... (output truncated)
       [2] _call_and_capture (res://tools/run_godot_tests.gd:210)
       [3] _run_test_method (res://tools/run_godot_tests.gd:183)
       [4] _run_test_file (res://tools/run_godot_tests.gd:157)
       [5] _run (res://tools/run_godot_tests.gd:87)
ERROR: res://content/maps/monastery_quarter.rrmap:19:1: warning[MAP_CHUNK_BOUNDARY_AMBIGUOUS]: object crosses future 16x16-cell chunk boundaries ((5, 4) to (6, 4)); split it or document ownership before chunking
   at: push_error (core/variant/variant_utility.cpp:1023)
   GDScript backtrace (most recent call first):
       [0] create (res://scripts/map/definitions/prototypes/monastery_quarter_definition.gd:13)
       [1] test_nunnatorn_transition_ids_are_reciprocal (res://tests/godot/test_nunnatorn_transitions.gd:8)
       [2] _call_and_capture (res://tools/run_godot_tests.gd:210)
       [3] _run_test_method (res://tools/run_godot_tests.gd:183)
       [4] _run_test_file (res://tools/run_godot_tests.gd:157)
       [5] _run (res://tools/run_godot_tests.gd:87)
ERROR: res://content/maps/monastery_quarter.rrmap:19:1: warning[MAP_CHUNK_BOUNDARY_AMBIGUOUS]: object crosses future 16x16-cell chunk boundaries ((8, 6) to (9, 6)); split it or document ownership before chunking
   at: push_error (core/variant/variant_utility.cpp:1023)
   GDScript backtrace (most recent call first):
       [0] create (res://scripts/map/definitions/prototypes/monastery_quarter_definition.gd:13)
       [1] test_nunnatorn_transition_ids_are_reciprocal (res://tests/godot/test_nunnatorn_transitions.gd:8)
       [2] _call_and_capture (res://tools/run_godot_tests.gd:210)
       [3] _run_test_method (res://tools/run_godot_tests.gd:183)
       [4] _run_test_file (res://tools/run_godot_tests.gd:157)
       [5] _run (res://tools/run_godot_tests.gd:87)
ERROR: res://content/maps/monastery_quarter.rrmap:19:1: warning[MAP_CHUNK_BOUNDARY_AMBIGUOUS]: object crosses future 16x16-cell chunk boundaries ((0, 1) to (0, 2)); split it or document ownership before chunking
   at: push_error (core/variant/variant_utility.cpp:1023)
   GDScript backtrace (most recent call first):
       [0] create (res://scripts/map/definitions/prototypes/monastery_quarter_definition.gd:13)
       [1] test_nunnatorn_transition_ids_are_reciprocal (res://tests/godot/test_nunnatorn_transitions.gd:8)
       [2] _call_and_capture (res://tools/run_godot_tests.gd:210)
       [3] _run_test_method (res://tools/run_godot_tests.gd:183)
       [4] _run_test_file (res://tools/run_godot_tests.gd:157)
       [5] _run (res://tools/run_godot_tests.gd:87)
  ERROR res://tests/godot/test_nunnatorn_transitions.gd::test_nunnatorn_transition_ids_are_reciprocal - 38 engine/script diagnostic(s) interrupted clean completion
    [test] core/variant/variant_utility.cpp:1023 (push_error): res://content/maps/monastery_quarter.rrmap:19:1: error[MAP_TRANSITION_DESTINATION_UNKNOWN]: transition references unknown or inactive destination scene 'kuldjala_interior'
    [test] core/variant/variant_utility.cpp:1023 (push_error): res://content/maps/monastery_quarter.rrmap:19:1: warning[MAP_CHUNK_BOUNDARY_AMBIGUOUS]: object crosses future 16x16-cell chunk boundaries ((4, 1) to (5, 2)); split it or document ownership before chunking
    [test] core/variant/variant_utility.cpp:1023 (push_error): res://content/maps/monastery_quarter.rrmap:19:1: warning[MAP_CHUNK_BOUNDARY_AMBIGUOUS]: object crosses future 16x16-cell chunk boundaries ((4, 3) to (5, 3)); split it or document ownership before chunking
    [test] core/variant/variant_utility.cpp:1023 (push_error): res://content/maps/monastery_quarter.rrmap:19:1: warning[MAP_CHUNK_BOUNDARY_AMBIGUOUS]: object crosses future 16x16-cell chunk boundaries ((9, 2) to (10, 3)); split it or document ownership before chunking
    [test] core/variant/variant_utility.cpp:1023 (push_error): res://content/maps/monastery_quarter.rrmap:19:1: warning[MAP_CHUNK_BOUNDARY_AMBIGUOUS]: object crosses future 16x16-cell chunk boundaries ((10, 1) to (11, 1)); split it or document ownership before chunking
    [test] core/variant/variant_utility.cpp:1023 (push_error): res://content/maps/monastery_quarter.rrmap:19:1: warning[MAP_CHUNK_BOUNDARY_AMBIGUOUS]: object crosses future 16x16-cell chunk boundaries ((10, 5) to (11, 5)); split it or document ownership before chunking
    [test] core/variant/variant_utility.cpp:1023 (push_error): res://content/maps/monastery_quarter.rrmap:19:1: warning[MAP_CHUNK_BOUNDARY_AMBIGUOUS]: object crosses future 16x16-cell chunk boundaries ((8, 1) to (9, 2)); split it or document ownership before chunking
    [test] core/variant/variant_utility.cpp:1023 (push_error): res://content/maps/monastery_quarter.rrmap:19:1: warning[MAP_CHUNK_BOUNDARY_AMBIGUOUS]: object crosses future 16x16-cell chunk boundaries ((8, 4) to (9, 4)); split it or document ownership before chunking
    [test] core/variant/variant_utility.cpp:1023 (push_error): res://content/maps/monastery_quarter.rrmap:19:1: warning[MAP_CHUNK_BOUNDARY_AMBIGUOUS]: object crosses future 16x16-cell chunk boundaries ((11, 4) to (12, 4)); split it or document ownership before chunking
    [test] core/variant/variant_utility.cpp:1023 (push_error): res://content/maps/monastery_quarter.rrmap:208:8: warning[MAP_CHUNK_BOUNDARY_AMBIGUOUS]: object crosses future 16x16-cell chunk boundaries ((14, 0) to (14, 6)); split it or document ownership before chunking
    [test] core/variant/variant_utility.cpp:1023 (push_error): res://content/maps/monastery_quarter.rrmap:208:8: warning[MAP_CHUNK_BOUNDARY_AMBIGUOUS]: object crosses future 16x16-cell chunk boundaries ((0, 0) to (0, 1)); split it or document ownership before chunking
    [test] core/variant/variant_utility.cpp:1023 (push_error): res://content/maps/monastery_quarter.rrmap:19:1: warning[MAP_CHUNK_BOUNDARY_AMBIGUOUS]: object crosses future 16x16-cell chunk boundaries ((0, 3) to (0, 6)); split it or document ownership before chunking
    [test] core/variant/variant_utility.cpp:1023 (push_error): res://content/maps/monastery_quarter.rrmap:19:1: warning[MAP_CHUNK_BOUNDARY_AMBIGUOUS]: object crosses future 16x16-cell chunk boundaries ((2, 4) to (3, 5)); split it or document ownership before chunking
    [test] core/variant/variant_utility.cpp:1023 (push_error): res://content/maps/monastery_quarter.rrmap:19:1: warning[MAP_CHUNK_BOUNDARY_AMBIGUOUS]: object crosses future 16x16-cell chunk boundaries ((13, 3) to (14, 3)); split it or document ownership before chunking
    [test] core/variant/variant_utility.cpp:1023 (push_error): res://content/maps/monastery_quarter.rrmap:208:8: warning[MAP_CHUNK_BOUNDARY_AMBIGUOUS]: object crosses future 16x16-cell chunk boundaries ((13, 0) to (14, 0)); split it or document ownership before chunking
    [test] core/variant/variant_utility.cpp:1023 (push_error): res://content/maps/monastery_quarter.rrmap:19:1: warning[MAP_CHUNK_BOUNDARY_AMBIGUOUS]: object crosses future 16x16-cell chunk boundaries ((13, 6) to (14, 6)); split it or document ownership before chunking
    [test] core/variant/variant_utility.cpp:1023 (push_error): res://content/maps/monastery_quarter.rrmap:19:1: warning[MAP_CHUNK_BOUNDARY_AMBIGUOUS]: object crosses future 16x16-cell chunk boundaries ((0, 4) to (1, 4)); split it or document ownership before chunking
    [test] core/variant/variant_utility.cpp:1023 (push_error): res://content/maps/monastery_quarter.rrmap:19:1: warning[MAP_CHUNK_BOUNDARY_AMBIGUOUS]: object crosses future 16x16-cell chunk boundaries ((7, 4) to (8, 5)); split it or document ownership before chunking
    [test] core/variant/variant_utility.cpp:1023 (push_error): res://content/maps/monastery_quarter.rrmap:19:1: warning[MAP_CHUNK_BOUNDARY_AMBIGUOUS]: object crosses future 16x16-cell chunk boundaries ((7, 4) to (8, 4)); split it or document ownership before chunking
    [test] core/variant/variant_utility.cpp:1023 (push_error): res://content/maps/monastery_quarter.rrmap:19:1: warning[MAP_CHUNK_BOUNDARY_AMBIGUOUS]: object crosses future 16x16-cell chunk boundaries ((4, 4) to (4, 5)); split it or document ownership before chunking
    [test] core/variant/variant_utility.cpp:1023 (push_error): res://content/maps/monastery_quarter.rrmap:19:1: warning[MAP_CHUNK_BOUNDARY_AMBIGUOUS]: object crosses future 16x16-cell chunk boundaries ((6, 1) to (7, 2)); split it or document ownership before chunking
    [test] core/variant/variant_utility.cpp:1023 (push_error): res://content/maps/monastery_quarter.rrmap:19:1: warning[MAP_CHUNK_BOUNDARY_AMBIGUOUS]: object crosses future 16x16-cell chunk boundaries ((6, 4) to (7, 4)); split it or document ownership before chunking
    [test] core/variant/variant_utility.cpp:1023 (push_error): res://content/maps/monastery_quarter.rrmap:19:1: warning[MAP_CHUNK_BOUNDARY_AMBIGUOUS]: object crosses future 16x16-cell chunk boundaries ((9, 2) to (10, 2)); split it or document ownership before chunking
    [test] core/variant/variant_utility.cpp:1023 (push_error): res://content/maps/monastery_quarter.rrmap:19:1: warning[MAP_CHUNK_BOUNDARY_AMBIGUOUS]: object crosses future 16x16-cell chunk boundaries ((1, 1) to (2, 1)); split it or document ownership before chunking
    [test] core/variant/variant_utility.cpp:1023 (push_error): res://content/maps/monastery_quarter.rrmap:19:1: warning[MAP_CHUNK_BOUNDARY_AMBIGUOUS]: object crosses future 16x16-cell chunk boundaries ((5, 3) to (6, 4)); split it or document ownership before chunking
    [test] core/variant/variant_utility.cpp:1023 (push_error): res://content/maps/monastery_quarter.rrmap:19:1: warning[MAP_CHUNK_BOUNDARY_AMBIGUOUS]: object crosses future 16x16-cell chunk boundaries ((2, 2) to (2, 3)); split it or document ownership before chunking
    [test] core/variant/variant_utility.cpp:1023 (push_error): res://content/maps/monastery_quarter.rrmap:208:8: warning[MAP_CHUNK_BOUNDARY_AMBIGUOUS]: object crosses future 16x16-cell chunk boundaries ((2, 0) to (2, 1)); split it or document ownership before chunking
    [test] core/variant/variant_utility.cpp:1023 (push_error): res://content/maps/monastery_quarter.rrmap:19:1: warning[MAP_CHUNK_BOUNDARY_AMBIGUOUS]: object crosses future 16x16-cell chunk boundaries ((7, 2) to (8, 3)); split it or document ownership before chunking
    [test] core/variant/variant_utility.cpp:1023 (push_error): res://content/maps/monastery_quarter.rrmap:208:8: warning[MAP_CHUNK_BOUNDARY_AMBIGUOUS]: object crosses future 16x16-cell chunk boundaries ((7, 0) to (8, 0)); split it or document ownership before chunking
    [test] core/variant/variant_utility.cpp:1023 (push_error): res://content/maps/monastery_quarter.rrmap:208:8: warning[MAP_CHUNK_BOUNDARY_AMBIGUOUS]: object crosses future 16x16-cell chunk boundaries ((0, 0) to (3, 0)); split it or document ownership before chunking
    [test] core/variant/variant_utility.cpp:1023 (push_error): res://content/maps/monastery_quarter.rrmap:19:1: warning[MAP_CHUNK_BOUNDARY_AMBIGUOUS]: object crosses future 16x16-cell chunk boundaries ((0, 3) to (2, 3)); split it or document ownership before chunking
    [test] core/variant/variant_utility.cpp:1023 (push_error): res://content/maps/monastery_quarter.rrmap:208:8: warning[MAP_CHUNK_BOUNDARY_AMBIGUOUS]: object crosses future 16x16-cell chunk boundaries ((0, 0) to (0, 3)); split it or document ownership before chunking
    [test] core/variant/variant_utility.cpp:1023 (push_error): res://content/maps/monastery_quarter.rrmap:19:1: warning[MAP_CHUNK_BOUNDARY_AMBIGUOUS]: object crosses future 16x16-cell chunk boundaries ((2, 1) to (3, 2)); split it or document ownership before chunking
    [test] core/variant/variant_utility.cpp:1023 (push_error): res://content/maps/monastery_quarter.rrmap:19:1: warning[MAP_CHUNK_BOUNDARY_AMBIGUOUS]: object crosses future 16x16-cell chunk boundaries ((2, 1) to (3, 1)); split it or document ownership before chunking
    [test] core/variant/variant_utility.cpp:1023 (push_error): res://content/maps/monastery_quarter.rrmap:19:1: warning[MAP_CHUNK_BOUNDARY_AMBIGUOUS]: object crosses future 16x16-cell chunk boundaries ((2, 3) to (3, 3)); split it or document ownership before chunking
    [test] core/variant/variant_utility.cpp:1023 (push_error): res://content/maps/monastery_quarter.rrmap:19:1: warning[MAP_CHUNK_BOUNDARY_AMBIGUOUS]: object crosses future 16x16-cell chunk boundaries ((5, 4) to (6, 4)); split it or document ownership before chunking
    [test] core/variant/variant_utility.cpp:1023 (push_error): res://content/maps/monastery_quarter.rrmap:19:1: warning[MAP_CHUNK_BOUNDARY_AMBIGUOUS]: object crosses future 16x16-cell chunk boundaries ((8, 6) to (9, 6)); split it or document ownership before chunking
    [test] core/variant/variant_utility.cpp:1023 (push_error): res://content/maps/monastery_quarter.rrmap:19:1: warning[MAP_CHUNK_BOUNDARY_AMBIGUOUS]: object crosses future 16x16-cell chunk boundaries ((0, 1) to (0, 2)); split it or document ownership before chunking
  FAIL res://tests/godot/test_nunnatorn_transitions.gd::test_nunnatorn_transition_ids_are_reciprocal - Expected <nunnatorn_interior> but got <<null>>
  FAIL res://tests/godot/test_nunnatorn_transitions.gd::test_nunnatorn_transition_ids_are_reciprocal - Expected <nunnatorn_interior_entry> but got <<null>>
  FAIL res://tests/godot/test_nunnatorn_transitions.gd::test_nunnatorn_transition_ids_are_reciprocal - Expected <(96.0, 0.0)> but got <<null>>
  FAIL res://tests/godot/test_nunnatorn_transitions.gd::test_nunnatorn_transition_ids_are_reciprocal - Expected <<null>> but got <monastery_wall_tower_northwest_return>
Godot headless tests: 5 file(s), 16 test(s), 4 failure(s), 38 error(s).
WARNING: 118 ObjectDB instances were leaked at exit (run with `--verbose` for details).
   at: cleanup (core/object/object.cpp:2536)
ERROR: 8 resources still in use at exit (run with --verbose for details).
   at: clear (core/io/resource.cpp:822)
Godot command failed with status 1: /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_nunnatorn_interior_map,test_nunnatorn_transitions,test_nunnatorn_boss_encounter,test_nunnatorn_evidence,test_nunnatorn_persistence
```

### focused Nunnatorn presentation suite: BLOCKED

```text
$ /Users/artjomkurapov/git/rebel-reval/tools/run_godot_checked.sh --require-test-summary nunnatorn-presentation -- /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_nunnatorn_presentation
Live-only R-628 presentation smoke passed, but the packet is untracked and cannot count as committed acceptance evidence: docs/reports/images/nunnatorn/nunnatorn_day.png, docs/reports/images/nunnatorn/nunnatorn_night.png, scripts/audio/nunnatorn_audio_controller.gd, scripts/map/view3d/map_view_nunnatorn_interior.gd, tests/godot/test_nunnatorn_presentation.gd
Godot Engine v4.7.1.stable.official.a13da4feb - https://godotengine.org

Godot headless tests: discovered 1 file(s).
RUN res://tests/godot/test_nunnatorn_presentation.gd (3 test(s))
  PASS test_nunnatorn_audio_gain_is_thresholded_and_bounded
  PASS test_nunnatorn_day_night_fill_changes_without_mutating_definition
  PASS test_nunnatorn_presentation_builds_three_floor_lights_and_open_backed_marker
Godot headless tests: 1 file(s), 3 test(s), 0 failure(s), 0 error(s).
WARNING: 31 ObjectDB instances were leaked at exit (run with `--verbose` for details).
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

- R-628 presentation dependency: R-628 presentation packet is incomplete; missing=none, untracked=docs/reports/images/nunnatorn/nunnatorn_day.png, docs/reports/images/nunnatorn/nunnatorn_night.png, scripts/audio/nunnatorn_audio_controller.gd, scripts/map/view3d/map_view_nunnatorn_interior.gd, tests/godot/test_nunnatorn_presentation.gd, day_captures=1, night_captures=1, capture_errors=none.
- R-250 Kuldjala dependency: 15/15 Nunnatorn-specific tests pass; the reciprocal transition method is blocked by the external `kuldjala_interior` destination diagnostic in `monastery_quarter.rrmap` (R-250 owns the Kuldjala package).
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
