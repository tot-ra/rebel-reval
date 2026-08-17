# P0-101 Decomposition Readiness Ledger

**Task:** R-564 / P0-101 decomposition-gap verification
**Parent:** R-108 / P0-101
**Recorded:** 2026-08-18
**Verification checkout:** `7a82aaaf` (`main`), shared worktree dirty with unrelated WIP
**Decision:** **BLOCKED - R-538 cannot consume this ledger as an overall PASS; keep R-108 open.**

## Scope and decision rule

This ledger reconciles the four decomposition gaps named by R-564: gameplay-scale capture capability, the capture packet audit, the clean-checkout parse/load gate, and GPU/minimum-hardware budget evidence. It records board status separately from artifact-level test results. A green contract or a development-host measurement does not close a decomposition task when its acceptance contract requires visual review, a clean checkout, or the declared minimum hardware.

No supplementary orthographic image, headless-only measurement, or silent budget change is promoted to P0-101 acceptance evidence. No art, map geometry, runtime code, camera behavior, CI, budget, or human-review decision was changed by this verification.

## Readiness matrix

| Gap / board ref | Board status at verification | Linked artifact and command output | Result for R-564 | Unresolved owner and exact next action |
|---|---|---|---|---|
| Gameplay-scale capture capability / R-560 | `in_progress` | [`tools/capture_lower_town_p0_101.gd`](../../tools/capture_lower_town_p0_101.gd), [`tests/godot/test_capture_lower_town_p0_101.gd`](../../tests/godot/test_capture_lower_town_p0_101.gd), and [`capture_manifest.json`](images/lower_town_p0_101/capture_manifest.json). Focused command: `export GODOT_BIN=/Users/artjomkurapov/.local/share/mise/installs/godot/4.7.1-stable/Godot.app/Contents/MacOS/Godot; "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_capture_lower_town_p0_101`. Output: 1 file, 4 tests, 0 failures, 0 errors. Manifest records 4 authored route presets x day/night, `lower_town_slice`, `gl_compatibility`, 1280x720, gameplay orthographic size 33.75, and matched framing keys. | **CAPABILITY PASS / TASK OPEN** - the runner and packet contract are reproducible, but the board row is not resolved and capability alone is not visual acceptance. | R-560: complete its handoff and keep the packet tied to the authored map revision. R-561/R-536 must perform the acceptance audit; do not close R-108 from this capability result. |
| Gameplay-scale capture packet audit / R-561 | `todo` | [`lower_town_p0_101_capture_matrix.md`](lower_town_p0_101_capture_matrix.md) says `CAPTURE PACKET COMPLETE - visual acceptance review remains open`. The eight PNGs are present and the focused contract confirms they decode, are 1280x720, and are non-blank. The matrix still marks the required three tiers, materials, roof covers, wear, special buildings, St. Catherine's, inner/foregate, walls, and route-scale exceptional-building proof as `pending` / `BLOCKED`. The four generated route midpoint pairs do not identify all required stable IDs or prove those visual observations. | **BLOCKED** - packet integrity and route reproducibility pass, but the R-561 deliverable is the per-row acceptance audit and that audit is not complete. | R-561: claim the task, compare every matrix row against the R-486 inventory, capture or explicitly block each required day/night gameplay-scale row, and record the exact owner. R-536/R-492 remain downstream visual-review owners. Existing `view3d` and ADR-0018 plates stay supplementary. |
| Clean-checkout parse/load gate / R-562 | `done` | [`p0_101_clean_checkout_load_gate.md`](p0_101_clean_checkout_load_gate.md), [`tools/verify_clean_checkout_load.sh`](../../tools/verify_clean_checkout_load.sh), and [`tests/python/test_verify_clean_checkout_load.py`](../../tests/python/test_verify_clean_checkout_load.py). Python command: `python3 -m unittest tests.python.test_verify_clean_checkout_load -v`; output: 7 tests, 6 passed, 1 expected skip because the parse-error probe could not find Godot in its isolated environment. The live command with the installed Godot 4.7.1 binary created a detached checkout, restored 37 LFS runtime objects, and imported successfully, then failed the load stage with 41 failures and 193 errors. First product diagnostics are `unknown_command 'elevation_area'` at RRMap lines 14, 20, and 22 and `unknown_command 'elevation_ramp'` at line 17, followed by an invalid map definition. | **GATE IMPLEMENTATION PASS / CLEAN LOAD BLOCKED** - the guard and CI contract work, but P0-101 cannot count clean MapView3D load as green. | R-453 / R-455: register and validate the authored elevation commands, then rerun `tools/verify_clean_checkout_load.sh`. R-562 must not be treated as a clean-load acceptance PASS until that rerun is green. |
| GPU and minimum-hardware evidence / R-563 | `todo` | [`lower_town_p0_101_runtime_qa.md`](lower_town_p0_101_runtime_qa.md) and [`r535_lower_town_runtime_performance_verification.md`](r535_lower_town_runtime_performance_verification.md) explicitly state that the declared minimum target was not measured. The non-headless probe was run for this ledger on the detected Apple M5 Pro host with `gl_compatibility` / Metal: `draw_calls_peak=2592`, `primitives_peak=2962984`, `frame_time_ms_median=48.883`, `frame_time_ms_p95=58.361`, `video_mem_mib=610.892`, with a census of 3781 mesh instances, 272 MultiMesh instances, 44 GPU particle systems, and 795 shadow-casting meshes. These values are renderer evidence only. Existing headless M5 scene evidence records 8489 resident nodes / 439.3 MiB, 172 collisions, bird audio 1, and bird flight 1, but headless data cannot establish target-GPU acceptance. Declared target: [`tools/benchmarks/minimum-hardware.json`](../../tools/benchmarks/minimum-hardware.json), profile `minimum-hardware-intel-uhd-620`. No `p0_101_gpu_budget_evidence.md` exists. | **BLOCKED** - the M5 probe is reproducible supplementary evidence, not a measurement of Intel UHD 620; resident node/memory overages also remain unresolved and authored caps were not changed. | R-563 / P3-011 performance owner: run the probe and scene budget measurement on the declared minimum hardware, record target, renderer, resolution, all required metrics, and PASS/BLOCKED per cap. Reduce 8489 nodes / 439.3 MiB to the existing 7500 / 280 MiB caps or obtain an explicit evidence-backed budget decision; never raise limits silently. |

## Acceptance boundary

The following evidence is deliberately **not** counted as closing R-564 or R-108:

- `docs/reports/images/view3d/lower_town_slice_{day,night}.png`: fixed whole-map orthographic renderer smoke.
- `docs/reports/images/adr0018_calibration/lower_town_slice_third_person_{day,night}.png`: calibration context without the R-491 stable-ID matrix.
- Headless frame-time, node, memory, collision, or fauna values: valid CPU-side regression evidence, not target-GPU evidence.
- The M5 non-headless render probe: real renderer evidence on a development host, not minimum-hardware acceptance.
- Source counts, tier metadata, or passing map contracts: structural evidence, not proof of material, wear, silhouette, or route-scale readability.

## Reproduction record

### Capture contract

```bash
export GODOT_BIN=/Users/artjomkurapov/.local/share/mise/installs/godot/4.7.1-stable/Godot.app/Contents/MacOS/Godot
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_capture_lower_town_p0_101
# Godot headless tests: 1 file(s), 4 test(s), 0 failure(s), 0 error(s).
```

The first attempted invocation expanded `$GODOT_BIN` before assignment and exited 127; it was an invocation error, not a project result. The corrected exported invocation above is the authoritative result.

### Clean checkout load

```bash
export GODOT_BIN=/Users/artjomkurapov/.local/share/mise/installs/godot/4.7.1-stable/Godot.app/Contents/MacOS/Godot
GODOT_BIN="$GODOT_BIN" tools/verify_clean_checkout_load.sh
# exit 1 at "load Lower Town and MapView3D dependencies"
# first product blocker: elevation_area / elevation_ramp unknown_command diagnostics
```

The detached checkout and LFS restore/import stages pass. The failure is retained as the upstream parser blocker rather than repaired in this verification task.

### Renderer probe

```bash
export GODOT_BIN=/Users/artjomkurapov/.local/share/mise/installs/godot/4.7.1-stable/Godot.app/Contents/MacOS/Godot
"$GODOT_BIN" --path . --rendering-method gl_compatibility \
  --rendering-driver opengl3 res://tools/benchmarks/lower_town_render_probe.tscn \
  -- --output=/tmp/r564-render-probe.json
```

The host reported `Apple M5 Pro`; the generated JSON is temporary and is not treated as committed acceptance evidence. The probe confirms that draw-call and video-memory instrumentation works, but it cannot emulate or certify the declared Intel UHD 620 target.

## Decision and next actions

**R-564 verification deliverable: complete as a deterministic BLOCKED ledger.** R-538 may consume this report as an explicit readiness state, but not as an overall PASS. Keep R-108 / P0-101 open.

No new follow-up task is created: every blocker has an existing board owner (R-560, R-561, R-563, R-453/R-455, R-536/R-492, and P3-011). The next closeout must re-query R-560-R-563, confirm their artifacts and board statuses, rerun the clean-load gate, and verify declared-target hardware evidence before changing any status to PASS.

## Sources

- [`lower_town_p0_101_capture_matrix.md`](lower_town_p0_101_capture_matrix.md)
- [`lower_town_p0_101_runtime_qa.md`](lower_town_p0_101_runtime_qa.md)
- [`p0_101_clean_checkout_load_gate.md`](p0_101_clean_checkout_load_gate.md)
- [`r535_lower_town_runtime_performance_verification.md`](r535_lower_town_runtime_performance_verification.md)
- [`lower_town_p0_101_acceptance.md`](lower_town_p0_101_acceptance.md)
- [`tools/benchmarks/minimum-hardware.json`](../../tools/benchmarks/minimum-hardware.json)
- [`tools/benchmarks/lower_town_render_probe.tscn`](../../tools/benchmarks/lower_town_render_probe.tscn)
