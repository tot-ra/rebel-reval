# Domestic pig

> Pen pig of the farm plots.

| Field | Value |
|---|---|
| ID | `fauna.pig` |
| Latin | *Sus scrofa domestica* |
| Class | mammal |
| Group | `swine` |
| Owner or habitat | Lower Town and foreland pens (P0-106) |

## 3D model

| Item | Value |
|---|---|
| Status | Authored GLB (third-party, CC BY 4.0) |
| Runtime file | [`assets/storybook/pig/pig.glb`](../../assets/storybook/pig/pig.glb) |
| Source page | [Sketchfab page](https://sketchfab.com/3d-models/pig-041ea96fc6ae4839bf9ce16f8ea4ad68) |
| Author and licence | hendrikReyneke, CC BY 4.0 |
| Rig and clips | Shared mammal rig, six clips: Idle, Walk, Run, LookAround, Graze, Alert (measured limb chains). |

## Code

- Catalogue: `scripts/map/view3d/map_view_mammal_species.gd`
- Mesh and loader: `scripts/map/view3d/map_view_mammal_meshes.gd + map_view_medieval_animal_models.gd`

## Notes

- Lower body centre and shorter legs than the source, per the storybook realism pass.
