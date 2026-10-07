# Seamless Reval city (1343)

Status: implemented as a playable preview ([ADR 0031](../adr/0031-continuous-reval-city-plan.md), accepted 2026-10-07; board task to be filed, no board access in the authoring session). Attribution: `CREDITS.md` and `docs/THIRD_PARTY_NOTICES.md`. Scope: the whole walled Lower Town, Toompea, the shore to the 1343 waterline, the Härjapea and the near suburbs and fields as one continuous scene with real relief, the 1343 fortifications, enterable houses and one shared wind. Out of scope here: NPCs, quests, saves, swimming and night systems in this scene (they still run on the district maps; see [Limits](#limits)).

Review plates: [`docs/reports/reval_city_plan_2026-10-07.md`](../reports/reval_city_plan_2026-10-07.md).

## What the player can do

- Main menu → **Reval (seamless)**. Kalev starts on the forum.
- Walk anywhere in the plan without a loading screen: in through the Viru gate, along Pikk and Lai to the Coastal Gate and down to the shore, up Pikk jalg or the Lühike jalg steps onto Toompea, out of the Cattle or Smiths' gates to the fields.
- Walk into any ordinary house through its street door. The roof lifts while Kalev is inside and returns when he leaves; the room is the house footprint minus its walls.
- Camera: hold right (or middle) mouse and drag, or use the gamepad right stick, to orbit; mouse wheel to zoom; `Q`/`E` to turn. Movement uses the usual move actions relative to the camera. The camera pulls in front of walls and houses.
- Command line: `-- --city-spawn=<gate or point id>`, for example `gate.viru`, `gate.coastal`, `poi.forum`.

## How the plan is made

`tools/city/build_reval_city_plan.py` compiles three committed inputs into `content/world/reval_city/`:

| Input | What it gives | Licence |
|---|---|---|
| `tools/city/data/osm_reval_extract.json` | streets, plot footprints, surviving towers, wall fragments, cliffs, coast | ODbL, © OpenStreetMap contributors |
| `tools/city/data/eudem25m_reval.json` | 25 m surface heights (trend only; rooftop bias removed) | EU-DEM v1.1, Copernicus |
| `tools/city/reval_1343_overlay.json` | everything 1343: wall anchors and states, towers, gates, Toompea edge, shoreline, Härjapea, moat, excluded streets and buildings, extramural roads, suburbs, wells, guard posts, barracks, markets, supply and watch flows | project |

Rebuild after editing the overlay: `python3 tools/city/build_reval_city_plan.py`. `--check` fails when the committed outputs are stale. `--import-osm <overpass.json> --import-dem <dem.json>` refreshes the source extracts (see the script header for the queries). The builder also writes `docs/reports/images/city/reval_city_plan.png`, a top-down review map.

Rules the compiler enforces:

- Coordinates: local metres, origin at the forum (59.43725 N, 24.74535 E), x east, y south; output in world units of 0.87 m (x east, z south), logic pixels = world units × 32.
- Gates snap onto their street; a gate faces along its street.
- Streets inside the walls come from OSM, renamed from the 1343 street register where it has a record; excluded names (later streets, Rüütli, Uus, Väike-Karja, Patkuli stairs ...) are dropped; a street that crosses the curtain away from a gate is cut back to the inside (later wall breaches).
- Buildings come from OSM plot footprints inside the circuit or on Toompea; post-1343 landmarks and towers are excluded; back plots are thinned for 1343 density; material and roof follow street rank (limestone and tile on the spines, timber and thatch in the lanes); the ridge follows the plot's own axis.
- Terrain: EU-DEM trend, the walled town lowered by the surface-model rooftop bias, the Toompea table authored from the cliff edge, the hill ways carved as ramps, the beach and seabed from the 1343 shoreline, the Härjapea channel and the S/E ditch cut in.
- Stable IDs: `street.osm.<way>`, `bldg.osm.w<way>` / `bldg.osm.r<relation>`, `bldg.lm.<landmark>`, `bldg.<suburb>.<n>`, `gate.*`, `tower.*`, `curtain.NN`, `toompea_wall.NN`, `poi.*`, `flow.*`, `field.*`. OSM ids keep a building's id across rebuilds.

### 1343 fortifications

From [`walls-gates-towers.md`](../../history/dossiers/topography/walls-gates-towers.md) and `RevalFortificationRegistry`:

- Curtain: stone ~6.2 m on the west, north and east; unfinished courses with putlog scaffolding on the south and south-east (the 1340s extension); a timber palisade on the Toompea slope between the hill gates and on the south-west slope.
- Towers built: Nunnatorn, Kuldjala, Rentenitorn, Stolting, the Coastal Gate tower; Hinke under construction. Later towers (Fat Margaret, Kiek in de Kök, Neitsitorn, Epping, Loewenschede, Pikk Hermann, ...) are absent; their positions only shape the wall line.
- Gates: Coastal (low form), Sand, Nuns', Viru (unfinished, no foregate), Cattle and Smiths' (under construction), Long Hill and Short Hill (wooden).
- Toompea: a stone wall round the plateau with openings wherever a way crosses it; the castle on the south-west with four corner towers flying Danish crown pennants.

### City life layers (data, not yet simulated)

`plan.json` carries `points_of_interest` (wells, the forum, the fish landing, guard posts at every gate, the castle garrison, the council watch, granary, mill pond, bath, bakers, malt house, meat benches, smiths), `flows` (grain, cattle, Rus trade, iron and fish routes into the forum; the watch round of the gates), `gutters` (each street's fall direction, so rain runs downhill to the ditch or the sea; a slab-lined drain at the Coastal Gate per H11, no citywide sewer per the domestic-infrastructure report) and `fields`. The review map draws wells, guard posts and gutter outfalls.

## Runtime entry points

| Script | Role |
|---|---|
| `scripts/city/city_plan.gd` (`CityPlan`) | Loads the plan and heightfield; `ground_height`, `walk_height` (floors inside houses), `building_at`, `floor_height`, `slope_at` |
| `scripts/city/city_world_3d.gd` (`CityWorld3D`) | Builds the view, the sky, sun and fog (shared `SkyWeather3D` and `MapViewLighting`), pushes the world wind |
| `scripts/city/city_terrain_builder.gd` + `city_ground.gdshader` | Heightfield chunks, a far mesh, a horizon skirt; splat-blended cobble, earth, sand, mud, grass and slope rock |
| `scripts/city/city_building_builder.gd` | Footprint walls, gable roofs on the plan ridge, windows, lancets on churches, interiors with floor, inner walls, door reveal and ceiling |
| `scripts/city/city_fortification_builder.gd` | Curtains by state, merlons on the field side, gate houses, timber gates, dated towers, Toompea wall, castle |
| `scripts/city/city_vegetation_builder.gd` | Trees by species at real heights, chunked with visibility ranges |
| `scripts/city/city_dressing_builder.gd` | Hoist beams and wind-swung ropes on merchant gables, town banners, castle pennants |
| `scripts/city/city_water.gdshader` | Sea, stream and moat pools; waves travel with the wind |
| `scripts/city/city_collision_builder.gd` | Logic-plane collision: solid houses, wall quads with a door gap for enterable houses, curtains with gate gaps, towers, Toompea wall openings, cliffs over 38°, deep water |
| `scenes/world/reval_city/reval_city.tscn` | The playable scene: player, Kalev rig, orbit camera, roof lifting, day clock |
| `scenes/menu/seamless_city_label.gd` | Main-menu entry |

## Save and load

Not wired. The preview keeps no state and writes nothing to saves.

## Verification

- `python3 tools/city/build_reval_city_plan.py --check`
- `python3 -m unittest tests.python.test_build_reval_city_plan -v` (determinism, gates on the wall, no street breaches away from gates, no post-1343 towers, doors on footprints, Toompea relief)
- `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_city_plan` (plan, relief, hill ways, gates, towers, floors, interior sizes, roof frame, collision door gap and cliff, Toompea openings, castle towers)
- `tools/godot_render.sh --resolution 1600x900 res://tools/capture_reval_city_walk.tscn` walks Viru inward, Pikk jalg and Lühike jalg up to Toompea, Pikk to the shore, and into and out of the council hall; exits 1 on any block.
- `tools/godot_render.sh --script tools/capture_reval_city.gd` renders the review plates.
- `tools/godot_render.sh --script tools/verify_wind_direction.gd` checks that flags fly downwind for four wind directions.

Measured on the authoring machine (Apple GPU, 1600×900, minimized window): full scene ready in ~4 s, frame p50 7-13 ms walking the routes.

## Limits

- No NPCs, quests, interaction anchors, saves, swimming or night systems in this scene. The playable slice (forge, Mart, Act 1 cycles) still runs on `lower_town_slice`; re-homing its anchors onto the plan is follow-up work.
- Buildings are procedural shells from plot footprints: no kit GLB models, no upper floors, no furniture. Churches and the castle are massing models; St Mary's, St Olaf's, the Holy Spirit and the Dominican and Cistercian precincts need bespoke models.
- Plot footprints are modern survivals; individual houses are a plausible composite.
- The camera cannot see under overhangs it is already inside (3D-only roofs); occlusion uses the logic-plane walls.
- Life layers (wells, guards, flows, gutters) are data and review-map markers; no simulation reads them yet, and rain does not yet show water running in the gutters.
- Distant buildings beyond 1600 units and trees beyond 260 units are culled; there is no impostor skyline yet.
