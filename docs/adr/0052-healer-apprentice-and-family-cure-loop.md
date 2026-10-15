# ADR 0052: The healer's apprentice and the family-cure loop

- **Status:** Accepted (maintainer-directed, 2026-10-16: "lets make changes"). Nothing here is runtime truth until a task verifies it.
- **Reference:** maintainer request 2026-10-16 (session): helping the blacksmith "is too similar to KCD ... focusing also too much on weaponry"; "as we are doing spiritual battles, I want more suitable profession"; "apothecary ... people come in with various diseases and you need to also investigate, visit their families to cure them ... like Christ is a doctor of the soul"; "healer sounds good in combination with smith work"; dark path "for hard core RPG guys that want to do evil".
- **Amends:** [ADR 0033](0033-teen-protagonist-and-spirit-dialogue-combat.md) decision 1 (the protagonist as a forge apprentice who works commissions) and the commission-centred core loop of [ADR 0008](0008-three-act-campaign-and-faction-scope.md).
- **Does not change:** the teen clairvoyant protagonist, dialogue-as-combat and per-school guilt (ADR 0033), spirit sight and soul lights ([ADR 0041](0041-spirit-sight-auras-and-soul-lights.md)), psychological spells ([ADR 0048](0048-psychological-spells-and-willpower-cost.md)), the ban on a single morality score, the uprising and 1346 sale as the campaign spine.

## Context

The forge apprenticeship frames the hero as a craftsman whose work is weapons. It reads as a copy of *Kingdom Come: Deliverance* and pulls the story toward weaponry, while the game's combat and magic live in the spirit world and in dialogue. A healer's work already happens where spirits are strongest: at sickbeds, wakes and quarrelling households.

Two historical limits apply:

1. **No apothecary in 1343.** The Reval council apothecary is first recorded in 1422 (see the `apothecary` music note in [`SEAMLESS_CITY.md`](../SYSTEMS/SEAMLESS_CITY.md)). By the period rule a dated-later institution is not shown.
2. **No plague in 1343.** The Black Death reaches the Baltic around 1350; the 1351 plague epilogue is archived as non-canon ([`CANON.md`](../CANON.md)).

## Decision

1. **The hero is a healer's apprentice, not a weapon-smith's.** He keeps his almshouse origin and learns healing from three places, one per tradition:
   - **Kalev, smith and folk healer.** Kalev stays the master and the forge stays the home base. His craft turns from weapons to the work a 14th-century town smith mostly did (nails, hinges, tools, horseshoes, pulled teeth, set bones) and the folk healing the Finnic tradition gives smiths: iron at thresholds and smith-forged amulets against spirits (`folklore`, wide Baltic-Finnic distribution), forge (quench) water as a cure, and the *origin of iron* charm spoken over iron wounds. The smith as spirit-warder and healer is `plausible composite` ([`belief-omens-and-healing.md`](../../history/dossiers/folklore/belief-omens-and-healing.md)). Weapons enter only through plot, as with the seized spearhead.
   - **The infirmarian of St Catherine's** (Dominican friary, attested). The hero runs errands for herbs from the garden, Latin remedies and the Christian rites for the sick. This trains the Latin/German comprehension skill.
   - **The Holy Spirit almshouse** (church 1319 and an almshouse/hospice for the sick and poor `attested`; the orphan house within it `plausible composite`; see [`churches-and-religious-houses.md`](../../history/dossiers/religion/churches-and-religious-houses.md)). This is where patients arrive and the hero's first duty.
   Drugs and spices come from merchants, who did sell them; the hero never runs an apothecary shop.
2. **Core loop: patient → symptoms → household → duel → outcome.** A patient arrives or is fetched. The body shows symptoms; spirit sight shows the cause in the household (grief, debt, a feud, a secret, guilt). The hero visits the family, observes their quarrels as duels, and fights the decisive one. The physical remedy only holds when the household is mended. The theme is *Christus medicus*, Christ as the physician of souls. Outcomes are recorded per household and per person.
3. **The dark path is the same knowledge turned against people.** The Greek *pharmakon* means both cure and poison. A healer hears every family's wounds, so the hero can also:
   - open wounds instead of closing them: set relatives against each other, break households;
   - sell bedside secrets to factions as leverage or blackmail;
   - give false cures or poison;
   - feed the fever of grievance toward the uprising.
   The dark path is a full route for players who want to do evil, not a failure state. It is powerful in the short term and costs trust, households and guilt. It is built from concrete choices recorded per household, per faction and per guilt school; there is no light/dark meter.
4. **Plague and war are brothers.** *Katk*, the Plague walking as a person (`folklore`; in 1343 rumour and omen only, no documented outbreak, per [`belief-omens-and-healing.md`](../../history/dossiers/folklore/belief-omens-and-healing.md)), is seen only by the hero as a spirit-world shadow approaching Reval. Rebellion is his brother who does arrive in 1343. Mended households push the shadow back; broken ones draw it and the fever of war closer. No outbreak happens in the campaign. *(Open: the maintainer may choose an actual outbreak in a later epilogue, which would reverse the CANON non-canon line.)*
5. **Opening.** Mart is still missing. The seized-spearhead hook moves to the sickbed: a wounded man is brought to the almshouse with a spearhead bearing Kalev's mark in the wound. The hero tends him, the man's spirit will not settle, and Kalev, called as the smith who can speak the iron charm, takes the boy in. The rejected iron and the forge ledger remain clues.

## Scope accounting

**Removed or reduced as the offset:**

- **commission ledger as the core loop** and the forged-record "you fight with what you forged" recall across acts: reduced to a few plot commissions; household outcome records take their place;
- **forge sabotage and modification of weapons** as the main lever: reduced to the plot hook and Act 1 clues;
- **weapon-making progression**: cut. The forge set and forge bay assets stay as location and props.

**Added:** a household-cure quest template (data, not a new engine), a symptom/cause schema on existing dialogue move tags, three mentor relationships, and the Katk shadow as a spirit-world presence.

## Alternatives considered

- **Council apothecary shop.** Rejected: first recorded in 1422.
- **Keeper of the dead / bell-ringer.** Kept as almshouse duties the hero may do, not as his profession.
- **Wise-woman's apprentice only.** Rejected: leaves the Christian school without a mentor and moves the hub outside the walls.
- **Keep the weapon-smith apprenticeship.** Rejected by the maintainer (too close to KCD, too much weaponry).

## Consequences

- README premise, `docs/CANON.md`, [`apprentice.md`](../CHARACTERS/apprentice.md), [`kalev.md`](../CHARACTERS/kalev.md) and the Act 1 quest outlines are rewritten through tasks once this ADR is accepted.
- New planned feature page for the household-cure loop; [`SPIRIT_DIALOGUE.md`](../SYSTEMS/SPIRIT_DIALOGUE.md) and [`QUESTS.md`](../SYSTEMS/QUESTS.md) gain links to it.
- New named characters: the friary infirmarian (and optionally an almshouse healer); both need cards and confidence labels.
- History research task: medieval Reval medicine, Dominican infirmaries, Finnic smith-healing and *Katk* belief, before any canon text.
- Stable IDs (`quest.*`, `char.kalev`, `char.apprentice`, `flag.*`) are preserved; renamed quests keep their IDs.
