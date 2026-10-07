# Otepää and Vastseliina Frontier (Odenpäh, Neuhausen, Ugandi borderland)
**Status:** planned (design proposal, not implemented) · **Scope gate:** new (needs ADR + task) · **Act(s):** Act 2 (late May 1343 emissary and rumour node), Act 3 (optional frontier return)
**Map id:** `loc.world_frontier_ugandi` (proposed; no `content/maps/` file yet) · **Seasons/phases:** late May 1343 (leaf-out, high lakes), early summer; dusk and dawn mist phases
**Confidence summary:** Pskov force under Prince Ivan reaching Otepää on 26 May 1343 `attested`; Order contact near Vastseliina `attested` in repo summary but chronology unverified; Vastseliina founded 1342 `attested` as a date, founder `unverified`; Otepää hillfort and bishop's castle `plausible composite` for state in 1343; Setu/Võru customs `plausible composite` or `folklore`; all named NPCs `invented` or legacy seeds.

## 1. Why a player would want to visit
- The **edge of the map**: pine and spruce forest, chains of lakes, hills; a place where the Latin West ends and the Orthodox East begins.
- A world of **border politics**: Pskov emissaries, bishop's men and Order scouts all meet; the player brokers or sabotages.
- A culture the rest of the game lacks: **Orthodox-leaning Estonians** (the later Setu and Võru), with a distinct dialect, song and dress.
- An atmospheric hillfort the player can climb for a view over lakes, with the older Estonian past under foot.
- **Signature:** an old hillfort and a timber castle rising on a frontier, lakes in morning mist, and a chain of voices in Russian, South Estonian and German.
- Compact node: hillfort and bishop's castle, a ford, a half-built border fort in the woods.

## 2. History in 1343
| Claim | Label | Note |
|---|---|---|
| A Pskov force under Prince Ivan enters the Bishopric of Dorpat and reaches Otepää on 26 May 1343, turns back on hearing Harju is suppressed | `attested` | [../CANON.md](../CANON.md), [../../history/HISTORY.md](../../history/HISTORY.md); wiki: [../../wiki/people/prince_ivan_of_pskov.md](../../wiki/people/prince_ivan_of_pskov.md) |
| Force size 5,000 in the repo summary | `plausible composite` | Source figure unverified; do not show an army |
| Order army intercepts near Vastseliina, both sides claim victory | repo summary `attested`; battle details **unverified** | Not a playable battle (CANON: not an alternate victory) |
| Vastseliina (Neuhausen) founded 1342 | `attested` (year); founder **unverified** (Bishopric of Dorpat per brief, Order sources differ) | Show an earth-and-timber fort under construction, not the later stone castle |
| Otepää has a hillfort and bishop's castle | `plausible composite` | Hillfort `attested` archaeologically; 1343 castle state unverified; "symbolic rally point" per [../TOURIST_LANDMARKS.md](../TOURIST_LANDMARKS.md) #49 |
| Lake Pühajärv ("holy lake") near Otepää | `plausible composite` | Medieval use of the name unverified |
| Meelis of Otepää as rebel leader | `invented` | Legacy seed |

**Phases.** Early (before 26 May): rumours, travellers fleeing. 26 May: the Pskov column halts; the player sees only the aftermath and envoys. After: bishop's men and the Order press the locals. Act 3: slow return to border trade.

**Do NOT show:** Petseri (Pechory) monastery (1473, anachronism), the later stone Vastseliina ruins and chapel, Old Believers, late Setu villages with 19th c. embroidery as period proof, the Setu "king" ceremonies (19th c. folklore) as medieval fact, ski resort tropes, gunpowder.

## 3. Landscape and layout
**Biome:** rolling morainic hills, kettle lakes, deep spruce-pine forest, bogs, small rye clearings, juniper meadows. Cold nights, mist, many frogs and cranes in spring.

Proposed map `loc.world_frontier_ugandi`, **100 x 34 cells**.

| Zone | Cells (x y w h) | Terrain | Purpose |
|---|---|---|---|
| Otepää hillfort | 6 4 24 16 | earth ramparts, stone footing, timber | Hillfort, bishop's tower, rally yard |
| Holy lake shore | 0 18 30 14 | water, reed, stone shore | Offering place, boats |
| Forest road | 30 12 30 10 | dirt, roots | Path with ambush-free encounters |
| Village clearing (Võru) | 40 22 20 10 | dirt, rye strips | Farmhouses, smoke saunas, meeting house |
| Setu hamlet | 62 4 18 12 | log, plank | Cross posts, icon corner, woman choir place |
| Border ford | 60 20 20 8 | river ford, gravel | Pskov emissary meeting |
| Vastseliina works | 82 6 18 18 | earth rampart, timber towers | Fort under construction |
| East track | 92 28 8 6 | track | Narrative exit toward Pskov |

**Anchors:** `landmark_hillfort_gate`, `landmark_bishop_tower`, `landmark_holy_lake_stone`, `landmark_forest_cross`, `landmark_setu_hamlet`, `landmark_border_ford`, `landmark_neuhausen_works`, `landmark_pskov_camp_site`.

**Journey edges:**
| Edge id | From cell | To | Alignment |
|---|---|---|---|
| `road_to_tartu` | 0 22 | `loc.world_tartu` | travel |
| `track_east_to_pskov` | 99 30 | off-map; narrative gate | closed boundary, no Pskov map |
| `road_to_viljandi` | 10 0 | `loc.world_viljandi` | travel (optional; proposes edit to another proposed map) |

## 4. Architecture and built environment
- **Hillfort:** earth rampart with palisade; a small bishop's stone tower or hall within; wooden gate-tower. State of the castle in 1343: `plausible composite`.
- **Frontier fort works (Vastseliina/Neuhausen):** timber palisade, earth bank, one stone footing, scaffolds, stacks of limestone and logs; unfinished.
- **Village:** log houses with smoke-hole or chimneyless smoke dwelling (see [../../history/dossiers/architecture/rural-smoke-dwelling-and-farmstead-1343.md](../../history/dossiers/architecture/rural-smoke-dwelling-and-farmstead-1343.md)); sheds on stilts for grain.
- **Setu hamlet:** compact yard cluster, wayside timber cross with small roof, icon shelf in the corner of a room (Orthodox form; period details `plausible composite`).
- **Wayside:** boundary posts, offering stones, simple chapel hut.
- **Distinctive vs other nodes:** no big masonry; earth, log, lakes. Contrast with Viljandi's castle and Tartu's brick.

## 5. Cultures, languages, and people
| Group | Language | Wardrobe | Notes |
|---|---|---|---|
| Võru Estonians | Võro / South Estonian (`plausible composite`) | wool, linen, bast shoes | Farmers, hunters |
| Setu-leaning Estonians | Early Setu speech (Orthodox-leaning, `plausible composite`) | white linen, silver breast brooch (period doubtful, label `folklore` for later forms) | Women's polyphonic song tradition has later documentation (`folklore`); the medieval depth is unverified |
| Pskov emissaries and guards | Old Pskov Russian | kaftan, fur cap, round shield | A small party |
| Bishop's men | Middle Low German | mail, bishop's colours | Garrison of a few |
| Order scouts | Middle Low German | white mantle | Rare, in tension |
| Hunters | Estonian | hides | Border knowledge |

**Religion.** Mixed: Catholic baptism by fiat in the bishop's lands; Orthodox leaning among some; old forest rites persist (`folklore`). Present Orthodox Estonians as ordinary people, not as exotic. **Customs:** offerings at stones and trees, dead-day meals, border boundary oaths.

## 6. Factions present
| Faction id | Presence | Wants | Where | Act change |
|---|---|---|---|---|
| `pskov_novgorod` | Emissaries and guards | Allies among rebels; trade; testing of Bishop | Ford, camp site | A2 arrives 26 May; A3 trade envoys |
| `livonian_order` | Scouts, then a column | Seal the border; curb Bishop | Fort works | A2 arrives after 26 May; A3 control |
| `harju_kings` | Local sympathisers | Southern uprising help | Village | A2 disappointed; A3 fade |
| `cult_metsik` | Hidden rite | Protect sacred lake | Holy lake | A2 spirit-world encounter |
| `hanseatic` | Minor traders | Pskov wax and fur route | Ford | A2 nervous |
| `danish_crown` | None | none | none | none |
| `black_cloaks` | Courier trace | Messages | Village | one dialogue |
| `vitalienbruder` | None | none | none | none |
| Bishopric of Dorpat | Local power, **not a launch faction** | Hold border | Hillfort | A2 fear |
| `church` (affinity) | Chapel priest | Keep baptisms | Chapel hut | A2 pressure |

## 7. Characters
| char id | Name | Role / faction | Language | Confidence | Source | Hook |
|---|---|---|---|---|---|---|
| `char.prince_ivan_of_pskov` | Prince Ivan of Pskov | Leader of the force (offscreen/arrival only) | Russian | `attested` (name), `invented` (dialogue) | wiki: [../../wiki/people/prince_ivan_of_pskov.md](../../wiki/people/prince_ivan_of_pskov.md) | Seen from afar; his envoy speaks |
| `char.meelis_of_otepaa` | Meelis of Otepää | Southern rebel leader | South Estonian | `invented` (legacy) | legacy: [../../characters/bishopric_dorpat/meelis_of_otepaa.md](../../characters/bishopric_dorpat/meelis_of_otepaa.md) | Wants Pskov alliance; tests the player |
| `char.voivode_grigori` | Voivode Grigori | Pskov envoy/commander | Russian | `invented` (legacy) | legacy: [../../characters/bishopric_dorpat/voivode_grigori.md](../../characters/bishopric_dorpat/voivode_grigori.md) | Offers false promises |
| `char.mihail_kolovrat` | Mihail Kolovrat | Pskov scout/advocate for commoners | Russian | `invented` (legacy) | legacy: [../../characters/pskov/mihail_kolovrat.md](../../characters/pskov/mihail_kolovrat.md) | Honest voice, warns about Grigori |
| `char.anisia_of_novgorod` | Anisia of Novgorod | Caravan girl (cameo, may appear if merged with Reval storyline) | Russian | `invented` | existing: [../CHARACTERS/anisia_of_novgorod.md](../CHARACTERS/anisia_of_novgorod.md) | Optional; carries a message |
| `char.frontier_bishop_vogt` | Vogt Dietrich | Bishop's castellan | German | `invented` NEW | NEW | Tries to bribe the player to spy on Pskov |
| `char.frontier_setu_elder` | Elder Marja | Orthodox-leaning village elder | Setu/Võro | `invented` NEW | NEW | Lends a boundary oath; shows song |
| `char.frontier_hunter` | Hunter Ott | Guide | Võro | `invented` NEW | NEW | Shows hidden path |
| `char.frontier_priest` | Father Hermanus | Catholic chapel priest | Latin, German | `invented` NEW | NEW | Debates with Elder Marja |

**Crowd:** fisher, charcoal-burner, bee-keeper (honey and wax), rafter, boundary-post carpenter, shepherd, ferryman, Pskov cook.

## 8. Quests, encounters, and discoveries
| id | Act | Type | Hook | Ties |
|---|---|---|---|---|
| `quest.frontier_forged_dispatch` | 2 | investigation | Compare a "Pskov" letter with the Order's seal marks; CANON allows forged-dispatch evidence | `pskov_novgorod`, `livonian_order` |
| `quest.frontier_emissary_escort` | 2 | travel event | Lead Pskov emissaries through the forest without meeting Order scouts | `flag.pskov_emissary_escorted` (NEW) |
| `quest.frontier_holy_lake` | 2 | spirit-world | Echoes of the hillfort's old defenders | Apprentice clairvoyance (ADR 0033) |
| `quest.frontier_neuhausen_hinges` | 3 | forge commission | Gate hardware for the fort works | Kalev loop |
| `quest.frontier_boundary_oath` | 3 | exploration | Mark a boundary stone with Elder Marja | `cult_metsik` flavour |

**Sights:** (1) hillfort rampart view; (2) wayside timber cross; (3) a woman's song heard at dusk (`folklore`); (4) honey hunters' hollow tree; (5) lake-stone offering place.

## 9. Resources: what must be generated
### 9.1 Structures & architecture
| asset id | Description | Pri | Shared with | Notes |
|---|---|---|---|---|
| `asset.frontier.hillfort_ramparts` | Earth rampart, ditch, palisade | P1 | none | procedural |
| `asset.frontier.bishop_tower` | Small stone tower, timber gallery | P1 | none | may reuse `asset.kit.order_convent_castle_brick` tower module, cited |
| `asset.frontier.fort_works_timber` | Timber fort under construction | P1 | none | Neuhausen 1342 |
| `asset.frontier.log_farmhouse_smoke` | Log farmhouse with smoke hole | P1 | Viljandi village (optional) | dossier |
| `asset.frontier.wayside_cross` | Roofed wooden cross | P1 | Tartu Russian row | |
| `asset.frontier.grain_stilt_shed` | Stilt shed | P2 | none | |
| `asset.frontier.border_post` | Boundary post and stone | P2 | none | |
| `asset.frontier.ford_crossing` | Ford with stepping stones | P2 | Tartu bridge variant | |

### 9.2 Props & craft objects
| asset id | Description | Pri | Shared | Notes |
|---|---|---|---|---|
| `asset.prop.icon_small_travelling` | cited from Tartu page | P2 | Tartu | |
| `asset.prop.beeswax_candle_bundle` | Wax candles | P2 | Tartu | |
| `asset.prop.honey_vessel` | Clay honey pot | P2 | none | |
| `asset.prop.linen_embroidered_towel` | White linen with simple red-thread | P2 | none | `plausible composite` for the 14th c. |
| `asset.prop.bast_shoe` | Bast footwear | P3 | none | |
| `asset.prop.forged_dispatch` | Letter with seal (clue) | P1 | none | quest prop |
| `asset.prop.birch_bark_scroll` | Birch-bark note | P2 | none | Novgorod usage `attested` in general; Pskov use `plausible composite` |
| `asset.prop.round_shield_rus` | Painted round shield | P2 | none | |

### 9.3 Characters
| asset id | Description | Pri | Shared | Notes |
|---|---|---|---|---|
| `asset.wardrobe.russian_merchant` | cited from Tartu page | P1 | Tartu | |
| `asset.wardrobe.pskov_guard` | Mail, kaftan, round shield | P1 | none | |
| `asset.wardrobe.vorro_peasant` | Võro dress | P1 | Tartu `asset.wardrobe.south_est_peasant` | |
| `asset.wardrobe.setu_elder_woman` | White linen, head cloth | P2 | none | caution on later anachronisms |
| `asset.wardrobe.hunter_hide` | Hide coat | P2 | Viljandi | |
| `asset.hair.russian_beard_long` | cited from Tartu page | P2 | Tartu | |

### 9.4 Fauna
| species | Status | Notes |
|---|---|---|
| `fauna.wolf`, `fauna.brown_bear`, `fauna.lynx`, `fauna.elk`, `fauna.red_deer`, `fauna.roe_deer`, `fauna.wild_boar`, `fauna.pine_marten`, `fauna.beaver` | cataloged | forest |
| `bird.white_tailed_eagle`, `bird.osprey`, `bird.common_buzzard`, `bird.tawny_owl`, `bird.great_spotted_woodpecker` | cataloged | forest and lakes |
| `bird.common_crane`, `bird.black_grouse`, `bird.capercaillie`, `bird.black_woodpecker` | MISSING | frontier signature |
| `fauna.honeybee_hive` (prop actor) | MISSING | bee-keeper |
| `fauna.ox`, `fauna.cow`, `fauna.sheep`, `fauna.pig`, `fauna.goat` | MISSING (shared with Tartu/Viljandi; define once) | farms |

### 9.5 Flora & ground cover
| id | Status | Notes |
|---|---|---|
| `tree.spruce`, `tree.pine`, `tree.birch`, `tree.aspen`, `tree.alder`, `tree.juniper`, `tree.rowan` | existing | forest |
| `bush.heather`, `bush.cranberry`, `bush.bog_rosemary`, `bush.juniper_shrub` | existing | bog, heath |
| `plant.moss`, `plant.fern`, `plant.reed`, `plant.cattail`, `plant.water_lily` | existing | forest floor, lakes |
| `plant.lingonberry`, `plant.bilberry`, `plant.cotton_grass`, `plant.sundew` | MISSING | bog and forest floor |
| `crop.rye`, `crop.barley`, `crop.flax` | existing | clearings |
| `ground.pine_needle_carpet` | MISSING | decal |

### 9.6 Materials / terrain / water
| id | Description | Pri | Shared |
|---|---|---|---|
| `mat.moraine_gravel_soil` | Gravel and thin soil | P1 | Viljandi ridge |
| `mat.lake_still_misty` | cited from Viljandi page | P1 | Viljandi |
| `mat.log_weathered_spruce` | Dark spruce log | P1 | Tartu |
| `mat.rampart_turf` | Grass-covered earth | P1 | none |
| `mat.bog_peat_water` | Peaty bog pool | P2 | none |

### 9.7 Audio & music direction
Languages heard: Old Pskov Russian, Võro, German, Latin, Church Slavonic fragments. Ambient: wind in pines, loons and cranes, frogs, distant axe, bees, ford splashing, boundary bell. Instruments: voice (unaccompanied chant), a simple gusli or zither (`plausible composite`), bagpipe-free; the polyphonic women's song is a later-documented tradition (`folklore`), so treat as inspiration and keep it modest. No war drums.

## 10. Variety signature and risks
- **Palette:** dark spruce green, lake silver, birch white, earth brown. **Silhouette:** hillfort mound with timber works. **Sound:** wind, cranes, a single sung line.
- **Risks:** anachronism (Petseri, later Setu culture, stone Vastseliina); sensitivity (ethnicity and religion: avoid exoticising Setu/Võru, avoid "Orthodox = traitor" framing); scope (a second border node beyond Tartu); performance (forest density with many trees).
- **Open questions:** who founded Vastseliina in 1342; whether Otepää had a bishop's castle in 1343; whether to merge Otepää and Vastseliina into one clearing.
- **Scope gate.** New node; needs ADR. It could replace or compress: the inactive legacy "Swedish/Pskov event shells" that [../reports/global_map_mockups.md](../reports/global_map_mockups.md) lists as archived concepts, and any Act 2 rural travel event or "Pskov emissary" beat now held in Reval. Options: (A) cut the map entirely and make the 26 May story a **single travel event** with one authored scene (cheapest); (B) fold it into **Tartu** as an eastern gate sub-zone (saves one map); (C) keep as a separate node and remove an equal-cost Act 3 node named in the ADR. CANON explicitly allows only "emissary news, forged-dispatch evidence, or world-travel colour" without opening Dorpat as a campaign city, so option A or B fits CANON best.

## 11. Sources and next steps
- Repo: [../CANON.md](../CANON.md), [../TOURIST_LANDMARKS.md](../TOURIST_LANDMARKS.md), [../../history/HISTORY.md](../../history/HISTORY.md), [../CITIZENS/factions/pskov_novgorod.md](../CITIZENS/factions/pskov_novgorod.md), [../../characters/bishopric_dorpat/README.md](../../characters/bishopric_dorpat/README.md), [../FLORA_FAUNA.md](../FLORA_FAUNA.md), [../CHARACTER_GENERATION.md](../CHARACTER_GENERATION.md).
- External (by name): chronicle accounts of the 1343 Pskov raid; Vastseliina and Otepää castle archaeology; Setu and Võru ethnography (later sources, caution).
- Verification tasks: confirm Vastseliina founder and year; confirm 26 May chronology and the Order engagement; confirm Otepää castle state; review ethnic and religious representation with a cultural reader; check missing species; write ADR.
