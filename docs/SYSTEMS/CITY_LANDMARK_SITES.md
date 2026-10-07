# Landmark sites in the seamless city

Status: implemented for the first site, `site.raekoja_plats` ([ADR 0032](../adr/0032-bespoke-landmark-sites-in-the-city.md), accepted 2026-10-07; board task to be filed, no board access in the authoring session). Scope: a contract and runtime for bespoke, navigable models of famous Reval buildings and places in the [seamless city](./SEAMLESS_CITY.md), shown as they stood in spring 1343. Out of scope: Blender-generated GLB models (the first site uses an interim GDScript builder), multi-storey interiors, NPC behaviour on sites, the remaining sites (Kiriku plats and St Mary's, St Olaf, St Nicholas, Holy Spirit, St Catherine, St Michael, the castle, the gates).

Review plates: `docs/reports/images/city/raekoja_plats_aerial.png`, `raekoja_plats_topdown.png`, `raekoja_plats_street.png`, and the walk-in shots `walk_site_raekoja_plats_inside*.png`.

## What the player sees and can do

- **Raekoja plats in 1343** (per [`raekoja-plats-extents-1343.md`](../../history/dossiers/topography/raekoja-plats-extents-1343.md)):
  - The council hall: one storey of grey limestone, 26 × 14.8 m, with a clay-tile gable roof, stone gables with coping, a footing plinth and dressed quoins. Its market front has a pointed portal, shuttered lights and barred cellar lights, an attic hoist and the red-and-white banners. There is no arcade, tower or upper storey; all three came after 1343.
  - Three merchants' booths (*Kramerbuden*, recorded 1339) against the hall front.
  - Market stalls with cloth, fish, grain and pottery, two carts and trade goods.
  - The pillory at the forum centre (`anchor.forum_pillory_1337`, plausible composite).
  - Packed earth with patches of paving.
  - No well: the dossier resolves it as absent (R-1207).
- Kalev walks into the hall through its door. The door swings open, and roof and ceiling lift while he is inside, so all three cameras see the room. The minimap shows "Inside: Council hall". Walls, booths, stalls and carts block him; the pillory does not (dossier: no permanent collision).

## How a site is authored

1. Write `content/world/reval_city/sites/<name>.json` (fields in ADR 0032 decision 1) and add `<name>` to `content/world/reval_city/sites/registry.json`. Sites are never found by scanning a folder.
2. Coordinates are **site-local metres**. `anchor.at` is the plan position of the local origin; `anchor.rotation_deg` turns local +x. Local +z is to its right, which is south at rotation 0. Heights are relative to the terrace level.
3. `replaces` lists the generic plan buildings the site removes (stable IDs). `tools/validate_city_sites.gd` fails while any generic building still overlaps a site building by more than 1 m².
4. `terrace.level.door` names the door whose outside ground (`outside_m` out) sets the level. `terrace.polygon` is levelled to it and blended over `blend_m`.
5. `walk` is the logic plane:
   - `walls` are outer-face segments with a thickness that goes into the building. Leave the door gap out.
   - `floors` are polygons with a height above the terrace.
   - `solid` holds extra blocking polygons.
   - A dressing item with `"solid": [w, d]` also blocks.
6. `rooms` say which floor they are on and which visual nodes (`hide` paths relative to the site's root) disappear while Kalev is inside.
7. `doors` hang leaves through `CityDoors` (gap ends `a`/`b`, `inward`, `height`, `style`, `paint`).
8. `dressing` uses the prop catalogue `CitySiteProps`:
   - `market_stall` with `goods` (`fish`, `cloth`, `grain`, `pottery`, joined with `+`);
   - `cart`;
   - `trade_goods` with `variant` (`eastern_furs_wax`, `western_cloth_salt`, `livonian_grain_flax`, `barrelled_herring_metal`);
   - `pillory`.
9. `visual` is either `{"kind": "builder", "script": ...}`, a script with `static func build(site: CitySite, plan: CityPlan) -> Node3D`, or `{"kind": "scene", "path": ...}`.
10. Rebuild the plan (`python3 tools/city/build_reval_city_plan.py`), then run the validator.

Period rule: show the building as it stood in spring 1343. A later feature needs a maintainer-recorded entry in the manifest's `presentation` list.

## Runtime entry points

| Script | Role |
|---|---|
| `tools/city/build_reval_city_plan.py` (`load_sites`, `terrace_site`, `flatten_ground`) | Drops `replaces`, levels the terrace, keeps trees and shrubs off the site, paints splat and minimap, writes `plan.json` → `sites[]` (`id`, `at`, `rotation_deg`, `level`, world `footprints`, `reserve`) |
| `scripts/city/city_site.gd` (`CitySite`) | Manifest plus placement; local↔world transforms; floors, rooms, walls, solids, doors in world XZ |
| `scripts/city/city_site_registry.gd` (`CitySiteRegistry`) | Loads the registry and pairs manifests with their plan placement |
| `scripts/city/city_plan.gd` | `sites`, `site_at`, `site_room_at`; `walk_height` uses site floors first; `location_at` names site rooms |
| `scripts/city/city_world_3d.gd` | Builds each site visual at its anchor; `set_site_room_hidden`, `site_occluder_index` |
| `scripts/city/city_collision_builder.gd` (`_sites`) | Site walls, solids and dressing footprints on the logic plane |
| `scripts/city/city_doors.gd` | Site doors keyed `"site:<door id>"` |
| `scripts/city/city_site_props.gd` (`CitySiteProps`) | Prop catalogue for dressing |
| `scripts/city/sites/raekoja_plats_builder.gd` | Interim council-hall model: a hollow city shell plus the 1343 hall details of `MapViewTownHallModel`, mounted at 0.87 m units |
| `scenes/world/reval_city/reval_city.gd` | Lifts site room roofs while Kalev is inside; camera occluder index |

## Save and load

Sites hold no state. Door positions are not saved; the plan and manifests rebuild the same site every time.

## Verification

- `godot --headless --path . --script tools/validate_city_sites.gd`: the registry loads; replaced buildings are gone; no overlap with generic buildings; every door has clear ground outside and a floor inside; no wall crosses a door; every floor is reachable; every `hide` path resolves; visual walls and authored walls agree within 0.25 m (AABB of the `Walls` mesh against the wall segments).
- `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_city_sites`: placement, replaced building, floor height, room and HUD name, door gap.
- `tools/godot_render.sh --resolution 1600x900 res://tools/capture_reval_city_walk.tscn`: walks in through every site door (door opens, roof lifts, top-down shot inside) and back out.
- `tools/godot_render.sh --script tools/capture_reval_city.gd -- --only=raekoja_plats_aerial,raekoja_plats_topdown,raekoja_plats_street`.

## Limits

- The council hall is an interim GDScript port. The Blender GLB (ADR 0025 tier B budgets) is follow-up work, as are the hall interior furnishings (benches, chests, the consistorium table).
- The validator's mesh check compares plan extents (AABB), not a full top-down raster.
- The plan's `forum` polygon (about 90 × 80 m) is still larger than the dossier's 1343 market reserve (about 44 × 36 m). The site's `reserve` follows the dossier, but the extra open ground around it is not yet filled with burgess plots.
- Stalls and carts are the district-map GLBs at their old scale; there are no awnings in varied cloth colours and no horses yet.
- Only `site.raekoja_plats` exists. The other sites in ADR 0032 decision 7 are separate tasks.
