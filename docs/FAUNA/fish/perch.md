# European perch

> The striped lurker of the shallows, the odd one among the herring.

![European perch](../images/perch.jpg)

| Field | Value |
|---|---|
| ID | `fish.perch` (card ID; the runtime species key is `perch`) |
| Latin | *Perca fluviatilis* |
| Class | fish |
| Group | `freshwater and brackish predator` |
| Owner or habitat | clear shallows (0.35 to 1.1 m of water) near the shore and river mouths |

## 3D model

| Item | Value |
|---|---|
| Status | Project-built mesh (procedural, in code) |
| Runtime file | none (no GLB); lofted at load by `CityFish.build_mesh` |
| Source | none (project-built or procedural) |
| Author and licence | Project code, AGPL-3.0-or-later |
| Rig and clips | None. The tail is animated in `scripts/city/city_fish.gdshader` from the shared ocean clock. |

## Code

- School placement and mesh: [`scripts/city/city_fish.gd`](../../../scripts/city/city_fish.gd)
- Painted look (no textures): [`scripts/city/city_fish.gdshader`](../../../scripts/city/city_fish.gdshader)
- System page: [`CITY_SEA.md`](../../SYSTEMS/CITY_SEA.md) ("Fish")

## Notes

- Appears in 18 percent of schools, 5 fish each. Humped back, olive body with six dark saddle bars, orange pelvic and anal fins, black spot on the spiny first dorsal.
- Perch is a brackish-water fish of the Gulf of Finland; its place in 1343 Reval is an ecological inference (`plausible composite`), not a documented catch.
- Visual only: nothing is caught, hit or saved.
- No object item exists for perch yet.