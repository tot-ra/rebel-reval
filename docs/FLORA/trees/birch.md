# Birch

![Birch, district tree model at medium size](../images/trees/birch.jpg)

| Field | Value |
|---|---|
| Latin | *Betula pendula / B. pubescens* |
| Estonian | arukask / sookask |
| Runtime ID | `tree.birch`, city `birch` |
| Period (1343) | high |
| Model | Procedural Weber-Penn skeleton with leaf-cluster cards, built at runtime ([trees](../../SYSTEMS/LIVING_VEGETATION.md#trees)) |

## Look

White bole, airy drooping crown, gold in autumn.

## Where it grows in game

Everywhere: field edges, young woods, yards.

## Seasons

Bud-burst in spring, gold autumn. Phenology: `VegetationPhenology` ([seasons](../../SYSTEMS/LIVING_VEGETATION.md#seasons-and-fruit)).

## Folk use and herbalism (planned)

Spring sap (kasemahl), leaves for tea and dye, bark for vessels, tinder fungus on old trunks. No gathering system exists yet; see [herbalism readiness](../README.md#herbalism-readiness).

## Notes

- The portrait is the district (blueprint) model from `tools/capture_flora_cards.gd`. The seamless city draws the same skeleton with metre-scale bark, near and macro crown tiers and whole-tree wind ([detail by distance](../../SYSTEMS/LIVING_VEGETATION.md#detail-by-distance)).
- All 20 species side by side: [tree reference sheet](../../reports/images/fauna/p0_103_tree_reference_sheet.png).
