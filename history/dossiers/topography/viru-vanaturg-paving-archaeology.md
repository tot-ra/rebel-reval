---
domain: topography
slug: viru-vanaturg-paving-archaeology
status: partial
consumers: [map, art, dev]
related:
  - ./old-market-vanaturg.md
  - ./raekoja-plats-extents-1343.md
  - ./walls-gates-towers.md
  - ./lower-town-street-plan.md
updated: 2026-07-28
---

# Viru–Vanaturg paving and gate-apron surfaces (c. 1340)

## Brief for Map

You are surfacing the **east civic approach** from Raekoja *forum* through Vanaturu kael to the Viru Gate apron. Kraut & Nurk (AVE 2016/17) documents what survives under the 2015–16 pedestrian-zone rebuild; this dossier translates that into **1343 ground tiles**, not modern granite pavers [1].

**Ship these decisions:**

1. **Forum interior** (`raekoja-plats-extents-1343`): predominantly **packed earth / patch limestone** — not a uniform stone plaza [2][3].
2. **Vanaturu kael (forum SE → Viru/Vene junction):** **4–6 m** through-lane; surface = **mixed pebble and localized limestone slabs** on darkened sand occupation layers — **plausible composite**; no attested full-width slab carpet in 2016 trenches [1][4].
3. **Kuninga / southern Vana turg frontage:** **attested partial** — limestone slab hints at **~1–2 m** below present grade (Kuninga 3, Kuninga 1/2); treat as **buried 13th–14th-c. occupation horizon**, not guaranteed visible wear in 1343 gameplay unless excavated [1].
4. **Viru Street west of junction (toward Müürivahe):** **humus-rich layers**, sporadic earlier structures; **no mapped slab continuum** — default **cobble/pebble band** with mud margins [1][3].
5. **Viru Gate apron (inside wall, east of Müürivahe crossing):** main gate tower **mid-14th-c.**; **moat in front of tower** in early phase; **wooden plank pavement** on moat fill ~1.7 m below present surface; **small cobble fragment** inside tower gateway ~1 m below present surface = probable **post-completion street level** [1][5]. **No 15th-c. barbican pavements**, no foregate towers, no zwinger [1][5].
6. **Elevation:** medieval street at gate complex was only **~1 m below** present Viru pavement at final medieval phase — April 1343 may be **0.5–1 m lower still** if gate/moat works ongoing [1].
7. **Exclude:** 19th–20th-c. timber water pipes, limestone vaulted collectors, 2016 granite pedestrian scheme, and barbican split-granite layers (all post-1343) [1][6].
8. **Use the zone table below** for `terrain_surface` tags; every cell carries a confidence label.

## Findings

### Research scope and limits

Kraut & Nurk monitored **480 m** of trenching on Viru, Vana turu, and Kuninga Streets (Oct 2015–Aug 2016) during utility and pavement renewal [1]. The paper is explicitly **preliminary**: drawings were draft, artefacts not fully analysed, many sections excavated piecemeal [1]. Upper **0.5–2 m** was often destroyed by 19th–20th-c. collectors and cable tunnels; **medieval horizons survive mainly at trench bottoms** [1]. Claims for **April 1343** therefore combine **stratigraphic termini** with **plausible composite** extrapolation — never upgrade absence to certainty.

### Paving zone map (authoring)

Local axes match [`old-market-vanaturg.md`](./old-market-vanaturg.md): **+X east**, **+Y north**, origin at **forum SE corner**.

| Zone | Geometry (approx.) | 1343 surface treatment | Confidence | AVE / other basis |
|---|---|---|---|---|
| **F** — Forum open ground | Raekoja polygon interior | Packed earth, patch limestone at thresholds; stall zones trampled bare | attested usage; surface mix **plausible composite** [2][3] | HISTORICAL_AUDIT market_civic_quarter band |
| **T** — Vanaturu kael | Forum SE (0,0) → junction (~52,0), width 4–6 m | Pebble/cobble lane with **localized slab patches**; crown drains to side gutters | plausible composite [1][4] | Junction approach; upper fill disturbed |
| **K** — Kuninga south frontage | Kuninga 1–3 street front | Dark humus on sand **20–30 cm**; **limestone slab hints** at occupation horizon | **partial** attested [1] | Fig. 3; Kuninga 3 & Kuninga 1/2 spots |
| **Vw** — Viru west lane | Junction → Müürivahe, Viru south cable trench | Pebble/cobble default; **black humus** sporadic; mud at plot edges | plausible composite [1][3] | Western Viru; few paved horizons |
| **G** — Gate passage interior | Inside main gate tower footprint 11.8×8.8 m | **Small cobble pavement** on clay fill ~1 m below present grade | **partial** attested [1][5] | Gateway fragment; mid-14th-c. completion horizon |
| **A** — Gate apron (tower front) | East of tower, pre-barbican | **Moat** with clay insulation; **wooden plank pavement** on moat fill (planks crosswise to street) | **partial** attested for early phase [1][5] | Figs 7–8; moat filled before barbican |
| **X** — Post-1343 only | Barbican gateway, zwinger, 2016 granite | **Do not render in 1343** | attested exclusion [1][5] | Barbican mid-15th c.; pavements at abs. alt. 4.50–5.25 m |

### Forum–throat transition (Zone F → T)

No continuous **measured slab edge** was published between Raekoja *forum* and Vanaturu kael [1]. The 2016 work on Vana turg itself concentrated on **upper refurbishment layers**; “no traces of occupation layer of archaeological value” in the renewed pavement zone [1]. Reconcile with [`raekoja-plats-extents-1343.md`](./raekoja-plats-extents-1343.md): transition is a **usage and surface-quality change** (open market → paved through-lane), not a walled boundary [2][4].

| Transition element | 1343 treatment | Confidence |
|---|---|---|
| Surface material change | Earth/stone patch → pebble lane | plausible composite [2][4] |
| Level change | Gentle fall east ~0.3–0.5 m over 50 m neck | plausible composite [4][5] |
| Drainage | Side gutters toward plot yards; **no** civic underground drain | plausible composite [3] |
| Width change | Opens 38–46 m (forum) → narrows 4–6 m (neck) | plausible composite [4] |

### Kuninga and southern Vana turg (Zone K)

At **Kuninga 3** (western research area), ~**1 m** below present street: **20–30 cm** dark humus on natural sand with **limestone slabs** suggesting floor or pavement [1] (Fig. 3). At **Kuninga 1/2** (southern Vana turg), a similar layer at **~2 m** depth [1]. Between these spots a **pre-13th-c. hearth** was known from earlier work (Talvar 2000) — the corridor has **deep antiquity** but **sparse continuous paving map** [1].

### Viru Gate apron and fortification interface (Zones G, A)

Zobel’s chronology, tested by 2016 trenches [1][5]:

| Structure | Date per Zobel/Kraut | 1343 status |
|---|---|---|
| Main gate tower (G1) | Mid-14th c. | **Present / possibly incomplete** [1][5] |
| Watermill (WM) | Mid-14th c., against later barbican | **Plausible**; mill conduit post-dates moat fill [1] |
| Moat before main tower | Pre-barbican | **Present** — filled when barbican built (post-1343) [1] |
| First barbican | Last quarter 14th c. | **Absent** |
| Present barbican (G2) | Mid-15th c. | **Absent** |
| Wooden pavement on moat fill | Stratified before clay raise | **Plausible** on apron approach [1] |
| Cobble inside tower | On clay fill in gateway | **Partial** — mid-14th-c. completion level [1] |

**Tower metrics (foundation):** outer wall **11.8 × 8.8 m**; gateway **offset north** of centre; outer wall foundation **2.5 m** thick, **>2 m** below present ground (abs. alt. ~4.3 m) [1]. **Müürivahe limestone wall** (1.1 m wide) runs near tower inner side — possibly fortification, not domestic [1].

**Pavement sequence at barbican (for exclusion reference only):** (1) split granite, pre-barbican; (2) small fieldstones on sand/brushwood ~4.50 m abs. alt.; (3) larger fieldstones ~4.75–5.25 m — trend to **larger stones over time** [1]. None of this belongs in April 1343 except possibly the **lowest horizons** as comparanda for Zone G/A.

### Regional context

- **Danish / Hanseatic Reval:** High-traffic civic approach surfaces receive **more stone** than artisan back-lanes, but AVE 2016 confirms **not citywide slab paving** [1][3].
- **Livonian Order:** Extramural; gate apron is **burgher-controlled** passage — siege scenes show **mud, planks, moat works**, not Order paving [5][7].
- **Estonian labour:** Cart ruts and manure margins on through-routes; paved centres, muddy plot edges [3].

## Production hooks

- **Map:** Tag zones F/T/K/Vw/G/A per table; set `surface=earth_patch_stone` (F), `surface=pebble_lane` (T,Vw), `surface=slab_partial` (K hotspots), `surface=cobble` (G), `surface=plank_on_fill` (A moat lip). **Forbidden tiles:** barbican polygon, zwinger, 2016 granite pattern. Plate [`topography.viru-vanaturg-paving-archaeology.01`](../../reference/topography/viru-vanaturg-paving-archaeology/topography.viru-vanaturg-paving-archaeology.01.jpg) (AVE plan) for trench locations 1–15.
- **Art:** Forum = worn earth, straw, chalk marks; neck = uneven limestone and rounded pebble with **wagon rut darkening**; gate apron = **fresh plank track** over damp clay, unfinished tower masonry, **no twin round towers** [`topography.viru-vanaturg-paving-archaeology.05`](../../reference/topography/viru-vanaturg-paving-archaeology/topography.viru-vanaturg-paving-archaeology.05.jpg) shows **1370s+ foregate only** — use for scale, not 1343 fabric.
- **Dev / systems:** `cart_speed` penalty on zones F and A mud; `wheel_damage` higher on plank (A); `slip_risk` on clay moat margins during rain scenes.
- **Quest / Narrative:** Bread-and-iron cart bottleneck at zone T; siege queue at zone A with **moat works** visible [4][7].

## Reference plates

| Plate | Shows | Source, date, origin | License | Answers |
|-------|-------|----------------------|---------|---------|
| `topography.viru-vanaturg-paving-archaeology.01` (link-only) | AVE 2016 research plan: sections 1–15, gate labels G1/WM/G2 | Kraut & Nurk, AVE 2016, Tallinn | linked | Where paving and gate evidence was found |
| `topography.viru-vanaturg-paving-archaeology.02` (link-only) | Darkened sand + limestone slab hints, Kuninga 3 | Kraut & Nurk Fig. 3, AVE 2016 | linked | Occupation-horizon slab type at forum-throat margin |
| `topography.viru-vanaturg-paving-archaeology.03` (link-only) | Wooden plank pavement on moat fill, gate apron | Kraut & Nurk Fig. 8, AVE 2016 | linked | Plank surface on gate approach (pre-barbican phase) |
| [`topography.viru-vanaturg-paving-archaeology.04`](../../reference/topography/viru-vanaturg-paving-archaeology/topography.viru-vanaturg-paving-archaeology.04.jpg) | Raekoja plats cobble and worn stone mix | Pöllö photo, 2007, Tallinn | CC BY-SA 3.0 | Forum-edge stone/earth surface comparandum — not 1343 layout |
| [`topography.viru-vanaturg-paving-archaeology.05`](../../reference/topography/viru-vanaturg-paving-archaeology/topography.viru-vanaturg-paving-archaeology.05.jpg) | Viru Gate seen from east, street approach | Panoramio / Wikimedia, 2012, Tallinn | CC BY-SA 3.0 | Apron approach width — **1370s+ towers absent in 1343** |
| [`topography.viru-vanaturg-paving-archaeology.06`](../../reference/topography/viru-vanaturg-paving-archaeology/topography.viru-vanaturg-paving-archaeology.06.jpg) | Viru Gate (Lehmpforte) historical view | R. von der Ley, TLA 1465.1.1972, Reval | CC BY-SA 4.0 | Pre-1888 gate massing — post-1343 barbican but pre-demolition |

## Cross-references

- [`old-market-vanaturg.md`](./old-market-vanaturg.md) — neck geometry and junction; this dossier supplies **surface tags** for its corridor polygon.
- [`raekoja-plats-extents-1343.md`](./raekoja-plats-extents-1343.md) — forum SE vertex opens into zone T; forum interior = zone F.
- [`walls-gates-towers.md`](./walls-gates-towers.md) — Viru Gate mid-14th-c. verdict; moat and unfinished foregate rules.
- [`lower-town-street-plan.md`](./lower-town-street-plan.md) — Viru/Vene/Kuninga spines feeding the junction.
- [`back-lanes-east-of-pikk.md`](./back-lanes-east-of-pikk.md) (R-032) — Müürivahe paving character at Viru crossing.

## Open questions

- **Continuous forum–neck slab edge:** no published trench tie-line — needs measured section from forum SSE corner (future R-row, deps: R-029).
- **Absolute 1343 street altitude** at forum SE vs gate tower foundation — only relative depths published [1].
- **Visible vs buried** Kuninga slab horizons in 1343 gameplay — occupation layers may be **below** contemporary wear surface.

## Sources

1. Kraut, A. & Nurk, R., “Results of archaeological surveillance in Tallinn during the reconstruction of Viru, Vana turu and Kuninga Streets in 2015–2016,” *AVE* 2016, 181–194 — `history/AVE2016_17_KRAUT-NURK_Tln-Viru-tn.pdf` (English/Estonian).
2. [`raekoja-plats-extents-1343.md`](./raekoja-plats-extents-1343.md) — forum polygon and open-ground treatment (English).
3. [`docs/HISTORICAL_AUDIT.md`](../../../docs/HISTORICAL_AUDIT.md) H04, H09 — market_civic_quarter ground-surface bands (English).
4. [`old-market-vanaturg.md`](./old-market-vanaturg.md) — Vanaturu kael corridor and junction (English).
5. [`walls-gates-towers.md`](./walls-gates-towers.md) — Viru Gate 1343 chronology (English).
6. T-Model / Merko project pages — 2016 pedestrian granite scheme (modern; excluded from 1343) (English/Estonian).
7. [`history/TIMELINE.md`](../../TIMELINE.md) — April–May 1343 siege context (English).
