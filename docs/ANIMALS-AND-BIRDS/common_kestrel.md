# Common kestrel

> Small falcon that hovers over the field edges.

| Field | Value |
|---|---|
| ID | `bird.common_kestrel` |
| Latin | *Falco tinnunculus* |
| Class | bird |
| Group | `raptor` |
| Owner or habitat | hinterland fields and town walls |

## 3D model

| Item | Value |
|---|---|
| Status | Procedural only, no 3D model |
| Runtime file | none (procedural mesh in code) |
| Source | none (project-built or procedural) |
| Author and licence | - |
| Rig and clips | - |
| Find a model | [Sketchfab search: kestrel bird rigged](https://sketchfab.com/search?q=kestrel+bird+rigged&type=models) (filter CC BY or CC0 by hand; not yet verified) |

## Code

- Catalogue: `scripts/map/view3d/map_view_bird_species.gd`
- Mesh and loader: `scripts/map/view3d/map_view_bird_meshes.gd + map_view_bird_assets.gd`

## Notes

- Hovering is not implemented in flight (see `FLORA_FAUNA.md` Bird flight limits).
