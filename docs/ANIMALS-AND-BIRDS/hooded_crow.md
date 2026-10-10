# Hooded crow

> Grey and black scavenger of the town and the fields.

| Field | Value |
|---|---|
| ID | `bird.hooded_crow` |
| Latin | *Corvus cornix* |
| Class | bird |
| Group | `corvid` |
| Owner or habitat | town roofs, fields, dumps |

## 3D model

| Item | Value |
|---|---|
| Status | Project-built GLB (procedural) |
| Runtime file | [`assets/storybook/hooded_crow/hooded_crow.glb`](../../assets/storybook/hooded_crow/hooded_crow.glb) |
| Source | none (project-built or procedural) |
| Author and licence | Project tooling (`tools/assets/storybook_birds.py`), AGPL-3.0-or-later |
| Rig and clips | Bird clips: Idle, Walk, Hop, Peck, TakeOff, Fly, Glide, Land (separate shoulder and wing-tip joints). |

## Code

- Catalogue: `scripts/map/view3d/map_view_bird_species.gd`
- Mesh and loader: `scripts/map/view3d/map_view_bird_meshes.gd + map_view_bird_assets.gd`

## Notes

- Used as the animated model for the flap cycle in `map_view_bird_assets.gd`.
