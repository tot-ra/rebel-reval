# Padise Monastery (Padis, Cistercian abbey on the Kloostri river)

**Status:** planned (design proposal, not implemented) · **Scope gate:** existing prototype `loc.world_padise` (the repo also has `loc.padise_monastery` content ids) · **Act(s):** 2 (rural news and evidence), 3 (full two-phase scene, **P6-002** / **P6-009**)
**Map id:** `loc.world_padise` (existing: `content/maps/world_padise.rrmap`, already 140x90 cells, 1 cell = 1 m, `scope=prototype`, `active=false`) · **Seasons/phases:** Phase A "before" (spring 1343, up to 22 April), Phase B "after" (about 1 May 1343, burnt estate); optional Phase C "rebuilding" (1344-46, timber scaffolds and foundation trenches only)
**Confidence summary:** Cistercian house founded 1305 by monks from Dünamünde and sacked at St George's Night 1343, about 28 monks killed: `attested`. Two limestone buildings surviving from before the sack (excavations): `attested`. Timber conventual fabric, room positions, personal names, daily scenes: `plausible composite` / `invented`. Fortified quadrangle, stone church and gate towers: later (post-1343), excluded.

## 1. Why a player would want to visit

- A calm, strangely beautiful place that the player is likely to know will be destroyed: the first phase is a short chance to meet people before they are gone.
- Two visibly different lives on the same estate: White Brothers (choir monks) and Grey Brothers (lay brothers/conversi, working the fields, mill and smithy).
- Phase B is a quiet crime scene: ash, a river, a ford, a cemetery; the player reads what happened from objects and testimony.
- A site where a forge commission is believable (a monastery smithy, bells, hinges, a chalice repair).
- **Signature:** the only node whose sound is a daily rhythm: Latin office hours, hand-sign silence, the mill wheel, then (after) wind in ash.

## 2. History in 1343

| Fact | Label | Note |
|---|---|---|
| Cistercian abbey Padise founded 1305 by King Eric VI Menved's grant, monks from Dünamünde (Daugavgrīva) | `attested` | From [`padise_monastery_research_p6_009.md`](../reports/padise_monastery_research_p6_009.md); the same file says stone works began 1317; treat dates as approximate. |
| Estonian rebels attack and burn the house; about 28 monks killed on St George's Night | `attested` (see [`CANON.md`](../CANON.md)) | Rebels' motives and the exact route are not documented in detail. |
| Pre-sack complex: several small, mostly timber buildings scattered over a wider area; a large stone building under the later western range; a "building with arched niches" south of it | `attested` (excavation, Kadakas 2011) | Basis of the map's two limestone anchors. |
| Site: plateau above the Kloostri river, Tallinn-Haapsalu road with a ford to the north, pond to the east | `attested` (Kadakas Fig. 2) | |
| Quadrangular claustrum, stone abbey church (consecrated 1448), gate towers, gun towers, moat | `attested` as later | Wall-trench stoneware dates the ranges to about 1350-1400; excluded from 1343. |
| Rågervik / Paldiski harbour rights held or claimed by the abbey | unverified; `plausible composite` | Optional sub-zone only; see section 3. |
| Lay brothers by the 14th century at Padise | uncertain; the research notes numbers diminished | Keep a small Grey Brother group, label `plausible composite`. |

**Research conflict flagged:** the research file's "Phase 2" notes describe a fortified cube-shaped cloister with towers, drawbridges and a basement well. Its own 1 May 1343 section and the map header say that is post-1343 construction. This page follows the excavation-based reading: Phase B is the burnt open estate. The fortified cloister could be a later Act 3 optional Phase C only if a decision is taken; it is not shown here. Do NOT show: the late claustrum, drawbridges, portcullis, a stone abbey church with rib vaults, Paldiski port town, the Soviet-era navy base.

## 3. Landscape and layout

Biome: forested Harju west of Tallinn; spruce and pine with oak and linden at the close, river meadows, small fields, mill pond. Climate: late April cool, birch buds, damp; Phase B smell of char.

| Zone | Existing cell hints (140x90) | Reads as | Carries |
|---|---|---|---|
| Kloostri river, mill, ford | x5-30, y5-65 | Western water edge, mill house, ford at `landmark_river_ford` (9,8) | Entry from Padise road, miller |
| Grange and work yard | x20-80, y10-30 | Barn, granary, stable, smithy, pigsty | Grey Brother labour, `landmark_work_yard` (32,28) |
| Lay brothers' quarter | x23-50, y35-55 | Cottage, workshop (burnt in B) | `room_lay_brothers` (49,46) |
| Precinct core | x40-105, y18-71 | Low fieldstone boundary, garth, timber ranges | Cloister garth `room_cloister_garth` (78,44) |
| Stone anchors | x50-70, y34-73 | Early limestone hall and arched-niche house | `landmark_early_stone_house` (70,46), `landmark_arched_niche_house` (59,73) |
| Oratory and cemetery | x72-92, y20-31 | Timber oratory, bellcote, monks' graves | `landmark_timber_oratory` (81,31), `landmark_monks_cemetery` (86,20) |
| Infirmary and burnt wing | x105-125, y25-50 | Timber infirmary, burnt guest range | `room_infirmary` (119,36), `landmark_fire_damage` (114,30) |
| Refectory, brewhouse, gardens | x70-100, y60-85 | South range, bake-brew house, kitchen garden, orchard | `room_refectory` (84,67), `room_brewhouse` (81,84) |
| Fields and pasture | all edges | Five farm-soil zones, cattle and sheep | Economy, rebel approach |
| Optional: Rågervik quay | south-west corner, proposed `x0-24, y70-90` | Small timber landing on the coast | Optional sub-zone |

Other existing anchors: `precinct_gate_anchor` (62,20), `landmark_monastery_well` (76,49), `landmark_watermill` (24,58), `room_chapter_range` (101,43). Journey edges (existing): `road_to_reval` (east), `road_to_parnu` (west). Proposed: `road_to_ragervik` optional spur.

## 4. Architecture and built environment

- **Stone:** two limestone masses (hall and niche house), rubble under shingle, two storeys over an undercroft (existing styles `stone.early`, `stone.niche`). Reuse `asset.kit.limestone_castle` parts only for the masonry shell ([`paide_castle.md`](paide_castle.md) owns the kit); do not use curtain, gatehouse or keep parts.
- **Timber conventual fabric:** log and plank ranges, a timber oratory with paired lancets and a framed west bellcote with one bell (`timber_oratory_1343` primitive), `cloister_walk` posted timber pentices (view landmark), unheated dorter/chapter ranges (no chimney).
- **Estate:** barn, granary, stable, smithy, mill, bakehouse and brewhouse in plank and thatch; low precinct wall (72 cm in map units), not a defensive circuit.
- **Interiors:** Padise multi-level vaulted routes in the research brief refer to the later stone complex. For 1343 use the undercroft and ground floor of the limestone hall for vaulted, columned, narrow-window routes (`plausible composite`); timber ranges are single-level.
- Construction state: A: working, scaffolds for new stone works; B: scorched sills, collapsed roofs, one burnt range, smoke-black stone; C (optional): timber scaffold, mortar tubs, new footings.
- Distinct from other nodes: dispersed low roofs around an open close, not a block.

## 5. Cultures, languages, and people

| Group | Language | Wardrobe / notes |
|---|---|---|
| White Brothers (choir monks, priests) | Latin (liturgy), Low German / Danish-influenced speech; hand signs in cloister | White habit and cowl with black scapular (usual depiction; 14th-c. Padise detail unverified); tonsure |
| Grey Brothers (lay brothers, conversi) | Estonian and German working speech; Latin prayers by rote | Undyed grey-brown wool, short beard allowed, leather apron |
| Abbot and prior | Latin, German | White habit with pectoral cross or ring |
| Estonian tenants and servants | Estonian (Harju dialect) | Brown and green homespun |
| Order officer (after) | MHG | White mantle, black cross |
| Rebels (after) | Estonian | Hooded cloaks, farm tools as arms |

Religion: Cistercian Rule: silence, hand signs, Divine Office (Matins to Compline), Mass, chapter. Customs: infirmary care, gate hospitality, grain tithe. Names: monastic names (Brother Thomas, Brother Martin from the legacy roster), Estonian tenant names. Sign language: a few Cistercian signs as a gameplay lens.

## 6. Factions present

| Faction id | Presence | Wants | Where | Act-by-act |
|---|---|---|---|---|
| `church` (candidate affinity) | Core | Peace, tithe, safe road | Oratory, ranges | A: dominant; B: survivors only |
| `livonian_order` | Phase B inspector | Evidence, blame, order | Gate, burnt wing | Act 2: rumour; Act 3: investigation and exploitation |
| `harju_kings` | Phase B | Stores, justification, regret | Burnt wing, ford | Rebels as actors; leaders surveying damage |
| `hanseatic` | Marginal | Grain and malt contracts | Brewhouse | A only |
| `danish_crown` | Patron | The abbey is a royal foundation | Charter chest | Weak, absent |
| `cult_metsik` | Marginal | Quiet reclamation of the site | Woods | B: offering at the ford |
| `black_cloaks`, `vitalienbruder`, `pskov_novgorod` | None / rumour | - | - | - |

## 7. Characters

| char id | Name | Role / faction | Language | Confidence | Source | Hook |
|---|---|---|---|---|---|---|
| `char.padise_abbot` | The Abbot (unnamed in sources) | Head of house | Latin, German | `plausible composite` | legacy [`padise_monastery.md`](../../scenes/world/padise/padise_monastery.md) | Receives visitors; frames the choice |
| `char.padise_brother_thomas` | Brother Thomas | Young choir monk | Latin | `invented` | legacy NPC 2 | Idealist; may not survive |
| `char.padise_brother_martin` | Brother Martin | Old monk, brewer | German, Latin | `invented` | legacy NPC 3 | Beer, cynicism, truth |
| `char.padise_alcuin` | Brother Alcuin | Parchment-maker | Latin | `invented` | legacy [`brother_alcuin.md`](../../characters/clergy/brother_alcuin/brother_alcuin.md) | Records; a book to save |
| `char.padise_infirmarian` | Brother Henrik | Infirmarian | Latin, German | `invented` (NEW) | NEW | Medicine; Apprentice's mentor in plants |
| `char.padise_cellarer` | Brother Gerlach | Cellarer, grange manager | German | `invented` (NEW) | NEW | Controls grain, keys |
| `char.padise_lay_brother` | Brother Jaan | Grey Brother smith | Estonian | `invented` (NEW) | NEW | Smith colleague; trust anchor |
| `char.padise_novice_survivor` | Novice Tõnis | Survivor | Estonian, Latin | `invented` | legacy NPC 11 | Witness in B |
| `char.padise_miller` | Miller Ants | Tenant | Estonian | `invented` (NEW) | NEW | Knows the river and who crossed |
| `char.lembit_helme` | Lembit Helme | Rebel king | Estonian | `invented` | existing [`lembit.md`](../CHARACTERS/lembit.md) | Appears in B only if branch allows |
| `char.apprentice` / `char.kalev` | Apprentice / Kalev | Protagonists | Estonian | `invented` | existing [`apprentice.md`](../CHARACTERS/apprentice.md), [`kalev.md`](../CHARACTERS/kalev.md) | Forge visit (A), evidence (B) |

Crowd archetypes: White Brother at prayer, Grey Brother with scythe, lay servant with water buckets, miller's boy, shepherd, guest-house traveller, peasant at the gate asking sanctuary, bell-ringer.

## 8. Quests, encounters, and discoveries

| id proposal | Act | Type | Hook | Ties |
|---|---|---|---|---|
| `quest.padise_chalice_repair` | 2/3 (Phase A flashback or early visit) | forge commission | Repair a chalice foot and a bell clapper before a feast | Smithy pillar; `loc.padise_monastery` |
| `quest.padise_hand_signs` | 3 | exploration | Learn three hand signs to pass the silence zones | Dialogue verbs |
| `quest.padise_ash_ledger` | 3 | investigation | Reconstruct who opened the gate from scorch marks, a ledger and the miller's account | Order standing |
| `quest.padise_infirmary_herbs` | 3 | exploration | Gather herbs from the drying rack for a survivor | `plant.*` ids |
| `quest.padise_book_rescue` | 3 | night mission | Retrieve a book chest from the arched-niche house before looters | Brother Alcuin |
| `quest.padise_ford_offering` | 3 | spirit-world | Apprentice meets a presence at the ford where two stories collide | ADR 0033 |

Sights: (1) the arched niches of the early stone house, `attested`; (2) wheel crosses scratched high on the walls (consecration marks), `plausible composite` for 1343; (3) the Cistercian well, `plausible composite`; (4) the hand-sign table in the cloister, `attested` practice; (5) a pillaged grain store with the Danish king's charter chest, `plausible composite`.

## 9. Resources: what must be generated

`asset.kit.limestone_castle` is defined in [`paide_castle.md`](paide_castle.md); only its masonry parts are cited here. `asset.kit.timber_harbour` (mill pier) is defined in [`parnu.md`](parnu.md).

### 9.1 Structures and architecture

| Asset id | Description | Pri | Shared with | Notes |
|---|---|---|---|---|
| `asset.kit.monastic_timber` | **Shared kit:** timber oratory shell, bellcote, posted pentice (cloister_walk), plank range, shingle and thatch roofs, scorched variants | P1 | Poide (chapel wing), Paide (market chapel) | Evidence: Kadakas 2011 timber hypothesis; existing map primitives `timber_oratory_1343`, `unheated_timber_range_1343` |
| `asset.padise.early_stone_hall` | Two-storey limestone hall with undercroft, columned undercroft hall | P1 | | Built from `asset.kit.limestone_castle.convent_range` masonry |
| `asset.padise.arched_niche_house` | Smaller limestone block with arched niches | P1 | | |
| `asset.padise.watermill_overshot` | Timber mill with overshot or undershot wheel, race, pond | P2 | Saaremaa (no) | |
| `asset.padise.infirmary_timber` | Infirmary with herb rack | P2 | | |
| `asset.padise.brewhouse_bakehouse` | Plank brew-bake house with kegs, malt kiln | P2 | | |
| `asset.padise.precinct_wall_low` | Low fieldstone wall with timber gate | P2 | Saaremaa (kiviaed relation) | |
| `asset.padise.burnt_variants` | Scorched sill, roofless timber, collapsed rafters, ash patches | P1 | all burnt sites | |
| `asset.padise.rebuild_scaffold` | Optional Phase C scaffolds, footings, mortar tubs | P3 | | |

### 9.2 Props and craft objects

| Asset id | Description | Pri | Shared with | Notes |
|---|---|---|---|---|
| `asset.prop.chalice_and_paten` | Silver-gilt chalice, paten | P1 | Poide | Chalice repair quest |
| `asset.prop.reliquary_box` | Small wood-and-silver reliquary | P2 | Poide | |
| `asset.prop.choir_book_chained` | Antiphonary and psalter on a lectern | P1 | | Parchment, no printed text |
| `asset.prop.processional_cross` | Wooden cross with metal fittings | P2 | Poide | |
| `asset.prop.bell_small` | 40 cm bell, clapper | P1 | Paide, Poide | |
| `asset.prop.scriptorium_set` | Quill, ink horn, parchment, knife | P2 | Paide | |
| `asset.prop.herb_drying_rack`, `asset.prop.brew_keg_stack` | Existing greybox props; refine | P2 | | |
| `asset.prop.wheel_cross_plaster` | Incised consecration cross decal | P3 | | |
| `asset.prop.hand_sign_board` | Wax board with sign sketches | P3 | | `invented` aid |

### 9.3 Characters

| Asset id | Description | Pri | Shared with | Notes |
|---|---|---|---|---|
| `asset.char.wardrobe.cistercian_white_choir` | White habit, scapular, hood, belt, tonsure | P1 | | One shared rig plus wardrobe ([`CHARACTER_GENERATION.md`](../CHARACTER_GENERATION.md)) |
| `asset.char.wardrobe.cistercian_grey_lay` | Undyed grey-brown cowl, apron, beard | P1 | | |
| `asset.char.wardrobe.abbot_ceremonial` | Cope, ring, crozier prop | P2 | | |
| `asset.char.wardrobe.novice` | Short white tunic | P2 | | |
| `asset.char.wardrobe.estonian_tenant` | Homespun, felt hat | P1 | all rural | |
| Hair/beard: tonsure, balding old man, braid | | P1 | | |

### 9.4 Fauna

| Species | Status | Notes |
|---|---|---|
| Horse, cattle, sheep, pig, chicken, goose, duck, dog, cat | already cataloged | Pigsty, pasture |
| Rook, hooded crow, great spotted woodpecker, skylark, grey heron, mallard, tawny owl, osprey | already cataloged | Mill pond |
| Brown bear, wolf, lynx, elk, red deer, roe deer, beaver, otter | already cataloged | Forest edges (B: wolf near cemetery) |
| Bees (apiary `asset.fauna.honeybee_skep`) | missing | P3, wax for candles |
| Carp or pike pond fish `asset.fauna.fish_pond_set` | missing | P3 |

### 9.5 Flora and ground cover

Existing: `tree.linden`, `tree.pine`, `tree.spruce`, `tree.oak`, `tree.birch`, `tree.apple`, `tree.cherry`, `plant.mugwort`, `plant.chamomile`, `plant.st_johns_wort`, `plant.yarrow`, `plant.caraway`, `plant.mint`, `crop.rye`, `crop.barley`, `crop.hops`, `crop.cabbage`, `crop.onion`, `crop.pea`, `plant.moss`, `plant.fern`. Missing: yew (`tree.yew`, a monastic cemetery tree; the map currently stands in `tree.linden`) P2; `plant.sage`, `plant.rue`, `plant.lovage` (cloister herb garden) P3; `plant.madder` (dye) P3.

### 9.6 Materials, terrain, water

`asset.mat.shingle_oak_weathered` P1; `asset.mat.charred_timber` P1; `asset.terrain.ash_and_char` P1; river water clear brown P2; `asset.mat.lime_wash` is cited from the kit.

### 9.7 Audio and music direction

Languages heard: Latin psalmody and Mass, German murmurs, Estonian work calls; silence between hours. Phase A: Gregorian chant (Kyrie, Gloria, Sanctus, Agnus Dei; Matins, Lauds, Prime, Terce, Sext, None, Vespers, Compline), a single bell, mill wheel, hand tools. Phase B: wind through burnt beams, crows, dripping water, one cracked bell, no choir. Music: monophonic chant only for A; solo voice and cello for B (per legacy brief). Instruments (period): voice, organum fragments, hand bell, chime bar. Latin audio needs a real-text pass (liturgical calendar: [`liturgical-calendar-spring-1343.md`](../../history/dossiers/religion/liturgical-calendar-spring-1343.md)).

## 10. Variety signature and risks

- **Palette:** pale lime-wash stone and white habits against dark spruce; B: soot black, ash grey, one white habit in the ash.
- **Silhouette:** dispersed low shingled roofs, a small bellcote, one limestone mass.
- **Soundscape:** Latin office hours and a mill wheel; B: wind and silence.
- **Massacre handling:** the killing of the monks is never staged. The player arrives after the sack (Phase B) or sees only the last quiet hour before (Phase A). Evidence: a tally of names on a wax board, scorch patterns, a single survivor's halting account, burial ground. No violence close-ups; no depiction of rebels as cartoon killers or monks as martyr-saints only. The legacy "Spirit of Vengeance" NPC is dropped; a "child's lost toy" prop is kept only if handled as a quiet object.
- **Anachronism:** no fortified claustrum, no Soviet Paldiski, no gunpowder, no stone church.
- **Religion sensitivity:** Latin liturgy shown with respect; the rebels' grievance (tithe, land) remains legible.
- **Scope:** the map already exists at 140x90; the optional Rågervik/Paldiski sub-zone is a scope addition (equivalent compression: drop Phase C scaffolds).
- **Performance:** big map, many props; chunk by zone (see [`ADR 0010`](../adr/0010-large-map-runtime-chunking.md)).
- **Open questions:** (1) Is Phase B the 1 May 1343 burnt estate only, as in the map? (2) Include the Phase C rebuild? (3) Is "Grey Brother" the right label (lay brothers historically in brown/grey)?

## 11. Sources and next steps

Repo: [`padise_monastery_research_p6_009.md`](../reports/padise_monastery_research_p6_009.md), `world_padise.rrmap`, [`padise_monastery_massacre.md`](../../wiki/events/padise_monastery_massacre.md), [`CANON.md`](../CANON.md), [`TOURIST_LANDMARKS.md`](../TOURIST_LANDMARKS.md), [`churches-and-religious-houses.md`](../../history/dossiers/religion/churches-and-religious-houses.md), [`p6_001_act3_design.md`](../reports/p6_001_act3_design.md). External by name: Villu Kadakas, *Archaeological Studies in Padise Monastery* (AVE 2011); Padise Monastery permanent exhibition; Cistercian Rule and customary.

Verification tasks: (1) reconcile research Phase 2 notes with Kadakas; (2) verify the 1305 and 1317 dates; (3) check whether the abbey held Rågervik rights in 1343; (4) author interior routes in the limestone hall; (5) liturgical Latin sourcing and recording; (6) sensitivity review of the sack scenes.
