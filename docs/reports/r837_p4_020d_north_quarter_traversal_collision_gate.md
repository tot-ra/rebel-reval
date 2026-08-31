# R-837 P4-020d North Quarter traversal and collision gate

**Task:** R-837 / P4-020d
**Parent:** R-245 / P4-020 North Quarter activation
**Verification date:** 2026-09-01
**Repository HEAD at verification:** `f3a9a3d329742d1ea375a6f775a30d0bba29bc29` (shared worktree contains unrelated staged and unstaged WIP)
**Godot:** `4.7.1.stable.official.a13da4feb`
**Decision:** **BLOCKED - scoped traversal/collision evidence is green, but North Quarter acceptance and activation remain fail-closed**

## Scope and decision boundary

This is an evidence-only closeout for the North Quarter traversal, spawn-clearance, reciprocal-transition, and collision gate. It does not change `content/maps/north_quarter.rrmap`, the transition manifest, runtime activation state, the activation ledger, or unrelated map composition data.

The result must not be read as a promotion approval. The activation ledger remains blocked by `P0-040`, `P2-021`, `P4-019`, and `P4-023f`; the next controlled activation task, R-838 / P4-020e, remains open.

## Verification matrix

| Check | Result | Evidence and interpretation |
|---|---|---|
| North Quarter activation guard | **PASS, fail-closed** | `python3 tools/verify_north_quarter_activation.py` passed. The RRMap and catalog remain `scope=prototype active=false`; developer traversal remains available with release disabled; the ledger remains `decision=blocked`. |
| Activation-ledger Python suite | **PASS** | `python3 -m unittest tests.python.test_verify_north_quarter_activation -v`: **4/4 tests passed**. |
| North Quarter prototype suite | **PASS** | `test_north_quarter_prototype_map`: **10/10 tests passed**. |
| Transition spawn-clearance suite | **PASS** | `test_transition_spawn_clearance`: **6/6 tests passed**. |
| Transition manifest suite | **PASS** | `test_transition_manifest`: **6/6 tests passed**. |
| Scoped focused matrix | **PASS with external failure** | Four focused Godot files ran **42 tests: 41 passed, 1 failed, 0 errors**. Every North Quarter, transition-manifest, and spawn-clearance assertion passed. The only failure is the unrelated South Quarter composition assertion below. |
| North Quarter collision and route probe | **PASS** | A bounded standalone Godot probe against `north_quarter_definition.gd` reported `collision_parity=true` and `route_to_merchant_court=true`, then exited 0. The log contains only known teardown ObjectDB/resource-leak diagnostics: 185 leaked ObjectDB instances and 8 resources still in use. |
| Aggregate transition verifier | **BLOCKED by timeout** | `tools/verify_transitions.gd` was bounded at **120 seconds** and retried at **90 seconds**. Both runs emitted only the Godot banner before timeout; no aggregate pass is claimed. |
| Aggregate map-quality/collision run | **BLOCKED by independent map parser diagnostics and timeout** | The bounded run exited with status **124**. Its log includes repeated `MAP_ID_UNSTABLE` errors for uppercase IDs in `content/maps/toompea_small_castle.rrmap`, including `SC-castle-chapel`, `SC-service-cellar`, `OB-courtyard`, and `OB-east-gate`. This is outside R-837 and is not evidence of a North Quarter collision defect. |

## External focused-matrix failure

The single failed assertion was:

```text
south_quarter stone_pct measured 23.2551934438727 outside 25.0-40.0
```

This is the South Quarter composition contract in `test_market_prototype_maps.gd`, not a North Quarter traversal, spawn, transition, or collision assertion. It remains an external blocker owned by the South Quarter composition work and is preserved rather than altered here.

## Acceptance disposition

The scoped R-837 behavior is verified as follows:

- North Quarter prototype geometry and required routes pass.
- North Quarter transition spawn clearance passes.
- Reciprocal transition manifest contracts pass.
- North Quarter building collision footprints match authored footprints in the bounded probe.
- The route from the authored player spawn to `merchant_court` is available in the compiled terrain.

The acceptance gate remains **blocked**. This evidence does not clear the activation ledger, does not make `reval_north` a production scene, and does not authorize R-838 to promote the district. Upstream approval, environment/parity evidence, and the independent South Quarter/Toompea diagnostics still require their owning tasks.

## Exact verification commands

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot

python3 tools/verify_north_quarter_activation.py
python3 -m unittest tests.python.test_verify_north_quarter_activation -v

"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_north_quarter_prototype_map
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_transition_spawn_clearance
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_transition_manifest
```

The focused matrix was captured in `/private/tmp/r837-godot/map-quality-command.log`. The bounded North Quarter collision probe was run from a temporary `res://` helper and removed after the result was captured; its output is in `/private/tmp/r837-godot/north-collision-probe.log`. The transition verifier timeout output is in `/private/tmp/r837-godot/verify-transitions.log`.

## Required next steps

1. Keep `docs/data/p4_020_north_quarter_activation.json` unchanged with `decision=blocked` and the four existing blockers.
2. Resolve or explicitly accept the upstream P4-020 dependencies, including the signed P4-023f environment/day-night packet and the P4-019 prerequisite.
3. Resolve the independent `south_quarter` composition failure and the `toompea_small_castle.rrmap` stable-ID/parser diagnostics under their owning tasks.
4. Re-run the full transition verifier with a bounded process after the unrelated timeout/parser blockers are understood.
5. Revisit R-838 only after the activation guard, evidence packet, and all release gates are accepted together.

## Sources

- [`../data/p4_020_north_quarter_activation.json`](../data/p4_020_north_quarter_activation.json)
- [`p4_023_north_quarter_environment_acceptance.md`](p4_023_north_quarter_environment_acceptance.md)
- [`r834_p4_020a_upstream_dependency_reconciliation.md`](r834_p4_020a_upstream_dependency_reconciliation.md)
- [`r835_p4_020b_north_quarter_elevation_parser_gate.md`](r835_p4_020b_north_quarter_elevation_parser_gate.md)
- [`r836_p4_020c_north_quarter_day_night_parity_review.md`](r836_p4_020c_north_quarter_day_night_parity_review.md)
- [`../../content/maps/north_quarter.rrmap`](../../content/maps/north_quarter.rrmap)
- [`../../scripts/map/map_verification.gd`](../../scripts/map/map_verification.gd)
- [`../../scripts/map/definitions/prototypes/north_quarter_definition.gd`](../../scripts/map/definitions/prototypes/north_quarter_definition.gd)
- [`../../tests/godot/test_north_quarter_prototype_map.gd`](../../tests/godot/test_north_quarter_prototype_map.gd)
- [`../../tests/godot/test_transition_manifest.gd`](../../tests/godot/test_transition_manifest.gd)
- [`../../tests/godot/test_transition_spawn_clearance.gd`](../../tests/godot/test_transition_spawn_clearance.gd)
- [`../../tools/verify_north_quarter_activation.py`](../../tools/verify_north_quarter_activation.py)
- [`../../tools/verify_transitions.gd`](../../tools/verify_transitions.gd)

**Final status:** **R-837 verification complete; North Quarter acceptance and activation remain BLOCKED.**
