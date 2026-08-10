---
id: wr-research-20260810-0800-brewery-denkelbuch-access
raised_by: research-rebel-historical-geo
raised_at: 2026-08-10T08:00:00Z
status: open
proposed_owner: producer
slice: none
source: blocked R-451
---

# Clear the Denkelbuch access blocker for 1340–1343 brewery evidence

## Player value

A cleared archival pass would tell Quest, Dialogue, Character, and Map whether a 1340–1343 Reval beer excise, brewer rule, collector role, rate, or civic location can be shown as historical fact. Until then, the brewery scene can use beer and brewing as period context, but must not present a tax post, official collector, or quoted tariff as attested.

## Evidence

The target source is the Tallinn City Archives Denkelbuch catalogue record **TLA.230.1.Aa2**, *Ältestes Denkelbuch des Revaler Rats*. The International League of Historical Cities catalogue describes the volume as a **48-page** band covering **1333–1374** and identifies council elections, punishments, and judgments as its catalogue scope. This is catalogue metadata, not a transcription of the 1340–1343 folios.

- The official Rahvusarhiiv Pärgamendid catalogue record is reachable at the audited URL below. The catalogue/image route identifies the target record, but the image link redirects to the VAU authentication page.
- The folio images/DGS therefore could not be opened in this pass, and no original wording, folio number, brewery entry, beer-excise rate, collector name, or office can be responsibly reported.
- The public BSB/MDZ IIIF manifest for Arbusow's **1888 printed** *Ältestes Wittschopbuch* is accessible, but it is a separate AWB publication. Its OCR and scan cannot substitute for a folio-level read of Denkelbuch `TLA.230.1.Aa2`.
- This is an **evidence/access blocker**, not negative evidence that the Denkelbuch contains no brewery or beer-excise material.

The blocker clears only through an authenticated VAU/DGS folio review of `TLA.230.1.Aa2`, or through an archive-provided lawful scan or transcription that preserves folio/page identifiers and provenance.

## Proposed task

- **Goal:** Obtain a source-preserving folio-level check of Denkelbuch `TLA.230.1.Aa2` for brewery, beer-excise, and collector terms dated 1340–1343.
- **Deliverable:** A dated ledger or transcription naming each located entry, folio/page, original language and wording, document date, and a clear no-hit statement for the searched terms when applicable.
- **Allowed files:** Archive-provided or authenticated-source export under `history/sources/catalog_exports/`; update `history/dossiers/economy/reval-brewery-ordinances-1340s.md` and `history/RESEARCH_INDEX.md` only after the source pass is available; do not alter `docs/CANON.md` or downstream quest content in this request.
- **Dependencies:** VAU/DGS authentication or a lawful Tallinn City Archives scan/transcription; archive rights and provenance must be confirmed before redistribution.
- **Verification:** The returned material identifies `TLA.230.1.Aa2`, preserves folio/page references, covers 1340–1343, and supports or explicitly fails to support searches for `Bier`, `Brauer`, `Brauerschragen`, `Biersteuer`, `cervisia`, `accisa`, `Zoll`, and collector terms in Latin and Middle Low German.
- **Handoff:** Producer triages this request and names the authenticated archive-access or archive-outreach owner; Research updates the dossier and releases R-451 for Canon review after evidence arrives.

## Constraints and non-goals

Do not bypass VAU authentication, scrape protected images, or treat catalogue metadata as folio text. Do not treat the BSB/MDZ 1888 AWB manifest as a Denkelbuch surrogate. Do not infer a 1340–1343 citizen-only brewing rule, beer-excise rate, named Estonian collector, office, or tax-post location from later Tallinn ordinances or an undated secondary account. Do not convert the access failure into a claim that the target volume lacks such entries.

## Producer decision

Producer changes frontmatter `status: open` to the matching terminal status and fills exactly one:

- `status: accepted` with `accepted: <TODO-ID>`
- `status: rejected` with `rejected: <reason>`
- `status: merged` with `merged-into: <TODO-ID or request id>`

## Sources

1. Rahvusarhiiv, **Pärgamendid**, `TLA.230.1.Aa2` catalogue record, *Ältestes Denkelbuch des Revaler Rats*, 1333–1374: https://www.ra.ee/apps/pargamendid/index.php/en/parchment/search?institution=TLA&refcode=TLA.230.1.Aa2&start_year=1340&end_year=1363&q=1 (official catalogue; folio viewer requires VAU login; access behavior recorded 2026-08-07).
2. International League of Historical Cities / Stadtbücher, **Denkelbuch**, Reval, `TLA.230.1.Aa2`, 1333–1374: https://www.stadtbuecher.de/en/stadtbuecher/estland/kreis-harju/reval-talinn/aeltestes-denkelbuch-des-revaler-rats/ (catalogue metadata; image link redirects to VAU login; folio-level text not accessible, accessed 2026-08-07).
3. L. Arbusow, ed., *Das älteste Wittschopbuch der Stadt Reval (1312–1360)*, Reval 1888, public-domain BSB/MDZ scan and OCR: https://api.digitale-sammlungen.de/iiif/presentation/v2/bsb00149661/manifest (separate printed AWB publication; accessible surrogate for the Denkelbuch is not established).
4. [`../../../history/dossiers/economy/reval-brewery-ordinances-1340s.md`](../../../history/dossiers/economy/reval-brewery-ordinances-1340s.md) - current evidence boundary for brewery rules and beer excise.
