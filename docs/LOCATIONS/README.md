# Locations beyond Reval: journey nodes, variety, and resources

**Status:** planned (design proposal, not implemented). No map, scene, or asset is added by these pages.
**Scope:** the ten existing distant prototypes (`loc.world_*`, `release=false`) are deepened; eight new journey nodes are *proposed*. Reval itself is covered by [`../SYSTEMS/SEAMLESS_CITY.md`](../SYSTEMS/SEAMLESS_CITY.md) and [`../TOURIST_LANDMARKS.md`](../TOURIST_LANDMARKS.md) Part I.
**Out of scope:** a seamless Estonia-wide world, playable Riga/Dorpat/Narva campaigns, army sims ([`AGENTS.md`](../../AGENTS.md), [ADR 0008](../adr/0008-three-act-campaign-and-faction-scope.md)). New nodes are compact authored travel greyboxes like the existing `world_*` maps (46-110 cells wide), not cities.

Each location page follows one template: why visit, history in 1343, landscape, architecture, cultures and languages, factions, characters, quests and discoveries, **resources to generate**, variety signature and risks, sources.

## Existing prototypes, deepened

| Page | Map id | Act | Signature |
|---|---|---|---|
| [Harju village](./harju_village.md) | `loc.world_harju` | 2 | Compact cluster village, smoke-dwelling farmsteads, manor yard, coast hamlets |
| [Sacred grove (hiis)](./sacred_grove.md) | `loc.world_sacred_grove` | 2 | Oak/ash grove, offering stone, spirit-world entrance |
| [Rebel kings' camp](./rebel_kings_camp.md) | `loc.world_rebel_kings` | 2 | Signal hill, wagon laager, the Four Kings |
| [Kanavere Bog](./kanavere_bog.md) | `loc.world_kanavere` | 2 | Raised bog, duckboards, 11 May battle |
| [Sõjamäe](./sojamae.md) | `loc.world_sojamae` | 2 | Lake Ülemiste shore, 14 May defeat |
| [Paide Castle](./paide_castle.md) | `loc.world_paide` | 2 finale | Order tower castle, truce hall, Four Kings killed |
| [Pärnu](./parnu.md) | `loc.world_parnu` | 2 | Hanseatic river-mouth port, ferry to the island |
| [Padise Monastery](./padise_monastery.md) | `loc.world_padise` | 2-3 | Cistercian house, before/after phases, Latin soundscape |
| [Saaremaa coast and Kaali](./saaremaa.md) | `loc.world_saaremaa` | 3 | Alvar, kiviaed, crater lake, seals |
| [Pöide Castle](./poide_castle.md) | `loc.world_poide` | 3 | Fortified church-castle, the broken safe-conduct |

## Proposed new nodes (scope gate: new)

| Page | Proposed id | Why it earns a place | Biggest contrast with the existing set |
|---|---|---|---|
| [Tartu / Dorpat](./tartu_dorpat.md) | `loc.world_tartu` | Bishop's hill, brick-gothic cathedral works, river toll on the Pskov road | Brick, South-Estonian speech, Russian merchants |
| [Viljandi / Fellin](./viljandi_fellin.md) | `loc.world_viljandi` | Order castle above a lake valley; the rye-sack infiltration tale | Ridge-and-lake castle town |
| [Otepää - Vastseliina frontier](./otepaa_vastseliina_frontier.md) | `loc.world_frontier_ugandi` | Hillfort, new border castle, Pskov's May 1343 raid | Deep forest, Orthodox-leaning Estonians |
| [Rakvere / Wesenberg](./rakvere_wesenberg.md) | `loc.world_rakvere` | **Danish** crown castle on the Viru road | Limestone upland, road-inn life |
| [Haapsalu and Läänemaa](./haapsalu_laanemaa.md) | `loc.world_haapsalu` | Bishop's castle with cathedral, besieged by local rebels; coastal Swedes | Shallow bay, reed, Swedish speech |
| [Narva and the Peipus shore](./narva_peipus_east.md) | `loc.world_narva` | Danish river castle, rapids, Orthodox lake villages | Eastern Christian culture, salmon rapids |
| [Baltic Klint coast](./baltic_klint_coast.md) | `loc.world_klint` | Limestone cliffs, waterfalls, erratic boulders, quarries that built Reval | Vertical landscape |
| [Soomaa flood refuge](./soomaa_flood_refuge.md) | `loc.world_soomaa` | Spring "fifth season" flood, dugout boats, rebel retreat | Water-as-ground traversal |

Priority if only some are approved (value per cost): **Haapsalu** (siege already in CANON, Swedes, bishopric), **Tartu** (the other great power, new architecture), **Baltic Klint** (cheapest, strongest landscape contrast), **Soomaa** (spring-flood visuals fit April-May). Rakvere, Viljandi, Narva and the frontier node are best kept as **rumour/travel-event nodes** unless a mission needs the map.

## Cross-cutting pages

| Page | Contents |
|---|---|
| [Biomes and wildlife](./BIOMES_AND_WILDLIFE.md) | Biome by biome: seasons, flora/fauna, what already exists in the runtime catalogs and what is missing |
| [Cultures and languages](./CULTURES_AND_LANGUAGES.md) | Communities, dialects, dress tokens, religion, names, where the player meets them |
| [Architecture typology](./ARCHITECTURE_TYPOLOGY.md) | Every building, castle and church type with materials, scale, silhouette, and kit id |

## Variety matrix (the Witcher-3 test: does each arrival look, sound and feel different?)

| Node | Landscape | Dominant built form | Main speech heard | Signature life |
|---|---|---|---|---|
| Harju village | Field strips, birch/alder edge | Smoke-dwelling cluster, timber manor yard | Estonian (Harju) | Cattle, hens, rooks, oats and rye |
| Sacred grove | Old oak/ash forest, spring | Stone, antlers, ribbons | Estonian, ritual formulae | Owls, hazel grouse, wood anemone carpet |
| Kanavere | Raised bog, pools | Duckboards, brushwood | Estonian | Cranes, bog bilberry, cottongrass |
| Sõjamäe | Lake shore, meadow | Camp fences, siege debris | Estonian, Low German | Reed geese, waders |
| Paide | Limestone plateau | Tower castle, market ring | Low German, Estonian | Kites, horses, storks |
| Pärnu | River mouth, sea flats | Timber harbour, brick warehouses | Low German, Estonian, Swedish | Gulls, lamprey, flax |
| Padise | Forest valley, river | Cistercian limestone | Latin, Low German, Estonian | Bees, herb garden, fishponds |
| Saaremaa | Alvar, juniper, sea | Kiviaed, thatch, boat sheds | Island Estonian | Seals, sheep, orchids (July) |
| Pöide | Hill with church-fortress | Fortified church, bailey | Low German, island Estonian | Crows, siege horses |
| Tartu | River terrace, hill | Brick-gothic, bridge, Russian chapel | South Estonian, Low German, Russian | Barges, bells, hawks |
| Viljandi | Lake valley, ridge | Brick Order castle | Low German, South Estonian | Swans, rye barges |
| Frontier | Hillfort, lakes, deep forest | Log farms, palisade | Võro/Setu-leaning Estonian, Russian | Lynx, bees, cranes |
| Rakvere | Limestone upland | Crown keep, road inns | Danish, Low German, Viru Estonian | Packhorses, roadside shrines |
| Haapsalu | Shallow bay, reeds | Bishop's castle, Swedish farms | Low German, Latin, Swedish, Estonian | Reed birds, mud flats, geese |
| Narva / Peipus | Rapids, lake, birch | Orthodox timber, river fort | Russian/Votic, Estonian, Danish | Salmon, nets, smuggler boats |
| Klint coast | Cliffs, waterfalls, boulders | Lime kilns, quarry cuts | Estonian, Swedish | Eagles, cormorants, lime smoke |
| Soomaa | Flooded meadows, alder carr | Dugouts, pile huts | Estonian | Cranes, beaver, elk (labelled) |

## Shared kits (generate once, reuse everywhere)

Shared `asset.kit.*` ids are defined on the first page that needs them and cited elsewhere. The heaviest reuse:

| Kit id | Defined in | Also cited by |
|---|---|---|
| `asset.kit.limestone_castle` | [Paide](./paide_castle.md) | Pöide, Rakvere, Haapsalu, Narva, Padise, Pärnu, Saaremaa, Viljandi, [architecture typology](./ARCHITECTURE_TYPOLOGY.md) |
| `asset.kit.brick_gothic_church` | [Tartu](./tartu_dorpat.md) | Viljandi |
| `asset.kit.order_convent_castle_brick` | [Viljandi](./viljandi_fellin.md) | Otepää - Vastseliina frontier |
| `asset.kit.timber_harbour` | [Pärnu](./parnu.md) | Padise, Saaremaa |
| `asset.kit.monastic_timber` | [Padise](./padise_monastery.md) | Pöide |
| `asset.kit.island_vernacular` | [Saaremaa](./saaremaa.md) | Pöide |
| `asset.kit.log_farmstead` | [Harju](./harju_village.md) | Sacred grove, Kanavere, Rebel kings' camp |
| `asset.kit.bog_causeway` | [Kanavere](./kanavere_bog.md) | Soomaa |
| `asset.kit.dugout_boat` | [Soomaa](./soomaa_flood_refuge.md) | typology page |

The full kit list (about 50 ids, many used by one page) is in each page's section 9.1; `grep -ho "asset\.kit\.[a-z_]*" docs/LOCATIONS/*.md | sort | uniq -c` reproduces the counts.

Generation order that gives the most visual range per asset: (1) limestone castle + brick gothic church + timber harbour kits, (2) Estonian vernacular farmstead + island vernacular, (3) bog/flood traversal props, (4) regional wardrobe tokens and headgear (see [cultures](./CULTURES_AND_LANGUAGES.md)), (5) missing fauna/flora (fish, amphibians, goat, alvar and bog plants - see [biomes](./BIOMES_AND_WILDLIFE.md)). Process rules (provenance, asset freeze, character rig): [`../ASSET_STORAGE_POLICY.md`](../ASSET_STORAGE_POLICY.md), [`../CHARACTER_GENERATION.md`](../CHARACTER_GENERATION.md), [`../../assets/SOURCES.csv`](../../assets/SOURCES.csv).

## Corrections these pages make to existing docs (not yet applied)

| Existing claim | Problem for 1343 | Page that handles it |
|---|---|---|
| [`TOURIST_LANDMARKS.md`](../TOURIST_LANDMARKS.md) #16: Rakvere is an Order stronghold | Danish crown castle until the 1346 sale | [Rakvere](./rakvere_wesenberg.md) |
| #81-82: Narva "Teutonic" Hermann Castle; Ivangorod opposite | Narva was Danish; Ivangorod dates from 1492 | [Narva](./narva_peipus_east.md) |
| #18 Toolse fort, #71 Kõpu lighthouse, #25 Käsmu captain village, #84 Kallaste Old Believers, #63 Kuressaare castle | Built 1471, 1500s, 19th c., 17th c., late 14th c. | [Klint](./baltic_klint_coast.md), [Saaremaa](./saaremaa.md), [Narva](./narva_peipus_east.md) |
| Legacy roster "Ironhand Störtebeker" | Lived c.1360-1401 | Use an `invented` Vitalienbrüder captain |
| Padise research "Phase 2" fortified cloister | Fortified cloister is post-1343 per the excavation notes | [Padise](./padise_monastery.md) |
| `world_kanavere.rrmap` and `world_sojamae.rrmap` share a layout; `world_poide.rrmap` copies Paide | Greyboxes do not yet express their sites | Each page's landscape section |
| `docs/FLORA_FAUNA.md` "30/30 mammals" | Runtime catalog has no goat; no fish, amphibian, reptile or visible-insect catalog | [Biomes](./BIOMES_AND_WILDLIFE.md) |
| Character ids differ between files (`char.lembit` vs `char.lembit_helme`; Burchard, Goswin) | Pages use `char.lembit_helme`, `char.burchard_von_dreileben`, `char.goswin_von_herike` | n/a |
| Ellen Luik baptized midwife (active brief) vs grove priestess (legacy) | Pages follow the active brief | [Sacred grove](./sacred_grove.md) |
| Forenames dossier dates the rising 13 April | CANON: 23 April | n/a |

Unverified items (bishop names, castle founders, Pernau charter dates, Estonian Swede settlement extent, medieval salt boiling, dugout use) are marked per page as `unverified` / `plausible composite`.

## Scope gate for adoption

Per [`AGENTS.md`](../../AGENTS.md), adding a node is a **scope change**: (1) name the equivalent-cost scope removed or compressed (each new-node page proposes one in section 10), (2) write the next numbered ADR in [`../adr/`](../adr/README.md), (3) open a task with allowed files, dependencies, and verification. Deepening an existing prototype needs only its own task. Nothing here activates a map; activation still needs the gates in [`../MAP_CONVERSION_PLAN.md`](../MAP_CONVERSION_PLAN.md).
