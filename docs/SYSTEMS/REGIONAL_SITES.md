# Regional sites: distant destinations on the seamless-city pipeline

Status: implemented for the Paide pilot (task **R-1520**, [ADR 0042](../adr/0042-regional-site-plans.md)); the other nine sites are planned (R-1521..R-1529).

Scope: every distant travel destination is a georeferenced plan built by the same builder and shown by the same runtime as the seamless Reval city ([SEAMLESS_CITY.md](./SEAMLESS_CITY.md)): terrain from EU-DEM, sky with sun, moon and stars over the site's own latitude, clouds, weather, one wind, rain wetness and puddles, ground splat and road wear, vegetation, farmland, streams and ditches, fortifications and buildings. A new site is data only: an overlay, two trimmed input extracts and a two-node scene.

Out of scope: quests, dialogue, NPC schedules or battles inside a site; people and animals (off until a site task turns them on); furnished interiors (off: houses have doors but are not enterable); any seamless link between sites or between a site and Reval (leaving is always a journey on the global map); a coast at an inland site. The greybox prototype `content/maps/world_paide.rrmap` is still registered with the map audit and alignment tools; retiring it is a follow-up task (ADR 0042 "Equivalent-cost scope removal").

## What the player sees (Paide, May 1343)

- Choosing **Paide Castle** on the global travel map loads `scenes/world/sites/paide.tscn`. The player arrives on the road from where they came: the Reval road at the north edge (`from_world_sojamae`), the north-west field track (`from_world_kanavere`) or the Pernau road in the west (`from_world_parnu`). Started directly, the scene puts the player on the town's market place.
- The Order castle of Wittenstein on its levelled mound: a square upper ward with a wide north wing (chapel and chapter house) and a narrow east wing (refectory), the octagonal keep of about 30 m at the ward's south-west corner, an L-shaped outer bailey with stable, granary, kitchen and smithy, a west gatehouse towards the town, a north-east gate tower and a square south-east corner tower. A dry ditch with a few standing pools rings the bailey; the castle way and the north-east field way cross it on timber bridges.
- The small chartered town south-west of the castle: log and plank houses with thatch or shingle roofs along the roads, a kitchen-garden plot with a fruit tree behind most houses, a timber chapel and the market place.
- Open strip fields of rye, barley and oats with fallow strips, a wet meadow along the brook east of the castle with alder and willow carr, field-edge trees, a birch and spruce grove in the north-west, and the commons by the castle.
- Day, night, every weather and the season come from the shared sky; the sun stands about half a degree higher at noon than over Reval (58.889 N against 59.437 N). There is no sea: no FFT water, shore field, surf, harbour or ships.
- Walking into the 28 m edge band opens the global travel map and sets the player back inside, as in Reval.

Review plates (`tools/capture_regional_sites.gd`): `docs/reports/images/sites/paide_day_castle.png`, `paide_day_keep_from_town.png`, `paide_day_aerial.png`, `paide_night_castle.png`, `paide_rain_castle.png`, and `reval_day_aerial.png` (the city through the same path, sea and ships present).

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
python3 tools/city/build_reval_city_plan.py --check          # Reval byte-identical
python3 -m unittest tests.python.test_build_site_plan tests.python.test_build_reval_city_plan
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_regional_site_plan
tools/godot_render.sh --script tools/capture_regional_sites.gd
```

`test_regional_site_plan.gd` loads the Paide plan and scene, checks that no sea node exists while sky, sun and weather do, that every manifest spawn is a plan arrival inside the edge, that ids are site-prefixed, that the noon sun follows the site latitude and is restored on exit, and that walking into the edge opens the travel map.

## Limits

- Citizens, fauna, fish and interiors are off at Paide; houses keep a closed door and see-through window openings.
- The stream is a narrow wadeable brook (about 1.1 m deep); no swim pools are carved.
- The greybox `world_paide.rrmap`, its `scenes/world_travel/world_paide.tscn` and their audit, alignment and activation entries still exist (no longer routed); the global-map neighbour graph for Paide still reads the other greyboxes' transitions.
- The keep's 1343 completion, the ward wings and the bailey buildings are `plausible composite`; see [`docs/CANON.md`](../CANON.md).
- Captures run outside the game scene (the city view only), so the travel-map arrival and the edge are covered by tests, not plates.
