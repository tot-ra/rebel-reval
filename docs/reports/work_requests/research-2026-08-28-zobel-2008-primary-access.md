---
id: wr-research-20260828-0300-zobel-2008-primary-access
raised_by: research-rebel-historical-geo
raised_at: 2026-08-28T03:05:00Z
status: open
proposed_owner: producer
slice: act2-fire-of-rebellion
source: blocked R-787 / toompea-small-castle-interior dossier
---

# Clear the Zobel 2008 primary-access blocker for Danish Small Castle dimensions

## Player value

A cleared primary pass would let Map (`P4-039` / `R-297`) and Art (`A-012`) scale `SC-*` Danish-era rooms from measured evidence instead of topology-only labels. Until then, the Small Castle interior may use the 2026-08-28 A2 secondary collation and Wikipedia (et) frames, but must not import Order **34 × 39 m** or Medieval Heritage **52 × 40 m** comparanda as April 1343 Danish dimensions.

## Evidence

Target source: Rein Zobel, "Toompea loss keskajal (ca 1030–1525)," in *Toompea loss* (Kalm, Maiste, Zobel), Riigikogu Kantselei, Tallinn **2008**, pp. **11–30** (ISBN **9789985953167**).

- ETIS publication record: https://www.etis.ee/Portal/Publications/Display/2c1729b5-31d1-4923-9db8-810e8f82814c
- Riigikogu publications catalogue lists the print volume only; no chapter PDF is exposed on the public site.
- Internet Archive advanced search returned **0** hits for `title:(Toompea loss) AND creator:Zobel` on 2026-08-28.
- The repository checkout contains **no** local OCR/PDF extract under `history/`.
- Google Books API returned HTTP **429** on 2026-08-28; this is a tooling limit, not evidence about the chapter contents.

This is an **access/rights blocker**, not negative evidence that Zobel 2008 lacks measured Danish-phase interior drawings.

## Proposed task

- **Goal:** Obtain a rights-cleared scan or maintainer transcription of Zobel 2008 pp. 11–30 and extract any measured Danish-era Small Castle interior drawings or room dimensions.
- **Deliverable:** `history/Zobel_2008_toompea_loss_excerpt.txt` (or equivalent OCR export) plus dossier update in `history/dossiers/architecture/toompea-small-castle-interior.md` naming page, figure, and measured values tied to `SC-*` zone IDs.
- **Allowed files:** `history/Zobel_2008_toompea_loss_excerpt.txt`, `history/dossiers/architecture/toompea-small-castle-interior.md`, `history/reference/plates.csv`, `history/RESEARCH_INDEX.md`
- **Dependencies:** Library loan, Riigikogu Kantselei permission, or maintainer-owned scan with redistribution rights.
- **Verification:** Every upgraded `SC-*` dimension cites a Zobel 2008 page and figure; Order 1350–1360 convent measurements remain explicitly excluded from April 1343 scenes.
- **Handoff:** Producer names the library-acquisition or rights-clearing owner; Research updates the dossier and releases **R-787** for Canon review after the primary pass lands.

## Constraints and non-goals

Do not treat Wikipedia (et), Medieval Heritage, Riigikogu visitor copy, or the 2022 TLPA A2 inventory as substitutes for Zobel 2008 pp. 11–30. Do not download or register figures without explicit redistribution permission. Do not convert the access failure into a claim that no Danish interior measurements exist in the primary chapter.

## Producer decision

Producer changes frontmatter `status: open` to the matching terminal status and fills exactly one:

- `status: accepted` with `accepted: <task-ref>`
- `status: rejected` with `rejected: <reason>`
- `status: merged` with `merged-into: <task-ref or request id>`

## Sources

1. ETIS, publication record for *Toompea loss* (2008): https://www.etis.ee/Portal/Publications/Display/2c1729b5-31d1-4923-9db8-810e8f82814c
2. Riigikogu, publications catalogue (print listing): https://www.riigikogu.ee/infoallikad/riigikogu-valjaanded/
3. Internet Archive advanced search API, query `title:(Toompea loss) AND creator:Zobel`, `numFound: 0`, accessed 2026-08-28.
4. [`../../../history/dossiers/architecture/toompea-small-castle-interior.md`](../../../history/dossiers/architecture/toompea-small-castle-interior.md) — current secondary collation, explicit exclusions, and access-boundary table.
