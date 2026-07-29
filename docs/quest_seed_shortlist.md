# P7-006 Quest-Seed Shortlist

**Status:** Approved planning artifact
**Source:** `docs/QUESTS.md`, `docs/IDEAS_RESEARCH.md`
**Evaluated against:** ADR 0008 three-act campaign, current content packages, `docs/CANON.md`

---

## Legend

| Label | Meaning |
|-------|---------|
| **keep** | Seed is usable as-is or with minor rewording; ready for content-package authoring |
| **adapt** | Core hook is strong but needs rewording to fit canon/rules (no literal magic, no plague epilogue, no travel outside Reval/siege region) |
| **defer** | Seed belongs to a later act or requires systems not yet built |
| **reject** | Seed conflicts with canon, scope, or design rules; do not implement |

Act tags: **A1** = Act 1 (Simmering City), **A2** = Act 2 (Fire of Rebellion), **A3** = Act 3 (Iron Harvest).

---

## Shortlist (15 seeds)

### A1 - Act 1 candidates (ready for P4 quest-pipeline authoring)

| # | Seed | Source | Label | Target act | Content-ID stub | Required systems | Notes |
|---|------|--------|-------|------------|-----------------|------------------|-------|
| 1 | The Silent Baker | QUESTS.MD miscellaneous | **adapt** | A1 | `quest.silent_baker` | investigation, evidence, consequence | Tone down hallucination to plausible ergot/tainted flour mystery; no literal prophecy. Candidate for P4-021 faction quest line filler or standalone cycle. |
| 2 | The Guild's Gambit | QUESTS.MD hanseatic | **keep** | A1 | `quest.guilds_gambit` | faction ledger, supply chain, consequence | Hanseatic economic sabotage fits Act 1 merchant-district tension. Candidate for P4-021 Black Cloaks or Hanseatic line. |
| 3 | The Debt Collector | QUESTS.MD hanseatic | **adapt** | A1 | `quest.debt_collector` | faction ledger, NPC relationship, consequence | Reframe noble as a Hanseatic merchant creditor; player chooses enforcement method. No violence-only resolution. |
| 4 | The Spice of Life | QUESTS.MD hanseatic | **keep** | A1 | `quest.spice_of_life` | investigation, evidence, supply chain | Theft investigation; fits existing investigative-quest pattern from P4-035. |
| 5 | The Whispering Walls | QUESTS.MD estonian_rebels | **keep** | A1 | `quest.whispering_walls` | night mission template, patrol evasion | Night propaganda mission; directly feeds Act 1 rebel quest line (P4-021). Candidate for Estonian Rebels faction line. |
| 6 | A Knight's Honor | QUESTS.MD livonian_order | **adapt** | A1 | `quest.knights_honor` | faction ledger, investigation, consequence | Knight investigation fits Livonian Order faction line (P4-021). Reframe "cowardice" accusation as a political tool within Order hierarchy. |
| 7 | Ashes for Amber | QUESTS.MD miscellaneous | **adapt** | A1 | `quest.ashes_for_amber` | investigation, stealth, consequence | Replace "magical amber" with a historically plausible amber trade good (Hanseatic amber was valuable). Smuggling a body from a crypt is a bold heist. |

### A2 - Act 2 candidates (need Act 2 design gate P5-001)

| # | Seed | Source | Label | Target act | Content-ID stub | Required systems | Notes |
|---|------|--------|-------|------------|-----------------|------------------|-------|
| 8 | The Heretic Hunt | QUESTS.MD livonian_order | **keep** | A2 | `quest.heretic_hunt` | faction war-state, patrol, consequence | Order infiltration mission; directly ties to Act 2 uprising context. |
| 9 | The Armory Heist | QUESTS.MD estonian_rebels | **keep** | A2 | `quest.armory_heist` | night mission template, combat, consequence | Rebel weapons raid; fits Act 2 rebel operations during siege. |
| 10 | The Emissary | QUESTS.MD estonian_rebels | **keep** | A2 | `quest.emissary` | world travel, escort, patrol evasion | Message-carrying mission; fits Act 2 world-travel layer (P5-002/P5-003). |
| 11 | The Border Crossing | QUESTS.MD pskov | **keep** | A2 | `quest.border_crossing` | world travel, stealth, faction ledger | Pskov agent smuggling; fits Act 2 Pskov faction line. |
| 12 | The Pskovian Pact | QUESTS.MD pskov | **keep** | A2 | `quest.pskovian_pact` | world travel, faction ledger, consequence | Alliance negotiation; Act 2 culmination of Pskov line. |
| 13 | Novgorod birch bark | IDEAS_RESEARCH.md | **adapt** | A2/A3 | `quest.birch_bark_manuscript` | world travel, investigation | Reframe from "Novgorod quest" to a birch-bark message recovered in Reval that reveals rebel correspondence. Avoids requiring Novgorod as a playable location. |

### Rejected

| # | Seed | Source | Label | Reason |
|---|------|--------|-------|--------|
| 14 | The Swedish Gambit | QUESTS.MD bandits | **reject** | Out of scope: requires travel to Sweden. Game region is Reval + immediate hinterland + siege locations. |
| 15 | The Elk with the Iron Eye | QUESTS.MD miscellaneous | **reject** | Supernatural animal-pact quest conflicts with design rules (no literal magic confirmation, no fantasy creatures as quest actors). Folklore creatures appear as beliefs, not as literal quest givers. |

### Plague epilogue (explicitly excluded)

| Seed | Source | Label | Reason |
|------|--------|-------|--------|
| "The Last Song" (1351 plague epilogue) | story/archive/ | **reject** | Superseded by ADR 0008; campaign closes at 1346 sale of Estonia. CANON.md marks this `non-canon`. |

---

## System requirements summary

| System | Seeds requiring it | Availability |
|--------|-------------------|--------------|
| Investigation / evidence | 1, 4, 6, 7, 13 | Built (P4-035) |
| Faction ledger | 2, 3, 6, 8, 11, 12 | Built (P4-016) |
| Night mission template | 5, 9 | Planned (P5-004) |
| World travel | 10, 11, 12, 13 | Planned (P5-002) |
| Supply chain | 2, 4 | Built (P4-033) |
| NPC relationship | 3, 6 | Built (P4-031) |
| Consequence / aftermath | 1, 2, 3, 4, 5, 6, 7, 8, 9, 12 | Built (P4-009 pattern) |

## Dependency on TODO rows

| TODO row | Seeds it enables |
|----------|-----------------|
| P4-021 (faction quest lines) | 2, 3, 5, 6, 8, 9, 10, 11, 12 |
| P5-001 (Act 2 design) | 8, 9, 10, 11, 12, 13 |
| P5-002 (world travel) | 10, 11, 12, 13 |
| P5-004 (night mission framework) | 5, 9 |

---

## Recommendation

1. **Immediate (A1):** Seeds 1-7 are ready for content-package authoring via P4-018 pipeline once P4-021 faction quest lines are scoped. Seeds 2, 4, 5 are the strongest because they reuse built systems with minimal adaptation.
2. **Act 2 planning:** Seeds 8-13 should be carried into P5-001 design gate as candidate faction-quest content. The Pskov line (11, 12) and Estonian rebel line (8, 9, 10) are the strongest candidates for the three-quest faction-line contract.
3. **No new systems needed for A1 seeds:** All seven A1 candidates use investigation, faction ledger, or supply-chain systems that are already built.
