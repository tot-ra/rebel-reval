---
domain: topography
slug: nunne-bath-plot-boundaries-tla
status: partial
consumers: [map, art, quest, dialogue]
related:
  - ./public-bath-locations-1343.md
  - ./lower-town-street-plan.md
  - ../power/reval-street-cleaning-ordinances-1340s.md
  - ../dailylife/hygiene-and-grooming-1343.md
updated: 2026-08-06
---

# Nunne bath plot boundaries and the TLA evidence gap (1310–1345)

## Brief for Canon Keeper / Map / Art / Quest

This pass tests the claim that the 1310 Stocker sauna can be given an attested plot boundary across the modern Nunne tn 6–8 address window. The result is **partial**, not a TLA cadastral upgrade:

1. The **1310 Stocker sauna on Nunne** is preserved in a secondary archival tradition and is the strongest dated bath lead [1][3].
2. The NUKU courtyard archaeology supplies a **local early-14th-century built-context anchor** and a relationship to the modern Nunne street edge, but it is an excavation report, not a property-book folio [2].
3. No permissioned TLA folio, AWB line, owner name, neighbour formula, or measured medieval boundary for **Nunne tn 6–8** was exposed in this pass. Exact plot limits therefore remain a **gap** [1][2][6].
4. Keep BATH-NUNNE at **partial archaeological context / plausible composite footprint**. Do not label the modern address range as an attested medieval parcel subdivision.

## Findings

### Evidence ledger

| Claim | Evidence result | Confidence |
|---|---|---|
| A Stocker sauna was recorded on Nunne in **1310** | Estonian secondary account gives the date, name, and Nunne location; the underlying archival folio was not inspected here [3] | attested date in secondary tradition [1][3] |
| The bath belongs in the NUKU / Nunne quarter | Existing project dossier links the 1310 tradition to the NUKU courtyard SW and the western Lower Town quarter [1] | partial spatial context [1][2] |
| Early-14th-century construction exists in the NUKU archaeological context | AVE 2013 is a report on archaeological investigations in the NUKU inner courtyard; the indexed source describes the excavation, not a cadastral survey [2] | attested archaeological context; bath attribution partial [2] |
| Nunne tn 6–8 are medieval plot numbers | No medieval folio or deed with those modern numbers was found | gap [2][6] |
| A TLA/Kangropool boundary line fixes the sauna footprint | No folio image, transcription, page citation, owner/neighbour formula, or measured boundary was available in this pass | gap [1][2][6] |
| The sauna was still operating in April 1343 | 1310 existence supports continuity, but no 1343 operating entry was isolated | plausible composite [1][3][4] |

### What the evidence supports

The defensible anchor is a **bath-related site in the Nunne / NUKU quarter**, with the modern Nunne tn 7 position used as a map reference rather than as a medieval parcel identity [1]. The archaeological report is useful because it places early-14th-century building activity in the same local quarter and helps prevent a wholly open-field or modern-kerb placement [1][2]. The northern institutional / convent-garden context and the Lai–Nunne–Suur-Kloostri block are contextual adjacencies from the parent topography dossier, not surveyed bath boundaries [1][5].

The 1310 name-date-location chain is stronger than the exact footprint. It should therefore be represented as **attested documentary date + partial archaeological context + reconstructed footprint**, not as a measured cadastral polygon [1][3].

### What the evidence does not support

- Do not treat **Nunne tn 6–8** as medieval address labels. Modern numbering is a locator for the research target, not a quoted 1310–1345 plot division [1][6].
- Do not draw a boundary from the NUKU excavation edge and call it the Stocker sauna boundary. An excavation trench or building phase is not automatically a property line [2].
- Do not assign an owner, operator, neighbour, frontage width, depth, wall line, or drain corridor to a named 1343 plot without the TLA/AWB folio text [1][6].
- Do not promote 1343 operation from continuity inference to an attested dated event. The available dated line is 1310; the 1343 state remains a production reconstruction [1][3][4].

### Authoring boundary for Nunne

| Map element | Safe 1343 authoring decision | Confidence |
|---|---|---|
| Bath POI | Place BATH-NUNNE at the Nunne tn 7 / NUKU courtyard SW research anchor | partial archaeological context [1][2] |
| Building footprint | Use a compact reconstructed bath mass that may touch the medieval street alignment; do not claim a measured 6–8 parcel envelope | plausible composite [1][2] |
| Plot boundary | Keep the boundary unresolved; represent it as `plot_confidence: gap` or equivalent metadata | gap [1][6] |
| Neighbours | Preserve quarter-level context only: NUKU courtyard, Lai/Nunne block, and convent-garden direction | partial context [1][5] |
| 1343 operation | `open: true` only as a labelled continuity reconstruction, not a hard documentary trigger | plausible composite [1][3][4] |

## Production hooks

- **Map:** Keep the shipped BATH-NUNNE anchor near Nunne tn 7 / NUKU courtyard SW. Use `confidence: partial` for the archaeological site context and `plot_boundary_confidence: gap` for the unresolved medieval parcel. Do not generate a deed-shaped polygon from modern numbers 6–8.
- **Art:** A timber-and-limestone bathhouse with a smoke vent and peripheral drainage remains compatible with the parent bath dossier. The NUKU evidence supports local built occupation, not a preserved bath elevation [1][2].
- **Quest / Narrative:** A clerk or bath operator may cite “the Stocker sauna on Nunne, 1310” as a dated tradition. A dispute over the exact rear boundary should be written as an unresolved property-book question, not as a solved deed.
- **Dialogue:** Retain *Saun*, *Bad*, and *Stupa* as source-grounded bath vocabulary. Do not invent a personal owner name or a Latin boundary formula for Nunne from this pass.
- **Dev / systems:** Suggested record: `bath_poi: {id: "BATH-NUNNE", date_attested: 1310, site_confidence: "partial", plot_boundary_confidence: "gap", operation_1343: "plausible_composite"}`.

## Reference plates

No new licensed plate was required. The parent dossier's linked AVE plan remains a source lead, but it was not downloaded in this pass because the official PDF endpoint timed out before returning headers; no image is registered as newly verified here [2].

## Cross-references

- [`public-bath-locations-1343.md`](./public-bath-locations-1343.md) - parent bath POI dossier; this pass narrows BATH-NUNNE from an undifferentiated composite to partial archaeological context with an explicit plot-boundary gap.
- [`lower-town-street-plan.md`](./lower-town-street-plan.md) - quarter-level street and plot logic; its modern Nunne name is post-1343, so it cannot supply a medieval address boundary [5].
- [`../power/reval-street-cleaning-ordinances-1340s.md`](../power/reval-street-cleaning-ordinances-1340s.md) - dated 1310 bath tradition and the separate 1340–1343 Badpacht gap.
- [`../dailylife/hygiene-and-grooming-1343.md`](../dailylife/hygiene-and-grooming-1343.md) - operational and social bath context, kept distinct from plot evidence.

## Open questions

- Obtain a permissioned TLA/AWB folio image or a page-level Kangropool citation for the 1310–1345 Nunne entries, then transcribe owner, neighbour, frontage, rear boundary, and any *area*, *curia*, *murus*, or bath-rent formula verbatim.
- Re-read the complete Heinloo & Piirits AVE 2013 plan and captions when the official PDF is reachable; distinguish excavation limits, building phases, modern street edge, and any actual property wall.
- Determine whether a 1340–1343 entry documents continued operation or rent of the Nunne bath; do not infer this from the 1310 date alone.

## Sources

1. [`public-bath-locations-1343.md`](./public-bath-locations-1343.md) - project dossier carrying the prior Kangropool / NUKU evidence chain and the 1343 production boundary; used here as a secondary project source, not as a substitute for a TLA folio.
2. Eero Heinloo, “Archaeological investigations in the inner courtyard of the puppet theatre ‘NUKU’,” *Archaeological Fieldwork in Estonia* 2013, official PDF: https://arheoloogia.ee/ave2013/AVE2013_06_Heinloo_Nuku.pdf. The indexed record identifies an archaeological excavation report; direct PDF access timed out on 2026-08-06 before headers, so no new page/figure transcription is claimed in this pass.
3. Ain Kübar, “Saunakultuuri tõid meile sakslased,” *Kristlik Mõttevõra*, Estonian secondary account: https://www.kristlikmottevora.ee/blogs/post/saunakultuuri-toid-meile-sakslased. The accessible text states that a Stocker sauna on Nunne is mentioned in 1310 and a sauna by St Olaf in 1329; it does not expose the underlying folio or plot boundary.
4. Saunale.ee, “Eesti alade esimesed linnasaunad,” Estonian secondary overview: https://saunale.ee/eesti-alade-esimesed-linnasaunad/. Used only for the broader bath-institution context already bounded in the parent dossier; it does not supply a Nunne deed boundary.
5. [`lower-town-street-plan.md`](./lower-town-street-plan.md) - project topography dossier; modern Nunne / *susterstrate* is dated there to 1361, after the target date.
6. International League of Historical Cities / Stadtbücher, Reval city-books catalogue lead: https://www.stadtbuecher.de/en/stadtbuecher/estland/kreis-harju/reval-talinn/. Catalogue metadata confirms the relevant city-book corpus, but a folio-level TLA read was not available in this pass.
