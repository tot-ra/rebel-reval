# Goat

> Goats on the pens and the banks.

| Field | Value |
|---|---|
| ID | `fauna.goat` |
| Latin | *Capra hircus* |
| Class | mammal |
| Group | `goat` |
| Owner or habitat | penned livestock (in game, not in catalogue) |

## 3D model

| Item | Value |
|---|---|
| Status | Authored GLB (third-party, CC BY 4.0) |
| Runtime file | [`assets/storybook/goat/goat.glb`](../../assets/storybook/goat/goat.glb) |
| Source page | [Sketchfab page](https://sketchfab.com/3d-models/goat-2624ac2ce2364930ba2d5f70eb7aa1ea) |
| Author and licence | hendrikReyneke, CC BY 4.0 |
| Rig and clips | Shared mammal rig, six clips: Idle, Walk, Run, LookAround, Graze, Alert (measured limb chains). |

## Code

- Catalogue: `scripts/map/view3d/map_view_mammal_species.gd`
- Mesh and loader: `scripts/map/view3d/map_view_mammal_meshes.gd + map_view_medieval_animal_models.gd`

## Notes

- The runtime keys it as `&"goat"`; it is not in `map_view_mammal_species.gd`. Add it to the catalogue or document the exception.
