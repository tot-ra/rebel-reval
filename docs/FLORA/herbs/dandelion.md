# Dandelion

| dandelion flower | dandelion clock | dandelion leaves |
|---|---|---|
| ![Dandelion: dandelion flower](../images/herbs/dandelion_flower.jpg) | ![Dandelion: dandelion clock](../images/herbs/dandelion_clock.jpg) | ![Dandelion: dandelion leaves](../images/herbs/dandelion_leaves.jpg) |

| Field | Value |
|---|---|
| Latin | *Taraxacum officinale* |
| Estonian | harilik võilill |
| Runtime ID | city `dandelion_flower`, `dandelion_clock`, `dandelion_leaves`; district `plant.dandelion` |
| Habitat group | meadow and pasture |
| Period (1343) | high |
| Model | Detailed city wild-plant model (`CityForbMeshes`), near and far variants; blueprint maps reuse it ([wild plants](../../SYSTEMS/LIVING_VEGETATION.md#wild-plants-forbs)) |

## Where it grows in game

Short grass round settlement and roads, in drifts.

## Seasons

Flowers in May, seed clocks in June, rosettes until November.

## Folk use and herbalism (planned)

Spring leaves as salad; root as a bitter tonic. No gathering system exists yet; see [herbalism readiness](../README.md#herbalism-readiness).

## Notes

- Seasons switch the model through `VegetationPhenology.forb_phase`; placement is `CityForbs.suitability`.
