---
domain: topography
slug: forum-pillory-placement-1337
status: partial
consumers: [map, quest, narrative, art]
related:
  - ./raekoja-plats-extents-1343.md
  - ../power/law-courts-and-punishment.md
  - ./lower-town-street-plan.md
updated: 2026-08-02
---

# Forum pillory placement (1337-1343)

## Brief for Map / Quest

Use one stable authoring point for the pillory on the 1343 open *forum* while keeping the historical claim bounded:

1. Place the pillory at local **(X=21.3 m, Y=17.7 m)**, where +X is east and +Y is north from the south-west corner of the open-market polygon.
2. Treat that point as **plausible composite**, not a surveyed medieval coordinate. It is the centroid of the project polygon, rounded to 0.1 m, because the sources attest a forum-centre pillory from 1337 but do not publish a 1343 survey point.
3. Keep it on open ground, away from the Town Hall south strip (X=8-32 m on the south edge), the north frontage, and the later Town Hall arcade. Do not mount it on an arcade pillar.
4. Preserve the existing 1337+ attestation in quest and narrative text; do not back-project the later arcade or claim that the exact point is documentary.

## Findings

### Documentary placement

- A pillory (*Schandpfahl*) is reported on the square from **1337 to 1816**. The date establishes that a public-shame fixture could exist in Reval before the 1343 campaign, but the source does not provide a surviving 1337 plan or a measured 1343 coordinate: **attested** for the date and square association [1].
- The law dossier places the usable 1343 venue in the **forum centre**, while separately warning that the Town Hall arcade is a 1402-04 addition. The 1343 scene therefore needs a free-standing timber pillory on open ground, not an arcade-column prop: **attested** for the forum-centre rule and later arcade exclusion [2].
- The forum authoring polygon uses local axes +X east and +Y north, with vertices SW (0, 0), SE (40, 0), NE (44, 34), and NW (2, 36), for a derived area of **1,438 m²**: **plausible composite** authoring geometry [3].

### Coordinate derivation

| Item | Value | Confidence | Basis |
|---|---:|---|---|
| Forum centroid | **(21.323 m, 17.659 m)** | plausible composite | Polygon centroid from the four vertices in [3] |
| Shipped authoring point | **(X=21.3 m, Y=17.7 m)** | plausible composite | Centroid rounded to 0.1 m for stable map content [3] |
| Clearance to polygon edges | **inside open polygon** | plausible composite | Centroid lies inside the authored convex quadrilateral [3] |

This is a reproducible placement target, not a claim that medieval surveyors marked the point. The coordinate should remain stable unless the forum polygon is deliberately revised; if that happens, recompute the centroid and record the change here.

### Historic exclusions

- Do not use the present Town Hall arcade pillar as the support: the arcade belongs to the 1402-04 rebuild and is later than the 1343 scene: **attested** [2][3].
- Do not place the fixture on the Town Hall footprint or the north built frontage. The map dossier reserves the south strip for the hall and describes the north edge as burgess plots and the Holy Spirit chapel-almshouse frontage: **plausible composite** for the exact setback, **attested** for the hall and institutional relationship [3].
- Do not label the point as a modern Raekoja plats or Vana Turg landmark in dialogue. The 1343 civic market is the *forum*; the differentiated *forum inferior* / Vana Turg is later: **attested chronology** [3].

## Production hooks

- **Map:** Add one stable `forum_pillory_1337` anchor at `(21.3, 17.7)` in the forum's local coordinate frame. Keep its footprint clear of stalls and routes at runtime; a small timber post, crossbar, and neck board are sufficient. Do not add a permanent collision wall around it.
- **Art:** Use weathered timber and iron restraint hardware, with a low silhouette readable from the isometric gameplay camera. Avoid stone, Gothic tracery, arcade masonry, or a later civic monument treatment.
- **Quest / Narrative:** Use the fixture for public-shame scenes from 1337 onward, including market fraud. Phrase the setting as the forum centre and retain the coordinate's `plausible composite` status in implementation notes.
- **Dialogue:** Prefer *forum*, *markt*, and *Schandpfahl* / “pillory” as period-facing terms. Do not call the location Vana Turg or Raekoja plats in 1343 dialogue.

## Cross-references

- [`./raekoja-plats-extents-1343.md`](./raekoja-plats-extents-1343.md) - supplies the local coordinate frame, four polygon vertices, hall strip, and later-landmark exclusions.
- [`../power/law-courts-and-punishment.md`](../power/law-courts-and-punishment.md) - supplies the 1337+ forum-centre attestation and public-shame gameplay context.
- [`./lower-town-street-plan.md`](./lower-town-street-plan.md) - establishes the forum as the central open market node and its feeder streets.

## R-044 verification: bounded negative result (2026-08-02)

The requested source pass did not locate a documentary, archaeological, or archival measurement that places the 1337-1343 pillory within the forum. This remains a **bounded negative result**, not evidence that the fixture was absent:

- **Local holdings checked:** OCR text from all 16 repository PDFs in `history/` (including `Linnakindlustuste kaardistus.pdf` and the Tallinn archaeology yearbooks `AVE2009`-`AVE2022`) was searched for `pillory`, `Schandpfahl`, `Pranger`, `Raekoja`, `Rathausplatz`, and `forum`. The hits were modern square/map labels or unrelated address text; no dated plan, excavation coordinate, or measured pillory position was published in the searchable text.
- **Published web pages checked:** Tallinn Town Hall, “The building” (official institutional history); Medieval Heritage, “Tallinn town hall” (architectural history and Neumann/Nottbeck bibliography); Tallinn Streets, “Raekoja plats” (pillory/manacle chronology); and the German “Rathausplatz (Tallinn)” page (1337-1816 chronology and modern geographic coordinates). These establish the square association, chronology, or later building phases, but none supplies a 1337-1343 local measurement.
- **Blocked primary-plan check:** the Heidelberg University Library scan for Neumann and Nottbeck, `https://digi.ub.uni-heidelberg.de/diglit/nottbeck1904bd2/0213`, returned an anti-bot challenge during this pass. The existing dossier's plate manifest already treats the relevant 1904 material as a later hall-plan/relationship comparandum, not a direct pillory survey; the access failure is recorded as an evidence boundary rather than inferred evidence.
- **Coordinate decision:** retain `(X=21.3 m, Y=17.7 m)` as **plausible composite** centroid placement. Rechecking the authored polygon from `raekoja-plats-extents-1343.md` gives positive edge cross-products `(708.0, 706.6, 730.0, 731.4)` and a minimum straight-edge clearance of approximately `17.361 m`, so the target remains inside the authored forum polygon.

No documentary coordinate is promoted, and no map polygon, modern landmark, or shipped target is changed by this result.

## Open questions

- Whether a surviving plan, archaeological report, or archival entry can replace the centroid target with a measured 1337-1343 position.
- Whether the production map should expose the anchor as a visible prop in every forum state or only when an active sentence requires it.

## Sources

1. Existing project dossier: [`../power/law-courts-and-punishment.md`](../power/law-courts-and-punishment.md), especially the punishment table and source [10], which records the 1337-1816 square pillory chronology from de.zxc.wiki, “Rathausplatz (Tallinn)” (German).
2. Existing project dossier: [`../power/law-courts-and-punishment.md`](../power/law-courts-and-punishment.md), especially the forum-centre venue and the 1402-04 arcade exclusion.
3. Existing project dossier: [`./raekoja-plats-extents-1343.md`](./raekoja-plats-extents-1343.md), especially “Open market polygon (authoring coordinates)” and the map production hooks (project source, English).
