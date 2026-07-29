---
domain: topography
slug: public-bath-locations-1343
status: partial
consumers: [map, art, quest, dialogue]
related:
  - ../dailylife/hygiene-and-grooming-1343.md
  - ../power/reval-street-cleaning-ordinances-1340s.md
  - ../religion/ecclesiastical-precinct-boundaries-1343.md
  - ../religion/churches-and-religious-houses.md
  - ./lower-town-street-plan.md
  - ./walls-gates-towers.md
updated: 2026-07-29
---

# Public bath plot locations (Spring 1343)

## Brief for Map

You are placing **city-owned public baths** (*Bad*, *Saun*, *stupa*) and **one enclosed convent bath** on the Lower Town mesh — **peripheral timber or stone bathhouses**, not Roman thermae and **not** the post-1371 **Saunatorn** stone tower [`hygiene-and-grooming-1343.md`](../dailylife/hygiene-and-grooming-1343.md).

**Ship these decisions:**

1. **Four municipal POIs** with stable IDs below: **Nunne (Stocker)**, **Oleviste**, **Sauna street (Uus saun)**, and **south-wall nunnery bath** — all **city- or convent-owned**, drained toward **wet margins** or **licensed channels**, not into forum paving [1][2][3].
2. **Rataskaevu is a well/crane street, not a named 1343 bath plot.** Do **not** place a `bath.rataskaevu` POI unless a later AWB folio pass (R-066) finds a Badpacht row; secondary historiography lists Rataskaevu among later bath streets only `plausible composite` [4][5].
3. **Nunne Stocker sauna (1310)** sits on the **west belt** opposite the future NUKU courtyard (modern Nunne 7); medieval street line may lie **under present Nunne tänav** — author a **~12×18 m** timber/stone bath footprint straddling lane and courtyard edge `plausible composite` [6][7].
4. **Sauna street cluster (1329 Uus saun)** occupies **Viru–Väike-Karja** lane lots at modern Sauna 6–8; street name (*Stavenstraße*, *Badstubenstraße*) reflects this cluster from the **14th c.** onward [8][9].
5. **Oleviste bath (1329)** is a **second municipal node** north of St Olaf church on the **Zantberg** slope — separate mesh from Sauna street; do not merge into one mega-bath [2][10].
6. **South-wall / Saunatorn zone:** show a **wooden circular-wall nuns' bath** inside St Michael precinct (**13th-c. tradition**); **omit** the **1371+ stone Saunatorn** turret and **1422** demolition conflict [11][12].
7. **Use the point table and authoring coordinates** (local axes, metres). Vertices are **plausible composite** ±5–8 m; reconcile with [`ecclesiastical-precinct-boundaries-1343.md`](../religion/ecclesiastical-precinct-boundaries-1343.md) nunnery polygon.

## Findings

### Method and limits

No **1343 measured bath cadastre** survives. Plot anchors combine: Tallinn property-book tradition cited in archaeology (Heinlöö NUKU 2013) [6], Estonian bath historiography (Saunale.ee, Kübar) [1][2], street-name onomastics [5][8], and surviving wall/convent topography [11][12]. **TLA Ältestes Wittschopbuch** may hold Badpacht clauses for these plots — **not folio-read this tick**; coordinates are **authoring targets**, not survey.

### Map-usable point list

Local axes: **+X east**, **+Y north**, origin at **south-west corner of open market ground** (*forum*), consistent with [`raekoja-plats-extents-1343.md`](./raekoja-plats-extents-1343.md). Metres.

| Stable ID | Common name | Authoring point (X, Y) | Footprint target | Document anchor | 1343 operational status | Confidence | Ref |
|---|---|---:|---|---|---|---|---|
| `bath.nunne_stocker` | Stocker municipal sauna | **(−48, 22)** | ~12×18 m; may extend under lane | **1310** — first public town sauna (Kanne letter tradition) | Open; city-leased | attested (doc date); plot `plausible composite` | [6][7] |
| `bath.oleviste` | St Olaf church bath | **(−12, 58)** | ~10×14 m yard building | **1329** — sauna by Oleviste church | Open; city-leased | attested (doc date); plot `plausible composite` | [2][10] |
| `bath.sauna_street_uus` | Uus saun / Sauna street baths | **(28, −18)** | ~14×20 m on lane lots 6–8 | **1329** — *Uus saun* at present Sauna 6–8 | Open; city-leased | attested (doc date); plot `plausible composite` | [8][9] |
| `bath.saunatorn_precinct` | Cistercian nuns' enclosed bath | **(−52, 12)** | ~8 m dia. within circular precinct wall | **13th c.** — ladies' sauna in convent ring wall | Open; convent use | attested tradition; 1343 fabric `plausible composite` | [11][12] |
| `bath.rataskaevu` | *(do not author)* | — | — | Street **1328** *dummestrate*; **1348** *sub monte* — **well/crane**, not bath | **No 1343 bath plot attested** | gap [4][5] | Heinloo 2013; Tallinn Streets [5] |

**Secondary / post-scope baths** (cite only; no April 1343 POI without new evidence):

| Location | Note | Confidence |
|---|---|---|
| Niguliste church margin | Listed in 14th–15th-c. bath inventories | plausible composite [1] |
| Small Coastal Gate (*Väike Rannavärav*) | Harbour-edge bath tradition | plausible composite [1] |
| Dominican priory service yard | Priory + guest bath `plausible composite` | plausible composite [13] |

### Zone-by-zone narrative

#### Nunne (Stocker sauna)

- **1310** document associates the **first municipal public sauna** with the plot opposite the inner courtyard of the present NUKU theatre (**Nunne 7** tradition) [6][7].
- **Archaeology (2013):** early-14th-c. **thick-walled stone building** partly under **modern Nunne street**; medieval Nunne alignment may lie **south-west of present carriageway** [6].
- **1343 scene:** timber or mixed **steam bath** with **city rent to Saunapidaja**; **drain** toward **west wet margin** / nunnery garden edge; **hay-bundle or horn** at door per Baltic custom `plausible composite` [1][2].
- **Wall pressure:** 1340s curtain incorporation eats western margin; bath may sit **just inside** new wall line near **Nuns' opening** — not yet named **1355** [`walls-gates-towers.md`](./walls-gates-towers.md).

#### Rataskaevu

- Street first recorded **1328** as *platea dicta dummestrate* (hoist/lever street), **1348** *sub monte*, **1381** *sub monte sitam penes machina* — all name the **well-hoist apparatus**, not a bathhouse [5].
- **Saunale.ee** lists Rataskaevu among streets that **later** hosted public baths; **no 1343 property-book row** tying a Bad to this slope was reviewed [1][4].
- **Map rule:** author **Rataskaevu well POI** separately; **do not** duplicate a municipal bath here unless R-066 AWB pass finds Badpacht.

#### Sauna street (*Sauna tänav*)

- Lane **~140 m**, **Viru → Väike-Karja**; MLG *Badstubenstraße*, *Stovenstraße* [8].
- **1329:** *Uus saun* (**New sauna**) attested at sites of modern **Sauna 6 and 8** [8][9].
- **1343:** dense **nightlife-adjacent** lane in modern tourism, but in period = **working bath row** with **smoke, lye run-off, and queue** at Saturday peak `plausible composite` [1][2].
- **Drainage:** licensed bath waste may tie into **wooden storm channels**; not full sewer grid [`hygiene-and-grooming-1343.md`](../dailylife/hygiene-and-grooming-1343.md).

#### South-wall service zone (St Michael / Saunatorn)

- **13th-c.** Cistercian precinct had **~3.5 m circular wall** incorporating a **women's sauna** — name source for later **Saunatorn** [11][12].
- **1371–1372:** stone **Saunatorn** turret begins — **post-1343** [`walls-gates-towers.md`](./walls-gates-towers.md).
- **1422:** council demands demolition of nuns' bath blocking **wall patrol** — **post-1343** conflict [11].
- **April 1343:** author **low timber bath** inside **south-west precinct** (`bath.saunatorn_precinct`); **no stone tower mesh**; show **construction scaffold** on adjoining **W1** curtain [`ecclesiastical-precinct-boundaries-1343.md`](../religion/ecclesiastical-precinct-boundaries-1343.md).

### Relative placement sketch

```
                    [Toompea]
                        |
         bath.oleviste ·  St Olaf
                        |
    bath.nunne_stocker  |     [forum]
         ·              |        ·
    [St Michael]        |    bath.sauna_street_uus
 bath.saunatorn_precinct|        ·
         ·              |
              [Viru gate apron]
```

## Production hooks

- **Map:** Register five rows in bath POI table; activate **four** (`bath.nunne_stocker`, `bath.oleviste`, `bath.sauna_street_uus`, `bath.saunatorn_precinct`). Tag `owner: city` or `owner: convent`; `drain: wet_margin`; `quest_hook: sanitation`. **Exclude** `bath.rataskaevu` until AWB evidence.
- **Art:** Municipal baths = **low timber hall**, **smoke vent**, **tub or steam benches**, **nude same-sex interior** [`dailylife.hygiene-and-grooming-1343.02`](../../reference/dailylife/hygiene-and-grooming-1343/dailylife.hygiene-and-grooming-1343.02.jpg) comparandum only. Nunnery bath = **small circular wooden structure** inside curtain, **not** stone tower.
- **Quest / Narrative:** **Saturday queue** at `bath.sauna_street_uus`; **Vogt fine** after brawl at `bath.nunne_stocker` (1225 *stupa* double composition) [`reval-street-cleaning-ordinances-1340s.md`](../power/reval-street-cleaning-ordinances-1340s.md); **siege** reduces cart service but baths stay open unless council orders closure (gap).
- **Dialogue:** MLG **Bad**, **Saun**, **stupa**, **Saunapidaja**; point players to **Nunne** (oldest), **Sauna street** (nearest Viru), **Oleviste** (north burghers).

## Reference plates

| Plate | Shows | Source, date, origin | License | Answers |
|---|---|---|---|---|
| [`dailylife.hygiene-and-grooming-1343.02`](../../reference/dailylife/hygiene-and-grooming-1343/dailylife.hygiene-and-grooming-1343.02.jpg) | Communal tub bath with attendants | Tacuinum Sanitatis print, 1531 publ. | CC BY 4.0 | Interior layout comparandum — not Reval fabric |
| [`religion.ecclesiastical-precinct-boundaries-1343.04`](../../reference/religion/ecclesiastical-precinct-boundaries-1343/religion.ecclesiastical-precinct-boundaries-1343.04.jpg) | Nunnatorn and Monastery Gate massing | Leif Jørgensen photo, 2018, Tallinn | CC BY-SA 4.0 | South-wall zone — gate arch later than 1343 |
| `topography.public-bath-locations-1343.01` (link-only) | NUKU courtyard archaeology plan with Nunne sauna plot | Heinloo, AVE 2013:6 fig. 3 | linked | Stocker sauna under-street footprint |

## Cross-references

- [`../dailylife/hygiene-and-grooming-1343.md`](../dailylife/hygiene-and-grooming-1343.md) — bathing rhythm, status tiers, open question resolved here.
- [`../power/reval-street-cleaning-ordinances-1340s.md`](../power/reval-street-cleaning-ordinances-1340s.md) — 1310/1329 dated bath lines; Art. 31 enforcement.
- [`../religion/ecclesiastical-precinct-boundaries-1343.md`](../religion/ecclesiastical-precinct-boundaries-1343.md) — St Michael polygon and Saunatorn zone.
- [`./lower-town-street-plan.md`](./lower-town-street-plan.md) — Nunne (*susterstrate* 1361), Sauna street routes.
- [`./walls-gates-towers.md`](./walls-gates-towers.md) — 1340s west-wall incorporation around nunnery.

## Open questions

- **AWB Badpacht rows** for each plot (Nunne, Oleviste, Sauna 6–8) — downstream **R-066** folio read.
- **Rataskaevu:** confirm absence of 1340–1343 bath lease or refute secondary lists — same AWB pass.
- **GeoJSON export** of four bath footprints for `lower_town_slice` / `monastery_quarter` rrmap import — downstream **dev** task.
- **Dominican priory bath** exact south-yard footprint — needs Vene archaeology pass.

## Sources

1. Saunale.ee, "Eesti alade esimesed linnasaunad" — 14th-c. municipal baths, peripheral siting, drain practice (Estonian; cites archival tradition): https://saunale.ee/eesti-alade-esimesed-linnasaunad/
2. Ain Kübar, "Saunakultuuri tõid meile sakslased," Kristlik Mõttevõra (Estonian essay) — Stocker **1310**, Oleviste **1329**, Lübeck licensure: https://www.kristlikmottevora.ee/blogs/post/saunakultuuri-toid-meile-sakslased
3. [`../power/reval-street-cleaning-ordinances-1340s.md`](../power/reval-street-cleaning-ordinances-1340s.md) — city lease and 1225 *stupa* fine (project dossier).
4. Heinloo, "Archaeological investigations in the inner courtyard of the puppet theatre NUKU," *AVE* 2013:6 — Nunne 7 / Stocker sauna, street under-build (English/Estonian): https://arheoloogia.ee/ave2013/AVE2013_06_Heinloo_Nuku.pdf
5. Tallinn Streets, "Rataskaevu" — *dummestrate* 1328, *sub monte* 1348, hoist/well naming (English): https://tallinnstreets.com/en/rataskaevu
6. Kangropool 2003 via Heinloo 2013 — Nunne 7 sauna **1310** citation chain (Estonian archaeology tradition).
7. [`./lower-town-street-plan.md`](./lower-town-street-plan.md) — Nunne route; name post-1343 (project dossier).
8. Estonian Wikipedia, "Sauna tänav" — **1329** Uus saun at lots 6–8, ~140 m lane, MLG street names (Estonian): https://et.wikipedia.org/wiki/Sauna_t%C3%A4nav
9. [`../dailylife/hygiene-and-grooming-1343.md`](../dailylife/hygiene-and-grooming-1343.md) — Sauna street as municipal bath node (project dossier).
10. [`../religion/churches-and-religious-houses.md`](../religion/churches-and-religious-houses.md) — St Olaf quarter placement (project dossier).
11. Vaatavanalinna.ee, "The Sauna Tower" — 13th-c. circular wall and nuns' bath; stone tower **1371+**; **1422** conflict (English): https://vaatavanalinna.ee/en/sauna-tower/
12. [`../religion/ecclesiastical-precinct-boundaries-1343.md`](../religion/ecclesiastical-precinct-boundaries-1343.md) — St Michael precinct and bath zone (project dossier).
13. [`../religion/churches-and-religious-houses.md`](../religion/churches-and-religious-houses.md) — Dominican service yard (project dossier).
