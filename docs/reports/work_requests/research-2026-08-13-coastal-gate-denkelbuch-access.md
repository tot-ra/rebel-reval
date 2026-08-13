---
id: wr-research-20260813-0002-coastal-gate-denkelbuch-access
raised_by: research-rebel-historical-geo
raised_at: 2026-08-13T00:02:24Z
status: open
proposed_owner: producer
slice: none
source: blocked R-502
---

# Clear authorized Denkelbuch access for the Coastal Gate carter-owner review

## Player value

A lawful folio-level read could determine whether the fourteenth-century aggregate of two cooper gardens and one carter garden before Reval's Coastal Gate can be attached to a named holder, or must remain an owner-name gap. This protects Map, Quest, Dialogue, and Dev from assigning an EV II name to the carter plot or presenting catalogue metadata as Spring-1343 evidence.

## Evidence

The target is Rahvusarhiiv Denkelbuch `TLA.230.1.Aa2`, *Ältestes Denkelbuch des Revaler Rats*, catalogued for 1333-1374. The existing Coastal Gate dossiers already distinguish the public-domain EV II readings from the inaccessible Denkelbuch manuscript:

- [`history/dossiers/economy/pr-voorimees-garden-coastal-gate.md`](../../../history/dossiers/economy/pr-voorimees-garden-coastal-gate.md) keeps `named_carter_owner: null` and records that zero Denkelbuch folios were inspected.
- [`history/dossiers/economy/ev2-karrienpforte-carter-ort-folio.md`](../../../history/dossiers/economy/ev2-karrienpforte-carter-ort-folio.md) identifies EV II nos. 686 and 859 as named gate-plot controls, not named carter deeds.
- A fresh unauthenticated AIS request on 2026-08-13 returned HTTP 200 `text/html`, catalogue metadata, and anonymous `Gallery image 0`-`25` entries without folio/page identifiers or usable transcription.
- A fresh unauthenticated DGS request returned redirects through protected TIFF `tla0230_001_0000aa2_00001_x.tif` and ended at the VAU login page. No manuscript image, folio identifier, or original wording was available. This is an access boundary, not a Denkelbuch hit or no-hit.

## Proposed task

- **Goal:** Obtain a lawful, source-preserving folio-level check of `TLA.230.1.Aa2` for the 1340-1343 Coastal Gate garden and carter-owner question.
- **Deliverable:** Producer-authorized VAU/DGS session details or an archive-supplied scan/transcription under `history/sources/catalog_exports/`, preserving archive identity, access date, folio/page identifiers, original wording, and provenance. The evidence owner then updates R-499 and the Coastal Gate dossier.
- **Allowed files:** `history/sources/catalog_exports/**`; after the source is available, `history/dossiers/economy/pr-voorimees-garden-coastal-gate.md`, `history/dossiers/economy/ev2-karrienpforte-carter-ort-folio.md`, and `history/RESEARCH_INDEX.md`. Do not alter `docs/CANON.md` or downstream quest/map content in this request.
- **Dependencies:** Producer-approved authenticated VAU/DGS access or a lawful Tallinn City Archives/Rahvusarhiiv scan or transcription; rights and redistribution terms must be confirmed.
- **Verification:** The returned material is traceable to `TLA.230.1.Aa2`, reaches folio-level content or preserves archive-supplied provenance, covers 1340-1343, and supports an explicit positive or bounded no-hit result with page/folio identifiers and original wording.
- **Handoff:** Producer enables the access channel; Research passes the artifact to R-499 for the carter-owner collation and Canon review.

## Constraints and non-goals

Do not bypass VAU authentication, scrape protected images, or treat public AIS catalogue metadata and anonymous gallery previews as folio evidence. Do not back-date EV II nos. 686 or 859 to April 1343, and do not assign Borchardus myt der Have, Ghos(s)chalcus van Rode, or another EV II holder to the carter garden without a profession-linked primary reading. Do not claim the Denkelbuch lacks carter material merely because this environment has no authenticated access.

## Producer decision

Producer changes frontmatter `status: open` to the matching terminal status and fills exactly one:

- `status: accepted` with `accepted: <TODO-ID>`
- `status: rejected` with `rejected: <reason>`
- `status: merged` with `merged-into: <TODO-ID or request id>`

## Sources

1. Rahvusarhiiv, **Pärgamendid**, `TLA.230.1.Aa2`, *Ältestes Denkelbuch des Revaler Rats*, 1333-1374: https://www.ra.ee/apps/pargamendid/index.php/en/parchment/search?institution=TLA&refcode=TLA.230.1.Aa2&start_year=1340&end_year=1363&q=1 (official catalogue metadata; accessed 2026-08-13).
2. Rahvusarhiiv, **AIS**, description unit `TLA.230.1.Aa2`: https://ais.ra.ee/en/description-unit/view?id=124030010181&ru=5GsV5p (anonymous gallery previews; no folio/page identifiers or usable transcription; accessed 2026-08-13).
3. Rahvusarhiiv, **DGS/VAU**, `TLA.230.1.Aa2` image permalink: https://www.ra.ee/dgs/_purl.php?shc=TLA.230.1.Aa2 (redirect chain exposes protected TIFF target `tla0230_001_0000aa2_00001_x.tif` and ends at VAU login without folio content; accessed 2026-08-13).
4. [`../../../history/dossiers/economy/pr-voorimees-garden-coastal-gate.md`](../../../history/dossiers/economy/pr-voorimees-garden-coastal-gate.md) - current aggregate verdict and access boundary.
5. [`../../../history/dossiers/economy/ev2-karrienpforte-carter-ort-folio.md`](../../../history/dossiers/economy/ev2-karrienpforte-carter-ort-folio.md) - direct EV II control readings and owner-name gap.
6. [`../../../history/RESEARCH_INDEX.md`](../../../history/RESEARCH_INDEX.md) - linked R-499/R-502 handoff history.
