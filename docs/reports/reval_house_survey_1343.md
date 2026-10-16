# Reval house-by-house survey - which buildings stood in spring 1343

Status: research report, 2026-10-16 (maintainer request: walk every Old Town street, find which houses existed during the game, model those as bespoke historical buildings and leave the rest generic). Not reviewed by the Canon Keeper yet.
Scope: every protected building (*ehitismälestis*) of the Tallinn Old Town in the national register of cultural monuments, plus plots named in Estonian Wikipedia street articles and project dossiers, with a 1343 verdict and a modelling recommendation. Out of scope: churches, convents and gates already covered by [Landmark sites in the seamless city](../SYSTEMS/CITY_LANDMARK_SITES.md) (they appear here only as one-line pointers), walls and towers (see that page's gate and tower sections), and any map, code or asset change.

## Decision brief

1. **No private house survives in its 1343 form.** Vaga's study of the medieval Reval dwelling puts every surviving house in the period that starts in the early 15th century; houses built before then were different: a **stone store building separate from the dwelling**, the dwelling often of timber, lower, probably without the tall gable, and **not built wall to wall** (drip gaps and gate gaps between plots) [V]. The tourist icons (Peppersack, Olde Hansa, Three Sisters, Great Guild, Blackheads, Town Hall Pharmacy) are all later and stay out of the 1343 city.
2. **Only a handful of plots carry evidence of a building in April 1343.** Of 119 surveyed buildings and plots: **10 standing** in 1343 (most already landmark sites), **18 with a 14th-century predecessor of unknown decade or a plot attested by 1343**, **22 first recorded later in the 14th century**, **69 with no 14th-century building evidence**.
3. **New bespoke candidates** (beyond the existing site catalogue), each with its own dossier:

| Rank | Building | Verdict | Confidence | Why |
|---|---|---|---|---|
| 1 | [St Canute's guild house, Pikk 20](../../history/dossiers/architecture/buildings/st-canute-guild-house-pikk-20.md) | standing (house held from 1326) | attested | Kalev's guild; its Estonian members left after the 1343 uprising; task R-1987 already places it |
| 2 | [St Olaf's guild house, Pikk 24](../../history/dossiers/architecture/buildings/st-olaf-guild-house-pikk-24.md) | standing (guild 1341, house 14th c.) | attested by century | evening venue already used by the social-life slice; Estonian-German tension |
| 3 | [Cistercian town courts on Vene street](../../history/dossiers/architecture/buildings/vene-street-cistercian-town-courts.md) (Kärkna, Roma, Padise) | standing (plots attested 1259-c. 1280) | plausible composite for 1343 | Padise's Reval office when Padise is sacked on St George's Night; "monks' street" identity |
| 4 | [Vene 17 early stone house](../../history/dossiers/architecture/buildings/vene-17-early-stone-house.md) | standing (first half 14th c.) | plausible composite | the best surviving evidence of a private stone house of the period |
| 5 | [Kohtu 12 tower house, Toompea](../../history/dossiers/architecture/buildings/kohtu-12-toompea-tower-house.md) | predecessor (14th c. tower core) | plausible composite | one evidence-based vassal *curia* silhouette for the Danish hill |
| 6 | [Raekoja plats 18 tower house](../../history/dossiers/architecture/buildings/raekoja-plats-18-tower-house.md) | predecessor (14th c. tower; shops only recorded 1367) | plausible composite | a tall stone corner on the market edge with booths |

4. **The two named examples:** [Peppersack](../../history/dossiers/architecture/buildings/peppersack-plot-vana-turg-6.md) (Vana turg 6) is a 1420-1460 house; a **14th-century timber house** (decade unknown, stone footings survive) preceded it, so the plausible 1343 state is a timber house. [Olde Hansa](../../history/dossiers/architecture/buildings/olde-hansa-plot-vana-turg-1.md) (Vana turg 1) is the 1655-56 packhouse; the plot's first stone warehouse is from the second half of the 14th century. Both plots stay **generic**.
5. **Conflicts found in existing docs and tasks** (for follow-up, not changed here):
   - [`docs/TOURIST_LANDMARKS.md`](../TOURIST_LANDMARKS.md) row 19 says the Town Hall Pharmacy is "a respected apothecary shop" in 1343; the pharmacy is first named **1422** and the small weigh house on its site **1358** [R1197].
   - Board tasks **R-1120 / R-1196** ("Great Guild 1343 exterior") contradict the catalogue's "do not build" row: the Great Guild hall is **1407-10** [R3037]; the guild met elsewhere in 1343.
   - The [Holy Spirit site page](../SYSTEMS/landmark_sites/holy_spirit.md) has the 1334 almshouse but not the **west range of Pühavaimu 6, built 1341-1350 on a plot bought in 1338** [R3057]: in April 1343 it is a building site.
   - Vaga reads the 1312-1360 property books as showing **stone houses already predominant** in the first half of the 14th century [V], while [Pikk and Lai frontage materials](../../history/dossiers/topography/pikk-lai-frontage-materials-1340s.md) sets a timber-dominant default. The two can both hold if "stone house" in the books often means the separate stone store; the Canon Keeper should decide which reading the frontage weights follow.

## Method and sources

- **Walking list:** the street list of Russian Wikipedia ["Старый город (Таллин)"](https://ru.wikipedia.org/wiki/Старый_город_(Таллин)) (10 Upper Town and 47 Lower Town streets), cross-read with the Estonian Wikipedia article of each street (77 pages, house sections and register links).
- **Per-house evidence:** every Old Town building monument in the register block 2997-3105 plus the numbers linked from the street articles (153 records read, 119 buildings and plots kept after removing movables, sites outside the Old Town and 20th-century buildings). The register's *Ajalugu* (history) and *Kirjeldus* (description) give first mentions, dendro dates and the oldest fabric. Register titles such as "14.-20. saj" are **not** taken at face value: Pühavaimu 13 is titled "14.-20. saj" but first named in 1464.
- **Verdict words:** `standing` = a building on the plot is attested by April 1343 or its oldest fabric is dated into a window that includes 1343; `predecessor` = a 14th-century building of unknown decade, or the plot attested by 1343 without a described building; `later` = the first building record is after 1343; `none` = no 14th-century building in the register text. Confidence words follow [CANON](../CANON.md).
- **Recommendation words:** **bespoke** = its own landmark site; **simplified bespoke** = a distinct model of the simplified documented form (period rule); **generic plot** = the ordinary house generator, optionally with a stone or timber flag from the evidence column.

| ID | Source | Use | Limits |
|---|---|---|---|
| R + number | Kultuurimälestiste register, https://register.muinas.ee/public.php?menuID=monument&action=view&id=NUMBER, read 2026-10-16 | per-house history and fabric dates | heritage-protection summaries, not building surveys; few dendro dates |
| V | V. Vaga, "Tallinna keskaegne elamu", *Eesti NSV ajaloo küsimusi* 87, Tartu 1960, pp. 42-54, https://dspace.ut.ee/server/api/core/bitstreams/05ef3b62-a491-4864-b6bc-aa5708ff6cb9/content | the pre-1400 house pattern | 1960 synthesis; no excavation data after 1960 |
| ETW | Estonian Wikipedia street and building articles (2026 revisions) | walking list, first mentions | tertiary pointers |
| VHK | Vanalinna Hariduskolleegium, "Kloostrikinnistutest Vene tänaval", 2024, after Kangropool and Kuuskemaa, https://vhk.ee/et/node/113 | Vene street abbey courts | secondary synthesis |
| MKA | Muinsuskaitseamet, Tallinn Old Town building inventory report (2022-2023), https://www.muinsuskaitseamet.ee/sites/default/files/documents/2024-02/Tallinna%20vanalinna%20muinsuskaitseala%20inventeerimisaruanne.pdf | completeness check of the building list | protection categories, not dating |

Limits: houses that are not register monuments (most of the A/B/C category buildings in the MKA inventory) have no register history card, so they are not listed one by one; treat them as generic plots unless a dossier says otherwise. The Wikipedia API rate-limited the first pass (HTTP 429), so street pages were read as HTML.

## Already covered landmark sites

Town Hall, Holy Spirit, St Olaf, St Nicholas, St Mary, St Catherine, St Michael and Kalev's smithy are built sites; the Danish castle, the bishop's court and vassal houses, the guild houses, St John's leper hospital, gates and towers are pending or proposed in [Landmark sites in the seamless city](../SYSTEMS/CITY_LANDMARK_SITES.md). This survey adds evidence to that page and does not repeat it.

## Lower Town

### Landmarks, institutions and fortifications

| Address | Reg. no. | 1343 verdict | Confidence | Evidence | Recommendation |
|---|---|---|---|---|---|
| Toompea castle ring wall | [2997](https://register.muinas.ee/public.php?menuID=monument&action=view&id=2997) | standing | attested | stone castle 13th c.; rebuilding from the 2nd quarter of the 14th c.; south forecourt ring and Pikk Hermann from mid-14th c. | pending castle site (R-1462) |
| Lossi plats 1a (Toompea castle) | [1101](https://register.muinas.ee/public.php?menuID=monument&action=view&id=1101) | standing | attested | castle improved by the Order and the Danish king in the 13th and early 14th c. | pending castle site (R-1462) |
| Raekoja plats 1 (Town Hall) | [1199](https://register.muinas.ee/public.php?menuID=monument&action=view&id=1199) | standing | attested | stone building on the site c. 1250; consistorium and cellar 1322 | built [`site.raekoja_plats`](../SYSTEMS/landmark_sites/raekoja_plats.md) |
| Pühavaimu 6 (Holy Spirit almshouse) | [3057](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3057) | standing | attested | almshouse named 1334; plot bought 1338; west range of Pühavaimu 6 built 1341-1350 (building site in April 1343) | part of [`site.holy_spirit`](../SYSTEMS/landmark_sites/holy_spirit.md); add the 1341-50 range as a building site |
| Vene 16-18 (St Catherine's friary) | [1245](https://register.muinas.ee/public.php?menuID=monument&action=view&id=1245) | standing | attested | founded 1246; stone buildings from the later 13th and early 14th c. | built [`site.st_catherine`](../SYSTEMS/landmark_sites/st_catherine.md) |
| Pikk 20 (St Canute's guild) | [8519](https://register.muinas.ee/public.php?menuID=monument&action=view&id=8519) | standing | attested | guild house on the plot from 1326 (a third of today's site); great hall 1470s; front 1863-64 | **bespoke** (R-1987) - [dossier](../../history/dossiers/architecture/buildings/st-canute-guild-house-pikk-20.md) |
| Pikk 24 (St Olaf's guild) // Pikk 26 | [3040](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3040) | standing | attested | guild first named 1341 and held a house on the plot in the 14th c.; hall rebuilt 1419-22; Blackheads only from 1399/1517 | **bespoke** - [dossier](../../history/dossiers/architecture/buildings/st-olaf-guild-house-pikk-24.md) |
| Pikk 71 // Tolli 2 (Three Sisters) | [3054](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3054) | predecessor | plausible composite | buildings on the plot named in the 14th c.; owners from 1372; present houses 15th c. | generic plot |
| Town chancery | [3067](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3067) | later | attested | first named 1378 | exclude |
| Raekoja 6 (town prison) | [3061](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3061) | later | attested | prison built 1370 | exclude |
| Raekoja plats 11 (Town Hall Pharmacy) | [1197](https://register.muinas.ee/public.php?menuID=monument&action=view&id=1197) | later | attested | small weigh house named 1358; pharmacy first named 1422 | generic plot; no apothecary in 1343 |
| Pikk 17 (Great Guild hall) | [3037](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3037) | later | attested | guild c. 1325, but the hall is 1407-1410 | exclude the hall; generic plot |
| Lai 47 (horse mill) | [3034](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3034) | later | attested | first named 1379 | exclude |
| Toompea komandandi maja | [3011](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3011) | none | unknown | fabric dated 17.-19.saj.; no 14th-c. building recorded | generic plot |

### Aida

| Address | Reg. no. | 1343 verdict | Confidence | Evidence | Recommendation |
|---|---|---|---|---|---|
| Aida 3 | [3016](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3016) | none | unknown | fabric dated 1692. a, 1823. a, 1974.-1980. a; no 14th-c. building recorded | generic plot |
| Aida 6 | [3017](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3017) | none | unknown | fabric dated 15.saj.,1551.a., 1723.a., 1967.a.; no 14th-c. building recorded | generic plot |

### Dunkri

| Address | Reg. no. | 1343 verdict | Confidence | Evidence | Recommendation |
|---|---|---|---|---|---|
| Dunkri 6 | [3018](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3018) | later | attested | 'Soest' tavern on the plot 1362; stone dwelling 1388 | generic plot |

### Ehisseinaga

| Address | Reg. no. | 1343 verdict | Confidence | Evidence | Recommendation |
|---|---|---|---|---|---|
| Ehisseinaga ja aknakonstruktsioon Kinga 7 // Pikk 4 | [8148](https://register.muinas.ee/public.php?menuID=monument&action=view&id=8148) | none | unknown | fabric dated 6, 8, 16. saj.; no 14th-c. building recorded | generic plot |

### Hobusepea

| Address | Reg. no. | 1343 verdict | Confidence | Evidence | Recommendation |
|---|---|---|---|---|---|
| Hobusepea 12 | [3019](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3019) | none | unknown | fabric dated 15.saj., 19.saj.; no 14th-c. building recorded | generic plot |

### Kinga

| Address | Reg. no. | 1343 verdict | Confidence | Evidence | Recommendation |
|---|---|---|---|---|---|
| Kinga 10 // Pikk 10 | [3020](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3020) | predecessor | plausible composite | building of the 14th c.; only medieval face in its block | generic plot (stone flag) |

### Kuninga

| Address | Reg. no. | 1343 verdict | Confidence | Evidence | Recommendation |
|---|---|---|---|---|---|
| Kuninga 1 | [3021](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3021) | predecessor | attested | plot first named 1339 | generic plot |
| Kuninga 3 | [3022](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3022) | predecessor | plausible composite | stone dwelling first named in the mid-14th c. | generic plot (stone flag) |
| Kuninga 6 | [3023](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3023) | later | attested | stone dwelling first named 1373 | generic plot |

### Lai

| Address | Reg. no. | 1343 verdict | Confidence | Evidence | Recommendation |
|---|---|---|---|---|---|
| Lai 37 | [3031](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3031) | later | attested | St Olaf's parsonage on the plot 1367 | generic plot |
| Lai 5 | [3024](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3024) | none | unknown | fabric dated 15.-20.saj.; no 14th-c. building recorded | generic plot |
| Lai 17 | [3025](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3025) | none | unknown | fabric dated 1680.a., 1887.a.; no 14th-c. building recorded | generic plot |
| Lai 21 | [3026](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3026) | none | unknown | fabric dated 1772.a.-20.saj.; no 14th-c. building recorded | generic plot |
| Lai 23 | [3027](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3027) | none | unknown | register title dates the complex '14.-20.saj.', but its history names no building before 1400 | generic plot |
| Lai 29 | [3028](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3028) | none | unknown | fabric dated 15. saj, 18. saj, 20. saj; no 14th-c. building recorded | generic plot |
| Lai 32 | [3029](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3029) | none | unknown | fabric dated 15.-19.saj.; no 14th-c. building recorded | generic plot |
| Lai 35 | [3030](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3030) | none | unknown | fabric dated 15.-19.saj.; no 14th-c. building recorded | generic plot |
| Lai 40 | [3032](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3032) | none | unknown | fabric dated 15.-19.saj.; no 14th-c. building recorded | generic plot |
| Lai 45 | [3033](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3033) | none | unknown | fabric dated 15.-18.saj., 1924.a.; no 14th-c. building recorded | generic plot |

### Other

| Address | Reg. no. | 1343 verdict | Confidence | Evidence | Recommendation |
|---|---|---|---|---|---|
| apteegiga Vana-Viru 15 välistrepi piirdega | [24240](https://register.muinas.ee/public.php?menuID=monument&action=view&id=24240) | none | unknown | fabric dated later; no 14th-c. building recorded | generic plot |
| fassaad ja historitsistlikud interjöörid Pikk 16 // Pühavaimu 1 | [8518](https://register.muinas.ee/public.php?menuID=monument&action=view&id=8518) | none | unknown | fabric dated 1876. a.; no 14th-c. building recorded | generic plot |

### Pikk

| Address | Reg. no. | 1343 verdict | Confidence | Evidence | Recommendation |
|---|---|---|---|---|---|
| Pikk 7 | [3035](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3035) | predecessor | plausible composite | small one-room stone house in the yard in the 14th c. | generic plot (stone rear house) |
| Pikk 18 // Pühavaimu 3 | [3038](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3038) | predecessor | plausible composite | stone warehouse with cellar in the 14th c. | generic plot (stone warehouse) |
| Pikk 19 | [3039](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3039) | predecessor | plausible composite | stone dwelling named in the 14th c.; block plots formed in the 13th c. | generic plot (stone flag) |
| Pikk 37 | - | predecessor | attested | oldest written data on the plot 1335 (Estonian Wikipedia) | generic plot |
| Pikk 43 | [3045](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3045) | predecessor | attested | plot named early 14th c.; building first named 1380; roof dendro 1434 | generic plot |
| Pikk 69 | [3053](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3053) | predecessor | plausible composite | corner house named in the oldest property books; owner by 1364 | generic plot (stone flag) |
| Pikk 34 | [3044](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3044) | later | attested | first building data from the late 14th c. | generic plot |
| Pikk 55 | [3050](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3050) | later | attested | building first named 1365 | generic plot |
| Pikk 66 | [3052](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3052) | later | attested | house, warehouse and gateway built in the late 14th c. | generic plot |
| Pikk 15 | [3036](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3036) | none | unknown | fabric dated 15.-20.saj.; no 14th-c. building recorded | generic plot |
| Pikk 28 | [3041](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3041) | none | unknown | fabric dated 1670.a., 19.-20.saj.; no 14th-c. building recorded | generic plot |
| Pikk 29a | [3042](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3042) | none | unknown | fabric dated 15.-20. saj; no 14th-c. building recorded | generic plot |
| Pikk 30 | [8520](https://register.muinas.ee/public.php?menuID=monument&action=view&id=8520) | none | unknown | fabric dated 15.-19. saj.; no 14th-c. building recorded | generic plot |
| Pikk 33 ja Lai 30 | [3043](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3043) | none | unknown | fabric dated 15.-20.saj.; no 14th-c. building recorded | generic plot |
| Pikk 44 | [3046](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3046) | none | unknown | fabric dated 15.-19.saj.; no 14th-c. building recorded | generic plot |
| Pikk 46 | [3047](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3047) | none | unknown | fabric dated 15.-20.saj.; no 14th-c. building recorded | generic plot |
| Pikk 47 | [3048](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3048) | none | unknown | fabric dated 15.-20.saj.; no 14th-c. building recorded | generic plot |
| Pikk 51 | [3049](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3049) | none | unknown | fabric dated 15.-20.saj.; no 14th-c. building recorded | generic plot |
| Pikk 60 | [3051](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3051) | none | unknown | fabric dated 15.-19.saj.; no 14th-c. building recorded | generic plot |
| Pikk tn. 68 | [24239](https://register.muinas.ee/public.php?menuID=monument&action=view&id=24239) | none | unknown | fabric dated later; no 14th-c. building recorded | generic plot |

### Pühavaimu

| Address | Reg. no. | 1343 verdict | Confidence | Evidence | Recommendation |
|---|---|---|---|---|---|
| Pühavaimu 13 | [3058](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3058) | later | attested | two medieval warehouses joined; first named 1464 (the register title's '14. saj' is not borne out) | generic plot |
| Pühavaimu 15 | [3059](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3059) | none | unknown | fabric dated 15.-17.saj.; no 14th-c. building recorded | generic plot |

### Raekoja

| Address | Reg. no. | 1343 verdict | Confidence | Evidence | Recommendation |
|---|---|---|---|---|---|
| Raekoja 4 | [3060](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3060) | later | attested | plot traced 1360; small stone house city-owned by 1386 | generic plot |

### Raekoja plats

| Address | Reg. no. | 1343 verdict | Confidence | Evidence | Recommendation |
|---|---|---|---|---|---|
| Raekoja plats 12 | [3065](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3065) | predecessor | plausible composite | oldest constructions dated to the 14th c. | generic plot (stone flag) |
| Raekoja plats 18 // Vanaturu kael 3 | [3070](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3070) | predecessor | plausible composite | later merchant house built around a small multi-storey 14th-c. tower house; 1367 dwelling and three shops | **simplified bespoke** - [dossier](../../history/dossiers/architecture/buildings/raekoja-plats-18-tower-house.md) |
| Raekoja plats 5 | [3063](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3063) | later | attested | stone house first named 1366 | generic plot |
| Raekoja plats 13 | [3066](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3066) | later | attested | first building data 1369 | generic plot |
| Raekoja plats 4 | [3062](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3062) | none | unknown | fabric dated 15.-18.saj.; no 14th-c. building recorded | generic plot |
| Raekoja plats 10 | [3064](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3064) | none | unknown | fabric dated 18.saj.; no 14th-c. building recorded | generic plot |
| Raekoja plats 14 ja Vene 5 | [22251](https://register.muinas.ee/public.php?menuID=monument&action=view&id=22251) | none | unknown | fabric dated 18.-19. saj; no 14th-c. building recorded | generic plot |
| Raekoja plats 16 fassaad | [3068](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3068) | none | unknown | fabric dated 15.-19. saj; no 14th-c. building recorded | generic plot |
| Raekoja plats 17 fassaad | [3069](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3069) | none | unknown | fabric dated 18.-20.saj.; no 14th-c. building recorded | generic plot |

### Rataskaevu

| Address | Reg. no. | 1343 verdict | Confidence | Evidence | Recommendation |
|---|---|---|---|---|---|
| Rataskaevu 8 | [3071](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3071) | later | plausible composite | probably built late 14th or early 15th c. | generic plot |
| Rataskaevu 16 | [3073](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3073) | later | attested | dwelling first named in the last quarter of the 14th c. | generic plot |
| Rataskaevu 14 | [3072](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3072) | none | unknown | fabric dated 15.-20.saj.; no 14th-c. building recorded | generic plot |

### Rüütli

| Address | Reg. no. | 1343 verdict | Confidence | Evidence | Recommendation |
|---|---|---|---|---|---|
| Rüütli 2 | [3074](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3074) | predecessor | plausible composite | corner plot named 1361; oldest cellar walls probably 14th c. | generic plot |
| Rüütli 12 | [3075](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3075) | predecessor | attested | small timber house with a cellar in the 14th c. | generic plot (timber) |
| Rüütli 12a | [3076](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3076) | later | attested | two small houses finished by the end of the 14th c. | generic plot |

### Saiakang

| Address | Reg. no. | 1343 verdict | Confidence | Evidence | Recommendation |
|---|---|---|---|---|---|
| Saiakang 4 | [3077](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3077) | none | unknown | fabric dated 1656.a.-20.saj.; no 14th-c. building recorded | generic plot |

### Sauna

| Address | Reg. no. | 1343 verdict | Confidence | Evidence | Recommendation |
|---|---|---|---|---|---|
| Sauna 4 | [3078](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3078) | none | unknown | fabric dated 15.-18. saj; no 14th-c. building recorded | generic plot |
| Sauna 6 | [3079](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3079) | none | unknown | fabric dated later; no 14th-c. building recorded | generic plot |
| Sauna 8 | [3080](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3080) | none | unknown | fabric dated 15.-19.saj.; no 14th-c. building recorded | generic plot |
| Sauna 10 | [3081](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3081) | none | unknown | fabric dated 15.-20.saj.; no 14th-c. building recorded | generic plot |

### Suur-Karja

| Address | Reg. no. | 1343 verdict | Confidence | Evidence | Recommendation |
|---|---|---|---|---|---|
| Suur-Karja 1 | [3082](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3082) | none | unknown | fabric dated 1904.a., 1924.a.; no 14th-c. building recorded | generic plot |
| Suur-Karja 8 | [3083](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3083) | none | unknown | fabric dated 15.-20.saj.; no 14th-c. building recorded | generic plot |
| Suur-Karja 12 | [3084](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3084) | none | unknown | fabric dated 15.saj.; no 14th-c. building recorded | generic plot |
| Suur-Karja 18 fassaad | [3085](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3085) | none | unknown | fabric dated 1923.a.; no 14th-c. building recorded | generic plot |

### Tallinna

| Address | Reg. no. | 1343 verdict | Confidence | Evidence | Recommendation |
|---|---|---|---|---|---|
| Tallinna Kanuti gildi hoone | [8519](https://register.muinas.ee/public.php?menuID=monument&action=view&id=8519) | none | unknown | fabric dated 1863. a.; no 14th-c. building recorded | generic plot |

### Tolli

| Address | Reg. no. | 1343 verdict | Confidence | Evidence | Recommendation |
|---|---|---|---|---|---|
| Tolli 3 | [3086](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3086) | none | unknown | fabric dated 17.-20.saj.; no 14th-c. building recorded | generic plot |
| Tolli 4 | [3087](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3087) | none | unknown | fabric dated 15.-20.saj.; no 14th-c. building recorded | generic plot |
| Tolli 6 | [3088](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3088) | none | unknown | fabric dated 15.-20.saj.; no 14th-c. building recorded | generic plot |

### Uus

| Address | Reg. no. | 1343 verdict | Confidence | Evidence | Recommendation |
|---|---|---|---|---|---|
| Uus 10 fassaad | [3089](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3089) | none | unknown | fabric dated 1791.a.; no 14th-c. building recorded | generic plot |
| Uus 15 | [3090](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3090) | none | unknown | fabric dated 1751.a., 20.saj.; no 14th-c. building recorded | generic plot |
| Uus 27 ja Olevimägi 13 | [3091](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3091) | none | unknown | fabric dated 19.saj.; no 14th-c. building recorded | generic plot |

### Valli

| Address | Reg. no. | 1343 verdict | Confidence | Evidence | Recommendation |
|---|---|---|---|---|---|
| Valli baari interjöörid | [28313](https://register.muinas.ee/public.php?menuID=monument&action=view&id=28313) | none | unknown | fabric dated later; no 14th-c. building recorded | generic plot |

### Vana turg

| Address | Reg. no. | 1343 verdict | Confidence | Evidence | Recommendation |
|---|---|---|---|---|---|
| Vana turg 6 // Viru 2 (Peppersack) | [3097](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3097) | predecessor | plausible composite | a 14th-c. timber house with stone footings preceded the 1420-1460 stone house | generic plot, timber house - [verdict note](../../history/dossiers/architecture/buildings/peppersack-plot-vana-turg-6.md) |
| Vana turg 1 (Olde Hansa) | [3096](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3096) | later | attested | stone warehouse on the plot only from the second half of the 14th c.; present packhouse 1655-56 | generic plot - [verdict note](../../history/dossiers/architecture/buildings/olde-hansa-plot-vana-turg-1.md) |

### Vene

| Address | Reg. no. | 1343 verdict | Confidence | Evidence | Recommendation |
|---|---|---|---|---|---|
| Vene 15 // Pühavaimu 8 (Kärkna abbey court) | - | standing | plausible composite (plot attested 1259, c. 1280) | two barns on the Kärkna Cistercian plot 1259; abbey curia taxed c. 1280 | **simplified bespoke** group - [dossier](../../history/dossiers/architecture/buildings/vene-street-cistercian-town-courts.md) |
| Vene 17 | [3102](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3102) | standing | plausible composite | one-room stone house, probably first half of 14th c., survives under the dornse; plot built 1363 | **bespoke** - [dossier](../../history/dossiers/architecture/buildings/vene-17-early-stone-house.md) |
| Vene 20-22 (Roma and Padise abbey courts) | - | standing | plausible composite | Roma (Gotland) court 1259-1519; neighbouring Dünamünde court passed to Padise (founded 1305) | **simplified bespoke** group - [dossier](../../history/dossiers/architecture/buildings/vene-street-cistercian-town-courts.md) |
| Vene 5 // Raekoja plats 14 | [3472](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3472) | predecessor | attested | oldest record of the plot 1333 (Estonian Wikipedia); present facades 18th-19th c. | generic plot |
| Vene 25 | [3104](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3104) | predecessor | plausible composite | first data on the plot from the 14th c. | generic plot |
| Vene 10 | [3100](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3100) | later | attested | dwelling first named 1374 | generic plot |
| Vene 27 | [3105](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3105) | later | plausible composite | probably built as a warehouse in the second half of the 14th c. | generic plot |
| Vene 6 | [3099](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3099) | none | unknown | register title dates the complex '14.-20.saj.', but its history names no building before 1400 | generic plot |
| Vene 12 | [3101](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3101) | none | unknown | fabric dated 15.-20.saj.; no 14th-c. building recorded | generic plot |
| Vene 23 | [3103](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3103) | none | unknown | fabric dated later; no 14th-c. building recorded | generic plot |

### Viru

| Address | Reg. no. | 1343 verdict | Confidence | Evidence | Recommendation |
|---|---|---|---|---|---|
| Viru 20 | [3098](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3098) | later | attested | dwelling first named 1398 | generic plot |

## Toompea

### Kiriku

| Address | Reg. no. | 1343 verdict | Confidence | Evidence | Recommendation |
|---|---|---|---|---|---|
| Kiriku 2 | [2998](https://register.muinas.ee/public.php?menuID=monument&action=view&id=2998) | none | unknown | fabric dated 18.-19. saj; no 14th-c. building recorded | generic plot |
| Kiriku 6 | [2999](https://register.muinas.ee/public.php?menuID=monument&action=view&id=2999) | none | unknown | fabric dated 17.-20.saj.; no 14th-c. building recorded | generic plot |

### Kohtu

| Address | Reg. no. | 1343 verdict | Confidence | Evidence | Recommendation |
|---|---|---|---|---|---|
| Kohtu 12 | [3002](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3002) | predecessor | plausible composite | square massive walls of a tower-like core, probably 14th c. | **simplified bespoke** - [dossier](../../history/dossiers/architecture/buildings/kohtu-12-toompea-tower-house.md) |
| Kohtu 2 | [3000](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3000) | none | unknown | fabric dated 1798.a.; no 14th-c. building recorded | generic plot |
| Kohtu 8 | [3001](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3001) | none | unknown | fabric dated 1809.a., 1927.a.; no 14th-c. building recorded | generic plot |

### Lossi plats

| Address | Reg. no. | 1343 verdict | Confidence | Evidence | Recommendation |
|---|---|---|---|---|---|
| Lossi plats 2 | [3003](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3003) | none | unknown | fabric dated 17.saj.-1911.a.; no 14th-c. building recorded | generic plot |
| Lossi plats 3 | [3004](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3004) | none | unknown | fabric dated 18.saj.; no 14th-c. building recorded | generic plot |
| Lossi plats 4 | [3005](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3005) | none | unknown | fabric dated 17.-19.saj.; no 14th-c. building recorded | generic plot |
| Lossi plats 5 | [3006](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3006) | none | unknown | fabric dated 17.-18.saj.; no 14th-c. building recorded | generic plot |
| Lossi plats 6 | [3007](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3007) | none | unknown | fabric dated 18.saj.; no 14th-c. building recorded | generic plot |

### Rahukohtu

| Address | Reg. no. | 1343 verdict | Confidence | Evidence | Recommendation |
|---|---|---|---|---|---|
| Rahukohtu 1 | [3012](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3012) | none | unknown | fabric dated 17.-20.saj.; no 14th-c. building recorded | generic plot |
| Rahukohtu 3 | [3013](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3013) | none | unknown | fabric dated 1787-1792. a; no 14th-c. building recorded | generic plot |
| Rahukohtu 4 | [3014](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3014) | none | unknown | fabric dated 17.-20.saj.; no 14th-c. building recorded | generic plot |

### Toom-Kooli

| Address | Reg. no. | 1343 verdict | Confidence | Evidence | Recommendation |
|---|---|---|---|---|---|
| Toom-Kooli 3 | [3008](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3008) | none | unknown | fabric dated 17.-20. saj; no 14th-c. building recorded | generic plot |
| Toom-Kooli 7 | [3009](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3009) | none | unknown | fabric dated 15.-18. saj; no 14th-c. building recorded | generic plot |
| Toom-Kooli 21 | [3010](https://register.muinas.ee/public.php?menuID=monument&action=view&id=3010) | none | unknown | fabric dated 17.-20.saj.; no 14th-c. building recorded | generic plot |

## Follow-up

Board epic **R-2164 / HH-0** (historical houses pack). The candidates are listed as **proposed** sites on [Landmark sites in the seamless city](../SYSTEMS/CITY_LANDMARK_SITES.md); builds need maintainer approval.

| Task | Work |
|---|---|
| R-2165 / HH-1 | Canon Keeper review of this survey and the dossiers (verdict words, stone-versus-timber reading); gates the builds |
| R-2166 / HH-2 | Fix the conflicts in decision brief item 5 (Town Hall Pharmacy row, Great Guild tasks R-1120 / R-1196, St Olaf's "house from 1341") |
| R-2167 / HH-3 | Vene street Cistercian town courts |
| R-2168 / HH-4 | Vene 17 early stone house |
| R-2169 / HH-5 | Kohtu 12 tower house |
| R-2170 / HH-6 | Raekoja plats 18 tower house |
| R-2171 / HH-7 | St Olaf's guild house (St Canute's is R-1987 / SOC-5) |
| R-2172 / HH-8 | Holy Spirit almshouse range of 1341-1350 as a building site |

Not tasked yet: flagging the `predecessor` plots in the city plan as stone or timber fronts so generic houses follow the evidence column.
