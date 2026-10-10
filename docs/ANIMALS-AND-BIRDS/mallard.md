# Mallard

> Wild duck of the ponds and the ditches.

| Field | Value |
|---|---|
| ID | `bird.mallard` |
| Latin | *Anas platyrhynchos* |
| Class | bird |
| Group | `waterfowl` |
| Owner or habitat | ponds, ditches and the harbour |

## 3D model

| Item | Value |
|---|---|
| Status | Project-built GLB (procedural) |
| Runtime file | [`assets/storybook/duck/duck.glb`](../../assets/storybook/duck/duck.glb) |
| Source | none (project-built or procedural) |
| Author and licence | Project tooling (`tools/assets/storybook_birds.py`), AGPL-3.0-or-later |
| Rig and clips | Bird clips: Idle, Walk, Hop, Peck, TakeOff, Fly, Glide, Land (separate shoulder and wing-tip joints). |

## Code

- Catalogue: `scripts/map/view3d/map_view_bird_species.gd`
- Mesh and loader: `scripts/map/view3d/map_view_bird_meshes.gd + map_view_bird_assets.gd`

## Notes

- Uses the same GLB as the domestic duck (`fauna.duck`). Wild and domestic share one model for now.
