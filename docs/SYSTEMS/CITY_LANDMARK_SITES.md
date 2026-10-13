# Landmark sites in the seamless city

Status: implemented for `site.raekoja_plats`, `site.holy_spirit`, `site.st_olaf`, `site.st_nicholas`, `site.st_mary`, `site.kalev_smithy` and `site.st_michael` ([ADR 0032](../adr/0032-bespoke-landmark-sites-in-the-city.md); smithy implementation reference **R-1643**; nunnery **R-1719**; visual catalogue **R-1695**). Scope: a contract and runtime for bespoke, navigable models of famous Reval buildings and places in the [seamless city](./SEAMLESS_CITY.md), shown as they stood in spring 1343, and one catalogue entry per building (built or not) with its 1343 function, room plan, decoration and research. Out of scope: final Blender-generated landmark shells, multi-storey interiors, site-specific NPC behaviour, and building the pending or proposed sites listed below (each needs its own task).

## How to read this page

Each built site has its own page under [`landmark_sites/`](./landmark_sites/); pending and proposed buildings have a section on this page. A page or section holds: status and links, captured views (built sites only, plus a gallery of further views), **function in 1343**, **plan** (rooms and what happens in them), **decoration**, **left out** (later fabric), **historical research** (project dossiers first, then external studies) and related board work. Shared runtime behaviour, the authoring contract, verification and limits for all sites follow after the buildings.

- **Implemented** means a registered, navigable model in the seamless city, not final art approval. All eight sites use **interim GDScript builders**; the final Blender-generated shells required by [ADR 0032](../adr/0032-bespoke-landmark-sites-in-the-city.md) are pending. Images are captured model evidence (review snapshots, not concept art or photos of modern Tallinn); ongoing fixes may postdate them.
- **Pending** means ADR 0032 already names the site but no manifest exists. **Proposed** means the building stood in 1343 and is worth a site, but no ADR or task names it yet; adding one is a scope decision (see [AGENTS.md, Scope](../../AGENTS.md#scope)).
- Confidence words follow the dossiers: **attested** (a dated source), **plausible composite** (reconstructed from the type and later fabric), **unknown**. Plans of rooms are composites unless marked attested; no measured 1343 interior plan survives for any Reval building.
- **Period rule** (maintainer, 2026-10-07): an element dated after 1343 is left out. Where the 1343 state is unrecorded, use a slightly simplified form of the later, documented building. A later feature needs a maintainer-recorded entry in the manifest's `presentation` list.
- Board references (`R-…`) are task IDs, not delivery dates; states are a snapshot of **2026-10-11**. Legacy district-map tasks are labelled and must be re-scoped before they can deliver a seamless-city site.

## Building index

| Building | Kind | 1343 state | Game status |
|---|---|---|---|
| [Council hall and market square](./landmark_sites/raekoja_plats.md) | political, market | standing (consistorium 1322) | implemented `site.raekoja_plats` |
| [Holy Spirit church and almshouse](./landmark_sites/holy_spirit.md) | parish, council church, hospice | standing | implemented `site.holy_spirit` |
| [St Olaf's church](./landmark_sites/st_olaf.md) | parish | standing, tower unfinished | implemented `site.st_olaf` |
| [St Nicholas' church](./landmark_sites/st_nicholas.md) | merchant parish | standing | implemented `site.st_nicholas` |
| [St Mary's cathedral](./landmark_sites/st_mary.md) | cathedral, bishop | building site | implemented `site.st_mary` |
| [Kalev's smithy](./landmark_sites/kalev_smithy.md) | craft house, game hub | plausible composite | implemented `site.kalev_smithy` |
| [Danish royal castle (Small Castle)](#danish-royal-castle-on-toompea-castrum-minus) | political, military | standing | pending (partial non-site enclosure) |
| [Bishop's court and chapter on the Great Castle](#bishops-court-chapter-and-vassal-houses-castrum-maius) | political, religious | standing | proposed |
| [St Catherine's Dominican friary](./landmark_sites/st_catherine.md) | friary, preaching, school | standing, smaller than its peak | implemented `site.st_catherine` |
| [St Michael's Cistercian nunnery](./landmark_sites/st_michael.md) | convent | standing, wall tie-in under way | implemented `site.st_michael` |
| [St Canute's guild house](#st-canutes-guild-house-kanutigilde) | guild, political | house held from 1326 | proposed |
| [St Olaf's guild house](#st-olafs-guild-house-olaigilde) | guild, political | house held from 1341 | proposed |
| [St John's leper hospital](#st-johns-leper-hospital-jaani-seek) | hospital, outside the walls | standing (first mention 1237) | proposed |
| [Coastal Gate](#coastal-gate-strantporte) | gate | gate tower, low form | non-site model |
| [Viru Gate](#viru-gate-lehmporte) | gate | present, possibly unfinished | non-site model |
| [Karja Gate](#karja-cattle-gate) | gate | present | non-site model |
| [Harju Gate](#harju-gate-smedeporte) | gate | present | non-site model |
| [Nuns' Gate and Nuns' Tower](#nuns-gate-and-nuns-tower) | gate, tower | under construction | proposed |
| [Sand Gate](#sand-gate) | minor gate | present | proposed |
| [Long Leg and Short Leg hill gates](#long-leg-and-short-leg-hill-gates) | hill gates | wooden | proposed |
| [Golden Leg tower](#golden-leg-tower-kuldjala) | wall tower | standing (c. 1310 core) | proposed |
| [Rent, Stolting and Hinko towers](#rent-stolting-and-hinko-towers) | wall towers | standing | proposed |
| [Not in 1343](#buildings-that-did-not-exist-in-1343) | - | later | do not build |

## Implemented sites

One page per built site, with the function in 1343, plan, decoration, research, verification and a gallery of captured views. Interim GDScript builders; new sites get a page when they are built.

| Site | Stable ID | Page |
|---|---|---|
| Council hall and market square (Raekoja plats) | `site.raekoja_plats` | [landmark_sites/raekoja_plats.md](./landmark_sites/raekoja_plats.md) |
| Holy Spirit church and almshouse (Pühavaimu) | `site.holy_spirit` | [landmark_sites/holy_spirit.md](./landmark_sites/holy_spirit.md) |
| St Olaf's church (Oleviste) | `site.st_olaf` | [landmark_sites/st_olaf.md](./landmark_sites/st_olaf.md) |
| St Nicholas' church (Niguliste) | `site.st_nicholas` | [landmark_sites/st_nicholas.md](./landmark_sites/st_nicholas.md) |
| St Mary's cathedral (Toomkirik, Dome church) | `site.st_mary` | [landmark_sites/st_mary.md](./landmark_sites/st_mary.md) |
| Kalev's smithy (task R-1643) | `site.kalev_smithy` | [landmark_sites/kalev_smithy.md](./landmark_sites/kalev_smithy.md) |
| St Catherine's Dominican friary (task R-1718) | `site.st_catherine` | [landmark_sites/st_catherine.md](./landmark_sites/st_catherine.md) |
| St Michael's Cistercian nunnery | `site.st_michael` | [landmark_sites/st_michael.md](./landmark_sites/st_michael.md) |

## Pending and proposed sites (not built yet)

None of these has a manifest in the [site registry](../../content/world/reval_city/sites/registry.json). **No site model** does not mean nothing is visible: generic shells and fortification-builder geometry are separate from the bespoke site contract. Plans below are design briefs for a future task, not built behaviour.

### Danish royal castle on Toompea (castrum minus)

**Status:** pending ([ADR 0032 delivery order](../adr/0032-bespoke-landmark-sites-in-the-city.md#7-first-sites-in-order)). **Partial non-site fortification model:** the enclosure is visible, the bespoke hall, keep, chapel and service ranges are not. [Existing enclosure screenshot](../reports/images/historical_walk/toompea_castle_aerial.jpg) (not the finished castle). Board: **R-1462 / HW-T1** (`in_progress`, seamless-city castle buildings); R-1128 / LM-04 (`todo`) is the legacy district predecessor.

**Function in 1343:** *Castrum Danorum*, the Danish crown's administrative and military seat in Estonia: the viceroy (*capitaneus*) Konrad Preen holds court and audience here in April; the garrison musters here. Danish banner, not the Order cross, until the handover on 16 May 1343 (attested).

**Plan** (production zones from the interior dossier; no measured Danish plan survives):

| Zone | Function | Confidence |
|---|---|---|
| Southern forecourt (`SC-forecourt`) | muster yard, carts, storage | plausible composite |
| Cross-wall gate and tower (`SC-gate-tower`) | controlled passage to the residence | attested |
| Viceroy's audience hall (`SC-viceroy-audience`), upper storey | judgment, petitions, council of vassals | plausible composite |
| Viceroy's private chambers (`SC-viceroy-private`) | sleeping, treasury, household | plausible composite |
| Castle chapel (`SC-castle-chapel`) | castle worship, not the cathedral | plausible composite |
| Service cellar (`SC-service-cellar`) | stores, arms racks, possibly kitchen | plausible composite, gap |
| West gate and dansker (`SC-west-gate`, `SC-west-dansker`) | drawbridge exit at second-storey level; latrine projection | plausible composite |
| Outer bailey (`OB-courtyard`, `OB-east-gate`) | stables, smithy, guard barracks; upper end of the Short Leg | plausible composite |

**Decoration:** limestone walls; bricked-up large window openings in the western outer wall are the only fabric confidently tied to the Danish build (attested). Audience hall: Danish royal arms (three lions), benches along the walls, a raised seat, wall hangings, plank shutters; plausible composite.

**Left out (later):** the four-wing Order convent house (34 × 39 m, 1350–60+), Pikk Hermann (first masonry 1360–71), Stür den Kerl and Landskrone at current height, the stone Long Leg gate tower (1380), the baroque Riigikogu front (1767–73).

**Historical research:**

- Project: [Toompea castle and upper town](../../history/dossiers/architecture/toompea-castle-and-upper-town.md); [Small Castle and Great Castle interiors](../../history/dossiers/architecture/toompea-small-castle-interior.md); [Jurisdictions of Reval](../../history/dossiers/power/jurisdictions-of-reval.md); [Order and comptoir transition 1343–46](../../history/dossiers/power/order-comptoir-transition-1343-1346.md).
- External: Wikipedia (et), ["Toompea Väike linnus"](https://et.wikipedia.org/wiki/Toompea_V%C3%A4ike_linnus) (Danish cross-wall, forecourt, viceroy's residence); Medieval Heritage, ["Tallinn - Toompea Teutonic Castle"](https://medievalheritage.eu/en/main-page/heritage/estonia/tallinn-toompea-teutonic-castle/) (post-1346 plan, comparandum only); R. Zobel, "Toompea loss keskajal (ca 1030–1525)", in *Toompea loss*, Tallinn 2008, pp. 11–30 (primary, not yet mined: see the dossier's access notes); M. Reppo, ["The Bishop's House and new additions to the study of the limestone quarry on Toompea Hill"](https://arheoloogia.ee/ave2018/AVE2018_12_Reppo_Toompea.pdf), *AVE* 2018; R. Nurk, *Linnakindlustuste kaardistus* (local `history/Linnakindlustuste kaardistus.pdf`, A2 inventory).

### Bishop's court, chapter and vassal houses (castrum maius)

**Status:** proposed; no ADR or task. The Great Castle plateau around the cathedral.

**Function in 1343:** the bishop's residence (Bishop Olaf, pro-Danish political actor and co-signatory of crisis letters), the canons' houses and chapter meetings, and the fortified town houses (*curiae*) of the Harju-Viru vassals: the nobility's political ground, distinct from the merchant Lower Town.

**Plan:** `GC-bishop-palace` next to the cathedral (hall, chamber, chapel, yard; attested function, composite rooms); `GC-chapter` canons' houses; `GC-vassal-plot-*` stone town houses with yards and small chapels around the square (attested density); `GC-cross-wall` dividing the enclosure (attested 1238–1346); the Toom Gate on the south (position composite, ring wall may be incomplete in 1343).

**Decoration:** composite after Livonian noble houses: lime-washed hall, painted beams, heraldic shields of vassal families, a hearth, benches and chests. No primary source describes these interiors.

**Left out (later):** the 2018 Bishop's House excavation footprint (late medieval), the Knighthood House, baroque palaces.

**Historical research:** [Small Castle and Great Castle interiors](../../history/dossiers/architecture/toompea-small-castle-interior.md) (Great Castle zones); [Toompea castle and upper town](../../history/dossiers/architecture/toompea-castle-and-upper-town.md); Wikipedia (et), ["Toompea Suur linnus"](https://et.wikipedia.org/wiki/Toompea_Suur_linnus) (castrum maius, vassal density, cross-wall); Reppo 2018 (above).

### St Canute's guild house (Kanutigilde)

**Status:** proposed; no ADR or task. Pikk 20 (medieval core under the 1863 front).

**Function in 1343:** seat of the St Canute umbrella guild of the "finer", mostly German crafts (house held from 1326, attested): feasts, elections, mutual aid, burials, and from the mid-14th century political voice against the council. Smiths belong to this umbrella, so this is Kalev's guild ground.

**Plan** (composite after Hanseatic guild houses): a street-front hall (*gildestube*) for feasts and meetings with the alderman's table, a cellar for beer and stores, a kitchen, and a chest room for the guild box, statutes and silver; the guild altar is in a parish church, not in the house.

**Decoration:** long trestle tables and benches, the patron's banner and image (St Canute Lavard), candle crowns, painted beams; composite.

**Left out (later):** the 1863–64 Tudor-Gothic front and its statues.

**Historical research:** [Guild structure](../../history/dossiers/crafts/guild-structure.md); [Schmiede-Amt ordinances before 1363](../../history/dossiers/crafts/schmiede-amt-ordinances-pre-1363.md); A. Mänd, ["Suurgildi liikmeskonnast…"](https://doi.org/10.3176/hist.2005.1.07), *Acta Historica Tallinnensia* 9, 2005.

### St Olaf's guild house (Olaigilde)

**Status:** proposed; no ADR or task. Pikk 24 (14th-century core).

**Function in 1343:** seat of the St Olaf umbrella guild of the simpler trades (house held from 1341, attested); later tradition gives it more Estonian members, so it is the natural ground for the Estonian-German tension of the uprising (social colour, not proof of Estonian masters in April).

**Plan and decoration:** as St Canute's, plainer; composite.

**Left out (later):** the 15th-century guild hall rebuild.

**Historical research:** [Guild structure](../../history/dossiers/crafts/guild-structure.md); [Estonian and German populations](../../history/dossiers/people/estonian-and-german-populations.md); Mänd 2005 (above).

### St John's leper hospital (Jaani seek)

**Status:** proposed; no ADR or task. Outside the walls, about 0.5 km south-east of the Viru Gate where the Tartu road crosses the Härjapea river, in the hinterland streaming group ([ADR 0027](../adr/0027-reval-hinterland-streaming-group.md)).

**Function in 1343:** the town's leper house and hospital (*domus fratrum leprosorum sancti Johannis*), first mentioned in 1237, run by the council (earlier by the cathedral chapter), with lands and the Patika mill (1279 gift). Care and separation: the sick live beyond the walls.

**Plan:** a late-14th-century account (closest to 1343) lists a **church**, a **dwelling house with a storeroom**, a **latrine** with a long stone seat, a **lock-up** for disobedient inmates, an **anteroom and a stone-vaulted sauna**, a **stable** and a **mill**; plus the cemetery (attested list, layout composite).

**Decoration:** plain timber and limestone; beds, chests, a common hearth, the chapel altar. The 15th-century house rules (fines for quarrelling, drinking, missing mass, staying in town) give scene colour.

**Left out (later):** the 1571 siege destruction and rebuild, the 20th-century buildings at Tartu mnt 16.

**Historical research:** Wikipedia (et), ["Jaani seek"](https://et.wikipedia.org/wiki/Jaani_seek) (1237, 1279, late-14th-c. building list, house rules); T. Kala, "Mis oli ja millega tegeles Jaani seek?", *Horisont* 4, 2004; Tallinn City Museum, ["Seegi ajalugu"](https://linnamuuseum.ee/jaani-seek/lugemiseks/seegi-ajalugu/); Tallinn City Archives blog, ["Seek"](https://linnaarhiiv.wordpress.com/2017/10/25/seek/). No project dossier yet.

## Gates and wall towers

The mid-14th-century circuit has **eight gates** in rectangular towers with ground-floor passages, and a short list of towers; the ring closes only around 1355. Gates in the current city are **fortification-builder models without landmark-site manifests**. Board: **R-1131 / LM-06** (`todo`, Karja Gate on the retired south-quarter map, needs re-scoping); no city-site task for the others. Shared research for every gate and tower: [Walls, gates and towers](../../history/dossiers/topography/walls-gates-towers.md); [Watch duty and town defence](../../history/dossiers/military/watch-duty-and-town-defence.md); [Gate garrisons](./GATE_GARRISONS.md); Medieval Heritage, ["Tallinn city defensive walls"](https://medievalheritage.eu/en/main-page/heritage/estonia/tallinn-city-defensive-walls/) (Zobel reconstruction and mid-14th-century plan); R. Nurk, *Linnakindlustuste kaardistus* (local `history/Linnakindlustuste kaardistus.pdf`, B1 inventory).

**Shared gate-tower plan** (plausible composite from the type): a vaulted or beamed **passage** on the ground floor with two plank leaves and a draw bar; a **guard room** beside or above it for the toll-taker and watch; upper storeys on timber floors reached by ladders, with loopholes; a **wooden fighting deck** with hoardings at the top in wartime; a door to the wall-walk. No portcullis complexes or drawbridges of the later forms; no gunports.

### Coastal Gate (Strantporte)

Non-site model: [from the harbour](../reports/images/city/gate_coastal_from_harbour.png), [aerial](../reports/images/city/coastal_gate_aerial.png). **1343:** low wall and gate, probable gate tower 1311–1340, on a sandstone cliff 5–8 m above the harbour ground; name *Suur Rannavärav* first written 1359. **Function:** the harbour gate, where goods come up from the strand and customs are taken. **Left out:** Fat Margaret (c. 1529), the 1430 barbican. **Research:** M. Reppo, V. Kadakas, *AVE* 2019 (local `history/AVE2019_15_Reppo-Kadakas.pdf`); [Harbour and shoreline](../../history/dossiers/topography/harbour-and-shoreline.md); [Harbour customs](../../history/dossiers/economy/reval-harbour-customs-1340s.md).

### Viru Gate (Lehmporte)

Non-site model: [from outside](../reports/images/city/gate_viru_from_outside.png), [aerial](../reports/images/city/viru_gate_aerial.png). **1343:** present but possibly unfinished; archaeology places the main gate in the mid-14th century; written name *Lehmporte* (clay gate) only from 1362. **Function:** the eastern main road to Tartu and Narva; toll and cart traffic to the market. **Left out:** the round flanking towers (1370s+ foregate), the 1450s barbican. **Research:** Kraut & Nurk, *AVE* 2016/17 (local `history/AVE2016_17_KRAUT-NURK_Tln-Viru-tn.pdf`); Wikipedia, ["Gatehouse of the Viru Gate"](https://en.wikipedia.org/wiki/Gatehouse_of_the_Viru_Gate); [Viru and Vanaturg paving archaeology](../../history/dossiers/topography/viru-vanaturg-paving-archaeology.md).

### Karja (Cattle) Gate

Non-site model: [gate and mill](../reports/images/historical_walk/hw3_karja_gate_mill.jpg). **1343:** early-14th-century wall and gate rebuild plausible; name *Kariestrate* 1365; the watermill over the moat is **uncertain** in 1343. **Function:** the south gate to the pastures; cattle driven out and in. **Left out:** the barbican (1453–56). **Research:** Nurk et al., *AVE* 2010 Karja Gate (cited in the walls dossier); [Karja gate leaf state](../../history/dossiers/topography/karja-gate-leaf-state-1343.md).

### Harju Gate (Smedeporte)

Non-site model: [looking out](../reports/images/historical_walk/hw4_harju_gate_out.jpg). **1343:** present (plausible composite); gate mentioned 1361, smiths' street 1362. **Function:** the "smiths' gate" to the Harju settlement and the south-west road; the smith trade clusters inside it, which ties it to Kalev. **Left out:** the foregate (1448–53). **Research:** walls dossier [11]; [Lower Town street plan](../../history/dossiers/topography/lower-town-street-plan.md); [Trades of the Lower Town](../../history/dossiers/crafts/trades-of-the-lower-town.md).

### Nuns' Gate and Nuns' Tower

**Proposed.** **1343:** the nunnery wall is being tied to the new curtain; an opening may exist, but the name *Porta Monialium* is recorded only at the 1355 closure, so do not label it in the UI. The Nuns' Tower is a rectangular bartizan type of the first half of the 14th century (about 8.4 m high, projecting 0.4 m). **Function:** the west gate by the convent; a watch post on the curtain. **Research:** walls dossier; [Ecclesiastical precinct boundaries](../../history/dossiers/religion/ecclesiastical-precinct-boundaries-1343.md).

### Sand Gate

**Proposed.** **1343:** a minor north-east beach gate on the mid-14th-century plan (plausible composite). **Function:** boats, fish and the path to the Kalamaja fishing shore; a smugglers' way in quest terms. **Research:** walls dossier; [Kalamaja fishing shore](../../history/dossiers/topography/kalamaja-fishing-shore-1343.md).

### Long Leg and Short Leg hill gates

**Proposed.** **1343:** both are **wooden** gates on the two ascents from Lower Town to Toompea; the town may close them at night; stone Long Leg tower only after 1380, Short Leg mid-15th century; the curtain between hill and town is a timber or earthen barrier until 1454–55. **Function:** the political border between the self-governing town and the crown's hill. **Research:** walls dossier; [Toompea castle and upper town](../../history/dossiers/architecture/toompea-castle-and-upper-town.md).

### Golden Leg tower (Kuldjala)

**Proposed.** **1343:** present, c. 1310 core, horseshoe plan about 9 m wide and 7 m high (attested). **Function and plan:** the north-west corner tower; open or timber-floored storeys with loopholes and a wooden fighting deck (composite). **Research:** walls dossier.

### Rent, Stolting and Hinko towers

**Proposed.** **1343:** Rent Tower (north-west, before mid-14th c., attested); Stolting Tower (north-east corner) and Hinko Tower (south-east corner), both on the mid-14th-century plan. **Function and plan:** corner and curtain towers of the burgher watch; as Golden Leg (composite). **Research:** walls dossier.

## Buildings that did not exist in 1343

Do not add these as 1343 buildings; each is dated later in the dossiers.

| Building | Earliest date | Source |
|---|---|---|
| Great Guild hall (*Suurgild*) | 1407–10 | [Guild structure](../../history/dossiers/crafts/guild-structure.md) |
| House of the Black Heads | charter 1400, house 1517 | Guild structure |
| Town hall tower, upper storey, arcade | 1371–1404 | [Town hall (Medieval Heritage)](https://medievalheritage.eu/en/main-page/heritage/estonia/tallinn-town-hall/) |
| Pikk Hermann | 1360–71 | [Toompea dossier](../../history/dossiers/architecture/toompea-castle-and-upper-town.md) |
| Order convent house on Toompea | 1350–60+ | [Small Castle interiors](../../history/dossiers/architecture/toompea-small-castle-interior.md) |
| Maiden, Goat, Stable towers | 1370s (Maiden 1373) | [Walls, gates and towers](../../history/dossiers/topography/walls-gates-towers.md) |
| At the Monks, Bremen, Helleman, Loewenschede, Epping, Plate towers | late 14th-15th c. | Walls, gates and towers |
| Kiek in de Kök | 1475+ | Walls, gates and towers |
| Fat Margaret | c. 1529 | Walls, gates and towers |
| Foregates and barbicans (Viru, Karja, Harju, Coastal) | 1370s-1461 | Walls, gates and towers |
| St Olaf's spire, St Nicholas' basilica | c. 1450, 1405+ | [Churches](../../history/dossiers/religion/churches-and-religious-houses.md) |
| Pirita Brigittine convent | 1407 | Churches |

**Uncertain, needs research before a site is proposed:** a Rus merchants' Orthodox church in the Vene street quarter (not covered by any dossier); public bath houses (see [Public bath locations](../../history/dossiers/topography/public-bath-locations-1343.md)).

## Shared behaviour of all sites

- **Walking in:** Kalev enters through the portal and the door swings open.
- **People:** none. Landmark sites no longer post nameless people (they could not be clicked and had no census record); only census citizens populate the city. The `people` manifest key and `CitySiteActor` remain supported but unused.
- **Cutaway:** in the top-down and third-person cameras, while he is inside, everything above head height lifts away: upper walls, gables, banners, roof and ceiling. The wall stubs get a stone section cap, so the cameras see into the room. First person keeps the whole room, ceiling included. The lifted nodes stay in the sun's shadow pass (`CityWorld3D.set_cutaway` makes their geometry shadows-only and hides lights), so the room below stays shaded. Ordinary houses use the same cutaway ([Seamless city](./SEAMLESS_CITY.md#how-buildings-are-built)).
- **Minimap:** shows the room, e.g. "Inside: Council hall".
- **Collision:** walls, posts, tables, chests, lecterns, partitions, stores, booths, stalls and carts block Kalev. The pillory does not (dossier: no permanent collision).

## How a site is authored

1. Write `content/world/reval_city/sites/<name>.json` (fields in ADR 0032 decision 1) and add `<name>` to `content/world/reval_city/sites/registry.json`. Sites are never found by scanning a folder.
2. Coordinates are **site-local metres**. `anchor.at` is the plan position of the local origin; `anchor.rotation_deg` turns local +x. Local +z is to its right, which is south at rotation 0. Heights are relative to the terrace level.
3. `replaces` lists the generic plan buildings the site removes (stable IDs). `tools/validate_city_sites.gd` fails while any generic building still overlaps a site building by more than 1 m².
4. `terrace.level.door` names the door whose outside ground (`outside_m` out) sets the level. `terrace.polygon` is levelled to it and blended over `blend_m`.
5. `walk` is the logic plane:
   - `walls` are outer-face segments with a thickness that goes into the building. Leave the door gap out.
   - `floors` are polygons with a height above the terrace.
   - `solid` holds extra blocking polygons.
   - A dressing item with `"solid": [w, d]` also blocks.
6. `rooms` say which floor they are on and which visual nodes (`hide` paths relative to the site's root) disappear while Kalev is inside.
7. `doors` hang leaves through `CityDoors` (gap ends `a`/`b`, `inward`, `height`, `style`, `paint`). Inner doors between rooms work the same way.
   `people` lists who is at work there: `id`, `role`, `rig` (a variant under `assets/characters/variants/`), `at`, `facing_deg`, `pose` (`sit`, `stand`, `talk`). `CityNpcs` spawns them as `CitySiteActor`s near the site. Seated people have no collision.
   `walk.floors` may hold raised floors (a dais) reached by `walk.ramps` (`to_floor`). A floor with `rise` ([x0, h0, x1, h1], site-local x) is a flight of steps. Floors that touch a reachable floor count as reachable.
   Fabric `openings` also take `lights` (multi-light tracery and glass), `reveal` (the material of the reveal) and `kind: "recess"` (a blind recess in the inner face). An opening's `s` runs from the wall's `a` end towards `b`.
   `review_shots` hold reviewer camera views in site-local metres (`eye`, `look`, `fov`, `cutaway`) for `capture_reval_city.gd`. `review_views` are first-person spots for the walk test.
8. `dressing` uses the prop catalogue `CitySiteProps`:
   - `market_stall` with `goods` (`fish`, `cloth`, `grain`, `pottery`, joined with `+`);
   - `cart`;
   - `trade_goods` with `variant` (`eastern_furs_wax`, `western_cloth_salt`, `livonian_grain_flax`, `barrelled_herring_metal`);
   - `pillory`;
   - `stone_stack` (dressed blocks on skids, for a masons' yard).
   A builder may define its own kinds; `kalev_smithy_builder.gd` reads `kit` (an old-forge GLB by `model`), `catalog` (an object-catalog id, `y` lift) and its yard pieces. Solid furniture footprints then go in `walk.solid`.
   `spawns` (optional) lists spawn ids the site owns, with site-local `at` and `facing_deg`; `CityTravel.spawn_position` and the arrival camera use them before any other spawn kind.
   `terrace.over_houses: true` levels the terrace again after the neighbouring house plots are cut (a small site between houses).
   `close` (optional, a walled precinct such as `site.st_michael`): `polygon` (site-local, the ground inside the close wall), `wall_h`, and `gates` (`id`, the `door` that closes it, the `street` it opens to). The wall itself is `walk.walls` entries marked `"close": true`; a builder drapes them over the ground. `orchards` (`id`, `polygon`, `step`, optional `mix` of fruit species) are planted by the compiler; `garden_beds` (`id`, `at`, `rotation_deg`, `bed` size, `beds` count) and `chimneys` (site-local stack tops) are read by the builder.
9. `fabric` (optional) describes the walls once for both the model and the walk data. Each entry has an outer face line `a`→`b`, `inside`, `thick`, `y0`/`y1`, `floor`, the face keys `outer`/`inner` and `openings`. An opening has `kind` (`window`, `door`, `arch`, `niche`, `louvre`), `s`, `w`, `sill`, `spring`, an optional `apex` for a pointed head, `splay` and `glass`. `CitySiteKit` builds the walls from it, and `CitySite` derives the logic-plane walls from it, with door and arch openings at floor level left open.
10. `visual` is either `{"kind": "builder", "script": ...}`, a script with `static func build(site: CitySite, plan: CityPlan) -> Node3D`, or `{"kind": "scene", "path": ...}`.
11. `close` (optional) is the walled close (`polygon`, site-local): the plan keeps trees and shrubs out of it, and at runtime its turf stays short (`CitySite.in_close`); no grass grows on any site floor or solid (`CitySite.covers`).
12. `community` (optional) houses a census institution in the site: `household`, walkways (`paths`, an `entry` path joins the street graph at a gate, the rest stays interior) and `seats` (site-local `[x, z, facing_deg]` per group: home, choir, chapter, refectory...). `tools/city/build_citizen_runtime.py` (`apply_communities`) assigns them; see [St Catherine's friary](./landmark_sites/st_catherine.md#community-the-friars-day).
13. Rebuild the plan (`python3 tools/city/build_reval_city_plan.py`) and the citizen runtime (`python3 tools/city/build_citizen_runtime.py`), then run the validator.

**Maintaining the catalogue:** when a model changes, update its building page (`landmark_sites/<slug>.md`) (status, plan, board reference and captured views) together. Keep stable site IDs, link an existing building dossier or report before creating a duplicate, and label historical photos, concepts and retired-model images explicitly if adding them. A pending or proposed building moves to **Implemented sites** only with a registry entry; create its `landmark_sites/<slug>.md` page then and add it to the table and the building index. Documentation checks: `python3 tools/docs_index.py --check` and `python3 tools/generate_active_docs_report.py --check`.

## Runtime entry points

| Script | Role |
|---|---|
| `tools/city/build_reval_city_plan.py` (`load_sites`, `terrace_site`, `flatten_ground`, `site_closes`) | Drops `replaces`, levels the terrace, keeps trees and shrubs off the site, paints splat and minimap, writes `plan.json` → `sites[]` (`id`, `at`, `rotation_deg`, `level`, world `footprints`, `reserve`). For a site with a `close`, `site_closes` clears generic trees and shrubs from the close, its buildings and reserve after every seeded planting loop and plants its `orchards` as unfenced plan orchards (fruit trees in rows), so no countryside field, pasture or orchard ID moves |
| `scripts/city/city_site.gd` (`CitySite`) | Manifest plus placement; local↔world transforms; floors, rooms, walls, solids, doors in world XZ |
| `scripts/city/city_site_registry.gd` (`CitySiteRegistry`) | Loads the registry and pairs manifests with their plan placement |
| `scripts/city/city_plan.gd` | `sites`, `site_at`, `site_room_at`; `walk_height` uses site floors first; `location_at` names site rooms |
| `scripts/city/city_world_3d.gd` | Builds each site visual at its anchor; `set_site_room_hidden`, `site_occluder_index` |
| `scripts/city/city_collision_builder.gd` (`_sites`) | Site walls, solids and dressing footprints on the logic plane |
| `scripts/city/city_doors.gd` | Site doors keyed `"site:<door id>"` |
| `scripts/city/city_site_props.gd` (`CitySiteProps`) | Prop catalogue for dressing |
| `scripts/city/city_site_actor.gd` (`CitySiteActor`) | A person on a site: rig, facing, pose |
| `scripts/city/sites/site_kit.gd` (`CitySiteKit`) | Shared kit for site models. Walls from `fabric` with flat or pointed openings, splays, glass, niches and louvres; crow-stepped gables; gable and pyramid roofs; quadripartite rib vaults (`rib_vault`); square piers (`square_pier`, plastered or bare `greystone`); octagonal pillars; flag floors with ledger slabs; cut caps; materials (`bind_site_washes` binds the lime wash and painted wash of a site's meshes to its floor height and frieze frame and sets their indoor brightness) |
| `scripts/city/sites/st_michael_builder.gd` | St Michael's nunnery: two-aisled vaulted church with flat-ended chancel, plain gables, ridge bell-cote, nuns' west gallery; claustral ranges with closed niche doors, cloister lean-to walks and lavabo; gate house; service wing; close wall draped over the ground from the `close` walk walls; kitchen-garden beds (`MapViewKitchenGardenModels`); kitchen and brewhouse stacks (root meta `chimneys`) |
| `scripts/city/sites/kalev_smithy_builder.gd` | Kalev's smithy: rubble walls with the old forge's plates, plain gables, shingle roof, gable stack, loft, shutters, shop counter, lean-to, and the old forge GLB kit with the live hearth fire. Root meta `chimneys` (site-local stack tops, always-lit smoke); fire controllers join group `city_cycle_lights` (`CityWorld3D.apply_time`) |
| `scripts/city/sites/holy_spirit_builder.gd` | Holy Spirit church, choir, almshouse and bell turret on the kit |
| `scripts/city/sites/st_mary_builder.gd` | St Mary's chancel, apse, vestry, finished bay, rising nave, crane, centering, scaffolds, lodge, belfry |
| `scripts/city/sites/st_catherine_builder.gd` | St Catherine's friary: buttressed preaching hall with tie-beam roof, ridge bell turret, rood screen and friars' stalls; ranges with enterable ground floors (sacristy, chapter house on a central pillar, dormitory stair, refectory, kitchen, stores, granary, lay brothers' hall), valley roofs and the kitchen stack (root meta `chimneys`); cloister arcade and lean-to roofs (`Cloister/Roof`); close wall; garth well (`MapViewWellModels`) and beds; yard dressing (`life_prop` kind: `MapViewMeshBuilderDistrictLifeProps`, `catalog`: object-catalog GLB) |
| `scripts/city/sites/st_nicholas_builder.gd` | St Nicholas' hall church, chancel, sacristy, porch, low tower, buttresses, St Barbara charnel chapel, cemetery |
| `scripts/city/sites/st_olaf_builder.gd` | St Olaf's hall church, chancel, unfinished tower, scaffold, belfry, vaults |
| `scripts/city/sites/church_furnishings.gd` (`CityChurchFurnishings`) | Shared church furnishings: plank floors, benches, font, altars with a winged retable and saint figures, the rood, pulpit, statues, candle crowns, candle lights |
| `scripts/city/city_stained_glass.gdshader` | Leaded stained glass |
| `scripts/city/sites/raekoja_plats_parts.gd`, `raekoja_plats_interior.gd` | Shared dimensions and helpers; the diele, dornse, partition and furniture |
| `scripts/city/sites/raekoja_plats_builder.gd` | Council-hall model in metres. Walls with real openings are built as grid cells between the opening edges (`_facade`, `_holed_face`). It adds the gables, portal, window dressing, interior and roof, then splits everything at the cut height into `CouncilHall/Lower`, `CouncilHall/Upper` (with the banners) and `CouncilHall/Roof` |
| `scripts/city/city_tile_roof.gdshader` | Procedural monk-and-nun clay tiles from the roof UVs (metres): courses, per-tile colour, lip shadows, moss in the channels, lichen, wetness. Used by every tile roof in the city |
| `scripts/city/city_limewash.gdshader`, `city_flagstone.gdshader` | Interior lime wash and limestone flags. Both are darkened and warmed for indoors and have no distance fog, because the GL Compatibility renderer has no ambient occlusion |
| `scenes/world/reval_city/reval_city.gd` | Lifts site room roofs while Kalev is inside; camera occluder index |

## Save and load

Sites hold no state. Door positions are not saved; the plan and manifests rebuild the same site every time.

## Verification

- `godot --headless --path . --script tools/validate_city_sites.gd`: the registry loads; replaced buildings are gone; no overlap with generic buildings; every door has clear ground outside and a floor behind it (its own floor, or a passage through a thick wall touching it); no wall crosses a door; every door and arch is at least 1.4 m wide (Kalev's capsule is 1.0 m); every floor is reachable; every room is reachable from the street through doors and floor-level openings (room graph); people stand on a floor and not inside furniture; every `hide` path resolves; visual walls and authored walls agree within 0.25 m (AABB of the `Walls` mesh against the wall segments).
- `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_city_sites`: placement, replaced building, floor height, room and HUD name, door gap.
- `tools/godot_render.sh --resolution 1600x900 res://tools/capture_reval_city_walk.tscn [-- --only-sites]` (NPC collision is ignored during the site checks, so people standing at a door do not fail them; each inner door must be reachable from at least one entrance): walks in through every site door (door opens, roof lifts, top-down shot inside), then from inside through every other door of the site (the hall into the council chamber) and back out.
- `tools/godot_render.sh --resolution 1600x900 res://tools/capture_reval_city_walk.tscn -- --only-holy-spirit-benches`: walks Kalev with real input along the Holy Spirit middle aisle, through a bench-row slot on each side and along the south aisle; fails if he stops short, and saves `walk_holy_spirit_<leg>.png`.
- `tools/godot_render.sh --script tools/capture_reval_city.gd -- --only=raekoja_plats_aerial,raekoja_plats_topdown,raekoja_plats_street,raekoja_plats_cutaway,raekoja_plats_interior` (the cutaway plate lifts the rooms as if Kalev were inside).

## Limits

- All eight registered site shells are interim GDScript models. Their Blender GLB replacements (ADR 0025 tier B budgets) are follow-up work; no per-site delivery task or date was confirmed in the 2026-10-11 catalogue review.
- The cut is one flat plane at head height: window openings above it are cut through, and the section cap spans the window holes.
- Neighbouring generic roofs are clipped where they would overhang a site building (`keep_out`), so they no longer poke through its walls.
- The retable, figures and pulpit are box-modelled; carved detail and painted faces need the planned Blender models.
- Council, court and clergy are not shown until they can be census citizens with civic costume (asset task under the asset freeze).
- Interior light is approximate: one candle light per room, with the indoor darkening baked into the materials. There is no light falling through the windows.
- The validator's mesh check compares plan extents (AABB), not a full top-down raster.
- The plan's `forum` polygon (about 90 × 80 m) is still larger than the dossier's 1343 market reserve (about 44 × 36 m). The site's `reserve` follows the dossier, but the extra open ground around it is not yet filled with burgess plots.
- Stalls and carts are the district-map GLBs at their old scale; there are no awnings in varied cloth colours and no horses yet.
- Eight sites are registered. The castle and the gates are pending; the guild houses, the bishop's court, St John's hospital and the remaining towers are proposals without an ADR or task. See [Pending and proposed sites](#pending-and-proposed-sites-not-built-yet).
- The council-hall cellar (*cellarium civitatis*) is not walkable.
