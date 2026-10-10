# Domestic goose

> Yard geese; loud and quick to hiss at strangers.

| Field | Value |
|---|---|
| ID | `fauna.goose` |
| Latin | *Anser anser domesticus* |
| Class | domestic bird (listed in the mammal catalogue) |
| Group | `fowl` |
| Owner or habitat | Lower Town and foreland pens (P0-106) |

## 3D model

| Item | Value |
|---|---|
| Status | Project-built GLB (procedural) |
| Runtime file | [`assets/storybook/goose/goose.glb`](../../assets/storybook/goose/goose.glb) |
| Source | none (project-built or procedural) |
| Author and licence | Project author (`tools/assets/build_bird_gaits.py`), AGPL-3.0-or-later |
| Rig and clips | Bird clips: Idle, Walk, Hop, Peck, TakeOff, Fly, Glide, Land (separate shoulder and wing-tip joints). |

## Code

- Catalogue: `scripts/map/view3d/map_view_mammal_species.gd`
- Mesh and loader: `scripts/map/view3d/map_view_mammal_meshes.gd + map_view_medieval_animal_models.gd`

## Notes

- Relocated from the earlier greylag walking model. Distinct from the wild `bird.greylag_goose`, which has no GLB.
