# Domestic dog

> Shaggy village dog; a generic phenotype, not a breed claim.

| Field | Value |
|---|---|
| ID | `fauna.dog` |
| Latin | *Canis lupus familiaris* |
| Class | mammal |
| Group | `canid` |
| Owner or habitat | urban (P2-024), Lower Town |

## 3D model

| Item | Value |
|---|---|
| Status | Authored GLB (third-party, CC BY 4.0) |
| Runtime file | [`assets/storybook/dog/dog.glb`](../../assets/storybook/dog/dog.glb) |
| Source page | [Sketchfab page](https://sketchfab.com/3d-models/realistic-terrier-dog-game-ready-asset-51f498df96c049cbb9e600b0a88c5838) |
| Author and licence | 3Dima (Hdjusj), CC BY 4.0 |
| Rig and clips | Shared mammal rig, six clips: Idle, Walk, Run, LookAround, Graze, Alert (measured limb chains). |

## Code

- Catalogue: `scripts/map/view3d/map_view_mammal_species.gd`
- Mesh and loader: `scripts/map/view3d/map_view_mammal_meshes.gd + map_view_medieval_animal_models.gd`

## Notes

- The dog's Run clip is retimed as a springy trot (see the mammal source manifest).
