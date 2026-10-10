# Wild boar

> Bristled forest pig that charges when cornered; a hunting animal.

| Field | Value |
|---|---|
| ID | `fauna.wild_boar` |
| Latin | *Sus scrofa* |
| Class | mammal |
| Group | `ungulate` |
| Owner or habitat | wild margin, hinterland woods |
| Bestiary | [`bst.boar`](../BESTIARY/README.md) |

## 3D model

| Item | Value |
|---|---|
| Status | Authored GLB (third-party, CC BY 4.0) |
| Runtime file | [`assets/storybook/boar/boar.glb`](../../assets/storybook/boar/boar.glb) |
| Source page | [Sketchfab page](https://sketchfab.com/3d-models/bristled-wild-boar-3d-model-free-1c243598b9e54606a0bf1d8f5bf0a8b1) |
| Author and licence | iRahulRajput (rt699448), CC BY 4.0 |
| Rig and clips | Shared mammal rig, six clips: Idle, Walk, Run, LookAround, Graze, Alert (measured limb chains). |

## Code

- Catalogue: `scripts/map/view3d/map_view_mammal_species.gd`
- Mesh and loader: `scripts/map/view3d/map_view_mammal_meshes.gd + map_view_medieval_animal_models.gd`

## Notes

- Bestiary entry `bst.boar` is backlog. The GLB is a runtime model; the boar combat role is not yet designed.
