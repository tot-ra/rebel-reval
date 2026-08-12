---
domain: economy
slug: reval-market-weekday-1340s
status: partial
consumers: [quest, dialogue, dev, map, narrative]
related:
  - ../religion/liturgical-calendar-spring-1343.md
  - ../culture/festivals-games-and-public-life.md
  - ./reval-cart-tolls-and-fuhr-rent-1340s.md
  - ../power/reval-law-codex-arms-and-watch.md
updated: 2026-08-12
---

# Reval market weekday and holy-day trading (1340–1343)

## Brief for Quest, Dialogue, Dev, Map, and Narrative

The reviewed evidence does **not** identify a fixed weekly market weekday for Reval in 1340–1343. Do not present the current `Wednesday/Saturday` implementation as an attested historical schedule. It is a gameplay choice until an AWB, Denkelbuch, or council-ordinance folio supplies a local day [1][2][3].

**Ship these decisions:**

1. Keep `market_weekday` unset in historical data. The market is the attested *forum* at Raekoja plats, but its weekly weekday is a gap [1][2].
2. Treat Sundays, Easter Monday, Ascension, and Pentecost as reduced or closed routine-trade days in the Lübeck-law/Hanseatic comparandum. This remains a `plausible composite` for Reval, based on general comparative evidence rather than a verified ZRG passage or a recovered 1343 Reval ordinance [4][7][9].
3. A dated legal anchor exists in the **Lübeck Stadtrecht extract dated 1260–1276**: Art. 91 protects *market peace* and assigns a three-mark silver sanction for market violence. This supports council enforcement around the forum, but it is not a weekly-market or holy-day clause [6].
4. The project research citation to **the 1864 volume catalogued as _Zeitschrift für Rechtsgeschichte_** is unresolved: its scanned title/contents and OCR pass did not confirm the cited Lübeck holy-day trading fines. Do not use it as evidence until the exact article, page, underlying ordinance, and town are recovered [5].
5. St George's Day, 23 April 1343, is a feast and campaign anchor, but no local market closure is attested for that date. Do not turn the feast into a guaranteed town-wide fair or shutdown [4].
6. Siege pressure may override ordinary trade rhythm after 23 April. Show ration queues, emergency sales, and thin inland supply without claiming that the emergency reveals the normal weekly market day [2][7].

## Findings

### Weekly market weekday

| Question | Result for Reval, 1340–1343 | Confidence |
|---|---|---|
| Which weekday held the regular market? | No AWB, Denkelbuch, or reviewed council-ordinance line located that names Tuesday, Wednesday, Thursday, Friday, or Saturday as Reval's weekly market day | gap [1][2][3] |
| Where was the civic market? | The *forum* at Raekoja plats is attested from 1313; Vanaturu kael is a route and cart throat, not a second 1343 market square | attested / plausible composite [1][2] |
| Current Wednesday/Saturday system schedule | Existing implementation choice in `MarketDayModel`; not historical evidence and should not be quoted by dialogue or canon | invented implementation, historically unverified [8] |
| Sunday market | No Reval-specific weekday evidence found. A Sunday closure or reduced routine trade is a Hanseatic/religious composite, not proof that Reval normally marketed on Sunday | plausible composite [4][7][9] |

The negative result is bounded: the accessible AWB material is a property, rent, mortgage, and civic-obligation register, not a complete market calendar. “Not located” therefore means that the reviewed publication/OCR and project dossier pass did not recover the rule; it does not prove that the council never set one [1][3].

### Bunge 1844 full-scan boundary

The University of Tartu copy of F. G. von Bunge, *Die Quellen des Revaler Stadtrechts*, Lieferung 3, *Ordnungen des Rathes der Stadt Reval (Schluss)*, was checked as a complete 205-page scan. The contents place the relevant market/trade-police material in later sections: Straßen-Ordnung confirmed 31 May 1679 (printed p. 333), Kaufhaus-Ordnung 22 November 1670 (p. 337), Nürnberger Krämer/Bauerhändler regulation 2 December 1743 (p. 358), Wäger-Ordnung (p. 397), and later trade tariffs/revisions from 1750-1798 (pp. 405 onward) [10].

A local OCR pass searched `Markt`, `Markttag`, `Marktordnung`, `Marktrecht`, `Feier`, `Festtag`, `Feiertag`, `Sonntag`, `Woche`, `Wochen`, `feria`, `mercat`, `nundin`, `forum`, `Handel`, `Gewerbe`, `Kauf`, `heilig`, `Bursprache`, `Sabbat`, `Messe`, `Pfennig`, and `Schilling` variants. The later `Markt` hits concern market quarters, market-place hawking, fairs, or trade police; none names a Reval weekly market weekday or holy-day trading rule applicable to 1340-1343 [10]. This is a bounded negative for the inspected later-ordinance collection, not a Denkelbuch or medieval council-ordinance no-hit and not proof that Reval lacked such a rule.

### Denkelbuch AIS/DGS public-access audit (2026-08-12)

A fresh unauthenticated check of the official AIS record confirms the archival identity of `TLA.230.1.Aa2`, *Ältestes Denkelbuch des Revaler Rats*: digitized status, 48-page extent, German-language material, and the catalogue note about council elections, punishments, and judgments [11]. The record's public gallery exposes 26 JPEG resources under the unit asset path, but the HTML labels them only `Gallery image 0` through `Gallery image 25`; the files carry no folio/page identifiers, date labels, or transcription. A local OCR pass over those low-resolution gallery previews produced no usable source text. They are therefore not a provenance-preserving folio read and cannot support a market weekday, opening-hours, or Sunday/feast-day penalty claim [11].

The official DGS permalink still redirects through a protected image target and ends at the VAU sign-in page. The redirect names `tla0230_001_0000aa2_00001_x.tif` as the protected TIFF target, but no authenticated image request was made and no manuscript folio was inspected [12]. This pass consequently recovers **zero folios**, no date-bearing entry, no original Latin or Middle Low German wording, and no responsible text-level hit or no-hit result for the market question. The result is an **access blocker, not negative evidence** about the contents of the Denkelbuch.

| Public-access probe | Observed result | Evidence boundary |
|---|---|---|
| Official AIS unit page | Catalogue record loads for `TLA.230.1.Aa2`; digitized 48-page German unit identified | Catalogue metadata only [11] |
| AIS gallery | 26 unlabeled JPEG previews, `Gallery image 0`-`25`; no folio/page/date identifiers or usable transcription | Preview resources only; not folio evidence [11] |
| Official DGS permalink | Redirect chain exposes a protected TIFF target and ends at VAU authentication | Access blocker; zero folios inspected [12] |
| R-485 direct-source check (12 Aug. 2026) | Official AIS and DGS URLs were fetched directly; the Huygens WI_048 record was checked as the requested Middelburg comparandum | No Reval date, entry identifier, folio/page, or original wording recovered; retain `market_weekday: null` and do not promote a local fine |
| Market search | Not run against authenticated manuscript text | No responsible positive or negative claim for weekday, hours, or holy-day penalty |

The clearing condition remains an authenticated VAU/DGS review or an archive-supplied scan/transcription that preserves `TLA.230.1.Aa2`, folio/page identifiers, provenance, date coverage for 1340-1343, and the original wording before any local rule is promoted from `gap` or `plausible composite` [11][12].

### Dated legal anchors and fines

| Document / date | Rule or line | 1343 use | Confidence |
|---|---|---|---|
| **Lübeck Stadtrecht, legal extract dated 1260–1276**, Art. 91 | Violence on the market violates *market peace*; the offender pays three marks silver, with the council's share split two-thirds to the city and one-third to the court | A transferable legal vocabulary for a Reval forum brawl or market-peace intervention under received Lübeck law; it does not set a stall fee or market weekday | attested Lübeck text; Reval application plausible composite [6][7] |
| **1864 volume, catalogued as _Zeitschrift für Rechtsgeschichte_**, exact article/page not recovered | The scanned volume's title page/contents and OCR pass did not confirm the project note about Lübeck holy-day trading fines; underlying ordinance, town, date, and wording remain unidentified | Retain only as an unresolved bibliography lead. It does not support a Reval rule, a Lübeck fine, or a claim about the contents of the 1864 volume | unresolved lead; negative source check [5] |
| **Middelburg, 4 August 1338**, count Willem IV, Huygens record WI_048 | For religious reasons, the weekly market may no longer be held on Sunday; a **5-schelling Tournois fine** applies, and the market moves to **Tuesday**. The same charter prohibits Sunday trade throughout Walcheren | A dated North European comparandum showing both a named weekday and a feast-day trading penalty. It demonstrates the kind of local charter needed, but it does not set Reval's weekday or prove Reval adopted the fine | attested comparative document; not Reval evidence [9] |

The dated **1260–1276** Lübeck text remains the strongest directly inspectable legal anchor for market-peace enforcement, while the **4 August 1338 Middelburg charter** is the strongest directly inspectable comparative anchor for a named weekday plus a holy-day trading fine. Neither source supplies a Reval 1340–1343 rule: the Lübeck text is not a holy-day clause, and the Middelburg charter is a different town. The 1864 bibliography lead did not survive title/contents/OCR verification, so it cannot currently support an additional Lübeck holy-day fine or comparative rule [5][6][9].

### Holy days in the April–May 1343 window

| Date / rhythm | Production rule | Confidence |
|---|---|---|
| Sundays | Thin routine stalls and ordinary craft selling; retain church traffic, household exchange, and emergency transactions rather than a fully empty square | plausible composite [4][7][9] |
| Easter Monday, 14 April | Restrict routine trade during the holy-day observance; do not stage a new fair without evidence | plausible composite [4][7][9] |
| St George, 23 April | Parish feast and uprising-night anchor; no attested Reval market closure | attested feast date; closure gap [2][4] |
| Ascension, 22 May | Quiet or reduced routine trade around worship; siege can shorten observance | plausible composite [4][7][9] |
| Pentecost, 1 June | Holy-day closure/reduction belongs to the campaign-tail calendar, outside the main playable window | plausible composite [4][7][9] |

“Holy day” does not mean every seller disappears. A council emergency, a perishable food sale, or a harbour supply movement can remain visible as an exception. Label such scenes `siege_override` or `emergency_trade`, not `market_weekday` [2][4].

### Legal and social boundary

Reval received Lübeck law, but daughter towns did not necessarily follow every Lübeck paragraph verbatim. The 1282 Revaler Kodex is therefore the right legal family and a strong context for council market order, while a Lübeck clause remains a `plausible composite` until the Reval manuscript or a local Burspraken confirms it [7]. The council's Art. 31-style authority to set and judge its orders makes market-peace enforcement usable in dialogue; it does not fill the missing weekly schedule [7].

## Production hooks

- **Map:** Keep the active market at the Raekoja *forum*. Do not add a weekday-only market polygon at Vanaturu kael. Reversible overlays may use `market_open` or `holy_day_reduced`, while the normal weekday remains unset [1][2].
- **Art:** On ordinary market scenes show stalls, scales, bread, beer, fish, carts, and mixed-status foot traffic. On Sundays and major feasts thin stalls, increase bells and parish movement, and leave room for emergency exchanges. Do not use an empty square as the only holy-day read [4][7][9].
- **Quest / Narrative:** A market-peace brawl can invoke the three-mark Lübeck Art. 91 comparandum, but a clerk must call it a received-law scale, not a recovered 1343 AWB tariff. A feast-day seller can face social or council pressure without an invented local fine amount [6][7].
- **Dialogue:** Use *forum* / *markt* for the civic market. Avoid “Wednesday market” or “Saturday market” as canon. Use *market peace* / *Marktfrieden* only as a Lübeck-law comparison unless a Reval folio confirms the local wording [1][6].
- **Dev / systems:** Keep `market_weekday: null` in historical/canon data. Preserve `MarketDayModel`'s current Wednesday/Saturday behavior as an explicit implementation fallback, not a lore assertion. Model `holy_day_trade_modifier` as reduced routine trade, with `emergency_trade` and `siege_override` exceptions [4][8].

## Reference plates

No licensed visual evidence was found for a dated Reval 1340–1343 market schedule or holy-day trading ordinance. The evidence in this pass is textual; existing forum and liturgical plates remain comparanda in the neighbouring dossiers.

## Cross-references

- [`../religion/liturgical-calendar-spring-1343.md`](../religion/liturgical-calendar-spring-1343.md) - supplies Julian feast dates, the St George boundary, and the existing holy-day trading gap.
- [`../culture/festivals-games-and-public-life.md`](../culture/festivals-games-and-public-life.md) - stages public market life and deliberately leaves the weekly weekday unresolved.
- [`./reval-cart-tolls-and-fuhr-rent-1340s.md`](./reval-cart-tolls-and-fuhr-rent-1340s.md) - separates market-peace fines and traffic enforcement from an invented cart toll.
- [`../power/reval-law-codex-arms-and-watch.md`](../power/reval-law-codex-arms-and-watch.md) - explains received Lübeck law, council authority, and the Art. 91 market-peace comparator.
- [`../topography/old-market-vanaturg.md`](../topography/old-market-vanaturg.md) - fixes the forum as the market and Vanaturu kael as circulation rather than a second market.

## Open questions

- **AWB / Denkelbuch folio pass:** locate a 1340–1343 Reval line naming the weekly market weekday, market hours, or a Sunday/feast-day trading penalty, with entry number and folio/page.
- **1864 legal-history bibliography lead:** recover the exact journal title, article, page, medieval ordinance date, town, and original wording behind the project citation. The scanned volume catalogued as _Zeitschrift für Rechtsgeschichte_ (1864) did not confirm the cited Lübeck holy-day fines in its title/contents/OCR pass.
- **Reval adoption boundary:** compare any recovered Lübeck holy-day clause against the 1282 Revaler Kodex and surviving Burspraken before promoting it from `plausible composite` to local attestation.

## Sources

1. [`../topography/old-market-vanaturg.md`](../topography/old-market-vanaturg.md) - *forum* at Raekoja plats attested from 1313; Vanaturu kael treated as a route, not a separate 1343 market (project dossier).
2. [`../culture/festivals-games-and-public-life.md`](../culture/festivals-games-and-public-life.md) - current bounded negative result for Reval's weekly market weekday and production restrictions (project dossier).
3. L. Arbusow (ed.), *Das älteste Wittschopbuch der Stadt Reval (1312–1360)*, Reval: Kluge, 1888 - AWB register scope and accessible OCR/edition pass; no weekday line located in the reviewed material (German, public-domain edition; source boundary explicit).
4. [`../religion/liturgical-calendar-spring-1343.md`](../religion/liturgical-calendar-spring-1343.md) - Julian 1343 feast dates and the distinction between holy-day comparandum and direct Reval attestation (project dossier).
5. The project bibliography points to a 1864 volume catalogued as _Zeitschrift für Rechtsgeschichte_ (Internet Archive item `zeitschriftfrre05unkngoog`, https://archive.org/details/zeitschriftfrre05unkngoog), but its scanned title page, contents, and OCR pass did **not** confirm the cited Lübeck holy-day trading fines. The exact article, page, underlying ordinance, town, date, and wording remain unrecovered; this is an unresolved lead, not evidence for Reval or even for the claimed Lübeck fines.
6. Rolf Sprandel (ed.), *Quellen zur Hanse-Geschichte*, Darmstadt 1982, p. 15, reproducing Korlén, *Stadtrecht*, pp. 83–153 - excerpt from **Lübeck Stadtrecht 1260–1276**, Art. 91, market-peace fine; https://www.spaetmittelalter.uni-hamburg.de/spaetmittelalter/luebeck/stadtrecht.html (German).
7. T. Kala (ed.), *Der Revaler Kodex des lübischen Rechts 1282*, Tallinn 1998, and Geschichtsquellen Werk/5024 - Reval's 1257/1282 Lübeck-law codices and the daughter-town evidence boundary; https://www.geschichtsquellen.de/werk/5024 (German/Estonian).
8. Project runtime: `scripts/world/market_day_model.gd` and `tests/godot/test_market_day_events.gd` - current Wednesday/Saturday implementation, recorded here as an explicit gameplay fallback rather than historical evidence.
9. Count of Holland, **WI_048**, 4 August 1338, Middelburg, Huygens RGP online edition: [record](https://resources.huygens.knaw.nl/registershollandsegrafelijkheid/oorkonde/WI_048) - the regest states that religious reasons moved the Middelburg weekly market from Sunday to Tuesday under a 5-schelling Tournois fine and prohibited Sunday trade throughout Walcheren; archival reference AGH 218, f. 8r, no. 47. North European comparative evidence only, not Reval evidence.
10. F. G. von Bunge, *Die Quellen des Revaler Stadtrechts*, I. Band, Lieferung 3, *Ordnungen des Rathes der Stadt Reval (Schluss)*, Dorpat: Franz Kluge, 1844, University of Tartu DSpace item `29ba1aed-444d-4e61-8468-372da8231aed`, handle http://hdl.handle.net/10062/17622, PDF `bunge_revaler_erster.pdf` (German). The complete 205-page scan was checked; its contents and dated headings show that the market/trade-police material cited here is from 1670 onward, with later trade revisions through 1798. It is a source-boundary and bounded-negative check, not direct 1343 evidence.
11. Tallinn City Archives AIS, description unit `TLA.230.1.Aa2`, *Ältestes Denkelbuch des Revaler Rats*, official record: https://ais.ra.ee/en/description-unit/view?id=124030010181&ru=5GsV5p ; public asset gallery observed at https://ais.ra.ee/assets/41e0dd40/images/ (accessed 2026-08-12). The catalogue record identifies a digitized 48-page German unit; the public gallery exposes 26 anonymous JPEG previews without folio/date/transcription metadata. Catalogue and preview boundaries only, not authenticated folio evidence.
12. Tallinn City Archives DGS permalink for `TLA.230.1.Aa2`: https://www.ra.ee/dgs/_purl.php?shc=TLA.230.1.Aa2 (accessed 2026-08-12). The unauthenticated redirect chain ended at VAU sign-in after exposing a protected TIFF-like target; no folio was opened or transcribed. Access-boundary evidence only.
