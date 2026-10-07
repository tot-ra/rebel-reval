# The Rebel Kings' Camp (Harju command camp, eastern Harria corridor)

**Status:** planned (design proposal, not implemented) · **Scope gate:** existing prototype `loc.world_rebel_kings` · **Act(s):** 2 (hub), 3 (empty-camp aftermath only)
**Map id:** `loc.world_rebel_kings` (existing: [`content/maps/world_rebel_kings.rrmap`](../../content/maps/world_rebel_kings.rrmap), 50x28 cells, `scope=prototype`, `active=false`) · **Seasons/phases:** siege investment (late April), sortie/supply (about 9-13 May), assault (14-16 May), emptied camp (after 14 May)
**Confidence summary:** the rising, the siege, the Four Kings as an institution, the Swedish appeal `attested`; a camp in the eastern Harju corridor `plausible composite`; the exact plot, the signal hill, every named king, every shelter and the council ring `invented`.

## 1. Why a player would want to visit

- It is the Act 2 political hub: the player meets the people who decided to march, argues with them, and sees what a rising looks like from the inside - mixed, tired, proud, badly fed.
- It is the only node where the factions' arguments are visible in one place: Lembit counsels patience, Jüri wants to strike, Urmas reads omens, the fourth king doubts them all.
- It is the player's forge in the field: a camp smithy repairing scythes, spearheads and axes. Act 1 forge work (`mission.act2.recall.spearhead`) resurfaces here.
- It changes visibly across the three siege phases and is empty, ash and trampled mud afterwards - the strongest "this was a place with people" reversal in the game.
- **Signature:** an improvised settlement of low shelters, smoke columns, a cart line and a council fire under a plain standard - warm, crowded, noisy, and then silent.

## 2. History in 1343

| Claim | Label | Source | Use |
|---|---|---|---|
| St George's Night uprising, 23 April 1343; siege of Reval by rebels from Harju | `attested` | [`CANON.md`](../CANON.md), [`siege_of_reval.md`](../../wiki/events/siege_of_reval.md) | Frame |
| Four leaders ("kings") elected by the rebels; names not recorded | `attested` institution; persons `invented` | [`four_kings_act2_lore.md`](../lore/four_kings_act2_lore.md) | Cast |
| Rebel appeal to Swedish bailiffs (Turku, Viborg) | `attested` appeal; Swedish capacity limited | [`CANON.md`](../CANON.md); `history/HISTORY.md` | Swedish envoy beat |
| Chronicle host of about 10,000 | `attested` chronicle figure, rhetorical | [harju-village dossier](../../history/dossiers/hinterland/harju-village-and-manor.md) | Show hundreds, not thousands |
| Signal fire on an unnamed Harria hill | `attested` event; hill `invented` anchor | [rebel-camp dossier](../../history/dossiers/hinterland/harju-rebel-camp-and-pirita-approach-1343.md) | Do not label the camp plot as that hill |
| Viru - Iru - Pirita line as the eastern approach, 5-12 km, 1-3 h on foot | `plausible composite` | same | Smoke and glow, not a view into Reval |
| Pirita bridge or ford | `unknown`; use `crossing_status: invented_reconstruction` | same | Reversible crossing primitive only |
| Pirita convent (1407), Pirita church | NOT 1343 | same | Never show |
| Rebels renounce Christianity (chronicle topos); massacre of Germans | hostile-source `attested` | harju-village dossier | Voiced by Order and clergy, not confirmed |
| Padise monastery massacre (April) | `attested` | [`padise_monastery_massacre.md`](../../wiki/events/padise_monastery_massacre.md) | News arriving at camp |
| Order enters after invitation; field battles 11 and 14 May; Toompea leverage 16 May | `attested` | [`CANON.md`](../CANON.md) | Phase changes |
| Paide killing of the Four Kings; Act 2 places it after Sõjamäe | `attested` event; ordering `invented` framing | [`paide_castle.md`](paide_castle.md) | Kings leave the camp |

**Phases.** A (investment): crowded, loud, hopeful; supply carts, recruits, rumour of the Swedish offer. B (sortie/supply, after Kanavere): victory mood, pursuit versus consolidation argument, captured gear. C (assault, 14 May): the camp thins as the host marches; wounded return. D (after Sõjamäe): abandoned fires, scattered tents, a few wounded and women. Act 3: only a ring of ash and a standard pole.
**Do not show:** a permanent fortress, stone walls, a tower, a wooden palisade of 15th-c. style, a "royal" tent with heraldry, uniform armour, handgonnes, or a numbered army parade. Camp is not the village centre.

## 3. Landscape and layout

Biome: wet meadow and field edge in the eastern Harju corridor, trampled to mud; alder and birch strip along a drainage ditch; a low ridge to the north-east for the beacon view. April-May: cold, windy, rain showers, last frost at night.

| Zone | Cells (x,y,w,h) | Prototype id | Notes |
|---|---|---|---|
| Camp road | 3,12,44,6 | `camp_road` | Dirt spine W-E, ruts, cart traffic |
| West camp | 6,5,10,5 (+ straw 6,5,10,5) | `west_camp`, `west_camp_straw` | Harju Kings' fighting men; straw bedding |
| East camp | 34,6,10,5 | `east_camp` | Auxiliaries, wounded, Metsik helpers |
| Council fire | around 25,15 | `landmark_council_camp` | Standing council ring, cauldrons |
| Supply shelter | 20,19,8,4 | `supply_shelter` | Grain, tools, cart line |
| Muddy common | 12,18,26,5 | `muddy_common` | Overflow crowds, livestock |
| Field forge (proposed) | 29,9,5,4 | - | Camp smithy by the east road |
| Beacon ridge (proposed) | 40,1,9,5 | - | View-only slope, `invented` signal hill |
| Wet ditch strip (proposed) | 0,23,50,4 | - | Alder, reeds; spawn edge |

Landmarks (existing): `landmark_council_camp` (25,15), `landmark_west_camp` (11,11), `landmark_east_camp` (39,11). Proposed (`invented`): `landmark_signal_hill` (44,3), `landmark_field_forge` (31,10), `landmark_king_oak_ring` (24,12), `landmark_prisoner_pen` (17,20), `landmark_wounded_shed` (41,14), `landmark_standard_pole` (32,14, existing prop `field_standard`).

**Journey edges (existing, all `alignment=travel`):** `road_to_harju` (0,22) to `world_harju`; `road_to_kanavere` (46,22) to `world_kanavere`. Proposed: none. ADR 0027 keeps this node explicit travel. A journey-time clock (2-3 hours Viru-Iru-Pirita bracket, mud modifier) can colour the arrival text without a new map.

## 4. Architecture and built environment

| Type | Form | Material | State by phase | Label |
|---|---|---|---|---|
| Lean-to shelter | Pole frame with hides, sacking and brush | Poles, wool, bark, straw | A: dense; D: collapsed | `plausible composite` |
| Peasant hut cluster | Reused farm outbuildings and a requisitioned barn | Log, thatch | A-C: crowded; D: burned | `plausible composite` |
| Council ring | Four stools or stakes around a fire, plain standard on a pole | Timber | A: ceremonial; D: ashes | `invented` |
| Field forge | Portable bellows, anvil on a stump, charcoal pile, quench trough | Iron, stump, clay | A-C: in use | `plausible composite` (smith role per [arms dossier](../../history/dossiers/military/arms-and-armour-livonia-1340s.md)) |
| Wagon line | Carts in a loose arc, yoke poles, grain sacks | Oak, hemp rope | A-C | `plausible composite` |
| Cooking pits | Cauldrons on tripods, trench ovens | Iron, clay, stone | A-C | `plausible composite` |
| Beacon post | Brush pile on a log tripod, windbreak | Timber | A and one phase-B relight | `plausible composite` |
| Wounded shed | Roofed barn bay, straw rows | Log, thatch | B-D | `plausible composite` |
| Prisoner pen | Hurdles and stakes | Withy | B | `invented` |

Distinguishing rule vs other nodes: no walls, no permanent roofline; the silhouette is ragged, low, smoky and horizontal with vertical poles (standards, tripods, spears stacked in cones). Differs from Harju by its disorder (no rows, no fences) and from the Order castle at Paide by having nothing stone.

## 5. Cultures, languages, and people

| Group | Language | Dress | Religion and custom |
|---|---|---|---|
| Harju freeholders, bound tenants | North Estonian; oaths by Jüri/George, Taara as cry (`attested` Tharapita, `plausible composite` as oath) | Wool, linen, bast shoes, mix of tool-weapons; captured cap or mail as loot | Baptized; omens, charms, a priest or two |
| Vassal clients and Estonian knights (2 % of the vassal class) | Estonian and Middle Low German | Better wool, mail shirt, riding boots | Latin rite; the fourth king's circle |
| Manor labourers, smiths, millers | Estonian | Leather aprons, soot | Craft customs, iron lore |
| Metsik helpers and seers | Estonian; charm-song | Undyed wool, rowan, bone/feather trim on Urmas (legacy visual) | Folk rites, `folklore` |
| Women who followed the host | Estonian | Layers, head wraps | Cooking, mending, nursing |
| Swedish/Finnish envoy | Swedish and Finnish; interpreter | Good cloak, fur cap, boat boots | Latin rite |
| Captive Order brother | Middle Low German, Latin | Torn white mantle, black cross | Order rule |
| Black Cloaks liaison | Estonian | Dark cloak | Urban rebel cell |

The Apprentice understands Estonian by default; Low German is the language of the prisoner and the fourth king's circle; Swedish and Finnish are flavour or gated imagery ([`CULTURES_AND_LANGUAGES.md`](CULTURES_AND_LANGUAGES.md)). Show Estonian rural dialect against the Low German of the captured and the quarrelling: the kings use Low German only as a tool.

## 6. Factions present

| Faction id | Presence | Wants | Where | Act-by-act |
|---|---|---|---|---|
| `harju_kings` | Command and host | Take Reval, keep the host fed, a Swedish promise | Council ring, both camps | A2 investment to assault; A3 dead or scattered |
| `cult_metsik` | Seers, healers, omen readers | Ritual cover, sanctuary after defeat | East camp, council fringe | A2 omens; A3 martyr symbols |
| `black_cloaks` | Liaison with the city | Gate sabotage, steel for weapons | Field forge, supply shelter | A2 night-network handoffs |
| `livonian_order` | Absent until prisoners, spies, then attackers | Break the host | Prisoner pen; later east road | A2 after 11 May |
| `danish_crown` | Absent; captured clerks or messages | Hold the walls | Prisoner pen | A2 onward |
| `hanseatic` | Grain levy, smugglers selling to both | Neutral profit | Supply shelter | A2 |
| `pskov_novgorod` | Distant feelers only | Information | Envoy fringe | A2 (May 26 raid = news only) |
| `vitalienbruder` | Rumour | - | - | - |
| `church` (candidate affinity) | A rebel priest | Peace, burial rites | Wounded shed | A2 |

## 7. Characters

| char id | Name | Role / faction | Language | Confidence | Source | Hook / quest use |
|---|---|---|---|---|---|---|
| `char.lembit_helme` | Lembit Helme | Elder King, `harju_kings` | Estonian; Low German as a tool | `plausible composite` | [`lembit.md`](../CHARACTERS/lembit.md); legacy [`lembit_helme.md`](../../characters/rebels/lembit_helme.md) | Fire Sermon; King's Council |
| `char.juri_ratnik` | Jüri Ratnik | Smith-warrior king, "Iron Hand" | Estonian | `invented` | legacy [`juri_ratnik.md`](../../characters/rebels/juri_ratnik.md); [`four_kings_act2_lore.md`](../lore/four_kings_act2_lore.md) | Camp smith; tests the player's craft |
| `char.urmas_laar` | Urmas Laar | Seer king | Estonian | `invented` | legacy [`urmas_laar.md`](../../characters/rebels/urmas_laar.md) | Omens; reads Kalev as giant-king |
| `char.kaja` | Kaja Lahekivi | Bilingual courier, `harju_kings` | Estonian, Low German | `invented` | [`kaja.md`](../CHARACTERS/kaja.md); legacy [`kaja_lahekivi.md`](../../characters/rebels/kaja_lahekivi.md) | Message network; knows the rising is premature |
| `char.king_hannus_rider` | Hannus the Rider | Fourth king, Estonian vassal-client | Estonian, Low German | `invented` | NEW | Embodies the multi-status coalition; doubts the plan |
| `char.martin_cloaks` | Martin of the Cloaks | Black Cloaks smith-contact | Estonian | `invented` | [`martin_black_cloaks.md`](../CHARACTERS/martin_black_cloaks.md) | Steel and news from the city |
| `char.triin_aino_tutar` | Triin Aino tütar | 15-year-old courier | Estonian | `plausible composite` | [citizen card](../CITIZENS/people/harju_road/triin_aino_tutar.md) | Runs words to the camp |
| `char.veronika` | Veronika | Drover, supply route | Estonian | `plausible composite` | [citizen card](../CITIZENS/people/harju_road/veronika.md) | Cattle for the host |
| `char.camp_quartermaster_eha` | Eha | Quartermaster | Estonian | `invented` | NEW; legacy quartermaster | Grain count, short rations, honest ledger |
| `char.swedish_envoy_ake` | Åke | Envoy of the Swedish bailiffs | Swedish, some Finnish | `invented` | NEW | Escort/diplomacy; the offer's limits |
| `char.captured_order_brother` | Brother Dietrich | Prisoner | Low German, Latin | `invented` | NEW; legacy "captured knight" | Ransom, interrogation, mercy |
| `char.camp_healer_anna` | Anna | Camp healer | Estonian | `invented` | NEW | Wounded shed; herb needs |
| `char.rebel_priest_johannes` | Johannes | Priest who joined | Latin, Estonian | `invented` | NEW | Burial rites |

Crowd archetypes: young recruit with a scythe-blade on a pole; woman who followed her husband; veteran drilling the line; skald; sentry on the ditch; dice circle; dog; farmer delivering grain.

## 8. Quests, encounters, and discoveries

| Id (proposed) | Act | Type | Hook | Ties |
|---|---|---|---|---|
| `quest.camp_field_forge` | 2 | Forge commission | Re-haft scythe-blades, repair spearheads with scrap; honest steel vs defect | `mission.act2.recall.spearhead`, [`arms dossier`](../../history/dossiers/military/arms-and-armour-livonia-1340s.md) |
| `quest.kings_council` | 2 | Investigation | Break a deadlock with forged or found evidence | [`lembit.md`](../CHARACTERS/lembit.md) |
| `quest.fire_sermon` | 2 | Travel event | Escort a gathering that must hear Lembit before a village commits | [`lembit.md`](../CHARACTERS/lembit.md) |
| `quest.the_swedish_offer` | 2 | Investigation | The envoy's promises versus a ship that has not come; verify what can be delivered | `mission.act2.travel.harju_camp` |
| `quest.grain_for_the_host` | 2 | Night mission | Supply run to camp across a patrolled road | `mission.act2.siege.sortie_rebel` |
| `quest.the_camp_spy` | 2 | Investigation | Someone sells the muster list; Hanseatic, Order or Cloaks | `faction` ledgers |
| `quest.ransom_or_mercy` | 2 | Spirit-world | A captured brother; dialogue duel with stakes | ADR 0033 |
| `quest.last_night_at_camp` | 2 end | Spirit-world | Urmas's death-omen (mardus) of the Four Kings; warning for Paide | F-12 in [`estonian_folklore.md`](../lore/estonian_folklore.md) |

Sights: (1) the muster order: how a rising feeds itself; (2) what a camp smith can and cannot make; (3) the beacon post and why the hill is unnamed (`invented`, labelled honestly); (4) the Swedish appeal as the one attested diplomatic act; (5) a rebel's tally-stick of days worked.

## 9. Resources: what must be generated

### 9.1 Structures and architecture
| Asset id | Description | Pri | Shared with | Notes |
|---|---|---|---|---|
| `asset.kit.camp_lean_to` | Hide/brush lean-to, tent, straw bed rows; owns this definition | P1 | [`kanavere_bog.md`](kanavere_bog.md), [`sojamae.md`](sojamae.md) | Reuse the greybox `camp` primitive volume |
| `asset.kit.timber_beacon_post` | Cited, defined in [`baltic_klint_coast.md`](baltic_klint_coast.md) | P2 | baltic, narva | Signal hill dressing |
| `asset.kit.log_farmstead` | Requisitioned barn, outbuildings (cited from [`harju_village.md`](harju_village.md)) | P1 | Harju | - |
| `asset.kit.log_hut_refuge` | Cited from [`soomaa_flood_refuge.md`](soomaa_flood_refuge.md) | P3 | Soomaa | Sheltered huts at the camp edge |
| `asset.kit.field_forge` | Anvil on stump, bellows, charcoal pile, trough, wattle windbreak | P1 | [`sojamae.md`](sojamae.md) | Defined here |
| `asset.kit.wagon_laager` | Cart arc, yoke poles | P2 | Kanavere, Sõjamäe | Reuse `wooden_cart.glb` |

### 9.2 Props and craft objects
| Asset id | Description | Pri | Shared with | Notes |
|---|---|---|---|---|
| `asset.prop.peasant_weapon_rack` | Spears, axes, scythe-blades on poles, flails, clubs | P1 | Kanavere, Sõjamäe | Arms dossier, rebel kit |
| `asset.prop.camp_standard` | Plain dyed cloth on a pole with a sprig | P1 | Kanavere, Sõjamäe | `invented` (no heraldry) |
| `asset.prop.council_stools_and_stakes` | Four stools or stakes around a fire | P1 | none | `invented` |
| `asset.prop.cauldron_tripod` | Iron cauldron, ladles, trench oven | P2 | Harju | - |
| `asset.prop.tally_stick_set` | Notched sticks for labour and grain | P2 | Harju | Illiterate bookkeeping |
| `asset.prop.field_forge_tools` | Tongs, hammers, swages, nail header, quench barrel | P1 | Forge | Forge hub |
| `asset.prop.captured_order_gear` | Surcoat, shield, kettle helm on a pole | P2 | Kanavere, Sõjamäe | Order kit |
| `asset.prop.wounded_straw_rows` | Straw beds, bandage rolls | P2 | Kanavere, Sõjamäe | - |
| `asset.prop.swedish_seal_letter` | Folded letter with a wax seal | P3 | none | Prop for the offer |

### 9.3 Characters
| Asset id | Description | Pri | Shared with | Notes |
|---|---|---|---|---|
| `asset.wardrobe.harju_peasant` | Cited (hub); camp-worn variants `.camp`, `.looted_cap`, `.wounded` | P1 | all Harju-group | One shared rig + MPFB |
| `asset.wardrobe.wounded_rebel` | Cited ([`soomaa_flood_refuge.md`](soomaa_flood_refuge.md)) | P2 | Soomaa | - |
| `asset.wardrobe.knight_vassal` | Cited (hub); fourth king, no arms | P2 | Harju | `invented` arms |
| `asset.wardrobe.swedish_coast_man` | Cited (hub); envoy variant `.bailiff_envoy` | P2 | baltic_klint | - |
| `asset.wardrobe.order_brother` | Cited (hub); prisoner variant `.captive` | P2 | Paide | - |
| `asset.hair.rebel_beard_set` | Elder white, soot-black, scarred | P2 | Harju | Jüri/Lembit briefs |

### 9.4 Fauna
| Species | Id | Status | Notes |
|---|---|---|---|
| Ox, horse, dog, cattle, sheep, goose, chicken | `fauna.*` | cataloged except `fauna.ox` (proposed, P2, from [`harju_village.md`](harju_village.md)) | Draught oxen at the wagon line |
| Hooded crow, rook, magpie | `bird.*` | cataloged | Camp scavengers |
| Raven | `bird.raven` | missing (hub, P1) | Carrion bird in phase D |
| Wolf, red fox | `fauna.*` | cataloged | Edge ambience, night |

### 9.5 Flora and ground cover
Existing: `tree.alder`, `tree.birch`, `tree.willow`, `plant.nettle`, `plant.reed`, `plant.dandelion`, `grass.*`. Missing: `plant.coltsfoot`, `plant.wood_anemone` (hub). Proposed: `asset.terrain.trampled_meadow` (decal set, P1), `plant.willow_catkin_bough` (P3).

### 9.6 Materials, terrain, water
`asset.mat.till_mud_wet` (defined in [`harju_village.md`](harju_village.md)); `asset.mat.camp_ash_trample` (P1); `asset.mat.hide_and_sacking` (P2); terrain `dirt`, `mud`, `straw` exist; add `asset.water.drainage_ditch_brown` (P3).

### 9.7 Audio and music direction
Ambient: crowd murmur, hammer on the field anvil, bellows, axe on firewood, oxen, cartwheels in mud, dogs, ravens, rain on hide. Languages: Estonian dialect in many accents, Low German snapped by the prisoner and the fourth king, Swedish from the envoy. Music: horn shouts for mobilisation (not a band), a lone *regilaul* voice at night (`folklore`/`plausible composite`), no organ, no town pipers ([music dossier](../../history/dossiers/culture/music-and-instruments.md)). Legacy "anthemic choral theme" and bagpipes are not adopted for 1343 audio.

## 10. Variety signature and risks

- **Palette:** wet ochre, ash-grey, smoke-orange, hide-brown; red only at the fires.
- **Silhouette:** ragged low shelters, poles (standards, tripods, spear cones), smoke columns.
- **Soundscape:** crowd and hammer, then silence.
- **Risks:** (1) anachronism - tents with heraldry, plate, firearms, uniformity; (2) scale - the "10,000" is rhetoric, show hundreds; (3) camp "within sight of Reval's walls" appears in older notes but the dossier brackets 5-12 km, so use glow and smoke only; (4) massacre and war crimes sensitivity - rebel violence and Order reprisals both occur; do not give either side clean hands; (5) performance - dense camp crowd on a 50x28 map; (6) scope - none new here.
- **Contradictions found:** `char.lembit_helme` (CHARACTERS and lore) versus `char.lembit_helme` in [`padise_monastery.md`](padise_monastery.md); `lembit.md` labels him `plausible composite`, the lore file `invented`; the lore calls Kalev's rebel alias "Martin the Blacksmith" while [`martin_black_cloaks.md`](../CHARACTERS/martin_black_cloaks.md) says he is not Kalev; legacy roster treats Kaja as a fourth leader, the active brief as a courier.
- **Open questions:** who is the fourth king? Should the Swedish envoy be gated by language skill? How much of the Paide trap does the camp know?

## 11. Sources and next steps

Repo: [`world_rebel_kings.rrmap`](../../content/maps/world_rebel_kings.rrmap), [`scenes/events/rebel_kings.md`](../../scenes/events/rebel_kings.md) (legacy), [`global_map_mockups.md`](../reports/global_map_mockups.md), [`p5_001_act2_design.md`](../reports/p5_001_act2_design.md), [`four_kings_act2_lore.md`](../lore/four_kings_act2_lore.md), [`CITIZENS/factions/harju_kings.md`](../CITIZENS/factions/harju_kings.md), [`CANON.md`](../CANON.md), [`arms dossier`](../../history/dossiers/military/arms-and-armour-livonia-1340s.md). External, by name: Hermann de Wartberge, Hoeneke (Younger Livonian Rhymed Chronicle), Moisio on Harria fiefs.
Verification tasks: (1) name or leave open the fourth seat; (2) decide whether the camp sits on a dedicated map or reuses the Harju east fields; (3) review the war-state keys (`war.kings_alive`, `war.rebel_field_strength`) against the camp phase states; (4) check Swedish envoy canon; (5) pass the Pirita crossing through the Map and Canon boundary review.
