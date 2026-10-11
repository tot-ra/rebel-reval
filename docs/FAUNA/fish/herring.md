# Baltic herring

> The silver shoal of the Kalamaja shore; the cheapest fish in Reval.

![Baltic herring](../images/herring.jpg)

| Field | Value |
|---|---|
| ID | `fish.herring` (card ID; the runtime species key is `herring`) |
| Latin | *Clupea harengus membras* |
| Class | fish |
| Group | `schooling fish` |
| Owner or habitat | clear shallows (0.35 to 1.1 m of water) off the Kalamaja fishing shore |

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

- Default species of a school: 82 percent of the seven schools, 11 fish each. Keeled belly, dark blue-green back, silver violet-gold flanks, brassy gill cover.
- Canon: the 1340s diet leaned heavily on Baltic herring ([`CANON.md`](../../CANON.md)); the shore lives off the spring run ([Kalamaja fishing shore](../../../history/dossiers/topography/kalamaja-fishing-shore-1343.md)).
- Visual only: nothing is caught, hit or saved.
- Related objects (not creatures): [`obj.herring_fresh`](../../../content/objects/food/obj.herring_fresh.json), [`obj.herring_filleted`](../../../content/objects/food/obj.herring_filleted.json), [`obj.cargo_herring_barrels`](../../../content/objects/trade_good/obj.cargo_herring_barrels.json).