# European robin

> Red-breasted songbird of the gardens and churchyards.

| Field | Value |
|---|---|
| ID | `bird.european_robin` |
| Latin | *Erithacus rubecula* |
| Class | bird |
| Group | `songbird` |
| Owner or habitat | gardens, churchyards, woods |

## 3D model

| Item | Value |
|---|---|
| Status | Project-built GLB (procedural) |
| Runtime file | [`assets/storybook/robin/robin.glb`](../../assets/storybook/robin/robin.glb) |
| Source | none (project-built or procedural) |
| Author and licence | Project tooling (`tools/assets/storybook_birds.py`), AGPL-3.0-or-later |
| Rig and clips | Bird clips: Idle, Walk, Hop, Peck, TakeOff, Fly, Glide, Land (separate shoulder and wing-tip joints). |

## Code

- Catalogue: `scripts/map/view3d/map_view_bird_species.gd`
- Mesh and loader: `scripts/map/view3d/map_view_bird_meshes.gd + map_view_bird_assets.gd`

## Notes

- Skinned storybook model; animated flight via the `Fly`/`Glide` clips.
