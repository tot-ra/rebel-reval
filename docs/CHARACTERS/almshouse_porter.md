# Porter Hanß

**Confidence label:** `invented` (the almshouse at the Holy Spirit parish is `plausible composite`; the parish and a priest in 1316 are `attested`, see [`CANON.md`](../CANON.md))
**Role:** Porter of the almshouse; opponent of the first spirit duel in New Game ([R-1872](../SYSTEMS/SPIRIT_DIALOGUE.md#new-game-duel-in-the-smithy-r-1872))
**Stable ID:** `char.almshouse_porter` ([`content/prologue/character.almshouse_porter.json`](../../content/prologue/character.almshouse_porter.json))
**Pronunciation:** HAHNSS

## Visual Description
- **Clothes:** Undyed or russet wool tunic to the knee, worn hood, hose and turnshoes; a leather belt carrying the almshouse keys (the cold-store key is rusted). In game he wears a crowd body, no bespoke model (`invented` presentation).
- **Age:** About forty to fifty (`invented`).
- **Hair:** Short, greying, cropped close (`invented`).
- **Physical Build:** Heavy-handed and broad, used to carrying sacks and shutting doors (`invented`).

## Motivations & Core
- **Want:** Be obeyed; keep the stores locked.
- **Fear:** Losing his small authority.
- **Contradiction:** He guards the bread for the house and sells some to the market.
- **Secret or withheld fact:** He sells a share of the grain. The rusted key is the spirit image of that secret.

## History (Biography)
*All `invented`.* A townsman of no trade who got the almshouse door and its keys as a living. The keys are the only authority he has, and he guards them harder than the bread behind them. In a lean spring he has been selling part of the barley and the loaves; the matron suspects it and the children feel it in the gruel.

In the prologue the orphan boy runs from the almshouse to Kalev's smithy with a loaf and the cold-store key. Hanß bursts in after him and accuses him of theft. The boy sees the quarrel as a spirit duel by the hearth (`dialogue.prologue.porter_confrontation`, topic `rusted_key`: key, place, bread, orphan, hunger). Kalev then walks in and takes the boy as his apprentice; the porter leaves and keeps his post.

## Ties & Relationships
- **Allies:** None of his own; he answers to the parish and the reeve who audits the house at Michaelmas.
- **Enemies:** The orphans he calls "little thieves"; anyone who counts his keys.
- **Initial View of the Main Player (the Apprentice):** A thief and a liar who gets the rod ("Liars get the rod"). He does not know the boy can see what he fears.
- **[Matron Gertrud](./almshouse_matron.md):** She runs the house, he keeps its doors. She accuses him of the missing barley; he deflects onto rats and her "little thieves" and yields only when she names the reeve (`dialogue.prologue.almshouse_quarrel`).
- **[Kalev](./kalev.md):** The smith whose roof the duel happens under. After the duel Kalev remarks on how Hanß left, depending on the ending.

## Daily Routines
*`invented`.* Sleeps in the porter's room by the almshouse gate; opens and locks the doors and the cold store, counts the sacks, receives the council's bread, carries the rod. Market trips are where the missing grain goes.

## Voice
Gruff and suspicious. Short commands and threats. Diction of keys, locks, counts, and the rod: "Count your own mouths before you count my keys." "Liars get the rod. Say it again, and look at me!" When broken he turns to pleading and God.

## Possible Quest Lines & Outcomes
- **Quest Title:** The first duel (prologue, implemented R-1872).
- **Quest Objectives:**
  - Answer his accusation with word spells (Fireball, Iron Skin, Earth Tremor) or shove him away.
  - Bring his pressure to zero before the boy's composure runs out.
- **Rewards:** Kalev takes the boy as his apprentice (`flag.prologue.apprenticed`) in every ending.
- **Arc:** Accuser -> Exposed -> Keeps his post.
- **Endings:** Each sets its flag; in every case he keeps his post (card `outcomes.end`).
  - **Spared** (`flag.prologue.spared_porter`): he gives the heel of the loaf to the little one and asks the boy to keep quiet.
  - **Broken** (`flag.prologue.broke_porter`): he gives up the loaf and the key and begs the boy to stop looking at him; Kalev warns that "words cut too".
  - **Punished** (`flag.prologue.punished_by_porter`): the boy says nothing and takes the rod on his hand.
  - **Struck** (`flag.prologue.struck_porter`): the boy shoves him; he calls the watch, and the blow is recorded as guilt.

Later appearances (the grain sale exposed, the reeve's audit) are not designed and have no task.

---

*Sources: [`content/prologue/`](../../content/prologue/README.md), [`SPIRIT_DIALOGUE.md`](../SYSTEMS/SPIRIT_DIALOGUE.md). Content records stay `canon_status: draft`.*
