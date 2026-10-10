# Sheep

> Flocks on the foreland; wool and milk for the town.

| Field | Value |
|---|---|
| ID | `fauna.sheep` |
| Latin | *Ovis aries* |
| Class | mammal |
| Group | `ungulate` |
| Owner or habitat | foreland pasture (static props) |

## 3D model

| Item | Value |
|---|---|
| Status | Authored GLB (third-party, CC BY 4.0) |
| Runtime file | [`assets/storybook/sheep/sheep.glb`](../../assets/storybook/sheep/sheep.glb) |
| Source page | [Sketchfab page](https://sketchfab.com/3d-models/sheep-67abff7459f34afca11e3effab62c761) |
| Author and licence | hendrikReyneke, CC BY 4.0 |
| Rig and clips | Shared mammal rig, six clips: Idle, Walk, Run, LookAround, Graze, Alert (measured limb chains). |

## Code

- Catalogue: `scripts/map/view3d/map_view_mammal_species.gd`
- Mesh and loader: `scripts/map/view3d/map_view_mammal_meshes.gd + map_view_medieval_animal_models.gd`

## Notes

- Catalogue lists the owner as static props only; the model still has the shared clips.
