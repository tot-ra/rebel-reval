---
domain: nature
slug: working-horses-and-draught-tack-1343
status: partial
consumers: [art, dev, map, quest]
related:
  - spring-climate-and-living-world.md
  - ../economy/merchant-cart-and-transport-1340s.md
  - ../crafts/blacksmith-materials-and-techniques.md
updated: 2026-08-27
---

# Working horses and draught tack (Spring 1343 Reval)

## Brief for Art / Dev

Build a useful town-and-road horse, not a named breed or a tournament warhorse.

1. Use two visual scale tiers: a compact worker proxy at roughly 125–135 cm at the withers and a larger freight proxy at roughly 135–145 cm. These are production envelopes, not a 1343 measurement [2].
2. Keep the body moderate and serviceable: medium neck, ordinary head, lightly slender lower legs, and practical hooves. Avoid heroic mass, extreme refinement, and decorative feathering [2][3].
3. Permit restrained coat variation without claiming a colour distribution. Do not make one coat the Estonian type [1][2].
4. Pair a single horse with the small two-wheel cart; use a plain leather draught arrangement and shafts. Keep straps, collar/breast support, traces, and bit visually legible but sparse [4].
5. Use a simple iron-shod or unshod hoof option; a horseshoe is a prop decision, not proof of a Reval shoe pattern [4][5].
6. Reserve larger animals and multiple teams for heavy freight. Do not turn every lane cart into a war wagon [4].

## Findings

### Presence and regional scale

- Horses were present in the Spring 1343 living-world and transport brief: the project season dossier places horses on foreland pasture and in penned yards, while the transport dossier makes the horse the default draught animal for burgher supply and Harju carting [6][4]. This is `plausible composite` for scene placement, with the uprising and exact Reval stable inventories remaining unquantified.
- A Tallinn/Kadriorg salvage excavation supplies one direct local faunal datapoint: the medieval wreck Peeter, built after AD 1296 and probably grounded in the second quarter of the 14th century, yielded one horse occipital from a young individual. The authors caution that it came from outside the wreck and may have arrived by chance, so it confirms neither a shipboard horse nor urban horse density [8]. This is `attested` for the reported find and `plausible composite` only as weak confirmation that horse remains occur in the wider medieval Tallinn coastal record.
- The Estonian horse is documented as a strategically controlled commodity in the medieval Baltic, including export certification at Narva. This supports treating horses as valuable working stock rather than disposable generic scenery, but it does not identify a breed or a Reval owner's animal [1]. This is `attested` for the trade-control claim and a `plausible composite` production implication.
- A large eastern-Baltic comparative study reports a persistent small local type around 118–125 cm in its Viking-period material, alongside a wider 12th–14th-century range and an expansion of 140–150 cm individuals. The sample is Lithuanian, not Reval, and does not separate cart horses from riding horses [2]. This is `attested` for that study and `plausible composite` when used as a regional scale envelope.
- A 13th-century midden at Karksi Castle in southern Estonia included a single `Equus caballus` rib among a much larger animal-bone assemblage. The authors interpret the assemblage mostly as food waste and do not provide horse measurements, pathology, sex, or use [9]. This is `attested` for the local comparative find, but it is not evidence for Reval horse form or working specialization.
- Cēsis evidence confirms that sizeable horses and riding tack existed in Livonia, but its dated assemblage is late 15th/early 16th century and military-associated. It must not set the default 1343 worker silhouette [3]. This is `attested` as a late comparative and an explicit chronological limit.

### Body, legs, head, and hoof

- No reviewed source supplies a 1343 Reval horse skeleton with body measurements, sex, coat, or work specialization [1][2][3][8][9]. The Kadriorg occipital is explicitly a single young-animal find of uncertain association, while the Karksi rib is a single food-waste-context comparative; neither supports reconstruction of body form or use. This remains an evidence gap; assigning exact values here would be `invented`, not research.
- For a production proxy, keep the worker silhouette compact to medium, with a moderately deep barrel, ordinary head, medium neck, and lightly slender lower legs. This transfers the eastern-Baltic comparative pattern conservatively and is `plausible composite` [2]. Do not imply that every animal shares it.
- Hoof treatment can read as plain and work-worn. A 1200–1400 English horseshoe is a chronological comparandum in the existing craft evidence, while a Karksi hoof ice spike is an Estonian regional find with mixed/disturbed context and should not be treated as a shoe or a Reval pattern [5][10]. These are `plausible composite` production references; exact Reval shoe dimensions, nail pattern, ice spike use, and prevalence are an evidence gap and any fixed local measurement would be `invented`.
- Use neutral coat slots and restrained markings only. Coat frequency, mane length, leg white, and sex-linked colour differences are an evidence gap for Reval 1343 [1][2][8][9]; a fixed distribution would be `invented`.

### Draught harness and tack

- The transport dossier supports a single horse between shafts for the default two-wheel cart and identifies multi-horse hauling as a heavy-load exception [4]. This is `plausible composite`, not an excavated Reval harness set.
- The visible tack set should therefore be minimal: bridle or bit when steering is needed, a plain leather collar or breast support, traces, shafts, and simple fastening points. Exact collar, hames, pad, and strap geometry in Reval 1343 is an evidence gap; the sparse set is `plausible composite` from the cart brief and northern-European comparanda [4][7]. The Karksi harness fitting is only a single regional object, described as an iron fitting originally silver-covered and reported from an excavation area whose associated finds include a 14th-century crossbow bolt and later 15th-century material; it cannot establish a date for the fitting, Reval harness construction, or decoration [10].
- Decorative brass harness, modern synthetic webbing, Western saddle styling, and mounted-warhorse armour are explicit exclusions. No source reviewed here supports them for a working cart horse in Spring 1343 [3][4][10]. This is `invented` as a production exclusion, not a historical claim.

## Production hooks

- **Art:** Build one neutral working-horse mesh with two scale presets (worker and freight), medium proportions, plain mane/tail, restrained coat slots, optional worn iron shoe, and a removable draught rig. Keep the silhouette readable at cart distance; do not bake named-breed traits [1][2].
- **Map / Quest:** Place tethered horses at foreland yards, inns, harbour approaches, and cart staging points; use larger teams only for heavy freight or wall-yard work [4][6].
- **Dev:** Expose `withers_height_cm` as a presentation range of `125-145` with a `worker|freight` role, not a canon species field. Keep `coat_pattern` unconstrained and `tack_profile: plain_draught` separate from `riding_tack`. [2][4]
- **Cart pairing:** Default `cart_2w` uses one horse in shafts; `wagon_4w` may use a larger team. Preserve the existing `wheel_rut_spacing: 1.3` cart contract rather than deriving horse dimensions from the cart [4].
- **Smithy pairing:** A plain shoe can be a repair prop or forge commission; do not turn the comparative English shoe or the Karksi ice spike into a local archaeological claim [5][10].
- **Evidence boundary:** The Kadriorg horse bone is a useful local presence check but not a tack, conformation, or stable-density signal; keep `withers_height_cm`, `coat_frequency`, `horse_pathology`, and `Reval_harness_measurements` as `null`/gap until a dated local osteological or fitting study is available [8].

## Explicit exclusions

- No named breed, exact colour distribution, or claim that a modern Estonian Native profile survives unchanged into 1343.
- No exact Reval body measurements, sex ratio, age distribution, or work-specific conformation without a dated local osteological study.
- No modern riding saddle, synthetic harness, Western tack vocabulary, decorative parade harness, or fantasy armour.
- No generated image is evidence. Existing generated horse assets may be audited separately by Art, but are not historical plates for this dossier.

## Reference plates

All plates below are link-only comparanda. They are evidence prompts, not game assets and not direct proof of a Spring 1343 Reval horse.

| Plate | Shows | Source, date, origin | License | Answers |
|---|---|---|---|---|
| `nature.working-horses-and-draught-tack-1343.01` (link-only) | Eastern-Baltic horse osteometry and medieval comparative figures | Kurila et al., *Animals* 12 (2022), Lithuania, 3rd–14th c. | CC BY 4.0 (article; verify figure rights before fetch) | Scale range and measurement limits |
| `nature.working-horses-and-draught-tack-1343.02` (link-only) | Livonian horse remains and associated equestrian equipment | Pluskowski et al., *Medieval Archaeology* 62 (2018), Cēsis, late 15th/early 16th c. | CC BY-NC 4.0; link-only | Late Livonian comparison and chronological exclusion |
| `nature.working-horses-and-draught-tack-1343.03` (link-only) | Medieval horse team illustration | Wikimedia Commons, 1350–1450 comparandum | public domain (source page) | Broad team silhouette; no Reval-specific detail |
| `nature.working-horses-and-draught-tack-1343.04` (link-only) | Karrenmann, two-wheel cart, and horse | Mendel Hausbuch I 110r, 1494, Nuremberg | public domain | Later cart pairing and shaft read |
| `nature.working-horses-and-draught-tack-1343.05` (link-only) | Late medieval iron horseshoe | PAS FindID 232991, 1200–1400, England | CC BY-SA 4.0 | Plain shoe silhouette; not regional proof |

## Cross-references

- [`spring-climate-and-living-world.md`](spring-climate-and-living-world.md) - season, pasture, penned livestock, and Spring 1343 placement.
- [`../economy/merchant-cart-and-transport-1340s.md`](../economy/merchant-cart-and-transport-1340s.md) - cart classes, single-horse shafts, loads, and traffic staging.
- [`../crafts/blacksmith-materials-and-techniques.md`](../crafts/blacksmith-materials-and-techniques.md) - horseshoe evidence and forge/repair pairing; its English horseshoe remains a comparative plate, while Karksi supplies only a regional ice-spike comparator [5][10].

## Open questions

- Can a dated Reval/Tallinn 13th–14th-century zooarchaeological report provide withers height, sex, age, pathology, or work-use evidence for horse remains?
- Is there a securely dated Livonian or North German 14th-century draught-harness find with enough surviving leather or fittings to replace the plain-tack proxy?
- Can a rights-cleared 14th-century Baltic or North German image show a working horse without relying on later manuscript comparanda?

## Sources

1. Rahvusarhiiv / *Tuna*, “The Estonian Horse - A Strategic Commodity in the Middle Ages,” export-control evidence and Narva certificates: https://tuna.ra.ee/en/the-estonian-horse-a-strategic-commodity-in-the-middle-ages/ (English).
2. L. Kurila, A. Zagurskyte, V. Micelicaite et al., “Horses in Lithuania in the Late Roman–Medieval Period (3rd–14th C AD) Burial Sites,” *Animals* 12 (2022), 1549, DOI: https://doi.org/10.3390/ani12121549 (open article; eastern-Baltic comparative osteometry).
3. A. Pluskowski, K. Seetah, M. Maltby, R. Banerjea, S. Black, and G. Kalnins, “Late-Medieval Horse Remains at Cesis Castle, Latvia, and the Teutonic Order's Equestrian Resources in Livonia,” *Medieval Archaeology* 62 (2018), 351–379, DOI: https://doi.org/10.1080/00766097.2018.1535385 (accepted manuscript; late comparative only).
4. [`../economy/merchant-cart-and-transport-1340s.md`](../economy/merchant-cart-and-transport-1340s.md) - project dossier, cart typology and single-horse shaft brief.
5. [`../crafts/blacksmith-materials-and-techniques.md`](../crafts/blacksmith-materials-and-techniques.md) - project dossier, horseshoe plate and forge context.
6. [`spring-climate-and-living-world.md`](spring-climate-and-living-world.md) - project dossier, Spring 1343 livestock and pasture placement.
7. Encyclopaedia Britannica, “Horse collar,” general historical technology summary: https://www.britannica.com/technology/horse-collar (secondary comparative source; not Reval-specific).
8. M. Roio, L. Lõugas, A. Läänelaid, L. Maldre, E. Russow, and Ü. Sillasoo, “Medieval ship finds from Kadriorg, Tallinn,” *Archaeological Fieldwork in Estonia 2015*, 139–158: `history/AVE2015_15_Roiojt_Kadriorg.pdf` (English; local salvage report and faunal table).
9. H. Valk, E. Rannamäe, A. D. Brown, A. Pluskowski, and M. Badura, “Thirteenth century cultural deposits at the castle of the Teutonic Order in Karksi,” *Archaeological Fieldwork in Estonia 2012*, 73–92: `history/AVE2012_Valkjt_Karksi.pdf` (English; southern-Estonian 13th-century midden and zooarchaeological summary).
10. H. Valk, A. Pluskowski, A. D. Brown, E. Rannamäe, M. Malve, and L. Varul, “Karksi ordulinnus: esialgseid kaevamistulemusi,” *Archaeological Fieldwork in Estonia 2011*, 47–56: `history/AVE2011_Valkjt_Karksi.pdf` (Estonian; local excavation summary, harness fitting and hoof ice-spike captions/context).
