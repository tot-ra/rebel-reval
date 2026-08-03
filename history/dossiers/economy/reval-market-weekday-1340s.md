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
updated: 2026-08-03
---

# Reval market weekday and holy-day trading (1340–1343)

## Brief for Quest, Dialogue, Dev, Map, and Narrative

The reviewed evidence does **not** identify a fixed weekly market weekday for Reval in 1340–1343. Do not present the current `Wednesday/Saturday` implementation as an attested historical schedule. It is a gameplay choice until an AWB, Denkelbuch, or council-ordinance folio supplies a local day [1][2][3].

**Ship these decisions:**

1. Keep `market_weekday` unset in historical data. The market is the attested *forum* at Raekoja plats, but its weekly weekday is a gap [1][2].
2. Treat Sundays, Easter Monday, Ascension, and Pentecost as reduced or closed routine-trade days in the Lübeck-law/Hanseatic comparandum. This is a `plausible composite` for Reval, not a recovered 1343 Reval ordinance [4][5].
3. A dated legal anchor exists in the **Lübeck Stadtrecht extract dated 1260–1276**: Art. 91 protects *market peace* and assigns a three-mark silver sanction for market violence. This supports council enforcement around the forum, but it is not a weekly-market or holy-day clause [6].
4. The project research citation to **ZRG 4 (1864)** transmits Lübeck holy-day trading fines. Use it only as a dated publication of a medieval legal transmission until the underlying ordinance and folio/page are recovered [5].
5. St George's Day, 23 April 1343, is a feast and campaign anchor, but no local market closure is attested for that date. Do not turn the feast into a guaranteed town-wide fair or shutdown [4].
6. Siege pressure may override ordinary trade rhythm after 23 April. Show ration queues, emergency sales, and thin inland supply without claiming that the emergency reveals the normal weekly market day [2][7].

## Findings

### Weekly market weekday

| Question | Result for Reval, 1340–1343 | Confidence |
|---|---|---|
| Which weekday held the regular market? | No AWB, Denkelbuch, or reviewed council-ordinance line located that names Tuesday, Wednesday, Thursday, Friday, or Saturday as Reval's weekly market day | gap [1][2][3] |
| Where was the civic market? | The *forum* at Raekoja plats is attested from 1313; Vanaturu kael is a route and cart throat, not a second 1343 market square | attested / plausible composite [1][2] |
| Current Wednesday/Saturday system schedule | Existing implementation choice in `MarketDayModel`; not historical evidence and should not be quoted by dialogue or canon | invented implementation, historically unverified [8] |
| Sunday market | No Reval-specific weekday evidence found. A Sunday closure or reduced routine trade is a Hanseatic/religious composite, not proof that Reval normally marketed on Sunday | plausible composite [4][5] |

The negative result is bounded: the accessible AWB material is a property, rent, mortgage, and civic-obligation register, not a complete market calendar. “Not located” therefore means that the reviewed publication/OCR and project dossier pass did not recover the rule; it does not prove that the council never set one [1][3].

### Dated legal anchors and fines

| Document / date | Rule or line | 1343 use | Confidence |
|---|---|---|---|
| **Lübeck Stadtrecht, legal extract dated 1260–1276**, Art. 91 | Violence on the market violates *market peace*; the offender pays three marks silver, with the council's share split two-thirds to the city and one-third to the court | A transferable legal vocabulary for a Reval forum brawl or market-peace intervention under received Lübeck law; it does not set a stall fee or market weekday | attested Lübeck text; Reval application plausible composite [6][7] |
| **ZRG 4 (1864) transmission**, underlying Lübeck holy-day ordinance date not recovered in this pass | Project research notes report fines for craftsmen and pedlars who trade or work on holy days | Supports reduced routine trading on Sundays and major feasts in a Lübeck-law town; do not quote a Reval amount or claim the 1864 publication date is the medieval ordinance date | plausible composite; source-boundary explicit [5] |
| **Middelburg, 1338**, market moved from Sunday to Tuesday | A North European comparandum showing that a town could move a market off Sunday | Demonstrates that a named weekday must be sourced locally rather than inferred from a generic “market day” rule | attested comparative document; not Reval evidence [9] |

The dated **1260–1276** Lübeck text is the strongest directly inspectable legal anchor in this pass. It establishes market-peace enforcement, while the **1864** ZRG citation preserves the holy-day-fine lead but still requires a folio-level source check before it can be promoted beyond a comparative rule [5][6].

### Holy days in the April–May 1343 window

| Date / rhythm | Production rule | Confidence |
|---|---|---|
| Sundays | Thin routine stalls and ordinary craft selling; retain church traffic, household exchange, and emergency transactions rather than a fully empty square | plausible composite [4][5] |
| Easter Monday, 14 April | Restrict routine trade during the holy-day observance; do not stage a new fair without evidence | plausible composite [4][5] |
| St George, 23 April | Parish feast and uprising-night anchor; no attested Reval market closure | attested feast date; closure gap [2][4] |
| Ascension, 22 May | Quiet or reduced routine trade around worship; siege can shorten observance | plausible composite [4][5][7] |
| Pentecost, 1 June | Holy-day closure/reduction belongs to the campaign-tail calendar, outside the main playable window | plausible composite [4][5] |

“Holy day” does not mean every seller disappears. A council emergency, a perishable food sale, or a harbour supply movement can remain visible as an exception. Label such scenes `siege_override` or `emergency_trade`, not `market_weekday` [2][4].

### Legal and social boundary

Reval received Lübeck law, but daughter towns did not necessarily follow every Lübeck paragraph verbatim. The 1282 Revaler Kodex is therefore the right legal family and a strong context for council market order, while a Lübeck clause remains a `plausible composite` until the Reval manuscript or a local Burspraken confirms it [7]. The council's Art. 31-style authority to set and judge its orders makes market-peace enforcement usable in dialogue; it does not fill the missing weekly schedule [7].

## Production hooks

- **Map:** Keep the active market at the Raekoja *forum*. Do not add a weekday-only market polygon at Vanaturu kael. Reversible overlays may use `market_open` or `holy_day_reduced`, while the normal weekday remains unset [1][2].
- **Art:** On ordinary market scenes show stalls, scales, bread, beer, fish, carts, and mixed-status foot traffic. On Sundays and major feasts thin stalls, increase bells and parish movement, and leave room for emergency exchanges. Do not use an empty square as the only holy-day read [4][5].
- **Quest / Narrative:** A market-peace brawl can invoke the three-mark Lübeck Art. 91 comparandum, but a clerk must call it a received-law scale, not a recovered 1343 AWB tariff. A feast-day seller can face social or council pressure without an invented local fine amount [5][6][7].
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
- **ZRG 4 (1864) source recovery:** identify the exact article, page, medieval ordinance date, town, and original wording behind the project citation for holy-day trading fines.
- **Reval adoption boundary:** compare the relevant Lübeck holy-day clause against the 1282 Revaler Kodex and surviving Burspraken before promoting it from `plausible composite` to local attestation.

## Sources

1. [`../topography/old-market-vanaturg.md`](../topography/old-market-vanaturg.md) - *forum* at Raekoja plats attested from 1313; Vanaturu kael treated as a route, not a separate 1343 market (project dossier).
2. [`../culture/festivals-games-and-public-life.md`](../culture/festivals-games-and-public-life.md) - current bounded negative result for Reval's weekly market weekday and production restrictions (project dossier).
3. L. Arbusow (ed.), *Das älteste Wittschopbuch der Stadt Reval (1312–1360)*, Reval: Kluge, 1888 - AWB register scope and accessible OCR/edition pass; no weekday line located in the reviewed material (German, public-domain edition; source boundary explicit).
4. [`../religion/liturgical-calendar-spring-1343.md`](../religion/liturgical-calendar-spring-1343.md) - Julian 1343 feast dates and the distinction between holy-day comparandum and direct Reval attestation (project dossier).
5. *Zeitschrift für geschichtliche Rechtswissenschaft* 4 (1864), project citation transmitted in [4], exact article/page and underlying medieval ordinance date **not recovered in this pass** - reported Lübeck holy-day trading fines (German; secondary transmission, not a direct Reval 1343 record).
6. Rolf Sprandel (ed.), *Quellen zur Hanse-Geschichte*, Darmstadt 1982, p. 15, reproducing Korlén, *Stadtrecht*, pp. 83–153 - excerpt from **Lübeck Stadtrecht 1260–1276**, Art. 91, market-peace fine; https://www.spaetmittelalter.uni-hamburg.de/spaetmittelalter/luebeck/stadtrecht.html (German).
7. T. Kala (ed.), *Der Revaler Kodex des lübischen Rechts 1282*, Tallinn 1998, and Geschichtsquellen Werk/5024 - Reval's 1257/1282 Lübeck-law codices and the daughter-town evidence boundary; https://www.geschichtsquellen.de/werk/5024 (German/Estonian).
8. Project runtime: `scripts/world/market_day_model.gd` and `tests/godot/test_market_day_events.gd` - current Wednesday/Saturday implementation, recorded here as an explicit gameplay fallback rather than historical evidence.
9. Count of Holland, Middelburg market moved from Sunday to Tuesday, **1338**, Huygens RGP online edition - North European comparative evidence cited in the liturgical dossier; not Reval evidence.
