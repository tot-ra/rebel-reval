---
domain: culture
slug: reval-musician-payments-1340s
status: solid
consumers: [dialogue, dev, narrative]
related:
  - ./music-and-instruments.md
  - ../people/town-council-and-officers.md
  - ../economy/coinage-prices-and-measures.md
  - ../religion/churches-and-religious-houses.md
updated: 2026-07-28
---

# Reval musician payments (1340-1343)

## Brief for Dialogue, Dev, and Narrative

You are checking whether **April 1343 Reval** had a **council-paid town musician corps** (*moosekandid*, *Spielleute*, *Pfeifer*) on the Hanseatic **Stadtpfeifer** model.

**Ship these decisions:**

1. **Formal council musician corps: ABSENT in 1343.** No AWB, Denkelbuch, or published secondary survey cites a **1340-1343 council payroll line** to *spilman*, *moosik*, *pfeifer*, *trumeter*, or *Piper* [1][2][3]. Do **not** spawn uniformed Ratsmusik NPCs, a named *Piperbude* post, or hourly tower fanfares.
2. **Earliest systematic council musician accounts begin 1432.** Lilian Kotter's pass on the three Reval account books (*arveraamatud*) records regular natura and cash pay to **four to six moosekandid** only from **1432-1533** [2][4]. Hillar Saha's earlier survey allows inferring city musicians **from the late 14th century** - still **after** the game date [1][5].
3. **Piperbude is post-game.** The musicians' stall (*Piperbude*) at Kinga/Teenri is **first named 1479**; Nottbeck's chapel of pipers and trumpeters is a **15th-16th c.** horizon [6][7].
4. **Church organist 1341 is not a council musician payment.** An organist at a Tallinn church is attested **1341** via organ-history scholarship citing Tallinn archives [8] - **parish or chapter payroll**, not AWB civic music corps. Usable for **Dome or St Nicholas** liturgy only [`music-and-instruments.md`](./music-and-instruments.md).
5. **Itinerant Spielleute remain plausible composite.** Private feasts, taverns, and merchant weddings may hire unnamed wind players **without council salary** - label **`plausible composite`** [3][9].
6. **AWB coverage in the band is good for other payments.** Council records from **1340-1343** survive for annuities, property, and guild-adjacent spending (see control table below) - the **negative musician search is meaningful**, not a records gap [10][11].

## Findings

### Verdict - formal town musician corps (April 1343)

| Question | Answer | Confidence |
|---|---|---|
| Council-employed moosekandid on regular payroll | **Absent** | attested negative [1][2][3] |
| Named *Piperbude* or Stadtpfeifer post | **Absent** | attested negative [6][7] |
| AWB payment to *spilman* / *moosik* / *pfeifer* 1340-1343 | **None published** | attested negative (secondary survey) [1][2] |
| Occasional hired Spielmann at private feast | **Plausible** | plausible composite [3][9] |
| Parish organist on church books | **Plausible at one church** | plausible composite [8] |

### Musician payment lines (1340-1343)

**Search scope:** Tallinn City Archives (*Tallinna Linnaarhiiv*) **AWB** (*Altere Verzeichnisse* / older council registers), **Denkelbuch**, and published extracts in Hillar Saha (*Muusikaelust vanas Tallinnas*, 1972), Lilian Kotter ("Muusikud Tallinna rae kolmes arveraamatus (1432-1533)," *Vana Tallinn* 1, 1991), and Risto Paju (2024) [1][2][6]. Keyword forms: *spilman*, *Spielmann*, *moosik*, *moosekant*, *pfeifer*, *Pfeifer*, *trumeter*, *Trummler*, *Piper*, *orgeliste*.

| Date | Payee / role | Amount | Source | Confidence | Notes |
|---|---|---|---|---|---|
| - | *spilman* / *moosik* / *pfeifer* (council) | - | AWB / Denkelbuch 1340-1343 pass [1][2] | **attested negative** | **No line published** in Saha 1972, Kotter 1991, or Paju 2024 for this window |
| **1341** | Organist (*orgeliste*) at a Tallinn church | not stated | Rojman 1960 via *The Diapason* survey [8] | plausible composite | **Church**, not council; amount and parish **unknown** |
| **1479** | Musicians' stall (*Piperbude*) at Kinga/Teenri | property reference | Paju 2024 [6] | attested | **Post-game**; confirms institution later, not 1343 payroll |
| **1531** | Jost *spelman* - estate inventory | instruments listed | Paju 2024 citing Saha [6] | attested | **Private estate**, not council salary |
| **1549** | Jacob *spielman* - estate inventory | 2 *mundstucke*, fiddle, drum, etc. | Paju 2024 [6] | attested | **Private estate**; earliest named *spielman* inventories are **mid-16th c.** |

### Control lines - non-musician AWB activity 1340-1343

These prove **council financial writing survives** in the target years; musician silence is not a blank archive.

| Date | Entry | Source | Confidence |
|---|---|---|---|
| **1341** | AWB no. 516; AWB no. 508 (widow Gertrude van Bremen household) | Kala 2018 citing AWB [10] | attested |
| **1343** | AWB no. 566 - Johann van Bremen annuity foundation (112 marks capital) | Kala 2018 citing AWB [10] | attested |
| **1343** | AWB no. 570; related 1344-1345 entries | Kala 2018 citing AWB [10] | attested |
| **1340-1343** | Harbour, property, and excise lines (no musician keyword) | Secondary surveys [1][2][11] | attested negative for musicians |

### Later council musician payroll (comparandum only)

From **1432** the three account books record **regular natura and cash pay** to **four to six moosekandid**, plus **instrument maintenance** [2][4]. **Do not back-project** this staffing table to 1343.

| Period | Corps size | Pay type | Source | Usable in 1343? |
|---|---|---|---|---|
| **1432-1533** | 4-6 moosekandid | Cash, natura, instrument repairs | Kotter 1991 [2][4] | **No** - begins 89 years after game date |
| **Late 14th c.+** | "Certain number" of city musicians treated like town servants | Inferred from documents | Saha 1972: 21-22 [1][5] | **No** - Saha's wording is **end of 14th century**, not 1340-1343 |

## Production hooks

- **Dialogue:** Burghers **do not** refer to "the council pipers" or "our Stadtpfeifer" as an institution. Tavern keeper may say *"I hired a spille man for the wedding"* - **`plausible composite`**.
- **Map / Dev:** **No** `town_piper_post` marker, **no** `stadtpfeifer_fanfare` scheduler before a post-1400 content flag [`music-and-instruments.md`](./music-and-instruments.md).
- **Narrative:** Henning's watch scenes use **bells and composite trumpet at muster** - not a salaried civic wind band [`../military/watch-duty-and-town-defence.md`](../military/watch-duty-and-town-defence.md).
- **Character:** If a musician NPC appears in Lower Town 1343, tag **`itinerant`** or **`private hire`** - never **`council moosekant`**.

## Cross-references

- [`./music-and-instruments.md`](./music-and-instruments.md) - instrument set, church vs tavern sound, regilaul boundary.
- [`../people/town-council-and-officers.md`](../people/town-council-and-officers.md) - council offices and AWB prosopography pass (R-038).
- [`../economy/coinage-prices-and-measures.md`](../economy/coinage-prices-and-measures.md) - marks and schillings if a later quest pays a Spielmann.
- [`../religion/churches-and-religious-houses.md`](../religion/churches-and-religious-houses.md) - which churches exist; organ absent in most parishes in 1343.

## Open questions

- **Primary AWB folio scan** at Tallinn City Archives for *moosik* / *pfeifer* strings in **1340-1343** registers - would upgrade negative search from secondary survey to direct attestation (maintainer or on-site researcher).
- **1341 organist** - parish name, salary, and whether the post is Dome chapter or St Nicholas.
- **Order comptoir musicians** on Toompea after May 1343 handover - separate from Lower Town council corps (see R-039).

## Sources

1. Hillar Saha, *Muusikaelust vanas Tallinnas* (Tallinn: Eesti Raamat, 1972), pp. 21-22 - documents from **late 14th century** allow inferring city-employed musicians; no 1340-1343 payroll table (Estonian).
2. Lilian Kotter, "Muusikud Tallinna rae kolmes arveraamatus (1432-1533)," *Vana Tallinn* 1 (1991), pp. 71-77 - earliest systematic council musician accounts **1432+** (Estonian/German).
3. [`./music-and-instruments.md`](./music-and-instruments.md) - R-018 instrument and ensemble verdicts; open question closed by this dossier.
4. Kotter 1991: 71, 74 - regular pay and four to six moosekandid; instrument expenses.
5. Risto Paju, "Kivistunud lauluhääl ja šalmei…," *Estonian Musicological Society*, 2024, https://doi.org/10.58162/mj78-w362 - cites Saha on late-14th-c. inference; Piperbude 1479 (Estonian).
6. Same as [5] - Piperbude 1479; Jost spelman 1531 and Jacob spielman 1549 estate lists; musician inventories mid-16th c.
7. Eugen von Nottbeck & Wilhelm Neumann, *Geschichte und Kunstdenkmäler der Stadt Reval*, vol. 1 (Reval: Kluge, 1904), p. 107 - later chapel of pipers and trumpeters; weak art-music culture (German).
8. *The Diapason*, "A History of the Organ in Estonia," citing Leonid Rojman, *Organnaja kul'tura Estonii* (Moscow, 1960), p. 85 - **organist at a Tallinn church, 1341** (English survey).
9. Juhan Kreem, "Linnades ja lossides: moosekandid, mobiilsus ja muusikakultuur keskaegsel Liivimaal," *Tuna* 1 (2003), pp. 13-18 - Order and castle musicians; mobility (Estonian).
10. Tiina Kala, "Scenes from the life of a rich widow (Reval in the mid-fourteenth century)," *Studia Historica Tallinnensia* 18 (2018), https://doi.org/10.4467/25442562sds.18.006.9808 - AWB nos. 508, 516 (1341), 566 (1343), 570 (1343) for non-musician council finance (English).
11. [`../economy/hanseatic-trade-and-season.md`](../economy/hanseatic-trade-and-season.md) - AWB harbour toll pass flagged as R-048; confirms 1340s register activity without musician rows.
