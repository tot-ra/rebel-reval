# Red clover

| red clover | red clover leaves |
|---|---|
| ![Red clover: red clover](../images/herbs/red_clover.jpg) | ![Red clover: red clover leaves](../images/herbs/red_clover_leaves.jpg) |

| Field | Value |
|---|---|
| Latin | *Trifolium pratense* |
| Estonian | punane ristik |
| Runtime ID | city `red_clover`, `red_clover_leaves`; district `plant.clover` |
| Habitat group | meadow and pasture |
| Period (1343) | high |
| Model | Detailed city wild-plant model (`CityForbMeshes`), near and far variants; blueprint maps reuse it ([wild plants](../../SYSTEMS/LIVING_VEGETATION.md#wild-plants-forbs)) |

## Where it grows in game

Patches in the open, uncut meadow.

## Seasons

Flowers June-August.

## Folk use and herbalism (planned)

Flower heads for cough tea; fodder. No gathering system exists yet; see [herbalism readiness](../README.md#herbalism-readiness).

## Notes

- Seasons switch the model through `VegetationPhenology.forb_phase`; placement is `CityForbs.suitability`.
