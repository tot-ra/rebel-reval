# Horse

> Bay cob of the Reval streets and carts.

| Field | Value |
|---|---|
| ID | `fauna.horse` |
| Latin | *Equus ferus caballus* |
| Class | mammal |
| Group | `ungulate` |
| Owner or habitat | urban (P2-024), foreland pasture |

## 3D model

| Item | Value |
|---|---|
| Status | Project-authored GLB |
| Runtime file | [`assets/storybook/horse/horse.glb`](../../assets/storybook/horse/horse.glb) |
| Source | `tools/assets/build_horse_source.py` |
| Author and licence | Project author, AGPL-3.0-or-later |
| Rig and clips | Shared mammal rig, six clips: Idle, Walk, Run, LookAround, Graze, Alert (measured limb chains). |

## Code

- Catalogue: `scripts/map/view3d/map_view_mammal_species.gd`
- Mesh and loader: `scripts/map/view3d/map_view_mammal_meshes.gd + map_view_medieval_animal_models.gd`

## Notes

- Known limits: rigid cannon and pastern, no tack, one coat.
