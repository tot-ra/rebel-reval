---
domain: topography
slug: lower-town-street-plan
status: partial
consumers: [map, dev, art]
related:
  - ../../../docs/HISTORICAL_AUDIT.md
  - ./walls-gates-towers.md
updated: 2026-07-27
---

# Lower Town street plan (Spring 1343)

## Brief for Map

You are laying out the Hanseatic Lower Town (*All-linn*) at the foot of Toompea, not the Upper Town castle hill. **Use the surviving medieval street directions as alignment evidence, not as a measured 1343 cadastre** — no complete town plan survives from 1343 [1][2].

**Decisions you can ship now:**

1. **Central node:** Place the open market square (*forum*, modern Raekoja plats) at the civic heart, with the elongated limestone Town Hall (first mentioned 1322) on its south side. The square is predominantly open ground with temporary stalls; do not fill it with permanent buildings [3][4].
2. **Primary spines:** Run **Pikk** (east–west merchant/port axis) and **Lai** (parallel broad merchant lane to the south) as the main through-routes. Treat **Viru** (clay-street etymology, first written 1362) and **Vene** (Russian-merchant quarter) as major north–south feeders into the market [5][6][7]. **Karja** (cattle street, first written 1365) and **Harju** (smith street, first written 1362) are valid southern/eastern approaches but their *names* post-date 1343 by a few years — use the routes, label names cautiously in UI [5].
3. **Plot rhythm:** Default merchant strip plots are **7–11 m wide** and **up to ~100 m deep**, gable-end to street, with a front house, rear yard, and service buildings. Artisan, institutional, and harbour plots may be wider, shorter, or irregular [4][8].
4. **Block logic:** Blocks are **irregular**, not a modern grid. A deep plot may reach from one spine street to a parallel lane behind; institutional precincts (Dominican, Cistercian, St Olaf) break the strip pattern with large enclosed closes [2][4][9].
5. **Surfaces:** Stone, pebble, or limestone-slab paving on primary routes and important closes; packed earth, mud, and yard chips on secondary lanes — **not** blanket cobble everywhere [4][10].
6. **Slope:** Lower Town ground rises west toward Toompea and falls east/northeast toward Viru Gate and wet coastal margin [2][11].
7. **Three worked blocks** (below) give dimensions and uncertainty labels you can trace directly into `rrmap` authoring.

## Findings

### What survives from 1343 vs what is later survival

The UNESCO/heritage consensus is that Tallinn's Lower Town retains a **13th–14th-century street network and property subdivision** in broad outline [1][2]. That supports **direction, adjacency, and plot rhythm** for 1343 maps. It does **not** license copying later Gothic stone facades, post-1400 town-hall tower mass, or assuming every modern street name was already in use in April 1343 [4][12].

| Evidence class | What it gives the map | Confidence |
|---|---|---|
| Surviving street/property skeleton | Irregular lanes, narrow frontages, deep yards | attested as medieval survival; 1343 day-specific plan **unknown** [1][2] |
| Documentary street names | Dated first attestations (see table) | attested per date; existence before attestation **plausible composite** [5] |
| Archaeological plot/street layers | Paving types, slopes, suburb growth phases | attested locally; not citywide [10][11][13] |
| Hanseatic burgess-house typology | Strip plots, diele-front houses, rear service zones | plausible composite from Reval + regional comparanda [4][8] |

### Named streets: first attestations near 1343

Low German and Latin record forms below come from Päll's onomastic survey [5]. Streets may have existed earlier; absence from the table means **name not yet attested**, not "street absent."

| Modern / game name | Attested form | Year | 1343 map use |
|---|---|---|---:|---|
| Raekoja plats (market) | *forum* | 1313 | **Use** — central market node [5][3] |
| Olevimägi | *Zantberg* | 1337 | Hill by St Olaf; route name usable [5] |
| Nunne | *susterstrate* | 1361 | Route plausible; name **post-1343** [5] |
| Rataskaevu | *sub monte* | 1361 | Well area **uncertain** at exact modern anchor in 1343 [12] |
| Harju | *smedestrate* | 1362 | Smith-trade lane; route likely, name 1362 [5] |
| Viru | *leymstrate* ("clay street") | 1362 | Major eastern approach; name 1362 [5] |
| Suur-Karja | *Kariestrate* | 1365 | Cattle-market approach; name 1365 [5] |
| Lühike jalg | *parvus mons* | 1371 | Toompea descent; name 1371 [5] |
| Kuninga | *schostrate* | 1374 | Shoe-makers' lane; name 1374 [5] |
| Pikk | *(no 14th-c. attestation in [5])* | — | **plausible composite** main east–west spine from harbour archaeology + surviving alignment [2][14] |
| Lai | *(first MLG 1547+)* | — | **plausible composite** parallel merchant lane [5][2] |
| Vene | *(Estonian 1732+; linked to Russian merchants)* | — | **plausible composite** quarter identity by 1343 [6][7] |
| Müürivahe | *(wall lane — medieval function attested generically)* | — | Lane along inner wall face; treat as **plausible composite** [2][8] |
| Niguliste | *(church attested; street gravel 13th c.)* | — | Approach to St Nicholas; street surface **attested** 13th c. locally [15] |

### Market square placement

- The market (*forum*) is **attested in 1313** at the Town Hall square [5].
- Town Hall itself is **attested 1322**, with first-quarter-14th-century expansion; the recognisable arcade/tower silhouette is **post-1343** [3][4].
- For 1343: an **irregular open market space** north of the elongated hall, fed by Pikk, Viru/Vana Turg, Kuninga/Karja, and routes toward Niguliste and Toompea — not a formal rectangular plaza [4][12].
- Temporary stalls do not count as built footprint; surround the square with **narrow merchant strip plots** [4].

### Plot widths, depths, and block structure

**Default burgess strip (merchant/craft majority):**

- Width **7–11 m** at street frontage; depth **up to ~100 m** on affluent plots, shorter on poorer or "boda" craft plots [4][8].
- Plot separated by **timber/wattle fences** or **limestone plot walls** (~3 m high on wealthy strips — later-medieval upper bound, not universal default) [4].
- Typical massing: **gable end to street**, ridge perpendicular to lane; front **diele** hall/workshop, **rear yard** with sheds, privy, well, garden; wealthy plots add **rear house** (*dornse* zone) and cellar necks at street [4][8].
- **"Boda"** plots: smaller, often two-room workshop-dwellings, sometimes rented from a wealthy burgher [4].

**Institutional breaks in the strip pattern:**

- Dominican St Catherine (site from 1246; stone church 1260s) — large enclosed precinct with garden [9].
- Cistercian St Michael convent — northern expansion zone; substantial open service/garden ground [4][12].
- St Olaf — church recorded 1267; northern settlement incorporated early 14th c.; vault work 1330 [12].

**Block density (production ranges from project audit H04):**

| Zone | Built footprint | Open (streets/yards/closes) |
|---|---|---|
| Market/civic frontage | 50–65% | 35–50% (excl. market reserve) |
| Merchant north (Pikk/Lai) | 45–60% | 40–55% |
| Eastern artisan / Dominican edge | 45–60% | 40–55% |
| Monastic/guild precincts | 35–50% | 50–65% |

Ranges are **plausible composite** authoring bands, not measured 1343 statistics [12].

### Three worked blocks for map authoring

Dimensions below combine attested medieval bands [4] with surviving alignment [2]. Treat numbers as **target widths** with ±1 m acceptable variance.

#### Block A — Market south frontage (civic quarter)

| Edge | Treatment | Width / depth | Confidence |
|---|---|---|---|
| North | Open market (*forum*) | ~40–55 m open span (irregular) | plausible composite [3][4] |
| South | Town Hall long façade | ~30–35 m hall length (pre-1371 mass) | attested hall; exact 1343 length **partial** [3] |
| East–west frontage plots | Strip burgess houses | 7–9 m wide × 25–40 m deep to service lane | plausible composite [4] |
| Rear | Service lane + small yards | 3–4 m lane; yards 8–15 m deep | plausible composite [4] |

**Map hook:** Dense limestone/timber frontage on south side of square only; square stays open; no town-hall tower.

#### Block B — Pikk merchant strip (north quarter segment)

| Edge | Treatment | Width / depth | Confidence |
|---|---|---|---|
| Street | Pikk spine | 4–6 m paved cart width + flanking frontage | plausible composite [4][14] |
| Plot depth | Front house + rear warehouse/court | 8–10 m wide × 60–90 m deep | plausible composite [4][8] |
| Rear | Parallel work lane or neighbour plot tail | May reach toward Lai or a named rear lane | attested pattern type [2][4] |
| North margin | Falls toward harbour lowland | Express 1–2 m grade change over block depth | plausible composite [12][14] |

**Map hook:** Gable ends shoulder-to-shoulder; larger rear courts near Coastal Gate approach; tile more common on stone merchant houses.

#### Block C — Viru / Dominican edge (eastern artisan ward)

| Edge | Treatment | Width / depth | Confidence |
|---|---|---|---|
| West | Viru approach (clay-street) | 5–7 m primary width | name attested 1362; width **plausible composite** [5] |
| Plots | Mixed craft houses | 7–11 m wide × 30–50 m deep (shorter than Pikk deep strips) | plausible composite [4][12] |
| East | St Catherine precinct wall | Enclosed; do not fill with generic housing | attested institution [9] |
| Surfaces | More earth/mud on secondary lanes | Stone 25–40% of traversable ground in ward | plausible composite [12] |

**Map hook:** Tighter craft yards, wattle fences, Dominican garden visible beyond precinct wall; slope falls east toward wet margin.

### Regional power context on the ground

- **Danish crown** sits on Toompea; Lower Town is burgher/Hanseatic space under Danish sovereignty but **self-governed by council** in daily trade and craft [16].
- **Livonian Order** has extramural strongholds; inside walls the Order matters for defence alliances during the 1343 siege, not for plot layout [16].
- **Estonian population** works as servants, labourers, and some craft assistants; legal exclusion from full burgher status shapes who owns frontage plots vs rents "boda" space [4] — see people dossier (R-026).

## Production hooks

- **Map:** Use Block A–C tables as seed `rrmap` modules; preserve irregular block angles; keep market square open; run Pikk and Lai as parallel spines; feed Viru/Karja/Harju into market from east/south; express westward rise toward Toompea; limit cobble to primary spines (~25–55% stone share by ward per audit) [12].
- **Art:** Gable-end streetscapes on 7–11 m fronts; cellar necks and low terraces before doorways; rear yards with timber sheds, not uniform stone rows [4][8].
- **Character:** Front-house diele visibility from street on merchant plots; craft "boda" on smaller rear or rented plots [4].
- **Quest / Narrative:** Market square as rallying point; cattle route friction on Karja approach (name 1365); smith street identity on Harju; St George's Night siege approaches from east (Viru) and mainland south [16].
- **Dialogue:** Use *forum* / market, *strate* / street, Low German lane names where attested; avoid quoting 1374+ names as if common speech in April 1343 [5].
- **Dev / systems:** Plot width spawn band 7–11 m; depth cap ~100 m for generation; institutional precincts as non-buildable zones; surface-type weights per ward from audit [12].

## Cross-references

- [`walls-gates-towers.md`](walls-gates-towers.md) — gate positions (Viru, Karja, Coastal) terminate these spines; wall lane (*Müürivahe*) bounds blocks on the curtain side.
- [`../../../docs/HISTORICAL_AUDIT.md`](../../../docs/HISTORICAL_AUDIT.md) — P0-072 ward-level density, surface, and gate chronology that implement this street plan in prototype maps.
- **Pending neighbour:** `architecture/burgher-house-plan.md` (R-003).

## Open questions

- Exact 1343 footprint of **Pikk** and **Lai** names in council records — worth a dedicated language/register pass (supports R-024).
- **Rataskaevu** well at modern anchor vs generic well placement in 1343 — flagged uncertain in audit [12].
- Measured **street widths** at specific intersections (Viru × market, Pikk × Coastal Gate) — only local archaeology, no citywide survey.
- **Vene** quarter eastern limit and riverside plots — needs harbour shoreline dossier (R-005).
- Whether **Müürivahe** functioned as a full public lane or intermittent service path in 1343.

## Sources

1. UNESCO, "Historic Centre of Tallinn," https://whc.unesco.org/en/list/822/ — medieval plot/street survival (English).
2. Tallinn Heritage Protection, https://www.tallinn.ee/en/ehitus/heritage-protection — 13th-c. street network maintained (English).
3. Tallinn Town Hall building history, https://raekoda.tallinn.ee/en/the-building/ — 1322 first mention, 14th-c. expansion (English).
4. Medieval Heritage, "Tallinn residential buildings," https://medievalheritage.eu/en/main-page/heritage/estonia/tallinn-gothic-houses/ — plot sizes, house types, paving, plot walls (English).
5. Päll, P., "Names in Multi-Lingual, -Cultural and -Ethic Contact," Proceedings of the 23rd ICOS, York University, 2009 — dated street-name attestations (English).
6. Päll / S-Gabriel street-name list, https://www.s-gabriel.org/names/ffride/eestreets.html — MLG/Latin forms (English).
7. Heinloo, "Hidden Heritage" (EKA), Pikk Street medieval layout summary, https://www.artun.ee/en/curricula/cultural-heritage-conservation/hidden-heritage/ — Pikk as harbour spine (English).
8. Estonian Academy of Arts / artun.ee — diele-dornse layout, Hanseatic merchant house form (English).
9. Medieval Heritage, "Dominican Friary of St Catherine," https://medievalheritage.eu/en/main-page/heritage/estonia/tallinn-monastery-of-st-catherine-puha-katariina-klooster/ — precinct chronology (English).
10. Kraut & Nurk, AVE 2016/17 Viru tn archaeology — local limestone paving, Viru gate mid-14th c. (Estonian; PDF in `history/`).
11. Nurk et al., AVE 2010 Karja Gate — early pebble road, coastal relief (Estonian; PDF in `history/`).
12. Project internal: `docs/HISTORICAL_AUDIT.md` P0-072 dossier — ward ranges, gate chronology, 1343 constraints (English).
13. Heinloo, AVE 2018 Karja Gate suburb — suburb plot uptake 14th/15th c. (Estonian).
14. Roio et al., AVE 2015 Kadriorg ship find — maritime activity east of Hanseatic town, second quarter 14th c. (Estonian).
15. AVE 2022 Niguliste Street — 13th-c. gravel street layer, slope (Estonian).
16. Project internal: `history/HISTORY.md`, `history/TIMELINE.md` — 1343 siege and power structure (English).
