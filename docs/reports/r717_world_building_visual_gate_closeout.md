# R-717 world-building visual gate closeout

**Task:** `R-717` / R-716 exterior capture packet and sign-offs
**Recorded UTC:** 2026-08-25
**Decision:** **BLOCKED - deterministic gate contract is executable, but the required capture and review evidence is not present**

## Scope and boundary

This closeout makes the R-716 release gate actionable without inventing visual evidence. It does not change map IDs, scene IDs, fixed capture settings, transition release flags, performance caps, or human review outcomes.

The checked-in manifest covers the complete expected matrix:

| Requirement | Inventory | Current state |
|---|---:|---|
| Active/candidate exterior maps | 30 | All represented |
| Required capture categories | 12 | Contract locked |
| Capture jobs | 360 | Plan generated; all manifest rows remain `pending` |
| Per-map rubric criteria | 12 x 30 = 360 | All rows remain `pending` |
| Human art reviews | 30 | All remain `pending`; no reviewer/date/evidence claimed |
| Automated checks | 5 | All remain `pending` |
| Performance evidence tiers | 2 (`minimum`, `recommended`) | Both remain `pending` |
| Comparison sheet | 1 | Remains `pending`; no revision/timestamp claimed |

## Contract hardening delivered

The verifier now fails closed when any of the following is missing or unaccepted:

- an automated check row;
- separate minimum and recommended performance evidence;
- `target_hardware` and `measurement_host` identity on each performance row;
- comparison-sheet revision;
- comparison-sheet ISO-8601 `generated_utc` timestamp.

The manifest records the existing performance evidence references without promoting them. The minimum-hardware evidence identifies the declared Intel UHD 620 target separately from the Apple M5 Pro measurement host. The recommended row similarly keeps target and host identity explicit. Neither row is marked accepted.

## Verification

| Command | Result |
|---|---|
| `python3 tools/generate_world_building_capture_plan.py --output /tmp/r716-capture-plan.json` | **PASS** - wrote 360 jobs, covering 30 maps x 12 categories |
| `python3 -m unittest tests.python.test_verify_world_building_visual_gate tests.python.test_generate_world_building_capture_plan -v` | **PASS** - 8 tests |
| `python3 -m py_compile tools/verify_world_building_visual_gate.py tools/generate_world_building_capture_plan.py tests/python/test_verify_world_building_visual_gate.py tests/python/test_generate_world_building_capture_plan.py` | **PASS** |
| `python3 -m json.tool docs/data/world_building_visual_benchmark.json` | **PASS** |
| `python3 tools/verify_world_building_visual_gate.py --json` | **BLOCKED** - exit 1; 30/30 matrix rows are present, but the required evidence remains pending (849 findings) |
| `git diff --check -- tools/verify_world_building_visual_gate.py tests/python/test_verify_world_building_visual_gate.py docs/data/world_building_visual_benchmark.json docs/WORLD_BUILDING_VISUAL_GATE.md` | **PASS** |

The 849 findings are expected fail-closed output, not a missing-map defect: 360 capture rows, 360 rubric rows, 30 human review rows, automated evidence, both performance tiers, and the comparison sheet remain unresolved.

## Hardware and evidence boundary

`docs/reports/data/r653_minimum_hardware_gpu_evidence_manifest.json` records supplementary non-headless instrumentation on an Apple M5 Pro `arm64` host. The declared minimum target remains Intel Core i5-8250U / Intel UHD Graphics 620 / `x86_64` / 8 GiB. The host mismatch means the Apple run cannot certify the minimum target and is intentionally not marked `pass` in this manifest.

The existing `docs/reports/data/p038_comparison_evidence.json` is a development-baseline/headless report. It is useful provenance, but it cannot substitute for a declared-target GPU measurement or human visual acceptance.

## Remaining blockers

1. Run and retain the 360 fixed-setting capture jobs at `1920x1080` using the locked camera, exposure, day/midnight, clear/rain, and wind-seed settings.
2. Attach repository-relative evidence for every capture and every rubric decision, including a versioned comparison sheet.
3. Obtain named, dated human art review for all 30 exterior map rows.
4. Obtain valid minimum and recommended performance reports with target/measurement-host identity. Do not relabel the Apple M5 Pro supplementary run as Intel UHD 620 evidence.
5. Mark the five automated checks accepted only after their referenced reports are independently green.

Until all five groups are complete, `verify_world_building_visual_gate.py` must continue to return non-zero and no map may be promoted through this gate.

## Sources

- [`docs/data/world_building_visual_benchmark.json`](../data/world_building_visual_benchmark.json)
- [`docs/WORLD_BUILDING_VISUAL_GATE.md`](../WORLD_BUILDING_VISUAL_GATE.md)
- [`tools/generate_world_building_capture_plan.py`](../../tools/generate_world_building_capture_plan.py)
- [`tools/verify_world_building_visual_gate.py`](../../tools/verify_world_building_visual_gate.py)
- [`tests/python/test_generate_world_building_capture_plan.py`](../../tests/python/test_generate_world_building_capture_plan.py)
- [`tests/python/test_verify_world_building_visual_gate.py`](../../tests/python/test_verify_world_building_visual_gate.py)
- [`docs/reports/data/r653_minimum_hardware_gpu_evidence_manifest.json`](data/r653_minimum_hardware_gpu_evidence_manifest.json)
- [`docs/reports/data/p038_comparison_evidence.json`](data/p038_comparison_evidence.json)
