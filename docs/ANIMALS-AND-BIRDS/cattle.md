# Cattle

> Brown landrace-like cows of the pens and the pasture.

| Field | Value |
|---|---|
| ID | `fauna.cow` |
| Latin | *Bos taurus* |
| Class | mammal |
| Group | `ungulate` |
| Owner or habitat | Lower Town and foreland pasture (P0-106) |

## 3D model

| Item | Value |
|---|---|
| Status | Authored GLB (third-party, CC BY 4.0) |
| Runtime file | [`assets/storybook/cow/cow.glb`](../../assets/storybook/cow/cow.glb) |
| Source page | [Sketchfab page](https://sketchfab.com/3d-models/brown-cow-3d-model-14a5bf64cd93490682e841292b318d1b) |
| Author and licence | iRahulRajput (rt699448), CC BY 4.0; Holstein variant: 3Dima (Hdjusj), CC BY 4.0 ([cow_holstein](https://sketchfab.com/3d-models/realistic-holstein-cow-game-ready-asset-0bd2f1c0c79a4b5b9d36e67f0f700c5e)) |
| Rig and clips | Shared mammal rig, six clips: Idle, Walk, Run, LookAround, Graze, Alert (measured limb chains). |

## Code

- Catalogue: `scripts/map/view3d/map_view_mammal_species.gd`
- Mesh and loader: `scripts/map/view3d/map_view_mammal_meshes.gd + map_view_medieval_animal_models.gd`

## Notes

- Two coats in use: `cow/` (canonical) and `cow_holstein/`, picked per placement seed.
