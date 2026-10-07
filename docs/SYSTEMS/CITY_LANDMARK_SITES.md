# Landmark sites in the seamless city

Status: implemented for `site.raekoja_plats` and `site.holy_spirit` ([ADR 0032](../adr/0032-bespoke-landmark-sites-in-the-city.md), accepted 2026-10-07; board task to be filed, no board access in the authoring session). Scope: a contract and runtime for bespoke, navigable models of famous Reval buildings and places in the [seamless city](./SEAMLESS_CITY.md), shown as they stood in spring 1343. Out of scope: Blender-generated GLB models (the first site uses an interim GDScript builder), multi-storey interiors, NPC behaviour on sites, the remaining sites (St Olaf next, strict 1343 with the unfinished tower stump by maintainer decision; Kiriku plats and St Mary's, St Nicholas, St Catherine, St Michael, the castle, the gates).

Review plates: `docs/reports/images/city/raekoja_plats_aerial.png`, `raekoja_plats_topdown.png`, `raekoja_plats_street.png`, and the walk-in shots `walk_site_raekoja_plats_inside*.png`.

## What the player sees and can do

- **Raekoja plats in 1343** (per [`raekoja-plats-extents-1343.md`](../../history/dossiers/topography/raekoja-plats-extents-1343.md)):
  - **The council hall:** one tall storey of grey limestone rubble, 26 × 14.8 m, with walls 0.95 m thick.
    - **Roof:** steep (50°) monk-and-nun tile roof between stone parapet gables, with a corrugated eave edge and half-round ridge tiles.
    - **Gables:** coping slabs, kneelers and an apex stone; three stepped blind lancet niches with pointed heads; two rows of putlog holes; a loft door with hoist beam, rope and hook in the east gable.
    - **Market front:** a pointed-arch portal (dressed jambs, lintel, tympanum, worn threshold stone flush with the floor, no plinth across the door). Six rectangular windows in dressed frames with a projecting sill, an iron grille, and two plank shutters that exactly cover the opening; shutters are closed, ajar or folded back, varied per window. Two red-and-white banners on iron rods.
    - **Rest of the exterior:** smaller lights at the rear, a footing plinth and alternating dressed quoins.
    - Not modelled, because they came after 1343: arcade, tower, upper storey.
  - **Inside the hall, a 1343 program** (manifest `program_1343`). The plan follows the merchant-house pattern the dossier records for the hall ("cellar and diele–dornse expansion precede 1343"):
    - **Diele** (great hall, entered from the portal): the Vogt's lower court under Lübeck law.
      - The Vogt sits on a raised dais under the town arms (white cross on red), with two assessors.
      - A court barrier with a gap for the parties; before it a litigant pleading and an oath-helper. An oath lectern with a book and relic box.
      - A petitioner waiting on the bench along the market wall; the hall servant (Ratsdiener) by the door.
      - The Kämmerer receiving a fine at his counting table (reckoning cloth, coin, balance), with an iron-bound strongbox.
      - The trapdoor to the cellar store; two oak posts on stone pads, clear of every walking line; pricket candle stands.
    - **Dornse** (council chamber) behind a limestone partition with its own door:
      - The sitting council: two burgomasters (not four; that bench is later) on the high-backed seat under a striped woollen hanging and the arms, four councillors on benches.
      - The council table with green cloth, the town seal, red wax and parchment.
      - The town scribe at a slanted desk under the window; the book cupboard (town books lie flat), the three-lock town chest, hypocaust vents in the floor.
    - **Walls:** lime wash painted with red-ochre false-ashlar joints, an earthy dado and a frieze (chevron in the diele, green-and-red vine scroll in the dornse). This is a plausible composite after 14th-century Hanseatic halls; no Reval hall painting of 1343 survives.
    - **Floor and ceiling:** limestone flags; oak joists under a boarded ceiling.
    - **Sources:** `town-council-and-officers.md`, `law-courts-and-punishment.md`, `writing-and-records-reval-1343.md`, `burgher-house-plan.md`, `reval-council-prosopography-1340-1345.md`.
  - **On the forum:** three merchants' booths (*Kramerbuden*, recorded 1339) and two shoemakers' stalls (shoemaker stall areas beside the consistorium, AWB 1341) against the hall front, market stalls with cloth, fish, grain and pottery, two carts and trade goods. The pillory stands at the forum centre (`anchor.forum_pillory_1337`, plausible composite).
  - **Ground:** packed earth with patches of paving.
  - **No well:** the dossier resolves it as absent (R-1207).
- **Holy Spirit church and almshouse in 1343** (per [`churches-and-religious-houses.md`](../../history/dossiers/religion/churches-and-religious-houses.md)):
  - **Exterior:**
    - A two-aisle hall church under one steep tile roof between crow-stepped gables (coping on every step, blind lancet niches).
    - A square choir on the north nave's axis with its own stepped gable and a triple east lancet.
    - The almshouse (documented 1334) in the south-east corner with its own street door.
    - The **1360 west tower** with louvred belfry lights and a shingled helm, a presentation choice recorded in the manifest and `docs/CANON.md`. No baroque spire, no clock.
  - **Inside:**
    - Three octagonal pillars down the middle; a flat ceiling of painted boards with beams (the star vaults are 1360).
    - Lancets with **leaded stained glass**: ruby and cobalt borders, pot-metal medallions and grisaille quarries, glowing from inside and dark from outside (`city_stained_glass.gdshader`; plausible composite after Gotland parish glazing).
    - Painted false ashlar and frieze, with the vine frieze in the choir; twelve consecration crosses.
    - The triumphal arch with the rood beam, crucifix, Mary and John; the high altar with linen, frontal, candlesticks, cross and a painted retable on the raised choir; a side altar; a lectern.
    - An octagonal font, the holy-water stoup and bell ropes in the tower porch.
    - Stone wall benches (the congregation stands); ledger slabs in the floor.
    - In the almshouse: five box beds with straw ticks and blankets, a chest, the arch into the south nave and a squint to the high altar.
  - **People:** the priest at the altar with an acolyte, burghers and servants at mass, an old woman on the wall bench, almshouse inmates on their beds, the infirmarian, the sexton in the tower porch.
- **Walking in:** Kalev enters through the portal and the door swings open.
- **People:** the 16 people of the hall are present while Kalev is within 45 m of the site, seated (`sit_idle`), standing or gesturing (`talk_gesture`). They do not talk yet.
- **Cutaway:** in the top-down and third-person cameras, while he is inside, everything above head height lifts away: upper walls, gables, banners, roof and ceiling. The wall stubs get a stone section cap, so the cameras see into the room. First person keeps the whole room, ceiling included. Ordinary houses use the same cutaway ([Seamless city](./SEAMLESS_CITY.md#how-buildings-are-built)).
- **Minimap:** shows "Inside: Council hall".
- **Collision:** the walls, posts, table, chest, lectern, storeroom partition and stores block Kalev, as do the booths, stalls and carts outside. The pillory does not (dossier: no permanent collision).

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
7. `doors` hang leaves through `CityDoors` (gap ends `a`/`b`, `inward`, `height`, `style`, `paint`). Inner doors between rooms work the same way.
   `people` lists who is at work there: `id`, `role`, `rig` (a variant under `assets/characters/variants/`), `at`, `facing_deg`, `pose` (`sit`, `stand`, `talk`). `CityNpcs` spawns them as `CitySiteActor`s near the site. Seated people have no collision.
   `walk.floors` may hold raised floors (a dais) reached by `walk.ramps` (`to_floor`).
8. `dressing` uses the prop catalogue `CitySiteProps`:
   - `market_stall` with `goods` (`fish`, `cloth`, `grain`, `pottery`, joined with `+`);
   - `cart`;
   - `trade_goods` with `variant` (`eastern_furs_wax`, `western_cloth_salt`, `livonian_grain_flax`, `barrelled_herring_metal`);
   - `pillory`.
9. `fabric` (optional) describes the walls once for both the model and the walk data. Each entry has an outer face line `a`→`b`, `inside`, `thick`, `y0`/`y1`, `floor`, the face keys `outer`/`inner` and `openings`. An opening has `kind` (`window`, `door`, `arch`, `niche`, `louvre`), `s`, `w`, `sill`, `spring`, an optional `apex` for a pointed head, `splay` and `glass`. `CitySiteKit` builds the walls from it, and `CitySite` derives the logic-plane walls from it, with door and arch openings at floor level left open.
10. `visual` is either `{"kind": "builder", "script": ...}`, a script with `static func build(site: CitySite, plan: CityPlan) -> Node3D`, or `{"kind": "scene", "path": ...}`.
11. Rebuild the plan (`python3 tools/city/build_reval_city_plan.py`), then run the validator.

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
| `scripts/city/city_site_actor.gd` (`CitySiteActor`) | A person on a site: rig, facing, pose |
| `scripts/city/sites/site_kit.gd` (`CitySiteKit`) | Shared kit for site models. Walls from `fabric` with flat or pointed openings, splays, glass, niches and louvres; crow-stepped gables; gable and pyramid roofs; octagonal pillars; flag floors with ledger slabs; cut caps; materials (`painted_for` binds the painted wash to a site) |
| `scripts/city/sites/holy_spirit_builder.gd` | Holy Spirit church, choir, almshouse and tower on the kit |
| `scripts/city/city_stained_glass.gdshader` | Leaded stained glass |
| `scripts/city/sites/raekoja_plats_parts.gd`, `raekoja_plats_interior.gd` | Shared dimensions and helpers; the diele, dornse, partition and furniture |
| `scripts/city/sites/raekoja_plats_builder.gd` | Council-hall model in metres. Walls with real openings are built as grid cells between the opening edges (`_facade`, `_holed_face`). It adds the gables, portal, window dressing, interior and roof, then splits everything at the cut height into `CouncilHall/Lower`, `CouncilHall/Upper` (with the banners) and `CouncilHall/Roof` |
| `scripts/city/city_tile_roof.gdshader` | Procedural monk-and-nun clay tiles from the roof UVs (metres): courses, per-tile colour, lip shadows, moss in the channels, lichen, wetness. Used by every tile roof in the city |
| `scripts/city/city_limewash.gdshader`, `city_flagstone.gdshader` | Interior lime wash and limestone flags. Both are darkened and warmed for indoors and have no distance fog, because the GL Compatibility renderer has no ambient occlusion |
| `scenes/world/reval_city/reval_city.gd` | Lifts site room roofs while Kalev is inside; camera occluder index |

## Save and load

Sites hold no state. Door positions are not saved; the plan and manifests rebuild the same site every time.

## Verification

- `godot --headless --path . --script tools/validate_city_sites.gd`: the registry loads; replaced buildings are gone; no overlap with generic buildings; every door has clear ground outside and a floor inside; no wall crosses a door; every floor is reachable; every room is reachable from the street through doors and floor-level openings (room graph); people stand on a floor and not inside furniture; every `hide` path resolves; visual walls and authored walls agree within 0.25 m (AABB of the `Walls` mesh against the wall segments).
- `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_city_sites`: placement, replaced building, floor height, room and HUD name, door gap.
- `tools/godot_render.sh --resolution 1600x900 res://tools/capture_reval_city_walk.tscn [-- --only-sites]`: walks in through every site door (door opens, roof lifts, top-down shot inside), then from inside through every other door of the site (the hall into the council chamber) and back out.
- `tools/godot_render.sh --script tools/capture_reval_city.gd -- --only=raekoja_plats_aerial,raekoja_plats_topdown,raekoja_plats_street,raekoja_plats_cutaway,raekoja_plats_interior` (the cutaway plate lifts the rooms as if Kalev were inside).

## Limits

- The council hall is an interim GDScript model. The Blender GLB (ADR 0025 tier B budgets) is follow-up work.
- The cut is one flat plane at head height: window openings above it are cut through, and the section cap spans the window holes.
- Site people use the crowd townsfolk rigs. Civic costume (burgomasters' fur-trimmed dark wool, the scribe's gown) needs new character variants, which are an asset task under the asset freeze. People do not talk or react.
- Interior light is approximate: one candle light per room, with the indoor darkening baked into the materials. There is no light falling through the windows.
- The validator's mesh check compares plan extents (AABB), not a full top-down raster.
- The plan's `forum` polygon (about 90 × 80 m) is still larger than the dossier's 1343 market reserve (about 44 × 36 m). The site's `reserve` follows the dossier, but the extra open ground around it is not yet filled with burgess plots.
- Stalls and carts are the district-map GLBs at their old scale; there are no awnings in varied cloth colours and no horses yet.
- Only `site.raekoja_plats` exists. The other sites in ADR 0032 decision 7 are separate tasks.
