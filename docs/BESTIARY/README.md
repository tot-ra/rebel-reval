# Bestiary roster

Status: planned (task **R-1578**, epic **R-1577**). The feature page is [`docs/SYSTEMS/BESTIARY.md`](../SYSTEMS/BESTIARY.md); the card format is [`TEMPLATE.md`](./TEMPLATE.md). This page is the one authoritative list of who the apprentice can meet and fight, split by combat layer ([ADR 0033](../adr/0033-teen-protagonist-and-spirit-dialogue-combat.md)). It replaces the creature list in the archived [`assets/bestiary/README.md`](../../assets/bestiary/README.md).

## Layers, tiers, confidence

| Layer | Meaning |
|---|---|
| `spirit` | Folklore being. Met in the spirit duel; visible only to the clairvoyant apprentice. |
| `physical` | Humans and animals. Met in physical combat, with per-school guilt. |
| `hybrid` | A human (or made thing) that is fought physically and also shows in the spirit layer. |
| `rejected` | Wrong region or period, or a duplicate. Kept in the table so nobody re-proposes it without a reason. |

Tiers: `slice` (vertical slice), `act1`, `act2`, `act3`, `backlog` (kept, not scheduled). Rejected rows carry tier `-`. Confidence labels follow [`CANON.md`](../CANON.md): folklore beings are `folklore`, human adversaries are `invented` on `attested` city and road conditions.

## Decisions

- **Estonian core is kept.** The Slavic and Scandinavian beings in the legacy README came from a generic mythology sweep, not from Reval.
- **Slavic beings only through Pskov/Novgorod contact:** the Russian merchant yard and the Pskov-Novgorod faction justify a Domovoy and a Vodyanoy as *variants* of the Estonian house spirit and water father. Rusalka, Likho, Upyr, Poludnitsa, Striga, Zmey and Psoglav have no such contact and are rejected or folded into an Estonian equivalent.
- **Scandinavian beings only through Swedish coastal settlers** (Ösel, the Viru coast): the Myling survives as the Swedish name for the murdered-child ghost. Draugr, Huldra, Troll, Jötunn and Lindworm are rejected.
- **Leshy is the Slavic import of Metsavana / Metsik** ([`estonian_folklore.md`](../lore/estonian_folklore.md) 4a). One entry, `bst.metsavana`, keeps the legacy card and art.
- **Kratt, Tulihänd and Puuk share one folk basis** (the devil-bought wealth bringer). They stay three entries because the in-game roles differ: a built guardian, a night omen, a thieving familiar.
- **Archive images were matched by viewing them** (R-1597). Images are pixel-art sprites; ones that fit no kept creature are left unlisted. Image-19 (a frog in water) is the Vodyanoy; the Domovoy has no archive art.

## Roster

Card column: a link once the card exists, `planned` before. Images are numbers in `archive/2d_sprites_inspiration/assets/bestiary/` (`image-N.png`) unless a name or a `bandits:` prefix is given (`bandits:` is `.../assets/bandits/`).

| ID | Name | Layer | Tier | Habitat | Factions | Basis | Images | Card | Reasoning |
|---|---|---|---|---|---|---|---|---|---|
| `bst.kratt` | Kratt | hybrid | act1 | hinterland farmsteads, rebel caches | cult_metsik | folklore | kratt.png | planned | A built guardian: fought physically, but its soul is read in the spirit layer. Legacy card exists. |
| `bst.puuk` | Puuk | spirit | act1 | Lower Town lofts, harbour stores | - | folklore | puuk.png | planned | Thieving familiar; fits the commission loop (stolen goods, missing grain). Legacy card exists. |
| `bst.pohja_konn` | Põhja Konn | spirit | act2 | Kanavere bog | - | folklore | konn.png | planned | Title tale of Kreutzwald; the bog battlefield is its habitat. Boss-scale spirit duel. Legacy card exists. |
| `bst.metsavana` | Metsavana (Metsik, Leshy) | spirit | act1 | sacred grove, forest edge | cult_metsik | folklore | leshy2.png, image-1 | planned | Owner-spirit of the forest; the Metsik cult's patron. Absorbs the Slavic Leshy. Legacy card exists. |
| `bst.nakk` | Näkk | spirit | act1 | rivers, mill ponds, Ülemiste | - | folklore | image-3, image-4, image-5, image-6 | planned | Shapeshifting drowner; singing frees a victim, which suits a non-violent resolution. |
| `bst.luupainaja` | Luupainaja | spirit | slice | the sleeper's room, almshouse, forge loft | - | folklore | image-7 | planned | The mare on the chest; blocked by iron in the doorway. Natural fit for the first night after the prologue. |
| `bst.kulmking` | Külmking | spirit | act1 | winter roads, the unbaptized dead | - | folklore | image-8 | planned | Cold spirit of the unquiet dead; tied to the Church burial theme. |
| `bst.kodukaija` | Kodukäija | spirit | slice | the dead person's house | church | folklore | image-2, image-9 | planned | The dead who will not stay buried; laid to rest by ritual, not force. Absorbs Upyr. Core spirit-duel teacher. |
| `bst.tulihand` | Tulihänd | spirit | act1 | night sky over farms, Harju hinterland | - | folklore | image-10 | planned | Fire omen of a neighbour trafficking with the devil; a signal, rarely a fight. |
| `bst.maa_alused` | Maa-alused | spirit | act2 | undisturbed ground, building plots, tunnels | - | folklore | image-11 | planned | Underground folk; illness from disturbed ground. Quest hook: building works near the walls. |
| `bst.hiid` | Hiid | spirit | act3 | boulder fields, hillforts | harju_kings | folklore | image-12, image-13, image-14 | planned | Kin of Kalevipoeg; sacred sites in the hinterland. Absorbs Troll as the only giant. |
| `bst.libahunt` | Libahunt | hybrid | act2 | forests, Harju wilds | - | folklore | image-15, image-16, image-17 | planned | A cursed person: a physical wolf fight with guilt, and a person in the spirit layer. Silver-only rule from the legacy README is dropped (not Estonian). |
| `bst.vanapagan` | Vanapagan | spirit | act3 | under monasteries, cult rites | cult_metsik, church | folklore | image-18 | planned | The Old Devil; source of the cultists' bargains. Act 3 spirit boss. |
| `bst.myling` | Myling (Näkiline) | spirit | act2 | Ösel and Viru coast, Swedish settlers | - | folklore | image-33 | planned | Swedish name for the murdered-child ghost; kept because of the Swedish coastal settlers. Estonian equivalent: Näkiline. |
| `bst.katk` | Katk | spirit | act2 | roads, river crossings | - | folklore | - | planned | Plague as a traveller asking to be ferried. A rumour and omen in 1343, not an outbreak. New from `estonian_folklore.md` 4b. |
| `bst.majahaldjas` | Majahaldjas | spirit | slice | the smithy home, farmsteads | - | folklore | - | planned | House guardian fed the first of every meal; a wronged one brings ruin. Fits the smithy home loop. New from 4b. |
| `bst.vetevana` | Vetevana | spirit | act1 | harbour, fishing coast | vitalienbruder | folklore | - | planned | Old man of the waters; sailors bargain with him. Harbour and Seamen's Inn content. New from 4b. |
| `bst.tulukesed` | Tulukesed (grave-lights) | spirit | act1 | old graves, buried caches | black_cloaks | folklore | - | planned | Lights over buried treasure; a night-exploration lure toward rebel caches. New from 4b. |
| `bst.marras` | Marras (omen-double) | spirit | act2 | Sõjamäe, execution sites | harju_kings | folklore | - | planned | A person or funeral seen shortly before the real death; foreshadows the Four Kings. New from 4b. |
| `bst.domovoi` | Domovoy | spirit | backlog | Russian merchant yard | pskov_novgorod | folklore | - | planned | Pskov variant of the house spirit; kept only as that variant. |
| `bst.vodyanoy` | Vodyanoy | spirit | backlog | Pskov-side water, mill ponds | pskov_novgorod | folklore | image-19 | planned | Pskov variant of the water father; kept only as that variant. |
| `bst.noid` | Nõid (cunning-folk) | hybrid | act1 | villages, Metsik healers | cult_metsik | folklore | image-25 | planned | The wise one, feared and needed (Ellen Luik is the model). Absorbs Striga: vial throwing and healing both survive. |
| `bst.rehepapp` | Rehepapp | hybrid | backlog | estate barns | - | folklore | - | planned | Trickster who robs the German lord with his kratt. Likely an NPC first. New from 4b. |
| `bst.street_thug` | Street thug | physical | slice | Lower Town alleys | - | invented | bandits:thug.png, bandits:thug2.png, image-53 | planned | Club or dagger, throws sand; the base of the physical archetype. |
| `bst.saboteur` | Saboteur | physical | act1 | Lower Town, harbour | black_cloaks | invented | image-55, image-56 | planned | Smoke and caltrops; the Black Cloaks' street fighter. |
| `bst.brute` | Brute | physical | act1 | taverns, dock gangs | - | invented | image-45, image-54 | planned | Shove attacks. The legacy "minor supernatural strength" is dropped: he is just strong. |
| `bst.road_bandit` | Road bandit | physical | act1 | hinterland roads | - | invented | bandits:thug3.png, bandits:thug4.png, image-57, image-58, image-51 | planned | Ambush on the Harju roads; flees or surrenders when outnumbered. |
| `bst.black_cloak_fighter` | Black Cloak fighter | physical | act2 | Lower Town, sewers, rooftops | black_cloaks | invented | image-48, image-52 | planned | Urban rebel using the city as a weapon; guilt-sensitive because he is a potential ally. |
| `bst.spirit_caller` | Spirit-caller | hybrid | act2 | hinterland groves | cult_metsik | invented | image-47 | planned | Shaman with a ranged curse; the human anchor for a summoned spirit. Physical wolves are real wolves; spectral ones belong to the spirit layer. |
| `bst.vanapagan_cultist` | Vanapagan cultist | hybrid | act2 | monastery cellars, cult rites | cult_metsik, church | invented | image-46, image-49, image-50 | planned | A human who has traded his soul; fought physically, seen darker in the spirit layer. Absorbs the Rock-Thrower. |
| `bst.wolf` | Wolf | physical | act1 | forests, winter roads | - | attested | - | planned | Real predator of the Harju woods. New; no archive art. |
| `bst.bear` | Bear | physical | backlog | deep forest | - | attested | - | planned | Real predator; rare and not scheduled. New; no archive art. |
| `bst.boar` | Wild boar | physical | backlog | hinterland woods | - | attested | - | planned | Real hunting animal. New; no archive art. |
| `bst.rusalka` | Rusalka | rejected | - | - | - | - | - | - | Duplicate of Näkk; no Pskov contact reason beyond the water father. |
| `bst.likho` | Likho | rejected | - | - | - | - | image-21 | - | Abstract bad-luck hag with no Estonian or Pskov-quarter basis. |
| `bst.upyr` | Upyr | rejected | - | - | - | - | image-20 | - | Duplicate of Kodukäija (the dead who return). |
| `bst.zmey` | Zmey | rejected | - | - | - | - | image-22 | - | Multi-headed dragon: no Estonian or Livonian folk basis and breaks the grounded tone. |
| `bst.psoglav` | Psoglav | rejected | - | - | - | - | image-23 | - | Balkan dog-headed demon; no contact with Reval. |
| `bst.poludnitsa` | Poludnitsa | rejected | - | - | - | - | image-24 | - | Slavic midday spirit; no attestation here. The hat-shuriken and scythe moves do not fit a 1343 setting. |
| `bst.draugr` | Draugr | rejected | - | - | - | - | image-26, image-27, image-28 | - | Viking tomb guardian; Swedish settlers of 1343 were Christian and have no barrow tradition. |
| `bst.huldra` | Huldra | rejected | - | - | - | - | image-29 | - | Norwegian forest woman; Metsavana covers the forest owner. |
| `bst.troll` | Troll | rejected | - | - | - | - | image-30, image-31, image-32 | - | Scandinavian giant; Hiid covers the giant. |
| `bst.jotunn` | Jötunn | rejected | - | - | - | - | image-34 | - | Norse myth giant; no reason written to keep it beside Hiid. |
| `bst.lindworm` | Lindworm | rejected | - | - | - | - | image-35 | - | Dragon again; Põhja Konn already is the Estonian dragon-frog. |
| `bst.leshy` | Leshy | rejected | - | - | - | - | leshy2.png | - | Merged into `bst.metsavana`; kept as an alias, not a second creature. |

## Rules

- A new creature needs a row here before a card. Rejected rows are reopened only by writing a reason in this table.
- Card files live in [`cards/`](./cards/) as `<slug>.md` where `bst.<slug>` is the ID. Check them with `python3 tools/validate_bestiary_cards.py`.
- Spirit-layer entries carry no guilt; physical entries and the physical half of a hybrid carry per-school guilt ([ADR 0033](../adr/0033-teen-protagonist-and-spirit-dialogue-combat.md)).
- Writing the cards is [BST-2a/2b/3](../SYSTEMS/BESTIARY.md#work-plan), not this page.
