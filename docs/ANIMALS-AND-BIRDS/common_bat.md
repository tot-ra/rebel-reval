# Common bat

> Small night flyer over the town walls and the orchards.

| Field | Value |
|---|---|
| ID | `fauna.common_bat` |
| Latin | *Pipistrellus pipistrellus* |
| Class | mammal |
| Group | `bat` |
| Owner or habitat | night margin |

## 3D model

| Item | Value |
|---|---|
| Status | Procedural only, no 3D model |
| Runtime file | none (procedural mesh in code) |
| Source | none (project-built or procedural) |
| Author and licence | - |
| Rig and clips | - |
| Find a model | [Sketchfab search: pipistrelle bat rigged](https://sketchfab.com/search?q=pipistrelle+bat+rigged&type=models) (filter CC BY or CC0 by hand; not yet verified) |

## Code

- Catalogue: `scripts/map/view3d/map_view_mammal_species.gd`
- Mesh and loader: `scripts/map/view3d/map_view_mammal_meshes.gd + map_view_medieval_animal_models.gd`

## Notes

- Procedural reference mesh only; a flight model would need the bird flight path, not the mammal clips.
