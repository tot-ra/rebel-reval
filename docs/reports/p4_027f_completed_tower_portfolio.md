# R-261 / P4-027f completed-tower portfolio acceptance

**Decision: BLOCKED (fail-closed).** This report defines the acceptance and activation plan for the conservative Spring 1343 completed-tower registry. It does not activate maps, create interiors, or treat construction candidates as finished dungeons.

## Decision boundary

The runtime registry is the source of truth for the dated portfolio. It currently contains exactly four completed positions: Nunnatorn, Kuldjala, Rentenitorn, and the Great Coastal Gate tower. Sand Gate, Viru Gate, Hinke, Cattle/Karja Gate, and Harju Gate remain construction candidates. Post-1343 exclusions remain absent from the completed portfolio. A candidate can enter the completed-tower portfolio only through a registry, map, transition, content, save, test, and review change; a familiar later tower silhouette is not sufficient evidence.

The gate is fail-closed:

- missing evidence is **BLOCKED**, not approval;
- a completed registry position without exactly one dedicated interior is **FAIL**;
- a construction candidate or post-1343 exclusion exposed as a completed dungeon is **FAIL**;
- a partial activation, one-way door, reused boss identity, missing save migration, or unsigned capture is **FAIL**;
- developer traversal may remain available with `release=false`, but no tower package is release-active from this plan.

## Registry and ownership matrix

The machine-readable ledger is [`../data/p4_027f_tower_portfolio.json`](../data/p4_027f_tower_portfolio.json). The rows below intentionally include planned scene/map IDs before those files exist, so missing implementation is visible rather than silently omitted.

| Historical identity | Map / building ID | Dedicated interior contract | Owner | Current state | Difficulty / loot band | Required boss distinction |
|---|---|---|---|---|---|---|
| Nunnatorn / Nun's Tower | `monastery_quarter` / `monastery_wall_tower_northwest` | `nunnatorn_interior` / `scenes/reval_monastery/nunnatorn_interior.tscn` | R-251, independent R-629 | **BLOCKED** | baseline / baseline evidence | Marten of Nunnatorn; use `nunnatorn_boss_guard` only for this package |
| Kuldjala / Golden Leg Tower | `monastery_quarter` / `monastery_wall_tower_west_mid` | `kuldjala_interior` / `scenes/reval_monastery/kuldjala_interior.tscn` | R-250 | **PLANNED** | entry / local craft and evidence | new authored identity and outcome contract; never copy Nunnatorn's boss |
| Rentenitorn / Rent Tower | `north_quarter` / `merchant_wall_tower_northwest` | `rentenitorn_interior` / `scenes/reval_north/rentenitorn_interior.tscn` | R-246 | **IN PROGRESS** | intermediate / watch and merchant evidence | mechanically distinct encounter, evidence, and alternate resolution |
| Great Coastal Gate tower | `north_quarter` / `coast_gate_west_tower` | `great_coastal_gate_interior` / `scenes/reval_north/great_coastal_gate_interior.tscn` | R-252 | **IN PROGRESS** | advanced / gate and harbour evidence | archaeology-reviewed gate-phase identity, not Fat Margaret or a later barbican |

The shared tower contract remains R-270. Each row must preserve its exterior stable ID, add one reciprocal interior transition pair, provide safe entry/return spawns, and remain inactive until the complete package passes this gate.

## Historical state guard

| Registry class | Spring 1343 treatment | Portfolio rule |
|---|---|---|
| Completed (`nunnatorn`, `kuldjala`, `rentenitorn`, `great_coastal_gate`) | Conservative completed baseline | Exactly one dedicated interior per row; no duplicate interior or generic tower fallback |
| Construction (`sand_gate`, `viru_gate`, `hinke`, `cattle_gate`, `harju_gate`) | Reversible masonry/scaffolding or exterior-only | No completed mini-dungeon, finished roof, mature barbican, or passable wall breach |
| Excluded (`saunatorn`, `nunnadetagune`, `loewenschede`, `koismae`, `epping`, `neitsitorn`, `kiek_in_de_kok`, `fat_margaret`) | Absent from the dated portfolio | No enterable interior, release transition, or later silhouette in a completed-tower capture |

Viru Gate's 1343 state is especially bounded: an unfinished gate position may have construction presentation, but its later foregate towers are not a completed interior package.

## Per-tower acceptance contract

Every completed row must provide all of the following before it can become `PASS`:

1. **Dedicated map and scene:** stable map ID, packed scene, source contract, and no generic tower scene substitution.
2. **Exterior/interior transition:** reciprocal destination and spawn IDs, one inward-facing exterior door, safe arrival cells, repeatable entry/exit without duplicate players or camera traps.
3. **Vertical traversal:** all authored floors reachable in both directions, a wall-walk or explicitly reviewed upper defensive route, collision and navigation continuity, and a bounded camera/readability check.
4. **Encounter identity:** one named boss, combat route, alternate/non-lethal route where authored, and outcome flags unique to the package. Boss, loot, and evidence are gameplay-authored, not archival claims.
5. **Loot and evidence:** separate records with outcome-aware collection and idempotent re-entry behavior. Loot tables must stay inside the row's difficulty/loot band and must not become a universal reward ladder.
6. **Save compatibility:** door, boss, alternate outcome, loot/evidence, and retry state survive save/load. Older envelopes receive safe defaults and migration tests. Failed attempts restore the documented retry checkpoint.
7. **Presentation:** historical/art review signs the 1343 form and exclusions; gameplay-scale day and night captures have identical framing, differ in lighting, and are signed for exterior and interior views.
8. **Performance:** target-hardware evidence records frame-time, draw-call, memory, node/collision, and actor counts for the package. Headless timing is regression evidence only, not target-GPU acceptance.
9. **Accessibility:** the package is checked with keyboard/mouse and gamepad paths, readable focus/contrast, subtitles/text settings, reduced flashing/screen-shake options, and no gameplay state encoded by hue alone.
10. **Packaged smoke:** the exact developer/release artifact loads, enters, exits, saves, reloads, and returns without activating excluded maps or losing persistent state.

## Difficulty, loot, and boss portfolio progression

The four rows form a bounded progression, not a power treadmill:

- **Baseline - Nunnatorn:** establishes the shared vertical route, alternate resolution, evidence separation, save/retry semantics, and readability packet. Its accepted identity is Marten of Nunnatorn; later tower forms remain excluded.
- **Entry - Kuldjala:** adds the circa-1310 horseshoe form only under its own historical/art review and introduces local craft/evidence rewards. It must not copy Nunnatorn's encounter, layout assumptions, or loot record.
- **Intermediate - Rentenitorn:** uses the conservative pre-mid-fourteenth-century form and watch/merchant evidence. Unknown fabric remains labelled reversible reconstruction; challenge comes from authored encounter design, not invented historical certainty.
- **Advanced - Great Coastal Gate:** uses the probable 1311-1340 gate phase and harbour-facing evidence. The package must explicitly reject Fat Margaret, mature barbicans, and later gate works. Its difficulty comes from gate-route pressure and authored choices, not a later fortress mass.

Acceptance checks must compare each package against its own band and identity. A package passes only when it is distinct by stable IDs, encounter content, evidence/loot records, and capture labels, not merely by recoloured materials.

## Save migration and retry matrix

| State | New save | Older save / missing fields | Re-entry expectation |
|---|---|---|---|
| Door entered, encounter unresolved | Create package state with safe checkpoint | Add default unresolved state without changing existing act/faction records | Return to entry without duplicate player or reset of unrelated state |
| Lethal outcome | Persist unique defeated flag, outcome ledger, and eligible loot | Migrate absent tower fields to unresolved, never infer a kill | Loot collection is one-shot and remains collected |
| Alternate outcome | Persist unique alternate flag, witness/evidence result, and no lethal-only loot | Preserve alternate only when explicit; mixed flags fail closed | Re-entry keeps the authored alternate state and retry semantics |
| Failed attempt | Persist only approved transient retry/checkpoint data | Safe defaults clear stale transient values | Retry restores checkpoint without duplicating ledger events |
| Package introduction | Preserve existing save envelope and act boundary | Versioned migration with fixture and round-trip test | No release activation is implied by migration alone |

## Performance and accessibility evidence packet

For each row, retain a report entry with the package ID, host profile, renderer, frame-time p95, peak draw calls/primitives, static and delta memory, node/collision counts, and actor count. Run the non-headless GPU probe on the declared target; label headless results as CPU/regression evidence only. Compare against the existing performance methodology in [`../PERFORMANCE_REPORT.md`](../PERFORMANCE_REPORT.md), without inventing a tower-specific budget until the maintainer records one.

The accessibility packet must cite the existing checklist and demonstrate both input methods. Reviewers must be able to distinguish player, enemy, route, door, loot, and outcome state by shape/value/labels, with subtitle background, scalable text, text speed, focus contrast, reduced flashing, and screen-shake controls available. A missing capture or review is BLOCKED, not waived.

## Final activation sequence

1. Run the registry/map audit and assert four completed IDs, five construction IDs, and eight exclusion IDs with no overlap.
2. For each completed ID, verify exactly one dedicated interior map/scene and reciprocal transition/spawn pair.
3. Run per-package traversal, collision/navigation, boss branch, loot/evidence, save/migration/retry, and packaged smoke suites.
4. Run the target-hardware performance packet and accessibility review for every exterior/interior pair.
5. Capture matched day/night exterior and interior plates, obtain historical/art sign-off, and link the signed day/night captures in the portfolio ledger.
6. Re-run the full tower portfolio verifier. It may report `BLOCKED` while dependencies are incomplete, but it must never report `PASS` unless every row is green.
7. Only after the ledger is `approved` with no blockers may a maintainer separately change developer-only transition state to release-active. This plan itself never performs that promotion.

## Current verdict and follow-up ownership

**R-261 remains BLOCKED.** Nunnatorn has a dedicated acceptance report but its independent presentation gate is not yet a portfolio sign-off. Kuldjala, Rentenitorn, and Great Coastal Gate still require their owning packages and independent review. R-270 is also still open, so no row can honestly be activated as a completed tower from this report.

| Blocker | Owner / next evidence |
|---|---|
| Shared enterable-tower contract | R-270: common transition, floor, boss, persistence, camera, and packaged checks |
| Nunnatorn independent closeout | R-629: consume the package acceptance and presentation evidence |
| Kuldjala package | R-250: dedicated map/scene, reviewed horseshoe form, distinct boss/loot/save tests |
| Rentenitorn package | R-246: reversible historical form and complete runtime package |
| Great Coastal Gate package | R-252: archaeology-reviewed gate phase, no later barbican/Fat Margaret |
| Portfolio closeout | R-261: rerun this ledger and record signed captures for all four rows |

## Verification commands

```bash
python3 tools/verify_p4_027f_tower_portfolio.py
python3 -m unittest tests.python.test_verify_p4_027f_tower_portfolio -v

export GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_map_tower_doors
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_nunnatorn_interior_map,test_nunnatorn_transitions,test_nunnatorn_boss_encounter,test_nunnatorn_evidence,test_nunnatorn_persistence
```

The first two commands are the R-261 static gate. The Godot commands are current baseline evidence and do not close missing Kuldjala, Rentenitorn, or Great Coastal Gate packages.

## Sources

- [`scripts/map/reval_fortification_registry.gd`](../../scripts/map/reval_fortification_registry.gd) - dated completed, construction, and excluded sets.
- [`reval_fortifications_1343.md`](reval_fortifications_1343.md) - 1343 boundary, one-interior-per-completed-tower rule, construction policy, and exclusions.
- [`nunnatorn_acceptance.md`](nunnatorn_acceptance.md) - existing independent package evidence and its blocked presentation boundary.
- [`nunnatorn_interior_contract.md`](nunnatorn_interior_contract.md) - shared route, transition, outcome, save, and review semantics.
- [`../PERFORMANCE_REPORT.md`](../PERFORMANCE_REPORT.md) - target-hardware versus headless performance evidence boundary.
- [`../data/accessibility_checklist.json`](../data/accessibility_checklist.json) - existing accessibility surfaces and supported input methods.
