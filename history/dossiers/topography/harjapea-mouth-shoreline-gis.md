---
domain: topography
slug: harjapea-mouth-shoreline-gis
status: partial
consumers: [map, dev]
related:
  - ./harbour-and-shoreline.md
  - ./kalamaja-fishing-shore-1343.md
  - ./walls-gates-towers.md
  - ./lower-town-street-plan.md
updated: 2026-08-13
---

# Härjapea mouth and 1343 shoreline GIS

## Brief for Map

You need a **bounded wet-margin polygon** for Spring 1343, not the modern engineered harbour basin. Copy **today's quay line** and you erase roughly **150–350 m** of medieval shallow water, marsh, and Härjapea delta between the wall and Lootsi/Sadama [1][2][7].

**Ship these decisions:**

1. **Coordinate system:** Author in **WGS84** (`EPSG:4326`) for interchange; the bundled GeoJSON uses the same. For `rrmap` tiling, reproject to your local metres grid with origin at the Lower Town forum — do not assume modern harbour CAD grids [project].
2. **Polygon role:** The file [`../../reference/topography/harjapea-mouth-shoreline-gis/shoreline-1343-wet-margin.geojson`](../../reference/topography/harjapea-mouth-shoreline-gis/shoreline-1343-wet-margin.geojson) marks **wet ground in April 1343** (sea, river delta, mud, reed fringe). Everything **inside the mid-1340s wall circuit** is **dry** unless a dossier flags a moat cell [3][4].
3. **Attested anchors (do not move without new archaeology):** **Lootsi 8** wreck foreshore (`59.44149°N, 24.76579°E`); **Peeter/Pikksilma** wreck foreshore (`59.44212°N, 24.78155°E`, ~895 m E of Lootsi 8) [1][5]; **Kadriorg** 14th-c. ship find east of the Hanseatic town [6]. Wet tiles must include these points.
4. **Reconstructed curve (label in UI):** Segments between anchors are **plausible composite** from 1850/1885 channel maps, post-glacial shore-displacement literature, and 19th-c. fill history — not a surveyed 1343 hydrographic chart [2][7][8].
5. **Two harbour bands inside the wet polygon:** (a) **merchant landing** below Coastal Gate / Mere–Sadama strip; (b) **Härjapea delta** at Lootsi — deeper mud, shifting sand ridges, **not** a wide navigable river under Pikk [1][4]. See [`harbour-and-shoreline.md`](./harbour-and-shoreline.md).
6. **Inland sea limit:** Künnapuu & Raukas place 13th–14th-c. open water **nearly to the modern Viru hotel / Narva Street margin** — the polygon's **southeast corner** hugs `59.43660°N, 24.75492°E` as **plausible composite**, not wreck-attested [7].
7. **Kalamaja/Kalarand:** Northwest wet beach outside Sand Gate is **plausible composite** for April 1343; toponym *Kalamaja* is later (1374) — see [`kalamaja-fishing-shore-1343.md`](./kalamaja-fishing-shore-1343.md) [9].
8. **Roadstead:** Deep water for cog grounding lies **outside** this polygon, north/northeast in open Gulf water; do not fill the whole bay with walkable mud [1][4].
9. **Confidence colouring:** Use three map material classes — `shore_attested` (wreck anchors), `shore_reconstructed` (interpolated curve), `shore_modern_fill` (post-1840 dry land — must stay **dry** in 1343 layer) [1][2].
10. **Vertical:** Lootsi wreck lay **~1.5–5 m below modern grade**; harbour ground at Coastal Gate cliff toe was **5–8 m below gate sill** — express as tile cliff/step, not a flat plaza [1][10].

## Findings

### Method and limits

No published GIS layer gives a **surveyed 1343 coastline**. This deliverable **stitches**:

| Input | What it constrains | Confidence |
|---|---|---|
| Lootsi 8 & Peeter wreck foreshores | Wet sand/mud at find spots in 14th c. | attested [1][5] |
| Roio et al. Kadriorg ship | Maritime use on shallow east strip | attested [6] |
| Tammet et al. Fig. 2 (1850 map) | Härjapea mouth position relative to modern dry land | plausible composite (map is 1850, not 1343) [1][8] |
| Nurk et al. Holocene shore displacement | Long-term emergence; Limnea stage near-modern mean sea | attested geology; **1343 offset from modern coast inferred** [2] |
| Künnapuu & Raukas | 13th–14th c. sea to Viru-hotel margin | plausible composite [7] |
| 19th-c. warehouse/rail fill at Lootsi | Lootsi dry only after ~1840–1900 | attested [1][2] |

**Regional context:** Danish crown revenue interest in trade; Hanseatic merchant landing west of delta; Livonian Order military concern at gates, not harbour administration [4][11].

### Anchor points (WGS84)

| ID | Label | Lat | Lon | 1343 role | Confidence |
|---|---|---:|---:|---|---|
| A1 | Kalarand fishing wet beach | 59.44520 | 24.73480 | Open beach / net yards | plausible composite [9] |
| A2 | Sand Gate beach toe | 59.44450 | 24.73750 | Minor boat exit | plausible composite [3] |
| A3 | Coastal Gate cliff toe | 59.44180 | 24.74850 | Merchant landing descent | plausible composite [10] |
| A4 | Mere puiestee harbour strip | 59.44320 | 24.75650 | Primary cargo interface | plausible composite [1][4] |
| A5 | **Lootsi 8 wreck** | 59.44149 | 24.76579 | Härjapea delta foreshore | attested [1] |
| A6 | **Peeter / Pikksilma wreck** | 59.44212 | 24.78155 | Delta / east foreshore | attested [1][5] |
| A7 | **Kadriorg ship find zone** | 59.43850 | 24.77800 | Shallow east grounding band | attested [6] |
| A8 | Viru-hotel inland sea limit | 59.43660 | 24.75492 | Wet margin at forum throat | plausible composite [7] |
| W1 | Wall foot NW (Coastal–Sand) | 59.44380 | 24.73950 | Dry/wet boundary on landward side | plausible composite [3] |
| W2 | Wall foot N (Pikk tail) | 59.44200 | 24.75200 | Dry/wet boundary | plausible composite [4] |
| W3 | Wall foot E (Viru apron) | 59.43646 | 24.75025 | Viru Gate dry apron | attested gate position; wet limit **uncertain** [3][7] |

Geocoded gate/wreck addresses via OpenStreetMap Nominatim (2026-07-28); wreck positions are **find-spot centroids**, not hull outlines.

### 1343 wet-margin polygon (summary)

**File:** [`shoreline-1343-wet-margin.geojson`](../../reference/topography/harjapea-mouth-shoreline-gis/shoreline-1343-wet-margin.geojson)

**Outer ring (wet side)** — vertices S1–S8 follow shore from NW to SE:

| Vertex | WGS84 (lon, lat) | Segment confidence | Notes |
|---|---|---|---|
| S1 | 24.73480, 59.44520 | plausible composite | Kalarand beach |
| S2 | 24.73750, 59.44450 | plausible composite | Sand Gate beach |
| S3 | 24.74850, 59.44180 | plausible composite | Coastal cliff toe |
| S4 | 24.75650, 59.44320 | plausible composite | Merchant harbour strip |
| S5 | 24.76579, 59.44149 | **attested** | Lootsi 8 foreshore |
| S6 | 24.78155, 59.44212 | **attested** | Peeter wreck foreshore |
| S7 | 24.77800, 59.43850 | **attested** | Kadriorg grounding band |
| S8 | 24.75492, 59.43660 | plausible composite | Viru-hotel wet limit |

**Landward closure** — wall-foot chain W1→W2→W3→S1 keeps the Lower Town dry.

**Approximate wet area:** ~0.42 km² (planimetric on WGS84, not cadastral). **Maximum inland wet extent** from Coastal Gate: ~320 m to Lootsi 8; **NE extent** to Pikksilma: ~895 m east of Lootsi 8 [1][5].

### Segment confidence map

| Shore segment | Between | Verdict | Map material |
|---|---|---|---|
| Fishing beach | S1–S2 | plausible composite | `shore_reconstructed` |
| Cliff descent | S2–S3 | plausible composite | `shore_reconstructed` |
| Merchant strip | S3–S4 | plausible composite | `shore_reconstructed` |
| Härjapea delta foreshore | S4–S5–S6 | **attested** at S5–S6; interpolated S4–S5 | `shore_attested` at anchors |
| East shallow belt | S6–S7 | attested at S7; interpolated | mixed |
| Forum-throat wet | S7–S8 | plausible composite | `shore_reconstructed` |
| Modern Lootsi/Sadama dry land | inside post-1840 fill | **must be wet in 1343 layer** | invert modern landuse |

### Härjapea channel (within polygon)

- River first named in town accounts **1363** (*Ifartjenpe*) — **name post-dates game**; channel existence **plausible composite** for 1343 [12].
- 1885 *Situationsplan* and 1850 cartography show channel entering sea at Lootsi/Sadama — used as **later comparandum** for delta axis, not exact 1343 width [8][13].
- **Do not** route a navigable river under Pikk Street to Coastal Gate [4][10].

## Production hooks

- **Map:** Import `shoreline-1343-wet-margin.geojson`; paint wet cells `water_shallow`, `mudflat`, `reed_margin` per segment confidence. **`reval_harbor_north`:** wet band from S3–S4; cliff step at W2. **`reval_harbor_east`:** S1–S2 outside Sand Gate. Block **walkable** on attested anchors only for quest salvage scenes, not the whole delta [1][4].
- **Art:** Dressing density drops with distance from S4–S5 — timber jetties at S3–S4; nets and smoke at S1; **no stone quay** along S3–S6 [4]. Plate [`topography.harjapea-mouth-shoreline-gis.02`](../../reference/topography/harjapea-mouth-shoreline-gis/topography.harjapea-mouth-shoreline-gis.02.jpg) for delta position on 1810 map.
- **Dev / systems:** Tile metadata flag `shore_confidence: attested|reconstructed`; pathfinding **shallow_water** slows movement; **deep_water** only outside polygon bounding box north [project].
- **Quest / Narrative:** Grounded cog salvage at S5; smuggler beach landings S1–S2; watch sightlines from Coastal Gate cliff (W2) across S3–S4 [4][11].

## Reference plates

| Plate | Shows | Source, date, origin | License | Answers |
|---|---|---|---|---|
| [`topography.harjapea-mouth-shoreline-gis.01`](../../reference/topography/harjapea-mouth-shoreline-gis/topography.harjapea-mouth-shoreline-gis.01.png) | Härjapea course on modern base from 1885 plan | Hannu~commonswiki after *Situationsplan der Stadt Reval* 1885 | CC BY-SA 3.0 | Delta axis at Lootsi — **late 19th-c. comparandum** |
| [`topography.harjapea-mouth-shoreline-gis.02`](../../reference/topography/harjapea-mouth-shoreline-gis/topography.harjapea-mouth-shoreline-gis.02.jpg) | Tallinn town plan extract with Toompea border | Tallinn City Archives via Wikimedia, 1810 | public domain | Wet margin east of walls vs Toompea — **not 1343 survey** |
| `topography.harjapea-mouth-shoreline-gis.03` (link-only) | Lootsi cog wreck in excavation pit | [Estonian Maritime Museum via ERR News](https://news.err.ee/1609172593/europe-s-oldest-compass-found-in-lootsi-wreck-even-older-cog-still-underground) | rights unclear; no local copy | Foreshore mud context at Lootsi anchor |
| `topography.harjapea-mouth-shoreline-gis.04` (link-only) | Lootsi wreck site on 1850 map fig. 2 | Tammet, Lätti & Heikkilä, AVE 2022:10 | scholarly | Anchor S5 on historical channel margin |
| `topography.harjapea-mouth-shoreline-gis.05` (link-only) | Holocene shore displacement around Tallinn | Nurk, Vassiljev & Saarse, Proc. Estonian Acad. Sci. 2010, Fig. 4 | scholarly | Long-term emergence context — not month-scale 1343 curve |
| [`topography.harjapea-mouth-shoreline-gis.06`](../../reference/topography/harjapea-mouth-shoreline-gis/topography.harjapea-mouth-shoreline-gis.06.jpg) | Suur Rannavärav cliff and gate alignment | Alvesgaspar Wikimedia photo, 2010 | CC BY-SA 3.0 | Cliff descent S3 — **post-medieval gate mass**; use grade only |

## Cross-references

- [`harbour-and-shoreline.md`](./harbour-and-shoreline.md) — parent harbour decisions; two-zone model; roadstead; open question on this polygon now **closed here**.
- [`kalamaja-fishing-shore-1343.md`](./kalamaja-fishing-shore-1343.md) — fishing-shore built footprint at polygon vertex S1–S2.
- [`walls-gates-towers.md`](./walls-gates-towers.md) — Coastal, Sand, and Viru gates as dry/wet boundary anchors W1–W3.
- [`lower-town-street-plan.md`](./lower-town-street-plan.md) — Pikk spine falling toward wet margin at W2.
- [`../nature/spring-climate-and-living-world.md`](../nature/spring-climate-and-living-world.md) — April ice break-up and muddy foreshore dressing on S3–S5.

## Open questions

- **Sub-metre 1343 bathymetry** inside the delta — no soundings; channel width at Lootsi remains **unknown** beyond "shallow" [1].
- **Peeter wreck hull outline** — centroid only; do not size wet polygon to hull beam [5].
- **Kadriorg find exact coordinates** — zone polygon from publication sketch only [6].
- **Monthly spring tide band** for April 1343 — not modelled; polygon is **mean wet margin** `plausible composite`.
- **GIS import to `rrmap`** — needs Dev pass to register `shore_confidence` tile property (downstream request).

## Sources

1. Tammet, Lätti & Heikkilä, "A 14th-century wreck discovered at Lootsi Street 8 in Tallinn," AVE 2022:10 — `https://www.arheoloogia.ee/ave2022/AVE2022_10.pdf` (English; local PDF).
2. Nurk, Vassiljev & Saarse, "Holocene shore displacement in the surroundings of Tallinn," Proc. Estonian Acad. Sci. Geol. 59(3), 2010 — `https://doi.org/10.3176/earth.2010.3.03` (English).
3. [`walls-gates-towers.md`](./walls-gates-towers.md) — gate positions and 1343 circuit (project dossier).
4. [`harbour-and-shoreline.md`](./harbour-and-shoreline.md) — harbour zones, quay practice, Härjapea mouth (project dossier).
5. Roio et al., Peeter wreck Pikksilma 2/1 — cited in [1]; ~800 m from Lootsi 8 (English/Estonian).
6. Roio et al., medieval ship east of Tallinn, AVE 2015 — `history/AVE2015_15_Roiojt_Kadriorg.pdf` (Estonian).
7. Künnapuu & Raukas via Kask, coast development Tallinn area — `https://doi.org/10.3176/geol.2005.2.04` (English) — 13th–14th c. sea to Viru margin.
8. Tammet et al. [1], Fig. 2 — 1850 map wreck position (Estonian/English).
9. [`kalamaja-fishing-shore-1343.md`](./kalamaja-fishing-shore-1343.md) — Kalarand attestation band (project dossier).
10. Reppo & Kadakas, Coastal Gate excavations — `history/AVE2019_15_Reppo-Kadakas.pdf` (Estonian).
11. [`../power/jurisdictions-of-reval.md`](../power/jurisdictions-of-reval.md) — harbour jurisdiction seams (project dossier).
12. WeskiWiki / city accounts — Härjapea first named **1363** (*Ifartjenpe*) — `https://www.weskiwiki.ee/index.php/Härjapea_jõgi` (Estonian); name post-1343.
13. Wikimedia, Härjapea River.svg after 1885 plan — `https://commons.wikimedia.org/wiki/File:Härjapea_River.svg` (public domain).
