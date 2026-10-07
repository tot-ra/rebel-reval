# Saaremaa (Ösel; north coast, alvar and the Kaali crater)

**Status:** planned (design proposal, not implemented) · **Scope gate:** existing prototype `loc.world_saaremaa` · **Act(s):** 3 (July 1343 muster, winter 1343-44, 1345 pacification aftermath)
**Map id:** `loc.world_saaremaa` (existing: [`content/maps/world_saaremaa.rrmap`](../../content/maps/world_saaremaa.rrmap), 104x60 cells, `scope=prototype`, `active=false`) · **Seasons/phases:** A "muster" (July 1343, dry grass, long light), B "frozen sea" (Feb 1344, ice, snow on limestone), C "after" (winter 1345, submission and demolition of island works); the existing map is phase A only
**Confidence summary:** July 1343 rising, killing of German lords, march on Pöide, Vesse as rebel leader: `attested`. Tharapita as the god of the Oeselians in Henry of Livonia's 13th-century chronicle: `attested` (belief in 1343 `folklore`). Kaali as a prehistoric cult site with stone enclosure: `attested` (archaeology); its 1343 use: `plausible composite`. Dialect forms, individual NPCs, hamlet layout: `plausible composite` / `invented`. Design basis: [`saaremaa_kaali_location_design.md`](../reports/saaremaa_kaali_location_design.md).

## 1. Why a player would want to visit

- A different Estonia: bare limestone, juniper, sea light and a horizon with almost nothing on it.
- Kaali crater, a walkable ritual bowl with a lake: the one natural wonder in the game, tied to omen-reading before battle.
- A people with a distinct dialect, boats, food and gods; the island has not been under a lord as long as the mainland.
- The moral set-up for Pöide: the player stands in the camp before the oath, the betrayal and the massacre are decided.
- **Signature:** a flat, bleached limestone-and-juniper coast under a huge sky, with sea on three sides and a crater lake in the middle.

## 2. History in 1343

| Fact | Label | Note |
|---|---|---|
| Rising on 24 July 1343: German lords killed, manors burned, priests drowned (chronicle tradition), march on Pöide | `attested` | [`CANON.md`](../CANON.md). Priest drownings are chronicle reports and must be handled with restraint. |
| Vesse as the rebels' leader ("king"), captured at Karja and executed Feb 1344 | `attested` | Karja and Vesse stay an off-map echo here (section 8). |
| Island divided between Bishopric of Ösel-Wiek and the Livonian Order (Pöide, east) | `attested` (background); bishopric is not a launch faction | The bishop's seat is at Haapsalu on the mainland in 1343; no stone Kuressaare. |
| Tharapita (Taarapita) invoked by Oeselians | `attested` in Henry of Livonia (c. 1227); 1343 oath-use `folklore` | See [`belief-omens-and-healing.md`](../../history/dossiers/folklore/belief-omens-and-healing.md): the chronicle places Tharapita's birth on a hill in Virumaa; he flew to Ösel. |
| Kaali crater (~110 m, ~3,500 years old) with a stone enclosure wall | `attested` (archaeology); medieval ritual function `plausible composite` | Map compresses it to ~30 cells. |
| Alvar, limestone pavement, juniper, dry-stone walls | `attested` landscape; present-day wall pattern mostly later, so period walls are low, patchy `plausible composite` | The existing map uses `kiviaed` at 16 cm height. |
| Pacification winter 1345; Maasilinna (Soneburg) begun as "castle of atonement" | `attested` | Aftermath concept only; not shown built. |
| Kuressaare stone castle, Maasilinna masonry, windmills, Kuressaare town | anachronism | Excluded. |

Phases: A (muster) is the playable summer ground. B (frozen sea) is a loading-visual overlay on the same coast, with Order troops crossing the ice from the mainland; shown as aftermath markers, not a battle. C (after): fortresses demolished, weapons handed over, bare landing.

## 3. Landscape and layout

Biome: Baltic island of Ordovician-Silurian limestone and dolomite; alvar grassland on thin soil, juniper scrub, pine on dunes, coastal reeds, flat, windy, bright. Sea north, west and east; a pine belt screens the south road.

| Zone (existing map) | Cells | Reads as | Carries |
|---|---|---|---|
| Ferry bay and pier | x0-20, y8-29 | Sheltered bay, timber landing | `ferry_to_reval` |
| Fishing hamlet | x20-48, y12-31 | Boat sheds, smoke cottages, net store, well | Civilians, fish economy |
| Alvar pasture | x20-37, y32-45 | Dry grass, limestone pavement, sheep | Island silhouette |
| Muster camp | x40-60, y30-50 | Brushwood shelters, field forge, banner | Staging for Pöide |
| Burnt manor | x8-28, y40-50 | Ash and roofless rubble shells | Consequence of July |
| Kaali crater | x53-87, y24-50 | Mossy slope, bare inner slope, shallows, lake, bank | Ritual centre, omen reading |
| Strait landing | x88-104, y28-46 | East beach and second pier | `ferry_to_parnu` |
| South wood | y51-60 | Pine belt | Road to Pöide |

Sub-zones (proposed, optional, no new maps): **Muhu strait edge** (east beach, tide flats, a stone-footed wayside shrine, `plausible composite`) and **Sõrve spit** (south peninsula seen on the horizon; seal rocks and wreck-wood; reachable only as a boat travel event). Both are dressing for the existing zones, not new nodes.

Anchors (existing): `landmark_island_coast`, `landmark_ferry_landing`, `landmark_fisher_hamlet`, `landmark_muster_camp`, `landmark_west_camp`, `landmark_east_camp`, `landmark_burned_manor`, `landmark_kaali_crater`, `landmark_kaali_lake`, `landmark_strait_landing`. Proposed: `landmark_offering_stone`, `landmark_net_store`, `landmark_seal_rocks`, `landmark_muhu_shrine`. Journey edges (existing): `ferry_to_reval`, `ferry_to_parnu`, `road_to_poide`.

## 4. Architecture and built environment

- **Island vernacular:** low log or stacked limestone-footed smoke cottages (chimneyless), thatched with reed or straw; boat sheds of plank and thatch on the dune; net stores; brushwood muster shelters ([`rural-smoke-dwelling-and-farmstead-1343.md`](../../history/dossiers/architecture/rural-smoke-dwelling-and-farmstead-1343.md)).
- **Dry-laid limestone** field walls (`kiviaed`), knee-high, with gate gaps; slabs of local dolomite stand as gate-posts and boundary cairns.
- **Crater:** earth-and-stone bank with one gap, offering stones, wood posts with ribbons, pits for fire.
- **No church, no windmills, no stone manor.** The burnt manor is rubble-walled and low, a Baltic-German farmstead (`plausible composite`), not a keep.
- Construction state: poor, practical, windswept; every roof is weighted against gale.
- Distinct from other nodes: no castle, no market; the building types are boat and byre.

## 5. Cultures, languages, and people

| Group | Language | Wardrobe / notes |
|---|---|---|
| Islanders (fishers, herders, seal-hunters) | Estonian, Saaremaa/island dialect (`plausible composite` features: palatalised forms, open vowels, different words for tools and boats; avoid 19th-c. dialectology as fact) | Undyed and indigo wool, sheepskin vests, hide moccasin-like shoes (pasteln), bone toggles |
| Cult priesthood (crater) | Estonian, ritual formulae | Dark cloaks, ribbon-tied staffs, amber and bone; `folklore` |
| Surviving German manor servants | Low German | Plainer wool, kept hidden |
| Mainland rebels (Harju/Lääne messengers) | Estonian (North/West) | Travel-stained |
| Order sentries (distant) | MHG | Seen only on the Pöide road |
| Swedish-speaking sailors (rare) | Old Swedish | Seen at piers |

Religion: nominal Christianity by baptism after 1227, strong older belief in Tharapita, hiis sites, and sky-fire omens (`folklore`). Customs: seal-hunting rights, boat-launching luck, juniper smoke, bread-and-wool offerings. Names: Estonian forenames, short patronymic forms; no Kreutzwald-style invented gods.

## 6. Factions present

| Faction id | Presence | Wants | Where | Act-by-act |
|---|---|---|---|---|
| `cult_metsik` | Dominant | Legitimise the rising; omen before Pöide | Crater, muster | A: omen quest; B: martyr cult; C: driven underground |
| `livonian_order` | Distant | Hold Pöide; crush the rising | Pöide road, offstage | A: threat; B: crossing the ice; C: occupation |
| `harju_kings` | Echo | Mainland solidarity | Muster | Fading after Paide |
| `hanseatic` | Minor | Fish and salt trade via Reval | Ferry, hamlet | Constant; fishermen with a German buyer |
| `vitalienbruder` | Minor | Smuggled goods and boats | Strait landing | A-B |
| `danish_crown`, `black_cloaks`, `pskov_novgorod` | None | - | - | Rumour |
| Bishopric of Ösel-Wiek | Background canon | Hold land and tithe | Absent | Rumour only |

## 7. Characters

| char id | Name | Role / faction | Language | Confidence | Source | Hook |
|---|---|---|---|---|---|---|
| `char.vesse` | Vesse | Island rebel leader | Estonian | `attested` (person); portrayal `plausible composite` | [`CANON.md`](../CANON.md) | Swears to the oath at the stone |
| `char.ellen_luik` | Ellen Luik | Cult leader | Estonian | `invented` | legacy [`ellen_luik.md`](../../characters/metsik_cult/ellen_luik.md), existing [`ellen.md`](../CHARACTERS/ellen.md) | Presides over the omen |
| `char.urmas_laar` | Urmas Laar | Seer | Estonian | `invented` | legacy [`urmas_laar.md`](../../characters/rebels/urmas_laar.md) | Sees Kalev/Apprentice in his visions |
| `char.kaja` | Kaja | Courier | Estonian | `invented` | existing [`kaja.md`](../CHARACTERS/kaja.md) | Delivers messages from the mainland |
| `char.apprentice` / `char.kalev` | Apprentice / Kalev | Protagonists | Estonian | `invented` | existing [`apprentice.md`](../CHARACTERS/apprentice.md), [`kalev.md`](../CHARACTERS/kalev.md) | Field forge at camp; the Apprentice sees the crater |
| `char.saaremaa_ferryman` | Matts the ferryman | Ferry master | Estonian (island) | `invented` (NEW) | NEW | His mare is a possible offering |
| `char.saaremaa_bailiff` | Hinrik the bailiff's clerk | Hidden German servant | Low German | `invented` (NEW) | design report quest 5 | The "offering" the priesthood wants |
| `char.saaremaa_net_mender` | Tiiu the net-mender | Hamlet keeper, hides the clerk | Estonian | `invented` (NEW) | NEW | Moral pivot |
| `char.saaremaa_cairn_warden` | Old Ose | Warden of the crater stones | Estonian, ritual idiom | `folklore` / `invented` (NEW) | NEW | Knows the old oath words |
| `char.saaremaa_muster_captain` | Captain Kaido | Rebel muster captain | Estonian | `invented` (NEW) | NEW | Wants Pöide iron and grain |
| `char.saaremaa_seal_hunter` | Rein of the skerries | Seal hunter, strait guide | Estonian | `invented` (NEW) | NEW | Knows ice routes |

Crowd archetypes: net-mender, seal-skinner, herder with sheep, boat-builder, muster archer, woman with water-yoke, juniper-smoke curer, child with fish basket.

## 8. Quests, encounters, and discoveries

Quest seeds follow [`saaremaa_kaali_location_design.md`](../reports/saaremaa_kaali_location_design.md); the numbered seeds are `invented` on `attested` ground.

| id proposal | Act | Type | Hook | Ties |
|---|---|---|---|---|
| `quest.saaremaa_omen` | 3 | spirit-world | The muster will not march until the crater reads favourably; an offering is demanded | `beat.landmark.estonia.kaali_meteorite_craters` |
| `quest.saaremaa_siege_iron` | 3 | forge commission | Salvage fittings from the burnt manor to forge siege iron at the camp | CANON: player-forged siege iron |
| `quest.saaremaa_oath_at_stone` | 3 | investigation | Persuade the captain to swear safe passage for Pöide at the offering stone | Pöide massacre branch |
| `quest.saaremaa_ferry_keeps_running` | 3 | travel event | Keep or cut the Reval ferry | `faction.hanseatic` |
| `quest.saaremaa_bailiff_net_store` | 3 | exploration | Decide what to do with the hidden clerk | Quests 1 and 3 |
| `quest.saaremaa_ice_crossing` | 3 | travel event | Phase B: Order column crosses the frozen sea; escape or witness; Karja is off-map | Karja Feb 1344 |
| `quest.saaremaa_hand_over_arms` | 3 | exploration | Phase C: arms collection, demolition; reflect | 1345 pacification |

Karja fortress and Vesse's execution remain off-map: the player learns of it by a returning boatman, a missing banner, a woman's cry across the strait. Sights: (1) the crater rim at dawn, `attested`; (2) a bare limestone pavement with glacial grooves, `attested` landscape; (3) a seal rock at low tide, `plausible composite`; (4) the gate-gap in a `kiviaed` wall with a bundle of rye, `folklore`; (5) a Tharapita story told by Old Ose, `attested` name, tale `folklore`.

## 9. Resources: what must be generated

`asset.kit.limestone_castle` is defined in [`paide_castle.md`](paide_castle.md); not used here beyond rubble props. `asset.kit.timber_harbour` is defined in [`parnu.md`](parnu.md); a small jetty subset is used.

### 9.1 Structures and architecture

| Asset id | Description | Pri | Shared with | Notes |
|---|---|---|---|---|
| `asset.kit.island_vernacular` | **Shared kit:** low smoke cottage with reed-thatch, net store, boat shed, hay barn, plank pier, fish rack, sauna hut | P1 | Pöide (outer huts), Pärnu (edge cottages) | Existing styles `rural.smoke_cottage`, `coast.boat_shed` as base; evidence: rural dossier |
| `asset.saaremaa.kiviaed_wall_set` | Dry-laid limestone wall, 6 variants, gate gap, cairn | P1 | Pöide | Replaces the single style `wall.kiviaed` |
| `asset.saaremaa.crater_bank_and_stones` | Bank, offering stone, standing slabs, fire pit, ribbon posts | P1 | | Kaali enclosure type |
| `asset.saaremaa.burnt_manor_shells` | Rubble shells, ash, bent hinges | P1 | | Reuse `asset.padise.burnt_variants` look-alike materials |
| `asset.saaremaa.muster_shelter_brushwood` | Brushwood and hide shelters, field forge | P2 | | |
| `asset.saaremaa.kaali_crater_terrain` | Crater bowl terrain with lake; needs ring elevation primitive | P1 | | Open issue in the design report |

### 9.2 Props and craft objects

| Asset id | Description | Pri | Shared with | Notes |
|---|---|---|---|---|
| `asset.prop.juniper_tableware` | Juniper bowls, tankards, spoons | P2 | | Island craft, `plausible composite` |
| `asset.prop.amber_bone_toggle_set` | Amber beads, bone toggles, bronze pendants | P2 | Pärnu | |
| `asset.prop.sheep_wool_cloak` | Wool cloak, ribbon-edged | P2 | | Saaremaa weaving, type only; not Muhu embroidery (19th c.) |
| `asset.prop.seal_skin_boat_gear` | Seal-skin float, bone harpoon, net sinkers | P1 | Pärnu | |
| `asset.prop.fish_rack_and_salt_barrel` | Herring racks, wooden salt barrels | P1 | Pärnu | |
| `asset.prop.ferry_boat_clinker_open` | (defined in [`parnu.md`](parnu.md)) | - | - | Cited |
| `asset.prop.offering_bundle` | Bread, wool, wax, yarn bundle | P2 | | Matches dossier offering list |
| `asset.prop.sacrificial_ram_stand` | Ram on lead rope (no kill shown) | P3 | | Restraint |

### 9.3 Characters

| Asset id | Description | Pri | Shared with | Notes |
|---|---|---|---|---|
| `asset.char.wardrobe.islander_fisher` | Indigo wool, sheepskin vest, hide shoes | P1 | Pöide | |
| `asset.char.wardrobe.islander_woman` | Wool dress, shawl, headcloth, amber | P1 | Pöide | |
| `asset.char.wardrobe.cult_priest` | Dark cloak, ribbon staff, antler or bone ornament | P1 | | `folklore` |
| `asset.char.wardrobe.muster_fighter` | Round shield, spear, leather cap, wool coat | P1 | Pöide | Not armoured |
| `asset.char.wardrobe.german_clerk_hiding` | Plain gown, ink-stained | P3 | | |

### 9.4 Fauna

| Species | Status | Notes |
|---|---|---|
| Grey seal, ringed seal | already cataloged | Seal rocks |
| Sheep, cattle, horse, pig, goose, dog | already cataloged | Alvar pasture |
| White-tailed eagle, osprey, herring gull, common tern, cormorant, mute swan, grey heron, skylark | already cataloged | Coast |
| Hare, red fox, roe deer, elk, wolf | already cataloged | Wild margins |
| Eurasian crane `bird.common_crane` | missing | P2 |
| Eider `bird.common_eider` | missing | P2, strand |
| Greylag already cataloged; Barnacle goose `bird.barnacle_goose` | missing | P3 |
| Baltic herring, flounder, pike `asset.fauna.fish_set_sea` | missing | P2 (shared with Pärnu) |
| Adder `asset.fauna.adder` (alvar) | missing | P3 |

### 9.5 Flora and ground cover

Existing: `tree.juniper`, `tree.pine`, `tree.birch`, `tree.oak`, `bush.juniper_shrub`, `bush.coastal`, `bush.heath`, `bush.sea_buckthorn`, `bush.heather`, `grass.dry`, `grass.short`, `grass.mossy`, `plant.moss`, `plant.fern`, `plant.reed`, `crop.rye`, `crop.barley`. Missing: `plant.alvar_sedge_pavement` (thin-soil sedge and stonecrop) P1; `plant.sea_thrift`, `plant.sea_holly`, `plant.sea_lyme_grass` (strand) P2; `plant.orchid_alvar` (alvar orchids, e.g. spotted orchid) P3; `plant.sundew` (crater bog edge) P3; `tree.dwarf_pine_coastal` P3.

### 9.6 Materials, terrain, water

`asset.terrain.alvar_limestone_pavement` (bare cracked slab, grykes) P1; `asset.terrain.crater_inner_slope` P1; `asset.water.crater_lake_still` (dark, tinted) P1; `asset.water.baltic_open_clear` P2; `asset.terrain.frozen_sea_ice` (Phase B) P2; `asset.terrain.shingle_beach_boulders` (existing shore debris family, see [`FLORA_FAUNA.md`](../FLORA_FAUNA.md)) P3.

### 9.7 Audio and music direction

Languages heard: island dialect of Estonian, Low German (rare), Old Swedish (pier). Ambience: wind on open ground, surf and ice-creak (B), sheep bells, crater echo, juniper crackle, gulls, boat hull on shingle. Music: solo voice and low string drone, a kannel-like plucked line (`plausible composite`); drum only for the omen scene, sparse; no cinematic shamanism. Avoid the legacy "shamanic throat-singing" cliché unless a source supports it. Instruments (period): voice, jaw harp, bagpipe, bone flute (`plausible composite`).

## 10. Variety signature and risks

- **Palette:** bleached limestone, juniper green-black, dull silver sea, blue-grey sky; B: white ice; C: grey ash.
- **Silhouette:** flat horizon, a crater bowl, low roofs weighted by stones.
- **Soundscape:** wind, surf and an island accent.
- **Massacre handling:** no massacre is staged on this map. The July killings of lords and priests are reported by the burnt manor and the net-store clerk, not shown as action. The Pöide betrayal (see [`poide_castle.md`](poide_castle.md)) is decided here by an oath scene; the moral cost is carried in dialogue, not spectacle. The priest drownings are not depicted.
- **Religion/ethnicity sensitivity:** Oeselian belief is shown as lived practice, not as fantasy paganism; Tharapita is labelled, 1343 usage is `folklore`.
- **Anachronism:** no windmills, no Kuressaare, no Maasilinna built, no Muhu embroidery as 1343 fact, no lighthouses. Dolomite-built farm walls are patchy.
- **Scope:** existing map; sub-zones Muhu/Sõrve are dressing only. Ring-capable elevation primitive is a tooling dependency.
- **Performance:** big flat sight lines; use instanced juniper and stone scatter.
- **Open questions:** (1) Are Phase B/C overlays on this map or separate loads? (2) Keep the sacrifice-offering mechanic as presented in the design report? (3) How explicit should the priest-drowning references be in journal text? (default: summary line only).

## 11. Sources and next steps

Repo: [`saaremaa_kaali_location_design.md`](../reports/saaremaa_kaali_location_design.md), [`world_saaremaa.rrmap`](../../content/maps/world_saaremaa.rrmap), [`CANON.md`](../CANON.md), [`p6_001_act3_design.md`](../reports/p6_001_act3_design.md), [`cult_metsik.md`](../CITIZENS/factions/cult_metsik.md), [`belief-omens-and-healing.md`](../../history/dossiers/folklore/belief-omens-and-healing.md), [`HISTORY.md`](../../history/HISTORY.md), [`saaremaa.md` (legacy)](../../scenes/events/saaremaa.md). External by name: Henry of Livonia, *Chronicon Livoniae* (Tharapita); Kaali crater archaeology (Estonian archaeologists, 20th-21st c.); Saaremaa dialect studies.

Verification tasks: (1) confirm 1343 stone-wall practice; (2) read Henry's Tharapita passage in a critical edition and record exact references; (3) check seal-hunting and fish economy sources; (4) build the ring elevation primitive or accept the compression; (5) sensitivity pass on the omen offering; (6) blueprint review per [`MAP_AUTHORING.md`](../MAP_AUTHORING.md).
