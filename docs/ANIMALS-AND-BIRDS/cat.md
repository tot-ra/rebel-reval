# Domestic cat

> Town cat; the forge cat is the same model as Kalev's and dresses in another coat.

| Field | Value |
|---|---|
| ID | `fauna.cat` |
| Latin | *Felis catus* |
| Class | mammal |
| Group | `felid` |
| Owner or habitat | urban (P2-024), Lower Town |

## 3D model

| Item | Value |
|---|---|
| Status | Authored GLB (third-party, CC BY 4.0) |
| Runtime file | [`assets/storybook/forge_cat/forge_cat.glb`](../../assets/storybook/forge_cat/forge_cat.glb) |
| Source page | [Sketchfab page](https://sketchfab.com/3d-models/cat-in-motion-3d-model-free-baa1120483c844e6bce9744f3f868c63) |
| Author and licence | iRahulRajput (rt699448), CC BY 4.0. Source is Meshy AI |
| Rig and clips | Shared mammal rig, six clips: Idle, Walk, Run, LookAround, Graze, Alert (measured limb chains). Also Sleep, Groom, Stretch. |

## Code

- Catalogue: `scripts/map/view3d/map_view_mammal_species.gd`
- Mesh and loader: `scripts/map/view3d/map_view_mammal_meshes.gd + map_view_medieval_animal_models.gd`

## Notes

- The runtime scene is `assets/storybook/forge_cat/forge_cat.tscn`; the actors use it as `fauna.cat`.
