# Matron Gertrud

**Confidence label:** `invented` (the almshouse at the Holy Spirit parish is `plausible composite`; the parish and a priest in 1316 are `attested`, see [`CANON.md`](../CANON.md))
**Role:** Matron of the almshouse where the Apprentice grew up
**Stable ID:** `char.almshouse_matron` ([`content/prologue/character.almshouse_matron.json`](../../content/prologue/character.almshouse_matron.json))
**Pronunciation:** GAIR-trood

## Visual Description
- **Clothes:** Plain dark wool kirtle with a full linen apron, white linen wimple and veil, a household purse and tally sticks at the belt (`invented` on period dress).
- **Age:** About fifty (`invented`).
- **Hair:** Grey, kept under the wimple (`invented`).
- **Physical Build:** Spare and upright, red work-worn hands (`invented`).

## Motivations & Core
- **Want:** Keep the children fed through a lean spring.
- **Fear:** Being blamed when a child dies.
- **Contradiction:** She is kind in private and harsh in front of the porter.
- **Secret or withheld fact:** She waters the gruel to stretch the grain.

## History (Biography)
*All `invented`.* A widow placed in charge of the almshouse at the Holy Spirit parish, she keeps the house accounts and answers to the reeve at Michaelmas. This spring the barley runs short. She suspects Porter Hanß is selling it and confronts him, while she quietly waters the gruel herself so the stores last. The orphan boy who later becomes Kalev's apprentice grew up in her house.

## Ties & Relationships
- **Allies:** The parish and the reeve, as long as the accounts balance.
- **Enemies:** None declared; she suspects [Porter Hanß](./almshouse_porter.md).
- **Initial View of the Main Player (the Apprentice):** One of her children, odd and staring; she scolds in public and is softer in private. In the porter duel the boy invokes her rule: "Matron said no child goes to bed hungry."
- **[Porter Hanß](./almshouse_porter.md):** She names the missing barley and the reeve's audit; he deflects, then yields bread at vespers to keep her quiet (`dialogue.prologue.almshouse_quarrel`, observation mode SD-06).

## Daily Routines
*`invented`.* Rises before the children, keeps the kitchen and the gruel, counts the bread against the council's allowance, takes the children to the Holy Spirit church for mass and vespers, and keeps the accounts by candle.

## Voice
Tired, firm, quick to scold. Diction of household accounts, bread, and penance: "Half the barley sack is gone, Hanß. The children ate gruel you could read through." "The reeve will ask at Michaelmas. Shall I tell him which rats carry keys?"

## Possible Quest Lines & Outcomes
- **Quest Title:** The almshouse quarrel (observed).
- **Quest Objectives:** Watch the matron and the porter quarrel in spirit sight and choose whom to stand with (observation mode, SD-06).
- **Rewards:** None in the current build. `dialogue.prologue.almshouse_quarrel` is no longer played by the New Game opening; it is kept for tests (`tests/godot/test_spirit_observation.gd`) and reuse.
- **Arc:** Accuser -> Keeper of her own secret.
- **Endings:** Remains in charge of the house (card `outcomes.end`). A later reckoning over the watered gruel is not designed and has no task.

---

*Sources: [`content/prologue/`](../../content/prologue/README.md), [`SPIRIT_DIALOGUE.md`](../SYSTEMS/SPIRIT_DIALOGUE.md). Content records stay `canon_status: draft`.*
