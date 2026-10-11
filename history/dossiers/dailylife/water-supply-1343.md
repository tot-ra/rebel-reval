---
domain: dailylife
slug: water-supply-1343
status: partial
consumers: [art, map, character, dev]
related: [dailylife/hygiene-and-grooming-1343, dailylife/food-and-drink, architecture/burgher-house-plan, architecture/rural-smoke-dwelling-and-farmstead-1343]
updated: 2026-10-12
---

# Household water supply in Reval and its villages (spring 1343)

Builds on section 1 of [`reval_domestic_infrastructure_1343.md`](../../../docs/reports/reval_domestic_infrastructure_1343.md)
(wells, drains, mills, harbour water, with P0-072 evidence classes). This dossier adds the town's
piped-water chronology, the vessels people carried and stored water in, who fetched it, and the rural
sweep well. The game design that uses it is [`docs/SYSTEMS/WATER_SUPPLY.md`](../../../docs/SYSTEMS/WATER_SUPPLY.md).

## Brief for art, map and dev

1. **In 1343 Reval drinks from wells, not pipes.** The Danish king granted the town the right to lead
   Ülemiste water in by a canal in **1345**; the stone conduit to the Harju gate is mid-14th century
   and timber pipes to public street wells are late 14th / early 15th century. All three are
   **after** the campaign date: exclude them (period rule: dated-later features are not shown) [2][3][4].
2. **Wells:** private wells in rear yards of burgher and craft plots, a few precinct wells (Dominican
   close, Bishop's garden) and a castle well. Not a well on every street corner [1].
3. **Rataskaev (Wheel Well) is 1375** in the record [7]; its wheel superstructure is excluded. A plain
   street well on the Rataskaevu belt is at most **B/C** [1].
4. **Town well form is unknown** (stone-lined shaft vs timber box) [1]. Author a limestone-lined shaft
   (the town stands on limestone and builds in it) with a low curb or a square timber collar and a
   board lid; lift by windlass or sweep. Label `plausible composite`.
5. **Village well:** a log-crib well (`salvkaev`) with a sweep (`vinnkaev`, `kaevuvinn`): forked post,
   long pole, stone counterweight, hook pole and bucket. Known from ethnography and surviving later
   wells; the 1343 form is unknown, so use the simplified later form [5][6].
6. **Vessels are coopered wood:** stave buckets with withy hoops, a covered water tub by the hearth
   with a wooden dipper, rain butts under eaves channels. Iron-hooped or tinned-iron buckets only for
   the castle or rich houses (`plausible composite`).
7. **Carrying:** by hand or on a shoulder yoke with two buckets. The yoke is a long-lived North and
   East European tool; 1343 Reval evidence is **U**, use it as `plausible composite` colour for
   servants and women.
8. **Who fetches:** servants, maids, women and children; a licensed water-carrier trade in 1343 Reval
   is **unknown** [1].
9. **Drink:** beer and small beer are the everyday drink; water is for cooking, brewing, washing,
   animals and the forge [8]. Do not drink from harbour, moat or ditch (B rule) [1].

## Findings

### Town supply chronology

| Date | Fact | Confidence | Use in 1343 |
|---|---|---|---|
| 13th c. | Mills on the Härjapea river (outflow of Lake Ülemiste) | attested [3][4] | river and mill pond exist |
| 1325 | Rataskaevu name | B/C [1] | at most one plain street well |
| **1345** | Valdemar IV grants Reval the right to lead Ülemiste water to the town (canal) | attested [2][3] | **not yet** |
| mid-14th c. | Underground stone conduit brings lake water to the Harju gate | attested secondary [2] | **not yet** |
| 1375 | Wheel Well (Rataskaev) recorded | attested [7] | excluded |
| late 14th / early 15th c. | Timber pipes from mill ponds to public street wells | attested secondary [2] | excluded |
| 1860 | Timber pipes replaced with cast iron, public taps | attested [2] | excluded |

So the 1343 town lives on wells, rain water and the Härjapea. That makes the well a daily social
place and a chore, which suits the game.

### Wells in town

- Attested 1343-relevant wells: courtyard wells in the western Lower Town, the Bishop's garden well
  on Toompea, a courtyard well at the Dominican friary [1].
- The burgher-house typology puts a well (or a well sweep) in the rear yard with privy, sheds and
  garden [9]. Private wells sit in yards; public wells are few named points [1].
- Construction, depth and lining of an ordinary 1343 well are **unknown** [1]. Lower Town groundwater
  lies near the surface towards the sea; Toompea stands on a limestone plateau, so a castle well
  there would be deep. Depth figures are **U**; the model only implies depth by a fake shaft.

### Rural wells

- Estonian `salvkaev` (log-crib well) with a sweep: the sweep (`kaevuvinn`, dialect `jung`, `ling`,
  `roog`, `vibu`, `valdas`) is a long pole on a forked post (`kaevusammas`) with a counterweight;
  the hook pole (`kaevukook`) carries the bucket [5][6].
- Oberschneider (2019): crib wells were central to Estonian village landscapes, since only a clean
  water source allowed permanent settlement [6]. Surviving examples are 18th-20th c.; treat the 1343
  form as `plausible composite (simplified later form)`.
- Springs and brooks serve farmsteads too; a low log box over a spring is a plain alternative.
- The project's farmstead dossier already lists a well among the yard features [10].

### Vessels and storage

- **Bucket:** coopered staves with withy or wooden hoops, two raised stave ears and a rope or withy
  bail. Coopers worked in Reval; coopered vessels are the normal medieval Baltic container
  (`plausible composite`). Capacity ~10-12 l is a **D** gameplay value, not a measurement.
- **Kitchen tub:** the burgher-house kitchen inventory has a water bucket by the hearth [9]; a larger
  covered tub with a dipper is the `plausible composite` daily store (fill in the morning, cover
  against ash and dust).
- **Rain butt:** wooden roof channels feeding a barrel are `plausible composite` [1][11].
- **Drinking vessels:** jugs and cups are already in the object catalog (`obj.jug`, `obj.cup`).

### Carrying and carriers

- Two buckets on a shoulder yoke or by hand. Yokes are common in later Baltic, Russian and German
  folk use; 1343 Reval proof is **U**.
- Fetching water is servant, women's and children's work in the hygiene and food dossiers
  (`plausible composite`) [8][11]. A licensed water-carrier craft in Reval 1343 is **U** [1].

### Uses and amounts

Cooking (pottage, porridge), brewing (large volumes; brewers want the river or a good well), washing,
animals, the forge (slack tub). Per-person daily water use in 1343 is **U**; the game uses an
`invented` (D) 5-8 l per person per day for household use, labelled as such.

## Production hooks

- **Art:** coopered pine/spruce staves, grey weathered; withy hoops (twisted hazel/willow); hemp rope;
  limestone curb with lime mortar; silvered board lids; sweep pole of a peeled spruce trunk with a
  lashed field stone. Concept refs: [`docs/reports/images/water_supply/`](../../../docs/reports/images/water_supply/concept_yard_well_yoke.jpg)
  (AI concept images; known errors listed in WATER_SUPPLY.md).
- **Map:** yard wells in rear yards, at least ~6 m from the privy; public wells only at the named
  points; one sweep well on a village common plus farmstead wells.
- **Character:** carriers are maids, wives, daughters, apprentices and children; a yoke marks a servant
  or a woman of a poorer household.
- **Quest / Narrative:** the well as a gossip point; a fouled or frozen well; a dispute over a shared
  yard well (the census cards already have "draw from one back-yard well on an unwritten rota").
- **Dev / systems:** 1-3 trips a day per household; 20-25 l per yoke trip; 20-40 s at the well.

## Cross-references

- [`../../../docs/reports/reval_domestic_infrastructure_1343.md`](../../../docs/reports/reval_domestic_infrastructure_1343.md) - evidence classes and the water authoring table.
- [`hygiene-and-grooming-1343.md`](hygiene-and-grooming-1343.md) - wash water, yard bucket, well sweep.
- [`food-and-drink.md`](food-and-drink.md) - beer as everyday drink, water for labourers and peasants.
- [`../architecture/burgher-house-plan.md`](../architecture/burgher-house-plan.md) - rear-yard well and kitchen water bucket.
- [`../architecture/rural-smoke-dwelling-and-farmstead-1343.md`](../architecture/rural-smoke-dwelling-and-farmstead-1343.md) - farmyard with well.

## Open questions

- Find a published excavation of a 13th-14th century Tallinn well (lining, depth, collar) to replace the composite town well form.
- Confirm the Estonian folk term for the water yoke (candidates `kaelkoogud`, `kandepuu`) from the Estonian Open Air Museum or the ERM collection.
- Find evidence for coopers' guild or cooperage finds in 14th-century Tallinn to raise the bucket form from composite to attested.
- Read Kadakas (ed.), *Puhas vesi Tallinna ajaloos*, for 14th-century well locations and the exact date of the Harju-gate conduit.

## Sources

1. Project report, [`docs/reports/reval_domestic_infrastructure_1343.md`](../../../docs/reports/reval_domestic_infrastructure_1343.md), section 1 Water, 2026-09-26 (and its sources).
2. Rohegeenius, "Puutorude ajast tänapäevani - Eesti veevärkide ajalugu ulatub 13. sajandisse", Geenius / Delfi, 22.03.2022, https://geenius.delfi.ee/artikkel/120528523 (Estonian; based on V. Kadakas (ed.), *Puhas vesi Tallinna ajaloos*, Tallinna Linnamuuseum / Tallinna Vesi).
3. "Härjapea river", WanderTrails, https://wandertrails.app/places/harjapea-river-tallinn (English; 1345 grant; secondary).
4. "Veerenni kanal", WeskiWiki, https://weskiwiki.ee/index.php/Veerenni_kanal (Estonian).
5. "Vinnkaev" and "Kaevuvinn", Estonian Wikipedia, https://et.wikipedia.org/wiki/Vinnkaev, https://et.wikipedia.org/wiki/Kaevuvinn (Estonian).
6. L. Oberschneider, "Vinnaga salvkaevu taastamine", *Studia Vernacula*, 2019, https://ojs.utlib.ee/index.php/SV/article/download/17015/11891/18270 (Estonian; only the abstract was read).
7. "Wheel Well", aroundus.com, https://aroundus.com/p/11266222-wheel-well (English; 1375 record; secondary).
8. [`food-and-drink.md`](food-and-drink.md) (project dossier).
9. [`../architecture/burgher-house-plan.md`](../architecture/burgher-house-plan.md) (project dossier).
10. [`../architecture/rural-smoke-dwelling-and-farmstead-1343.md`](../architecture/rural-smoke-dwelling-and-farmstead-1343.md) (project dossier).
11. [`hygiene-and-grooming-1343.md`](hygiene-and-grooming-1343.md) (project dossier).
