# ADR 0017: Reintroduce legacy design systems into the campaign plan

- **Status:** Accepted (maintainer-directed, 2026-07-29)
- **Amends:** [ADR 0008](0008-three-act-campaign-and-faction-scope.md) scope exclusions for Living City meters, NATURAL aspects, combinatorial magic, and the seven-character hard cast budget
- **Does not supersede:** ADR 0003 (no runtime LLM), ADR 0007 / 0015 / 0016 (presentation and character fidelity), MVP-first delivery order (demo → slice → Act 1 → Act 2 → Act 3)

## Context

[ADR 0008](0008-three-act-campaign-and-faction-scope.md) widened the campaign to three acts and eight factions while deliberately excluding large pieces of the original vision: Living City Hope/Fear meters, NPC-allegiance arithmetic, NATURAL aspect progression, combinatorial pagan/Christian magic, Ego-as-NPC psyche play, and the wider `characters/` roster. Those materials remain in the repository under README **Legacy Design & Research Material**, marked `superseded` or `archive`.

The maintainer has directed that this legacy material return to the **game plan** - characters, history, magic, and related systems - while treating legacy 2D/pixel sprites and HUD art as inspiration only. Production characters and UI must use the current shared-rig / art-bible pipeline (new models, not a return to the pixel-frame asset pipeline).

## Decision

1. **Legacy systems are in campaign scope again**, delivered through verifiable `TODO.md` track **P7** and act-gated implementation tasks. Individual seeds still require reconciliation into active docs (`docs/CANON.md`, `docs/CHARACTERS/`, system design docs) before code lands.

2. **Reintroduced pillars** (sources listed in README Legacy Design & Research Material):
   - **Magic:** dual schools (pagan combinatorial elements and Christian divine rites) with the smith's hammer as conduit (`character/MAGIC-ELEMENTS.md`, `PAGAN-MAGIC.md`, `CHRISTIAN-MAGIC.md`).
   - **NATURAL + Psyche:** seven-aspect progression, psyche states, and an explorable Hingepuu inner world (`character/BUILD.md`, `PSYCHE.md`).
   - **Living City:** Hope / Fear (and related city-pressure) meters plus district and NPC reaction layers (`docs/GAMEPLAY.md`, `docs/GAME-PILLARS.md`), reconciled with the existing faction ledger rather than silently deleting it.
   - **Characters and factions:** promote named figures from [`characters/`](../../characters/README.md) into `docs/CHARACTERS/` briefs; expand beyond the seven-core hard budget through act-gated casts; evaluate bishoprics, Blackheads, Lizard Union, Lithuania, and Golden Horde for playable or semi-playable quest lines.
   - **History and story:** fold usable beats from `history/HISTORY.md`, `history/TIMELINE.md`, and `story/STORY.md` into `docs/CANON.md` with confidence labels.
   - **Supporting systems:** combat depth from `character/COMBAT.md`; night mission richness from `docs/GAMEPLAY-NIGHT.md`; quest seeds from `QUESTS.md` / `docs/IDEAS_RESEARCH.md`; selected mini-games from `docs/MINI_GAMES.md` after a priority pass (not a blanket reinstate of naval/castle-building sims).

3. **Art rule:** legacy 2D sprites, pixel idle GIFs, and old NATURAL/element HUD graphics are **reference and mood boards only**. Runtime characters stay on the shared rig and fidelity tiers (ADR 0007 / 0016). New magic/NATURAL/Living City UI must be authored for the current presentation, not restored from superseded HUD assets.

4. **Delivery order is unchanged.** No P7 implementation task may pull ahead of vertical-slice MVP gates. Design and canon reconciliation may proceed in parallel with P2/P4.

5. **Still excluded** (unless a later ADR names them):
   - seamless open world or playable full campaigns in Riga, Dorpat, or other cities;
   - runtime LLM, procedural quests, or free-text NPC chat;
   - party control and army/fleet battle simulation;
   - the non-canon 1351 plague epilogue;
   - restoring the pixel-frame animation pipeline as production art.

## Equivalent scope accounting (per AGENTS.md scope-change rule)

- **Reinstated:** Living City meters and allegiance-pressure design; NATURAL aspects and Hingepuu psyche play; combinatorial magic and divine rites; expanded character/faction casts from the legacy roster; richer history/story seed reactivation; selected mini-game and night-system seeds.
- **Removed / deferred as the offset:**
  - the ADR 0008 product promise that folklore stays rare/ambiguous with **no** spell system;
  - the hard **seven-character** first-campaign cast ceiling (seven remain the slice MVP core; wider casts become planned production);
  - the hard ban on Hope/Fear-style city meters (ledger remains, meters return beside or through a reconciliation design);
  - the "no more than three forge techniques" ceiling as the long-term combat/magic budget (slice may keep three techniques until magic systems land);
  - continued treatment of bishopric and fringe factions as permanent background-only (they become candidates for act-gated lines).

## Alternatives considered

- **Keep ADR 0008 exclusions; cherry-pick only characters.** Rejected by maintainer direction: magic and systems must return, not only cast names.
- **Implement full legacy immediately ahead of the slice.** Rejected: violates MVP-first delivery and explodes the verification surface before the forge loop is proven.
- **Restore pixel sprites as production characters.** Rejected: presentation ADRs and art bible require new shared-rig models; sprites stay inspiration.

## Consequences

- README.md, AGENTS.md, and `docs/ROADMAP.md` sync to this ADR; `TODO.md` gains a **P7** track.
- [`docs/LEGACY_REINTRODUCTION.md`](../LEGACY_REINTRODUCTION.md) is the working inventory of legacy sources → planned systems → TODO IDs.
- Legacy markdown headers flip from permanent `superseded` exclusion to **reactivating via ADR 0017** while remaining non-runtime until reconciliation tasks close.
- P4-007 Root and Ember (ambiguous folklore, no literal magic confirmation) stays shipped slice content; later magic tasks may extend belief branches without rewriting that quest's historical verify line.
- Active-doc and canon reports must list this ADR; agents must not implement magic/NATURAL/Living City runtime until the matching P7 design row is done and an implementation row names allowed files.
