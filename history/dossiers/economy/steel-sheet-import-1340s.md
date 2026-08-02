---
domain: economy
slug: steel-sheet-import-1340s
status: partial
consumers: [dev, art, quest, dialogue]
related:
  - ../crafts/blacksmith-materials-and-techniques.md
  - coinage-prices-and-measures.md
  - hanseatic-trade-and-season.md
  - reval-harbour-customs-1340s.md
updated: 2026-08-02
---

# Lübeck steel, Swedish osmund, and barrel measures (1340s Reval)

## Brief for Dev / Art / Quest / Dialogue

The surviving evidence supports an active Swedish iron corridor to Livonia before 1343, but it does **not** preserve a dated Reval purchase of Lübeck steel sheet or rod in 1340-1343.

**Ship these decisions:**

1. Treat Swedish osmund as an economically plausible 1343 forge input, with the 1336 Narva-Stockholm trade as the earliest written Livonian import and the 1357 Riga barrel as the first direct osmund sale [1].
2. Treat Lübeck steel or sheet-metal in Reval before 1368 as a **gap**, not an attested stock item. The first documented German iron traffic is 1368-1369; steel and sheet-metal from Lübeck are explicitly attested only in later fifteenth-century evidence [1].
3. Use a standard osmund piece of about **283 g** and a Stockholm barrel of about **136 kg / 480 pieces** as later attested measures, not as a recovered 1343 customs tariff [1].
4. For a game-scale 1343 barrel, allow **130-145 kg** only as a labelled `plausible composite` range. Keep the 136 kg Stockholm standard as the primary material-cost anchor [1].
5. Use the dated price anchors **100 osmund pieces for 15 öre in Tallinn in 1363** and **one barrel for 5-8 Riga öre in 1372** as later comparanda. Do not present either as an April 1343 price [1][3].

## Findings

### Dated import path

| Date | Route or record | What it establishes for the forge economy | Confidence |
|---|---|---|---|
| **1335-10 July 1336** | Narva burgher Florekinus de Ermennowe made Stockholm voyages, exchanged Livonian grain for copper and iron, and sold the goods in Livonia | A profitable Sweden-to-Livonia iron route existed before 1343; the record does not name osmund, Reval, or a sheet/rod form | attested route; material form and Reval destination gap [1] |
| **Early 1357** | Riga council bought one barrel of osmund for **7 Riga öre** | First direct written osmund sale in Livonia and a dated barrel-price anchor | attested later [1] |
| **1358** | Riga council bought one barrel of osmund for **5 Riga öre** | Shows that barrel pricing could vary substantially even in consecutive entries | attested later [1] |
| **30 September 1363** | Tallinn council accounts record **100 osmund pieces for 15 öre** | First recorded Tallinn osmund sale; gives a piece-count price, not a barrel tariff | attested later [1][3] |
| **1364** | Tallinn merchant Hermannus van der Hove was already involved in Stockholm-to-Tallinn osmund traffic | Confirms an established Tallinn import network immediately before the Lübeck evidence | attested later [1] |
| **Spring 1368** | Hermannus van der Hove sent one **last**, defined as 12 barrels, of osmund from Lübeck to Tallinn | First documented Lübeck-to-Tallinn osmund movement; it is 25 years after the game date | attested later [1] |
| **Summer 1368** | Tallinn merchant Hans de Linen exported roughly ten barrels of osmund to Lübeck for about **25-26 Lübeck marks**; the same tariff corpus values one last at about **30 Lübeck marks** | Demonstrates a functioning Tallinn-Lübeck osmund corridor and a wholesale comparator | attested later [1][4] |
| **1368-1369** | Lübeck pound-toll lists record German iron traffic to Riga; some cargoes are counted by weight or by 100 pieces | A German iron route is documented, but the surviving entries do not securely identify the material as steel or a Reval delivery | attested later; material identification partial [1][4] |
| **15th century** | Lübeck and other German regions are described as sources of steel and sheet-metal for Livonia | Supports the later steel/sheet trade pattern used by the parent smithing dossier, not a 1343 import claim | attested later; 1343 presence gap [1] |

**Verdict for April-May 1343:** Swedish osmund in a Reval merchant or smith stock is `plausible composite`, because a profitable Stockholm-Livonia route is attested by 1336 and the first written records are explicitly described as first surviving instances of older relations [1]. A named Lübeck steel-sheet or steel-rod purchase in Reval before 1368 remains a `gap`; the evidence does not justify upgrading it to `attested` [1].

### Steel, sheet, rod, and iron form

| Stock form | Origin / route | 1343 authoring decision | Confidence |
|---|---|---|---|
| **Osmund** | Swedish iron, shipped through Stockholm and Baltic ports | Use as lumpy, cut iron pieces; it is the historically strongest imported forge stock for the period | plausible composite for Reval 1343; attested Livonian trade by 1357 [1] |
| **Hammered bar iron** | Could be prepared from osmund or another iron source | Use as a smith's prepared stock only when the source is explicitly labelled local workshop preparation or later comparator | plausible composite [1][5] |
| **Steel sheet / strip** | Lübeck or other German route | Keep rare and unconfirmed in the 1343 Reval stock list; do not create a dated customs entry | gap for Reval 1340-1343 [1] |
| **Steel rod / counted pieces** | The 1368-1369 Riga entries include iron counted by 100 pieces; the high price may indicate steel, but the source does not name it securely | A rod or small steel-piece prop can be a reversible reconstruction, never an attested 1343 import | plausible composite reconstruction; identification partial [1][4] |
| **Lübeck steel and sheet-metal** | German import pattern documented for Livonia in later fifteenth-century sources | Valid for a later-period ruleset; do not back-project it into the 1343 scene | attested later, anachronistic if asserted for 1343 [1] |

The 1368-1369 entries are useful because 100 imported iron pieces were valued at about **2.5-2.8 Lübeck marks**, almost five times the approximate value of one osmund barrel in the same corpus. Mäesalu treats this difference as evidence that the counted iron **may have been a type of steel**, not as a secure identification [1]. Preserve that uncertainty in data and dialogue.

### Osmund pieces, barrels, and customs measures

| Measure | Historical value | Use in production data | Confidence |
|---|---|---|---|
| **One osmund piece** | About **260-300 g**; one standard used by Wallander is **283 g** | `osmund_piece_kg = 0.283`; render as a flat, irregular cut piece, not a modern round bar | attested later standard and archaeological range [1] |
| **Stockholm barrel** | About **480 pieces**, **20 Stockholm leisik**, approximately **136 kg** of osmund | Primary material-cost anchor: `osmund_barrel_kg = 136`; `osmund_barrel_pieces = 480` | attested later commercial standard [1] |
| **Tallinn barrel control** | A Tallinn early-sixteenth-century regulation gives **18 Tallinn leisik**, approximately **145 kg**, apparently including the barrel | Use only to bound a local gross-barrel reconstruction; do not silently merge it with the Stockholm net-like figure | attested later control, measure differs [1] |
| **One osmund last** | **12 barrels**, approximately **1,630 kg** under the Stockholm convention | `osmund_last_barrels = 12`; useful for convoy and wholesale cargo, not a smith-shop quantity | attested later commercial convention [1] |
| **Livonian pound ladder** | Silver mark about **208 g**; 1 pfund = 2 silver marks; 1 lispund = 20 pfund; 1 schiffspfund = 20 lispund | Use for harbour-scale conversion only; do not derive a barrel from the ship-pound without naming the local standard | attested weight system; exact 1343 local application partial [2] |

The Stockholm barrel calculation is internally coherent: 480 pieces x 0.283 kg = 135.84 kg. The 130-145 kg game range is therefore a `plausible composite` that covers the Stockholm standard and the later Tallinn gross-barrel regulation; it is not a recovered 1343 Reval tare rule [1].

### Price lines usable for forge material costs

The following rows preserve their original unit systems. Do not convert Riga öre, Tallinn öre, and Lübeck marks into one 1343 shop currency without a separate exchange-rate decision.

| Date / market | Original line | Direct calculation | Production use | Confidence |
|---|---|---|---|---|
| **Early 1357, Riga** | 1 barrel osmund for **7 Riga öre** | 7 öre / barrel | Later low-volume barrel comparator | attested later [1] |
| **1358, Riga** | 1 barrel osmund for **5 Riga öre** | 5 öre / barrel | Later low-volume barrel comparator and price-volatility check | attested later [1] |
| **1363, Tallinn** | 100 osmund pieces for **15 öre** | 0.15 öre / piece; about 72 öre per 480-piece standard barrel if scaled linearly | Piece-count price anchor; scaled barrel figure is a calculation, not a quoted tariff | attested line; scaling composite [1][3] |
| **1370, Tallinn** | 3 barrels for 4 Riga marks minus 6 öre; 6 barrels for 6 marks and 1 veering | Wholesale price below the single-barrel examples | Shows bulk discount and mixed local accounting | attested later [1][3] |
| **1372, Tallinn** | One barrel for **5.5 veering**; another for **8 veering and 4 öre** | 5.5 and 8 veering + 4 öre per barrel | Later local range; do not collapse unlike units | attested later [1][3] |
| **1368, Lübeck tariff comparator** | One last (12 barrels) about **30 Lübeck marks** | About **2.5 Lübeck marks per barrel** | Wholesale corridor comparator for a merchant convoy | attested later [1][4] |

For the April 1343 forge loop, keep the existing price row as a `plausible composite` rather than relabelling it as a recovered 1343 quote. The new evidence provides dated later anchors and a weight basis, but no direct 1343 Reval price [1][3][5].

## Production hooks

- **Art:** Make osmund a stack of irregular, flat, axe-cut iron pieces around 260-300 g each, with a marked wooden barrel for merchant storage. Do not depict osmund as uniform modern round bar [1]. A rectangular steel strip or rod may appear only as a rare, reversible reconstruction labelled `plausible composite`.
- **Map:** A full osmund barrel is merchant-scale cargo, not a small forge basket. Use `osmund_last` only at harbour or convoy scale; one barrel can feed a smithy stock abstraction without placing 480 visible pieces in the yard [1].
- **Quest:** A stamped barrel, disputed ownership mark, or missing Stockholm-to-Reval consignment is historically grounded. A clerk claiming an attested 1343 Lübeck steel tariff is not; make that claim a contested reconstruction [1].
- **Dialogue:** Use *osmund*, *Stahl*, *Eisen*, *vaat* / barrel, *last*, *öre*, *mark*, and *Lübeck*. Restrict explicit steel-sheet import talk to a later-date speaker or mark it as uncertain merchant knowledge [1][3].
- **Dev / systems:**
  ```text
  osmund_piece_kg: 0.283                 # later standard; attested [1]
  osmund_piece_range_kg: [0.260, 0.300]  # later archaeological range; attested [1]
  osmund_barrel_kg: 136                   # Stockholm convention; attested later [1]
  osmund_barrel_game_range_kg: [130,145] # local reconstruction; plausible composite [1]
  osmund_barrel_pieces: 480               # Stockholm convention; attested later [1]
  osmund_last_barrels: 12                 # later commercial convention; attested [1]
  steel_sheet_reval_1343: unknown         # evidence gap [1]
  steel_piece_1368_price: [2.5, 2.8]      # Lübeck marks per 100 pieces; attested later [1][4]
  ```

## Cross-references

- [`../crafts/blacksmith-materials-and-techniques.md`](../crafts/blacksmith-materials-and-techniques.md) - parent forge dossier; keeps Lübeck steel in the `plausible composite` band and needs these weight anchors.
- [`coinage-prices-and-measures.md`](coinage-prices-and-measures.md) - local accounting units, weight ladder, and the existing composite iron-price row.
- [`hanseatic-trade-and-season.md`](hanseatic-trade-and-season.md) - spring shipping season, harbour handling, and the post-23 April supply shock.
- [`reval-harbour-customs-1340s.md`](reval-harbour-customs-1340s.md) - separates later customs control from a missing 1343 quay tariff.

## Open questions

- **Reval 1340-1343 price pass:** locate an AWB, council-account, or private-letter line that prices iron, steel, or osmund in a target-year local unit.
- **Pre-1368 steel form:** locate a dated Livonian or Lübeck record that names *Stahl*, sheet, strip, or rod before the later fifteenth-century steel/sheet evidence.
- **Barrel tare:** determine whether a surviving Reval or Tallinn measure treats the barrel as included weight, separate tare, or merchant convention for osmund.
- **Currency conversion:** establish whether the 1357-1372 Riga/Tallinn öre and veering lines can be safely translated into the project's Lübeck schilling model.

## Sources

1. Mihkel Mäesalu, "Iron Import to Medieval Livonia in the 14th Century," *Tuna* 2 (2024), pp. 12-29, Estonian with English summary. Official article: https://tuna.ra.ee/en/iron-import-to-medieval-livonia-in-the-14th-century-2/ . Full PDF: https://tuna.ra.ee/wp-content/uploads/02-tuna-2-2024-maesalu.pdf . The article cites the 1336 Narva testimony, Riga 1357-1358 accounts, Tallinn 1363-1374 accounts, and the 1368-1369 Lübeck pound-toll lists.
2. Ivar Leimus, "Mark, leisikas ja laevanael: keskaegse Liivimaa kaaluühikutest," *Ajalooline Ajakiri* 4 (2014), pp. 287-302, Estonian with English abstract. Official article page: https://ojs.utlib.ee/index.php/EAA/article/view/11912 .
3. O. Greiffenhagen (ed.), *Tallinna wanimad linna arweraamatud. 1363-1374 = Die ältesten Kämmereibücher der Stadt Reval. 1363-1374*, Tallinn 1927, pp. 10, 30-35, German/Low German. Digital catalogue: https://www.etera.ee/zoom/174199/view .
4. G. Lechner (ed.), *Die Hansischen Pfundzollisten des Jahres 1368 (18. März 1368 bis 10. März 1369)*, Quellen und Darstellungen zur hansischen Geschichte 10, Lübeck 1935, pp. 87, 90, 103, 123, 131, 134, 139, 305, German. Page and entry references are transcribed and discussed in [1].
5. [`../crafts/blacksmith-materials-and-techniques.md`](../crafts/blacksmith-materials-and-techniques.md) - project dossier retaining the 1343 forge decision as `plausible composite` where direct target-year prices are absent.
