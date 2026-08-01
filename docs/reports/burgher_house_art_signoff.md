# A-009 Lower Town burgher-house art sign-off

**Review date:** 2026-08-02
**Historical target:** Spring 1343 Reval, Lower Town
**Task:** A-009 / R-6
**Inputs:** A-008 reference pack, R-003 `burgher-house-plan.md`, and P0-163 `house_tier` contract

## Decision

**CONDITIONAL ART-DIRECTION PASS; FINAL GAMEPLAY SIGN-OFF BLOCKED.**

The six A-008 synthetic reference plates establish a coherent visual target for the three closed ordinary-house tiers. They support the required Spring 1343 massing and material direction, and they reject late-Gothic tourist-facade defaults. They do **not** prove that production GLBs exist, that the tiers are wired into a playable route, or that the families remain readable under matched gameplay-scale day/night lighting.

A-009 must therefore remain open for final acceptance until the downstream authored kits and capture evidence are available. This report records the art decision boundary rather than treating documentation-only studies as runtime or archaeological evidence.

## Evidence inventory

| Evidence | Result | Review note |
|---|---|---|
| `reference_merchant_stone_street_gable.png` | Present | 1200x800 synthetic Blender street-gable study |
| `reference_merchant_stone_rear_yard.png` | Present | 1200x800 synthetic Blender rear-yard study |
| `reference_merchant_timber_street_gable.png` | Present | 1200x800 synthetic Blender street-gable study |
| `reference_merchant_timber_rear_yard.png` | Present | 1200x800 synthetic Blender rear-yard study |
| `reference_craft_boda_street_gable.png` | Present | 1200x800 synthetic Blender street-gable study |
| `reference_craft_boda_rear_yard.png` | Present | 1200x800 synthetic Blender rear-yard study |
| Production house GLBs for the three tiers | Missing | Owned by P2-063, P2-064, and P2-065, all currently open |
| `signoff_*.png` gameplay-scale day/night captures | Missing | No final day/night evidence exists for this A-009 review |
| Runtime registration in `assets/SOURCES.csv` | Correctly absent | A-008 plates remain documentation-only and are not runtime assets |

## Tier review

| Tier | Provisional art verdict | Required read | Boundary / amendment |
|---|---|---|---|
| `merchant_stone` | Pass as a reference target | Narrow 2-3 storey gable, strongest limestone or mixed-front read, cellar-neck/raised threshold, storage hatches, optional merchant hoist, selective tile | Hoist remains functional and optional. Do not add four-light crosses, blind niches, rich tracery, or universal stone frontage. |
| `merchant_timber` | Pass as a reference target | Timber or plastered-timber front, two typical storeys, smaller openings, restrained storage treatment, shingle bias, optional stone cellar | Do not make the hoist a default facade ornament. Do not copy a later stone Gothic skin or tile every roof. |
| `craft_boda` | Pass as a reference target | Compact one or two storeys, simple workshop-dwelling mass, modest openings, single-hearth implication, shared/minimal rear yard | Hoist, loading crane, granary treatment, hypocaust default, and landmark-scale massing remain rejected. |

## R-003 Brief ship-decision review

| # | Decision | A-009 reference verdict | Final-capture requirement |
|---:|---|---|---|
| 1 | Gable end faces the street and ridge runs perpendicular to the lane | **Pass in reference pack** | Confirm in gameplay camera for all three production families. |
| 2 | Merchant fronts default to 2-3 storeys; *boda* stays at 1-2 storeys | **Pass in tier separation** | Confirm relative height and silhouette separation in one shared route capture. |
| 3 | Street-to-yard sequence reads as cellar neck/threshold, diele, chimney-kitchen zone, dornse, and rear yard | **Partially evidenced** | Reference plates show exterior intent only; gameplay or cutaway evidence must confirm no oversized landmark-like volume. |
| 4 | Merchant upper levels read as storage/loading, with hatches rather than domestic window walls | **Pass for `merchant_stone`; restrained for `merchant_timber`** | Confirm authored hatch/hoist combinations and ensure `craft_boda` has none. |
| 5 | `merchant_stone` carries limestone or mixed frontage, portal, larger ground opening, cellar, and selective tile | **Pass as target** | Confirm material response at day and night; reject all-over clean stone or tourist ornament. |
| 6 | `merchant_timber` carries timber/plaster, small openings, and shingle/thatch bias | **Pass as target** | Confirm timber remains visually primary at gameplay distance and does not collapse into stone Gothic. |
| 7 | `craft_boda` remains a compact two-room workshop-dwelling | **Pass as target** | Confirm footprint and height stay below merchant tiers; no merchant crane or granary silhouette. |
| 8 | Roof covers vary by wealth and ward: selective tile, ordinary shingle/thatch | **Pass as material rule** | Matched day/night plates must retain roof-band separation without relying on hue alone. |
| 9 | Rear yards read as working service space, not empty garden plazas | **Pass in paired rear-yard studies** | Confirm gate/fence, water point, fuel, and modest outbuilding relationships in gameplay-scale views. |
| 10 | Ordinary houses must not become post-1400 tourist Gothic monuments or scaled-up landmarks | **Pass as explicit rejection rule** | Final review must include a negative check for four-light crosses, blind niches, rich tracery, monumental width, and landmark substitution. |

## Required closeout evidence

A-009 can move from conditional review to final art acceptance only when all of the following are attached under this report's allowed evidence boundary:

1. A production-ready `merchant_stone` GLB and gameplay-scale day/night capture.
2. A production-ready `merchant_timber` GLB and gameplay-scale day/night capture.
3. A production-ready `craft_boda` GLB and gameplay-scale day/night capture.
4. A shared gameplay route or comparison plate where all three tiers are visible at the same camera scale.
5. An annotation for each capture against the ten R-003 decisions above.
6. Confirmation that runtime assets, if later shipped, are owned and registered by P2-063 through P2-067 rather than by this documentation-only review.

## Open blockers and ownership

- **P2-063 / R-209:** author and verify `merchant_stone` production kit.
- **P2-064 / R-210:** author and verify `merchant_timber` production kit.
- **P2-065 / R-211:** author and verify `craft_boda` production kit.
- **P2-067 / R-213:** wire the tier families into Lower Town route composition.
- **P0-101 / R-108:** perform the final ordinary-fabric and landmark gameplay-scale day/night acceptance after the dependencies land.

No new follow-up task is created here because each blocker already has an owning board row. The six A-008 plates remain non-runtime documentation and must not be used to close those production or gameplay gates.

## Sources

- [`burgher_house_art_brief.md`](burgher_house_art_brief.md) - A-008 tier matrix, confidence labels, plate pack, and non-runtime boundary.
- [`burgher_house_typology_contract.md`](burgher_house_typology_contract.md) - P0-163 closed tier allowlist and rejection rules.
- [`history/dossiers/architecture/burgher-house-plan.md`](../../history/dossiers/architecture/burgher-house-plan.md) - R-003 Brief ship decisions 1-10 and confidence notes.
