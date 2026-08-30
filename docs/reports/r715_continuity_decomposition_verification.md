# R-816 water continuity decomposition verification

- Task: R-816
- Parent: R-715, realistic reflective water rollout
- Recorded: 2026-08-30
- Decision: **READY_FOR_R757** for the two continuity child handoffs; R-715 itself remains owned by R-757 and is not closed by this report.

## Scope and fail-closed rule

This report independently verifies the completed continuity children R-814 and R-815. It does not modify or re-accept their runtime implementation, water materials, shaders, map data, save schema, weather state, capture packet, or performance evidence. It also does not duplicate R-757's full R-715 acceptance suite.

The verifier accepts the continuity decomposition only when both child reports and focused tests exist, their required evidence fields are present, and their scopes remain separate. A missing artifact, missing evidence field, failed child suite, or scope overlap is **BLOCKED** with the exact child reference; no pass is inferred from a neighboring result.

## Exact evidence paths

| Child | Report | Focused test | Scope boundary |
|---|---|---|---|
| R-814 | [`r715_water_save_envelope.md`](r715_water_save_envelope.md) | [`test_r715_water_save_envelope.gd`](../../tests/godot/test_r715_water_save_envelope.gd) | Save/load persistence through `GameState.save_payload()`, JSON round-trip, `GameStatePersistence.load_payload()`, and source/restored presentation/uniform equality. |
| R-815 | [`r715_water_map_handoff.md`](r715_water_map_handoff.md) | [`test_r715_water_map_handoff.gd`](../../tests/godot/test_r715_water_map_handoff.gd) | Live map-transition handoff between `reval_harbor_north` and `reval_harbor_east`, before/after inputs/uniforms, and environment-owner/parity continuity. |

## Child verification matrix

| Child | Board status | Required source/restored or before/after evidence | Fresh focused result | Decision |
|---|---|---|---|---|
| R-814 | `done` | Report records `GameState.save_payload()`, `GameStatePersistence.load_payload()`, explicit `JSON round-trip`, source/restored presentation, and source/restored water uniforms. Test records source/restored dictionaries and the JSON loader path. | `test_r715_water_save_envelope`: **4 tests, 0 failures, 0 errors** | **PASS** |
| R-815 | `done` | Report records both map IDs, before/after uniform keys, owner counts, terrain and walkability parity. Test records source/destination inputs/uniforms, environment binding, owner count, and source deactivation. | `test_r715_water_map_handoff`: **2 tests, 0 failures, 0 errors** | **PASS** |

## Fresh focused commands and outputs

The two child suites were run independently against the current checkout before this report was written.

### R-814 save/load persistence

```bash
export GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_r715_water_save_envelope
```

Recorded output:

```text
Godot headless tests: 1 file(s), 4 test(s), 0 failure(s), 0 error(s).
```

The run emitted equal `R-814 source presentation` / `R-814 restored presentation` dictionaries and equal `R-814 source water uniforms` / `R-814 restored water uniforms` dictionaries for `water`, `river_water`, `shallow_water`, and `deep_water`. It also passed the missing-environment and invalid-environment fail-closed checks.

### R-815 map-transition handoff

```bash
export GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_r715_water_map_handoff
```

Recorded output:

```text
Godot headless tests: 1 file(s), 2 test(s), 0 failure(s), 0 error(s).
```

The run emitted `reval_harbor_north` to `reval_harbor_east` source/destination inputs and uniforms, preserved `before=1, after=1` environment owners, and preserved both terrain/walkability parity signatures.

## R-715 clause mapping

| R-715 clause | Evidence owner | Result and boundary |
|---|---|---|
| **Save/load persistence** | R-814 | **PASS**. Non-default storm/night weather is serialized through the game-state envelope and restored with equal source/restored water presentation and uniforms. |
| **Map-transition continuity** | R-815 | **PASS**. A live two-presenter handoff retains rain, wind, wetness, tide, day/night, celestial inputs, and shared water uniforms without a scene reload. |
| **Single environment ownership** | R-815 | **PASS**. The source presenter is deactivated and the destination remains attached; owner count is exactly one before and after handoff. |
| Real-renderer visual evidence | R-814/R-815 boundary | **BLOCKED**. Both child reports explicitly state that headless structural equality does not prove gameplay-camera visual continuity; R-756 owns the capture packet. |
| Target-hardware performance evidence | R-814/R-815 boundary | **BLOCKED**. Neither child measures GPU frame time or memory on the target hardware; parent performance evidence remains required. |

## Scope separation and negative fixtures

The focused R-816 contract test checks the live child source and reports rather than trusting filenames alone. It rejects:

- a missing R-814/R-815 report or focused test, or a report that no longer links its focused test;
- missing R-814 persistence/source-restored fields or missing R-815 handoff/before-after fields;
- a missing child report contract;
- R-814 polluted with R-815 handoff markers such as `before/after`, `owner counts`, or `reval_harbor_east`;
- R-815 polluted with R-814 persistence markers such as `GameState.save_payload()`, `JSON.stringify`, or `source/restored`.

The negative fixtures are in-memory mutations only. They prove that the verifier fails closed without modifying child artifacts.

## Verification command

```bash
export GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_r715_continuity_decomposition_verification
```

Expected result for this handoff:

```text
Godot headless tests: 1 file(s), 4 test(s), 0 failure(s), 0 error(s).
```

A missing child artifact or failed child suite changes the recommendation to **BLOCKED: R-814** or **BLOCKED: R-815**, as applicable. The contract does not execute or replace either child suite, so R-757 must consume this report together with the two fresh child outputs and run the complete parent gate.

The current recommendation is **READY_FOR_R757 only when both children pass**. This handoff meets that condition; the visual and target-hardware boundaries below remain blocked for the parent closeout.

## Downstream handoff

**READY_FOR_R757** means only that both continuity children are complete, independently evidenced, non-overlapping, and ready for downstream consumption. R-757 remains the closeout owner for R-715 and must independently rerun the complete rollout, map, weather, performance, capture, and report gates. Visual and target-hardware performance blockers remain active until their owning evidence is accepted.

Artifact: [`test_r715_continuity_decomposition_verification.gd`](../../tests/godot/test_r715_continuity_decomposition_verification.gd)
