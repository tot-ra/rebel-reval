# Willow

![Willow, district tree model at medium size](../images/trees/willow.jpg)

| Field | Value |
|---|---|
| Latin | *Salix spp.* |
| Estonian | paju |
| Runtime ID | `tree.willow`, city shrub `willow_shrub` |
| Period (1343) | high |
| Model | Procedural Weber-Penn skeleton with leaf-cluster cards, built at runtime ([trees](../../SYSTEMS/LIVING_VEGETATION.md#trees)) |

## Look

Leaning bole with hanging shoots.

## Where it grows in game

Stream banks, moat edges, wet ground.

## Seasons

Catkins in spring. Phenology: `VegetationPhenology` ([seasons](../../SYSTEMS/LIVING_VEGETATION.md#seasons-and-fruit)).

## Folk use and herbalism (planned)

Bark for pain and fever; rods for baskets and wattle. No gathering system exists yet; see [herbalism readiness](../README.md#herbalism-readiness).

## Notes

- The portrait is the district (blueprint) model from `tools/capture_flora_cards.gd`. The seamless city draws the same skeleton with metre-scale bark, near and macro crown tiers and whole-tree wind ([detail by distance](../../SYSTEMS/LIVING_VEGETATION.md#detail-by-distance)).
- All 20 species side by side: [tree reference sheet](../../reports/images/fauna/p0_103_tree_reference_sheet.png).
