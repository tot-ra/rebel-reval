# R-834 P4-020 upstream dependency reconciliation

**Task:** R-834 / P4-020a
**Parent:** R-245 / P4-020
**Reconciliation date:** 2026-09-01
**Decision:** **BLOCKED for North Quarter activation; upstream reconciliation complete**

## Scope and decision boundary

This note reconciles the four dependencies named by the P4-020 readiness ledger against the current task board and the linked repository evidence. It does not change North Quarter geometry, runtime activation, transition release state, or visual acceptance. A board status of `in_review` is not treated as an accepted dependency: each row must reach its own verified closeout before P4-020 can promote the map.

The current North Quarter state remains intentionally fail-closed:

- `content/maps/north_quarter.rrmap` remains `scope=prototype active=false`;
- the `reval_north` catalog entry remains prototype/inactive;
- developer traversal remains available while `release=false`;
- `docs/data/p4_020_north_quarter_activation.json` remains `decision=blocked` with all required blockers present.

## Upstream dependency matrix

Board statuses queried on 2026-09-01:

| Dependency | Board ref | Board status | Current evidence | Reconciliation result | Remaining boundary |
|---|---|---|---|---|---|
| Art-bible and technical-freeze baseline | R-111 / P0-040 | `in_progress` | [`p0_040_maintainer_approval_packet.md`](p0_040_maintainer_approval_packet.md) | **BLOCKED** - the parent acceptance boundary is still open; downstream North Quarter activation cannot assume the baseline is finally approved | P0-040 / R-111 and its approval handoff |
| Converted-map visual/gameplay parity | R-214 / P2-021 | `in_review` | [`map_conversion_parity.md`](map_conversion_parity.md) | **BLOCKED** - review is not an accepted parity verdict, so the dependency remains open for activation purposes | P2-021 / R-214 must complete its named visual and gameplay sign-off |
| Central District activation prerequisite | R-254 / P4-019 | `in_review` | [`p4_019_central_district_activation.json`](../data/p4_019_central_district_activation.json) and [`verify_p4_019_central_district_activation.py`](../../tools/verify_p4_019_central_district_activation.py) | **BLOCKED** - its fail-closed ledger and board row remain open even though the implementation slice exists | P4-019 / R-254 must close its dependency and evidence gates |
| North Quarter environment acceptance | R-280 / P4-023f | `in_review` | [`p4_023_north_quarter_environment_acceptance.md`](p4_023_north_quarter_environment_acceptance.md) | **BLOCKED** - drainage/relief and Coastal Gate implementation are handed off for review; historical/art and signed day/night acceptance remain unresolved | P4-023f / R-280 must record accepted review and evidence |

## Deterministic readiness result

**R-834 result: reconciliation PASS; P4-020 activation BLOCKED.** The four ledger blockers are still the correct blockers, and none may be removed merely because its board row moved from `todo` to `in_review`. The parent activation gate must remain closed until all four dependencies are independently accepted and the later North Quarter traversal, parity, activation, and final-verification gates pass.

No activation change is authorized by this report. No duplicate implementation task is created because each unresolved boundary already has an owning board row.

## Verification

```bash
python3 tools/verify_north_quarter_activation.py
python3 -m unittest tests.python.test_verify_north_quarter_activation -v
```

Both commands pass against the reconciled, blocked repository state: the ledger is internally consistent, partial promotion is rejected, production promotion requires approval and parity evidence, and removal of a named dependency is rejected.

## Sources

- [`p4_020_north_quarter_activation.json`](../data/p4_020_north_quarter_activation.json)
- [`verify_north_quarter_activation.py`](../../tools/verify_north_quarter_activation.py)
- [`p4_019_central_district_activation.json`](../data/p4_019_central_district_activation.json)
- [`p4_023_north_quarter_environment_acceptance.md`](p4_023_north_quarter_environment_acceptance.md)
- [`location_activation_acceptance.md`](location_activation_acceptance.md)
