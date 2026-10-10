# Chicken

> Hens of the pens and the yards.

| Field | Value |
|---|---|
| ID | `fauna.chicken` |
| Latin | *Gallus gallus domesticus* |
| Class | domestic bird (listed in the mammal catalogue) |
| Group | `fowl` |
| Owner or habitat | Lower Town and foreland pens (P0-106) |

## 3D model

| Item | Value |
|---|---|
| Status | Authored GLB (third-party, CC BY 4.0) |
| Runtime file | [`assets/storybook/hen/hen.glb`](../../assets/storybook/hen/hen.glb) |
| Source page | [Sketchfab page](https://sketchfab.com/3d-models/chicken-ce17aabc51ba47bfbc7342a963b095e9) |
| Author and licence | hendrikReyneke (Sketchfab), CC BY; rebuilt by project |
| Rig and clips | 16-bone articulated rig, eight named animations. |

## Code

- Catalogue: `scripts/map/view3d/map_view_mammal_species.gd`
- Mesh and loader: `scripts/map/view3d/map_view_mammal_meshes.gd + map_view_medieval_animal_models.gd`

## Notes

- Runtime GLB `hen.glb` is derived from `assets/animals/hendrik_reyneke/chicken/chicken.glb`; rebuild with `tools/assets/import_authored_birds.py --only hen`.
