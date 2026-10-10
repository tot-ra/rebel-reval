# Tartu (Dorpat, Terra Mariana / Bishopric of Dorpat)
**Status:** planned (design proposal, not implemented) · **Scope gate:** new (needs ADR + task) · **Act(s):** Act 2 (late Apr-May 1343, rumour and envoy hub), Act 3 (1343-1346, optional journey node)
**Map id:** `loc.world_tartu` (proposed; no `content/maps/` file yet) · **Seasons/phases:** late spring (thaw, high Emajõgi, river-ice gone), early summer; day/dusk phases; no night mission proposed
**Confidence summary:** seat of the Bishopric, Toome hill, Emajõgi crossing and Pskov trade road `attested`; cathedral under Gothic brick construction in the 1340s `plausible composite`; wooden bridge, toll, Russian quarter and Orthodox presence `plausible composite`; named NPCs mostly `invented` or archived legacy seeds; all quest hooks `invented`.

## 1. Why a player would want to visit
- A different material world from Reval: red-brown **brick** instead of pale limestone, a river instead of a sea, a hill crowned by a half-built cathedral.
- The only node where the **Orthodox East** and the **Hanseatic West** share one street: wax, furs and salt change hands at a toll bridge.
- Safe ground for information play: the Bishop, a Hanseatic factor and a Pskov wax-buyer all want the same letter; the player carries it.
- Learn how the rising looks from a bishop's side: Dorpat feared Pskov more than the rebels (see the legacy bishopric README, section 2).
- **Signature:** a brick cathedral going up on a hill above a timber toll bridge, with cranes, lime smoke and two languages of prayer in earshot.
- Framed as a compact "bishop's hill + riverside market" node, not a full city. No town-wall circuit, no guild halls, no university (the university is 1632 and is an anachronism).

## 2. History in 1343
| Claim | Label | Note |
|---|---|---|
| Dorpat is the seat of a prince-bishopric from 1224 (first bishop Hermann von Buxhövden) | `attested` | Legacy summary in [../../characters/bishopric_dorpat/README.md](../../characters/bishopric_dorpat/README.md) |
| Toome hill (Domberg) holds the cathedral precinct and bishop's residence | `attested` (hill, seat); building state `plausible composite` | Gothic brick cathedral phase 14th-15th c.; exact 1343 state unverified |
| Dorpat is a Hanseatic town and intermediary in the Pskov/Novgorod trade | `attested` | Wax, furs, honey west; cloth, salt, wine east |
| Wooden bridge and toll on the Emajõgi east road | `plausible composite` | Listed in [../TOURIST_LANDMARKS.md](../TOURIST_LANDMARKS.md) #44; no stone bridge in 1343 |
| Russian merchants with a small Orthodox chapel or prayer house | `plausible composite` | Reval has a Novgorod court (see [../CITIZENS/factions/pskov_novgorod.md](../CITIZENS/factions/pskov_novgorod.md)); Dorpat equivalent unverified |
| Stone latrines in Tartu c.1335 | `attested` (as comparandum only) | [../CANON.md](../CANON.md) line on latrines; use as detail, not plot |
| Pskov force enters the bishopric, reaches Otepää 26 May 1343 | `attested` | [../CANON.md](../CANON.md); Tartu is the *threatened* seat, not a battlefield |
| Bishop in spring 1343 | **unverified** | Legacy roster names Johann I von Vifhusen "from 1343". Real chronology of Dorpat bishops around 1341-1346 is unverified in-repo; treat the name as a legacy seed, label `plausible composite` |

**Phases.** Act 2 early: nervous, gates watched, merchants hoard. Act 2 after 26 May: Pskov turns back; the Bishop's relief is mixed with fear of the Order's price. Act 3: quiet trade recovers; the Bishop's ties to the Order and to the 1346 sale of Estonia are background.

**Do NOT show:** a university, a Gustavus-era or 19th c. bridge, the ruined Domberg of later centuries, late-medieval Great Gothic towers, the Russian Old Believers (17th c.), Jaani church terracotta figures as finished (14th-15th c. dating unverified), any Hanseatic guild hall with a named late facade, gunpowder artillery.

## 3. Landscape and layout
**Biome:** river valley with a glacial hill, riverside meadow and alder carr, hazel and oak groves on slopes, rye and barley fields beyond; mild continental climate. Colder and drier than Reval; fewer sea birds, more river and meadow birds.

Proposed map `loc.world_tartu`, **96 x 32 cells** (same cell scale as the other greybox travel maps: 32 px cells, see [../../content/maps/world_poide.rrmap](../../content/maps/world_poide.rrmap)).

| Zone | Cells (x y w h) | Terrain | Purpose |
|---|---|---|---|
| Emajõgi river | 0 12 96 6 | river water, mud banks | Divides map; ford marks, ferry, rafts |
| Toome hill precinct | 8 1 34 14 | packed earth, brick paving, scaffold floors | Cathedral works, bishop's residence, canon houses |
| Hill slope path | 38 8 10 8 | dirt, steps | Link between precinct and market |
| Riverside market | 44 17 30 10 | cobble, timber boardwalk | Stalls, weigh-house, toll booth |
| Bridge | 50 11 14 8 | timber deck on piles | Toll gate, bridge-keeper |
| Russian row | 74 18 16 9 | dirt, plank walks | Merchant yards, wax store, chapel |
| East road | 90 20 6 6 | gravel road | Exit toward Pskov / Otepää |
| West road and brickyard | 0 22 30 8 | clay pits, drying racks, kiln | Brick and lime supply; exit toward Viljandi/Paide |

**Anchors (stable ids, proposed):** `landmark_cathedral_works`, `landmark_bishop_hall`, `landmark_emajogi_bridge`, `landmark_toll_booth`, `landmark_weigh_house`, `landmark_russian_chapel`, `landmark_brickyard`, `landmark_mill_row`, `landmark_hill_stair`.

**Journey edges (explicit loading, none seamless):**
| Edge id | From cell | To | Alignment |
|---|---|---|---|
| `road_to_viljandi` | 0 24 | `loc.world_viljandi` | travel |
| `road_to_paide` | 20 30 | `loc.world_paide` | travel (proposes an edit to an existing map: out of scope here) |
| `road_to_frontier` | 90 22 | `loc.world_frontier_ugandi` | travel |
| `road_east_to_pskov` | 95 20 | off-map; narrative gate only | closed boundary, no Pskov map |

## 4. Architecture and built environment
- **Brick-gothic cathedral works** (see `asset.kit.brick_gothic_church` in 9.1): choir and part of the nave standing, upper walls and roof incomplete, putlog holes and timber scaffolding. Gothic brick, not limestone: this is the visual opposite of Reval's limestone churches.
- **Bishop's residence on the hill:** a fortified two-storey brick-and-fieldstone hall, small tower, curtain of palisade and stone; **not** a Gothic castle.
- **Market and river houses:** timber and half-timber, one or two storeys, reed or shingle roofs, plank boardwalks over mud; a few brick merchant gables near the bridge.
- **Bridge and toll:** long timber pile bridge, a gate hut at each end, chain or bar for the toll; chain-tied rafts.
- **Russian row:** log (not half-timber) houses with carved eaves, a small timber chapel with an onion-less pitched roof or tent roof (period unverified; label `plausible composite`), wax warehouses.
- **Mills:** timber water-mill line on a side channel ([../TOURIST_LANDMARKS.md](../TOURIST_LANDMARKS.md) #60).
- **Distinguishing features vs other nodes:** brick, logs and boardwalks; no sea; cathedral scaffolding; no limestone castle.

## 5. Cultures, languages, and people
| Group | Language | Wardrobe | Notes |
|---|---|---|---|
| Bishop's household, canons | Latin (liturgy), Middle Low German | clerical black/crimson, tonsure | Cathedral chapter governs; legacy Bishop wears chainmail under robes |
| Hanseatic merchants | Middle Low German | wool houppelande, hood, belt purse | Dorpat trade with Pskov |
| Local Estonian townspeople, labourers | **South Estonian (Tartu dialect, label `plausible composite`)** | undyed wool, linen, bast shoes | Distinct from Reval's North Estonian; render in audio and dialogue tags |
| Russian merchants | Old Pskov/Novgorod Russian | kaftan, fur cap, fur-edged cloak | Orthodox rite, fasting days |
| Order knights passing through | Middle Low German | white mantle, black cross | A few, not a garrison |
| Brick-makers, masons | Low German and Estonian | leather aprons, caps | Masons' marks, lodge life |

**Religion.** Latin Christianity dominates; a small Orthodox presence among Russian guests; Estonians keep folk custom (hiis sites are outside the map, see [../../history/dossiers/folklore/belief-omens-and-healing.md](../../history/dossiers/folklore/belief-omens-and-healing.md)). **Customs:** toll paid in coin or wax; fasting days affect Russian stalls; feast calendar in [../../history/dossiers/religion/liturgical-calendar-spring-1343.md](../../history/dossiers/religion/liturgical-calendar-spring-1343.md).

**Names:** German (Rutenberg, Löwenwolde), Estonian single names with baptismal Christian names, Russian name plus patronymic (Gavril Ivanovich).

## 6. Factions present
| Faction id | Presence here | Wants | Where | Act-by-act |
|---|---|---|---|---|
| `hanseatic` | Strong | Toll-free bridge, safe road, cheap wax | Market, bridge, weigh-house | A2 fearful; A3 recovering |
| `livonian_order` | Moderate (envoys, not garrison) | Control over Bishop's castles; price for aid | Bishop's hall | A2 sends emissary; A3 pressure on Bishop |
| `pskov_novgorod` | Quiet (merchants, one envoy) | Open bridge, leverage on Bishop | Russian row | A2 tense; A3 trade resumes |
| `danish_crown` | Minimal | Counterweight to Order (informal) | Hill | A2 envoy; ends with 1346 sale (background) |
| `harju_kings` | Hidden sympathisers | Supplies, southern allies | Brickyard, mills | A2 secret courier; fades after Sõjamäe |
| `black_cloaks` | Courier link only | Pass messages south | Market | A2 one-off |
| `cult_metsik` | Offstage (folklore only) | None on-map | Outside map | rumours |
| `vitalienbruder` | None | none | none | none |
| Bishopric of Dorpat | Local power, **not a launch faction** (ADR 0017 candidate line) | Survive between Pskov and Order | Whole hill | See section 2 |
| `church` (affinity) | Strong | Finish the cathedral | Cathedral works | all acts |

## 7. Characters
| char id | Name | Role / faction | Language | Confidence | Source | Hook / quest use |
|---|---|---|---|---|---|---|
| `char.johann_von_vifhusen` | Prince-Bishop Johann I von Vifhusen | Bishop of Dorpat | German, Latin | `plausible composite` (bishop chronology unverified) | legacy: [../../characters/bishopric_dorpat/prince_bishop_johann.md](../../characters/bishopric_dorpat/prince_bishop_johann.md) | Gives the player a sealed letter; wants proof of Pskov plans |
| `char.klaus_von_rutenberg` | Klaus von Rutenberg | Hanseatic factor, Dorpat-Reval | German | `invented` (legacy) | legacy: [../../characters/bishopric_dorpat/klaus_von_rutenberg.md](../../characters/bishopric_dorpat/klaus_von_rutenberg.md) | Buys information; wants a Black Cloak courier caught |
| `char.brother_andreas` | Brother Andreas | Cathedral scribe, folklorist | Latin, German, Estonian | `invented` (legacy) | legacy: [../../characters/bishopric_dorpat/brother_andreas.md](../../characters/bishopric_dorpat/brother_andreas.md) | Shows a hidden wordlist; secret ally of the Apprentice |
| `char.matthias_von_lowenwolde` | Sir Matthias von Löwenwolde | Order knight, envoy | German | `invented` (legacy) | legacy: [../../characters/bishopric_dorpat/sir_matthias_von_lowenwolde.md](../../characters/bishopric_dorpat/sir_matthias_von_lowenwolde.md) | Names a price for the Order's help |
| `char.voivode_grigori` | Voivode Grigori of Pskov | Pskov envoy (tone only; Prince Ivan is the attested name) | Russian | `invented` (legacy) | legacy: [../../characters/bishopric_dorpat/voivode_grigori.md](../../characters/bishopric_dorpat/voivode_grigori.md) | Appears at the bridge as emissary; never leads an army on-screen |
| `char.tartu_master_mason` | Meister Everhard | Cathedral master mason | German | `invented` NEW | NEW | Asks Kalev for iron tie-rods and mason's tools; forge commission |
| `char.tartu_toll_reeve` | Toll reeve Jaan | Bridge toll keeper | South Estonian | `invented` NEW | NEW | Lets a cart through for a price; moral choice |
| `char.tartu_wax_factor` | Gavril Ivanovich | Pskov wax merchant | Russian | `invented` NEW | NEW | Pays for a letter; sells holy wax candles |
| `char.tartu_priest_nikola` | Priest Nikola | Orthodox chapel priest | Church Slavonic, Russian | `invented` NEW | NEW | Dialogue on faith; reads icon |
| `char.tartu_brick_burner` | Old Kasper | Brickyard foreman | South Estonian | `invented` NEW | NEW | Hides rebel courier among bricks |

**Crowd archetypes:** bridge toll-clerk, brick carrier, lime-burner, wax chandler, fur packer, raft-man, canon's servant, mill hand.

## 8. Quests, encounters, and discoveries
| id (proposal) | Act | Type | Hook | Ties |
|---|---|---|---|---|
| `quest.tartu_tie_rods` | 2 | forge commission | Make iron tie-rods for the unfinished nave vault | Kalev forge loop (see [../CHARACTERS/kalev.md](../CHARACTERS/kalev.md)) |
| `quest.tartu_sealed_letter` | 2 | investigation | Carry the Bishop's letter past the Order and Pskov watchers | flag `flag.tartu_letter_delivered` (NEW) |
| `quest.tartu_wax_toll` | 2 | travel event | Smuggled wax shortfall at the bridge | `hanseatic`, `pskov_novgorod` ledger |
| `quest.tartu_brickyard_courier` | 2 | night-free exploration | Find a hidden rebel courier at the brickyard | `harju_kings`; must not become a battle |
| `quest.tartu_cathedral_spirits` | 3 | spirit-world | Echoes of builders in the unfinished vault | Apprentice clairvoyance (ADR 0033) |

**Sights (knowledge entries):** (1) masons' marks on brick; (2) construction crane with treadwheel; (3) Orthodox candle-wax stall; (4) South Estonian proverb at the mill; (5) view of the river from the hill.

## 9. Resources: what must be generated
### 9.1 Structures & architecture
| asset id (proposed) | Description | Priority | Shared with | Notes |
|---|---|---|---|---|
| `asset.kit.brick_gothic_church` | **Shared kit, defined here.** Modules: `.buttress_stepped`, `.lancet_window_tracery_simple`, `.nave_bay_open`, `.nave_bay_roofed`, `.choir_apse`, `.west_front_stump`, `.portal_stepped_brick`, `.gable_stepped`, `.scaffold_bay` (timber putlog), `.treadwheel_crane`, `.brick_pile`, `.lime_pit`, `.mason_lodge`. Brick bond: Klosterformat-like (about 28x13x8 cm, plausible composite), monk bond, lime mortar, selective limestone dressings for plinths and sills. Procedural decay and soot materials. | P1 | `loc.world_viljandi` (church ruin), possible later convent churches | Reference: Hanseatic brick-gothic of the Baltic coast, not Reval limestone. 1343 state unverified |
| `asset.tartu.bishop_hall` | Brick-and-fieldstone two-storey hall with small tower | P1 | none | legacy seat |
| `asset.tartu.timber_bridge_toll` | Long pile bridge with toll gate | P1 | `loc.world_frontier_ugandi` (ford variant) | see TOURIST #44 |
| `asset.tartu.river_houses` | Half-timber house kit | P2 | `loc.world_viljandi` | reed/shingle |
| `asset.tartu.russian_log_house` | Log house, carved eave | P2 | `loc.world_frontier_ugandi` | Pskov style |
| `asset.tartu.orthodox_chapel_timber` | Small timber chapel, tent or pitched roof | P2 | frontier | period unverified |
| `asset.tartu.brick_kiln` | Updraft kiln, drying racks | P2 | none | |
| `asset.tartu.mill_row` | Water-mill line | P3 | Viljandi | |

### 9.2 Props & craft objects
| asset id | Description | Pri | Shared | Notes |
|---|---|---|---|---|
| `asset.prop.wax_cake_stack` | Wax cakes with merchant marks | P1 | frontier | Russian trade |
| `asset.prop.fur_bale` | Sable, marten, squirrel bundles | P1 | frontier | |
| `asset.prop.mason_tools` | Trowel, plumb line, square, compass | P1 | none | forge commission |
| `asset.prop.brick_hod` | Brick carrier hod | P2 | none | |
| `asset.prop.icon_small_travelling` | Small painted wooden icon | P2 | frontier | `plausible composite` |
| `asset.prop.reliquary_brick_chapel` | Simple reliquary box | P3 | none | |
| `asset.prop.toll_tally_stick` | Notched tally sticks | P2 | Viljandi | |
| `asset.prop.scale_set` | Weigh-house scale and weights | P2 | Viljandi | |

### 9.3 Characters
| asset id | Description | Pri | Shared | Notes |
|---|---|---|---|---|
| `asset.wardrobe.canon_robe` | Canon/bishop crimson and black | P1 | `loc.world_viljandi` | one rig + MPFB per [../CHARACTER_GENERATION.md](../CHARACTER_GENERATION.md) |
| `asset.wardrobe.russian_merchant` | Kaftan, fur cap | P1 | frontier | |
| `asset.wardrobe.mason_apron` | Leather apron, hood | P1 | none | |
| `asset.wardrobe.south_est_peasant` | Distinct cut/embroidery | P2 | Viljandi, frontier | regional variant |
| `asset.hair.russian_beard_long` | Long square beard | P2 | frontier | |
| `asset.hair.tonsure` | Monastic tonsure | P2 | Viljandi | |

### 9.4 Fauna
| species | Status | Notes |
|---|---|---|
| `fauna.horse`, `fauna.dog`, `fauna.cat`, `fauna.rat` | already cataloged | street life |
| `fauna.chicken` | cataloged | market |
| `fauna.otter`, `fauna.beaver` | cataloged | riverbank |
| `bird.grey_heron`, `bird.mallard`, `bird.barn_swallow` | cataloged | river |
| `bird.common_sandpiper`, `bird.kingfisher` | MISSING | river specialists |
| `fauna.cow`, `fauna.sheep`, `fauna.goose_domestic`, `fauna.ox` | MISSING (check catalog before building) | market and brick-cart oxen |
| `fauna.pig` | MISSING | |

### 9.5 Flora & ground cover
| id | Status | Notes |
|---|---|---|
| `tree.oak`, `tree.linden`, `tree.alder`, `tree.willow`, `tree.hazel`, `tree.ash` | existing | slope and bank |
| `plant.reed`, `plant.cattail`, `plant.nettle`, `plant.burdock` | existing | bank |
| `crop.rye`, `crop.barley`, `crop.flax`, `crop.hemp` | existing | fields |
| `plant.meadowsweet`, `plant.marsh_marigold` | MISSING | river meadow, spring colour |
| `ground.brick_dust`, `ground.lime_slurry` | MISSING | site decals |

### 9.6 Materials / terrain / water
| id | Description | Pri | Shared |
|---|---|---|---|
| `mat.brick_red_weathered` | Red-brown brick with lime joint | P1 | Viljandi |
| `mat.clay_wet` | Clay pit, wet mud | P2 | none |
| `mat.river_brown_slow` | Slow brown river with ripples | P1 | frontier |
| `mat.timber_weathered_pine` | Grey plank | P2 | all |
| `mat.boardwalk_wet` | Wet plank decals | P3 | none |

### 9.7 Audio & music direction
Languages heard: German, South Estonian, Russian, Latin chant. Ambient: hammering on brick, lime-slaking hiss, creaking treadwheel, river flow, bridge boards, church bell (single). Instruments: chant, vielle, a Russian gusli (period plausibility unverified, label `plausible composite`), pipe. Music mood: cool, patient, sacred-industrial; avoid battle cues.

## 10. Variety signature and risks
- **Palette:** red-brown brick, grey timber, green river light. **Silhouette:** cathedral stump with cranes on a hill. **Sound:** hammering plus river plus two prayers.
- **Risks:** anachronism (university, tall spires, stone bridge); scope (new city-like map); performance (brick kit instancing); sensitivity (religious difference, Pskov as "enemy"; present Orthodox merchants as neighbours, not villains); do not turn the Bishop into a villain by default.
- **Open questions:** Bishop name and date; whether Russian row existed in 1343; whether to depict the cathedral as brick or mixed.
- **Scope gate.** This node is new and would need its own ADR. Candidates to compress or replace: the inactive "Swedish/Pskov event shells" and the generic southern-travel slot currently held by `loc.world_parnu` ([../../content/maps/world_parnu.rrmap](../../content/maps/world_parnu.rrmap), "southern campaign town"). Option A: replace Pärnu's role as the southern stop with Tartu (net zero new maps). Option B: keep Pärnu, cut a rural travel event per Tartu visit, and ship Tartu as a single-quest-line node with only 3 quests from section 8. Option C: drop Tartu and cover its three storylines through a Reval Hanseatic merchant visit. The maintainer decides; this page assumes A or B. Brick kit can be reused by Viljandi and the later convent.

## 11. Sources and next steps
- Repo: [../CANON.md](../CANON.md), [../TOURIST_LANDMARKS.md](../TOURIST_LANDMARKS.md), [../reports/global_map_mockups.md](../reports/global_map_mockups.md), [../../history/HISTORY.md](../../history/HISTORY.md), [../../characters/bishopric_dorpat/README.md](../../characters/bishopric_dorpat/README.md), [../CITIZENS/factions/hanseatic.md](../CITIZENS/factions/hanseatic.md), [../CITIZENS/factions/church.md](../CITIZENS/factions/church.md), [../FLORA_FAUNA.md](../FLORA_FAUNA.md), [../CHARACTER_GENERATION.md](../CHARACTER_GENERATION.md).
- External (by name): Tartu Domberg archaeology and architectural histories; Hanseatic Dorpat trade records; Baltic brick-gothic surveys.
- Verification tasks: confirm Bishop of Dorpat chronology for 1343; confirm bridge, toll and Russian presence; confirm cathedral construction stage; check missing species against the fauna catalog; write ADR.
