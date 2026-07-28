---
domain: architecture
slug: smithy-workshop-layout
status: solid
consumers: [art, map, dev, quest]
related:
  - burgher-house-plan.md
  - ../crafts/guild-structure.md
  - ../crafts/blacksmith-materials-and-techniques.md
  - ../military/arms-and-armour-livonia-1340s.md
  - ../topography/lower-town-street-plan.md
  - ../military/watch-duty-and-town-defence.md
updated: 2026-07-28
---

# Smithy workshop layout (Lower Town, Spring 1343)

## Brief for Art, Map, and Dev

You are building **Kalev's urban smithy** on a **7–11 m craft plot** in the Harju / eastern craft belt, not a rural open-air forge or a post-1400 guild monument. April 1343 has **no attested Reval smithy floor plan**; this dossier combines **Baltic raised-forge archaeology** (Haapsalu, Käku comparanda) with **Hanseatic fire-risk practice** and the project's existing `kalev_smithy` gameplay partition.

**Ship these decisions:**

1. **Building form:** Master smith occupies a **stone-footed, timber-framed craft house** — either a widened *boda* or a front-house **diele converted to hot-work** with living behind a **stone or plastered partition**. Rear-yard-only smithies exist but the **living + forge under one roof** model is `plausible composite` for a household master with apprentice [`burgher-house-plan.md`](burgher-house-plan.md) [1][2][3].
2. **Forge bay (~55% of ground floor):** **Raised rectangular hearth** (~1.6–2.0 m wide) built of **local limestone and clay**, not a ground pit — Baltic urban norm by the 14th century [2][3]. **Bellows on the smith's left**, blowing into a **side tuyere**; **anvil 1.5–2.5 m** down-fire from the hearth mouth; **quench trough or bucket** beside the anvil, not in the coal bed [2][3][4].
3. **Living bay (~45%):** Sleeping nook, ledger table, food table — **no open hearth** in the sleeping zone; smoke partition or chimney mass separates bays [1][5]. Apprentice (*Lehrling*) sleeps in the living bay or loft [`guild-structure.md`](../crafts/guild-structure.md).
4. **Storage:** **Charcoal** in a roofed corner or rear-yard crib (never under the bed); **iron stock** on racks or in a chest away from the quench splash; **finished work** on a shelf near the street door for customer pickup [4][6].
5. **Smoke:** **Hood or chimney throat** over the forge taking smoke out through the **north gable or rear wall** — mandatory `plausible composite` for an in-town shop; do not vent raw smoke into the living bay [5][7].
6. **Fire-risk rule (usable in quests):** Hanseatic towns required **smith fires banked or extinguished at the evening bell** and hot trades in **stone or peripheral plots** — violation draws **watch or council fine** [`watch-duty-and-town-defence.md`](../military/watch-duty-and-town-defence.md) [5][7][8]. **Attested Reval 1343 ordinance text: absent** — treat as Lübeck-law composite.
7. **Do not show:** Industrial trip-hammers, water-powered forge, brick chimney pots (17th c.), separate guild hall interior, or open courtyard forge as the default Lower Town shop.

## Findings

### Where the smithy sits on the plot

| Placement | Description | 1343 confidence |
|---|---|---|
| **Street-front diele forge** | Customer door opens to working bay; living behind partition | `plausible composite` — matches widened craft *boda* and merchant workshop logic [1] |
| **Rear-yard smithy** | Hot work in stone or half-timber shed behind the house; living in front | `plausible composite` — fire ordinances favour separation [5][7] |
| **Harju / craft lane** | Smith trades cluster on routes toward Harju Gate; name *smedestrate* first written **1362** — route likely earlier [`lower-town-street-plan.md`](../topography/lower-town-street-plan.md) [9] | attested later name; 1343 lane identity **plausible composite** [9] |

**Kalev's layout** (project map `kalev_smithy.rrmap`) uses the **street-front diele + rear living** partition — valid as a **household master** shop if the forge bay is **stone-footed, chimney-vented, and mud-sealed** against the timber living half [1][5].

### Labelled floor plan (gameplay-scale)

Dimensions use a **9 m frontage** plot on a 7–11 m strip. Cell grid from `kalev_smithy.rrmap` (26×14 cells at 32 px ≈ **8.3 m × 4.5 m** interior) is a **compressed gameplay footprint** — scale up mentally to full plot depth for art [10].

```text
STREET (south wall — courtyard door to rear lane)
┌─────────────────────────────┬──────────────────────────────────┐
│  LIVING BAY (~45%)          │  FORGE BAY (~55%)                │
│  ledger, bed, table         │  bellows ←  HEARTH  → tool rack  │
│  (clean lime plaster)       │       ↓                          │
│                             │     ANVIL — quench bucket        │
│                             │  charcoal / iron scrap (rear)    │
│  west window                │  north forge window (smoke vent) │
└─────────────────────────────┴──────────────────────────────────┘
         partition wall (stone base, plastered timber above)
```

| Zone | Label | Function | Confidence |
|---|---|---|---|
| A | Forge hearth | Raised stone/clay fire-pot; charcoal fuel | attested type Baltic urban [2][3] |
| B | Bellows station | Great bellows or double-bag, left of tuyere | attested Haapsalu left-side blow [2] |
| C | Anvil block | Wrought-iron face on stone stump or timber block | attested type [4] |
| D | Quench | Wooden trough or large bucket; water refreshed daily | attested type [4] |
| E | Coal / stock | Charcoal pile corner; iron bar rack; scrap heap | `plausible composite` [4][6] |
| F | Tool wall | Tongs, hammers, chisels on pegs | attested Mendel comparandum [4] |
| G | Living bay | Bed, chest, table — **no forge** | attested household craft pattern [1] |
| H | Street / yard door | Customer entry to forge bay; courtyard access south | `plausible composite` [1] |

**Circulation:** Customer enters forge bay from street or courtyard; master crosses partition to living for meals and ledger work; apprentice hauls charcoal from **rear yard crib** through courtyard door [1][6].

### Hearth, bellows, and fire geometry

Baltic medieval urban forges shifted from **ground pits** to **raised rectangular hearths** in the 13th–14th centuries as German craft traditions arrived [2][3].

| Element | Specification | Source confidence |
|---|---|---|
| Hearth size | **~1.6–2.0 m** wide rectangular base (Haapsalu F1/F2 comparanda) | attested archaeology [2] |
| Fire-pit shape | **T-shaped or L-shaped** fuel bed inside raised walls | attested Haapsalu [2] |
| Hearth height | **Waist to chest height** for standing smith — raised forge, not floor pit | `plausible composite` [2][3] |
| Tuyere | **Clay or iron pipe** through left cheek of hearth; bellows nozzle mates here | attested left-side blow Haapsalu [2] |
| Bellows | **Great bellows** (two-stage) or paired bag bellows; floor-mounted, smith-operated with foot or assistant | `plausible composite` Nuremberg/Riga practice [4][11] |
| Fuel | **Charcoal** primary; wood kindling for light-up only | `plausible composite` — detail in R-013 |
| Hood | **Stone or plaster hood** throat rising to chimney flue | `plausible composite` urban fire law [5][7] |

**Enclosed three-wall hearth** (back and sides masonry, open front to smith) matches manuscript tradition and contains sparks — use for art [`architecture.smithy-workshop-layout.03`] [11][12].

### Anvil, quench, and work flow

Standard sequence: **heat in hearth → transfer with tongs → strike on anvil → quench or air-cool → finish at bench** [4].

| Station | Placement rule | Notes |
|---|---|---|
| Anvil | **1.5–2.5 m** from hearth mouth, clear line for long bars | Käku / Haapsalu anvil stump inferred opposite forge [2][13] |
| Quench | **Beside anvil**, not behind bellows (steam blind) | attested type [4] |
| Vise / hardy hole | On anvil block or stump adjacent | `plausible composite` [4] |
| Finishing bench | Between anvil and street door for filing, riveting | `plausible composite` [4] |

Quench water is **changed frequently**; slag and ash rake to a **yard pit**, not the living floor [4][6].

### Fuel, stock, and storage

| Material | Storage | Fire rule |
|---|---|---|
| Charcoal | Roofed **corner crib** in forge bay or **rear-yard shed** | Keep **≥2 m** from sleeping partition [5][6] |
| Iron bar / scrap | Wall rack + chest; wet quench splash zone separate | — |
| Finished goods | Shelf near customer door; weapons not left in street view during unrest | quest composite [14] |
| Tools | Pegboard / shelf on east wall away from heat | attested [4] |

Charcoal delivery arrives by **cart** on Harju / craft lanes; yard gate from [`burgher-house-plan.md`](burgher-house-plan.md) rear plot [1][9].

### Smoke handling and ventilation

Urban smithies **cannot** run like open-air rural forges inside timber blocks [5][7].

- **Minimum:** Hood over hearth → **masonry flue** to north gable or rear wall [5] — `plausible composite`
- **Living partition:** **Stone to sill height**, plastered timber above; door has **threshold step** so ash does not drift [1][5]
- **Windows:** **Forge bay high window** for smoke wash; living bay separate opening [1]
- **Night:** Fire **banked under ash** or **extinguished** at curfew bell — see fire rule below [7][8]

Project audit: quench runoff uses **short gutter or soakage**; no invented sewer [`docs/HISTORICAL_AUDIT.md`] [15].

### Fire regulation and council risk (quest-usable)

No **Reval 1343 Feuerordnung** survives in this pass. Hanseatic composite norms:

| Rule | Consequence if broken | Confidence |
|---|---|---|
| **Bank or extinguish forge at evening bell** | Watch fine; guild embarrassment; neighbour fire claim | `plausible composite` [7][8] |
| Hot trades in **stone-footed** bays on dense strips | Council orders timber forge closure or relocation | `plausible composite` [5][7] |
| **Spark screen** on courtyard door in dry April | Watch order during siege timber shortage | `plausible composite` [8][15] |
| Forge fire spreads to neighbour | **Draconian** Lübeck-law liability; master may flee (narrative hook) | `plausible composite` [5] |

**Attested rule for Reval 1343:** **none cited here** — Producer should treat fines as dramatic, not legal-historical certainties.

**Siege April–May 1343:** Charcoal supply tightens; watch **doubled** near timber yards [`watch-duty-and-town-defence.md`](../military/watch-duty-and-town-defence.md) [8]. Night forging during curfew is **high detection risk** for quest design.

### Regional context

| Actor | Relationship to urban smith |
|---|---|
| **Schmiede *Amt*** (St Canute) | Sets quality and membership norms; no surviving 1343 shop plan [`guild-structure.md`](../crafts/guild-structure.md) [16] |
| **Danish crown** | Indirect — council enforces fire and market law [8] |
| **Livonian Order** | Arms customer after late April; does not lay out Kalev's hearth [14] |
| **Estonian rural smiths** | Cheaper horseshoe competition outside walls — price pressure, not layout evidence [9] |

### Reconcile with gameplay map

`kalev_smithy.rrmap` places **furnace east, bellows west, anvil centre, quench west-of-anvil, coal/scrap east** — consistent with **left-side blow** and **clockwise work loop** [2][10]. Living bay props (bed, ledger, table) occupy the **west half** separated by `wall.divider` [10]. Art should **darken forge plaster** and **limewash living walls** per map comment [10][15].

## Reference plates

| Plate | Shows | Source, date, origin | License | Answers |
|---|---|---|---|---|
| [`architecture.smithy-workshop-layout.01`](../../reference/architecture/smithy-workshop-layout/architecture.smithy-workshop-layout.01.jpg) | Blacksmith at hearth, bellows left, tool rack | Mendel Hausbuch I f. 120r, Nuremberg, c. 1425–1504 | public domain | bellows-to-hearth side layout |
| [`architecture.smithy-workshop-layout.02`](../../reference/architecture/smithy-workshop-layout/architecture.smithy-workshop-layout.02.jpg) | Smith striking at anvil, apron, tongs | Mendel Hausbuch I f. 47r, Nuremberg, c. 1426 | public domain | anvil station and tool handling |
| [`architecture.smithy-workshop-layout.03`](../../reference/architecture/smithy-workshop-layout/architecture.smithy-workshop-layout.03.jpg) | Enclosed forge workshop, multiple smiths | Agricola *De re metallica*, Basel, 1556 — later comparandum | CC BY-SA 3.0 | three-wall hearth and shop density |
| [`architecture.smithy-workshop-layout.04`](../../reference/architecture/smithy-workshop-layout/architecture.smithy-workshop-layout.04.jpg) | Hardening/quench tub beside furnace | Agricola *De re metallica* steelmaking plate, 1556 | public domain | quench placement relative to heat |
| `architecture.smithy-workshop-layout.05` (link-only) | Haapsalu raised forge F1 plan, bellows left | Pärn & Russow 2006, Haapsalu, 13th–14th c. | scholarly | Baltic urban hearth dimensions |
| `architecture.smithy-workshop-layout.06` (link-only) | Forge hearth components diagram | HMS Datasheet 303, UK, modern summary | linked | hearth/tuyere/bellows vocabulary |

## Production hooks

- **Art:** **`architecture.smithy-workshop-layout.01`** for bellows-hearth geometry; **`.03`** for enclosed masonry hearth; darken **east bay** plaster (`smoked_plaster`); living west bay **clean limewash**; limestone hearth base, **no brick chimney pot**; props: tongs, 2–3 hammers, poker, water bucket, charcoal sacks [`architecture.smithy-workshop-layout.02`].
- **Map:** Forge bay **55%** floor depth from partition; hearth in **north-east corner**; anvil **centre-east**; quench **west of anvil**; charcoal **south-east corner**; courtyard door **south centre**; plot stacks on Harju craft belt [9][10].
- **Character:** Master at hearth; apprentice on bellows or quench; customer stops **inside forge bay** not bedroom; Mart (*Lehrling*) sleeps living bay [16].
- **Quest / Narrative:** **Curfew forge test** — working past evening bell draws watch; **charcoal shortage** during siege; **partition fire** if defect quest damages hood; neighbour complaint if smoke vents wrong [7][8].
- **Dialogue:** *Esse* (hearth), *Blasebalg* (bellows), *Amboss*, *Lösch* (quench); *Schmiede* shop; council *Feuerwacht* [7].
- **Dev / systems:** Zones `forge_bay`, `living_bay`; `forge_active` raises smoke particle + detection risk after `curfew_hour`; `charcoal_stock` depletes per commission; quench action at `quench` prop; failure to `bank_fire` at night increments `fire_risk` flag.

## Cross-references

- [`burgher-house-plan.md`](burgher-house-plan.md) — craft *boda* and diele shell the forge occupies; rear yard charcoal path.
- [`../crafts/guild-structure.md`](../crafts/guild-structure.md) — Schmiede *Amt*, apprentice household, St Canute obligations.
- [`../crafts/blacksmith-materials-and-techniques.md`](../crafts/blacksmith-materials-and-techniques.md) — fuel, iron, and task durations (R-013 deliverable).
- [`../military/arms-and-armour-livonia-1340s.md`](../military/arms-and-armour-livonia-1340s.md) — what leaves the shop as finished work.
- [`../topography/lower-town-street-plan.md`](../topography/lower-town-street-plan.md) — Harju smith lane and plot rhythm.
- [`../military/watch-duty-and-town-defence.md`](../military/watch-duty-and-town-defence.md) — curfew bell and fire-watch duty.

## Open questions

- **Attested Reval smithy excavation** inside the 1343 wall circuit — Roosikrantsi suburb finds are **bronze casting**, not Kalev's ferrous shop [17].
- **Reval 1343 Feuerordnung** article numbers — needs Tallinn City Archives pass (feeds R-041).
- **Chimney vs smoke hole** prevalence on craft houses in the 1340s — no measured Reval example.
- **Water supply** for quench: well in rear yard vs bucket haul from public well [`lower-town-street-plan.md`](../topography/lower-town-street-plan.md).

## Sources

1. [`burgher-house-plan.md`](burgher-house-plan.md) — diele, *boda*, plot shell, hearth separation (project dossier).
2. R. Saage, "Smithies and forges around the north-eastern Baltic Sea," *Historical Metallurgy*, 2018 — Haapsalu raised forges, left-side bellows, pit-to-raised evolution (English).
3. A. Pärn & E. Russow, "Handwerk in den Kleinstädten Estlands," in *Lübecker Kolloquium V: Das Handwerk*, 2006 — Haapsalu smithy dimensions (German).
4. Historical Metallurgy Society, Datasheet 303: Iron hand blacksmithing, https://historicalmetallurgy.org/media/mxiorxzr/hmsdatasheet303.pdf — hearth, bellows, anvil, quench vocabulary (English).
5. Mittelalter-Lexikon, "Feuerordnung," https://www.mittelalter-lexikon.de/wiki/Feuerordnung — hot trades in stone/periphery, evening hearth banking (German).
6. G. Agricola, *De re metallica*, Basel, 1556 — workshop engravings; later comparandum for layout density (Latin/German).
7. D. E. Kaiser, urban militia as fire watch, 2013 — composite watch/fire duty (English).
8. [`watch-duty-and-town-defence.md`](../military/watch-duty-and-town-defence.md) — curfew bell, fire watch (project dossier).
9. [`lower-town-street-plan.md`](../topography/lower-town-street-plan.md) — Harju *smedestrate* route (project dossier).
10. Project map: `content/maps/kalev_smithy.rrmap` — gameplay zone partition and prop anchors (English).
11. Mendel Hausbuch I f. 120r, Wikimedia Commons — hearth/bellows illustration (public domain).
12. File:Agricola Schmiede.jpg, Wikimedia Commons — enclosed workshop (public domain).
13. J. Peets et al., Käku medieval smithy site, AVE 2012–2014 — anvil position, water tank (Estonian/English summaries).
14. [`arms-and-armour-livonia-1340s.md`](../military/arms-and-armour-livonia-1340s.md) — forge output boundaries (project dossier).
15. Project internal: `docs/HISTORICAL_AUDIT.md` — kalev_smithy material hierarchy, drainage caution (English).
16. [`guild-structure.md`](../crafts/guild-structure.md) — Schmiede *Amt*, apprentice tier (project dossier).
17. AVE 2021, Roosikrantsi 9/11 — suburban bronze workshop, not ferrous street forge (Estonian).
