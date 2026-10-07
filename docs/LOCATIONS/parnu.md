# Pärnu (Pernau, New Pernau and Old Pernau)

**Status:** planned (design proposal, not implemented) · **Scope gate:** existing prototype `loc.world_parnu` · **Act(s):** 2 (supply and sea gate), 3 (ferry hub to Saaremaa)
**Map id:** `loc.world_parnu` (existing: [`content/maps/world_parnu.rrmap`](../../content/maps/world_parnu.rrmap), 50x28 cells, `scope=prototype`, `active=false`; proposal widens it to about 96x56) · **Seasons/phases:** May-June 1343 (Act 2), July 1343-1345 (Act 3); river in spring spate, then summer low water
**Confidence summary:** Pernau as a Hanseatic-Livonian port on the Pärnu river mouth: `attested`. Shared Order and Ösel-Wiek bishopric garrison duty: `plausible composite` (see [`TOURIST_LANDMARKS.md`](../TOURIST_LANDMARKS.md)). A "Battle of Pärnu" is `invented` and must not replace Kanavere or Sõjamäe ([`CANON.md`](../CANON.md)). Ferry to Saaremaa as a scheduled route: `plausible composite`. Individual NPCs: `invented`.

## 1. Why a player would want to visit

- The one Baltic trade port in the five pages: flax, grain, timber, hides and river fish leave here for Reval, Riga and Gotland.
- A true crossroads of tongues: Low German traders, Estonian rivermen, a few Swedish and Livonian (Finnic coastal) boatmen, Latin clerks of the bishop.
- Shared garrison politics: a bishopric of Ösel-Wiek and an Order both want the river mouth, and each sends men who dislike the other.
- The player's gateway to Saaremaa: buy passage, forge ferry fittings, or be turned away.
- **Signature:** the only wide, brown, slow river-mouth node: timber quays, fish weirs and flax racks under gull noise and rope creak.

## 2. History in 1343

| Fact | Label | Note |
|---|---|---|
| Old Pernau (Vana-Pärnu) founded by the bishop of Ösel-Wiek in the 13th century; New Pernau founded 1265 near the river mouth | `attested` (dates approximate; verify) | The bishop's cathedral chapter seat was Old Pernau until the move; 1343 state of the church is unverified. |
| Lübeck-law town rights for Pernau | `plausible composite` for 1343 (14th c.) | Do not date a charter on screen. |
| Hanseatic traffic: grain, flax, timber, wax, hides | `attested` as a regional type | Reval is the sea gate; Pernau is the "alternative" in [`TOURIST_LANDMARKS.md`](../TOURIST_LANDMARKS.md) item 47. |
| Timber-and-earth fort at the river mouth, shared duty | `plausible composite` | Item 48 of the tourist file. No stone Order castle shown as complete. |
| Ferry or coastal boat route to Ösel (via Kihnu or along the Sõrve side) | `plausible composite` | Operated by local boatmen; schedule is a game convenience. |
| Lamprey and salmon river fishing, weirs | `plausible composite` (river fishing is attested for the region; Pärnu-specific 1343 detail unverified) | |
| Rebel and Order activity at Pernau in May 1343 | unverified | Existing greybox shows two camps; keep as refugee and supply camps, not a battle. |

Phases: A (May 1343): crowded, nervous, muddy quays, rumours from Harju. B (summer 1343 on): Saaremaa rising makes the ferry politically dangerous; bishopric vs Order tension grows. Do NOT show: the resort town, 17th-c. star fort, wooden spa architecture, brick Hanseatic gables, Tallinn Gate, a Rüütli-street baroque skyline, later church spires.

## 3. Landscape and layout

Biome: wide river mouth, reed and willow flats, sandy bar, low pine ridges, coastal meadow; salty smell, fog banks, sea wind. Terrain is almost flat; the river is the main organiser.

| Zone | Approx cells (96x56) | Reads as | Carries |
|---|---|---|---|
| North road and Sauga ford | x0-30, y0-10 | Dirt road with reeds | Entry from Padise (west) |
| River quays | x30-70, y18-34 | Timber quays, jetties, slips | Ferry berth, goods, rope |
| Warehouse row | x20-60, y10-24 | Timber stores, flax lofts | Hanseatic factors |
| Market lane and church | x28-52, y34-50 | Mud market, wooden parish church | Crowd, news, healers |
| Fort and garrison mound | x62-80, y12-30 | Earth bank, timber tower, hall | Shared garrison, jail |
| Fish weirs and drying racks | x50-90, y30-52 | Withy weirs, racks, smoke sheds | Lamprey and salmon work |
| Sea strand and bar | x0-96, y50-56 | Sand, wrack, boats beached | Ferry to Saaremaa, smugglers |
| Old Pernau fringe (east) | x78-96, y30-50 | Ruinous chapter site, empty plots | Quiet, folklore, hideouts |

Landmarks: existing greybox anchors `landmark_town_barricade`, `landmark_west_quarter`, `landmark_east_quarter`; proposed `landmark_ferry_berth`, `landmark_hanse_warehouse_row`, `landmark_river_fort`, `landmark_weir_lines`, `landmark_old_pernau_chapter`, `landmark_flax_lofts`, `landmark_parish_church`.

Journey edges (existing): `road_to_padise` (west), `road_to_paide` (east), `ferry_to_saaremaa` (south). Proposed: none new.

## 4. Architecture and built environment

- **Timber port town:** low log and plank warehouses with loft doors and a hoist beam, tarred timber, pitched shingle and turf roofs, stone only in the church base and a few cellars. Flat, horizontal silhouette, in contrast to Paide's keep and Padise's dispersed estate.
- **Quays:** piled timber walls, cribs of logs filled with stone, rope bollards, lightering boats (compare [`baltic_vessels_1343.md`](../reports/baltic_vessels_1343.md)).
- **Ship types:** open clinker ferry boats, river lighters (lodi), a visiting cog standing off at the bar, withy fish weirs.
- **Fort:** earth bank, timber palisade, one stone-footed tower, hall and jail; the shared garrison uses two flags and two gates.
- **Houses:** diele-style merchant houses are possible in the best row (Hanseatic type), but only as timber-front buildings; rural smoke cottages at the edge ([`rural-smoke-dwelling-and-farmstead-1343.md`](../../history/dossiers/architecture/rural-smoke-dwelling-and-farmstead-1343.md) notes a separate Pernau evidence pass is still needed).
- Construction state: busy, active, slightly dilapidated; some plots empty (Old Pernau).

## 5. Cultures, languages, and people

| Group | Language | Wardrobe / notes |
|---|---|---|
| Hanseatic merchants and factors | Low German; some Latin for contracts | Dark wool, hoods, leather purses, belt knives |
| Estonian townspeople, rivermen, fishers | Estonian (Pärnu-Viljandi dialect area, `plausible composite`) | Undyed wool, felt hats, tarred boots (no oilcloth) |
| Livonian (Finnic) coastal boatmen | Livonian language, trade pidgin | Short fur caps, belt pouches; `plausible composite` presence |
| Swedish-speaking sailors and traders | Old Swedish | Blue-dyed wool, striped caps |
| Bishopric men (clerks, guards) | Low German, Latin | Dark cassocks, grey livery |
| Order sergeants and sentries | Middle High German | White-black tabards over mail |

Religion: parish Catholicism; river-spirits, weir luck-charms and fish-offering customs (`folklore`, see [`belief-omens-and-healing.md`](../../history/dossiers/folklore/belief-omens-and-healing.md)). Customs: toll at the bridge, weights and measures disputes, Hanseatic oath on a cross. Names: Estonian (Mihkel, Mart, Ülle, Mall), Low German (Hinrik, Tideke), Swedish (Nils, Olof).

## 6. Factions present

| Faction id | Presence | Wants | Where | Act-by-act |
|---|---|---|---|---|
| `hanseatic` | Strong | Open sea and river, uninterrupted flax and grain | Warehouse row, quays | Act 2: price spikes; Act 3: profits from the Order's island war |
| `livonian_order` | Strong | Control crossings, supply Saaremaa campaign | Fort, east quarter | Act 2: supply base; Act 3: Prussian reinforcements pass |
| `harju_kings` | Weak | Courier route, refugees | West camp, weirs | Act 2: runners; Act 3: gone |
| `cult_metsik` | Hidden | Smuggle omen-readers to Saaremaa | Strand, weirs | Act 3: ferry network |
| `vitalienbruder` | Moderate | Fence goods, buy boats | Strand, taverns | Act 2-3: invented captain below |
| `danish_crown` | Absent | Nothing | Rumour | None |
| `pskov_novgorod` | Minimal | Carters only | Market | Pskov raid rumours |
| Bishopric of Ösel-Wiek | Strong (background canon, not a launch faction) | Keep the river mouth; resist the Order | Church, old chapter | Act 2-3: quiet rival to the Order |
| `blackheads`, `church` | Candidate affinity | Merchants' fellowship; priests | Market | Optional |

## 7. Characters

| char id | Name | Role / faction | Language | Confidence | Source | Hook |
|---|---|---|---|---|---|---|
| `char.hermann_osenbrugge` | Bishop Hermann II Osenbrügge | Bishop of Ösel-Wiek (background) | Latin, German | Person unverified for 1343 tenure; `plausible composite` | legacy [`hermann_osenbrugge.md`](../../characters/bishopric_osel_wiek/hermann_osenbrugge.md) | Offstage authority; letters |
| `char.brother_hermann` | Brother Hermann | Order handler | MHG | `plausible composite` | existing [`brother_hermann.md`](../CHARACTERS/brother_hermann.md) | Supply and ferry permit |
| `char.dietrich` | Dietrich | Merchant | Low German | `invented` | legacy [`dietrich.md`](../../characters/merchants/dietrich/dietrich.md) | Flax contracts; credit |
| `char.jurgen` | Jürgen | Merchant link | Low German | `invented` | existing [`jurgen.md`](../CHARACTERS/jurgen.md) | Reval correspondent |
| `char.ironhand_replacement` | Captain Ulf Kruse | Vitalienbruder captain | Low German, Swedish | `invented` (NEW; replaces the anachronistic Störtebeker seed) | NEW, seed [`ironhand_stortebeker.md`](../../characters/pirates/ironhand_stortebeker.md) | Sells a boat; wants a keel-bolt forged |
| `char.kaja` | Kaja | Courier | Estonian | `invented` | existing [`kaja.md`](../CHARACTERS/kaja.md) | Needs a ferry seat |
| `char.parnu_ferryman` | Toomas the ferry-master | Ferry operator | Estonian | `invented` (NEW) | NEW | Sells passage; demands proof |
| `char.parnu_weir_woman` | Mall of the weirs | Fisher, lamprey smoker | Estonian | `invented` (NEW) | NEW | Smugglers' cache; weather sense |
| `char.parnu_vogt_clerk` | Clerk Johannes | Bishopric toll clerk | Latin, German | `invented` (NEW) | NEW | Toll ledger; letter forgery |
| `char.parnu_livonian_boatman` | Ranna | Livonian boatman | Livonian, Estonian | `plausible composite` (NEW) | NEW | Taboo of the sandbar; rare language |
| `char.parnu_swedish_trader` | Olof Nilsson | Swedish trader | Old Swedish | `invented` (NEW) | NEW | Rumours of Stockholm and Swedish aid |

Crowd archetypes: ferryman, warehouse hoist-hand, flax hackler, lamprey smoker, bishopric toll-sergeant, Order sentry, refugee carter, gull-boy (bird-scarer).

## 8. Quests, encounters, and discoveries

| id proposal | Act | Type | Hook | Ties |
|---|---|---|---|---|
| `quest.parnu_ferry_pass` | 2-3 | travel event | Obtain a berth to Saaremaa from three competing authorities | `ferry_to_saaremaa` |
| `quest.parnu_keel_bolt` | 2 | forge commission | Forge iron fittings for a Vitalienbruder keel; later inspection finds them | Smithy pillar; `faction.vitalienbruder` |
| `quest.parnu_toll_ledger` | 2 | investigation | Compare bishopric and Order toll ledgers; one is cooked | Church/Order friction |
| `quest.parnu_weir_night` | 2 | night mission | Move a courier past the Order boat patrol along the weirs | `faction.harju_kings` |
| `quest.parnu_flax_price` | 3 | exploration | Track why flax prices doubled; Reval and Pernau contracts | `faction.hanseatic` |
| `quest.parnu_sandbar_taboo` | 3 | spirit-world | Apprentice meets a river-spirit memory at the bar | ADR 0033 |

Sights: (1) lamprey smoking on willow withies, `plausible composite`; (2) Old Pernau's empty chapter plots, `attested` fact, details `plausible composite`; (3) multi-language trade tally board, `invented`; (4) flax retting pits and brake, `attested` craft; (5) sandbar fog-bell, `invented`.

## 9. Resources: what must be generated

The Order wardrobe, `asset.kit.limestone_castle` and `asset.prop.refugee_bundle_cart` are defined in [`paide_castle.md`](paide_castle.md) and only cited here.

### 9.1 Structures and architecture

| Asset id | Description | Pri | Shared with | Notes |
|---|---|---|---|---|
| `asset.kit.timber_harbour` | **Shared kit:** piled quay wall, crib jetty, bollards, slipway, crane hoist, fish rack, withy weir, rope walk | P1 | Saaremaa (small jetty), Padise (mill pier) | Evidence: Baltic Hanseatic harbour archaeology; compare [`baltic_vessels_1343.md`](../reports/baltic_vessels_1343.md) |
| `asset.parnu.warehouse_timber_loft` | Two-storey log warehouse, hoist beam, 6 variants | P1 | | |
| `asset.parnu.flax_loft_and_retting_pit` | Flax drying loft and retting pit | P2 | Saaremaa | |
| `asset.parnu.river_fort_timber` | Earth bank, palisade, stone-footed tower, hall | P2 | | May use `asset.kit.limestone_castle.well_house` etc. only for the footing |
| `asset.parnu.parish_church_wood_stone` | Stone base, timber upper, shingle roof | P2 | | `plausible composite` |
| `asset.parnu.smoke_cottage_edge` | Edge-of-town smoke cottage | P3 | | Use existing rural primitive |

### 9.2 Props and craft objects

| Asset id | Description | Pri | Shared with | Notes |
|---|---|---|---|---|
| `asset.prop.ferry_boat_clinker_open` | 6 m open clinker ferry, oars, mast stub | P1 | Saaremaa | `plausible composite` |
| `asset.prop.river_lighter_lodi` | Shoal-draft cargo lighter | P2 | | |
| `asset.prop.fish_basket_lamprey_withy` | Withy baskets and lamprey strings | P2 | Saaremaa | |
| `asset.prop.merchant_scale_and_weights` | Beam scale, lead weights, tally board | P2 | Paide | |
| `asset.prop.flax_bale_and_brake` | Flax bundle, flax brake, hackle | P2 | Saaremaa | |
| `asset.prop.amber_and_wax_goods` | Amber beads, wax blocks, hide bales | P3 | | |

### 9.3 Characters

| Asset id | Description | Pri | Shared with | Notes |
|---|---|---|---|---|
| `asset.char.wardrobe.hanse_factor` | Dark wool gown, hood, purse | P1 | Paide | |
| `asset.char.wardrobe.riverman` | Felt cap, tarred boots, wool tunic | P1 | Saaremaa | |
| `asset.char.wardrobe.livonian_boatman` | Short fur cap, striped belt, bone toggles | P2 | | `plausible composite` |
| `asset.char.wardrobe.swedish_sailor` | Striped cap, blue wool | P2 | | |
| `asset.char.wardrobe.bishopric_clerk` | Dark cassock, ink pouch | P2 | | |
| `asset.char.wardrobe.vitalienbruder_captain` | Heavy coat, brigandine-free, red cap | P3 | | |

### 9.4 Fauna

| Species | Status | Notes |
|---|---|---|
| Herring gull, common gull, common tern, mallard, mute swan, greylag goose, great cormorant, grey heron, osprey | already cataloged | Gull density high |
| Grey seal `fauna.grey_seal`, otter, beaver | already cataloged | Sandbar seals |
| Horse, dog, cattle, pig, goose, duck, chicken | already cataloged | |
| Lamprey (`asset.fauna.fish_river_lamprey`) | missing | P2, weir and basket prop |
| Salmon, pike, perch, bream, smelt (`asset.fauna.fish_set_river`) | missing | P2, fish racks, instanced |
| Flounder/herring (`asset.fauna.fish_set_sea`) | missing | P3 |

### 9.5 Flora and ground cover

Existing: `plant.reed`, `plant.cattail`, `plant.water_lily`, `tree.willow`, `tree.alder`, `tree.pine`, `bush.sea_buckthorn`, `bush.juniper_shrub`, `crop.flax`, `crop.hemp`, `crop.rye`, `grass.short`, `grass.dry`. Missing: `plant.sea_lyme_grass` (dune grass) P3; `plant.sea_kale` P3.

### 9.6 Materials, terrain, water

`asset.mat.tarred_timber` P1; `asset.terrain.river_mouth_silt` (brown water tint, sand bar, tide-free but seiche-ish levels) P1; `asset.water.river_brown_slow` P1; `asset.terrain.reed_flat` P2; `asset.mat.withy_woven` P2.

### 9.7 Audio and music direction

Languages heard: Low German, Estonian, Old Swedish, Livonian (a few phrases), Latin. Ambience: gulls, halyard slap, rope creak, quay planks, wave on sand, lamprey sizzle on the smoking rack, bell for toll. Music: vielle and low whistle melodies, a Finnic rune-song fragment (`plausible composite`), no orchestral battle score. Instruments (period): vielle, kannel (`plausible composite`), jaw harp, bagpipe fragments.

## 10. Variety signature and risks

- **Palette:** brown river, silver-grey sky, tarred black-brown timber, flax gold, red-clay sail patches.
- **Silhouette:** low, flat, horizontal quays, hoist beams and mast tips.
- **Soundscape:** gulls, rope and plank sounds, four languages in overlap.
- **Massacre handling:** none staged here. Any news of Padise, Paide or Pöide arrives as rumour, burnt clothes, a refugee's account. If a night patrol causes deaths, show the cost (a ledger line, a widow at the toll gate), not spectacle.
- **Canon risk:** a "Battle of Pärnu" is an `invented` local mission; do not rename Kanavere (11 May) or Sõjamäe (14 May). Mark any Pernau action clearly as `invented` in journal text.
- **Anachronism:** no resort spa town, no star fort, no brick gables, no church spires beyond what is attested.
- **Sensitivity:** Livonian (Finnic) presence is modest and must not imply a settled ethnography; keep it as `plausible composite`.
- **Performance:** many small boat and rope props; use instancing for quays, fish racks and crowd.
- **Open questions:** (1) Does the player ever fight here or only broker? (2) Should the shared garrison be a Bishopric/Order conflict quest? (3) Keep Old Pernau fringe or cut for scope?

## 11. Sources and next steps

Repo: [`CANON.md`](../CANON.md), [`TOURIST_LANDMARKS.md`](../TOURIST_LANDMARKS.md), [`global_map_mockups.md`](../reports/global_map_mockups.md), [`baltic_vessels_1343.md`](../reports/baltic_vessels_1343.md), [`hanseatic.md`](../CITIZENS/factions/hanseatic.md), [`vitalienbruder.md`](../CITIZENS/factions/vitalienbruder.md), [`hanseatic-trade-and-season.md`](../../history/dossiers/economy/hanseatic-trade-and-season.md), [`pernau.md` (legacy)](../../scenes/events/pernau.md). External by name: Livonian Order and Ösel-Wiek bishopric historiography; Pärnu Museum and archaeological digs at Old and New Pernau; Hanseatic Lübeck-law town charters.

Verification tasks: (1) verify New Pernau 1265 foundation and charter date; (2) check bishopric vs Order garrison arrangement in 1343; (3) write a Pernau urban-fabric dossier (rural dossier flags the gap); (4) blueprint `parnu` per [`MAP_AUTHORING.md`](../MAP_AUTHORING.md); (5) lamprey and fish species research.
