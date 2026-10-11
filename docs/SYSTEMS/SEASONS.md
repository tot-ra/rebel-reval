# Seasons

Status: partial (core **SeasonState** implemented; presentation tasks planned, [ADR 0045](../adr/0045-seasons.md)). Scope: the yearly cycle on top of day/night: climate, snow, ice, vegetation looks, sky, sea, clothing, smoke, movement. Out of scope: seasonal quests or economy effects (separate task and ADR if wanted).

## Player-facing behavior (target)

- Spring: buds, blossom, melt, mud and puddles. Summer: full leaf, fruit, short nights. Autumn: yellowing crowns, falling leaves that drift in wind and lie under trees. Winter: bare trees, grey straw-coloured grass, snow, ice, long nights.
- Snow falls slowly (fine), fast (heavy) or in large flakes. It settles on ground and roofs, grows icicles under eaves in the cold, and melts by itself when it warms.
- Puddles freeze in winter, then ponds, the moat and rivers, last the sea shore.
- Deep snow slows walking; over 0.5 m only roads are passable. Footprints stay for a while, like the mud trail logic.
- Citizens dress for the season. Chimneys smoke more in winter.
- The date and time are shown beside the map (already present); a debug control forces the date and season.

## Runtime entry points

| Piece | File | Status |
|---|---|---|
| `Snowfall3D` emitter | `scripts/map/view3d/snowfall_3d.gd` | implemented (test `tests/godot/test_snowfall.gd`, plates `tools/capture_snowfall.gd`) |
| `SeasonState` (pure climate by date) | `scripts/global/season_state.gd` | implemented (test `tests/godot/test_season_state.gd`) |
| Calendar, sun path | `scripts/global/game_calendar.gd`, `scripts/map/view3d/sky_astronomy.gd` | existing: the sun already follows the date |
| Crown phenology, falling leaves | `vegetation_phenology.gd`, `tree_leaf_fall_3d.gd` | existing |

`SeasonState.snapshot(date)` returns: `season`, `weights`, `temperature_c`, `snow_cover_target_m`, `snow_share`, `ice_puddle|fresh|sea`, `heating_demand`, `clothing_warmth`. Climate is a Tallinn-normals sinusoid (coldest day 30 at about -4 C, warmest day 212 at about +17 C).

## Task plan

| # | Task | Notes |
|---|---|---|
| 1 | Core `SeasonState` | done |
| 2 | Debug season/date control | done: `[` `]` step a day (Shift: 30 days), `F5`..`F8` jump to winter/spring/summer/autumn; clock speed already on the existing ladder |
| 3 | Snowfall weather | done: three looks (fine, flakes, heavy), one pooled GPU emitter, see **Snowfall** |
| 4 | Ground snow, roof snow, icicles, melt | shader `snow_depth` uniforms, thaw by temperature |
| 5 | Movement in snow and footprints | extends the mud trail |
| 6 | Ice on puddles, ponds, moat, rivers, shore | |
| 7 | Vegetation seasons: blossom, fruit, wither, grass, litter under trees | extends phenology |
| 8 | Sky, clouds, sea per season | |
| 9 | Citizen winter/summer wardrobe | `clothing_warmth` |
| 10 | Chimney smoke by `heating_demand`; wall weathering; save; docs | |

Every visual task must record High (25 fps) and Medium (30 fps) results from the F3 monitor.

## Snowfall

Status: implemented (precipitation only; ground and roof snow are the next tasks).

- When the weather state rains and the date's `snow_share` is 0.5 or more (about November to early April), `SkyWeather3D` shows the snow emitter instead of the rain streaks. `precipitation_snow_share()`, `snow_emitter_visible()`.
- Three looks picked from intensity and wind, no RNG (`Snowfall3D.kind_for`): **fine** (small, light, slow), **flakes** (big soft flakes sinking slowly), **heavy** (dense, fast, wind-driven blizzard). Wind drives it (below).
- **Wind:** `snowfall_particles.gdshader` is a small custom particle shader. Each flake's velocity relaxes toward "wind plus fall" every frame, so a gust shoves every flake in the air at once; wind strength also decides the look (`kind_for`). Rain was already wind-driven: `rain_slant()` leans the streaks with sustained wind and gusts (R-1501).
- Snow does not fill puddles (`_advance_ground_water` uses the liquid share only) and drums a tenth as loud on roofs.
- Cost: one `GPUParticles3D`, the rain tier's particle budget (700 Medium-class minimum, 2200 recommended), one billboard quad each. The rain emitter is hidden while it snows, so total particle cost does not add up. Flakes dim with the sun so unshaded flakes do not glow at night.
- Gotchas found while building it (keep): `billboard_keep_scale = true` is required or flake size is dropped; `ParticleProcessMaterial` turbulence made flakes vanish in the Mobile renderer, so the motion is a custom particle shader; `RANDOM_SEED` is the same for every flake in a particles shader, so positions are hashed from `INDEX` and spawn time; the follow camera looks down, so the flake column runs 8 m above to 8 m below the lens and sits 10 m ahead of it.
- Not yet measured in the city with the F3 monitor (task 10 gate: 25 fps High, 30 fps Medium).

## Winter ground, grass and trees

Status: implemented for the seamless city (the date drives all of it).

- **Trees:** crowns follow `VegetationPhenology` through `MapViewMaterials.apply_vegetation_season`. The city view overrode `set_calendar_date` without calling it, so city trees never changed; `CityMapView.set_calendar_date` now applies it (regression test in `test_season_state.gd`).
- **Grass:** `map_view_grass.gdshader` has `dormancy` (0 growing season, 1 deep winter, from `SeasonState` weights: all of winter plus a third of autumn). Dormant blades are a quarter of summer height, straw-brown with brown roots. `snow_cover` (existing R-1327 curve) presses blades down and whitens tips.
- **Ground:** `city_ground.gdshader` has `winter` (turf turns pale straw) and `snow_cover` (snow settles in patches, thinner on roads, paving, puddles and rock). Pushed by `CityWorld3D.apply_season(date)`.
- **Cold ground:** below freezing the sun no longer bakes soil or starts droughts, soil re-dampens and puddles evaporate at 15% speed (`SkyWeather3D.ground_warmth()`), so winter shows no cracked crust. Puddles freezing over is the ice task.
- **Snow is not rain:** the weather presentation's `rain_intensity` is scaled by the liquid share, so snowfall does not wet the ground, ring puddles or darken walls.
- Review plates: `tools/godot_render.sh --script tools/capture_city_forbs.gd -- --date=1343-12-10 --tag=dec` (writes `build/forbs/*_dec.png`).

## Autumn leaf fall

Status: implemented for the seamless city.

- `CityLeafFall` (`scripts/city/city_leaf_fall.gd` + `city_leaf_fall.gdshader`) is one pooled GPUParticles3D (900 slots). Every 0.3 s it reads the trees within 36 m of the player from `CityTreeLod.trees_near`, weighs them by view direction and shedding, and uploads the top 16 as crown centres, leaf colours and ground heights.
- A tree sheds in proportion to the leaves it still carries (`VegetationPhenology.state_for`: `leaf_density`, `fall_rate`) and the wind (`CityLeafFall.shed_weight`): a bare crown drops nothing, an October crown a steady trickle, a stiff wind or a gale much more (a gale even strips summer crowns). Leaf colours match the species' crown today.
- Leaves ride the shared wind (velocity chases wind plus fall each frame, so gusts shove them), tumble and flutter, and vanish when they reach the ground they were shed over: nothing lies around.
- Cost: one particle draw, two triangles per leaf, nothing when no leafed tree is near. Not yet measured with the F3 monitor.
- Gotchas: `CUSTOM` is not preserved between frames in a particle shader (recompute from `INDEX`); `return` is not allowed in `start()`; frames outrun the clock in a minimized capture window, so the plate tool preprocesses 10 s.
- Plate: `tools/godot_render.sh --script tools/capture_city_leaves.gd -- --date=1343-10-20 --wind=0.6`.
- Older `TreeLeafFall3D` (hit bursts, district maps) is unchanged; the city never used it for ambient leaves (its trees are not in the canopy groups).

## Water, reeds, lilies and ice

Status: implemented for the moat, the Hareapea stream and lakes (sea ice is planned).

- **Reeds and cattails** (`CityMoatPlants.apply_season`) yellow through autumn (`SeasonState.reed_dead_share`), lose stems as the water cools and are gone in a hard winter (`reed_standing`, via `MultiMesh.visible_instance_count` over a shuffled stand, so it thins evenly).
- **Lily pads and duckweed** fade with `water_plant_vigour` (water trails the air by about a week and a half); pads turn brown in autumn; **lily flowers** need warmer water than the pads.
- **Ice:** `city_moat_water.gdshader` has `ice` (thickness 0..1 from `SeasonState.ice_cover_target(ICE_FRESH)`) and `ice_snow`. The shallows freeze first, then the open water; running water (the stream) freezes later; waves die out; cracks and snow on the ice show. Pushed to every moat/stream/lake material by `CityWorld3D.apply_season`.
- Plates: `tools/godot_render.sh --script tools/capture_city_season.gd -- --date=1343-01-15` (also `1343-07-15`, `1343-10-20`).

## Snow footprints and the crunch

Status: implemented for the seamless city (Kalev, NPCs, hooves and wheels all use it).

- **Prints:** snow takes a print like wet clay does. `CitySnow.patch(xz, cover)` (GDScript) mirrors the patch rule of `city_ground.gdshader` (`snow_patch`), so the prints, the footsteps and the picture agree on where snow lies. `CityGroundTrail.snow_cover` (set by `CityWorld3D.apply_season`) makes snow count as "give" even on paved ground (only fully paved ground stays hard), deepens the stamp (`_weight(snow)`), and a boot in snow kicks up a small white powder puff. In the shader a print thins the snow and shades the packed floor blue-grey; the relief mesh lifts it into real geometry like mud prints.
- **Crunch:** new footstep surface `snow` (`SurfaceResolver.SURFACE_SNOW`, `with_snow`): turf, earth, mud and gravel under settled snow answer `sfx.footstep.snow.walk` (6 steps, `sounds/footsteps/snow_step_NN.mp3`). `CitySurfaceSampler.surface_at(..., snow_cover)` decides, `CityMapView.footstep_surface_at` passes the date's cover. Boards, flagstones and water stay as they were.
- **The clips are synthesised** (no CC0 snow recording is cleared): `python3 tools/audio/generate_snow_footsteps.py` builds a low "press" plus 90-260 crystal grains per step, mono 44.1 kHz, -17 dBFS loudest 50 ms, 128 kbps; rows in `assets/SOURCES.csv` (`--print-sources`). Replace by catalog ID with a real recording if one is cleared later.
- **Limits:** prints do not fill in under new snowfall or melt away on their own (the shader hides them as the snow thins, like mud prints it is a window image); no wind-blown drift; the crunch has not been judged by ear yet.
- Plate: `tools/godot_render.sh --script tools/capture_snow_prints.gd`.

## Debug controls

- **Debug overlay (mouse).** Open the quick menu and press **Debug**. The panel has a **Date and Season** block: the current date, season and mean temperature, buttons `-30d`, `-1d`, `+1d`, `+30d`, and `Winter`, `Spring`, `Summer`, `Autumn` that jump forward to 15 Jan, 21 Apr, 15 Jul and 15 Oct. Clock speed and pause are in the **Time Controls** block above it.
- **Keys (3D runtime).** `[` / `]` step a day back / forward (Shift: 30 days); `F5` winter, `F6` spring, `F7` summer, `F8` autumn.
- Elapsed campaign days never go negative, so a step back past the phase's start date wraps to the same calendar day next year (`GameCalendar.days_until`). The sun, HUD date, phenology, farmland and forbs follow through `set_calendar_date`.
- Entry points: `MapViewRuntime.shift_calendar_days`, `jump_to_season`, `calendar_date`; UI in `scripts/ui/debug_overlay.gd`; keys in `map_view_runtime_input.gd`. Test: `tests/godot/test_debug_overlay.gd`.

## Verify

`godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_season_state`

## Limits

Snowfall consumes the climate; everything else (ground and roof snow, ice, vegetation, sky, clothing, smoke, movement) is still planned.
