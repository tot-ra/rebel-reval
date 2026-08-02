---
domain: economy
slug: ev2-karrienpforte-carter-ort-folio
status: partial
consumers: [map, quest, dialogue, dev]
related:
  - pr-voorimees-garden-coastal-gate.md
  - awb-fuhr-servitude-clauses-1340-1343.md
  - merchant-cart-and-transport-1340s.md
updated: 2026-08-02
---

# EV II *Karrienpforte* garden entries and the carter-owner gap

## Brief for Canon Keeper / Map / Quest / Dialogue

This folio pass tests Kaplinski 1975, fn. 99 against the public-domain scan of Nottbeck's EV II (*Das zweitälteste Erbebuch der Stadt Reval*, 1360-1383).

**Ship these decisions:**

1. EV II directly preserves named *ortum* holders outside the *Karrienpforte*, including **Borchardus myt der Have** in no. 686 (printed p. 101) and **Nicolaus Strokerke** in no. 859 (printed p. 132) [1].
2. Neither direct gate-plot entry calls its named holder a *Fuhrmann*, *voorimees*, or carter. These are named gate-garden holders, **not a named carter deed** [1].
3. Kaplinski's statement that two cooper gardens and one carter garden lay before the Coastal Gate remains an **attested aggregate** from the EV/PR survey [2]. Fn. 99 is an index list for the garden evidence, not a claim that every listed entry names the carter owner [2].
4. Do not assign **Borchardus myt der Have**, **Nicolaus Strokerke**, or any other EV II name to the carter plot without a manuscript/folio collation that supplies the profession link [1][2].
5. EV II begins in 1360, so these records cannot by themselves produce an April 1343 owner deed; the Spring-1343 placement remains a cross-period reconstruction [1][2].

## Findings

### Method and evidence boundary

The public-domain digital object is the 1890 EV II edition held by the Kujawsko-Pomorska Digital Library (KPBC). Its download package contains the complete 159-page DjVu object. I searched the edition's OCR layer for *karienporten*, *Karrienpforte*, *Fuhrmann*, *Fuhr*, *Karren*, and related carter terms, then checked the two gate-plot readings against the page images. OCR spelling is retained where it matters; normalised translations are marked as such [1].

The pass checked the EV II numbers listed by Kaplinski in fn. 99: **352, 454, 515, 566, 676, 690, 691, 786, 823, 824, 829**. The listed entries do not yield a named carter owner in the published text. The gate-formula entries below are useful controls, but no. 686 and no. 859 are not a licence to reassign the aggregate carter garden to their named holders [1][2].

### Direct EV II gate-plot readings

| EV II entry | Printed page | Verbatim edition reading | Production reading | Confidence |
|---|---:|---|---|---|
| **686** | **101** | `Anno quo supra feria 6 pasce dominus Johannes Kurowen resignavit unum ortum, situm extra karienporten juxta Engelbertum, Borchardo myt der Have dicto hereditarie possidendum.` | On 15 April in the entry's 1379 sequence, Johannes Kurowen transferred one garden outside the *Karrienpforte*, beside Engelbert, to **Borchardus myt der Have** for hereditary possession. The text names a plot and holder, but no carter occupation. | attested [1] |
| **859** | **132** | `Eodem anno Nicolaus Strokerke resignavit ortum suum exteriorem extra karienporten Ghossehalco van Rode hereditarie possidendum.` | Nicolaus Strokerke transferred his outer garden outside the *Karrienpforte* to **Ghos(s)chalcus van Rode** for hereditary possession. Again, the entry does not identify a carter. | attested [1] |

The formula *extra karienporten* is therefore directly attested in EV II, and named plot holders are directly attested. The **owner-profession link is not**: neither reading contains *Fuhrmann*, *voorimees*, *carrarius*, or an equivalent occupational label [1].

### Kaplinski fn. 99 and the aggregate carter garden

Kaplinski writes that, on the sea side of the town, the Coastal Gate area held **two gardens belonging to coopers (*püttsepad*) and one belonging to a carter (*voorimees*)** in the fourteenth century. Her footnote 99 supplies a group of EV II, EV III, and PR numbers for the garden survey. The prose does not identify which one numbered deed belongs to the carter, and the cited EV II list does not contain a named *voorimees* in the published text checked here [2].

| Claim | Evidence result | Confidence |
|---|---|---|
| Garden outside the *Karrienpforte* | EV II nos. 686 and 859 give direct *ortum ... extra karienporten* readings | attested [1] |
| Named holders of gate plots | Borchardus myt der Have; Ghos(s)chalcus van Rode | attested [1] |
| One carter garden before the Coastal Gate | Kaplinski's fourteenth-century aggregate | attested aggregate [2] |
| Named carter owner | Not isolated in the published EV II text or fn. 99 prose | gap [1][2] |
| April 1343 deed | Not possible from EV II's 1360-1383 date span | gap [1] |

## Production hooks

- **Map:** Keep `GARDEN-COAST-01` as three slots: two cooper and one carter, with `owner_names: null` for the carter. The EV II readings support the gate-direction formula and extramural garden class, not a precise gate-adjacent footprint [1][2].
- **Quest / Narrative:** A clerk may quote *ortum extra karienporten* and name an unnamed carter's plot as an aggregate tradition. Do not give the carter the names **Borchardus myt der Have** or **Ghos(s)chalcus van Rode** [1].
- **Dialogue:** Retain *Karrienpforte*, *ortum*, *hereditarie*, *voorimees*, and *püttsepp* as source-grounded vocabulary. Label the carter-owner name as unknown until a TLA folio collation resolves it [1][2].
- **Dev:** `carter_plot_coastal_gate: true`; `confidence_tier: attested_aggregate`; `named_carter_owner: null`; `ev2_gate_formula: attested`; `ev2_named_gate_plot_holders: [Borchardus_my_t_der_Have, Ghos(s)chalcus_van_Rode]`.

## Reference plates

No new licensed visual plate was found or required for this text-only folio pass. The parent dossier's Coastal Gate and garden comparanda remain the visual evidence set; the EV II scan is the primary textual evidence [1].

## Cross-references

- [`pr-voorimees-garden-coastal-gate.md`](pr-voorimees-garden-coastal-gate.md) - parent dossier corrected here with direct EV II readings and the named-carter evidence boundary.
- [`awb-fuhr-servitude-clauses-1340-1343.md`](awb-fuhr-servitude-clauses-1340-1343.md) - separates the attested carter profession/plot aggregate from the un-attested *Fuhr* rent claim.
- [`merchant-cart-and-transport-1340s.md`](merchant-cart-and-transport-1340s.md) - supplies the production vehicle and carter-labour context without inventing a deed owner.

## Open questions

- Collate the relevant Tallinn City Archives / TLA EV or Tiik extract folios against Kaplinski fn. 99 to determine whether the carter profession is attached to one of the numbered deeds or only to an aggregate table.
- Locate a pre-1360 AWB entry, if one exists, that links a named carter to an *ort* before the *Karrienpforte*; do not back-date EV II no. 686 or no. 859.

## Sources

1. E. von Nottbeck, ed., *Das zweitälteste Erbebuch der Stadt Reval (1360-1383)*, Reval: Franz Kluge, 1890, EV II, Latin/German. Public-domain digitisation: [KPBC edition metadata and viewer](https://kpbc.umk.pl/dlibra/publication/31505/edition/40617/content), [public download package](https://kpbc.umk.pl/Content/40617/download/). EV II nos. 686 (printed p. 101) and 859 (printed p. 132) were checked in the complete 159-page object.
2. K. Kaplinski, "Käsitöölised Tallinna sotsiaalses struktuuris XIV sajandil II," *Eesti NSV TA Toimetised* 24:1 (1975), pp. 41-62, esp. p. 52 and fn. 99, Estonian. [Open PDF](https://kirj.ee/wp-content/plugins/kirj/pub/proc.hum.soc.sci-1975-1-41-62_20240517151355.pdf). Kaplinski gives the two-cooper/one-carter aggregate and the EV II/III/PR index list; she does not name the carter owner in that passage.
3. [`pr-voorimees-garden-coastal-gate.md`](pr-voorimees-garden-coastal-gate.md) - project dossier containing the prior aggregate verdict and production hooks.
