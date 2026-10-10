# Rakvere (Wesenberg, Tarvanpea)

**Status:** planned (design proposal, not implemented) · **Scope gate:** new (needs ADR + task) · **Act(s):** Act 2 (travel colour, Viru rising), Act 3 (aftermath and 1346 handover)
**Map id:** `loc.world_rakvere` (proposed; no `content/maps/world_rakvere.rrmap` exists yet, although [TOURIST_LANDMARKS.md](../TOURIST_LANDMARKS.md) already names it as a "distant placeholder") · **Seasons/phases:** late spring 1343 (rising), summer 1343 (reprisal), winter 1345-46 (sale of the Duchy)
**Confidence summary:** Danish crown ownership, a vogt, the limestone plateau, the pre-Christian hillfort and the Viru rising are `attested`; the 1343 look of the castle, the road-inn, the Tapa crossroads layout and every named person here are `plausible composite` or `invented`; the Tarapita legend is `folklore` read from an `attested` chronicle line.

> **Correction to existing repo text.** [TOURIST_LANDMARKS.md](../TOURIST_LANDMARKS.md) row 16 calls Rakvere an "Order-affiliated stronghold over Viru roads". For 1343 that is wrong: Wesenberg was a **Danish crown castle** of the Duchy of Estonia, held by a royal vogt. It passed to the Teutonic/Livonian Order only with the sale of 1346 (see [CANON.md](../CANON.md), Act 3 seeds). This page uses the Danish status and the tourist table should be amended when the node is accepted. Row 18 (Toolse) and row 26 (Vihula) of the same file carry the Toolse anachronism already flagged in the brief and are not used here.

## 1. Why a player would want to visit

- A real **limestone plateau** (Pandivere edge): pale outcrops, cut-stone walls, and a hill with a castle on it. It is the first node on the Viru road that looks like rock, not bog or sea.
- The **Viru rebels are the eastern flank** of the uprising. Here the player sees the rising from the side of a crown fortress that must hold, not from Reval's walls.
- A **Danish garrison under a vogt**, cut off from a viceroy in Reval who is himself thin on men. It is the only node where the Danish crown is the besieged party and the Order is the distant, patient neighbour.
- **Viru-county voices**: a recognisable north-eastern Estonian dialect, different from Harju speech in rhythm and vowels.
- **Signature:** pale limestone hill and quarry cuts under a Danish banner, with a road-inn at a crossing where couriers choose sides.

## 2. History in 1343

| Claim | Label | Note |
|---|---|---|
| Rakvere (Wesenberg) belonged to the Danish crown in the Duchy of Estonia until the 1346 sale | `attested` | Passes to the Order 1346; later Order castle expansion is post-1346 and must not be shown |
| A castle on the Tarvanpea hill, with a royal vogt (bailiff) for Viru | `attested` (office) / `plausible composite` (2-3 stone ranges, small bailey in 1343) | Exact extent in 1343 unverified; the large convent-type Order castle with its long western bailey is later |
| Pre-Christian hillfort on the same hill | `attested` (archaeology) | Earthen bank traces can survive as a lower terrace |
| Town of Wesenberg under Lübeck law | `plausible composite` | Charter date c. 1302 reported in secondary sources; unverified |
| Viru vassals and crown tenants killed or driven out in the rising of 23 Apr 1343 | `attested` (general pattern) / `plausible composite` (Wesenberg specifics) | The Viru rising is in the chronicle tradition; local events are not recorded |
| Tarapita, the god said to be born on a Viru mountain who flew to Ösel (Henry of Livonia, 1220) | `attested` (chronicle line) / `folklore` (later retelling) | Hill identification with Tarvanpea is `folklore`; use as optional lore only |
| Bishopric/Order tension over Viru tithes | `plausible composite` | Background only |

Phases:
- **Act 2, Apr-May 1343:** rebel bands hold the open country; the castle garrison is under pressure but not stormed. Couriers cross at Tapa.
- **Act 3, 1343-45:** the Order's reprisal columns pass on the road; Danish officials sell debts and fiefs.
- **1346:** keys change hands. Optional closing vignette: Danish banner lowered, Order seal read aloud (no army shown).

Do not show: Order-era great castle expansion, Rakvere town hall, the Vaala/Tapa railway, cement works at Kunda, any "Toolse" coastal fort (built c. 1471), Vihula manor (post-medieval), windmill ridges.

## 3. Landscape and layout

Biome: dry **limestone plateau, juniper pasture, pine and spruce on the rim**, clear streams in shallow stone beds; weather is colder and windier than Harju. Season palette: cold mud in April, dry gold grass in June.

Proposed map size **84 x 40 cells** (same compact scale as `world_*` greyboxes, wider than Paide at 50 x 30 because of the plateau and road).

| Zone | Cells (x, y) | Reads as | Carries |
|---|---|---|---|
| West approach and Tapa crossroads | x0-18, y16-34 | Churned road, a milestone cairn, two roads | `road_from_harju`, `tapa_junction` anchor, courier hide |
| Road-inn and stable yard | x14-32, y24-36 | Log-and-stone inn, pen, trough, smithy lean-to | Kalev-style forge errand, rumours, `landmark_road_inn` |
| Town fringe | x30-52, y22-38 | Wooden houses, a wooden church with a small stone chancel, market green | Crowd, merchants, `landmark_market_green` |
| Limestone quarry | x20-44, y4-18 | Pale rock cuts, stacked blocks, sledge ramp | Stone commission, `landmark_quarry` |
| Tarvanpea hill and castle | x52-78, y4-24 | Terraced hill, rock-cut ditch, gate tower, small hall and tower | `landmark_gatehouse`, `landmark_castle_hall`, `landmark_old_hillfort_bank` |
| East slope and juniper pasture | x58-84, y24-40 | Stock paths, juniper, sheep, rebel scouts | Optional camp, `east_viru_road` exit |
| Stream and spring | x4-16, y4-14 | Clear stream, birch alder strip | Optional spirit-world scene, `landmark_spring` |

Journey edges (all explicit travel, not seamless, per [AGENTS.md](../../AGENTS.md)):

| Edge id (proposed) | To | Notes |
|---|---|---|
| `road_to_harju` | `loc.world_harju` ([site](../SYSTEMS/REGIONAL_SITES.md)) | West, along the Viru road |
| `road_to_narva` | `loc.world_narva` ([page](./narva_peipus_east.md)) | East, long road; forced loading card |
| `road_to_paide` | `loc.world_paide` ([map](../../content/maps/world_paide.rrmap)) | South-west, Act 2 finale route |

## 4. Architecture and built environment

| Element | 1343 state | Material and form | What distinguishes it |
|---|---|---|---|
| Castle on Tarvanpea | Small stone royal castle, `plausible composite`: gate tower, hall range, one stair tower, timber hoardings on a rock-cut ditch | Coursed limestone slabs, lime mortar, shingle roofs | Pale stone, a ditch cut straight into rock, no brick |
| Hillfort bank | Overgrown earthen terrace below the castle | Grass-covered earth, a few old palisade post holes | Shows the site's older layer |
| Wesenberg settlement | A few streets of timber and clay-daub houses, one wooden church with stone chancel (`invented` form) | Log, turf and shingle; limestone footings | Rural-urban hybrid, not Hanseatic gables |
| Road-inn | Long log hall, stone cellar, fenced yard | Log, stone footing, reed or shingle roof | Eastern road inn type, different from Reval taverns |
| Quarry | Open cuts, wedge marks, sledge track | Bare rock and block stacks | Gives a "craft landscape" no other node has |
| Boundary markers | Boundary stones, waystone, wayside cross (wooden) | Limestone and oak | Road identity |

## 5. Cultures, languages, and people

| Group | Language | Dress and craft | Religion and custom |
|---|---|---|---|
| Viru Estonian peasants and quarrymen | Viru (north-eastern) dialect of Estonian | Undyed and brown wool, felted caps, bast shoes, limestone-dust aprons | Catholic parish plus private hiis custom (`plausible composite`) |
| Danish crown vogt household | Danish, German for letters, Latin for clerks | Dark wool with crown colours in tabard (red and gold, unverified) | Catholic, formal |
| German or Danish vassals and sergeants | Low German | Mail, gambeson, kettle hat | Catholic |
| Wesenberg townsfolk and merchants | Low German, Estonian | Plain wool, leather aprons | Small parish church |
| Road travellers (carters, pedlars, couriers) | Estonian, Low German, a little Russian | Mixed | Wayside shrines |

Names: Viru peasant forenames from the 1340s corpus in [estonian-forenames-harju-1340s.md](../../history/dossiers/language/estonian-forenames-harju-1340s.md) (Harju corpus; treat as proxy for Viru, `plausible composite`).

## 6. Factions present

| Faction id | Presence here | What they want | Where | Act-by-act |
|---|---|---|---|---|
| `danish_crown` | Strong in structure, weak in men: vogt, garrison of a few dozen | Keep the castle, collect tax, delay the Order | Castle, town hall room | Act 2 besieged; Act 3 selling; 1346 handover |
| `harju_kings` | Viru contingents (not Harju), local leaders | Burn manors, cut the road, take supplies | East slope, stream | Act 2 peak; Act 3 shatter |
| `livonian_order` | Distant: envoys, a chaplain, scouts | Buy loyalty, watch, prepare to inherit | Road-inn, town fringe | Rising from Act 2; heavy in Act 3 |
| `hanseatic` | Low: carters with Reval tokens | Open road, protect cargo | Inn yard | Constant |
| `black_cloaks` | Courier link at Tapa | Move messages, spy | Crossroads | Act 2 |
| `cult_metsik` | Rumour only | Hill veneration | Hillfort bank | Optional |
| `pskov_novgorod` | Trader transit eastwards | Use the road to Narva | Inn | Trade scenes |

## 7. Characters

| char id | Name | Role / faction | Language | Confidence | Source | Hook / quest use |
|---|---|---|---|---|---|---|
| `char.konrad_preen` | Konrad Preen | Danish viceroy (offstage letters) | Danish, German | `plausible composite` | existing ([brief](../CHARACTERS/konrad_preen.md)) | Orders the vogt by seal; no on-map body |
| `char.kalev` | Kalev | Master smith | Estonian, German | existing | [brief](../CHARACTERS/kalev.md) | Quarry iron and wedge commission |
| `char.apprentice` | Apprentice | Protagonist | Estonian | existing | [brief](../CHARACTERS/apprentice.md) | Hill-spirit scene |
| `char.lembit_helme` | Lembit Helme | Elder king of Harju rebels | Estonian | `plausible composite` | existing ([legacy](../../characters/rebels/lembit_helme.md)) | Sends a runner to Viru |
| `char.kaja` | Kaja Lahekivi | Rebel messenger | Estonian | `invented` | existing ([brief](../CHARACTERS/kaja.md)) | Courier chain through Tapa |
| `char.brother_hermann` | Brother Hermann | Order handler | German | `plausible composite` | existing ([brief](../CHARACTERS/brother_hermann.md)) | Order scouting in Act 3 |
| `char.vogt_of_wesenberg` | Vogt Jens Ravn (placeholder) | Danish crown vogt | Danish, German | `invented` | NEW | Siege and negotiation |
| `char.viru_quarry_master` | Tõnu Kivimägi | Quarry gang boss | Viru Estonian | `invented` | NEW | Stone, iron, rumours |
| `char.inn_keeper_tapa` | Ode, innkeeper | Road-inn keeper | Estonian, Low German | `invented` | NEW | Information broker |
| `char.viru_rebel_captain` | Mats Soosaar | Local rebel leader | Viru Estonian | `invented` | NEW | Offers or demands iron |
| `char.crown_chaplain` | Father Anders | Castle chaplain | Latin, Danish | `invented` | NEW | Confession scene |

Crowd archetypes: quarryman, sledge-carter, juniper-switch seller, castle sergeant, drover, wayside pilgrim.

## 8. Quests, encounters, and discoveries

| id (proposal) | Act | Type | Hook | Ties |
|---|---|---|---|---|
| `quest.viru_wedge_iron` | 2 | forge commission | Quarry cannot split stone without hardened wedges; the order is for the castle and the rebels both | `quest.stolen_iron` echo |
| `quest.tapa_courier` | 2 | night mission | Carry a sealed word across Tapa without showing either banner | `faction.black_cloaks` |
| `quest.vogt_ledger` | 2 | investigation | Who sold the castle grain stores? | `faction.danish_crown` |
| `quest.hill_spirit` | 2 | spirit-world | The old hill remembers a god and a fort | `faction.cult_metsik`, ADR 0033 |
| `quest.keys_of_wesenberg` | 3 | travel event | See the 1346 handover as a witness | CANON Act 3 |

Sights (journal pages): limestone strata and why Reval builders used them; the Tarapita line in the old chronicle; the rock-cut ditch method; a Viru farmstead's two-room smoke house; a wayside cross at Tapa.

## 9. Resources: what must be generated

### 9.1 Structures & architecture

| asset id | Description | Priority | Shared with | Notes |
|---|---|---|---|---|
| `asset.kit.limestone_castle` | Modular limestone castle kit: gate tower, wall segments, rock-cut ditch, stair tower, shingle roof | P1 | Paide, Padise, Haapsalu | Defined here; others cite it |
| `asset.struct.rakvere_castle_1343` | Wesenberg castle preset using the kit | P1 | - | `plausible composite` |
| `asset.kit.log_hall_inn` | Log hall with stone cellar and reed roof | P2 | Narva, Harju village | Road-inn |
| `asset.struct.quarry_cut` | Quarry face with wedge marks, stacks, sledge ramp | P1 | Haapsalu | Terrain sculpt |
| `asset.struct.wayside_cross_wood` | Oak wayside cross and cairn | P3 | Narva | Boundary marker |

### 9.2 Props & craft objects

| asset id | Description | Priority | Shared with | Notes |
|---|---|---|---|---|
| `asset.prop.quarry_wedges_set` | Iron wedges, mauls, plugs | P1 | Kalev forge | Commission item |
| `asset.prop.limestone_block_stack` | Cut block stacks | P2 | Haapsalu | - |
| `asset.prop.sledge_cart` | Stone sledge | P2 | - | - |
| `asset.prop.crown_banner_danish` | Red field banner (unverified form) | P2 | Narva | Do not use post-1400 Dannebrog |
| `asset.prop.vogt_seal_matrix` | Seal die and wax | P2 | Narva | - |

### 9.3 Characters

| asset id | Description | Priority | Shared with | Notes |
|---|---|---|---|---|
| `asset.char.wardrobe.viru_peasant` | Viru wool tunic, felt cap, bast shoes | P1 | Harju | Wardrobe variant on shared rig |
| `asset.char.wardrobe.quarryman` | Dust apron, leather cap | P2 | - | - |
| `asset.char.wardrobe.crown_sergeant` | Gambeson, tabard in crown colours | P1 | Narva | - |
| `asset.char.hair.viru_braids` | Braided hair set | P3 | - | MPFB |

### 9.4 Fauna

| Species | Status | Priority | Notes |
|---|---|---|---|
| Sheep, cow, pig, chicken, goose, horse | already cataloged (`fauna.sheep`, `fauna.cow` etc.) | - | Use as is |
| Juniper-pasture hare, fox, roe deer | already cataloged (`fauna.hare`, `fauna.red_fox`, `fauna.roe_deer`) | - | - |
| Hooded crow, rook, kestrel, skylark | already cataloged | - | - |
| Draught ox | missing | P2 | Quarry sledge |
| Black grouse | missing | P3 | Juniper edge |

### 9.5 Flora & ground cover

| Item | Status | Notes |
|---|---|---|
| `tree.juniper`, `tree.pine`, `tree.spruce`, `tree.birch`, `tree.alder` | existing | Plateau mix |
| `grass.dry`, `grass.short`, `plant.moss`, `plant.fern`, `plant.thistle` | existing | - |
| `plant.limestone_rock_flora` (alvar thyme, rock moss mat) | missing | P3 |
| `ground.limestone_pavement` | missing | P2, shared with Haapsalu |

### 9.6 Materials / terrain / water

| asset id | Description | Priority | Notes |
|---|---|---|---|
| `mat.limestone_pale` | Pale grey-cream stone, fine joints | P1 | Key identity |
| `terrain.rock_cut_ditch` | Rock-cut ditch profile | P1 | - |
| `water.clear_stone_stream` | Clear shallow stream | P2 | - |

### 9.7 Audio & music direction

Languages heard: Viru Estonian, Low German, Danish phrases. Ambient: wind over open plateau, quarry hammering, sledge runners, juniper rustle, rooks. Instruments: kannel or jouhikko style bowed lyre for a thin road theme (`plausible composite`); no organ.

## 10. Variety signature and risks

Palette: cold limestone cream, juniper green-black, rust of iron. Silhouette: bare plateau with a pale hill crown. Soundscape: hammers and wind.

Risks: anachronism (Order-era castle, Toolse, windmills); a stone-castle model that outgrows scope; the correction to existing docs; Viru dialect sensitivity; depiction of killings should stay off-screen.

**Scope gate:** `new`. A node of this size needs an ADR and a task. Equivalent scope to remove or compress: one of the minor Act 2 hinterland detours (for example folding the `world_sojamae` approach scene into `world_kanavere`), or the unactivated `world_parnu` side content. Keep it to one authored map plus one quest line.

Open questions: Does the maintainer accept the Danish-status correction? Is Wesenberg's stone castle too large for the 1343 date to show?

## 11. Sources and next steps

- Repo: [CANON.md](../CANON.md), [TOURIST_LANDMARKS.md](../TOURIST_LANDMARKS.md), [global_map_mockups.md](../reports/global_map_mockups.md), [FLORA_FAUNA.md](../FLORA_FAUNA.md), [world_paide.rrmap](../../content/maps/world_paide.rrmap) (scale model), [danish_crown](../CITIZENS/factions/danish_crown.md), [harju_kings](../CITIZENS/factions/harju_kings.md).
- External by name only: Henry of Livonia (Chronicon Livoniae), Danish crown records on the Duchy of Estonia, Estonian archaeology of the Tarvanpea hillfort.
- Verification tasks: confirm the 1346 handover details and the castle's 1343 extent; confirm Wesenberg's town charter date; confirm Viru rising events; confirm the red crown banner form; add `world_rakvere.rrmap` only after the ADR.
