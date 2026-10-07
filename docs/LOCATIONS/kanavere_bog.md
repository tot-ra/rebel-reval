# Kanavere Bog (Kanavere raba, eastern Harria)

**Status:** planned (design proposal, not implemented) · **Scope gate:** existing prototype `loc.world_kanavere` · **Act(s):** 2 (`mission.act2.kanavere`, 11 May 1343), 3 (memorial and aftermath only)
**Map id:** `loc.world_kanavere` (existing: [`content/maps/world_kanavere.rrmap`](../../content/maps/world_kanavere.rrmap), 54x30 cells, biome `bog`, `scope=prototype`, `active=false`) · **Seasons/phases:** pre-battle approach (9-10 May), battle day (11 May), aftermath (12-14 May), memorial state (Act 3)
**Confidence summary:** the 11 May battle and the limited rebel success `attested`; the bog as the setting is the tradition's own; the exact battlefield position, the shape of the engagement, fieldworks, trackway and every named person `plausible composite` or `invented`; raised-bog ecology `attested` (natural science), medieval use `plausible composite`.

## 1. Why a player would want to visit

- It is the rebels' one clear win, and the player decides how much it costs (survivor and casualty states, never the outcome - [`CANON.md`](../CANON.md)). That makes it the only node where success is the dilemma.
- It is the only raised bog in the game: a flat, silent, copper-and-silver landscape where heavy horse fails and a guide is worth more than a sword.
- It teaches the Apprentice to read ground rather than people - safe line versus soft peat, the tell-tale colour of sphagnum - and gives the forge a surprise (bog iron).
- The bog is also the Cult's omen-book: "reads bog as omen" ([`p5_001_act2_design.md`](../reports/p5_001_act2_design.md)). Marsh-lights and silence carry the spirit-world content.
- **Signature:** a perfectly flat horizon of rust-orange hummocks and black pools, crossed by one fragile log trackway - the least vertical node on the map.

## 2. History in 1343

| Claim | Label | Source | Use |
|---|---|---|---|
| Battle of Kanavere Bog, 11 May 1343, in Harju County | `attested` | [`CANON.md`](../CANON.md), [`battle_of_kanavere_bog.md`](../../wiki/events/battle_of_kanavere_bog.md) | Mission anchor |
| A rebel force defeats an Order detachment; a real but limited success before the main Order army arrives | `attested` (project reading of the chronicle tradition) | [`CANON.md`](../CANON.md) | Outcome fixed |
| Troop numbers, order of battle, casualty counts | unverified; chronicle rhetoric | - | Show a skirmish scale, not an army |
| Bog used to bog down mounted knights, rebels on foot with spears and axes | `plausible composite` | [`arms-and-armour-livonia-1340s.md`](../../history/dossiers/military/arms-and-armour-livonia-1340s.md) | Mechanism, not evidence |
| Jüri's split of forces creates the opening for the later Order counterattack | `invented` | [`four_kings_act2_lore.md`](../lore/four_kings_act2_lore.md) | Scouting-choice consequence |
| Ditch-and-stake fieldworks | `invented` | greybox `west_fieldworks`, `east_fieldworks` | Cheap earthwork props |
| Log-and-brushwood trackways across wet ground | `plausible composite` (attested archaeologically across northern Europe from prehistory) | - | Trackway kit |
| Modern boardwalks and "duckboards" on tourist bog trails | NOT 1343 | - | Never show planked boardwalks with handrails |
| Bog iron ore smelted in bloomeries | `plausible composite` | [`blacksmith-materials-and-techniques.md`](../../history/dossiers/crafts/blacksmith-materials-and-techniques.md) | Forge sight |
| Modern Kanavere memorial | NOT 1343 | [`TOURIST_LANDMARKS.md`](../TOURIST_LANDMARKS.md) row 3 | Act 3 only if a task asks, as a heap of stones |

**Phases.** A (approach): scouting the trackway, the guide, the first dew and frogs. B (battle, 11 May): fog or rain, noise, panic, horses in peat; resolved through scripted allies and a combat encounter, not an army sim. C (aftermath): bodies, abandoned gear, the question of prisoners and the wounded; the camp's mood of triumph. D (Act 3): wind, cranes, a heap of stones.
**Do not show:** gunpowder, plate harness, uniform Order ranks as a parade, a "memorial cross" from the 20th c., a sunlit summer bog (the battle is in May: cotton-grass in early bloom, pools still cold), a cleanly victorious army cheering.

## 3. Landscape and layout

Biome: raised bog (*kõrgsoo*) with a wet margin (lagg) of birch and alder carr, a mineral island of pine and spruce, and a southern meadow where the rebel camp spreads. May: cold, windy, frequent fog and drizzle; hollows still hold meltwater; frogs spawning.

| Zone | Cells (x,y,w,h) | Prototype id | Notes |
|---|---|---|---|
| Bog dome (north) | 0,0,54,8 | `northern_bog` | Hummock-hollow mosaic, black pools, dwarf pines |
| Flooded margin (lagg) | 0,8,54,5 | `flooded_margin` | Mud, alder/birch carr, standing water |
| Trackway and ridge | 2,13,50,6 | `causeway` | Dirt/log trackway across the narrow neck |
| South meadow | 0,19,54,11 | `south_meadow` | Rebel camp, Order approach field |
| Mineral island (proposed) | 36,2,10,5 | - | Pine island for a lookout and a hidden camp |
| Fieldworks | 8,10,1,11 / 45,10,1,11 | `west_fieldworks`, `east_fieldworks` | Ditch-edge pieces, `invented` |
| Field shelter | 23,20,8,4 | `field_shelter` | Aid post, shed |

Landmarks (existing): `landmark_bog_causeway` (27,15), `landmark_west_fieldworks` (9,17), `landmark_east_fieldworks` (44,17). Proposed (`invented`): `landmark_bog_pool_eye` (12,4, a dark tarn), `landmark_guide_stakes` (30,10, bark-ringed marker poles), `landmark_pine_island` (41,4), `landmark_bogiron_pit` (6,9), `landmark_memorial_heap` (27,22, Act 3 state).

**Journey edges (existing, all `alignment=travel`):** `road_to_harju` (0,24) to `world_harju`; `road_to_rebel_kings` (0,14) to `world_rebel_kings`; `road_to_paide` (50,24) to `world_paide`. Proposed: none. ADR 0027 keeps this node explicit travel ([ADR 0027](../adr/0027-reval-hinterland-streaming-group.md)). Note the greybox's `northern_bog` strip is flat along the whole north; deepening should break it into a dome with a visible edge.

## 4. Architecture and built environment

Nearly none; the built environment is earth and timber thrown up in a hurry.

| Element | Form | Material | Label |
|---|---|---|---|
| Log trackway | Cross-laid logs on brush, a few split planks as a patch; gaps and rot | Pine logs, brush | `plausible composite` |
| Ditch-and-stake fieldworks | Short ditch with spoil bank and sharpened stakes | Earth, stakes | `invented` |
| Aid shelter | Lean-to, straw, buckets | Poles, thatch | `plausible composite` |
| Bog-iron pit | Shallow digging, nodules stacked, charcoal clamp | Earth, turf | `plausible composite` |
| Fowler's blind and eel weir | Reed screen on a tarn edge | Reeds, withy | `plausible composite` |
| Hamlet edge (off-map) | Log farms of Kanavere village | Log, thatch ([`asset.kit.log_farmstead`](harju_village.md)) | `plausible composite`; village name modern |

Distinguishing rule vs other nodes: no walls, no rooftops over the horizon; the one vertical element is the standard pole. Contrast: the Sõjamäe node is open water and ridge; this node is closed peat and fog.

## 5. Cultures, languages, and people

| Group | Language | Dress | Customs |
|---|---|---|---|
| Harju rebels (freeholders, vassal clients, labourers) | North Estonian; Low German curses from the vassal client | Wool, leather, bast shoes; captured caps | Oaths, omens, charms; bog treated as an owner-realm (*haldjas*) - `folklore` |
| Fowlers, eel-trappers, charcoal-burners | Estonian | Hide and felt hats, waxed boots | Marsh lore, lights over graves (*tulukesed*) - `folklore` |
| Order detachment (knights, sergeants, local levies) | Middle Low German, Latin prayer | Mail, surcoat with black cross, kettle helms; levies in padded jacks | Order rule; fear of the bog |
| Wounded and dead | Any | - | Burial rites contested between priest and Metsik helpers |

Language note: the Apprentice understands Estonian by default; Low German is imagery or gated until comprehension grows ([`CULTURES_AND_LANGUAGES.md`](CULTURES_AND_LANGUAGES.md)). Use the contrast: the guide speaks slow bog-Estonian, the Order sergeants clipped Low German.

## 6. Factions present

| Faction id | Presence | Wants | Where | Act-by-act |
|---|---|---|---|---|
| `harju_kings` | Rebel host and its commanders | Hold the trackway, ambush the detachment | Fieldworks, south meadow | A2 battle day; A3 survivors bury the dead |
| `livonian_order` | A detachment (and its aftermath) | Cross the bog to the camp; recover the dead | Trackway, south approach | A2 beaten; later main army (Sõjamäe) |
| `cult_metsik` | Omen readers, healers | Interpret the bog, sanctify burials | Pine island, east camp | A2 omens; A3 martyr symbols |
| `black_cloaks` | Courier or scout | Information, steel | Edge | A2 |
| `danish_crown`, `hanseatic`, `pskov_novgorod`, `vitalienbruder` | None | - | - | - |
| `church` (candidate affinity) | A priest who buries | Rites, truce for the dead | Field shelter | A2 aftermath |

## 7. Characters

| char id | Name | Role / faction | Language | Confidence | Source | Hook / quest use |
|---|---|---|---|---|---|---|
| `char.juri_ratnik` | Jüri Ratnik | Commander of the vanguard | Estonian | `invented` | legacy [`juri_ratnik.md`](../../characters/rebels/juri_ratnik.md); [`four_kings_act2_lore.md`](../lore/four_kings_act2_lore.md) | Splits forces; wants pursuit |
| `char.lembit_helme` | Lembit Helme | Elder King | Estonian | `plausible composite` | [`lembit.md`](../CHARACTERS/lembit.md) | Argues for consolidation |
| `char.urmas_laar` | Urmas Laar | Seer king | Estonian | `invented` | legacy [`urmas_laar.md`](../../characters/rebels/urmas_laar.md) | Reads the bog as omen; marsh-lights |
| `char.kaja` | Kaja | Courier, scout | Estonian, Low German | `invented` | [`kaja.md`](../CHARACTERS/kaja.md) | Scouting report; choices shape the outcome |
| `char.ellen` | Ellen Luik | Midwife, keeper of songs | Estonian | `plausible composite` | [`ellen.md`](../CHARACTERS/ellen.md) | Aftermath: songs for the dead, remedies |
| `char.bog_guide_mihkel` | Mihkel the fowler | Guide through the soft ground | Estonian | `invented` | NEW | Safe line; refuses to guide twice |
| `char.order_sergeant_gerlach` | Sergeant Gerlach | Detachment sergeant | Low German | `invented` | NEW; archetype [`paide_castle.md`](paide_castle.md) | Prisoner, or a corpse found with a letter |
| `char.order_squire` | Tomas Veld | Order squire (Reval) | Low German | `invented` | [`order_squire.md`](../CHARACTERS/order_squire.md) | Optional: a young Order witness held after the battle |
| `char.rebel_boy_toomas` | Toomas | Boy with a spear | Estonian | `invented` | NEW; legacy "young man eager to fight" | Survivor state: lives, maimed, or lost |
| `char.camp_healer_anna` | Anna | Healer (from [`rebel_kings_camp.md`](rebel_kings_camp.md)) | Estonian | `invented` | NEW | Aid post, herb demands |

Crowd archetypes: fowler with net and decoys; woman carrying water to the aid post; sergeant on foot, helmet off; boy with a standard; frightened levy; charcoal-burner leading a cart; priest murmuring Latin.

## 8. Quests, encounters, and discoveries

| Id (proposed) | Act | Type | Hook | Ties |
|---|---|---|---|---|
| `mission.act2.kanavere` | 2 | Night/day mission | Hold the trackway; scouting choices alter casualties and survivors, not the result | Existing id ([`p5_001_act2_design.md`](../reports/p5_001_act2_design.md)) |
| `quest.the_safe_line` | 2 | Exploration | Find the firm line with the fowler; sphagnum colour, marker poles | Spirit-eyed reading |
| `quest.bog_iron_for_the_camp` | 2 | Forge commission | Dig nodules for the field forge; honest bloom or a defect | [`rebel_kings_camp.md`](rebel_kings_camp.md) forge |
| `quest.prisoners_and_papers` | 2 | Investigation | A sergeant's letter shows where the main army will strike | links to `mission.act2.sojamae` |
| `quest.whispering_fen` | 2 | Spirit-world | Lights over an old grave pit; lay the dead to rest by rite, not force | legacy Ellen seed; `kodukäija` in [`estonian_folklore.md`](../lore/estonian_folklore.md) |
| `quest.the_toomas_choice` | 2 end | Travel event | Carry the wounded boy out or send him to the fire | `flag.kanavere_survivors` (proposed) |
| `quest.libahunt_margin` | 3 | Spirit-world | A "wolf" haunts the bog edge after the dead are left | F-7 |

Sights: (1) the three zones of a raised bog (dome, lagg, mineral island) and why the surface quakes; (2) cotton-grass in early bloom and what the colours mean; (3) a corduroy track and why logs lie crosswise; (4) bog iron and the smith's trade; (5) cranes dancing on the margin at first light.

## 9. Resources: what must be generated

### 9.1 Structures and architecture
| Asset id | Description | Pri | Shared with | Notes |
|---|---|---|---|---|
| `asset.kit.bog_causeway` | Cited, defined in [`soomaa_flood_refuge.md`](soomaa_flood_refuge.md); this page adds variants `.wide`, `.broken_span`, `.patched_plank` | P1 | Soomaa | Not a modern boardwalk |
| `asset.kit.ditch_and_stake_works` | Short earthwork with stakes and spoil bank; defined here | P2 | [`sojamae.md`](sojamae.md) | `invented` |
| `asset.kit.camp_lean_to` | Cited from [`rebel_kings_camp.md`](rebel_kings_camp.md) | P1 | camp | Aid post |
| `asset.kit.bogiron_digging` | Pit, stacked nodules, charcoal clamp | P3 | Forge | `plausible composite` |

### 9.2 Props and craft objects
| Asset id | Description | Pri | Shared with | Notes |
|---|---|---|---|---|
| `asset.prop.bog_marker_stakes` | Bark-ringed marker poles along the safe line | P1 | Soomaa | Guide craft |
| `asset.prop.fascine_bundle` | Brushwood bundle for patching | P2 | Soomaa | - |
| `asset.prop.broken_levy_cart` | Mired cart (prototype `broken_cart`) | P1 | camp, Sõjamäe | Reuse `wooden_cart.glb` |
| `asset.prop.peasant_weapon_rack` | Cited from [`rebel_kings_camp.md`](rebel_kings_camp.md) | P1 | camp | - |
| `asset.prop.order_surcoat_scatter` | Dropped shields, surcoats, helms in peat | P2 | Sõjamäe | Aftermath |
| `asset.prop.fowler_net_and_decoys` | Net, wooden decoy ducks, snare | P3 | none | Craft sight |
| `asset.prop.bog_iron_nodules` | Rust nodules and a bloom lump | P2 | Forge | - |
| `asset.prop.memorial_stone_heap` | Act 3 heap of stones | P3 | none | `invented` |

### 9.3 Characters
| Asset id | Description | Pri | Shared with | Notes |
|---|---|---|---|---|
| `asset.wardrobe.harju_peasant` | Cited (hub); `.bog_wet` and `.bloodied` variants | P1 | Harju group | Shared rig + MPFB |
| `asset.wardrobe.hunter_hide` | Cited ([`otepaa_vastseliina_frontier.md`](otepaa_vastseliina_frontier.md)) | P2 | Frontier | Fowler guide |
| `asset.char.wardrobe.order_sergeant` | Cited ([`paide_castle.md`](paide_castle.md)) | P1 | Paide | Mud variant |
| `asset.wardrobe.order_brother` | Cited (hub) | P1 | Paide | Mud, torn mantle |
| `asset.wardrobe.wounded_rebel` | Cited ([`soomaa_flood_refuge.md`](soomaa_flood_refuge.md)) | P2 | Soomaa | - |

### 9.4 Fauna
| Species | Id | Status | Notes |
|---|---|---|---|
| Wolf, lynx, elk, brown bear, fox, otter | `fauna.*` | cataloged | Edge ambience; elk at the lagg |
| Snipe, grey heron, mallard, lapwing, hooded crow | `bird.*` | cataloged | Wet margin |
| Common crane | `bird.common_crane` | missing (hub, P1) | Dancing at dawn, calls carry for kilometres |
| Black grouse | `bird.black_grouse` | missing (hub, P2) | April-May lek, optional |
| Capercaillie | `bird.capercaillie` | missing (hub, P3) | Pine island |
| Moor/common frog | `amphibian.common_frog` | missing (hub, P3) | Spawning pools, loud |
| Adder | `reptile.adder` | missing (hub, P3) | Basking on hummocks, rare |
| Mosquito, dragonfly | insect audio/prop | missing (hub, P3) | May swarms |

### 9.5 Flora and ground cover
Existing: `plant.moss` (sphagnum), `bush.bog_rosemary`, `bush.cranberry`, `bush.cloudberry`, `bush.crowberry`, `bush.heather`, `tree.pine`, `tree.birch`, `tree.alder`, `tree.spruce`, `plant.reed`, `plant.fern`. Missing (hub ids): `plant.cottongrass` (P1), `plant.sundew` (P2), `bush.labrador_tea` (P2), `tree.pine_bog_dwarf` (P1), `plant.sedge_tussock` (P2). Proposed: `plant.bogbean` (P3), `asset.flora.sphagnum_hummock_mosaic` (P1; red-green-copper hummocks).

### 9.6 Materials, terrain, water
`asset.terrain.raised_bog_hummock_hollow` (P1; defined here), `asset.terrain.lagg_carr_mud` (P2), `asset.water.bog_pool_tannin` (P1; black-brown mirror, defined here), `asset.mat.peat_wet`, `asset.mat.sphagnum_copper`, `asset.mat.fog_volume` (P2); existing `bog`, `mud`, `shallow_water` types.

### 9.7 Audio and music direction
Ambient: wind in cotton-grass, drip and suck of peat, cranes, snipe drumming, frogs, distant horn, then the alarm: horses screaming and men shouting in two languages. Languages: slow Estonian from the guide, Low German commands from the detachment. Music: none until the aftermath; a single unaccompanied *regilaul* lament (`folklore`/`plausible composite`) and a low drone; no battle anthem ([music dossier](../../history/dossiers/culture/music-and-instruments.md)).

## 10. Variety signature and risks

- **Palette:** peat brown, copper-rust sphagnum, silver-black pools, fog grey.
- **Silhouette:** perfectly flat horizon, scattered dwarf pines and dead snags, one trackway line.
- **Soundscape:** wind, water, cranes, then the noise of the fight.
- **Risks:** (1) anachronism - boardwalks, plate harness, memorial crosses, summer vegetation; (2) battle detail is unverified, so every tactical claim must read `plausible composite`; (3) sensitivity - massacre and mutilation of the dead, prisoners; show consequence, not gore; (4) performance - fog volume and pool reflections on a wide flat map; (5) clashing identical greyboxes (this map and Sõjamäe share the same terrain rects and props) - deepening must give each a distinct layout.
- **Contradictions found:** `world_kanavere.rrmap` and `world_sojamae.rrmap` are the same layout apart from a terrain rename; the greybox shows a bog north of a south meadow while the lore says "bog tracks" through the middle; the legacy Jüri file calls him a Läänemaa smith while the camp shows him in Harju.
- **Open questions:** is the aftermath a separate state of the same map or a lighter new map? Should the player ever command allies?

## 11. Sources and next steps

Repo: [`world_kanavere.rrmap`](../../content/maps/world_kanavere.rrmap), [`battle_of_kanavere_bog.md`](../../wiki/events/battle_of_kanavere_bog.md), [`CANON.md`](../CANON.md), [`four_kings_act2_lore.md`](../lore/four_kings_act2_lore.md), [`p5_001_act2_design.md`](../reports/p5_001_act2_design.md), [`BIOMES_AND_WILDLIFE.md`](BIOMES_AND_WILDLIFE.md) (section 4), [`FLORA_FAUNA.md`](../FLORA_FAUNA.md), [`TOURIST_LANDMARKS.md`](../TOURIST_LANDMARKS.md). External, by name: Hermann de Wartberge and the Livonian chronicle tradition; Estonian raised-bog ecology (Soomaa and Viru bog literature); northern-European trackway archaeology.
Verification tasks: (1) fix the modern Kanavere village position and what the sources say about the engagement; (2) decide how the node differs structurally from Sõjamäe; (3) verify bog-iron use in 14th-c. Harju; (4) review fog and pool performance; (5) write the survivors-flag schema (`flag.kanavere_survivors`).
