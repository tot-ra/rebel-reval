# Legacy Design Reintroduction Inventory

**Status:** Active planning document  
**Approval:** [ADR 0017](./adr/0017-legacy-design-reintroduction.md)  
**Maintainer decision (2026-07-29):** Reintroduce Legacy Design & Research Material into the game plan - characters, history, magic, and related systems. Legacy 2D/pixel sprites are inspiration only; production needs new models under the current art pipeline.

This file maps archived or superseded design sources to planned reconciliation and implementation work. Nothing here is runtime truth until its `TODO.md` verify line passes and canon briefs exist.

## Delivery constraint

MVP-first order from ADR 0008 still holds: demo → vertical-slice MVP → Act 1 → Act 2 → Act 3.  
P7 design/canon rows may run in parallel. P7 implementation rows depend on slice gates and the design row for that pillar.

## Source → plan map

| Pillar | Legacy sources | Planned active home | Design TODO | Implementation TODO (after design) |
|---|---|---|---|---|
| Dual magic (pagan + divine rites) | `character/MAGIC-ELEMENTS.md`, `PAGAN-MAGIC.md`, `CHRISTIAN-MAGIC.md` | [`docs/SYSTEMS/MAGIC.md`](./SYSTEMS/MAGIC.md) + CANON folklore/invented labels | P7-001, P7-002 | P7-010 |
| NATURAL aspects + progression | `character/BUILD.md` | [`docs/SYSTEMS/NATURAL.md`](./SYSTEMS/NATURAL.md) | P7-001, P7-003 | P7-011 |
| Psyche / Hingepuu / Ego | `character/PSYCHE.md`, GAME-PILLARS Ego NPC | [`docs/SYSTEMS/PSYCHE.md`](./SYSTEMS/PSYCHE.md); extend Hingepuu beyond reflection screen | P7-001, P7-003 | P7-011 |
| Living City meters + allegiance pressure | `docs/GAMEPLAY.md`, `docs/GAME-PILLARS.md` | [`docs/SYSTEMS/LIVING_CITY.md`](./SYSTEMS/LIVING_CITY.md); complements faction ledger (no Balance of Power aggregate) | P7-001, P7-004 | P7-012 |
| Combat depth | `character/COMBAT.md` | extend combat design after magic/NATURAL contracts | P7-001, P7-005 | act-gated after P7-010/011 |
| Night systems | `docs/GAMEPLAY-NIGHT.md` | enrich P5 night templates; keep authored missions | P7-001, P7-005 | P5/P7 follow-ons |
| Quest seeds | `QUESTS.md`, `docs/IDEAS_RESEARCH.md` | content packages via P4 quest pipeline | P7-001, P7-006 | per-quest P4/P5/P6 rows |
| Mini-games (selected) | `docs/MINI_GAMES.md` | priority shortlist; reject naval/castle sims unless later ADR | P7-001, P7-007 | per accepted mini-game row |
| Story / timeline | `story/STORY.md`, `history/HISTORY.md`, `history/TIMELINE.md` | `docs/CANON.md` Timeline 1342–1346, Political landscape, Promoted and rejected story seeds | P7-001, P7-008 (delivered; pending canon) | P5/P6 act design + content tasks |
| Expanded cast | `characters/**` sheets | [`docs/cast_faction_promotion.md`](./cast_faction_promotion.md) + `docs/CHARACTERS/*.md` briefs + portraits/models via art pipeline | P7-001, P7-009 (delivered; pending canon on first briefs) | P7-013 brief batches; P2-004 follow-ons / A-track |
| Expanded factions | `characters/README.md` (15+ roster) | Promotion plan faction-candidate table; Blackheads / Ösel-Wiek candidates; Lizard Union stays intrigue cell until ADR | P7-001, P7-009 (delivered) | P4-045 Blackheads ledger stub; further P4-016+ follow-ons |
| Bestiary / folklore creatures | `assets/bestiary/README.md` | CANON + fauna/folklore content; new 3D where needed | P7-001, P7-008 | art + content rows |

## Art rule (explicit)

| Allowed | Not allowed |
|---|---|
| Use legacy portraits, pixel GIFs, and old HUD frames as mood/silhouette reference | Ship legacy isometric/pixel character sheets or NATURAL HUD as production runtime assets |
| Author new GLBs on the shared rig (ADR 0007 / 0016) | Reactivate the pixel-frame animation pipeline as the character source of truth |
| Author new UI for meters, aspects, and spell forging under the art bible | Copy superseded `assets/UI/character-hud` element icons into the shipped HUD without a named art task |

## Reconciliation rules

1. Every named historical claim needs a confidence label in `docs/CANON.md`.
2. Every promoted NPC needs a `docs/CHARACTERS/` brief before quest content references them as active cast.
3. Living City meters must state how they interact with the existing per-faction ledger (complement, drive, or replace specific ledger displays) - no silent dual bookkeeping.
4. Magic must remain deterministic and offline-authored (ADR 0003). No runtime LLM spell invention.
5. Tower-capture strategic loops, party control, army/fleet sims, open world, and other-city campaigns stay out unless a future ADR explicitly reinstates them.
6. Slice quest **P4-007 Root and Ember** stays valid as ambiguous folklore content; later magic systems may add literal branches without invalidating that ship.

## Maintainer decisions recorded

| Date | Decision |
|---|---|
| 2026-07-29 | Reintroduce Legacy Design & Research Material into the plan (characters, history, magic, systems). |
| 2026-07-29 | 2D/pixel sprites are inspiration only; new models required. |
| 2026-07-29 | Do not call sub-agents for this planning pass; commit when documentation lands. |
| 2026-07-31 | P7-004: Hope/Fear are independent `living_city.*` meters that complement `record_faction_event`; Balance of Power aggregate, tower-majority victory, and NPC-allegiance sums stay rejected. |
| 2026-07-31 | P7-008: Folded labelled beats from HISTORY/TIMELINE/STORY into CANON (Padise, Saaremaa arc, Pskov Otepää colour, forced-forge Act 3). Rejected Chaos meter, Act 1-as-1342, wife/daughter hostage, and Pärnu as Sõjamäe rewrite. Plague 1351 remains non-canon. |
| 2026-07-31 | P7-007: Mini-game pass in `docs/MINI_GAMES.md`. Naval/castle-building deferred without new ADR. Slice/A1 shortlist: Market Haggling, Smuggling Run, Tavern Brawling. Ritual Chanting and Herbalism deferred to magic/crafting rows. |
| 2026-07-31 | P7-009: Cast/faction promotion plan in `docs/cast_faction_promotion.md` with 18 promote-first NPCs and candidates beyond the eight launch factions. First briefs: Old Toomas, Martin of the Cloaks, Konrad Preen, Lembit Helme. Lizard Union remains intrigue cell, not a ninth launch ledger, until a later ADR. 2D art stays inspiration only. |
