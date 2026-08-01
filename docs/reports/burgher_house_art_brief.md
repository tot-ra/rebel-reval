# Lower Town burgher-house art brief

**Task:** A-008 / R-5
**Historical anchor:** Spring 1343 Reval, Lower Town
**Primary dossier:** [`history/dossiers/architecture/burgher-house-plan.md`](../../history/dossiers/architecture/burgher-house-plan.md) (R-003, status `solid`)
**Production contract:** [`docs/reports/burgher_house_typology_contract.md`](burgher_house_typology_contract.md) (P0-163)
**Evidence status:** The plates in this brief are synthetic Blender studies for non-runtime art direction. They are not archaeological reconstructions, licensed source photographs, or runtime assets.

## 1. Brief ship decisions

Use these studies to author ordinary Lower Town house families, not landmark buildings. The model language is a narrow 7-11 m strip plot with the gable end facing the street and the ridge perpendicular to the lane. Keep the house tall and deep rather than wide and monumental. A steep roof silhouette is required, but the roof cover follows wealth and ward rather than a citywide uniform material.

The visual target is a lived-in 1343 burgess plot:

- mixed timber and stone fabric can coexist in the same street block;
- a street-front house has a readable cellar neck or low threshold where the plot allows it;
- the merchant ground-floor sequence is street portal -> diele/workshop-shop hall -> chimney-kitchen zone -> dornse/rear room -> yard;
- upper merchant levels read as storage and loading, with small openings or hatches rather than a wall of domestic windows;
- rear yards contain service circulation, a gate or fence to the back lane, a well or water point, firewood, and a modest privy or lean-to;
- materials use local grey limestone, limewashed or plastered timber, tar-dark shingles, and selective red-brown tile on affluent stone masses.

Do not turn these silhouettes into post-1400 tourist facades. Ornament is subordinate to massing, roof pitch, material contrast, and plot circulation.

## 2. Tier matrix

| `house_tier` | Art read | R-003 confidence | Required silhouette and facade cues | Roof and material band | Explicit omissions |
|---|---|---|---|---|---|
| `merchant_stone` | Affluent merchant front, stone or mixed street frontage, diele-dornse plus cellar | **Attested typology; per-house material mix is plausible composite** | 2-3 storeys; narrow tall gable; stone portal and one larger ground opening; smaller upper openings; storage hatches; optional projecting hoist beam and pulley | Limestone or mixed stone/timber; tile is preferred on the affluent mass, with timber service buildings behind | No four-light crosses, blind niches, rich Gothic tracery, universal facade carving, or modern Peppersack restaurant dressing |
| `merchant_timber` | Ordinary timber or plastered-timber merchant/craft frontage on a strip plot | **Attested wood/stone coexistence; exact house assignment is plausible composite** | Two typical storeys; limewashed or plastered timber frame; small shuttered or glazed openings; optional stone cellar neck; merchant storage may have an authored hatch and winch, but this is not a default crane facade | Shingle is the default; thatch may occur on service structures; limited tile only where a stone or wealthy rear mass justifies it | No copied 15th-century stone Gothic skin, no obligatory hoist, no tiled-everywhere block, no exposed modern half-timber theatre |
| `craft_boda` | Compact rented two-room workshop-dwelling | **Attested type; exact 1343 dimensions unknown** | One or two storeys; small footprint; workroom/diele at front, sleeping nook behind; one modest hearth; simple door and opening rhythm | Timber, limewash, shingle or thatch; minimal rear yard or shared owner plot | No hypocaust, no hoist beam, no loading crane, no merchant granary, no enlarged diele volume, no landmark massing |

The tier keys are closed. Use only `merchant_stone`, `merchant_timber`, and `craft_boda` in downstream map and mesh work.

## 3. Plate pack

All six files are under `docs/reports/images/burgher_houses/`. They are deliberately named by production tier and viewing side so that art review can compare a street read with the service-yard read.

| Plate | Tier | View | R-003 reference questions answered | Intended use |
|---|---|---|---|---|
| [`reference_merchant_stone_street_gable.png`](images/burgher_houses/reference_merchant_stone_street_gable.png) | `merchant_stone` | Street gable | R-003 `.02` portal and cellar-neck logic; `.05`/.06 hatch and hoist rhythm; `.07`/.08 narrow gable massing | Primary street silhouette, stone portal, selective large opening, upper storage face |
| [`reference_merchant_stone_rear_yard.png`](images/burgher_houses/reference_merchant_stone_rear_yard.png) | `merchant_stone` | Rear yard | R-003 `.01` courtyard ensemble and `.03` rear yard/gate | Stone front-house rear, service wing, yard wall/gate, well, privy, firewood |
| [`reference_merchant_timber_street_gable.png`](images/burgher_houses/reference_merchant_timber_street_gable.png) | `merchant_timber` | Street gable | R-003 `.07`/.08 strip rhythm filtered through the dossier's timber-dominant 1343 ward bias | Limewashed timber, small openings, shingle roof, restrained facade frame |
| [`reference_merchant_timber_rear_yard.png`](images/burgher_houses/reference_merchant_timber_rear_yard.png) | `merchant_timber` | Rear yard | R-003 `.01`/.03 courtyard and service circulation logic | Timber service wing, fence, shared yard gate, well, privy, fuel stack |
| [`reference_craft_boda_street_gable.png`](images/burgher_houses/reference_craft_boda_street_gable.png) | `craft_boda` | Street gable | R-003 labelled *boda* plan and `.07` frontage rhythm, scaled down without merchant crane cues | Compact one-storey workshop dwelling, single hearth implication, simple openings |
| [`reference_craft_boda_rear_yard.png`](images/burgher_houses/reference_craft_boda_rear_yard.png) | `craft_boda` | Rear yard | R-003 *boda* shared-yard rule plus `.03` yard-gate/service reference | Small rear service zone or owner plot relationship, no independent merchant hinterhaus |

### Reading the historical plates

R-003 `.07` Three Brothers and `.08` Three Sisters are late surviving fabric and are used only for gable rhythm, narrow frontage, and vertical massing. R-003 `.05` and `.06` show the functional idea of storage hatches and a hoist beam, but their surviving facade dates and visible hardware are not a licence to copy a finished Gothic facade into April 1343. R-003 `.01` and `.03` support the street-house, service-wing, enclosed-yard, and back-lane relationship; they do not establish an exact 1343 wing date or universal yard plan. R-003 `.02` supports portal and threshold composition, while later carving is excluded. R-003 `.04` is a volume reference for a tall diele only; its modern restaurant furnishings, stained glass, and painted decoration are explicitly rejected.

## 4. Shared art rules

### Street-facing massing

1. Keep the gable end to the lane and the ridge perpendicular to the street.
2. Hold the frontage within the 7-11 m R-003 strip rhythm. Variation should come from depth, height, material, and repair state rather than oversized width.
3. Use two to three storeys for merchant fronts and one to two storeys for a *boda*. The steep roof volume is part of the silhouette and may contain bulk storage.
4. Use a cellar neck or low raised threshold where the plot and tier justify it. Do not turn every door into a ceremonial stair.
5. Make ground-floor activity readable: portal, diele opening, bench or shop/work display, and a restrained hearth/chimney mass.

### Openings and storage

- Stone merchant ground floors may use a pointed-arch opening or a portal paired with one larger rectangular opening.
- Upper levels should use small windows and loading hatches. Storage faces must not look like rows of modern domestic windows.
- A merchant hoist is an authored functional cue, not an ornament. It requires a visible hatch and an interior storage rationale.
- `craft_boda` never receives a hoist beam, winch, loading crane, or granary treatment.
- Avoid four-light stone crosses, blind niches, mouchettes, rich tracery, and other late-Gothic display enrichment as ordinary defaults.

### Roofs and surfaces

- Tile is selective: affluent stone or civic-scale masses may use it, but not every Lower Town roof.
- Shingle and thatch are the default visual counterweight for timber houses and rear service buildings.
- Use grey limestone, limewash, brown timber, tar-dark shingles, and muted red-brown tile. Surface wear should be local: repaired plaster, soot near hearths, mud at thresholds, damp at yard edges.
- Do not use a universal cobble substrate or a uniformly clean facade. The art pass should distinguish front street, working threshold, and wet service yard.

### Rear-yard composition

Every merchant rear-yard study should show a credible relationship between front house and back-lane service space: a gate or fence, a rear wing or lean-to, a well or water point, fuel/firewood, and a privy or service shed when space allows. The yard is an enclosed working area, not an empty garden plaza. A *boda* may share an owner's rear plot and should not be expanded into a second merchant compound.

## 5. Historical confidence and review language

Use the following labels in model review and sign-off:

- **Attested typology:** the source supports the building or room type, but not necessarily the exact surviving facade or exact 1343 dimensions.
- **Plausible composite:** the feature is a reasoned production synthesis from Reval evidence and Hanseatic comparanda. It is safe as a restrained gameplay choice but must not be presented as a measured 1343 fact.
- **Unknown:** the dossier does not support a fixed value. Keep the generator variable or use a conservative default; do not imply a citywide percentage or mandatory feature.

Known R-003 unknowns that remain open for art: the citywide wood-to-stone percentage, glazing versus shutter prevalence on timber fronts, whether attic hoists were standard on timber-front merchants in the 1340s, exact room dimensions, and the prevalence of rear stone *Hinterhaus* structures in this decade.

## 6. Non-runtime evidence boundary

The six PNGs are reference plates only. They must remain under `docs/reports/images/burgher_houses/` and must not be copied into `assets/`, loaded by a runtime scene, or added to `assets/SOURCES.csv`. Runtime house families belong to the downstream production rows:

- **P2-063:** `merchant_stone` exterior kit;
- **P2-064:** `merchant_timber` exterior kit;
- **P2-065:** `craft_boda` exterior kit;
- **P2-066:** plot dressing, cellar neck, fences, yard gates, service sheds, and merchant-only hoist dressing;
- **P2-067:** Lower Town tier assignment and mesh-builder wiring;
- **A-009:** visual sign-off at gameplay camera and day/night lighting.

Do not close those rows by treating these synthetic studies as runtime-ready GLBs or as archaeological proof. They are the visual guardrails for the next authored-kit pass.

## 7. Review checklist for Canon Keeper and art sign-off

- [ ] All three closed tier keys appear exactly as `merchant_stone`, `merchant_timber`, and `craft_boda`.
- [ ] Each tier has both a street-gable and rear-yard plate in the pack.
- [ ] Street gables read as narrow strip plots with steep roofs and ridge perpendicular to the lane.
- [ ] `merchant_stone` carries the strongest stone, cellar, hatch, and optional hoist read without tourist-Gothic enrichment.
- [ ] `merchant_timber` reads timber or plastered-timber first, with restrained small openings and shingle/thatch bias.
- [ ] `craft_boda` remains compact and functional, with no hypocaust, hoist, or granary cues.
- [ ] Rear yards read as service circulation with gates, fences, water, fuel, and modest outbuildings.
- [ ] R-003 `.01`-.`.08` are treated as later/composite comparanda, not direct 1343 facade templates.
- [ ] PNGs remain documentation-only and are not registered as runtime assets.

## Sources

1. [`history/dossiers/architecture/burgher-house-plan.md`](../../history/dossiers/architecture/burgher-house-plan.md), especially Brief ship decisions 1-10, the labelled merchant and *boda* plans, the ward-bias table, the visual-reference caveats, and reference plates `.01`-.`.08`.
2. [`docs/reports/burgher_house_typology_contract.md`](burgher_house_typology_contract.md), P0-163 closed tier keys, roof and hoist rules, ward bias, and rejection rules.
3. [`docs/MAP_AUTHORING.md`](../MAP_AUTHORING.md), for the boundary between documentation plates and map/runtime authoring.
