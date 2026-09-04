# P4-019 Central District activation readiness

**Task:** P4-019
**Verification date:** 2026-08-20
**Decision:** **GATE IMPLEMENTED; CENTRAL DISTRICT REMAINS BLOCKED.**

## Decision boundary

The readiness guard is fail-closed. It does not activate the unified Central District, repair its environment, or infer visual parity from the existing prototype. It checks that the rrmap, map catalog, transition manifest, approval artifact, and activation ledger agree before a future promotion can be considered.

A production promotion requires all three runtime state records to switch together:

1. `content/maps/market_civic_quarter.rrmap` uses `scope=production active=true`;
2. `scripts/map/map_catalog.gd` marks `reval_center` as production and active;
3. `content/transitions/active_destinations.json` keeps `reval_center` active and changes `release` to `true`.

The guard then requires an approved ledger with no blockers and accepted, distinct day/night PNG captures using identical dimensions. Until those conditions exist, developer traversal remains available with `release=false`.

## Current blocked state

The ledger records the named dependencies that prevent a truthful activation decision:

- `P0-040` - maintainer technical-freeze and visual-style approval;
- `P2-021` - accepted Central District visual/composition parity evidence;
- `P3-014` - runtime acceptance dependency;
- `P4-022` - Central District environment pass.

These blockers are recorded as evidence, not waived by this guard.

## Verification

| Check | Result | Evidence |
| --- | --- | --- |
| Repository readiness guard | **PASS** | `python3 tools/verify_p4_019_central_district_activation.py` |
| Focused Python suite | **PASS** | `python3 -m unittest tests.python.test_verify_p4_019_central_district_activation -v`; 4/4 tests |
| Existing generic activation guard | **PASS** | `python3 tools/verify_map_activation.py` |
| Existing prototype map state | **PASS** | Central District remains developer-only and `release=false` |

## Usage

```bash
python3 tools/verify_p4_019_central_district_activation.py
```

The command returns non-zero if any runtime registry is partially promoted, if the blocked ledger loses a named dependency, or if a future production state lacks approval/parity evidence.

## Files

- [`p4_019_central_district_activation.json`](../data/p4_019_central_district_activation.json)
- [`verify_p4_019_central_district_activation.py`](../../tools/verify_p4_019_central_district_activation.py)
- [`test_verify_p4_019_central_district_activation.py`](../../tests/python/test_verify_p4_019_central_district_activation.py)
- [`market_civic_quarter.rrmap`](../../content/maps/market_civic_quarter.rrmap)
- [`0008-three-act-campaign-and-faction-scope.md`](../adr/0008-three-act-campaign-and-faction-scope.md)
