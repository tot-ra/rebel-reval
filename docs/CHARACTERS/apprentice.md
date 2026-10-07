# The Apprentice (player character, working name)

**Confidence label:** `invented`
**Role:** Protagonist (per [ADR 0033](../adr/0033-teen-protagonist-and-spirit-dialogue-combat.md)); the player's character once the SD tasks land. The playable prototype still controls Kalev until then.
**Name:** not yet chosen; `char.apprentice` is the stable ID and may stay as the internal ID after the name is decided. Maintainer decision pending.

## Who he is
A 15-year-old orphan raised in an almshouse tied to the Holy Spirit parish (the parish is `attested`, a priest there in 1316; an orphan house is `plausible composite`). He is thin, watchful, and slow to speak. The master smith Kalev takes him in to fill the place of the missing apprentice [Mart](./mart.md).

## Gift and burden
He sees a spirit world that other people do not: the quarrels, shames, debts, and fears behind what people say appear to him as duels and phantoms. In game terms this is clairvoyance. Others read it as oddness: he stares, he talks to himself. The game gives it no clinical name and does not call it an illness or a superpower; it is both a gift and a cost. Estonian folklore creatures appear to him only as phantoms of fear, never in the physical world. Magic exists only in the spirit world.

## Motivations & Core
- **Want:** A place to belong, and to understand what the grown-ups are fighting about.
- **Fear:** That he is dangerous, and that what he sees is a sign something is wrong with him.
- **Contradiction:** He can read people better than anyone, yet cannot tell which side to trust. He hates violence but his body is the only weapon the physical world lets him use.
- **Secret or withheld fact:** He knows what a person fears before they speak it, and has told no one.

## Relationships
- **Kalev:** Master smith and mentor. The first adult who gives him work and a bed. The apprentice quietly alters, hides, or swaps parts of commissions, so the forged records are partly his.
- **Mart:** The missing older apprentice whose place he fills. Finding Mart is the hook of the story.
- **Aita:** Kalev's sister; the first person who treats his staring as ordinary.
- **Captain Henning, Kaja, Jürgen Witte, Ellen Luik:** the adults whose conflicts he sees as duels; see their briefs.

## Voice
Few words, concrete, literal. Notices what is not said. Understands little German or Russian at first; comprehension grows (see [`SPIRIT_DIALOGUE.md`](../SYSTEMS/SPIRIT_DIALOGUE.md)).

## Mechanics hooks
- Guilt per school when he strikes: [`SPIRIT_DIALOGUE.md`](../SYSTEMS/SPIRIT_DIALOGUE.md#guilt-implemented-sd-03).
- Double-edged traits and talking to himself: planned (SD-09, SD-15).
- Model: `assets/characters/variants/apprentice.tscn` (implemented, SD-10). No portrait yet.

## Possible outcomes
- Learns to carry the gift without being consumed by guilt.
- Becomes a feared reader of people.
- Breaks under the weight of what he sees.
- Leaves the forge and the city.
