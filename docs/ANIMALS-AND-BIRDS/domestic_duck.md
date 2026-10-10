# Domestic duck

> Ducks of the millpond and the ditches.

| Field | Value |
|---|---|
| ID | `fauna.duck` |
| Latin | *Anas platyrhynchos domesticus* |
| Class | domestic bird (listed in the mammal catalogue) |
| Group | `fowl` |
| Owner or habitat | Lower Town and foreland pens (P0-106) |

## 3D model

| Item | Value |
|---|---|
| Status | Project-built GLB (procedural) |
| Runtime file | [`assets/storybook/duck/duck.glb`](../../assets/storybook/duck/duck.glb) |
| Source | none (project-built or procedural) |
| Author and licence | Project tooling (`tools/assets/storybook_birds.py`), AGPL-3.0-or-later |
| Rig and clips | Bird clips: Idle, Walk, Hop, Peck, TakeOff, Fly, Glide, Land (separate shoulder and wing-tip joints). |

## Code

- Catalogue: `scripts/map/view3d/map_view_mammal_species.gd`
- Mesh and loader: `scripts/map/view3d/map_view_mammal_meshes.gd + map_view_medieval_animal_models.gd`

## Notes

- Same GLB is the animated model for the wild `bird.mallard` (see the bird list).
