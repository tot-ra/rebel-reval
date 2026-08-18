# P0-101 Runtime and Performance Gate Ledger

**Task:** R-591 / P0-101 decomposition: verify runtime and performance gates
**Parent:** R-108 / P0-101
**Verification date:** 2026-08-19
**Verification HEAD:** `fe31cc099783fa97ad54ec07e68414af78477dc9` (`main`)
**Worktree:** shared checkout with unrelated concurrent WIP, including an uncommitted `content/maps/lower_town_slice.rrmap` change and pre-existing staged/unstaged files
**Engine:** Godot 4.7.1.stable.official.a13da4feb
**Host:** macOS Apple M5 Pro development machine; this is not the declared minimum target
**Decision:** **BLOCKED - the independent P0-101 runtime and performance gates do not all pass. Keep R-108 / P0-101 open.**

## Scope and decision rule

This is a verification-only ledger for the runtime, clean-checkout, streaming/occlusion, resident-budget, authored-performance, minimum-hardware, and shutdown-diagnostic gates named by R-591. No camera/runtime code, RRMap parser, resident-budget policy, performance cap, hardware label, map fixture, or asset was repaired or re-authorized by this task.

A development-host or headless result is not promoted to Intel UHD 620 acceptance. A checked test summary is not promoted to a clean runtime pass when the log contains parser, shader, resource, or script diagnostics. Known shutdown-only ObjectDB/resource leak messages are recorded separately and do not waive non-shutdown failures.

## Independent gate matrix

| Gate | Result | Fresh evidence and boundary | Owner / next action |
|---|---|---|---|
| Camera behavior | **BLOCKED** | `tools/run_godot_checked.sh --require-test-summary r591-camera -- /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_map_camera_modes` reached the suite. **11 tests: 5 pass, 6 failures, 2 engine errors.** The six known failures remain building pull-out, first-person eye height, pitch-preserved follow boom, restored maximum boom, zoom-entered eye height, and restored minimum boom. The first non-shutdown diagnostic is a shader tokenizer error from `scripts/map/view3d/map_view_water_materials.gd:42` caused by `# gdlint` text embedded in GLSL; it is separate from the six camera assertions. | **R-577** / camera-runtime owner: repair the camera contract and independently resolve or route the shader diagnostic before claiming a clean checked run. Do not weaken assertions. |
| Clean-checkout parse/load | **BLOCKED** | `tools/verify_clean_checkout_load.sh` passed detached checkout creation, restored **38** runtime LFS objects, and completed clean import. The load stage failed with **41 failures / 193 errors**. First product diagnostics are `unknown_command 'elevation_area'` at `content/maps/lower_town_slice.rrmap:14,20,22` and `unknown_command 'elevation_ramp'` at line 17, followed by an invalid map definition and dependent MapView3D failures. | **R-453 / R-455**: register and validate the authored elevation commands, then rerun the gate. The clean import pass does not waive the load failure. |
| Collision, navigation, occlusion, and chunking | **BLOCKED for current checkout; clean baseline evidence remains PASS** | The live checked batch reached **9 files / 72 tests / 2 failures / 0 errors** at the harness summary level. The two failures are canonical Lower Town parity drift and reviewed object-chunk boundary inventory drift, both caused by current dirty map/content changes. The same batch passed the relevant authored route, collision, navigation, terrain-chunk, streaming, and performance assertions otherwise. Prior clean-head evidence in R-490 recorded route/collision/navigation/parity **39/39** and chunk/terrain/ownership **21/21** after reviewed fixture work. Because the current checkout has unreviewed map drift, this ledger does not promote the historical clean result to a current PASS. | Map/content change owner and **R-490**: review the live parity and chunk fixture diffs in a clean intended snapshot, regenerate only with approval, and rerun the focused suites. No fixture was changed here. |
| Resident nodes and memory | **BLOCKED** | Fresh `GODOT_BIN="$GODOT_BIN" tools/run_performance_report.sh build/benchmarks/r591-lower-town.json --quick` generated a report, but `lower_town_scene` measured **12,370 nodes / 478.987 MiB** against authored caps **7,500 / 280 MiB**. This is a production-scene overage. The same profile measured frame-time p95 **9.359 ms**, collision count **180**, bird audio peak **1**, and bird flight peak **1**. | **R-578 / P3-011**: reduce production resident cost or obtain an explicit evidence-backed budget decision. Never raise the 7,500-node or 280-MiB caps silently. |
| Authored performance caps | **BLOCKED** | `python3 tools/report_slice_performance.py --check` passes for the manifest/model contract. `python3 tools/report_slice_performance.py --check --report build/benchmarks/r591-lower-town.json` fails only because the production profile exceeds `memory_delta_mib` and `node_count`; frame-time, collisions, and ambient bird peaks remain within their authored limits. Therefore the aggregate production cap gate is not green even though those independent submetrics pass. | **R-578 / P3-011**: resolve the resident-cost failures, then rerun the report validator without changing caps. |
| Non-headless declared minimum-hardware measurement | **BLOCKED** | The declared profile is `minimum-hardware-intel-uhd-620`, Intel Core i5-8250U / Intel UHD Graphics 620 / 8 GiB / 1920x1080. No Intel UHD 620 machine was available. Existing R-563 non-headless evidence is an Apple M5 Pro supplementary probe, not an emulation or substitute; its renderer metrics cannot certify the declared target. The current quick benchmark is headless/development-host evidence only. | **R-563 / P3-011**: obtain a real non-headless run on the declared target, or record a named maintainer decision that explicitly accepts the blocker without changing caps. |
| Shutdown-only diagnostics | **BLOCKED** | Checked runs emit known shutdown ObjectDB/resource/RID leak diagnostics, but they also emit non-shutdown shader compilation errors in the live camera/performance runs and parser/resource/script errors in the clean MapView3D load run. The shutdown-only family is therefore not the only diagnostic class observed. The known shutdown messages are not used as the first failure and are not used to waive the other errors. | Runtime owners above: remove or independently classify the non-shutdown diagnostics before this row can become PASS. |

## Supporting validators and non-gate findings

- `python3 -m unittest tests.python.test_verify_clean_checkout_load -v`: **7 tests, 6 passed, 1 expected skip** because the isolated parse-error probe could not find a Godot binary. The gate contract, detached checkout, cleanup, checked-runner, and report assertions passed.
- `python3 tools/report_slice_performance.py --check`: **PASS** for manifest and slice-model consistency.
- `python3 tools/verify_asset_lint.py`: **BLOCKED by pre-existing baseline findings**, including portrait dimensions that are not multiples of 96 px and missing provenance rows for existing character GLBs. This task did not touch assets or `assets/SOURCES.csv`; the result is recorded for traceability and is not reclassified as an R-591 implementation defect.
- The benchmark report JSON under `build/benchmarks/` is host-specific generated output and is not part of this bounded documentation change.

## Reproduction commands

```bash
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
export GODOT_LOG_DIR=/tmp/r591-clean

# Clean checkout and MapView3D load gate. Expected BLOCKED at the RRMap parser stage.
GODOT_BIN="$GODOT_BIN" tools/verify_clean_checkout_load.sh

# Runtime route, collision, navigation, chunk and authored performance contracts.
# In the shared checkout this currently exposes the two active parity/ownership drifts.
tools/run_godot_checked.sh --require-test-summary r591-runtime-gates -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_lower_town_slice_map,test_kalev_smithy_map,test_burgher_house_tiers,\
 test_map_object_chunk_streaming,test_map_terrain_chunks,test_large_map_chunk_prototype,\
 test_vertical_slice_performance,test_performance_benchmark,test_urban_population_performance_cap

# Camera behavior. Expected BLOCKED with six known assertions plus the separate shader diagnostic.
tools/run_godot_checked.sh --require-test-summary r591-camera -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_map_camera_modes

# Host-specific production benchmark. Expected resident node/memory overage.
GODOT_BIN="$GODOT_BIN" tools/run_performance_report.sh \
  build/benchmarks/r591-lower-town.json --quick
python3 tools/report_slice_performance.py --check
python3 tools/report_slice_performance.py --check \
  --report build/benchmarks/r591-lower-town.json
```

## Closeout

R-591's verification deliverable is complete as a deterministic **BLOCKED** ledger. The independent rows are not waived, authored limits remain unchanged, and no new follow-up task is created because every actionable blocker has an existing board owner: R-577, R-578/P3-011, R-453/R-455, R-563, and the R-490 map/runtime verification boundary. R-108 / P0-101 must remain open until the blocked rows are rerun green on the correct snapshot and declared hardware.

## Sources

- [`docs/reports/lower_town_p0_101_runtime_qa.md`](lower_town_p0_101_runtime_qa.md)
- [`docs/reports/r535_lower_town_runtime_performance_verification.md`](r535_lower_town_runtime_performance_verification.md)
- [`docs/reports/p0_101_clean_checkout_load_gate.md`](p0_101_clean_checkout_load_gate.md)
- [`docs/reports/p0_101_gpu_budget_evidence.md`](p0_101_gpu_budget_evidence.md)
- [`tools/verify_clean_checkout_load.sh`](../../tools/verify_clean_checkout_load.sh)
- [`tools/run_performance_report.sh`](../../tools/run_performance_report.sh)
- [`tools/report_slice_performance.py`](../../tools/report_slice_performance.py)
- [`tools/benchmarks/minimum-hardware.json`](../../tools/benchmarks/minimum-hardware.json)
- [`tools/benchmarks/large_map_benchmark_config.json`](../../tools/benchmarks/large_map_benchmark_config.json)
- [`tests/python/test_verify_clean_checkout_load.py`](../../tests/python/test_verify_clean_checkout_load.py)
