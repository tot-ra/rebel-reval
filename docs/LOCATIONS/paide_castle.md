# Paide Castle (Wittenstein / Weissenstein, Paide)

**Status:** planned (design proposal, not implemented) · **Scope gate:** existing prototype `loc.world_paide` · **Act(s):** 2 (finale, `mission.act2.paide`), 3 opening handoff (`transition.act2_to_act3.paide`)
**Map id:** `loc.world_paide` (existing: [`content/maps/world_paide.rrmap`](../../content/maps/world_paide.rrmap), 50x30 cells, `scope=prototype`, `active=false`; proposal widens it to about 90x56) · **Seasons/phases:** mid-May 1343, cold thaw, standing mud; phase A "truce" (arrival, hall), phase B "after" (castle sealed, refugees, silence)
**Confidence summary:** Four Kings lured and killed at Paide under truce: `attested`. Burchard von Dreileben as Master: `attested`. Exact day-order against Kanavere/Sõjamäe: contested; Act 2 placement is `invented` framing. Castle layout, town market, all NPCs below the Master: `plausible composite` or `invented`. Goswin von Herike's 1343 post: unverified.

## 1. Why a player would want to visit

- It is the Act 2 finale: the player arrives at the place where every rebel plan ends, carrying survivor and warning states from Kanavere and Sõjamäe ([`p5_001_act2_design.md`](../reports/p5_001_act2_design.md)).
- A truce hall scene where the dread comes from procedure: seating, oaths, interpreters, a locked door. The player may warn, delay, or only witness; the killings stay fixed.
- A market town under a castle, crowded with refugees from burning manors, so the node is a living place before and after the event.
- Defines the "Order white" look of the whole game: pale limestone, black crosses, tight discipline.
- **Signature:** the one node built around a single tall stone keep in a flat, wet, treeless plain, where every sound is Latin, Low German or silence.

## 2. History in 1343

| Fact | Label | Note |
|---|---|---|
| Order castle at Paide (Wittenstein / Weissenstein), Järvamaa (Jerwen) | `attested` | Mentioned from the 1260s; seat of an Order official. |
| Stone keep-tower dominating the castle | form `attested`, 1343 completion `plausible composite` | Octagonal main tower of about 30 m with 2.4 m walls (Tuulse cross-section; Borowski plan), at the south-west corner of the square upper ward. Built in the regional site ([`REGIONAL_SITES.md`](../SYSTEMS/REGIONAL_SITES.md)) as an intact keep, not the ruin or the 1990s rebuild. |
| Master Burchard von Dreileben (Master 1340-1345) lures the Four Kings under truce; talks break down; envoys killed | `attested` ([`CANON.md`](../CANON.md), Hermann de Wartberge tradition) | Names of the four kings are not recorded; game kings are `invented` composites ([`four_kings_act2_lore.md`](../lore/four_kings_act2_lore.md)). |
| Goswin von Herike (later Master, 1345-1359) | `attested` as later Master; 1343 rank unverified | Legacy seed puts him at Paide as a senior brother. Label `plausible composite` for any 1343 office. |
| Market settlement beside the castle, refugees inside | `plausible composite` | Town rights date unverified. [`TOURIST_LANDMARKS.md`](../TOURIST_LANDMARKS.md) lists "modest fortifications around the market". |
| Rebel movements north of Paide in May 1343 | `attested` (context) | Day-order versus 11-14 May is contested; do not claim a settled chronology. |

Phases: A (truce): castle open to envoys, market loud. B (after): gates barred, bodies removed, Order scribes writing the official version, locals silent. The Act 3 handoff reads the player's warning and survivor flags.
Do NOT show: Toompea's Tall Hermann or other Toompea tower forms (the Paide keep's own modern nickname "Pikk Hermann" is not used in 1343 text), Türi windmill ridge, a ruined castle, gunpowder artillery, a town hall or guild house, late spires, "Paide Tall Tower" museum features.

## 3. Landscape and layout

Biome: flat Järvamaa clay plain, shallow limestone bedrock, wet fields, alder carrs and a small stream; few trees, wide sky, May mud, late snow-melt pools. Climate: cold rain, wind.

| Zone | Approx cells (90x56) | Reads as | Carries |
|---|---|---|---|
| South road and ford | x0-90, y48-56 | Churned clay road, carts, refugees | Journey edges, crowd entry |
| Market settlement | x6-40, y24-48 | Timber houses, stalls, a wooden parish chapel | Refugee camp, rumour, merchants |
| Outer ditch and palisade | x40-82, y6-52 | Wet ditch, earth bank, timber bridge | Approach, checkpoint |
| Forecourt (Vorburg) | x46-80, y30-48 | Stables, smithy, granary, well | Smithy hook, Order labour |
| Inner castle | x48-78, y8-30 | Limestone curtain, gatehouse, keep, convent range | Truce hall, chapel, cellar |
| East fields | x82-90, y20-48 | Wet pasture | Rebel camp edge in phase A |

Landmarks (stable anchor ids; existing greybox anchors in bold): **`landmark_gatehouse`**, **`landmark_central_keep`**, **`landmark_limestone_tower`**, `landmark_truce_hall`, `landmark_castle_chapel`, `landmark_market_cross`, `landmark_refugee_field`, `landmark_castle_well`, `landmark_forecourt_smithy`, `landmark_mud_ford`.

Journey edges (existing transitions, all `alignment=travel`): `road_to_kanavere` (west), `road_to_sojamae` (centre), `road_to_parnu` (east). Proposed: none new. The greybox's three roads converge at one gate, a deliberate narrowing.

## 4. Architecture and built environment

- **Order castle type:** a convent-castle in the Prussian-Livonian manner: rectangular curtain around a court, keep-tower, chapel, chapter hall/refectory, dormitory, cellars. Limestone rubble with dressed quoins, lime-washed render, steep shingle roofs, stepped gables. Defines the shared kit `asset.kit.limestone_castle` (section 9.1).
- **Truce hall:** a vaulted ground-floor hall (two bays, four ribbed vaults on one pier, narrow lancets) used for envoys; plain, cold, benches in two rows, one high table. `plausible composite`.
- **Market settlement:** timber block-and-log houses, plank stalls, turf and straw roofs, a wooden parish chapel; clay-packed street. Unlike Pärnu (river timber warehouses) and Padise (dispersed estate).
- Construction state: sound and clean. This is the one fully functioning stone fortress in the five pages; the contrast with Pöide's later ruin and Padise's ash is intended.
- Refugee tents, handcarts, hurdles and cattle pens in the market field give a temporary layer, removable by phase.

## 5. Cultures, languages, and people

| Group | Language | Wardrobe / notes |
|---|---|---|
| Order brothers (knights, priest-brothers, sergeants) | Middle High German / Low German; Latin for liturgy and treaty text | White mantle with black cross (knights), grey or brown sergeants, chain under surcoat; shaved or cropped hair |
| Order servants, smiths, stable hands | Estonian (Järva dialect) with working German | Undyed wool, leather apron, felt cap |
| Market townsfolk, traders | Estonian, Low German, some Russian words from Novgorod carters | Brown and blue-dyed wool, linen coifs |
| Refugees from Harju / Järvamaa | Estonian (North Estonian dialects) | Mud-stained, patched, carrying sacks and icons-by-habit |
| Rebel envoys (game kings, bodyguard, skald) | Estonian | Best clothes, silver brooches, fur trim |

Religion: Latin Catholic rite inside; village belief outside the gate (oath-stones, spring offerings, `folklore`). Customs: truce formulae, oaths on relics, hospitality law broken by the Order. Names: Estonian forenames (see [`estonian-forenames-harju-1340s.md`](../../history/dossiers/language/estonian-forenames-harju-1340s.md)), Order brothers by Westphalian-Rhenish place names.

## 6. Factions present

| Faction id | Presence | Wants here | Where | Act-by-act |
|---|---|---|---|---|
| `livonian_order` | Dominant | End the rising by decapitation; show authority | Inner castle, forecourt | Act 2: host; Act 3: occupier, requisitions, source of forced-forge orders |
| `harju_kings` | Envoys, a camp outside | Treaty, Swedish backing, recognition | East fields, truce hall | Act 2: arrive in good faith; killed; Act 3: martyr symbols |
| `cult_metsik` | Marginal | Read omens; a seer in the refugee field | Refugee field | Act 2: warning source; Act 3: martyr cult grows |
| `hanseatic` | Small | Keep roads open, supply the garrison | Market | Constant; quiet price-setter |
| `black_cloaks` | Hidden | Carry warnings, spy on garrison | Market, smithy | Act 2: courier cell; Act 3: dispersed |
| `danish_crown` | Absent | Their duchy is being left behind | Rumour only | Sold 1346; mention in dialogue |
| `pskov_novgorod`, `vitalienbruder`  | Absent | Rumours, carters only | Market | None |

## 7. Characters

| char id | Name | Role / faction | Language | Confidence | Source | Hook |
|---|---|---|---|---|---|---|
| `char.burchard_von_dreileben` | Master Burchard von Dreileben | Livonian Master, host | MHG, Latin | `attested` (person); portrayal `plausible composite` | legacy [`master_burchard_von_dreileben.md`](../../characters/order/master_burchard_von_dreileben.md) | Presides; never seen with a weapon |
| `char.goswin_von_herike` | Brother Goswin von Herike | Senior brother, garrison manager | MHG | Person `attested` (later Master); 1343 post unverified | legacy [`brother_goswin_von_herike.md`](../../characters/order/brother_goswin_von_herike.md) | Practical enforcer; the player's contact if complicit |
| `char.brother_hermann` | Brother Hermann | Order handler | MHG, Latin | `plausible composite` | existing [`brother_hermann.md`](../CHARACTERS/brother_hermann.md) | Arranges the player's access; Act 3 forced-forge face |
| `char.lembit_helme` | Lembit Helme | Elder King | Estonian | `invented` | legacy [`lembit_helme.md`](../../characters/rebels/lembit_helme.md) | Suspects, goes anyway |
| `char.juri_ratnik` | Jüri Ratnik | Aggressive king | Estonian | `invented` | legacy [`juri_ratnik.md`](../../characters/rebels/juri_ratnik.md) | Wants to fight on the hall floor |
| `char.urmas_laar` | Urmas Laar | Seer | Estonian | `invented` | legacy [`urmas_laar.md`](../../characters/rebels/urmas_laar.md) | Reads the mud and the birds |
| `char.kaja` | Kaja | Courier | Estonian | `invented` | existing [`kaja.md`](../CHARACTERS/kaja.md) | Delivers or fails a warning |
| `char.apprentice` / `char.kalev` | Apprentice / Kalev | Protagonists | Estonian | `invented` | existing [`apprentice.md`](../CHARACTERS/apprentice.md), [`kalev.md`](../CHARACTERS/kalev.md) | Kalev: Order smithy work; Apprentice: spirit-world sight |
| `char.paide_interpreter` | Tolk Ludolf | Order interpreter | German, Estonian | `invented` (NEW) | NEW | Chooses what to translate |
| `char.paide_scribe` | Brother Ancelm | Scribe | Latin | `invented` (NEW) | NEW | Writes the official account; evidence thread |
| `char.paide_smith` | Reinold the castle smith | Order smith | German, Estonian | `plausible composite` (NEW) | NEW | Forge rival or ally |
| `char.paide_refugee_midwife` | Maret of Koeru | Refugee healer | Estonian | `invented` (NEW) | NEW | Intelligence on rebel camps |

Crowd archetypes: Order sergeant-at-gate, refugee mother with cart, wood-hauler, market fishwife (dried fish from the lakes), mounted courier, castle cook, stable boy, truce-day onlooker.

## 8. Quests, encounters, and discoveries

| id proposal | Act | Type | Hook | Ties |
|---|---|---|---|---|
| `quest.paide_truce_day` | 2 | investigation | Gather what the Order is setting up in the hall before the talks; decide whom to tell | `mission.act2.paide`, `faction.harju_kings` |
| `quest.paide_warning_ride` | 2 | travel event | Race from Sõjamäe road to reach the kings' camp before they enter | Kaja; survivor flags from Kanavere/Sõjamäe |
| `quest.paide_hall_witness` | 2 | spirit-world | Apprentice sees the room's past and future; learns what can be changed (nothing) and what can be preserved (names, testimony) | ADR 0033 |
| `quest.paide_castle_smithy` | 2-3 | forge commission | Reinold needs a hinge or bar mended; the bar locks a door | [`quest.forced_forge`](../QUESTS.md) pattern |
| `quest.paide_testimony` | 3 | exploration | Collect the account from refugees, scribe and servants before the official version hardens | Act 3 opening flags |
| `quest.paide_cellar_ledger` | 3 | night mission | Retrieve the garrison ledger from the cellar | Order standing |

Sights (journal pages): (1) the Paide keep as a visible landmark from 8 km, `plausible composite`; (2) Order seal and mantle regulation, `attested` type; (3) refugee cart-marks scratched on the market cross, `invented`; (4) the interpreter's tally sticks, `plausible composite`; (5) the lime-wash recipe on the chapel wall, `plausible composite`.

## 9. Resources: what must be generated

This page owns the shared kit and the Order wardrobe set cited by Pöide, Padise (stone masonry fragments only) and Pärnu (garrison).

### 9.1 Structures and architecture

| Asset id | Description | Pri | Shared with | Notes |
|---|---|---|---|---|
| `asset.kit.limestone_castle` | **Shared kit** (modular GLB set, snapped to 1 m grid, 4 damage states `pristine`, `scarred`, `burnt`, `slighted`; all parts accept `.limestone_rubble_quoin` material and optional lime-wash overlay) | P1 | Pöide, Padise (masonry fragments), Pärnu (bishop's/Order tower) | Evidence: Order convent-castle typology; Estonian Paide, Karksi, Viljandi in later ruin states, used for types only |
| `asset.kit.limestone_castle.curtain_wall` | Rubble wall segments 6 m, 3 heights, rampart walk, stepped crenel-free parapet | P1 | Pöide | No gunports |
| `asset.kit.limestone_castle.gatehouse` | Square gate tower, portcullis slot, timber drawbridge, murder-hole | P1 | Pöide | Replaces greybox gatehouse |
| `asset.kit.limestone_castle.keep_tower` | Tall rectangular keep, high door, corner turrets, timber hoarding option | P1 | Pöide (low variant) | Paide: tallest; Pöide: squat |
| `asset.kit.limestone_castle.convent_range` | Two-storey range with lancets, vaulted ground floor, dorter above | P1 | Pöide | Truce hall and refectory interiors use it |
| `asset.kit.limestone_castle.chapel` | Single-nave chapel, apse or flat east, tiny bell turret | P2 | Pöide | |
| `asset.kit.limestone_castle.corner_turret` | Round or square wall turret | P2 | | |
| `asset.kit.limestone_castle.well_house` | Covered well with windlass | P3 | Padise | |
| `asset.mat.limestone_rubble_quoin` | Rubble with squared corner stones, mortar joints | P1 | all | Pre-existing Reval limestone materials may be reused ([`MATERIAL_STYLE_LOCK_KIT.md`](../MATERIAL_STYLE_LOCK_KIT.md)) |
| `asset.paide.market_settlement` | 12 timber house variants, stalls, market cross, wood chapel | P2 | Pärnu (stalls) | Plain log and plank |
| `asset.paide.forecourt_service` | Stable, granary, smithy, kitchen shed | P2 | | |
| `asset.paide.earth_bank_palisade` | Ditch, bank, palisade, timber bridge | P2 | Pöide | |

### 9.2 Props and craft objects

| Asset id | Description | Pri | Shared with | Notes |
|---|---|---|---|---|
| `asset.prop.order_seal_matrix` | Seal matrix and wax | P2 | Pöide | Type evidence only |
| `asset.prop.relic_oath_casket` | Relic casket for oaths | P2 | Padise | |
| `asset.prop.truce_table_set` | High table, benches, wax tablet, stylus | P1 | | |
| `asset.prop.order_banner_white_cross` | White banner with black cross (cloth sim, [`FLAG_CLOTH.md`](../SYSTEMS/FLAG_CLOTH.md)) | P1 | Pöide | |
| `asset.prop.refugee_bundle_cart` | Handcart, sacks, hurdles, cooking pot | P2 | Pärnu | |
| `asset.prop.tally_stick_set` | Notched tally sticks | P3 | Pärnu | |
| `asset.prop.estonian_silver_brooch` | Kings' brooches (penannular, 14th-c. type) | P2 | Saaremaa | Types only |

### 9.3 Characters

| Asset id | Description | Pri | Shared with | Notes |
|---|---|---|---|---|
| `asset.char.wardrobe.order_knight_brother` | White mantle, black cross, hauberk, surcoat, arming cap | P1 | Pöide, Pärnu | One rig plus wardrobe ([`CHARACTER_GENERATION.md`](../CHARACTER_GENERATION.md)) |
| `asset.char.wardrobe.order_priest_brother` | White habit, tonsure | P1 | Pöide | |
| `asset.char.wardrobe.order_sergeant` | Grey surcoat, brigandine-free | P1 | Pöide, Pärnu | |
| `asset.char.wardrobe.order_scribe` | Ink-stained habit, wax tablet | P2 | | |
| `asset.char.wardrobe.estonian_noble_envoy` | Fur-trimmed coat, brooch | P2 | | |
| `asset.char.wardrobe.refugee_set` | Mud-stained peasant outfits (6 variants) | P1 | Pärnu, Padise | |
| Hair/beard: `asset.char.hair.tonsure`, `.close_crop_knight`, `.braid_women` | | P2 | | |

### 9.4 Fauna

| Species | Status | Notes |
|---|---|---|
| Horse (`fauna.horse`), dog, cattle, sheep, pig, chicken, goose | already cataloged | Cattle pens in refugee field |
| Hooded crow, rook, jackdaw, lapwing, skylark, white-tailed eagle | already cataloged | Rooks on the keep |
| Warhorse (destrier heavier variant) `asset.fauna.horse_destrier` | missing | P2 |
| Hunting hound `asset.fauna.hound_greyhound` | missing | P3 |

### 9.5 Flora and ground cover

Existing: `tree.alder`, `tree.willow`, `tree.birch`, `plant.reed`, `plant.nettle`, `crop.rye`, `crop.barley`, `grass.short`, `plant.burdock`. Missing: `plant.marsh_marigold` (caltha, spring flood meadow) P3.

### 9.6 Materials, terrain, water

`asset.terrain.clay_mud_spring` (churned wet clay, puddles, wheel ruts) P1; `asset.terrain.thawing_snow_patches` P3; shallow ditch water P2 (shared with Pärnu water shader work).

### 9.7 Audio and music direction

Languages heard: Middle High German commands, Latin office (Compline, bells), Estonian whispers, Russian words from carters. Ambience: wind on open plain, rooks, bells of castle chapel, rope creak of drawbridge, mud footfalls, silence in the hall. Music: no battle music; thin plainchant (monophonic), low drone strings, one lament for kannel later. Instruments (period): vielle, portative organ for the Order liturgy, kannel (`plausible composite`). Existing SFX policy: [`SOUND_EFFECTS_TOP_100.md`](../SOUND_EFFECTS_TOP_100.md).

## 10. Variety signature and risks

- **Palette:** cold white-grey limestone, black cross, wet brown clay, grey sky.
- **Silhouette:** one tall keep above flat land and a low timber town.
- **Soundscape:** bells, Latin, Low German, mud, then silence.
- **Massacre handling:** the killing of the Four Kings is staged as consequence, not spectacle. The hall is shown before and after; the act itself is off-screen or seen through a door crack, a witness's face, a sound. No gore close-ups, no victim-as-prop. Journal entries record names (game composites), burial, and what the official account omitted. The Order is shown as rule-bound people doing a calculated thing, not cartoon villains.
- **Anachronism:** no ruined castle, no Tall Hermann form, no windmills, no gunpowder. Mark keep height as `plausible composite`.
- **Scope:** existing prototype, but the 90x56 widening is a scope change for this node only; keep greybox size if the budget requires.
- **Performance:** one tall keep plus two crowd zones; chunk the market settlement.
- **Open questions:** (1) Is the Paide killing before or after Kanavere/Sõjamäe in the player-visible journal? (2) Should Goswin appear at all in 1343? (3) Can the player prevent any death? (default: no.)

## 11. Sources and next steps

Repo: [`CANON.md`](../CANON.md), [`TOURIST_LANDMARKS.md`](../TOURIST_LANDMARKS.md), [`global_map_mockups.md`](../reports/global_map_mockups.md), [`p5_001_act2_design.md`](../reports/p5_001_act2_design.md), [`p6_001_act3_design.md`](../reports/p6_001_act3_design.md), [`four_kings_act2_lore.md`](../lore/four_kings_act2_lore.md), [`livonian_order.md`](../CITIZENS/factions/livonian_order.md), [`paide_castle.md` (legacy)](../../scenes/world/paide_castle.md). External by name: Hermann de Wartberge, *Chronicon Livoniae*; Livonian Order castle typology literature; Estonian National Heritage Board register for Paide castle.

Verification tasks: (1) confirm Paide castle phases for 1343 with an archaeological source; (2) confirm Goswin von Herike's career; (3) author blueprint `paide_castle` through `MapBlueprint` per [`MAP_AUTHORING.md`](../MAP_AUTHORING.md); (4) review the kit with the Pöide page for shared parts; (5) sensitivity pass on the hall scene.
