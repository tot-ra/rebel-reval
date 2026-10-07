# Spirit dialogue prototype review (SD-16)

Date: 2026-10-07. Scope: tasks SD-01 .. SD-15 of the [spirit dialogue pack](../../TODO.md) under [ADR 0033](../adr/0033-teen-protagonist-and-spirit-dialogue-combat.md). Written by the implementing agent from the code and tests; it is **not** the independent second review the task asks for. The go or no-go below is a recommendation until a maintainer or a second reviewer signs it.

## What exists

| Area | Result | Entry point |
|---|---|---|
| Hero model | 15-year-old apprentice, Tier 0, modular wardrobe, player rig switched | `assets/characters/variants/apprentice.tscn` |
| Tagged dialogue | `duel` and per-node `move` in the schema, validator codes, runner accessors | [`SPIRIT_DIALOGUE.md`](../SYSTEMS/SPIRIT_DIALOGUE.md#dialogue-move-tags-implemented-sd-02) |
| Duel arena | telegraphed blows, guard, parry, dodge, replies, spells, retry from checkpoint | `SpiritDuel`, `SpiritArenaHost` |
| Observation | watch NPC duels, learn moves, side once | `SpiritObservation` |
| Hybrid combat | physical blows open per-school guilt that weakens the spirit layer | `PhysicalBlowGuilt`, `GuiltLedger` |
| Language | imagery, fragments, gated replies, always-translate setting | `DialogueLanguage` |
| Self-talk, traits, temperaments, teen moves, apprentice commissions | implemented as models and hooks | see the feature page |
| Prologue content | almshouse quarrel, first duel with three endings, Kalev scene | `content/prologue/` |

93 new Godot tests in 13 files pass. About 1,400 lines of new runtime GDScript in eight files. Unchanged by this pack but noted: the repository has pre-existing failing tests (for example `test_vertical_slice_save_matrix`, `test_bread_and_iron_cycle`, `test_character_rig` parse error); none was caused or fixed here.

## Evidence 1: authoring cost per tagged scene

- A tagged node costs one extra `move` line (kind, element, stakes). That part is cheap.
- The expensive part is design: each exchange needs an incoming move, at least two replies with different kinds, a sensible element, and a resolution. The three prologue scenes (4, 7 and 4 nodes) plus three characters took one focused pass, but only because the combat vocabulary (six kinds, six elements, four stakes) is small and the counter table is fixed.
- The validator catches missing duel declarations, undeclared stakes and unreachable resolutions, but not whether a duel is *fun* or *fair*.
- Estimate for the slice: 3 to 5 tagged key scenes are affordable. Tagging every conversation is not, and the ADR already forbids it.

## Evidence 2: balance of the hybrid combat

Numbers from the code (prototype values, not tuned in play):

| Situation | Exchanges to break a 60-pressure opponent | Open blows the hero survives (composure 100, an `attack` blow of 20) |
|---|---|---|
| No guilt, counter reply (30) | 2 | 4 |
| Guilt tier 2 in the reply's school (replies x0.7 -> 21) and every school tier 2 (blows x1.6 -> 32) | 3 | 3 |
| Guilt tier 3 in the reply's school (x0.55 -> 16.5), blows x1.6 | 4 | 3 |

- Killing an unarmed person (church 7, folk 7, civic 5) puts all three schools at tier 2 or 3, so the spirit layer needs 3 to 4 exchanges instead of 2 and the hero survives 3 open blows instead of 4. That is a strong, legible penalty; whether it is *too* strong depends on how often the story pushes the player into physical blows.
- Self-defence costs 1 church only (tier 1: replies x0.85 in church elements, blows x1.1): a small, forgiving price, as intended.
- The physical option inside a duel (the `[Shove him away]` choice) currently ends the duel at once and only sets a flag; it is **not** yet converted into guilt, so the real trade-off (a quick win versus a spirit-layer debuff) cannot be felt in play. This is the biggest gap in the evidence.
- No rite lowers guilt in content yet, so guilt only ever grows; there is no relief loop to balance against.

## Evidence 3: faction count

Each faction that appears in a duel needs authored moves, temperaments and resolutions. The ledger itself (eight factions) costs nothing extra. **Recommendation:** keep the eight-faction ledger and Living City meters, but author spirit duels for four factions first (Livonian Order, Hanseatic merchants, Black Cloaks, and the Danish Crown through Captain Henning); the other four stay background until their act. This does not change ADR 0008 scope, only the order of authoring, so it needs no new ADR; reducing the ledger itself would.

## Evidence 4: frozen tower boss code

`scripts/tower/` and three boss encounters are still validated by the Kuldjala and Rentenitorn interior-map tests and the Nunnatorn adapter. Deleting them means retiring those three interior maps, their encounters and tests together. **Recommendation:** keep the code frozen (no new work) and decide deletion when the interiors are archived; it is neither a dependency nor a cost for the spirit duel.

## Go or no-go

**Recommendation: go**, for continuing toward the slice with these conditions:

1. Wire the prologue into a running scene (the arena host and observation host are not mounted anywhere yet; nothing enters a duel in the game today).
2. Convert physical-blow choices inside duels (`flag.prologue.struck_porter`) into guilt through `PhysicalBlowGuilt`, add one absolution rite, then re-measure the balance table in play.
3. Mount Kalev as the master-smith NPC (SD-17) and apprentice the hero in play, so the secret commission methods are reachable.
4. A human plays the prologue once and judges whether telegraphed lines plus a reply wheel read as a conversation or as a minigame; this is the risk the numbers cannot answer.
5. Independent second review of this report and the ADR scope accounting.

## Open decisions for the maintainer

- Hero's name (the brief uses a working name).
- Whether to accept the four-faction authoring order above.
- Whether to keep the frozen tower code until the interiors are archived.
