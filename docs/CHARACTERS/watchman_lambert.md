# Lambert of the watch

**Confidence label:** `invented` (a burgher town watch armed with spears is `plausible composite`; the Holy Spirit almshouse is `attested`, its use as a hospice `plausible composite`, see [ADR 0052](../adr/0052-healer-apprentice-and-family-cure-loop.md))
**Role:** Town watchman; the wounded patient of the New Game opening ([SPIRIT_DIALOGUE.md](../SYSTEMS/SPIRIT_DIALOGUE.md#new-game-duel-in-the-smithy-r-1872))
**Stable ID:** `char.watchman_lambert` ([`content/prologue/character.watchman_lambert.json`](../../content/prologue/character.watchman_lambert.json))
**Pronunciation:** LAHM-bert

## Visual Description
- **Clothes:** Quilted gambeson over a wool tunic, hose and boots; on duty a kettle hat and a spear. In the opening he lies bare-headed and without the spear; his phantom wears the full kit. In game he wears the shared watchman crowd body (`watchman.tscn`), no bespoke model (`invented` presentation).
- **Age:** About thirty (`invented`).
- **Hair:** Short, mid-brown (`invented`).
- **Physical Build:** Ordinary townsman's build; a broken spearhead in his left side (`invented`).

## Motivations & Core
- **Want:** To live through the night and never stand that watch again.
- **Fear:** That everyone will know he ran.
- **Contradiction:** He boasts of the watch's courage and fled the first real fight he saw.
- **Secret or withheld fact:** His comrade Tönnies called for him in the dark, and he ran instead of turning back.

## History (Biography)
*All `invented`.* A craftsman's son who took a paid place on the town watch. On the opening evening he and Tönnies met armed men in the dark; Tönnies fell, Lambert ran and was struck from behind. The spearhead broke off in his side, and the watch carried him to the Holy Spirit almshouse at dusk. The socket bears Kalev's maker's mark, which ties the wound to the forge and opens the later maker's-mark thread (`flag.prologue.saw_makers_mark`).

## Ties & Relationships
- **Allies:** The town watch; Tönnies (dead, `invented`).
- **Enemies:** The unknown men who carried a spear from Kalev's forge.
- **Initial View of the Main Player (the Apprentice):** A boy who looks at him "like that", at the shame no one else sees. Calmed, he takes the boy's hand; frightened, he screams at him to get away.
- **[Kalev](./kalev.md):** The smith whose mark is on the iron in his side, and who draws it out with the origin-of-iron charm.
- **[Matron Gertrud](./almshouse_matron.md):** Takes him in and sends for Kalev.

## Daily Routines
*`invented`.* None after the opening: he stays on the almshouse sickbed. A routine on the watch is not designed.

## Voice
Frightened, feverish, ashamed. Short broken sentences about the dark, the watch, Tönnies and the cold: "Do not touch it! If they pull it out I bleed like Tönnies." "Say it. Say I ran!"

## Possible Quest Lines & Outcomes
- **Quest Title:** The calming duel (prologue, implemented with ADR 0052).
- **Quest Objectives:**
  - Meet his fear as a phantom in spirit sight (`dialogue.prologue.lambert_fear`, topic `the_flight`: comrade, flight, wound, night, home).
  - Answer it gently (love, faith, duty, a steady defence) rather than shame him.
- **Rewards:** Kalev notices the boy's sight and takes him in (`flag.prologue.apprenticed`) in every ending.
- **Arc:** Frightened patient -> calmed or broken -> survivor.
- **Endings:** In both he survives the night (card `outcomes.end`).
  - **Calmed** (`flag.prologue.lambert_calmed`): "Hold my hand, then. I will lie still." Kalev finds him quiet.
  - **Frightened** (`flag.prologue.lambert_frightened`): he screams at the boy to get the iron out; Kalev hears it from the lane.

Later appearances (testimony about the men with the marked spear, the watch's inquiry) are not designed and have no task.

---

*Sources: [`content/prologue/`](../../content/prologue/README.md), [`SPIRIT_DIALOGUE.md`](../SYSTEMS/SPIRIT_DIALOGUE.md). Content records stay `canon_status: draft`.*
