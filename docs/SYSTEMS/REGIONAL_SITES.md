# Regional sites: distant destinations on the seamless-city pipeline

Status: implemented for the Paide pilot (task **R-1520**, [ADR 0042](../adr/0042-regional-site-plans.md)), Padise (**R-1522**) and the Act 2 hinterland sites Harju, the rebel kings' camp and the sacred grove (**R-1527**..**R-1529**); the other sites are planned (R-1521, R-1523..R-1526).

Scope: every distant travel destination is a georeferenced plan built by the same builder and shown by the same runtime as the seamless Reval city ([SEAMLESS_CITY.md](./SEAMLESS_CITY.md)): terrain from EU-DEM, sky with sun, moon and stars over the site's own latitude, clouds, weather, one wind, rain wetness and puddles, ground splat and road wear, vegetation, farmland, streams and ditches, fortifications and buildings. A new site is data only: an overlay, two trimmed input extracts and a two-node scene.

Out of scope: quests, dialogue, NPC schedules or battles inside a site; people and animals (off until a site task turns them on); furnished interiors (off: houses have doors but are not enterable); any seamless link between sites or between a site and Reval (leaving is always a journey on the global map); a coast at an inland site. The greybox prototype `world_paide.rrmap` and its `world_travel` scene are retired (task **R-1551**, ADR 0042 "Equivalent-cost scope removal").

## What the player sees (Paide, May 1343)

- Choosing **Paide Castle** on the global travel map loads `scenes/world/sites/paide.tscn`. The player arrives on the road from where they came: the Reval road at the north edge (`from_world_sojamae`), the north-west field track (`from_world_kanavere`) or the Pernau road in the west (`from_world_parnu`). Started directly, the scene puts the player on the town's market place.
- The Order castle of Wittenstein on its levelled mound: a square upper ward with a wide north wing (chapel and chapter house) and a narrow east wing (refectory), the octagonal keep of about 30 m at the ward's south-west corner, an L-shaped outer bailey with stable, granary, kitchen and smithy, a west gatehouse towards the town, a north-east gate tower and a square south-east corner tower. A dry ditch with a few standing pools rings the bailey; the castle way and the north-east field way cross it on timber bridges.
- The small chartered town south-west of the castle: log and plank houses with thatch or shingle roofs along the roads, a kitchen-garden plot with a fruit tree behind most houses, a timber chapel and the market place.
- Open strip fields of rye, barley and oats with fallow strips, a wet meadow along the brook east of the castle with alder and willow carr, field-edge trees, a birch and spruce grove in the north-west, and the commons by the castle.
- Day, night, every weather and the season come from the shared sky; the sun stands about half a degree higher at noon than over Reval (58.889 N against 59.437 N). There is no sea: no FFT water, shore field, surf, harbour or ships.
- Walking into the 28 m edge band opens the global travel map and sets the player back inside, as in Reval.

Review plates (`tools/capture_regional_sites.gd`): `docs/reports/images/sites/paide_day_castle.png`, `paide_day_keep_from_town.png`, `paide_day_aerial.png`, `paide_night_castle.png`, `paide_rain_castle.png`, and `reval_day_aerial.png` (the city through the same path, sea and ships present).

## Padise (April 1343)

Status: implemented (task **R-1522**). Scope: the Cistercian house of Padise before the St George's Night attack, as an open estate on the river plateau, on the shared site pipeline. Out of scope: the later quadrangle, stone church (1448), gate and gun towers and moat (period rule); monastery interiors and the P6-009 vaulted routes (**R-322**); burnt shells after the attack (the plan is one state; the controller's after-attack phase only empties the house); the greybox is retired (task **R-1556**): `world_padise.rrmap`, its `world_travel` scene, `test_world_padise_1343.gd` and `tools/capture_padise_view.gd` are gone, with their registry, catalog, audit, threshold, benchmark and P6-002 entries. Location `world_padise`, map `world.padise`, the spawns and every controller anchor id are unchanged (anchors are plan points of interest).

- Choosing **Padise Monastery** on the global travel map loads `scenes/world/sites/padise.tscn` (`world_padise`). The player arrives on the Reval road at the east edge (`from_reval_west`) or on the Pernau road at the south edge (`from_world_parnu`); started directly, inside the cart gate of the close (`padise.spawn.close`). The 600 m frame is centred on the later monastery ruin (59.2276 N, 24.1407 E).
- On the plateau east of the Kloostri river: the early limestone house (later buried under the west range) and the building with arched niches south of it, the two masonry buildings Kadakas (AVE 2011) places before the quadrangle; round a grass garth the timber oratory, the timber east range (chapter room) and south range (refectory); the lay brothers' range, the guest house, the infirmary and the brewhouse. No wall closes the estate.
- East of the close the grange (barn, granary, byre, smithy) with its work yard and a small orchard; a few tenant farmsteads with gardens on the Reval road. The river bends round the plateau's west and south; the road east to Harju and Reval fords it below the house (today's Kloostri bridge) and runs on west to Hapsal; the Pernau road leaves south. South of the river loop the watermill stands below the mill pond, a widened river reach (the builder has no separate pond record). Strip fields north, east, south and west, a wet meadow inside the loop, spruce and pine woods west of the river.
- `scenes/world/sites/padise_site.gd` extends the site level and mounts `PadiseMonasteryController`. `PadiseMonasteryController.definition_from_plan(plan)` turns every plan point of interest with an `anchor_id` into an interaction anchor under the greybox id (`room_cloister_garth`, `landmark_timber_oratory`, `room_lay_brothers`, `room_infirmary`, `room_brewhouse`, `landmark_monastery_well`, ...); the four `cloister_walk_*` points are view landmarks. Before `phase.act1_climax` a choir monk stands before the oratory and a lay brother at the lay range (`PadiseMonkActor`, mirrored into 3D by the runtime); from `phase.act1_climax` on the house is empty. The controller owns the music (`holy_spirit`, then `monastery`); the site plays no zone theme of its own.
- Terrain is the EU-DEM trend and the river cut only (`terrain.relief` false: the shared open-country swells put a hollow under the plateau).

Review plates (`tools/godot_render.sh --script tools/capture_padise_site.gd`): `docs/reports/images/sites/padise_day_monastery.png`, `padise_day_close.png`, `padise_day_mill.png`, `padise_day_aerial.png`, `padise_night_monastery.png`, `padise_rain_monastery.png`; the plan review is `padise_plan.png`. Tests: `tests/godot/test_padise_site.gd` (plan, ids, 1343 state, anchor contract, sky and weather without sea, monks before and after the attack, spawns, edge to travel map, travel neighbours) and `tests/godot/test_padise_monastery_controller.gd`.

Limits: the plan points of interest are anchors, not props: there is no well model, cloister walk roof or cemetery cross yet; generic timber footprints stand in for the AR-08 building set (**R-966**); the monks keep the greybox rigs (townswoman, watchman variants).

## Act 2 hinterland: Harju village, rebel kings' camp, sacred grove

Status: implemented (tasks **R-1527**, **R-1528**, **R-1529**). Scope: three invented places of the Harju countryside as small site plans on the shared pipeline, each on the EU-DEM of a representative real point east of Reval; every record is authored in the overlay and labelled in [`CANON.md`](../CANON.md). Out of scope: quests, dialogue and command-hub gameplay; citizens, animals and interiors (feature flags off); spirit-world content at the grove ([ADR 0041](../adr/0041-spirit-sight-auras-and-soul-lights.md)); burnt or emptied phase states; the greyboxes of all three are retired. [ADR 0027](../adr/0027-reval-hinterland-streaming-group.md), as amended by ADR 0042, keeps all three as explicit travel; the Reval plan has only the Harju gate and its extramural suburb (`suburb.harju`, `district.harju`), not this village, so nothing is duplicated.

Decision (2026-10-10): the terrain points are the recommended ones (the maintainer did not answer within the session; a new point only changes `site.origin`, the bbox and the two extracts): Rebala for the village, the Pirita valley at Vaskjala for the camp, Kostivere for the grove. The frames: Harju 700 m (ADR 0042's table and R-1527; the first cut was 600 m and grew by a 50 m outer ring of fields, wet meadow and woods, the village itself unchanged), camp and grove 500 m.

- **Harju village** (`scenes/world/sites/harju.tscn`, `world_harju`, frame 700 m on Rebala, 59.4600 N, 25.0881 E, April 1343): five farmsteads round a village common with a sweep well, each a barn-dwelling (`rehielamu`: smoke room and threshing floor under one thatch) with a granary and a shed; two smoke saunas by a brook in the low western meadow; open strip fields north, east and south-east; a fenced common pasture; birch, rowan and oak in the yards; spruce, pine and birch woods to the south. No chimney anywhere: a smoke plume rises over every smoke room and sauna. Arrivals: `from_reval_east` and `from_world_sojamae` on the Reval road at the west edge, `from_world_rebel_kings` on the forest track at the south-west edge, `from_world_sacred_grove` on the south track, `from_world_kanavere` on the east road; started directly, on the common (`harju.spawn.green`). Edge arrivals stand on their road about 40 m inside the edge. The `world_harju` greybox (rrmap, `world_travel` scene, registry, catalog, distant-definition, audit, threshold, benchmark, location-activation and P5-003 entries, `test_harju_rural_architecture.gd`, `test_harju_activation_manifest.py`) is retired (R-1527). ADR 0042 takes `world.harju` out of the planned `reval_hinterland` group of ADR 0027: the Harju parts of UF-15 (R-1133) and UF-15a (R-1213) are re-scoped (notes on both rows and in [`UF-15_hinterland_maps.md`](../tasks/urban_form/UF-15_hinterland_maps.md)); R-1340 (RG-2) is superseded.
- **Rebel kings' camp** (`scenes/world/sites/rebel_kings.tscn`, `world_rebel_kings`, frame 500 m on the Pirita valley at Vaskjala, 59.3666 N, 24.9500 E, May 1343): a clearing on the east bank of the Pirita (OSM course) in spruce and pine forest; the four kings' shelters, a store and the council fire under a plain standard inside a stake fence (`palisade` circuit) with two wooden gaps; eight groups of low pole-and-bough shelters round cooking fires on a trodden lane outside it; a field smithy by the Harju track; fenced horse lines on a meadow east of the camp; a watering place on the river. Arrivals: `from_world_harju` on the Harju track at the east edge, `from_world_kanavere` on the valley track at the south edge; started directly, before the east gap (`rebel_kings.spawn.camp`). The `world_rebel_kings` greybox (rrmap, `world_travel` scene, registry, catalog, distant-definition, audit, threshold, benchmark, alignment and the P5-003 activation gate, whose last target it was) is retired.
- **Sacred grove** (`scenes/world/sites/sacred_grove.tscn`, `world_sacred_grove`, frame 500 m on Kostivere, 59.4270 N, 25.0962 E, May 1343): old oaks, lindens, ash and elm spaced on a low rise west of the Jõelähtme river (OSM course), four cup-marked offering stones under them, a stone-rimmed spring at the foot of the rise on a wet meadow, an open meadow below the grove and spruce, birch and alder forest round it. No building. Arrivals: `from_reval_south` on the footpath at the west edge, `from_world_harju` on the footpath at the north edge; started directly, on the meadow below the grove (`sacred_grove.spawn.meadow`). Leaving for Reval still lands outside the Harju gate (`from_world_sacred_grove` -> `gate.harju.outside` in `CityTravel.REDIRECTS`). The `world_sacred_grove` greybox (rrmap, `world_travel` scene, registry, catalog, audit, threshold, benchmark and P5-003 entries, `test_sacred_grove_map.gd`) is retired (R-1529).
- `scenes/world/sites/hinterland_site.gd` (the three scenes' script) extends the site level and dresses the plan points of interest the builder does not draw, by `kind`: `smoke` (a plume at `smoke_h_m` above the ground), `campfire` (stone ring, logs, `CandleFlame3D` flame, flickering `OmniLight3D` driven by `DomesticHearthLight3D` from the level's cycle progress: embers by day, bright at night; plus a plume; size `fire_size`), `offering_stone` (a half-sunk boulder of `size_m` with cup marks) and `spring` (a pool of `radius_m` with a stone rim). Plumes join the shared `CityChimneySmoke` streamer (world wind, nearest 28 within 180 m). Fire rings, stones and the spring are solid on the logic plane. The static `dress(plan, world)` and `apply_dressing_cycle(root, progress)` let capture tools dress a bare `CityMapView`.
- Inputs: `tools/city/sites/{harju,rebel_kings,sacred_grove}_1343_overlay.json`, `tools/city/data/{osm,eudem25m}_<site>.json` (the OSM query takes waterway, natural and landuse ways only; only the two river courses are traced into the overlays). Terrain relief stays on (the shared open-country swells read right on these grounds); the grove's datum margin is 4 m so the river bed stays above zero.

Review plates (`tools/godot_render.sh --script tools/capture_hinterland_sites.gd`): `docs/reports/images/sites/harju_day_arrival.png` (arrival on the Reval road), `harju_day_village.png`, `harju_day_farmstead.png`, `harju_dusk_fields.png`, `harju_day_aerial.png`, `harju_night_village.png`, `harju_rain_village.png`; `rebel_kings_day_camp.png`, `rebel_kings_day_stockade.png`, `rebel_kings_day_aerial.png`, `rebel_kings_night_camp.png`, `rebel_kings_night_fire.png`; `sacred_grove_day_meadow.png`, `sacred_grove_day_stones.png`, `sacred_grove_day_spring.png`, `sacred_grove_day_aerial.png`, `sacred_grove_night_grove.png`; plan reviews `<site>_plan.png`; the edge-to-travel-map plate `harju_edge_travel_map.png` comes from the real site scene (`tools/godot_render.sh res://tools/capture_site_edge_travel.tscn -- --site=<site>`). Tests: `tests/godot/test_hinterland_sites.gd` (plans, ids and prefixes, spawns inside the edge, village, camp and grove content, sky and weather without sea, dressing and plumes, fire day/night, edge to travel map, travel neighbours and the grove's return to the Harju gate) and `tests/python/test_build_site_plan_hinterland.py`.

Limits: plumes reuse the chimney streamer's per-id schedule, so about one plume in three burns only by day, only at night or never; shelters are thatched outbuildings, not bough or hide models; the great oak is a point of interest, not a modelled tree (the grove's oaks come from the grove fill); there is no well model on the Harju common, no standard pole, carts or horses (fauna off); the spring pool is a flat disc on the ground, not a carved basin.

## Sky, night and far ground at the sites (shared systems)

The site sky uses the site's own origin as the `SkyAstronomy` observer (59.37 N for the hinterland, Paide and Padise), so the sun curve is already right for the latitude: the review plates' night shot (cycle progress 0.865) is a sun at about -6 degrees and 0.96 about -15 degrees in late April. What looked wrong was the shared look of that twilight, fixed once for every map and site:

- **Twilight sky.** `sky_weather_3d.gdshader` (and the water's mirror in `map_view_water.gdshader`) add a linear `TWILIGHT_TOP` / `TWILIGHT_HORIZON` glow over the night floor, fading from 0 at -18 degrees to full at the horizon. The `source_color` night colours alone decode to about 0.0015 linear, so the dome was black by -6 degrees.
- **Twilight ground.** `MapViewLighting.twilight_fill_blend` crossfades from `CIVIL_TWILIGHT_HORIZON_BLEND` (0.7) times a `TWILIGHT_FILL_CURVE` (0.5) tail to the day blend, so land, stockades and roads stay legible through civil and nautical twilight (pitch black before).
- **Far crop strips.** `CityFarmland` reads its `FAR_SOIL` / `FAR_GREEN` swatches as sRGB vertex colour (`vertex_color_is_srgb`); as linear they drew as pale cream bars.
- **No hole in the middle distance.** `CityTerrainBuilder` gives `FarTerrain` no visibility range. A range is measured to the mesh centre (the plan centre), so on a 700 m site plan the far mesh stayed hidden while near chunks beyond `NEAR_RANGE` were already culled, which showed as a pale slab (the sky) over the far fields in `harju_day_aerial.png`. The shader's `FAR_TERRAIN_CUT` still sinks the far mesh near the camera. Test: `tests/godot/test_city_far_terrain.gd`.

## Data and pipeline

| File | What it is |
|---|---|
| `tools/city/sites/<site_id>_1343_overlay.json` | Hand-authored 1343 site: `site` block, castle circuit, gates, towers, inner walls, ditch, stream, roads, settlement rules, buildings, field blocks, pastures, trees, points of interest, arrival spawns, districts |
| `tools/city/data/osm_<site_id>_extract.json` | Trimmed OpenStreetMap extract (ODbL); at Paide it supplies only the keep position |
| `tools/city/data/eudem25m_<site_id>.json` | EU-DEM v1.1 25 m samples (Copernicus) for the terrain trend |
| `content/world/<site_id>/{plan.json,height.json,splat.png,roads.png,minimap.png}` | Builder output, same schema (`rr.city_plan.v1`) and files as Reval, plus `.import` sidecars |

Builder: `tools/city/build_site_plan.py --site <site_id> [--check]` (also `tools/city/build_reval_city_plan.py --site <site_id>`). `--site reval_city`, the default, runs the Reval builder unchanged; its `--check` stays byte-identical. The shared geometry, DEM, raster and review helpers stay in `build_reval_city_plan.py`; the regional builder imports them.

The `site` block of the overlay:

| Key | Meaning |
|---|---|
| `id` | Bare snake_case site id (`paide`), the directory name and the prefix of every record id |
| `location_id`, `map_id`, `scene_id` | Existing travel ids, kept stable (`world_paide`, `world.paide`, `world_paide`) |
| `origin`, `bounds_m`, `metres_per_world_unit` | Georeference: origin latitude/longitude, the frame in metres from the origin (x east, y south) |
| `coast` | `auto`: the builder writes `site.coast` true only when it draws a shoreline (none yet; Paide is inland). `CityPlan.has_coast()` reads it; plans without a `site` block (Reval, the water sandbox) count as coastal |
| `features` | `citizens`, `fauna`, `interiors`; all `false` until a task enables them |
| `default_spawn` | Arrival when no travel spawn is pending |
| `inputs` | Extract paths, the OSM bbox, the Overpass query and the DEM grid used to fetch them |
| `music_theme` | MusicDirector theme id, or empty for none |

Every overlay section is optional, so a site may have no wall circuit, no ditch, no stream, no settlement or no fields. A castle is a `circuit` (anchors, gate refs, tower refs), free-standing `towers` (form `octagonal` for a keep, `square` for a corner tower, `gate_rect` carried by a gate), and `inner_walls` with openings. Heights are stored above a local datum a little under the lowest ground (`site.datum_asl` in the plan), so no inland ground falls below the runtime's sea level.

## Stable IDs

- Location, map and spawn ids from the travel graph do not change: `world_paide`, `world.paide`, `from_world_kanavere`, `from_world_sojamae`, `from_world_parnu`. Each manifest spawn of the location is a plan arrival (`spawns[].id`) with a site record id (`paide.spawn.from_world_sojamae`).
- Every record the builder writes is `<site_id>.<kind>.<name>`: `paide.tower.keep`, `paide.gate.west`, `paide.gate.northeast`, `paide.ditch`, `paide.brook`, `paide.road.castle`, `paide.bldg.north_wing`, `paide.bldg.house.07`, `paide.field.east.03`, `paide.garden.07`, `paide.poi.market`, `paide.district.castle`.
- Ids come from the overlay or from order inside one authored record (house rows, field strips), never from OSM ids; regenerating a plan with the same overlay keeps them. Editing a settlement row or field block may renumber the records it makes.

## Runtime

| Entry point | Role |
|---|---|
| `scenes/world/sites/site_level.gd` | Extends the city level (`scenes/world/reval_city/reval_city.gd`); overrides `load_plan()`, `scene_id()`, `default_spawn()` and music; sets the sky observer to the plan origin and resets it on exit |
| `scenes/world/sites/hinterland_site.gd` | Script of the Harju, rebel kings' camp and sacred grove scenes: dresses `smoke`, `campfire`, `offering_stone` and `spring` points of interest (see the Act 2 hinterland section) |
| `scenes/world/sites/<site_id>.tscn` | Two nodes like the city scene, with `site_id` exported |
| `CityPlan.load_site(id)` | Loads `content/world/<id>/`; `site_dir`, `site_id`, `file_path()`, `has_coast()` (the `site.coast` flag), `feature_enabled()`, `origin_latitude()`, `origin_longitude()`, `arrival_spawn()` |
| `CityWorld3D` | Builds the sea, shore field, harbour, shore dressing and ships only when `has_coast()` |
| `CityMapDefinition` | Map and location ids from the plan's `site` block; ditch ground is not read as harbour for birds |
| `CityTravel.spawn_position` / `consume_pending_spawn(scene_id)` | Plan arrivals before Reval gates and places; pending spawns keyed by the site's scene id |
| `SkyAstronomy.set_observer` / `reset_observer` | Sun, moon and sunrise follow the observer latitude; the stars turn by the longitude east of Reval |
| `CityFortificationBuilder.tower_centre` | The keep stands on its own point (mesh and collision); wall towers still project toward the field |
| `CitizenRoster.load_for(plan)` | Reval's census, or a site's own `citizens.json` when its flag is on, otherwise empty |

Saves need nothing new: the travel destination and spawn are the same ids the greybox used, and nothing inside a site is persisted yet.

## How to add a site

1. Read the site's row in [ADR 0042](../adr/0042-regional-site-plans.md) and its dossier in [`docs/LOCATIONS/`](../LOCATIONS/README.md). Fix the frame centre on the real place (the Paide row's approximate centre was 1 km off the castle).
2. Fetch the inputs into an empty scratch directory: the Overpass query in the overlay's `inputs.overpass_query` (every way in the bbox plus the multipolygon relations, recursed down to their nodes) and EU-DEM samples on a 0.0004 deg (lat) by 0.0008 deg (lon) grid through `api.opentopodata.org/v1/eudem25m` (100 points per request). Use a user agent; the public Overpass server answers 406 without one and is often busy.
3. Copy `tools/city/sites/paide_1343_overlay.json` to `<site_id>_1343_overlay.json`, set the `site` block and author the 1343 records with a confidence label on each.
4. `python3 tools/city/build_site_plan.py --site <site_id> --import-osm <raw.json> --import-dem <dem.json>`; the import clips the raw dump to the bbox. Check `docs/reports/images/sites/<site_id>_plan.png` and `content/world/<site_id>/minimap.png`.
5. Run `godot --headless --path . --import` once so the new PNGs get `.import` sidecars; keep `process/fix_alpha_border=false` on `roads.png` as in Reval.
6. Add `scenes/world/sites/<site_id>.tscn` (copy `paide.tscn`, change `site_id`), point the location's `path` in `content/transitions/active_destinations.json` at it and keep every spawn id of the location; make each one a plan arrival inside the edge band.
7. Add the site's confidence rows to [`docs/CANON.md`](../CANON.md), attribution rows to [`THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md), a section here, and tests in `tests/godot/test_regional_site_plan.gd` and `tests/python/test_build_site_plan.py`.

## Verify

```bash
python3 tools/city/build_site_plan.py --site paide --check
for s in harju rebel_kings sacred_grove; do python3 tools/city/build_site_plan.py --site $s --check; done
python3 tools/city/build_reval_city_plan.py --check          # Reval byte-identical
python3 -m unittest tests.python.test_build_site_plan tests.python.test_build_reval_city_plan
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_regional_site_plan,test_hinterland_sites
tools/godot_render.sh --script tools/capture_regional_sites.gd
tools/godot_render.sh --script tools/capture_hinterland_sites.gd
python3 -m unittest tests.python.test_verify_world_building_visual_gate   # sites stay out of the RRMap gate
```

`test_regional_site_plan.gd` loads the Paide plan and scene, checks that no sea node exists while sky, sun and weather do, that every manifest spawn is a plan arrival inside the edge, that ids are site-prefixed, that the noon sun follows the site latitude and is restored on exit, and that walking into the edge opens the travel map.

### Visual gate

Decision (2026-10-10, task **R-1619**): regional sites get no row in `docs/data/world_building_visual_benchmark.json`. That matrix is RRMap-based: its `automated_density` row comes from `tools/verify_map_composition.py` over a compiled RRMap, and a site has none (it is `content/world/<site>/plan.json`). `tools/verify_world_building_visual_gate.py` therefore leaves out every registry scene whose path starts with `res://scenes/world/sites/` (`REGIONAL_SITE_SCENE_PREFIX`), and drops the same map ids (`world.harju`, `world.sacred_grove`, `world.rebel_kings`, `world.padise`, `world.paide`) from the candidate manifests. A new site is excluded by its scene path alone. Its visual evidence is the `--check` build, the Godot tests and the review plates in `docs/reports/images/sites/` listed above. Alternative rejected: site rows pointing at `plan.json` and the plates, which would leave the density row permanently failing or need a second, plan-based density metric. Test: `tests/python/test_verify_world_building_visual_gate.py` (`test_regional_sites_are_not_rrmap_benchmark_rows`, `test_site_exclusion_is_by_scene_path_and_overrides_candidates`).

## Limits

- Citizens, fauna, fish and interiors are off at Paide; houses keep a closed door and see-through window openings.
- The stream is a narrow wadeable brook (about 1.1 m deep); no swim pools are carved.
- The global-map neighbour graph for Paide still reads the other greyboxes' transitions (Kanavere, Sõjamäe, Pärnu).
- The keep's 1343 completion, the ward wings and the bailey buildings are `plausible composite`; see [`docs/CANON.md`](../CANON.md).
- Captures run outside the game scene (the city view only), so the travel-map arrival and the edge are covered by tests, not plates.
