# Ironhand (unnamed Vitalienbrüder captain)

**Confidence label:** `invented`
**Role:** Hireable harbour-raider captain; `faction.vitalienbruder`; harbour chaos without a naval simulation
**Promotion:** P7-009 Wave B (`char.ironhand`) · Act gate **A2** · Art tier **1** · Legacy seed inspiration only
**Content ID:** `char.ironhand`

## Decision: an unnamed invented captain, not Störtebeker
The legacy seed was titled "Ironhand Störtebeker". The historical Klaus Störtebeker lived c.1360-1401 and the name "Vitalienbrüder" belongs to the 1390s, so both are anachronistic in 1343 ([`docs/CANON.md`](../CANON.md) accepts the faction label only as a launch label; see [`cast_faction_promotion.md`](../cast_faction_promotion.md)). Therefore:
- The character is an **unnamed, invented** harbour captain. "Ironhand" is an epithet that sailors and townsfolk use; his true name is never given, and in 1343 nobody calls him Störtebeker.
- No player-facing text, icon, or dialogue may name Störtebeker or tie him to the later pirate legend. The slug and `char.ironhand` ID stay stable.
- The legacy sheet had **no painted portrait** (only small pixel placeholders), so no sheet moved. A portrait needs a new art task before the NPC gets an avatar (`char.ironhand` has `portrait: null` in the registry). Art stays within the asset freeze: a new painted portrait needs its own task naming the files.

## Visual Description
- **Clothes:** A motley collection of stolen finery over rough sea clothes (no later pirate costume).
- **Age:** Unspecified; grizzled, a veteran.
- **Hair:** Wild beard; a patch over one eye.
- **Physical Build:** A mountain of a man, covered in scars and tattoos, with a booming laugh and a fierce temper.

## Motivations & Core
- **Want:** Gold, and a harbour that lets him sell what he takes.
- **Fear:** Hanging at Reval's gallows, and losing his crew's loyalty.
- **Contradiction:** A man of his word, but his word is backed by an axe and a lust for gold.
- **Secret or withheld fact:** Whose stolen finery he wears, and who paid him to sail near Reval in the first place.

## History (Biography)
The seed gives none beyond "leads the largest band of raiders in the Baltic". Invent a short origin only when a quest needs it (for example a bankrupt merchant crew turned outlaw).

## Ties & Relationships
- **Allies:** His crew; harbour fences and smugglers.
- **Enemies:** The Reval authorities and the Hanse merchants whose ships he robs.
- **Initial View of the Main Player (Kalev):** A tradesman with iron to sell, or a witness to silence, depending on whether the player pays.
- **[Jürgen Witte](./jurgen.md):** A cargo-owner's nightmare; business may link them through hostile hire.

## Daily Routines
By the registry schedule he is at the fish landing (`poi.fish_landing`) in daytime and aboard or in hiding otherwise.

## Voice
Loud, jovial, threatening; swears by his word and his axe.

## Possible Quest Lines & Outcomes
- None scheduled. Use as a hireable harbour-chaos face and an outlaw contrast; no fleet or naval battles.
- **Arc:** Rumour -> Hireling -> Liability.
- **Endings:** Hired, betrayed, or captured.

---

*Stub status:* the legacy seed was a single paragraph; any further content is new design and needs its own task.
