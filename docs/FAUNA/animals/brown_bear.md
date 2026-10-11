# Brown bear

> A real predator of the deep forest; rare and not scheduled for the slice.

![Brown bear](../images/brown_bear.jpg)

| Field | Value |
|---|---|
| ID | `fauna.brown_bear` |
| Latin | *Ursus arctos* |
| Class | mammal |
| Group | `bear` |
| Owner or habitat | wild margin, deep forest |
| Bestiary | [`bst.bear`](../../BESTIARY/cards/bear.md) |

## 3D model

| Item | Value |
|---|---|
| Status | Procedural only, no 3D model |
| Runtime file | none (procedural mesh in code) |
| Source | none (project-built or procedural) |
| Author and licence | - |
| Rig and clips | - |
| Find a model | [Sketchfab search: brown bear rigged](https://sketchfab.com/search?q=brown+bear+rigged&type=models) (filter CC BY or CC0 by hand; not yet verified) |

## Code

- Catalogue: `scripts/map/view3d/map_view_mammal_species.gd`
- Mesh and loader: `scripts/map/view3d/map_view_mammal_meshes.gd + map_view_medieval_animal_models.gd`

## Notes

- Bestiary card: [`bst.bear`](../../BESTIARY/cards/bear.md) (single source for combat role and guilt). The mammal catalogue only has a procedural reference mesh.
