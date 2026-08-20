# R-373 city-location activation acceptance

**Task:** R-373
**Verification date:** 2026-08-20
**Engine:** Godot 4.7.1 (`a13da4feb`)
**Decision:** **GATE IMPLEMENTED; ALL CURRENT CANDIDATES RED.**

## Decision boundary

The reusable gate is fail-closed. It does not activate maps and it does not repair map, runtime, renderer, population, or art implementation. The manifest may record RED candidates so production can see the first bad boundary. A promotion check selects one map with `--map=<map_id>` and exits non-zero until that candidate is fully GREEN.

A candidate can become GREEN only after its owning environment row is delivered and all of the following are explicit:

1. composition thresholds use `enforce=true` and the composition audit passes;
2. compile, navigation, transition, and patrol suites pass;
3. mandatory anchors have no blocked, missing, or unreachable record;
4. required landmarks and renderer affordances are present;
5. each fortification seam has reciprocal footprints plus signed, matched day and night captures from both adjacent districts;
6. urban maps provide accepted population and activity profiles;
7. representative gameplay loops and interactions pass, rather than relying on map-only inspection.

## Verification

| Check | Result | Evidence |
| --- | --- | --- |
| Focused gate suite | **PASS** | `./tools/run_godot_checked.sh --require-test-summary r373-location-activation -- /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_location_activation_acceptance`; 1 file, 8/8 tests, 0 failures, 0 errors |
| Positive fixture | **PASS** | Complete delivered fixture evaluates GREEN |
| Advisory composition fixture | **PASS** | `enforce=false` produces `COMPOSITION_NOT_ENFORCED` |
| Mandatory anchor fixture | **PASS** | blocked anchor produces `MANDATORY_ANCHOR_BLOCKED` |
| Landmark/affordance fixture | **PASS** | missing landmark and `GateDoor0` produce separate codes |
| Fortification seam fixture | **PASS** | footprint mismatch and unsigned night pair fail independently |
| Urban population fixture | **PASS** | absent activity profiles produce `URBAN_POPULATION_MISSING` |
| Gameplay fixture | **PASS** | empty loops/interactions produce `GAMEPLAY_EVIDENCE_MISSING` |
| Inventory mode | **PASS** | checker records six RED verdicts and exits 0 without claiming activation |
| Selected candidate mode | **PASS** | `--map=south_quarter` reports RED and exits 1 |

## Current verdicts

The first boundary intentionally follows delivery order. Later failures are still printed so owners can plan in parallel.

| Candidate | Owner | Verdict | First bad boundary | Additional named evidence boundary |
| --- | --- | --- | --- | --- |
| `lower_town_slice` | P0-100 | **RED** | `ENVIRONMENT_NOT_DELIVERED` | Enforced composition is red; St. Catherine's/gate acceptance, seam pairs, focused suites, and gameplay evidence remain incomplete. Lower Town population evidence is accepted through R-448. |
| `market_civic_quarter` | P4-022 | **RED** | `ENVIRONMENT_NOT_DELIVERED` | Composition is advisory; Town Hall/Holy Spirit, population/activity, focused suites, and gameplay evidence remain incomplete. |
| `north_quarter` | P4-023/P4-023f | **RED** | `ENVIRONMENT_NOT_DELIVERED` | Composition is advisory; Coastal Gate, wall seam pairs, population/activity, focused suites, and gameplay evidence remain incomplete. |
| `south_quarter` | P4-024 | **RED** | `ENVIRONMENT_NOT_DELIVERED` | Composition is advisory; `karja_gate_arch/GateDoor0` is absent; reciprocal topology alone lacks matched day/night seam evidence. |
| `toompea_quarter` | P4-025 | **RED** | `ENVIRONMENT_NOT_DELIVERED` | Composition is advisory; cathedral/castle and hill-gate affordances, seam pairs, population/activity, focused suites, and gameplay evidence remain incomplete. |
| `world.harju` | P5-003 | **RED** | `ENVIRONMENT_NOT_DELIVERED` | `MAP_ANCHOR_BLOCKED (35,10)` remains explicit; composition is advisory and gameplay evidence is absent. Urban population is not required. |

No image is promoted into `docs/reports/images/location_qa/`: existing topology checks and reference/capture packets do not provide signed, matched gameplay-camera seam pairs from both adjacent districts. Recording empty seam evidence is safer than copying unrelated or unsigned images.

## Usage

Inventory and report mode:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/verify_location_activation.gd
```

Fail-closed promotion check:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/verify_location_activation.gd -- --map=south_quarter
```

Producer should run the selected-map command before changing any candidate's release activation. RED findings return to the named Map, Dev, Art, or population owner; the gate itself must not weaken thresholds or infer visual continuity from coordinates.

## Files

- [`location_activation_manifest.json`](../data/location_activation_manifest.json)
- [`verify_location_activation.gd`](../../tools/verify_location_activation.gd)
- [`test_location_activation_acceptance.gd`](../../tests/godot/test_location_activation_acceptance.gd)
- [`map_composition_thresholds.json`](../data/map_composition_thresholds.json)
- [`r448_lower_town_urban_population_acceptance.md`](r448_lower_town_urban_population_acceptance.md)
