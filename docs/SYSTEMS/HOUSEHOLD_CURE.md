# Household cure: patients, families and the doctor of souls

Status: planned ([ADR 0052](../adr/0052-healer-apprentice-and-family-cure-loop.md), accepted 2026-10-16). Only the New Game opening at the Holy Spirit almshouse is built; everything below the opening is a design contract.

Scope: the hero's core loop as a healer's apprentice: patients, symptoms, the household behind the illness, the decisive spirit duel, and the remembered outcome, including the dark path. Out of scope: a disease simulation, randomised illnesses, an apothecary shop (there is none in 1343 Reval), an actual plague outbreak, and a single good/evil meter.

## The loop

1. **Patient.** Someone is brought to the Holy Spirit almshouse, sent by Matron Gertrud or Brother Tidemann, or found in the street.
2. **Symptoms.** The body shows authored symptoms (fever, a wound that will not close, a child who will not eat). Spirit sight ([`SPIRIT_SIGHT.md`](./SPIRIT_SIGHT.md)) shows the cause as a mark on the patient's soul lights that points into the household: grief, debt, a feud, a hidden sin, fear.
3. **Household.** The hero visits the family, observes their quarrels as duels ([`SPIRIT_DIALOGUE.md`](./SPIRIT_DIALOGUE.md) observation mode), and finds who holds the cause.
4. **Duel.** He fights the decisive conversation. Healing moves (soothe, confess, reconcile) are authored on the existing move tags.
5. **Remedy.** A physical remedy (Kalev's iron charm, Tidemann's herbs, Aita's ale) only holds when the household is mended.
6. **Outcome.** Recorded per household and per person in `GameState`: mended, partly mended, broken, or poisoned.

## The dark path

The same knowledge turned against people. The hero can open wounds instead of closing them, set relatives against each other, sell bedside secrets to factions, give false cures, poison, and feed the fever of grievance toward the uprising. It is a full route, rewarded with leverage, coin and faction favour, and paid for in trust, households and guilt (per school, see [`SPIRIT_DIALOGUE.md`](./SPIRIT_DIALOGUE.md#guilt-implemented-sd-03)). There is no light/dark meter.

## Plague and war

Katk, the Plague walking as a person (`folklore`), is a spirit-world shadow only the hero sees approaching Reval. Rebellion is his brother. Mended households push the shadow back; broken ones draw it and the fever of war closer. No outbreak happens in the campaign.

## Teachers

- **Kalev** (smith, folk healer): iron charms, forge water, the *origin of iron* charm over iron wounds, iron at thresholds against spirits.
- **Brother Tidemann** (infirmarian, St Catherine's): herbs from the garth beds, Latin remedies, the rites for the sick and dying, Latin/German comprehension.
- **The almshouse**: patients, and the matron's practical care.

## Built so far

- The New Game opening at the Holy Spirit almshouse sick-room: the porter duel, the wounded watchman Lambert calmed in spirit sight, and Kalev speaking the iron charm ([`SPIRIT_DIALOGUE.md`](./SPIRIT_DIALOGUE.md)).

## Limits

- No patient, symptom or household-outcome data yet; no schema. The quest template, the symptom/cause schema and the household outcome record each need a task.
- Older Act 1 quests still run forge commissions ([`QUESTS.md`](./QUESTS.md)) until they are reworked.
