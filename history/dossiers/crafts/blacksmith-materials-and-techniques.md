---
domain: crafts
slug: blacksmith-materials-and-techniques
status: solid
consumers: [dev, art, quest, character]
related:
  - ../architecture/smithy-workshop-layout.md
  - guild-structure.md
  - ../military/arms-and-armour-livonia-1340s.md
  - ../economy/coinage-prices-and-measures.md
updated: 2026-07-30
---

# Blacksmith materials and techniques (Spring 1343 Reval)

## Brief for Dev / Art / Quest

You are modelling **Kalev's forge loop** in **April 1343 Lower Town Reval**: what enters the shop, what the fire does to it, how long common jobs take, and what fails when the smith rushes or cheats.

**Ship these decisions:**

1. **Stock on the bench:** Urban masters work **imported Swedish osmund** and **hammered bar** more often than raw Livonian blooms — osmund needs **less charcoal and less prep** than local bloomery iron and was already traded to Livonia by the 1330s [1][2]. Kalev still buys **scrap, nails, and worn tools** for rework.
2. **Steel is imported or bought, not home-smelted:** Better edges come from **Lübeck steel sheet / rod** (15th-c. records are explicit; 1343 presence is `plausible composite` Hanse norm) or from **select osmund pieces** carburised in the forge — not from a full bloomery in the yard [1][3][4].
3. **Charcoal fuel:** **Birch and mixed hardwood charcoal** delivered in sacks or bulk cart loads; a **full commission day** burns roughly **8–15 kg charcoal** for intermittent forging (composite from experimental forge practice) [5][6]. Siege April tightens supply — price rises before quantity zeros [`smithy-workshop-layout.md`](../architecture/smithy-workshop-layout.md).
4. **Fluxes at the forge:** **Dry sand** on the anvil face for forge-welding; **clay** for hearth repair and case-hardening packs; **limestone** is smelting flux, not daily forge flux — do not show lime pots beside the anvil [5][7].
5. **Technique stack:** Heat → draw/upset → (optional) forge-weld → shape → quench or air-cool → temper → finish grind. **Water quench** for tools and blades; **slack quench / partial hardening** reduces warp risk on thin work [8][9].
6. **Durations (master + hot fire, gameplay-scale):** nail **~1 min**; horseshoe pair **45–90 min**; spearhead **3–6 h**; axe head **2–4 h**; batch of twenty arrow points **2–3 h**; hinge strap set **1–2 h**; sword re-hilt / furniture only **4–8 h** (blade import) [10][11][12].
7. **Failure modes:** **Cold shut**, **burn-through**, **quench crack**, **warp**, **poor weld**, **soft edge** (under-carburised), **brittle edge** (over-hard untempered) — each maps to a visible flaw quest and inspection can catch [8][9][13].
8. **Do not model:** Blast-furnace casting in Kalev's shop, industrial coke, crucible steel, or the smith smelting ore from scratch inside the Lower Town plot.

## Findings

### Iron and steel sources

| Material | Form | Origin / route | Smith prep before use | 1343 Reval confidence |
|---|---|---|---|---|
| **Osmund iron** | Fist-sized lumps (~300 g comparandum) in barrels | **Sweden** → Stockholm / Baltic ports → Reval merchants | Light scarfing; less slag than bloom | attested trade by 1336–1363; extensive in 14th c. [1][2] |
| **Hammered bar** | Rectangular bar stock | Osmund hammered at Lübeck hinterland mills or local master's stock | Minimal — ready to heat and draw | `plausible composite` [1][14] |
| **Local bloomery iron** | Bloom / schiene bar | Livonian rural bloomeries (declining) | Heavy forging to de-slag | attested production earlier; **uneconomic by late 1340s** [2][15] |
| **Scrap & rework** | Old nails, hinges, broken tools | Customer trade-ins, scrap heap | Clean, reheat | `plausible composite` daily practice [5] |
| **Steel (edge)** | Sheet, strip, or rod | **Lübeck import** (15th-c. documented); Riga market | Cut inserts, forge-weld to iron body | `plausible composite` for 1343 [1][4] |
| **Imported blade** | Finished sword blade | Solingen / west German trade | Smith hilts only | `plausible composite` [4][12] |

**Regional arc:** Before the mid-14th century rural producers sold bloom to town smiths; after Swedish osmund dominated Hanse routes, **towns controlled import** and guild barriers squeezed rural competitors [2][15]. Kalev's **price pressure from Estonian rural smiths** [`lower-town-street-plan`](../topography/lower-town-street-plan.md) is **economic**, not evidence they use better steel.

**First written iron import to Livonia:** **10 July 1336** — Narva burgher Florekinus de Ermennowe traded grain for copper and iron from Stockholm [1]. **Reval merchant elite** imported osmund by **1363**; **1343** sits in the **already-active** import phase even where documents are silent [1].

### Charcoal

| Topic | Finding | Confidence |
|---|---|---|
| Fuel type | **Charcoal** primary for forge; bituminous coal is **north-German / later British** pattern, not Baltic urban default [5][16] | attested type for medieval forge [5] |
| Wood source | **Birch, alder, pine** charcoal from Harju forests and hinterland stacks; **Saku / forest charcoal routes** in project lore [`docs/TOURIST_LANDMARKS.md`] | `plausible composite` Baltic forestry |
| Delivery | **Tied sacks** as a countable trade unit, carried by cart to the workshop; a 2025 study title quotes the medieval phrase "a sack of good charcoal" [20] | sacks attested in medieval metallurgical supply; Reval route is `plausible composite` |
| Shop storage | Closed delivery sacks plus one open working sack, kept dry in the roofed forge corner and raised on simple timber dunnage; no modern metal coal scuttle [15][20][21] | sacks attested; raised dry corner is `plausible composite` |
| Consumption scale | Experimental bloom-to-bar path: **~100 kg charcoal per 1 kg** finished bar from **ore** (smelting path, not Kalev's daily forge) [6] | attested experiment [6] |
| Forge session | **~0.5–2 kg charcoal per heat** for small work; **8–15 kg** across a full journeyman day of mixed commissions | `plausible composite` from forge practice [5][10] |
| April 1343 stress | Siege timber shortage raises **fire-watch** scrutiny; charcoal **price spike** before stockout is a valid quest beat | quest composite [17] |

**Peat smithing fuel** appears in **Scottish / Hebridean ethnography**, not attested for Reval — do not use for Kalev [16].

### Fluxes and hearth additives

| Substance | Use | At Kalev's forge? | Confidence |
|---|---|---|---|
| **Silica sand** | Forge-weld flux on scarfs; prevents scale | Yes — dry sand on anvil or brazing shovel | attested practice [5][7] |
| **Clay / loam** | Hearth mortar; case-hardening pack around iron in charcoal | Yes — hearth maintenance | `plausible composite` [7] |
| **Charcoal dust** | Carburising pack for case-hardening thin iron | Yes — mail rings, tool faces | attested technique [3] |
| **Limestone / flux stone** | **Smelting** slag chemistry in bloomery | No at bench — wrong process stage | attested separation [3] |
| **Tallow / oil** | Quench slackening, anti-rust wipe | Sometimes — see quench table | `plausible composite` [8][9] |

### Forging and joining techniques

| Technique | Application | Notes | Confidence |
|---|---|---|---|
| **Drawing** | Nails, spikes, tapering bar | Heat yellow-white; strike along length | attested [5][10] |
| **Upsetting** | Nail heads, tool poll | Shorten and widen hot end | attested [5] |
| **Forge welding** | Basket hilts, long straps, axe eye | Scarfs, sand flux, **welding heat** (near white) | attested [5][7] |
| **Slitting / punching** | Hinge barrels, nail header holes | Hot punch, drift | attested [5] |
| **Bending / scrolling** | Straps, hooks | Over horn or mandrel | attested [5] |
| **Case hardening** | Mail rings, chisel faces | Pack in charcoal/clay bake | attested medieval [3] |
| **Carburising by fire** | Small steel quantity | Repeated heat in charcoal fire | attested labor-intensive [3] |

Baltic urban forges use **raised hearths** and **side tuyere** blow — technique matches Hanse smiths, not pit-forge rural sites [15][18].

### Hardening, quenching, and tempering

| Step | Method | Result | Risk | Confidence |
|---|---|---|---|---|
| **Full water quench** | Cold water bucket / trough | Hard, brittle martensite | **Crack, warp** on thin plate | attested norm [8][9] |
| **Interrupted quench** | Pull early when edge colours | Tougher blade | Softer edge if mis-timed | attested Pol Hausbuch tradition [8] |
| **Oil / tallow quench** | Slower cool | Less crack on thin steel | Softer | `plausible composite` [8][9] |
| **Temper** | Reheat to **straw / blue** and air cool | Relieves stress | Over-temper = soft | attested [8][9] |
| **Air cool** | Large soft iron work | Soft wrought | No hard edge | attested [5] |

Medieval smiths judged temper by **colour and sound**, not degrees — gameplay can use **timer + colour cue** [`crafts.blacksmith-materials-and-techniques.02`] [8].

### Task durations and material quantities (systems table)

Assumes **master smith**, **prepped bar stock**, **single hearth**, **apprentice on bellows** for long jobs. Labelled `plausible composite` unless noted.

| Job | Input stock | Charcoal (est.) | Active forge time | Calendar time | Confidence |
|---|---|---|---|---|---|
| 1 wrought nail | ~6 cm bar slice | ~0.1 kg | **~1 min** | instant batch | `plausible composite` [10] |
| 100 nails | ~1.2 m bar | ~3–5 kg | **~1–2 h** | apprentice day task | `plausible composite` [10] |
| Horseshoe (1) | ~0.4–0.5 kg iron | ~1–2 kg | **20–45 min** | per shoe | `plausible composite` [11][12] |
| Horseshoe pair + nails | ~1 kg iron | ~3–5 kg | **45–90 min** | common cart job | `plausible composite` [11] |
| Spearhead socketed | ~0.5–0.8 kg | ~2–4 kg | **3–6 h** | single commission | `plausible composite` [12] |
| Axe head | ~0.6–1 kg | ~2–4 kg | **2–4 h** | farm/Rebel kit | `plausible composite` [5] |
| 20 arrow bodkins | ~0.3 kg | ~1–2 kg | **2–3 h** | militia batch | `plausible composite` [5] |
| Door hinge strap (pair) | ~0.5 kg | ~1–2 kg | **1–2 h** | house call | `plausible composite` [5] |
| Iron cap (chapel) | ~0.4–0.6 kg | ~2–3 kg | **2–4 h** | watch kit | `plausible composite` [13] |
| Sword re-hilt (import blade) | furniture iron | ~1–2 kg | **4–8 h** | not blade forging | `plausible composite` [12] |
| New sword blade from bar | ~1.5–2 kg steel/iron | **10+ kg** | **days** | week-scale with polish | `plausible composite` [12] |
| Forge-weld axe eye repair | scrap + bar | ~2 kg | **1–2 h** | failure recovery | `plausible composite` [7] |

**Gameplay compression:** A full **commission session** in the vertical slice may abstract **one heat cycle** to a player minigame; multi-hour jobs should span **in-game days** or **abstract completion** with stock + charcoal costs.

### Failure modes (quest and inspection hooks)

| Failure | Cause | Visible sign | Gameplay hook | Confidence |
|---|---|---|---|---|
| **Cold shut** | Hammered cold / poor weld | Seam line, flake | Weak gate chain; breaks on stress test | attested type [5] |
| **Burn-through** | Overheat thin section | Hole, thin spot | Haste minigame penalty | attested type [5] |
| **Quench crack** | Water quench on uneven section | Hairline at edge | Sabotaged blade; audible ping test | attested metallurgy [9] |
| **Warp** | Uneven quench / thin plate | Bent strap | Door won't close; gate fit fail | attested [9] |
| **Soft edge** | Skipped quench or low carbon | Edge dents in test cut | Inspection fail on weapon commission | attested [8] |
| **Brittle edge** | Quench without temper | Chips in use | Shatters in climax fight | attested [8] |
| **Slag inclusion** | Poor osmond prep (rare with osmund) | Pit in surface | Lower durability tier | `plausible composite` [2] |
| **Charcoal run-out** | Fuel neglect | Fire dies mid-job | Commission timer fail | `plausible composite` [6] |

Guild **quality inspection** (`Amt` visit) can catch **visible seams, wrong weight, or soft edges** — fines are `plausible composite` until R-041 ordinances land [`guild-structure.md`](guild-structure.md).

### Regional context (Danish Estonia, Hanse, Order)

| Actor | Material relationship |
|---|---|
| **Reval Schmiede *Amt*** | Sets who may sell forged goods; does not supply iron [19] |
| **Hanse merchants** | Import osmund barrels; council elite re-export [1] |
| **Danish crown** | Indirect — toll and market law, not forge fuel [1] |
| **Livonian Order (late April+)** | Bulk arms customer; may demand **priority charcoal** during siege | quest composite |
| **Estonian rural smith** | Cheaper horseshoes from **local bloom + lower labour cost** [2] |

## Reference plates

| Plate | Shows | Source, date, origin | License | Answers |
|---|---|---|---|---|
| [`crafts.blacksmith-materials-and-techniques.01`](../../reference/crafts/blacksmith-materials-and-techniques/crafts.blacksmith-materials-and-techniques.01.png) | Bloomery hearth cross-section (raw iron production chain) | Hofman & Richards, *Metallurgy of Iron and Steel*, 1904 — bloomery comparandum | public domain | what osmund replaced: bloom prep labour |
| [`crafts.blacksmith-materials-and-techniques.02`](../../reference/crafts/blacksmith-materials-and-techniques/crafts.blacksmith-materials-and-techniques.02.png) | Tempering furnace drawing heat zones | Richardson, *Practical Blacksmithing*, 1889 — later technical comparandum | public domain | temper colour / drawing station vocabulary |
| [`crafts.blacksmith-materials-and-techniques.03`](../../reference/crafts/blacksmith-materials-and-techniques/crafts.blacksmith-materials-and-techniques.03.jpg) | Smith drawing flat bar at hearth | Mendel Hausbuch I f. 35a, Nuremberg, c. 1425 | public domain | bar stock drawing before shaping |
| [`crafts.blacksmith-materials-and-techniques.04`](../../reference/crafts/blacksmith-materials-and-techniques/crafts.blacksmith-materials-and-techniques.04.jpg) | Quench tub and steel hardening scene | Agricola *De re metallica*, Basel, 1556 — later comparandum | public domain | water quench placement |
| [`crafts.blacksmith-materials-and-techniques.05`](../../reference/crafts/blacksmith-materials-and-techniques/crafts.blacksmith-materials-and-techniques.05.jpg) | Wrought iron horseshoe finished form | PAS FindID 232991, England, 1200–1400 | cc by-sa 4.0 | horseshoe proportions and nail holes |

## Production hooks

- **Art:** **`crafts.blacksmith-materials-and-techniques.03`** for drawing flat stock; **`.04`** for quench bucket scale; **`.05`** for horseshoe silhouette; indoor charcoal as **tied delivery sacks with one open working sack and visible angular charcoal**, not an ore-rock heap or modern metal scuttle; bar stock **rectangular section**, osmund as **lumpy fist chunks** not modern round bar.
- **Map:** Yard **charcoal crib** separate from **iron scrap pile**; no ore heap at urban plot [`smithy-workshop-layout.md`](../architecture/smithy-workshop-layout.md).
- **Character:** Master judges heat by colour; apprentice runs bellows on long heats; Mart's nail practice is **volume not glamour** [`guild-structure.md`](guild-structure.md).
- **Quest / Narrative:** **Charcoal shortage** during siege; **osmund barrel** delivery convoy [`P4-033`]; **soft-edge sabotage** on weapon commission; rural **cheap shoe** price pressure.
- **Dialogue:** *Osmund* / *Eisen* / *Stahl*; *Kohle* (charcoal); *Amboss*; *Zähne* (temper colours); *Lösch* (quench).
- **Dev / systems:** Model `iron_stock_kg`, `charcoal_kg`, `commission_forge_minutes`; failure flags `cold_shut`, `quench_crack`, `soft_edge`; duration table above; osmund reduces `prep_labour` vs `bloom_iron`.

## Cross-references

- [`../architecture/smithy-workshop-layout.md`](../architecture/smithy-workshop-layout.md) — hearth geometry, charcoal storage, quench station placement.
- [`guild-structure.md`](guild-structure.md) — Schmiede *Amt*, apprentice nail labour, inspection fines.
- [`../military/arms-and-armour-livonia-1340s.md`](../military/arms-and-armour-livonia-1340s.md) — which finished metal goods leave the shop.
- [`schmiede-amt-ordinances-pre-1363.md`](schmiede-amt-ordinances-pre-1363.md) - inspection disputes, visible forge failures, and the distinction between *Amt* remedies and town-law penalties.
- [`../economy/coinage-prices-and-measures.md`](../economy/coinage-prices-and-measures.md) — coin scale, iron/charcoal price rows, siege multiplier.

## Open questions

- **Reval 1343 iron price per kg or per barrel** — partial rows in economy dossier; AWB folio pass still needed (R-042).
- **Steel sheet import to Reval before 1368 Lübeck records** — attested later; 1343 presence uncertain (candidate R-042).
- **Weight standard for osmund barrel** in Reval customs — Swedish *kappe* comparandum [14].
- **Schmiede masterpiece steel requirements** — Tallinn archives pass (R-041).

## Sources

1. Tuna / Estonian National Archives, "Iron Import to Medieval Livonia in the 14th Century," https://tuna.ra.ee/en/iron-import-to-medieval-livonia-in-the-14th-century-2/ — osmund trade, 1336 Narva record, Reval 1363 (English).
2. R. Saage et al., "Smithies and forges around the north-eastern Baltic Sea," *Historical Metallurgy* 51(1), 2017 — osmund transition, guild monopolies, Haapsalu comparanda (English).
3. Medievalware.com, "Late Medieval Steel Revolution" summary of bloomery carburising — case harden and steel quantity limits (English).
4. Wikipedia, "Osmond process" — osmund form, Lübeck hammering, trade routes — use as secondary; cross-check [1] (English).
5. Historical Metallurgy Society, Archaeology Datasheet 303: Iron hand blacksmithing, https://historicalmetallurgy.org/media/mxiorxzr/hmsdatasheet303.pdf — charcoal fuel, hearth, weld flux, tools (English).
6. P. Crew & C. J. Salter, experimental bar iron production — ~100 kg charcoal per 1 kg bar from ore; ~25 man-days smelting path (English).
7. HMS / forge-weld experimental literature summarised in Datasheet 303 — sand flux scarfs (English).
8. Arms & Armor blog, Historical Sword Making heat treatment series — Pol Hausbuch quench/temper, colour judgement (English).
9. A. R. Williams, slack quench vs full quench armour steel — crack/warp risk (English summary).
10. Nail production rates summarised from historical smithing practice — ~36–60 s per nail, ~100/hr apprentice batch (English web synthesis; treat as composite).
11. J. Clark, *Medieval Horseshoes*, PAS datasheet 4, 1986 — shoe dimensions 115–120 mm width late medieval (English).
12. Wulflund / experimental swordsmithing summaries — ~8 h rough blade forge; week complete sword (English).
13. [`arms-and-armour-livonia-1340s.md`](../military/arms-and-armour-livonia-1340s.md) — commission item list (project dossier).
14. Osmond *kappe* weight, Novgorod 1203 treaty — Wikipedia osmond article citing customs records (secondary).
15. [`smithy-workshop-layout.md`](../architecture/smithy-workshop-layout.md) — charcoal delivery, siege shortage (project dossier).
16. Dungworth & Bayley slag fuel analysis — charcoal dominant medieval smithing fuel (English).
17. [`watch-duty-and-town-defence.md`](../military/watch-duty-and-town-defence.md) — siege curfew and fire watch (project dossier).
18. A. Pärn & E. Russow, Haapsalu smithies 13th–14th c. — raised forge Baltic urban (German).
19. [`guild-structure.md`](guild-structure.md) — Schmiede *Amt* obligations (project dossier).
20. A. Fostikov, "A Sack of Good Charcoal: Production and Use of Charcoal in Metallurgy in Medieval Serbia and Czechia," Historical Institute Belgrade, 2025, https://doi.org/10.34298/ZR9788677431600.F095 - medieval metallurgical charcoal supply and the sack as an explicit trade unit (English abstract; Serbian study).
21. U.S. National Park Service, "Charcoal House," Hopewell Furnace, https://www.nps.gov/hofu/charcoal-house.htm - later ironworks comparandum for wagon delivery and the operational need to keep charcoal dry; not direct evidence for Reval 1343.
