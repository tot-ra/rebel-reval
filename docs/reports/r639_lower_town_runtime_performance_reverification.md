# R-639 Lower Town Runtime and Performance Reverification

**Task:** R-639 / P0-101 runtime and performance recheck
**Parent:** R-108 / P0-101
**Verification date:** 2026-08-21
**Verification HEAD:** `8f1a3adbca8b64ccf1cb08970b239561df7b166c` (`main`)
**Worktree:** shared checkout with unrelated staged, modified, and untracked WIP. The clean-checkout gate was run from a detached checkout of this HEAD.
**Engine:** Godot 4.7.1.stable.official.a13da4feb
**Host:** macOS Apple M5 Pro development machine; not the declared minimum target
**Decision:** **BLOCKED - the independent P0-101 runtime and performance gates do not all pass. Keep R-108 / P0-101 open.**

## Scope and evidence boundary

This is a verification-only recheck. No runtime, camera, RRMap parser, map fixture, budget limit, hardware declaration, asset, or provenance row was changed. A green deterministic contract test is reported separately from a clean product load, resident-budget acceptance, and minimum-hardware evidence. No development-host or headless result is promoted to Intel UHD 620 acceptance.

The clean-checkout gate is authoritative for release-load attribution. It creates a detached checkout at the current HEAD, restores runtime LFS inputs, imports it, and then runs the bounded Lower Town/MapView3D load filter. Because the current clean import stopped on missing shader preloads, the older `elevation_area` / `elevation_ramp` parser result was not reached in this run. That earlier result remains historical evidence in the linked R-562/R-535 reports and must be rerun after the first clean-import blocker is resolved.

## Independent gate matrix

| Gate | Result | Fresh evidence and boundary | Owner / next action |
|---|---|---|---|
| Clean detached checkout and runtime import | **BLOCKED** | `tools/verify_clean_checkout_load.sh` exited 1 during `import clean checkout` after the detached checkout and Godot import began. HEAD's tracked `assets/characters/shared/shared_character_rig.gd` preloads `res://scripts/characters/eye_material.gdshader` and `res://scripts/characters/hair_material.gdshader`, but both files are untracked in the shared worktree and absent from clean HEAD. The checked log reports both missing preloads and the resulting shared-rig parse error. | **R-122 / R-124**: land the eye/hair shader assets through their owned task paths, then rerun the clean gate. Do not treat the live untracked files as clean-checkout evidence. |
| RRMap parser and MapView3D load | **UNAVAILABLE AFTER FIRST BLOCKER** | The clean gate did not reach its load stage. The previous R-562/R-535 runs recorded `unknown_command` for `elevation_area` and `elevation_ramp`; those diagnostics are not claimed as a new R-639 observation and remain a required next-stage rerun. | **R-453 / R-455 / R-604**: rerun the clean load after the shader import blocker is resolved and repair/accept the first substantive parser blocker. |
| Lower Town route, collision, navigation, and parity | **BLOCKED by parity drift; subchecks otherwise PASS** | The live checked batch covered 9 files and 72 tests with 0 errors and 1 failure. The only failure was `test_lower_town_slice_matches_canonical_parity_fixture`: expected `walkability_sha256=57e9b9d32a01099e4c399e51b1552e5edbf6eba58d07eff5b6975d081bbbbf8f`, actual `0c33d876cd74bdd69c35cb4e91e4b1503112cb1adf690c2072219c72f85a4944`. Route, collision, navigation, tier, and other Lower Town map assertions passed in the same run. | **R-547 / map-content owner**: review the authored map delta and regenerate the canonical fixture only after review. No fixture was changed here. |
| Terrain and object streaming/occlusion contracts | **PASS as focused contracts** | `test_map_object_chunk_streaming` passed 7/7 and `test_map_terrain_chunks` passed 6/6 in the same checked batch. This proves the focused ownership/residency and terrain reload contracts, not full product-load acceptance. | Keep as regression evidence; rerun after the parity and clean-load blockers are resolved. |
| Camera placement and follow-boom behavior | **BLOCKED** | `test_map_camera_modes` ran 11 tests with 6 assertion failures: building pull-out, first-person eye height, pitch-preserved follow boom, restored maximum boom, zoom-entered first-person eye height, and restored minimum boom. The checked run had no test-summary errors; shutdown-only resource/RID leak lines were retained as allowed diagnostics. | **R-577**: repair the existing camera contract without weakening assertions, then rerun the camera and route suites. |
| Production resident nodes and memory | **BLOCKED** | Fresh `build/benchmarks/r639-lower-town.json` reports `lower_town_scene` at **22,346 nodes** against **7,500** and **552.163 MiB** against **280 MiB**. These are headless CPU/resident measurements on the Apple M5 Pro development host. | **R-578 / P3-011**: reduce production resident cost or obtain an explicit evidence-backed budget decision. Do not raise caps silently. |
| CPU-side frame, collision, and fauna metrics | **PASS as development-host regression evidence** | The same production profile reports frame-time p95 **14.705 ms / 16.67 ms**, collisions **177 / 900**, bird audio peak **1 / 3**, bird-flight peak **1 / 4**, urban fauna peak **8 / 8**, and penned fauna peak **5 / 10**. These passes do not waive the node/memory failures or certify the declared hardware target. | Preserve as supporting evidence; rerun after R-578 changes. |
| Authored performance model | **PASS** | `python3 tools/report_slice_performance.py --check` passed the manifest and authored slice-gate contract. | No action. The aggregate report remains blocked by the production profile overages below. |
| Aggregate production performance gate | **BLOCKED** | `python3 tools/report_slice_performance.py --check --report build/benchmarks/r639-lower-town.json` failed only on `lower_town_scene.memory_delta_mib` and `lower_town_scene.node_count`; the independent frame/collision/fauna values above remain within their authored limits. | **R-578 / P3-011**: resolve resident-cost failures, then rerun the report validator without changing limits. |
| Declared minimum-hardware GPU evidence | **BLOCKED / UNAVAILABLE** | The declared profile is `minimum-hardware-intel-uhd-620` (Intel Core i5-8250U, Intel UHD Graphics 620, 8 GiB, 1920x1080). No such target was available. R-639 produced only the headless Apple M5 Pro development-baseline report; its zero video/texture-memory fields are not GPU evidence. Existing R-563 M5 non-headless measurements remain supplementary, not a substitute. | **R-563 / P3-011**: obtain a real non-headless run on the declared target or record a named maintainer decision that explicitly accepts the blocker without changing caps. |
| Asset lint and provenance validators | **BASELINE BLOCKED, OUT OF SCOPE** | `python3 tools/verify_asset_lint.py` reports the six existing character portraits (`aita`, `kaja`, `jurgen`, `kalev`, `mart`, `henning`) with sides not divisible by 96 px. `python3 tools/validate_asset_sources.py` reports pre-existing invalid house-material IDs and many active runtime paths missing from `assets/SOURCES.csv`, including the six portraits. R-639 did not modify assets or the manifest. | Existing art/provenance owners, including **R-642**, must resolve these findings. They are not reclassified as R-639 implementation failures. |
| Shutdown diagnostics | **NOT THE FIRST BLOCKER** | Live Godot runs emitted known shutdown-only ObjectDB/resource/RID leak lines. The runtime batch also had a real parity assertion failure, the camera batch had six assertion failures, the performance report failed its resident caps, and the clean import had missing-resource parse errors. Shutdown allowlisting does not waive those substantive failures. | Runtime owners above must resolve the substantive blockers before acceptance. |

## Verification commands

All checked Godot commands used the explicit installed binary and `tools/run_godot_checked.sh`; generated logs are retained under `/tmp/r639-live` and `/tmp/r639-clean` only.

```bash
export GODOT_BIN=/Users/artjomkurapov/.local/share/mise/installs/godot/4.7.1-stable/Godot.app/Contents/MacOS/Godot

# Clean detached checkout, LFS restore, import, and bounded MapView3D load.
GODOT_BIN="$GODOT_BIN" tools/verify_clean_checkout_load.sh
# BLOCKED during import: missing eye_material.gdshader and hair_material.gdshader

# Route, collision, navigation, parity, chunk, terrain and authored performance contracts.
tools/run_godot_checked.sh --require-test-summary r639-runtime-gates -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_lower_town_slice_map,test_kalev_smithy_map,test_burgher_house_tiers,\
 test_map_object_chunk_streaming,test_map_terrain_chunks,test_large_map_chunk_prototype,\
 test_vertical_slice_performance,test_performance_benchmark,test_urban_population_performance_cap
# 9 files, 72 tests, 1 failure, 0 errors; canonical parity mismatch

# Camera behavior.
tools/run_godot_checked.sh --require-test-summary r639-camera -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_map_camera_modes
# 1 file, 11 tests, 6 failures, 0 test-summary errors

# Host-specific performance report and authored-cap checks.
GODOT_BIN="$GODOT_BIN" tools/run_performance_report.sh \
  build/benchmarks/r639-lower-town.json --quick
python3 tools/report_slice_performance.py --check
python3 tools/report_slice_performance.py --check \
  --report build/benchmarks/r639-lower-town.json
# report generation PASS; manifest check PASS; aggregate report BLOCKED by node/memory caps

# Clean-checkout guard contract tests and baseline asset checks.
python3 -m unittest tests.python.test_verify_clean_checkout_load -v
python3 tools/verify_asset_lint.py
python3 tools/validate_asset_sources.py
# 7 Python tests: 6 pass, 1 expected skip; asset/provenance validators remain baseline BLOCKED
```

## Closeout

R-639 delivers a current, reproducible **BLOCKED** runtime/performance ledger. The existing implementation owners cover every actionable blocker, so no duplicate follow-up task is created. R-108 / P0-101 must remain open until the clean import/load stage, camera behavior, resident budgets, parity snapshot, and declared minimum-hardware evidence are independently rerun on the correct snapshots and target hardware.

## Sources

- [`tools/verify_clean_checkout_load.sh`](../../tools/verify_clean_checkout_load.sh)
- [`tools/run_godot_checked.sh`](../../tools/run_godot_checked.sh)
- [`tools/run_godot_tests.gd`](../../tools/run_godot_tests.gd)
- [`tools/run_performance_report.sh`](../../tools/run_performance_report.sh)
- [`tools/report_slice_performance.py`](../../tools/report_slice_performance.py)
- [`tools/benchmarks/minimum-hardware.json`](../../tools/benchmarks/minimum-hardware.json)
- [`tools/benchmarks/large_map_benchmark_config.json`](../../tools/benchmarks/large_map_benchmark_config.json)
- [`docs/reports/lower_town_p0_101_runtime_qa.md`](lower_town_p0_101_runtime_qa.md)
- [`docs/reports/p0_101_runtime_performance_gate_ledger.md`](p0_101_runtime_performance_gate_ledger.md)
- [`docs/reports/p0_101_clean_checkout_load_gate.md`](p0_101_clean_checkout_load_gate.md)
- [`docs/reports/p0_101_gpu_budget_evidence.md`](p0_101_gpu_budget_evidence.md)
- [`docs/reports/r535_lower_town_runtime_performance_verification.md`](r535_lower_town_runtime_performance_verification.md)
- [`tests/python/test_verify_clean_checkout_load.py`](../../tests/python/test_verify_clean_checkout_load.py)
