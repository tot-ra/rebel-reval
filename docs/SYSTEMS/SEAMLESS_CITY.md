# Seamless Reval city (1343)

Status: implemented as the game's Reval ([ADR 0031](../adr/0031-continuous-reval-city-plan.md), accepted 2026-10-07; board task to be filed, no board access in the authoring session). Attribution: `CREDITS.md` and `docs/THIRD_PARTY_NOTICES.md`. Scope: the whole walled Lower Town, Toompea, the shore to the 1343 waterline, the Härjapea and the near suburbs and fields as one continuous scene with real relief, the 1343 fortifications, enterable houses and churches, people, shipping, swimming, chimney smoke and one shared wind; every old Reval district destination now arrives here. Out of scope here: quests, dialogue and saves inside the city scene (the forge interior keeps them; see [Limits](#limits)).

Countryside (fields, pastures, woods): [`FARMLAND.md`](./FARMLAND.md). Review plates: [`docs/reports/reval_city_plan_2026-10-07.md`](../reports/reval_city_plan_2026-10-07.md).

## What the player can do

- Main menu → **Start**: Kalev wakes in his smithy (the `forge` scene, Mart, the anvil). Out through the courtyard door he steps into the city in front of his own house (`landmark.kalev_smithy`, a log house with a shingle roof off Viru street). Walking back in through that door returns to the forge interior. The old district maps are no longer reachable from the menu.
- Walk anywhere in the plan without a loading screen: in through the Viru gate, along Pikk and Lai to the Coastal Gate and down to the shore, up Pikk jalg or the Lühike jalg steps onto Toompea, out of the Cattle or Smiths' gates to the fields. Movement is 5× the district-map speed (maintainer request, for crossing the city quickly).
- Walk into any ordinary house, the council hall and the churches through their street door. The door swings inward as Kalev reaches it and shuts behind him once he moves on; roof and ceiling lift while he is inside, so the third-person, top-down and first-person cameras (`toggle_camera_view`) all see into the room.
- Swim: the sea and the water-filled moat use the game's swimming (wade, swim, dive with `player_dive`, breath).
- Magic: the Spellforge works as on the district maps; a Fireball flies as an ember orb and bursts on impact in the city view.
- Travel map (`M`): the district tab fast-travels inside the city (Kalev is moved in place, no reload: centre → forum, north → Pikk granary, monastery → St Olaf, Toompea → castle, harbour → fish landing, ...); the global tab starts journeys to distant regions. Walking within 28 m of the plan's edge opens the global travel map and sets Kalev back inside, so leaving the city always means choosing a destination. Returning from Padise, Harju, the sacred grove and other regions lands at the matching gate or road.
- People: gate garrisons and watch patrols (census residents on duty, [`GATE_GARRISONS.md`](./GATE_GARRISONS.md)), and the census residents of the houses around Kalev on their own timetables ([`CITIZENS.md`](./CITIZENS.md#in-the-city)); click one to see who they are.
- Birds: the game's bird flight and birdsong layers fly over the city. Flights are spawned across a 160 m window around Kalev, lifted 8 m over the highest ground in it, and the species mix follows where he is (`CityMapDefinition.bird_context_at`): gulls and terns on the shore and fishing beach, castle birds on Toompea, market birds round the forum, town birds in the Lower Town, open-country birds outside the walls.
- Ships: Hanseatic cogs ride at anchor in the roads north of the Coastal Gate, swinging bow-to-wind; fishing boats lie off the fish landing; one cog sails along the shore.
- Minimap (top right): a circular painted map that turns with the camera, a north mark, Kalev's arrow, and below it the district, the street (modern and 1343 name) and the building he is in.
- Camera: hold right (or middle) mouse and drag, or use the gamepad right stick, to orbit; mouse wheel to zoom; `Q`/`E` to turn. The camera pulls in front of walls and houses.
- Command line: `-- --city-spawn=<spawn id>`, for example `gate.viru`, `gate.coastal.outside`, `poi.forum`, `kalev_smithy`.

## How the plan is made

`tools/city/build_reval_city_plan.py` compiles three committed inputs into `content/world/reval_city/` (plan, heightfield, surface splat, cart-road raster and the painted `minimap.png`):

| Input | What it gives | Licence |
|---|---|---|
| `tools/city/data/osm_reval_extract.json` | streets, plot footprints, surviving towers, wall fragments, cliffs, coast | ODbL, © OpenStreetMap contributors |
| `tools/city/data/eudem25m_reval.json` | 25 m surface heights (trend only; rooftop bias removed) | EU-DEM v1.1, Copernicus |
| `tools/city/reval_1343_overlay.json` | everything 1343: wall anchors and states, towers, gates, Toompea edge, shoreline, Härjapea, moat, excluded streets and buildings, extramural roads, suburbs, wells, guard posts, barracks, markets, supply and watch flows | project |

Rebuild after editing the overlay: `python3 tools/city/build_reval_city_plan.py`. `--check` fails when the committed outputs are stale. `--import-osm <overpass.json> --import-dem <dem.json>` refreshes the source extracts (see the script header for the queries). The builder also writes `docs/reports/images/city/reval_city_plan.png`, a top-down review map.

Rules the compiler enforces:

- Coordinates: local metres, origin at the forum (59.43725 N, 24.74535 E), x east, y south; output in world units of 1 m (x east, z south), logic pixels = world units × 32. Kalev's rig is 1.83 units tall, so 1 m per unit keeps houses, walls and trees in proportion to him.
- Gates snap onto their street; a gate faces along its street.
- Streets inside the walls come from OSM, renamed from the 1343 street register where it has a record; excluded names (later streets, Rüütli, Uus, Väike-Karja, Patkuli stairs ...) are dropped; a street that crosses the curtain away from a gate is cut back to the inside (later wall breaches).
- Buildings come from OSM plot footprints inside the circuit or on Toompea; post-1343 landmarks and towers are excluded; back plots are thinned for 1343 density; material and roof follow street rank (limestone and tile on the spines, timber and thatch in the lanes); the ridge follows the plot's own axis.
- Terrain: EU-DEM trend plus open-country relief ([Ground relief, roads and prints](#ground-relief-roads-and-prints)), the walled town lowered by the surface-model rooftop bias, the Toompea table authored from the cliff edge, the hill ways carved as ramps, the beach and seabed from the 1343 shoreline, the Härjapea channel and the S/E ditch cut in.
- Stable IDs: `street.osm.<way>`, `bldg.osm.w<way>` / `bldg.osm.r<relation>`, `bldg.lm.<landmark>`, `bldg.<suburb>.<n>`, `gate.*`, `tower.*`, `curtain.NN`, `toompea_wall.NN`, `poi.*`, `flow.*`, `field.*`, `pasture.*`, `wood.*`, `farmstead.*`. OSM ids keep a building's id across rebuilds.

### Ground relief, roads and prints

Status: implemented. Scope: the open country outside the walls, the cart roads, and footprints in soft ground. Out of scope: deformation of the walkable surface (prints are visual; they change neither the heightfield, collision nor walking speed), prints from NPCs and animals (the `stamp_*` API is there, nothing calls it for them yet), and vertex-level rut geometry (ruts are shader relief, see Limits).

The EU-DEM trend is a smooth 25 m plate, so the compiler (`tools/city/terrain_relief.py`, called from `build_reval_city_plan.py` after the cut/fill passes) adds relief where nothing else authored the ground:

- **Swells and hummocks:** domain-warped fractal value noise at 260, 110, 48, 21 and 11 m wavelengths (amplitudes 5.0, 3.2, 1.8, 0.6, 0.18 m).
- **Gullies:** smooth ridged noise (95 m) cut up to 0.85 m, deeper where the broad swell is low.
- **Sand ridges:** 34 m wavelength, up to 0.85 m, 20–340 m from the water.
- **Hollow ways:** each `extramural_road` is sunk 0.24 m below its verge with a 0.13 m spoil berm either side, and the small relief is damped on the road so it stays travelable. Fades out within 40 m of the curtain, where the town plan owns the street.
- **Kept untouched:** everything inside the walls (heights within 120 wu of the forum are byte-identical to before), Toompea and its slope, 40 m of shore and the sea, the Härjapea, and the suburbs. The relief fades in from 16 m to 130 m outside the wall.

Everything is seeded lattice noise: the same inputs give the same `height.json`. Trees, grass and houses follow `ground_height`, so they sit on the new relief.

`content/world/reval_city/roads.png` (same rectangle and resolution as `splat.png`; import with `fix_alpha_border=false` or the road centre is overwritten) holds, per pixel: R road body, G signed lateral offset from the centreline (128 = centre, ±5 m), B traffic wear per road (`terrain_relief.ROAD_TRAFFIC`: Viru and the harbour road heaviest, the beach track lightest), A verge band. The splat no longer paints roads as flat mud; roads are packed earth there and the ground shader does the rest.

`city_ground.gdshader` reads that raster:

- **Wheel ruts:** two ruts a cart gauge apart (0.82 wu each side), a berm outside each and a trodden strip between where weeds grow on lightly used roads. The ruts wander with noise, vary in depth along the road and deepen with traffic. Computed as a height profile and lit through finite-difference normals; faded out with distance (`fwidth`) so far ground does not shimmer.
- **Dry:** pale dust, rough, ruts half-filled; footprints are soft with dusty rims.
- **Wet:** dark clay that gives under the wheel, deeper ruts and prints, shiny slick walls; water has a level: `puddles` raises it through the hollows, ruts and prints, so the deepest basins fill first and pools widen as rain accumulates. Gradation, driest to wettest: damp earth margin (darker, slightly glossy), a thin wet film that still shows the bed, then standing water (murky tint, near-mirror roughness, flat normal, rain rings while it is raining). Seep into soaked ruts is film only. `wetness` and `puddles` come from `SkyWeather3D` as before; review with `tools/godot_render.sh --script tools/capture_city_mud.gd -- --tag=x --wet=0.9 --puddles=0.3|1.0`.
- **Crests and hollows:** the heightfield texture gives curvature; crests dry to straw, hollows stay lush; grassy banks too steep for turf show bare sand before turning to rock.

`scripts/city/city_ground_trail.gd` (`CityGroundTrail`, built by `CityWorld3D`, fed by `reval_city.gd` each frame) keeps a 1024 × 1024 R8 relief image (0.04 wu cells, a 41 wu window that recentres on Kalev with its contents kept). Each 0.85 wu of walking presses a boot print (heel, arch and ball lobes, toe-out, left and right alternating) and heaps a rim; depth follows wetness (`0.4 + 1.15 * wetness`): dry ground only takes a faint print, soaked clay a deep one that seeps water and darkens to slick mud in the shader; prints bite where the splat says earth or mud (a faint print on grass, none on paving or in the sea). `stamp_foot`, `stamp_oval` and `stamp_track` are public so hooves and cart wheels can use them. The shader turns the image into relief, damp darkening and puddles. On dry soft ground a footfall also kicks up a puff of dust (`CPUParticles3D`, no texture asset); wet ground raises none. Prints are not saved: a teleport (> 10 wu in a frame) or leaving the window starts fresh ground.

Review: `tools/godot_render.sh --script tools/capture_terrain_relief.gd` renders the open country, the roads, and walked and wheeled prints, each dry and wet, to `docs/reports/images/city/terrain_*.png`.

### How buildings are built

Every house, hall and church is generated at load from its plan record (`plan.json` → `buildings[]`) by `CityBuildingBuilder.build_building`; nothing is hand-modelled. The record carries the footprint, `base_h`/`base_span` (lowest ground under the footprint and the slope across it), `wall_h`, `material`, `roof`, `roof_pitch_deg`, `ridge_angle`, the street `door` (point and outward angle), `kind` (`house`, `church`, `chapel`, `hall`) and `enterable`.

Chosen by the compiler (`tools/city/build_reval_city_plan.py`):

- Material, roof and height follow the plot's street rank ("wealth"): spine streets (Pikk, Lai, Viru, Vene, the forum) get limestone with tile (7.5–10.5 m eaves); middle ranks limestone or lime-plastered with tile or shingle (5.5–8 m); lanes and suburbs log or plank with thatch or shingle (3.2–4.8 m). Landmarks take their authored roof and nave height.
- The ridge follows one of the footprint's own axes (minimum-area rectangle). Near-square plots turn the gable to the street (Diele house); long plots roof along their length.
- The door sits on the footprint edge nearest the street. Because plot footprints are modern survivals, that edge can face straight into a neighbour; `fix_blocked_doors` then moves the door to the nearest edge with clear ground 1.2 m and 2.5 m outside (69 of 639 doors moved on 2026-10-07), and a house with no clear edge gets no door and is not enterable. Ordinary houses of 22–520 m², the council hall and the churches and chapels are `enterable`.
- Kalev's smithy is the enterable house nearest the overlay's `kalev_smithy.near_m` point.

Built at runtime (`scripts/city/city_building_builder.gd`):

1. **Wall ring.** `wall_ring(b, footprint)` orients the footprint consistently and fillets every corner with a short curve (`soften_ring`, `CORNER_SEGMENTS` = 3). Radius by material (`CORNER_RADIUS`): lime plaster 0.22 m, log 0.16 m, plank 0.14 m, dressed limestone 0.10 m, clamped to 30 % of the shorter adjoining edge. Walls, door leaves (`CityDoors.door_gap`), wall-foot weeds and the logic-plane collision of enterable houses all use this same ring, so the door gap lines up everywhere.
2. **Floor.** `CityPlan.floor_height` = `base_h + base_span + 0.12`: the floor is level with the highest ground under the house. Where the street is lower in front of the door, limestone steps (`_door_steps`) climb to the threshold. Churches, chapels and the council hall stand on a **levelled terrace**: the compiler (`terrace_landmarks`) cuts or fills the ground under the footprint to the street level 2 m outside the door and blends it back into the slope over 8 m, so their doors open at street level (before this, St Mary's door stood 5.2 m above Kiriku plats). Houses whose footprint spans 0.3-3 wu of height get the same cut with a 3 m blend (`HOUSE_TERRACE_*`; all levels are read before any plot is cut, then footprints are re-cut with a 2.2 m apron because the heightfield cell is 2 wu); bigger spans are merged OSM polygons and keep the runtime steps. Median door rise fell from 0.38 m to 0.13 m. Non-enterable houses have no interior floor, so `floor_height` puts their threshold at the street level in front of the door instead of the highest footprint ground; `_door_steps` uses up to 14 treads so a riser stays near 0.18 m.
3. **Walls.** One strip per ring edge from 0.7 m below ground (`SINK`, hides slope gaps) to the eave, with gable infill up to the roof line where an edge crosses the ridge. The door edge leaves a 1.5 × 2.55 m gap centred on the door (clamped to 20–80 % of the edge). Houses get windows every ~3.4 m on edges of 2.6 m or more; churches, chapels and the hall get tall lancets instead.
4. **Roof.** Tile roofs use the procedural monk-and-nun tile shader (`city_tile_roof.gdshader`); shingle and thatch keep their texture plates. A gable split along the ridge (`roof_frame`): pitch 52° thatch, 48° shingle, 50° tile, rise capped at 10.5 m, 0.38 m overhang all round. The cover has a thickness (`ROOF_COVER`: thatch 0.36 m, tile 0.13 m, shingle 0.11 m) that ends in a rounded roll at eaves and verges, and a half-round ridge cap runs the length of the ridge (`RIDGE_RADIUS`: bulky bound ridge on thatch, ridge tiles on tile, a ridge roll on shingle). Roll and cap carry roof UVs so they take the roof texture.
5. **Chimney.** 80 % of town houses that are not thatched get a stone stack through the roof near the ridge, rising 0.6–1.1 m above it (`CHIMNEY_SHARE`, `CHIMNEY_SIZE` 0.75 m). Thatched cottages keep a smoke hole. The stack top is recorded for smoke.
6. **Inside or cap.** Enterable buildings get an interior: inner walls inset by the wall thickness (limestone 0.62 m, timber 0.32 m) with a door reveal, a plank floor (boards about 0.2 m wide) and a ceiling at the eave. Inner walls are lime-washed (`city_limewash.gdshader`, darkened for indoors). **Cutaway:** the whole shell is split at `CUT_HEIGHT` (2.2 m above the floor) with `Shell.split_at`, which clips triangles at the plane. Everything above the cut (upper walls, gables, windows above head height) joins the roof node with the ceiling, and the wall stubs get a stone section cap (`wall_top_cap`, open at the door). While Kalev is inside, the roof node hides, so every camera sees a room cut at head height instead of tall walls and gables. Other buildings get a flat cap under the roof.
7. **Materials.** Walls and roofs use the weathered shaders (`city_weathered_wall.gdshader`, `city_weathered_roof.gdshader`, shared `city_weathering.gdshaderinc`): rising damp read from the ground heightfield, run-off streaks, lichen on walls, moss on roofs (shingle most, tile less, thatch least) and rain wetness from the weather.
8. **Batching.** Walls and the roofs of non-enterable buildings are merged per 96 m chunk and per material; each enterable building's roof (with its ceiling and chimney) is its own node so it can be hidden.

Around the buildings: `CityDoors` hangs the leaves (plank, braced, studded, ledged; five paints; latch and ring pull both sides). Farmstead outbuildings (`kind: outbuilding`: pigsty, sheep shed, byre, store, salt/smoke/cargo shed) get a smaller opening from `CityBuildingBuilder.door_size` (e.g. sty 0.62 x 0.9 m, byre 1.0 x 1.65 m, always 0.2 m under the eave; the wall gap, steps and collision follow it) and a `rough` leaf: bare weathered or tarred boards, two wooden ledges, a wooden latch bar, no ironwork or ring pull (checked by `test_outbuilding_doors_are_small_and_under_the_eave`); `CityWallFoot` scatters weed tufts along the wall foot (denser at corners, none in doorways) and hop/ivy climbers on about 9 % of houses; the splat paints trampled earth round each house and a muddy drip line at the wall foot; `CityChimneySmoke` streams smoke plumes (up to 28 within 180 m) over the lit stacks (about a third, with the shared day/night hearth schedule).

### Fortifications

Positions and roster from [`walls-gates-towers.md`](../../history/dossiers/topography/walls-gates-towers.md) and `RevalFortificationRegistry`; finish by maintainer direction (2026-10-07):

- Curtain: ~6.2 m limestone all round, crenellated on the field side, with a covered timber wall-walk (posts and a tiled lean-to roof) on the town side. Historically the south and south-east courses were still being built in 1343; showing them finished is a presentation choice recorded in the overlay (`presentation`).
- Towers (maintainer direction 2026-10-08): every wall tower is a round Tallinn drum with slit windows, a corbelled fighting gallery and a moderate (~50 degree) tiled cone; 13.5-16 m tall. 17 on the circuit: the 1343 set (Nunnatorn, Kuldjala, Rentenitorn, Stolting, Hinke, the Coastal Gate tower) plus towers recorded up to about 50 years later, shown early on purpose (Neitsitorn, Tallitorn, Saunatorn, Loewenschede, Köismäe, Epping, Plate, Bremen, At the Monks, Helleman, Assauwe), each labelled `invented (presentation)` with its real date in the overlay. Still absent: Kiek in de Kök (1475), Fat Margaret, Pikk Hermann and other 15th/16th-century works. Test: `test_no_post_1343_towers_are_built`.
- Gates: stone gate houses with a round-arched passage, open timber leaves, a tiled roof and two hanging town banners on the field face; the Coastal Gate house stands taller. Long Hill and Short Hill gates are wooden.
- Viru barbican (`barbicans` in the plan, overlay `barbicans`): the inner gate house and its two drums, 30 m of bailey between two 7.5 m side walls, an outer gate house (`gate.viru.outer`) and two outer drums, four round towers in all (`tower.viru_*`). Presentation choice: the real Viru foregate towers date from the 1370s. The causeway over the moat is widened to 26 m so the bailey stands on solid ground. Collision: side walls, outer jambs and drums. Test: `test_viru_gate_is_a_four_tower_barbican`.
- Moat: water fills the S/E ditch (presentation; the Ülemiste water rights date from 1345).
- Toompea: a stone wall round the plateau with openings wherever a way crosses it; the castle on the south-west with four corner towers flying Danish crown pennants.

### City life layers (data, not yet simulated)

`plan.json` carries `points_of_interest` (wells, the forum, the fish landing, guard posts at every gate, the castle garrison, the council watch, granary, mill pond, bath, bakers, malt house, meat benches, smiths), `flows` (grain, cattle, Rus trade, iron and fish routes into the forum; the watch round of the gates), `gutters` (each street's fall direction, so rain runs downhill to the ditch or the sea; a slab-lined drain at the Coastal Gate per H11, no citywide sewer per the domestic-infrastructure report) and `fields`. The review map draws wells, guard posts and gutter outfalls.

## Runtime entry points

| Script | Role |
|---|---|
| `scripts/city/city_plan.gd` (`CityPlan`) | Loads the plan and heightfield; `ground_height` (interpolated on the terrain mesh's own triangles, so feet meet the visible ground; test `test_ground_height_matches_terrain_mesh_triangles`), `walk_height` (floors inside houses), `building_at`, `floor_height`, `slope_at` |
| `scripts/city/city_world_3d.gd` (`CityWorld3D`) | Builds the view, the sky, sun and fog (shared `SkyWeather3D` and `MapViewLighting`), pushes the world wind |
| `scripts/city/city_terrain_builder.gd` + `city_ground.gdshader` | Heightfield chunks, a far mesh, a horizon skirt; splat-blended cobble, earth, sand, mud, grass and slope rock; cart-road ruts, dust and wet clay, crest/hollow tint |
| `scripts/city/city_ground_trail.gd` (`CityGroundTrail`) | Footprint and wheel-track relief window around Kalev, dust puffs |
| `scripts/city/city_building_builder.gd` | Buildings as described in [How buildings are built](#how-buildings-are-built): filleted wall ring, walls, door gap and steps, windows and lancets, gable roof with rolled edges and ridge cap, chimneys, interiors |
| `scripts/city/city_wall_foot.gd` (`CityWallFoot`) | Weeds at the wall foot and climbers on some walls (procedural leaf card, no texture asset) |
| `scripts/city/city_chimney_smoke.gd` (`CityChimneySmoke`) | Streamed `ChimneySmoke3D` plumes over lit chimneys near Kalev |
| `scripts/city/city_ships.gd` (`CityShips`) | Cogs at anchor, fishing boats, a cog under way (game boat builders, rescaled to metres) |
| `scripts/city/city_npcs.gd` (`CityNpcs`) | Site people and farm hands (logic bodies; rigs via the runtime); owns `CityCitizens` (`scripts/city/city_citizens.gd`), the census residents |
| `scripts/city/city_fauna.gd` (`CityFauna`) | Cats, dogs, horses, hens, geese, pigs, cattle, sheep, goats, hares and foxes placed from plan points of interest, gates and fields; at most 18 live near Kalev; visual only. See [animal placement plan](../reports/animal_placement_plan.md); tests `test_city_fauna` |
| `scripts/city/city_travel.gd` (`CityTravel`) | Redirects old Reval district destinations into city spawns; spawn positions; pending-spawn hand-off |
| `scripts/city/city_map_view.gd`, `city_map_definition.gd`, `city_runtime.gd` | The city on the shared `MapViewRuntime`: cameras, Kalev's rig, magic VFX, session clock and weather, swimming surface and depth, birds (`MapViewBirdFlight.path_origin` window, per-position habitat) |
| `scripts/city/city_fortification_builder.gd` | Curtains by state, merlons on the field side, gate houses, timber gates, dated towers, Toompea wall, castle |
| `scripts/city/city_vegetation_builder.gd` | Trees and shrubs by species at typical heights (town oak ~12 m, orchards ~4 m, hazel/elder ~3 m), chunked with visibility ranges |
| `scripts/city/city_grass.gd` (`CityGrass`) | Grass tufts streamed in 16-unit chunks around Kalev, thinned on trodden earth, absent on paving, floors, water and steep banks |
| `scripts/city/city_doors.gd` (`CityDoors`) | Hinged door leaves in the door gaps, styles per house, open/close as Kalev comes and goes |
| `scripts/city/city_minimap.gd` + `city_minimap.gdshader` (`CityMinimap`) | Circular camera-up minimap and the district/street/building labels (`CityPlan.location_at`) |
| `scripts/map/view3d/fieldstone_paving.gdshaderinc` | Fieldstone street paving shared with the district terrain shader |
| `scripts/city/city_dressing_builder.gd` | Hoist beams and wind-swung ropes on merchant gables, town banners, castle pennants |
| `scripts/city/city_water.gdshader` | Sea, stream and moat pools; waves travel with the wind |
| `scripts/city/city_collision_builder.gd` | Logic-plane collision: solid houses, wall quads with a door gap for enterable houses, curtains with gate gaps, towers, Toompea wall openings, cliffs over 38°; sea and moat stay open for swimming |
| `scenes/world/reval_city/reval_city.tscn` | The playable scene: spawn hand-off, roof lifting, the smithy door into `forge`, the edge-of-plan travel map, in-place fast travel (`arrive_at`) |
| `scripts/global/door_navigator.gd` | `go_to_scene` routes old district ids through `CityTravel.redirect` and moves Kalev in place when the target is the city already loaded |
| `scripts/city/city_music_zones.gd` (`CityMusicZones`) | Picks the `MusicDirector` theme from Kalev's position: landmark zones with a radius, district fallback, hold radius against flapping |

## Music

Music follows where Kalev is, not a scene path (`reval_city.tscn` has an empty entry in `MusicDirector.SCENE_THEME_ROUTES`). Every 0.25 s the scene asks `CityMusicZones.update(xz, district_id)` and hands the result to `MusicDirector.set_zone_theme_override()` (or clears it). The most specific zone around Kalev wins (smallest radius): the council hall beats the forum, the forum beats the wider quarter. A theme already playing holds on for 1.25 x its radius. Where no zone reaches, the plan district decides (`CityPlan.district_id_at`); fields and far suburbs have no theme and the music fades out. Themes are the existing folders under `music/` (`center`, `raekoda`, `holy_spirit`, `north`, `oleviste`, `monastery`, `south`, `town`, `forge`, `garden`, `harbor`, `toompea`); each theme keeps its own playlist, so nothing is mixed into one random list.

`MusicDirector` crossfades between themes (3 s, a second `OutgoingThemePlayer`), also on district scene changes. The scene's day clock is pushed to `MusicDirector.set_cycle_progress()` so night playlists and the night ducking apply.

Add or move a zone by editing `CityMusicZones.ZONES` (centre in world units, radius, theme id). Tests: `--filter=test_city_music_zones`.

## Save and load

Not wired inside the city: position, door states and people are not saved. Saving in the forge works as before; loading a save made in a district scene arrives through the redirect at the matching city spawn.

## Verification

- `python3 tools/city/build_reval_city_plan.py --check`
- `python3 -m unittest tests.python.test_build_reval_city_plan -v` (determinism, gates on the wall, no street breaches away from gates, no post-1343 towers, doors on footprints, Toompea relief)
- `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_city_ground_trail` (neutral ground, foot press and rim, alternating prints, recentre keeps prints, paving takes none, road raster, open-country relief)
- `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_city_plan` (plan, relief, hill ways, gates, towers, floors, interior sizes, roof frame, collision door gap and cliff, Toompea openings, castle towers)
- `tools/godot_render.sh --resolution 1600x900 res://tools/capture_reval_city_walk.tscn` walks Viru inward, Pikk jalg and Lühike jalg up to Toompea, Pikk to the shore, and into and out of the council hall (door opens, roof lifts, top-down and first-person shots inside, door shuts behind him), then checks people (≥ 20), chimneys (≥ 200), birds in flight (with distance and height from Kalev), in-place fast travel to the Pikk granary, smoke plumes there, swimming off the fish landing, a Fireball orb over the forum, and the travel map at the plan edge; exits 1 on any failure.
- `tools/godot_render.sh --script tools/capture_reval_city.gd [-- --only=a,b]` renders the review plates (door plates are framed from the street side of the built door gap).
- `tools/godot_render.sh --resolution 1600x900 res://tools/profile_reval_city.tscn [-- --quick]` measures frame time at three spots and with each layer removed.
- `tools/godot_render.sh --script tools/verify_wind_direction.gd` checks that flags fly downwind for four wind directions.

Measured on the authoring machine (Apple M5 Pro, 1600×900, minimized window): scene ready in ~5.3 s. Frame time is **not yet acceptable**: 50–135 ms per rendered frame on the walk routes with the full runtime. The profiling probe shows the city geometry layers cost little (removing buildings, trees, grass, smoke, ships or weeds saves under 5 ms); the cost sits in the `MapViewRuntime` subtree, most likely the ~40 NPC rigs plus the runtime's per-frame scan of all scene nodes for actors. The earlier figure (p50 ~14.5 ms) was measured per physics tick and understated it.

## Limits

- Performance: see Verification; NPC rigs need distance culling or the crowd renderer, and the actor scan needs to stop walking the whole scene each frame.
- No quests, dialogue, interaction anchors or saves in the city scene; the Act 1 cycles still run on `lower_town_slice` and the forge. City NPCs do not talk, react or fight.
- The old district scenes and their `.rrmap` maps are still in the repository and the transition manifest (redirected, not deleted).
- Buildings are procedural shells from plot footprints: no kit GLB models, no upper floors. Lived-in houses near Kalev are furnished and split into rooms by [`HOUSEHOLDS.md`](./HOUSEHOLDS.md); churches and halls stay empty. Church interiors are an empty nave; the castle is a massing model. Bespoke, navigable landmark sites replace the generic shells one site at a time ([Landmark sites](./CITY_LANDMARK_SITES.md), ADR 0032): Raekoja plats is done; Kiriku plats and St Mary's, the parish churches, the castle and the gates are planned.
- Corners are filleted at plan level only: the eave line, gable verges and window reveals are still straight-edged, and walls stay perfectly plumb (no lean or bulge).
- Some plan doors open almost straight onto a neighbour's wall (plots from modern footprints); the door plates skip them.
- Plot footprints are modern survivals; individual houses are a plausible composite.
- Ruts, prints and mud are shader relief on a 2 wu mesh: they shade and shine correctly but have no silhouette, and a low grazing camera sees them flat. Prints are lost beyond the 51 wu trail window and are not saved. The mud-slowing mechanic of the district maps is not wired to the city ground. NPC feet, hooves and carts do not leave tracks yet. Open-country relief is generic noise, not the real 1343 terrain: only the DEM trend is sourced.
- Life layers (wells, flows, gutters) are data and review-map markers; rain does not show water running in the gutters.
- Distant buildings beyond 1600 units, trees beyond 260 units, shrubs beyond 120 units, weeds beyond 90 units and grass beyond ~50 units are culled; there is no impostor skyline.
- Ships have no collision and cannot be boarded.
- Music zones are hand-placed circles around plan landmarks, not authored per building; interiors other than the council hall share their quarter's theme. Every theme plays its whole folder shuffled; there are no battle or stinger cues in this scene.
- Doors have no sound and no lock state; non-enterable houses keep theirs shut.

### Tall grass, wading drag and trail

Status: implemented ([ADR 0039](../adr/0039-tall-grass-height-and-wading-drag.md)). Grass height follows use: `CityGrass.wildness_at` (distance from roads and house walls) scales clump height from 0.55 beside a road or wall to 2.7 (about waist high) in open meadow. In dense wild grass the player walks at half speed (`CityGrass.walk_drag_at` through `Player.set_ground_drag_provider`, wired in `reval_city.gd`; dry land only). The grass shader parts and lays blades over in proportion to their own height around the walker and around the last 8 footfalls (`VegetationInteractionBuffer`, 4 s spring-back), so a lane stays open behind. Tests: `test_city_grass_height`, `test_vegetation_interaction_buffer`, `test_grass_interaction`. Review plates: `tools/godot_render.sh --script tools/capture_tall_grass.gd` writes `build/grass/tall_{behind,side}_<tag>.png`. Limits: NPCs and animals neither part the grass nor slow down; the trail is session-only.

### Road surface and verge grass

Meadow turf is matte and carries mid-scale relief (`grass_height` in `city_ground.gdshader`): clumps of ~2 m, ridged tufts of ~0.7 m and blade lumps drive cavity shading (`grass_relief_shade`) and a tussock normal (`grass_relief_normal`, faded with distance like the other micro relief) on pure turf only, and turf gets `grass_specular` 0.04 with roughness pushed to 1, so low sun no longer glints off the plate as a waxy sheet (earth, road, sand and paving keep their gloss). Review plate: `tools/godot_render.sh --script tools/capture_meadow_sheen.gd -- --tag=<t>` writes `build/grass/meadow_{high,low}_<t>.png`. Still shader-only relief: silhouettes come from the blade meshes of `CityGrass`.

Cart roads stay bare (`CityGrass.road_clearance`, from `roads.png`: body times traffic wear): no blade clumps or accent plants stand on the road body, tufts that do survive on a quiet edge are scaled to 30 %, and the ground shader shows only a faint green fuzz of sprouts on lightly used margins. Grass stands on the verge beside the road. Ruts are deeper (`road_profile`) and fill with water in patches rather than as continuous rails. Review plates: `tools/godot_render.sh --script tools/capture_city_mud.gd -- --tag=<t> [--wet=0.9]` writes `build/mud/{eye,game,low,verge}_<t>.png`. Tests: `test_city_ground_trail` (wet vs dry depth, road clearance). Still shader relief only: prints have no silhouette on a grazing camera and NPC feet, hooves and carts leave no tracks.
