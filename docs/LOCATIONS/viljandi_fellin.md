# Viljandi (Fellin, Sakala county)
**Status:** planned (design proposal, not implemented) · **Scope gate:** new (needs ADR + task) · **Act(s):** Act 2 (rumour and echo mission), Act 3 (optional return, Order-pressure beat)
**Map id:** `loc.world_viljandi` (proposed; no `content/maps/` file yet) · **Seasons/phases:** late spring to early summer 1343; dusk and market-day phases; no battle phase
**Confidence summary:** Order castle at Fellin and the rye-sack attempt `attested` (chronicle tale, Renner); castle layout and 1343 construction state `plausible composite`; Hanseatic-linked market `plausible composite`; commander Goswin von Herike and all named NPCs `invented` (legacy seeds) except the Order Master `attested`; every quest `invented`.

## 1. Why a player would want to visit
- A **castle seen from below**: the player climbs a ridge between a lake and a deep valley to a convent castle, the strongest Order point in this part of the game.
- The famous **rye-sack tale** becomes an *echo mission*: the player does not win a battle; they replay, interrupt or listen to a doomed idea.
- A different Estonian region: Sakala, with lakes, ridges and dialect distinct from Harju.
- Teaches the player what the Order is like when it is **not** besieging: ledgers, grain tribute, a chapter-house, a commandery brewery.
- **Signature:** a brick-and-limestone convent castle on a ridge, a lake on one side and a deep valley on the other, grain sacks on every road.
- Compact node: castle approach, ridge-top bailey, lower market and mill; not a full town.

## 2. History in 1343
| Claim | Label | Note |
|---|---|---|
| Fellin has an Order castle and commandery, seat of a komtur | `attested` | [../TOURIST_LANDMARKS.md](../TOURIST_LANDMARKS.md) #45; legacy [../../scenes/world/viljandi_castle.md](../../scenes/world/viljandi_castle.md) |
| Rebels attempt entry in rye sacks, betrayed by a mother bargaining for her son | `attested` (chronicle tale) | [../CANON.md](../CANON.md): usable as rumour, bark or content-only echo mission, **not** a second field-battle climax |
| Exact date of the sack tale | **unverified** | Treat as spring-summer 1343; label `plausible composite` for timing only |
| Viljandi town as Hanseatic-linked market | `plausible composite` | Grain, livestock; see TOURIST #46 |
| Commander in 1343 named Goswin von Herike | `invented` | Legacy: [../../characters/order/brother_goswin_von_herike.md](../../characters/order/brother_goswin_von_herike.md); actual komtur unverified |
| Master of the Livonian Order Burchard von Dreileben | `attested` as Master c.1340-1345 (dates to verify) | Legacy: [../../characters/order/master_burchard_von_dreileben.md](../../characters/order/master_burchard_von_dreileben.md) |
| Castle state: stone convent, chapel and gate-tower | `plausible composite` | Later Gothic expansion unverified; do not show late bastions |

**Phases.** Act 2: the garrison is nervous after Kanavere and Sõjamäe, the shortage of grain is real; the infiltration echo can be played. Act 3: Order commander shows how reprisals feel on the ground (Pöide-era pressure), but no battle.

**Do NOT show:** late-medieval gun bastions, the 1560s-1700s ruins, Swedish-era fortifications, the town's wooden windmills of later centuries, any named guild hall, heavy artillery. Do not present the rye-sack plot as a successful rebel feat.

## 3. Landscape and layout
**Biome:** glacial ridge, kame and kettle lake, mixed forest of spruce and birch, wet meadow, rye fields on loamy slopes. Cold lake mist; loud frogs and curlews in spring.

Proposed map `loc.world_viljandi`, **80 x 32 cells**.

| Zone | Cells (x y w h) | Terrain | Purpose |
|---|---|---|---|
| Lake shore | 0 14 20 14 | water, reeds, wet mud | Fishing stakes, boat landing |
| Valley floor and mill | 20 20 18 10 | meadow, mill stream | Water mill, bridge, tannery |
| Ridge approach | 36 12 14 12 | dirt road, stone steps | Climb from market to castle |
| Castle precinct (bailey) | 40 2 28 14 | cobble, packed earth | Convent castle, chapel, stables |
| Gate and tribute yard | 48 15 12 6 | cobble | Tribute weighing, rye sacks, the echo mission staging |
| Market below the castle | 50 20 22 8 | dirt, plank | Grain, livestock, fur |
| North road | 60 0 20 4 | gravel | Exit toward Paide |
| Forest edge | 0 0 30 12 | spruce, birch | Hidden path, rebel scout |

**Anchors:** `landmark_convent_castle`, `landmark_gate_tower`, `landmark_tribute_yard`, `landmark_lake_landing`, `landmark_water_mill`, `landmark_ridge_steps`, `landmark_market_cross`, `landmark_forest_path`.

**Journey edges:**
| Edge id | From cell | To | Alignment |
|---|---|---|---|
| `road_to_paide` | 70 1 | `loc.world_paide` | travel |
| `road_to_tartu` | 79 14 | `loc.world_tartu` | travel |
| `road_to_parnu` | 0 20 | `loc.world_parnu` | travel (needs edit to an existing map: out of scope here) |

## 4. Architecture and built environment
- **Convent castle** (shared kit `asset.kit.order_convent_castle_brick`, defined in 9.1): quadrangle of brick and limestone with corner towers, chapel, refectory, dormitory, chapter-house, gate-tower with portcullis slot, high curtain.
- **Not the Paide kit:** `asset.kit.limestone_castle` is cited, not redefined, and is used for stone-heavy parts (see the Paide page, id only).
- **Lower market:** low timber houses, reed roofs, grain stores on piles, a market cross (post), a tribute weigh-house.
- **Water mill:** timber, overshot wheel on a brook.
- **Lake landing:** pier of piles, boat sheds, fish racks.
- **Distinguishing features:** ridge-top, brick-limestone mix, lake mist, sacks and barrels; nothing resembles Reval's harbour or Tartu's cathedral.

## 5. Cultures, languages, and people
| Group | Language | Wardrobe | Notes |
|---|---|---|---|
| Order brothers and sergeants | Middle Low German, Latin | white mantle black cross, chainmail, tonsure for priests | Strict rule, silent meals |
| Sakala Estonians | Sakala dialect, close to South Estonian (`plausible composite`) | wool coat, bast shoes, fur cap | Tribute payers |
| German settlers and traders | Middle Low German | wool, hood | Few families |
| Fishermen of the lake | Estonian | oilskin-like greased wool, nets | |
| Priests | Latin | cassock | Castle chaplain |

**Religion:** Catholic in the castle; folk belief outside, with hiis and household spirits as folklore. **Customs:** tribute counted in rye measures (loof, tonne; unit names `plausible composite`), vigil on the eve of St George, Order silence rule.

## 6. Factions present
| Faction id | Presence | Wants | Where | Act change |
|---|---|---|---|---|
| `livonian_order` | Dominant | Grain, order, hostages | Castle | A2 on guard; A3 reprisals |
| `harju_kings` | Hidden, failing | Enter castle by trick | Forest path, tribute yard | A2 the sack plot is *already doomed* |
| `hanseatic` | Minor | Safe grain trade | Market | A2 hoarding; A3 recovery |
| `danish_crown` | Minimal | Gossip about Order | Market | news only |
| `pskov_novgorod` | None / rumour | None | none | rumour of Pskov army |
| `black_cloaks` | Courier trace | Pass news | Market | one dialogue |
| `cult_metsik` | Offstage | Hidden hiis rite near lake | Forest | optional spirit-world |
| `vitalienbruder` | None | none | none | none |
| `church` (affinity) | Castle chaplain | Last rites | Chapel | A2 executions |
| Bishopric of Dorpat | Background | None | none | not a launch faction |

## 7. Characters
| char id | Name | Role / faction | Language | Confidence | Source | Hook |
|---|---|---|---|---|---|---|
| `char.goswin_von_herike` | Brother Goswin von Herike | Commander of the castle | German | `invented` (legacy) | legacy: [../../characters/order/brother_goswin_von_herike.md](../../characters/order/brother_goswin_von_herike.md) | Sees through the sacks; offers a hard bargain |
| `char.burchard_von_dreileben` | Master Burchard von Dreileben | Order Master (visiting letter only) | German | `attested` role, `invented` characterisation | legacy: [../../characters/order/master_burchard_von_dreileben.md](../../characters/order/master_burchard_von_dreileben.md) | Sends a letter demanding more grain |
| `char.order_squire` | Order squire | Messenger | German | `invented` | existing: [../CHARACTERS/order_squire.md](../CHARACTERS/order_squire.md) | Guides the Apprentice in the bailey |
| `char.brother_andreas` | Brother Andreas | Scholar guest | Latin, Estonian | `invented` (legacy) | legacy: [../../characters/bishopric_dorpat/brother_andreas.md](../../characters/bishopric_dorpat/brother_andreas.md) | Optional tale-keeper of the rye sack story |
| `char.viljandi_mother` | The mother (unnamed) | Villager who bargains | Estonian | `attested` (tale), `invented` (detail) | NEW | Moral centre of the echo mission; handle with care |
| `char.viljandi_quartermaster` | Brother Hartwig | Quartermaster | German | `invented` NEW | NEW | Counts sacks, hears the extra weight |
| `char.viljandi_mill_master` | Miller Tõnis | Miller | Sakala Estonian | `invented` NEW | NEW | Tells how the sacks were loaded |
| `char.viljandi_fisher` | Old Mihkel | Fisherman | Estonian | `invented` NEW | NEW | Lake spirit story |

**Crowd:** rye-cart driver, sergeant on guard, tribute counter, mill hand, fish-racker, shepherd boy, tavern keeper, castle laundress.

## 8. Quests, encounters, and discoveries
| id | Act | Type | Hook | Ties |
|---|---|---|---|---|
| `quest.viljandi_rye_sack_echo` | 2 | spirit-world echo / exploration | Witness the doomed plan in a vision; choose to warn or stay silent; no combat, outcome pre-recorded | CANON rye-sack entry; flag `flag.viljandi_echo_seen` (NEW) |
| `quest.viljandi_tribute_weights` | 2 | investigation | Find a false weight in the tribute yard | `livonian_order` ledger |
| `quest.viljandi_grain_forge` | 2 | forge commission | Repair iron hoops for tribute barrels | Kalev loop |
| `quest.viljandi_lake_spirit` | 3 | spirit-world | A drowned rebel's echo at the landing | `cult_metsik` flavour |
| `quest.viljandi_commander_letter` | 3 | travel event | Deliver a letter from Goswin | `livonian_order` |

**Sights:** (1) stone steps worn by boots; (2) rye measures stamped with an Order sign; (3) lake mist at dawn; (4) hiis tree at forest edge (folklore); (5) view of valley from the bailey wall.

## 9. Resources: what must be generated
### 9.1 Structures & architecture
| asset id | Description | Pri | Shared with | Notes |
|---|---|---|---|---|
| `asset.kit.order_convent_castle_brick` | **Shared kit, defined here.** Modules: `.curtain_wall_brick_limestone` (limestone footing, brick upper), `.corner_tower_square`, `.gate_tower_portcullis`, `.chapel_hall_pointed_windows`, `.refectory_range`, `.dormitory_range`, `.chapter_house`, `.cellar_vaults`, `.wall_walk_wood_hoarding`, `.well_house`, `.stable_range`, `.storehouse_grain`. Brick bond monk bond; plaster patches; roof types: tile and shingle. Parametric footprint (quadrangle, up to 60x40 m). Uses `asset.kit.brick_gothic_church` details cited, not redefined. | P1 | `loc.world_tartu` cites brick; `loc.world_frontier_ugandi` may reuse tower and gate modules | Reference: Order convent castles of Livonia; 1343 state unverified |
| `asset.viljandi.ridge_terrain` | Sculpted ridge and valley mesh | P1 | none | procedural |
| `asset.viljandi.market_houses` | Timber houses with reed roofs | P2 | Tartu river houses | |
| `asset.viljandi.water_mill` | Mill with overshot wheel | P2 | Tartu mill row | |
| `asset.viljandi.lake_pier` | Pile pier, boat sheds | P2 | frontier lakes | |
| `asset.viljandi.tribute_weigh_house` | Weigh-house with scale | P2 | none | |

### 9.2 Props & craft objects
| asset id | Description | Pri | Shared | Notes |
|---|---|---|---|---|
| `asset.prop.rye_sack` | Sack, plain and "heavy" variant (hides a body-shaped bulge; no gore) | P1 | frontier | echo mission |
| `asset.prop.grain_measure_tub` | Loof measure with Order mark | P1 | none | |
| `asset.prop.tribute_cart_rye` | Ox-cart with sacks | P1 | Tartu | |
| `asset.prop.tally_stick` | Notched tally stick | P2 | Tartu | |
| `asset.prop.order_seal_matrix` | Seal matrix, black cross | P3 | none | |
| `asset.prop.chapel_chalice` | Plain silver chalice | P3 | none | |
| `asset.prop.lake_fish_rack` | Fish drying rack | P2 | frontier | |
| `asset.prop.iron_barrel_hoop` | Hoop for forge commission | P2 | none | |

### 9.3 Characters
| asset id | Description | Pri | Shared | Notes |
|---|---|---|---|---|
| `asset.wardrobe.order_brother_mantle` | White mantle with black cross | P1 | Tartu, Paide | existing wardrobe may cover; verify |
| `asset.wardrobe.order_sergeant` | Gray surcoat, chain | P1 | none | |
| `asset.wardrobe.sakala_peasant` | Sakala dress, belt, felt cap | P1 | Tartu `asset.wardrobe.south_est_peasant` variant | |
| `asset.wardrobe.fisher_wax_coat` | Greased wool coat | P2 | frontier | |
| `asset.hair.tonsure` | cited from Tartu page | P2 | Tartu | |

### 9.4 Fauna
| species | Status | Notes |
|---|---|---|
| `fauna.horse`, `fauna.dog`, `fauna.cat`, `fauna.chicken` | cataloged | |
| `fauna.red_deer`, `fauna.roe_deer`, `fauna.elk`, `fauna.wolf`, `fauna.brown_bear`, `fauna.lynx` | cataloged | forest edge |
| `fauna.beaver`, `fauna.otter` | cataloged | lake |
| `bird.great_cormorant`, `bird.mute_swan`, `bird.northern_lapwing`, `bird.common_snipe` | cataloged | lake meadow |
| `bird.eurasian_curlew`, `bird.black_grouse`, `bird.crane_common` | MISSING | spring display, calls |
| `fauna.ox`, `fauna.cow`, `fauna.sheep`, `fauna.pig` | MISSING (shared with Tartu, define once) | draught and market |
| `fauna.pike`, `fauna.bream` | MISSING (fish are optional, P3) | lake |

### 9.5 Flora & ground cover
| id | Status | Notes |
|---|---|---|
| `tree.spruce`, `tree.birch`, `tree.pine`, `tree.aspen`, `tree.alder`, `tree.oak`, `tree.linden` | existing | ridge forest |
| `plant.reed`, `plant.cattail`, `plant.water_lily`, `plant.moss`, `plant.fern` | existing | lake |
| `crop.rye`, `crop.barley`, `crop.oat`, `crop.flax` | existing | fields |
| `bush.juniper_shrub`, `bush.heather`, `bush.bog_rosemary` | existing | ridge and fen |
| `plant.wood_anemone`, `plant.marsh_marigold` | MISSING | spring forest floor |
| `ground.sack_dust` | MISSING | tribute yard decal |

### 9.6 Materials / terrain / water
| id | Description | Pri | Shared |
|---|---|---|---|
| `mat.brick_red_weathered` | cited from Tartu page | P1 | Tartu |
| `mat.limestone_pale` | Pale limestone footing | P1 | Paide, Reval |
| `mat.lake_still_misty` | Still lake with mist | P1 | frontier |
| `mat.ridge_gravel_clay` | Gravel and clay | P2 | none |
| `mat.thatch_reed` | Reed thatch | P2 | all rural |

### 9.7 Audio & music direction
Languages heard: German, Latin chant, Sakala Estonian. Ambient: lake water, frogs, curlews, creak of mill wheel, sack drag, chapel bell, rooks. Instruments: low drone, plainchant, a single kantele-like zither (plausibility `plausible composite`), pizzicato for the echo mission (see legacy music notes in [../../scenes/world/viljandi_castle.md](../../scenes/world/viljandi_castle.md)). Echo mission: muffled heartbeat, no triumphal brass.

## 10. Variety signature and risks
- **Palette:** limestone pale, brick red, lake blue-grey. **Silhouette:** castle on ridge with a lake behind. **Sound:** frogs, mill, plainchant.
- **Risks:** anachronism (gun bastions, ruins); scope (another castle after Paide and Pöide; risk of castle fatigue, mitigate with echo-mission focus and the lake biome); sensitivity (execution of captured rebels; the mother's choice; keep off-screen); performance (large ridge terrain).
- **Open questions:** exact date of the sack tale; actual komtur name; whether to merge this page into the Paide node.
- **Scope gate.** New node; needs ADR. Equivalent scope to compress: the legacy archived `viljandi_castle` scene stays inactive, so no existing active map is lost. Options: (A) fold the whole node into a **single travel stop on the Paide to Pärnu road** (one scene, one echo mission, no market); (B) replace one rural travel event of Act 2 with the rye-sack echo; (C) if the maintainer accepts the full map, remove an equal-cost node (for example one of the lower-priority Act 3 travel maps, to be named in the ADR). Because the CANON rules out a battle climax, the node can be built as a content-only echo with shared brick kit.

## 11. Sources and next steps
- Repo: [../CANON.md](../CANON.md), [../TOURIST_LANDMARKS.md](../TOURIST_LANDMARKS.md), [../../history/HISTORY.md](../../history/HISTORY.md), [../../scenes/world/viljandi_castle.md](../../scenes/world/viljandi_castle.md), [../../characters/order/brother_goswin_von_herike.md](../../characters/order/brother_goswin_von_herike.md), [../CITIZENS/factions/livonian_order.md](../CITIZENS/factions/livonian_order.md), [../FLORA_FAUNA.md](../FLORA_FAUNA.md), [../../content/maps/world_paide.rrmap](../../content/maps/world_paide.rrmap).
- External (by name): Renner's chronicle for the rye-sack tale; Viljandi castle archaeology; Livonian Order castle studies.
- Verification tasks: confirm the komtur at Fellin in 1343; confirm tale date; confirm Paide page publishes `asset.kit.limestone_castle`; check missing species; write ADR.
