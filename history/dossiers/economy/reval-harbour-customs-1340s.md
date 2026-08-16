---
domain: economy
slug: reval-harbour-customs-1340s
status: partial
consumers: [quest, dev, dialogue, map]
related:
  - reval-cart-tolls-and-fuhr-rent-1340s.md
  - hanseatic-trade-and-season.md
  - merchant-cart-and-transport-1340s.md
  - ../topography/harbour-and-shoreline.md
  - ../power/jurisdictions-of-reval.md
updated: 2026-08-16
---

# Reval harbour customs, landing, and crane dues (1340–1343)

## Brief for Quest / Dev / Dialogue / Map

The published AWB does **not** yield a dated Reval harbour tariff for spring 1343. It is a property, annuity, and mortgage register, not a surviving quay ledger. Do not make a crane fee, landing due, or per-cart harbour toll an `attested` 1343 number.

**Ship these decisions:**

1. **Harbour tariff gap:** no AWB 1340–1343 entry located in the accessible Arbusow edition names a harbour crane charge, landing fee, *Hafenzoll*, or cargo-weight tariff. This is a research gap, not evidence that no fee ever existed [1][2].
2. **Closest dated civic delivery evidence:** AWB 485 records a council rule charging **one ferto per lasta** for fuel burned at the bathhouses, with the fuel carried to them; the entry sits in the 1341 sequence but has no day/month [1]. This is a public-service fuel fee, not a harbour due.
3. **Closest dated multi-site delivery schedule:** AWB 553 lists annual wood-and-delivery payments of **1 mark** for the *stupa* outside the city, **1 mark** for the *stupa* under Long Hill, and **4 denarii** for the *stupa* beside St Olaf, payable at Michaelmas. The clause has no day/month; its position is in the 1342 register sequence between the June and December 1342 entries [1]. Use as a local municipal delivery comparator only.
4. **Movement without toll:** AWB 539, dated before Laetare 1342, requires a shared passage to remain high and wide enough for **one vehicle with a wagon** to enter and leave freely for both properties. It records access, not a gate or landing payment [1].
5. **Later control, not 1343:** Stieda's Reval Pfundzoll material begins in **1362** and concerns value/weight-based customs on ships and goods. The late-fourteenth-century Reval tariff is a control corpus for terminology and collection logic, not a fee table to back-project into April 1343 [2].
6. **Working game model:** keep `harbour_landing_due: null` and `harbour_crane_fee: null` as the attested 1343 defaults. If a quest needs a payment at the wet margin, label a negotiated lighter, porter, or carter charge `plausible composite`, and do not call it an AWB tariff [3][4].

## Findings

### Source and evidence boundary

The AWB is an urban property and credit register. Its target-year pages contain annuities, hereditary plots, walls, passages, and civic obligations, but the accessible printed text does not expose a harbour account book. The absence below therefore means **not located in this edition/search**, not proven non-existence.

| Question | Result for 1340–1343 | Confidence |
|---|---|---|
| Dated harbour landing due in AWB | No dated line located | gap [1] |
| Dated crane/treadwheel fee in AWB | No line located | gap [1] |
| Dated cargo-weight or ship tariff in AWB | No line located | gap [1] |
| Municipal wood delivery charges | Three AWB 553 rates; clause undated by day/month and not harbour-specific | attested register clause, date sequence partial [1] |
| Free wagon access through a shared passage | AWB 539, before Laetare 1342 | attested [1] |
| Reval Pfundzoll | Present in later corpus from 1362; not a 1343 tariff | attested later control [2] |

### Dated and near-dated document lines

The table preserves the original wording where it matters. Dates marked **sequence** are not silently upgraded to a day/month date.

| Document line | Date | Text / paraphrase | Economic use in 1343 | Confidence |
|---|---|---|---|---|
| **AWB 485** | **1341 sequence**, day/month not stated | A person burning fuel at the bathhouses pays **1 ferto per lasta**; the fuel is carried to the bathhouses, and the same ferto is due for each lasta burned | Public-service fuel handling and delivery precedent; do not transfer the amount to a ship or crane | attested clause, date sequence partial [1] |
| **AWB 539** | **1342, before Laetare** (seasonal date; the printed entry gives no exact day/month) | A shared four-foot-high passage must remain open so **one vehicle with a wagon** can enter and leave for both properties | A documented access obligation with **no toll**; supports a free-access route rather than an invented gate booth | attested [1] |
| **AWB 553a** | **1342 register sequence**, day/month not stated | The *stupa* outside the city gives the city **1 mark** at Michaelmas for wood and wood delivery | Closest extramural municipal delivery comparator; not a landing due | attested clause, date sequence partial [1] |
| **AWB 553b** | **1342 register sequence**, day/month not stated | The *stupa* under Long Hill gives the city **1 mark** at Michaelmas for wood and wood delivery | Shows that delivery can be bundled into an annual civic charge; no harbour collection point is named | attested clause, date sequence partial [1] |
| **AWB 553c** | **1342 register sequence**, day/month not stated | The *stupa* beside St Olaf gives the city **4 denarii** at Michaelmas for wood and wood delivery | A small-site comparator for local service scale; not a cargo or ship tariff | attested clause, date sequence partial [1] |
| **Stieda, Reval Pfundzoll** | **1362** | The first later Pfundzoll was levied on ships and exported goods by a value/weight rule; Reval's surviving receipt tradition belongs to this later corpus | Use only as a terminology and collection precedent for a later-period system | attested later, anachronistic for 1343 [2] |
| **Stieda, Reval Pfundzoll** | **late 14th century** | Reval's tariff at the end of the century lists commodity-specific duties, including grain, salt, copper, hides, and flax by load or ship-pound | Confirms the kind of cargo schedule a later tariff could contain; it does not fill the 1343 gap | attested later, anachronistic for 1343 [2] |

### What the AWB lines do and do not prove

- **They prove:** the council could record recurring urban obligations, charge for fuel used by public bathhouses, include delivery in a civic payment, and protect vehicle access through a shared passage [1].
- **They do not prove:** that a ship paid a landing due, that a treadwheel crane existed at Reval in 1343, or that cargo was charged by weight at the quay [1].
- The phrase *pro lignis persolvendis et pro lignis advectendis* in AWB 553 is best translated as **for wood supplied and wood brought/carried**, not as a generic harbour *Ladegeld*. Keep that distinction in dialogue and data labels [1].
- The later Pfundzoll is a **control corpus**: it makes a cargo-value tariff plausible in the wider Hanseatic world, but its dates and wartime purpose forbid direct back-projection to spring 1343 [2].

### Harbour revenue actors

| Actor | 1343 responsibility usable in scenes | Confidence |
|---|---|---|
| **Town council** | Can plausibly supervise a wet-margin landing and civic services; no dated AWB harbour rate located | plausible composite; rate gap [3][4] |
| **Crown / Danish customs interest** | External customs interest exists in the wider privilege history, but no AWB 1340–1343 landing amount is located here | plausible composite; amount gap [3] |
| **Hanseatic merchant or shipper** | Negotiates labour, lightering, and cart movement at a shallow landing; exact Reval fee remains unrecorded in this pass | plausible composite [4] |
| **Bathhouse operator / civic steward** | Collects or accounts for the AWB-style fuel and delivery obligation | attested civic comparator [1] |
| **Crane master** | Do not name as an attested 1343 office; a yard crane and its fee remain reconstruction | plausible composite only [3] |

### TLA/AIS catalogue pass (2026-08-10)

The public Tallinn City Archives search was rerun against the official Rahvusarhiiv **Pärgamendid** endpoint with `institution=TLA`, `start_year=1340`, `end_year=1343`, and `q=1`. The title field returned **No results found** for every searched harbour, customs, crane, and collector term: `portus`, `Lade`, `Ladung`, `Hafen`, `Hafenzoll`, `Zoll`, `Kran`, `telonium`, `teloneum`, `thelonium`, `Zollner`, `Zöllner`, `tolner`, `telonearius`, `collectarius`, and `Pfundzoll`. Representative reproducible queries are [portus](https://www.ra.ee/apps/pargamendid/index.php/en/parchment/search?institution=TLA&title=portus&start_year=1340&end_year=1343&q=1), [Zoll](https://www.ra.ee/apps/pargamendid/index.php/en/parchment/search?institution=TLA&title=Zoll&start_year=1340&end_year=1343&q=1), and [collectarius](https://www.ra.ee/apps/pargamendid/index.php/en/parchment/search?institution=TLA&title=collectarius&start_year=1340&end_year=1343&q=1).

This is a **bounded catalogue-title check**, not a full-text or folio search. The same catalogue identifies **TLA.230.1.Aa2**, *Ältestes Denkelbuch des Revaler Rats*, for **1333-1374**. The public AIS record gives the exact archival unit, a **48-page** extent, German as the material language, and the catalogue note: “**Enthält Notizen über Ratswahlen, Strafen, Sententien usw. Als Denkelbuch gehört auch Ad 5 hier.**” That is verbatim catalogue metadata, not a quotation from a 1340-1343 folio [6].

The AIS record marks the unit as digitized, but the public DGS permalink [TLA.230.1.Aa2](https://www.ra.ee/dgs/_purl.php?shc=TLA.230.1.Aa2) redirects to the VAU login before the manuscript image can be read. No folio/page reference, original Latin or Middle Low German wording, document date, rate, or collector name can therefore be reported from TLA in this pass. The result is an **archival lead plus access blocker**, not evidence that the Denkelbuch lacks harbour-dues material. The clearing condition is tracked as `R-459` [7][8].

### Repeat access verification (2026-08-12)

A fresh unauthenticated fetch of the official AIS unit page reproduced the catalogue record for `TLA.230.1.Aa2`; it identifies the same **48-page** German-language Denkelbuch for **1333-1374** and exposes **26 anonymous JPEG gallery previews**. The gallery HTML labels them only `Gallery image 0` through `Gallery image 25`; no preview carries a folio/page identifier, date label, or transcription. A local OCR check of those previews recovered no usable council text. This is a catalogue/preview audit, not a folio-level read [6].

A fresh fetch of the official DGS permalink returned the VAU sign-in page and an embedded remote target for a protected TIFF image rather than manuscript pixels or OCR. No authenticated image request was made and no manuscript folio was inspected. This probe therefore produced **zero folios**, no original Latin or Middle Low German wording, no document date, no rate, and no collector name. The protected image target is recorded only as an access diagnostic, not as evidence that its folio was read [8].

| Probe | Observed result | Evidence boundary |
|---|---|---|
| Official AIS unit page | Catalogue metadata loads for `TLA.230.1.Aa2`; 48-page German unit identified | Unit identity and extent only; no folio text [6] |
| AIS public gallery | 26 anonymous JPEG previews, labelled `Gallery image 0`-`25`; no folio/page/date identifiers or usable transcription | Preview resources only; not folio evidence [6] |
| Official DGS permalink | Redirects to VAU authentication before image display | Access blocker; no folio/page read [8] |
| Protected DGS TIFF target exposed by redirect | Image endpoint is named in the login redirect, but remains unauthenticated | Endpoint discovery only; no image/OCR evidence [8] |
| Harbour-term search | Not run against folio text because authentication is unavailable | No responsible text-level positive or negative claim |

This repeat check strengthens the provenance of the access boundary while leaving the harbour-dues question open. The next lawful action is an authenticated VAU/DGS review or a request to Tallinn City Archives / Rahvusarhiiv for a scan or transcription with folio identifiers. The clearing condition is tracked as `R-459` [6][8].

### Access recheck (2026-08-13, 13:02 UTC)

A direct request to the official AIS unit page returned HTTP 200 `text/html` without a redirect and reproduced the `TLA.230.1.Aa2` catalogue record and anonymous gallery previews. A separate direct request to the official DGS permalink returned HTTP 200 `text/html` only after six redirects, ending at the VAU login page. The redirect still exposed the protected TIFF target `tla0230_001_0000aa2_00001_x.tif`, but no authenticated image request was made. No folio/page identifier, original wording, date-bearing entry, rate, or collector name was recovered; zero Denkelbuch folios were inspected. The existing authorized-access handoff is `R-462`, with access enablement tracked through `R-502` [9].

This is a repeated access-boundary check, not a manuscript hit or no-hit. Keep `harbour_landing_due: null`, `harbour_crane_fee: null`, and the dossier status `partial` until a producer-approved authenticated session or archive-supplied provenance-preserving scan/transcription covers the 1340-1343 folios [9].

| Probe | Observed result | Evidence boundary |
|---|---|---|
| AIS unit page | HTTP 200 `text/html`, no redirect; catalogue record and anonymous previews reproduced | Catalogue and preview metadata only; no folio text [9] |
| DGS permalink | HTTP 200 `text/html` after six redirects; final page is VAU login and names the protected TIFF target | Authentication boundary; no image or OCR evidence [9] |
| Authenticated folio review | No producer-approved authenticated session or archive export available in this pass | Zero folios; no responsible harbour-term hit or no-hit |

### Access recheck (2026-08-15, 09:03 UTC)

Fresh unauthenticated direct requests reproduced the same zero-folio access boundary. The official AIS unit page returned HTTP 200 `text/html; charset=UTF-8`, 95,915 bytes, with zero redirects; it reproduced the `TLA.230.1.Aa2` catalogue and 26 anonymous `Gallery image 0`-`25` markers. The official DGS permalink returned HTTP 200 `text/html; charset=UTF-8`, 44,999 bytes, after six redirects; the final page was VAU login and the redirect chain exposed the protected target `tla0230_001_0000aa2_00001_x.tif`. No authenticated session or archive-supplied scan/transcription was available, so zero Denkelbuch folios were inspected and no folio/page identifier, original wording, dated entry, harbour rate, crane fee, or collector name was recovered [10].

This is an environment access blocker, not a manuscript hit or no-hit. Keep `harbour_landing_due: null`, `harbour_crane_fee: null`, and dossier status `partial` until `R-502` enables lawful authenticated VAU/DGS access or an archive supplies a provenance-preserving scan/transcription covering the 1340-1343 folios with folio/page identifiers and original wording [10].

| Probe | Observed result | Evidence boundary |
|---|---|---|
| AIS unit page | HTTP 200 `text/html; charset=UTF-8`, 95,915 bytes, zero redirects; catalogue plus 26 anonymous gallery markers | Catalogue/preview metadata only; no folio text [10] |
| DGS permalink | HTTP 200 `text/html; charset=UTF-8`, 44,999 bytes after six redirects; final page is VAU login and names the protected TIFF target | Authentication boundary; no image or OCR evidence [10] |
| Authenticated folio review | No lawful authenticated session or provenance-preserving archive export available | Zero folios; no responsible harbour-term hit or no-hit |

### Access recheck (2026-08-15, 12:02 UTC)

A fresh unauthenticated `curl -L` probe reproduced the same zero-folio boundary. AIS returned HTTP 200 `text/html; charset=UTF-8`, 95,915 bytes, zero redirects, the `TLA.230.1.Aa2` catalogue, and 26 anonymous gallery markers. DGS returned HTTP 200 `text/html; charset=UTF-8`, 44,999 bytes after six redirects to VAU login, with protected target `tla0230_001_0000aa2_00001_x.tif` in the redirect chain. No authenticated image, OCR, or folio text was accessed; zero Denkelbuch folios were inspected. This remains an environment access blocker, not a manuscript hit or no-hit; keep the dossier `partial` with `harbour_landing_due: null` and `harbour_crane_fee: null` until `R-502` clears access [11].

| Probe | Observed result | Evidence boundary |
|---|---|---|
| AIS unit page | HTTP 200 `text/html; charset=UTF-8`, 95,915 bytes, zero redirects; catalogue plus 26 anonymous gallery markers | Catalogue/preview metadata only; no folio text [11] |
| DGS permalink | HTTP 200 `text/html; charset=UTF-8`, 44,999 bytes after six redirects; final page is VAU login and names the protected TIFF target | Authentication boundary; no image or OCR evidence [11] |
| Authenticated folio review | No lawful authenticated session or provenance-preserving archive export available | Zero folios; no responsible harbour-term hit or no-hit |

### Access recheck (2026-08-15, 18:02 UTC)

A fresh unauthenticated endpoint probe again reproduced the same zero-folio boundary. The official AIS unit page returned HTTP 200 `text/html; charset=UTF-8`, 95,915 bytes, with zero redirects; the `TLA.230.1.Aa2` catalogue and 26 anonymous gallery markers were present. The official DGS permalink returned HTTP 200 after six redirects and ended at VAU login; the redirect chain exposed protected target `tla0230_001_0000aa2_00001_x.tif`. No authenticated image, OCR, or archive-supplied transcription was available, so zero Denkelbuch folios were inspected and no folio/page identifier, original wording, dated entry, harbour rate, crane fee, or collector name was recovered [12].

This remains an `environment` access blocker, not a manuscript hit or no-hit. Keep `harbour_landing_due: null`, `harbour_crane_fee: null`, and dossier status `partial` until `R-502` enables lawful authenticated VAU/DGS access or the archive supplies a provenance-preserving scan/transcription covering the 1340-1343 folios with identifiers and original wording [12].

| Probe | Observed result | Evidence boundary |
|---|---|---|
| AIS unit page | HTTP 200 `text/html; charset=UTF-8`, 95,915 bytes, zero redirects; catalogue plus 26 anonymous gallery markers | Catalogue/preview metadata only; no folio text [12] |
| DGS permalink | HTTP 200 after six redirects; final page is VAU login and names the protected TIFF target | Authentication boundary; no image or OCR evidence [12] |
| Authenticated folio review | No lawful authenticated session or provenance-preserving archive export available | Zero folios; no responsible harbour-term hit or no-hit [12] |

### Access recheck (2026-08-16, 03:01 UTC)

A fresh unauthenticated endpoint probe reproduced the same zero-folio boundary. The official AIS unit page returned HTTP 200 `text/html; charset=UTF-8`, 95,915 bytes, with zero redirects; the `TLA.230.1.Aa2` catalogue and 26 anonymous gallery markers were present. The official DGS permalink returned HTTP 200 `text/html; charset=UTF-8` after six redirects and ended at VAU login; the redirect chain exposed protected target `tla0230_001_0000aa2_00001_x.tif`. No authenticated image, OCR, or archive-supplied transcription was available, so zero Denkelbuch folios were inspected and no folio/page identifier, original wording, dated entry, harbour rate, crane fee, or collector name was recovered [13].

This remains an `environment` access blocker, not a manuscript hit or no-hit. Keep `harbour_landing_due: null`, `harbour_crane_fee: null`, and dossier status `partial` until `R-502` enables lawful authenticated VAU/DGS access or the archive supplies a provenance-preserving scan/transcription covering the 1340-1343 folios with identifiers and original wording [13].

| Probe | Observed result | Evidence boundary |
|---|---|---|
| AIS unit page | HTTP 200 `text/html; charset=UTF-8`, 95,915 bytes, zero redirects; catalogue plus 26 anonymous gallery markers | Catalogue/preview metadata only; no folio text [13] |
| DGS permalink | HTTP 200 `text/html; charset=UTF-8` after six redirects; final page is VAU login and names the protected TIFF target | Authentication boundary; no image or OCR evidence [13] |
| Authenticated folio review | No lawful authenticated session or provenance-preserving archive export available | Zero folios; no responsible harbour-term hit or no-hit [13] |

### Access recheck (2026-08-16, 06:02 UTC)

A fresh unauthenticated endpoint probe reproduced the same zero-folio boundary. The official AIS unit page returned HTTP 200 `text/html; charset=UTF-8`, 95,915 bytes, with zero redirects; the `TLA.230.1.Aa2` catalogue and 26 anonymous gallery markers were present. The official DGS permalink returned HTTP 200 `text/html; charset=UTF-8` after six redirects and ended at VAU login; the redirect chain exposed protected target `tla0230_001_0000aa2_00001_x.tif`. No authenticated image, OCR, or archive-supplied transcription was available, so zero Denkelbuch folios were inspected and no folio/page identifier, original wording, dated entry, harbour rate, crane fee, or collector name was recovered [14].

This remains an `environment` access blocker, not a manuscript hit or no-hit. Keep `harbour_landing_due: null`, `harbour_crane_fee: null`, and dossier status `partial` until `R-502` enables lawful authenticated VAU/DGS access or the archive supplies a provenance-preserving scan/transcription covering the 1340-1343 folios with identifiers and original wording [14].

| Probe | Observed result | Evidence boundary |
|---|---|---|
| AIS unit page | HTTP 200 `text/html; charset=UTF-8`, 95,915 bytes, zero redirects; catalogue plus 26 anonymous gallery markers | Catalogue/preview metadata only; no folio text [14] |
| DGS permalink | HTTP 200 `text/html; charset=UTF-8` after six redirects; final page is VAU login and names the protected TIFF target | Authentication boundary; no image or OCR evidence [14] |
| Authenticated folio review | No lawful authenticated session or provenance-preserving archive export available | Zero folios; no responsible harbour-term hit or no-hit [14] |


### Access recheck (2026-08-16, 12:02 UTC)

A fresh unauthenticated endpoint probe reproduced the same zero-folio boundary. The official AIS unit page returned HTTP 200 `text/html; charset=UTF-8`, 95,915 bytes, with zero redirects; the `TLA.230.1.Aa2` catalogue and 26 anonymous gallery markers were present. The official DGS permalink returned HTTP 200 `text/html; charset=UTF-8` after six redirects and ended at VAU login; the redirect chain exposed protected target `tla0230_001_0000aa2_00001_x.tif`. No authenticated image, OCR, archive-supplied transcription, or folio/page identifier was available, so zero Denkelbuch folios were inspected and no original wording, dated entry, harbour rate, crane fee, or collector name was recovered [15].

This remains an `environment` access blocker, not a manuscript hit or no-hit. Keep `harbour_landing_due: null`, `harbour_crane_fee: null`, and dossier status `partial` until `R-502` enables lawful authenticated VAU/DGS access or the archive supplies a provenance-preserving scan/transcription covering the 1340-1343 folios with identifiers and original wording [15].

| Probe | Observed result | Evidence boundary |
|---|---|---|
| AIS unit page | HTTP 200 `text/html; charset=UTF-8`, 95,915 bytes, zero redirects; catalogue plus 26 anonymous gallery markers | Catalogue/preview metadata only; no folio text [15] |
| DGS permalink | HTTP 200 `text/html; charset=UTF-8` after six redirects; final page is VAU login and names the protected TIFF target | Authentication boundary; no image or OCR evidence [15] |
| Authenticated folio review | No lawful authenticated session or provenance-preserving archive export available | Zero folios; no responsible harbour-term hit or no-hit [15] |

| Evidence item | Result | Confidence |
|---|---|---|
| TLA Pärgamendid title queries, 16 terms listed above | No catalogue-title result under the stated TLA and 1340-1343 parameters | bounded catalogue negative; not folio evidence [7] |
| AIS unit `TLA.230.1.Aa2` | 48-page German-language Denkelbuch, 1333-1374; digitized catalogue unit | attested catalogue metadata [6] |
| DGS image access | Redirects to VAU authentication; manuscript text not inspected | access blocker [8] |
| TLA folio-level harbour due, crane fee, landing collector, rate | No responsible claim possible without authenticated image or archive transcription | evidence gap [6][8] |

## Production hooks

- **Quest:** A clerk can produce the AWB-style line *pro lignis ... advectendis* when demanding payment for civic fuel, but a harbour master cannot quote an attested 1343 crane rate. A landing dispute should turn on missing cargo, wet-margin access, damage, or negotiated labour, not a fabricated tariff table. A later-period document may mention Pfundzoll only in a post-1362 scene.
- **Dialogue:** Use *lignum* / wood, *advectare* / bring or carry, *lasta* / load, *ferton*, *marca*, *denarii*, and *vehiculum cum plaustro* for the attested or directly translated vocabulary. Avoid presenting *Ladegeld*, *Kranpfennig*, or *Hafenzoll* as a dated Reval 1343 quotation.
- **Map:** Keep the merchant landing below the Coastal Gate, short timber jetties, lighters, carts, and one reversible crane marker as the separate harbour reconstruction in [`harbour-and-shoreline.md`](../topography/harbour-and-shoreline.md). Do not add a toll-booth POI or a fee-gate collision. A shared passage may be tagged `free_vehicle_access` from AWB 539.
- **Dev / systems:**
  - `harbour_landing_due: null` (`confidence: gap`)
  - `harbour_crane_fee: null` (`confidence: gap`)
  - `civic_firewood_delivery_fee: {source: awb_553, confidence: attested_clause_sequence_partial}`
  - `lighter_handling_fee: {confidence: plausible_composite, negotiable: true}`
  - `free_vehicle_passage: true` only for an authored shared-access passage, not as a universal city rule
  - `pfundzoll_enabled: false` for April–May 1343; `true` only in a later-date ruleset

## Reference plates

No licensed visual evidence was found for a dated **1340–1343 Reval fee line**: the relevant evidence is textual register/OCR material. Harbour geometry and crane form remain covered by the neighbouring shoreline dossier, where comparanda are explicitly labelled by date and confidence.

## Cross-references

- [`reval-cart-tolls-and-fuhr-rent-1340s.md`](reval-cart-tolls-and-fuhr-rent-1340s.md) - keeps cart tolls and *Fuhrpacht* as an explicit gap and defers harbour fees to this dossier.
- [`hanseatic-trade-and-season.md`](hanseatic-trade-and-season.md) - explains the 1343 merchant landing, steelyard, and post-23 April supply split without a surviving 1343 tariff.
- [`merchant-cart-and-transport-1340s.md`](merchant-cart-and-transport-1340s.md) - supplies vehicle and lighter-to-cart handling context; negotiated hire remains composite.
- [`../topography/harbour-and-shoreline.md`](../topography/harbour-and-shoreline.md) - supplies the wet-margin, jetty, lighter, and crane-marker map decisions.
- [`../power/jurisdictions-of-reval.md`](../power/jurisdictions-of-reval.md) - frames council harbour dues and crown customs as a jurisdictional seam, not a recovered 1343 rate.

## Open questions

- **TLA/AIS folio pass (R-459):** obtain lawful authenticated VAU/DGS access or an archive-supplied scan/transcription for `TLA.230.1.Aa2`; inspect the 1340-1343 pages for *portus*, *Lade/Ladung*, *Hafen/Hafenzoll*, *Zoll*, *Kran*, *telonium/teloneum/thelonium*, and collector terms. Preserve folio/page identifiers and original wording before changing any `gap` label.
- **Tallinn City Archives / TLA folio pass:** locate any unpublished AWB supplement, council account, or harbour memorandum for 1340–1343 naming *portus*, *Lade*, *Zoll*, *Kran*, or a landing collector.
- **Crane attestation:** test Lübeck and Riga port accounts for a dated treadwheel/crane payment that can remain a named Hanseatic comparandum rather than a Reval fact.
- **Crown versus council:** resolve who collected any pre-1362 Reval harbour dues, if a dated source is found, against the 1248 customs privilege and the Lower Town jurisdiction dossier.
- **Fee translation:** confirm the exact local sense of *stupa* and *lasta* in AWB 485/553 before exposing the figures as player-facing prices.

## Sources

1. L. Arbusow (ed.), *Das älteste Wittschopbuch der Stadt Reval (1312–1360)*, Reval: Kluge, 1888, Latin/German, public-domain BSB/MDZ scan and OCR. Bibliographic manifest: https://api.digitale-sammlungen.de/iiif/presentation/v2/bsb00149661/manifest . Relevant canvases: 87 (AWB 485, printed p. 71), 96–97 (AWB 539, printed pp. 80–81), and 99 (AWB 553, printed p. 83). Direct OCR: https://api.digitale-sammlungen.de/ocr/bsb00149661/87 , https://api.digitale-sammlungen.de/ocr/bsb00149661/96 , https://api.digitale-sammlungen.de/ocr/bsb00149661/99 .
2. W. Stieda, *Revaler Zollbücher und -Quittungen des 14. Jahrhunderts*, Halle: Niemeyer, 1887, German, public-domain Internet Archive OCR. The introduction dates the first Pfundzoll to 1362 and reproduces the later Reval tariff/control corpus: https://archive.org/details/revalerzollbu_ch9582stie and https://archive.org/download/revalerzollbu_ch9582stie/revalerzollbu_ch9582stie_djvu.txt .
3. [`reval-cart-tolls-and-fuhr-rent-1340s.md`](reval-cart-tolls-and-fuhr-rent-1340s.md) - project dossier recording the negative 1340–1343 search for *Wagenzoll*, *Radsteuer*, *Fuhrpacht*, and *Fuhrgeld* and deferring harbour dues to R-048.
4. [`hanseatic-trade-and-season.md`](hanseatic-trade-and-season.md) - project dossier for the spring 1343 merchant landing, roadstead, steelyard, and the explicit R-048 harbour tariff open question.
5. [`../topography/harbour-and-shoreline.md`](../topography/harbour-and-shoreline.md) - project dossier for the Coastal Gate landing, lighters, timber jetties, and the crane as a labelled plausible composite rather than a dated Reval attestation.
6. Rahvusarhiiv, **AIS**, `TLA.230.1.Aa2`, *Ältestes Denkelbuch des Revaler Rats*, 1333-1374, 48 pages, German-language material, catalogue note on council elections, punishments, and judgments: https://ais.ra.ee/en/description-unit/view?id=124030010181&ru=5GsV5p . Public asset gallery observed at https://ais.ra.ee/assets/41e0dd40/images/ (catalogue metadata and anonymous previews, accessed 2026-08-12).
7. Rahvusarhiiv, **Pärgamendid**, bounded TLA title queries for harbour/customs/crane/collector terms, 1340-1343: searched `portus`, `Lade`, `Ladung`, `Hafen`, `Hafenzoll`, `Zoll`, `Kran`, `telonium`, `teloneum`, `thelonium`, `Zollner`, `Zöllner`, `tolner`, `telonearius`, `collectarius`, and `Pfundzoll`; representative URLs for `portus` https://www.ra.ee/apps/pargamendid/index.php/en/parchment/search?institution=TLA&title=portus&start_year=1340&end_year=1343&q=1, `Zoll` https://www.ra.ee/apps/pargamendid/index.php/en/parchment/search?institution=TLA&title=Zoll&start_year=1340&end_year=1343&q=1, and `collectarius` https://www.ra.ee/apps/pargamendid/index.php/en/parchment/search?institution=TLA&title=collectarius&start_year=1340&end_year=1343&q=1 (all returned `No results found`, accessed 2026-08-10; catalogue-title check only).
8. Rahvusarhiiv, **DGS/VAU**, `TLA.230.1.Aa2` image permalink: https://www.ra.ee/dgs/_purl.php?shc=TLA.230.1.Aa2 (accessed 2026-08-12). The unauthenticated redirect ends at VAU authentication after exposing a protected TIFF-like target; no folio text accessible in this pass. Clearing condition: `R-459`.
9. Rahvusarhiiv, **AIS/DGS direct access recheck**, `TLA.230.1.Aa2` (2026-08-13 13:02 UTC): AIS returned HTTP 200 `text/html` without redirect; DGS returned HTTP 200 `text/html` after six redirects and ended at VAU login while exposing protected TIFF target `tla0230_001_0000aa2_00001_x.tif`. No authenticated image or folio text was accessed; zero folios inspected. Existing authorized-access handoff: `R-462`; access enablement: `R-502`.
10. Rahvusarhiiv, **AIS/DGS direct access recheck**, `TLA.230.1.Aa2` (2026-08-15 09:03 UTC): AIS returned HTTP 200 `text/html; charset=UTF-8`, 95,915 bytes, with zero redirects and 26 anonymous gallery markers; DGS returned HTTP 200 `text/html; charset=UTF-8`, 44,999 bytes, after six redirects to VAU login while exposing protected TIFF target `tla0230_001_0000aa2_00001_x.tif`. No authenticated image, OCR, or folio text was accessed; zero folios inspected. Clearing dependency: `R-502`.
11. Rahvusarhiiv, **AIS/DGS direct access recheck**, `TLA.230.1.Aa2` (2026-08-15 12:02 UTC): fresh unauthenticated `curl -L` requests returned the same HTML catalogue/login boundary - AIS HTTP 200 with 26 anonymous gallery markers and DGS HTTP 200 after six redirects to VAU login, exposing the protected TIFF target `tla0230_001_0000aa2_00001_x.tif`. No authenticated image, OCR, or folio text was accessed; zero folios inspected. Clearing dependency: `R-502`.
12. Rahvusarhiiv, **AIS/DGS direct access recheck**, `TLA.230.1.Aa2` (2026-08-15 18:02 UTC): AIS returned HTTP 200 `text/html; charset=UTF-8`, 95,915 bytes, with zero redirects and 26 anonymous gallery markers; DGS returned HTTP 200 after six redirects to VAU login while exposing protected TIFF target `tla0230_001_0000aa2_00001_x.tif`. No authenticated image, OCR, or folio text was accessed; zero folios inspected. Clearing dependency: `R-502`.
13. Rahvusarhiiv, **AIS/DGS direct access recheck**, `TLA.230.1.Aa2` (2026-08-16 03:01 UTC): AIS returned HTTP 200 `text/html; charset=UTF-8`, 95,915 bytes, zero redirects and 26 anonymous gallery markers; DGS returned HTTP 200 `text/html; charset=UTF-8` after six redirects to VAU login while exposing protected TIFF target `tla0230_001_0000aa2_00001_x.tif`. No authenticated image, OCR, or folio text was accessed; zero folios inspected. Clearing dependency: `R-502`.
14. Rahvusarhiiv, **AIS/DGS direct access recheck**, `TLA.230.1.Aa2` (2026-08-16 06:02 UTC): fresh direct `curl -L` requests returned AIS HTTP 200 `text/html; charset=UTF-8`, 95,915 bytes, zero redirects and 26 anonymous gallery markers; DGS HTTP 200 `text/html; charset=UTF-8` after six redirects to VAU login while exposing protected TIFF target `tla0230_001_0000aa2_00001_x.tif`. No authenticated image, OCR, or archive-supplied transcription was available; zero folios inspected. Clearing dependency: `R-502`.
15. Rahvusarhiiv, **AIS/DGS direct access recheck**, `TLA.230.1.Aa2` (2026-08-16 12:02 UTC): fresh unauthenticated `curl -L` requests returned AIS HTTP 200 `text/html; charset=UTF-8`, 95,915 bytes, zero redirects, with the `TLA.230.1.Aa2` catalogue and 26 anonymous gallery markers; DGS returned HTTP 200 `text/html; charset=UTF-8` after six redirects to VAU login and exposed protected TIFF target `tla0230_001_0000aa2_00001_x.tif`. No authenticated image, OCR, archive-supplied transcription, or folio/page identifier was available; zero folios were inspected. Official endpoints: https://ais.ra.ee/en/description-unit/view?id=124030010181&ru=5GsV5p and https://www.ra.ee/dgs/_purl.php?shc=TLA.230.1.Aa2. Clearing dependency: `R-502`.
