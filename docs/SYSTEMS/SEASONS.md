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

## Debug controls

- **Debug overlay (mouse).** Open the quick menu and press **Debug**. The panel has a **Date and Season** block: the current date, season and mean temperature, buttons `-30d`, `-1d`, `+1d`, `+30d`, and `Winter`, `Spring`, `Summer`, `Autumn` that jump forward to 15 Jan, 21 Apr, 15 Jul and 15 Oct. Clock speed and pause are in the **Time Controls** block above it.
- **Keys (3D runtime).** `[` / `]` step a day back / forward (Shift: 30 days); `F5` winter, `F6` spring, `F7` summer, `F8` autumn.
- Elapsed campaign days never go negative, so a step back past the phase's start date wraps to the same calendar day next year (`GameCalendar.days_until`). The sun, HUD date, phenology, farmland and forbs follow through `set_calendar_date`.
- Entry points: `MapViewRuntime.shift_calendar_days`, `jump_to_season`, `calendar_date`; UI in `scripts/ui/debug_overlay.gd`; keys in `map_view_runtime_input.gd`. Test: `tests/godot/test_debug_overlay.gd`.

## Verify

`godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_season_state`

## Limits

Snowfall consumes the climate; everything else (ground and roof snow, ice, vegetation, sky, clothing, smoke, movement) is still planned.
