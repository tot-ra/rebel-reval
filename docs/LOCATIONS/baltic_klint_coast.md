# Baltic Klint Coast (Glint coast; Estonian *Põhjaranniku klint*, Low German *de Strand*, 1343 name unverified)
**Status:** planned (design proposal, not implemented) · **Scope gate:** new (needs ADR + task) · **Act(s):** Act 2 (travel and signal-fire watch), Act 3 (smuggler hideout, quarry commissions)
**Map id:** `loc.world_klint` (proposed; no `content/maps/` file yet) · **Seasons/phases:** Apr-May 1343 (spring spray, snowmelt-fed falls), Jul 1343 (green cliff forest), winter 1344-45 (iced falls, frozen shore)
**Confidence summary:** the landscape (limestone cliff, waterfalls, erratics, quarries) is `attested` as physical geography; medieval use of specific sites is `plausible composite`; the Vitalienbrüder hideout and all named people are `invented`; folk beliefs about erratics are `folklore`.

## 1. Why a player would want to visit
- The only node where the player stands on a cliff: a 30-55 m limestone wall (the Baltic Klint, Glint) with a waterfall dropping into the sea. Every other node is flat, forest or town.
- Boulders as big as houses (glacial erratics of Lahemaa type) and a coast of grey stone, wet spray and spruce on the cliff-top, unlike the sandy Pärnu shore or the Saaremaa islands.
- A working stone landscape: quarries and lime kilns that supply Reval's walls, the visible reason the capital is built of grey limestone.
- A watch-fire coast: smoke and beacon fires on the cliff-top carry news of the rising along the Gulf, tying to the St George's Night signal motif.
- **Signature:** "the node with a drop": vertical grey stone, white water falling into the sea, lime-smoke on the wind.

## 2. History in 1343
| Claim | Label | Note |
|---|---|---|
| The Baltic Klint runs along North Estonia; Ontika cliff is ~56 m, Valaste falls ~30 m (modern figures) | `attested` (geography) | Waterfall flow is snowmelt-dependent: strongest April-May, a gift for the spring setting |
| Keila (Keila-Joa) and Jägala falls, 6-8 m, with mill sites on the rivers | `attested` geography; medieval mills `plausible composite` | See [TOURIST_LANDMARKS.md](../TOURIST_LANDMARKS.md) items 7 and 23 |
| Limestone quarried and burnt for lime near Reval for the city walls and Toompea | `attested` (Reval's building stone is local limestone); specific quarry sites `plausible composite` | Cement works (Kunda, 19th c.) are an anachronism: do not show |
| Large erratics (Lahemaa boulders, e.g. Majakivi) | `attested` geography; sacredness `folklore` | Cup-marked "offering stones" are `plausible composite` |
| Estonian and Swedish speakers on the north-west coast and islands | `attested` for Swedes in Läänemaa/Vormsi/Noarootsi from the 13th-14th c.; presence on this exact stretch `plausible composite` | See [CULTURES_AND_LANGUAGES.md](./CULTURES_AND_LANGUAGES.md) |
| Coastal beacon/signal-fire watch | `plausible composite` | Medieval coast watch existed in the Baltic; no 1343 record for this stretch |
| Vitalienbrüder hideout in a cove | `invented` | The sea-robber group name is the game's shorthand: [vitalienbruder.md](../CITIZENS/factions/vitalienbruder.md) |

**Phases.** Act 2: rebel messengers and refugees pass along the shore road; Order and crown riders patrol. Act 3: the cove becomes a smuggling base while Order tolls tighten; quarry labour is requisitioned for Order works.
**Do NOT show:** Toolse castle (built about 1471), Käsmu captain village (19th c.), Kunda cement plant, lighthouses (Kõpu 1500s), summer-resort villas, Soviet border-guard towers.

## 3. Landscape and layout
**Biome:** Glint cliff coast and klint forest (see [BIOMES_AND_WILDLIFE.md](./BIOMES_AND_WILDLIFE.md)). Limestone terrace on top, a talus slope of fallen blocks and ash/maple/elm "klint forest" under the face, shingle and boulder beach below. The cliff is a one-way navigation feature: descent only at the three marked paths.
**Map footprint (proposed):** about 96 x 30 cells, same compact greybox scale as `world_*` nodes; east-west strip along the coast.

| Zone id | Cells (x) | Content | Season note |
|---|---|---|---|
| `zone_shore_road` | 0-18 | Entry from Reval/Harju side; limestone road, ford at a small river | Mud in April, dust in July |
| `zone_waterfall_valley` | 18-38 | Stepped river, mill ruin foundation, 30 m falls into the sea (scripted, non-walkable drop) | Roaring in April-May; trickle in July; ice column in winter |
| `zone_quarry` | 38-58 | Open limestone quarry, kiln row, stone sledges, labour camp | Smoke most of the year; kilns idle in deep winter |
| `zone_erratic_forest` | 58-78 | Coastal spruce/pine forest with giant boulders, offering stone | Dim green, mossy; hiis-like unease |
| `zone_fishing_hamlet` | 78-92 | Estonian and Swedish hamlet, boat sheds, smoke racks, signal-fire post above | Seals on skerries in spring |
| `zone_smuggler_cove` | 92-96 | Hidden cove below the klint, reachable by rope path or by boat | `invented`, Act 3 |

**Landmarks (anchor ids):** `landmark_waterfall_valaste_type`, `landmark_cliff_edge_overlook`, `landmark_quarry_face`, `landmark_lime_kiln_row`, `landmark_great_erratic`, `landmark_offering_stone`, `landmark_signal_fire_post`, `landmark_hamlet_boat_sheds`, `landmark_smuggler_cove_rope`.
**Journey edges:** Reval/Harju (`world_harju`, west, road); Rakvere-Wesenberg (east, [rakvere_wesenberg.md](./rakvere_wesenberg.md)); sea edge to Padise/Läänemaa by boat (optional, journey with loading transition). All edges are explicit travel, not seamless.

## 4. Architecture and built environment
Types are defined in [ARCHITECTURE_TYPOLOGY.md](./ARCHITECTURE_TYPOLOGY.md); this node uses:
- `asset.kit.lime_kiln_and_quarry` (stone shaft kiln, charging platform, sledge track, split-block stacks).
- `asset.kit.fishing_hut_and_boat_shed` (low log huts, tarred boats on skids, drying racks).
- `asset.kit.swedish_coastal_farmstead` (log barn-house, stone-fenced fields, a cluster of gable-end buildings facing the sea).
- `asset.kit.timber_beacon_post` (new here, `plausible composite`: stacked brush on a log tripod, windbreak hut).
- `asset.kit.water_mill_small` (new here, `plausible composite`: undershot wheel, timber race, stone foundation; mill ruin variant).
No castle on this node (Toolse is anachronistic); the nearest stone presence is the quarry itself. The cliff-top road shows wheel-ruts cut into bare limestone.

## 5. Cultures, languages, and people
| Group | Language | Dress tokens | Religion and custom |
|---|---|---|---|
| North-coast Estonians (Viru/Harju) | Estonian (north dialect) | Undyed wool kirtle, belted tunic, leather sandals/bast shoes, felt cap | Christian with strong folk layer; offering stone and hiis memory |
| Estonian Swedes (coastal families) | Swedish (old Estonian-Swedish dialect) + Estonian | Longer wool coat, knitted cap, tarred leather boots | Christian; coastal sailors' blessings; own fishing rights (unverified detail) |
| Quarry/lime labour | Estonian, some Low German foremen | Rough linen, leather aprons, rags over mouth | Obligatory labour for lord |
| Order or crown tax riders | Low German, Latin | Mail, tabard (Order white mantle with black cross), horse | Order brothers' rule |
| Vitalienbrüder crew (`invented`) | Low German, Swedish, Danish mix | Mismatched seamen's gear, no badge | Oaths on salt and steel (`invented`) |
Naming follows [names-address-and-oaths.md](../../history/dossiers/language/names-address-and-oaths.md): forename plus patronymic or place for Estonians; MLG hypocoristics for foremen.

## 6. Factions present
| Faction id | Presence | Wants | Where | Act-by-act |
|---|---|---|---|---|
| `danish_crown` | Weak; toll riders | Stone, grain, loyalty of coast | `zone_shore_road` | A2 patrols; A3 crown fading before 1346 sale |
| `livonian_order` | Growing after summer 1343 | Quarry output, coast control | `zone_quarry` | A3 requisitions labour |
| `harju_kings` | Refugees, messengers | Safe passage, signal relay | `zone_fishing_hamlet` | A2 retreat route |
| `vitalienbruder` | Hidden | A harbour, buyers for loot | `zone_smuggler_cove` | A3 base |
| `cult_metsik` | Elders at offering stone | Keep stones unmoved | `zone_erratic_forest` | A2 and A3 |
| `hanseatic` | Stone and lime buyers | Cheap lime for Reval | `zone_quarry` | Throughout |

## 7. Characters
| char id | Name | Role/faction | Language | Confidence | Source | Hook |
|---|---|---|---|---|---|---|
| `char.kaja` | Kaja | Bilingual courier, rebels | Estonian + MLG | `invented` | existing, [kaja.md](../CHARACTERS/kaja.md) | Uses the coast road and signal fire |
| `char.ellen` | Ellen Luik | Midwife, folklore keeper | Estonian | `plausible composite` | existing, [ellen.md](../CHARACTERS/ellen.md) | Knows the offering stone's story |
| `char.lembit_helme` | Lembit Helme | Harju Kings elder | Estonian | `plausible composite` | existing, [lembit.md](../CHARACTERS/lembit.md) | Needs relay of the fire signal |
| `char.henning` | Captain Henning | Viru Watch | MLG | `plausible composite` | existing, [henning.md](../CHARACTERS/henning.md) | Chases coast smugglers (Act 3) |
| `char.kalev` | Kalev | Master smith | Estonian + MLG | `invented` | existing, [kalev.md](../CHARACTERS/kalev.md) | Quarry iron tools commission |
| `char.klint_ketil` | Ketil the net-mender | Estonian Swede, fisherman | Swedish + Estonian | `invented` | NEW | Guide to cove, sells fish |
| `char.klint_oras` | Oras Pikk | Lime-burner foreman | Estonian + MLG | `invented` | NEW | Missing kiln worker quest |
| `char.klint_gesa` | Gesa Brandt | Vitalienbrüder captain | MLG, Swedish | `invented` | NEW | Replaces legacy anachronistic Störtebeker seed |
| `char.klint_mihkel` | Old Mihkel | Stone-reader of the offering stone | Estonian | `invented` | NEW | Spirit-world gate |
Crowd archetypes: stone-cutter, lime-burner, sledge-driver, net-mender, signal-watcher, rope-carrier, mill-hand.

## 8. Quests, encounters, and discoveries
| id proposal | Act | Type | Hook | Ties |
|---|---|---|---|---|
| `quest.klint_fire_on_the_cliff` | 2 | exploration | Light the signal post before the Order patrol arrives | `quest.st_georges_night` motif |
| `quest.klint_lime_for_the_wall` | 2 | forge commission | Kalev forges chisels for the kilns in exchange for stone news | `quest.stolen_iron` iron economy |
| `quest.klint_stone_that_listens` | 2 | spirit-world | Apprentice hears the offering stone; Hingepuu link | ADR 0033 |
| `quest.klint_cove_ledger` | 3 | investigation | Smugglers' tally book exposes a Reval factor | `vitalienbruder` ledger |
| `quest.klint_ice_ladder` | 3 | travel event | Winter rope descent past the frozen falls | winter phase |
**Sights (journal pages):** the falls in spring flood; a fossil-bearing limestone slab (Ordovician orthocone, `attested` natural history, no medieval knowledge claim); a cup-marked boulder; seals on the skerries; a cranes' flyover in April.

## 9. Resources: what must be generated
### 9.1 Structures & architecture
| asset id | Description | Pri | Shared with | Notes |
|---|---|---|---|---|
| `asset.kit.klint_cliff_modules` | Modular cliff face (layered limestone, ledges, drip lines, 12-60 m) | P1 | none | Reference: Valaste/Ontika photographs; layered Ordovician carbonate |
| `asset.kit.waterfall_stepped` | Scripted waterfall with spray particles and flow scaling by season | P1 | [soomaa_flood_refuge.md](./soomaa_flood_refuge.md) (spring cascades) | Flow high Apr-May |
| `asset.kit.lime_kiln_and_quarry` | Shaft kiln, quarry face, sledge track | P1 | [harju_village.md](./harju_village.md) (lime for wall) | Defined here; see typology |
| `asset.kit.timber_beacon_post` | Brush-pile signal fire post | P2 | [rebel_kings_camp.md](./rebel_kings_camp.md), [narva_peipus_east.md](./narva_peipus_east.md) | |
| `asset.kit.water_mill_small` | Mill ruin and working variant | P2 | [harju_village.md](./harju_village.md) | |
### 9.2 Props & craft objects
| asset id | Description | Pri | Shared with | Notes |
|---|---|---|---|---|
| `asset.prop.erratic_boulder_set` | Five house-size granite erratics with lichen | P1 | [sacred_grove.md](./sacred_grove.md) | Existing `shore_boulder_granite_*` are small, <=2.1 m |
| `asset.prop.offering_stone_cupmarked` | Boulder with carved cups, ribbons | P2 | sacred_grove | `plausible composite` |
| `asset.prop.limestone_block_stack` | Dressed and rough block stacks, sledge | P1 | [paide_castle.md](./paide_castle.md) | |
| `asset.prop.net_rack_and_smoke_rack` | Net-drying poles, fish smoke rack | P2 | [parnu.md](./parnu.md) | Existing fishing-net wind materials can be reused |
| `asset.prop.rope_ladder_cliff` | Hemp rope descent | P3 | none | |
### 9.3 Characters
| asset id | Description | Pri | Shared with | Notes |
|---|---|---|---|---|
| `asset.wardrobe.quarry_labourer` | Rags, sacking apron, leather knee pads | P2 | all rural nodes | Uses shared MPFB rig |
| `asset.wardrobe.swedish_coast_man` | Long coat, knit cap, tarred boots | P2 | [haapsalu_laanemaa.md](./haapsalu_laanemaa.md), [saaremaa.md](./saaremaa.md) | See [CULTURES_AND_LANGUAGES.md](./CULTURES_AND_LANGUAGES.md) |
| `asset.wardrobe.seaman_outlaw` | Mixed gear, cutlass-free (short seax) | P2 | vitalienbruder nodes | |
### 9.4 Fauna
| species | Status | Notes |
|---|---|---|
| Grey seal `fauna.grey_seal`, ringed seal `fauna.ringed_seal` | EXISTING (catalog) | Skerries |
| Herring gull, common tern, cormorant `bird.*` | EXISTING | Cliff colony |
| White-tailed eagle `bird.white_tailed_eagle` | EXISTING | Cliff-top |
| Raven `bird.raven` | MISSING | Cliff nesting |
| Peregrine falcon `bird.peregrine` | MISSING (unverified for 1343, `plausible composite`) | Cliff hunter |
| Common crane `bird.common_crane` | MISSING | April flyover |
| Eider duck `bird.common_eider` | MISSING | Coastal shallows |
| Trout/salmon `fish.sea_trout`, herring/Baltic herring `fish.baltic_herring` | MISSING (no fish system) | Falls pool and net catch props |
| Wolf, lynx, elk, boar | EXISTING | Klint forest |
### 9.5 Flora & ground cover
Existing: `tree.spruce`, `tree.pine`, `tree.ash`, `tree.elm`, `tree.maple`, `tree.linden`, `bush.sea_buckthorn`, `bush.juniper_shrub`, `plant.fern`, `plant.moss`. Missing: `plant.hepatica` (spring), `tree.wych_elm_cliff` variant (ground-cover tint), `plant.limestone_stonecrop` and lichen/moss on boulders (material layer), `plant.sea_kale`, `plant.coltsfoot`.
### 9.6 Materials / terrain / water
`mat.limestone_layered_wet`, `mat.limestone_quarry_cut`, `mat.lime_ash_white`, `terrain.cliff_talus`, `water.waterfall_spray`, `water.shore_shingle_and_surf` (extend existing shore debris, see [FLORA_FAUNA.md](../FLORA_FAUNA.md)).
### 9.7 Audio & music direction
Falls roar (dominant, seasonal), surf on shingle, gulls and terns, rope creak, kiln roar, chisels, Estonian and Swedish voices, small bell from a distant chapel. Instruments: kannel-like zither, bagpipe/fiddle-free solo drone; see [music-and-instruments.md](../../history/dossiers/culture/music-and-instruments.md).

## 10. Variety signature and risks
Palette: cold grey stone, white water, dark spruce, rust-orange kiln glow. Silhouette: vertical line of the cliff with a white thread of water. Soundscape: waterfall plus surf.
**Risks:** cliff vertical geometry vs top-down/orthographic camera; waterfall particles budget; anachronism (Toolse, lighthouses); romantic-pirate cliche; Swedish-Estonian identity shown without clumsy stereotyping. **Scope:** new node; propose to replace/compress one southern node (hub README decides). **Open questions:** keep smuggler cove (`invented`) or cut; sea-journey edge or road only.

## 11. Sources and next steps
Repo: [CANON.md](../CANON.md), [TOURIST_LANDMARKS.md](../TOURIST_LANDMARKS.md), [FLORA_FAUNA.md](../FLORA_FAUNA.md), [vitalienbruder.md](../CITIZENS/factions/vitalienbruder.md), [spring-climate-and-living-world.md](../../history/dossiers/nature/spring-climate-and-living-world.md), [estonian-and-german-populations.md](../../history/dossiers/people/estonian-and-german-populations.md). External (by name): Estonian Geological Survey (Baltic Klint), Lahemaa National Park materials, Estonian Open Air Museum.
**Verification tasks:** confirm medieval lime-burning near Reval (Reval town accounts); check Estonian Swede settlement dates on the Harju-Viru coast; verify Valaste/Ontika modern heights; confirm raven/peregrine presence; ADR for new node.
