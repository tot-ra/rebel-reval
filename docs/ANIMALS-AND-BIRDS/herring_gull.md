# Herring gull

> Harbour gull; bold scavenger of the quays.

| Field | Value |
|---|---|
| ID | `bird.herring_gull` |
| Latin | *Larus argentatus* |
| Class | bird |
| Group | `gull` |
| Owner or habitat | harbour and Lower Town roofs |

## 3D model

| Item | Value |
|---|---|
| Status | Project-built GLB (procedural) |
| Runtime file | [`assets/storybook/gull/gull.glb`](../../assets/storybook/gull/gull.glb) |
| Source | none (project-built or procedural) |
| Author and licence | Project tooling (`tools/assets/storybook_birds.py`), AGPL-3.0-or-later |
| Rig and clips | Bird clips: Idle, Walk, Hop, Peck, TakeOff, Fly, Glide, Land (separate shoulder and wing-tip joints). |

## Code

- Catalogue: `scripts/map/view3d/map_view_bird_species.gd`
- Mesh and loader: `scripts/map/view3d/map_view_bird_meshes.gd + map_view_bird_assets.gd`

## Notes

- Shares the storybook gull GLB with the common gull. The maintainer found the gull bill and wing texture weak in close-up.
