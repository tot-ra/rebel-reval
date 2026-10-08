# Discrete cloud cells, cloud shadows and storm-cell lightning

Status: implemented (task **R-1400**)

Scope: individual clouds as world-space objects in the 3D view. Each cumulus or cumulonimbus has a position, base altitude, size and life; the sky dome ray-marches it as a volume, the ground shadow pass projects it along the sun, god rays are cut by it, and lightning is born only inside a grown cumulonimbus. Mounted in both `MapView3D` maps and the seamless city (`CityMapView`).

Out of scope: rain particles and puddles that follow the storm cell under the player (rain is still a weather-wide `rain_intensity`), thunder audio tied to strike distance, clouds that react to terrain, and replacing the dome's continuous cloud deck (it stays as the distant layer and the overcast sheet).

## What the player sees

- **Fair and cloudy days**: a handful (clear) to a dozen (cloudy) separate cumulus drift with the wind, grow from small puffs, mature, and dissolve over about 40-60 s of game time. They have flat grey bases, sunlit cauliflower crowns and a silver lining when they cross the sun. They move with real parallax as the camera moves.
- **Cloud shadows**: every cell throws its own soft-edged shadow on the ground, roofs and sea, offset along the sun, so you can watch one cloud's shadow sweep across a street or the harbour. The shadow removes most of the direct-sun share (up to 85%), and fades out at night and under full overcast.
- **Thunderstorms**: `storm` weather grows up to three cumulonimbus towers (1.7-2.3 km tall, with a spreading anvil) that are visible from several kilometres away, with a grey rain curtain hanging under the base. `rain` weather embeds the same cells in its deck.
- **Lightning** comes only from a mature storm cell. About 40% of strikes are cloud-to-ground: a jagged channel with two thinner, dimmer branches from the cell base to the ground. The channel is a hairline (about one pixel, physical half-width 0.35 m that only shows on a very close strike) with a faint halo; the bright corona comes from scene glow, not a painted fat stroke. The rest are in-cloud flashes that light the tower from inside. With no grown storm cell, there is no lightning, even when the weather profile has thunder. Scene light lift falls off with camera distance to the cell (to 40% beyond 2.6 km); the strike in the sky is always drawn at full strength.
- **Sunbeams**: when the camera faces a low sun, air shaded by a cell darkens the forward glow and sunlit gaps brighten it (sky dome), and the street-level god-ray pass only scatters light where the cloud shadow is open, so beams start at real cloud edges.

## Runtime entry points

| Piece | File |
|---|---|
| Cell field (pure, deterministic) | `scripts/map/view3d/cloud_cells.gd` (`CloudCells`) |
| Shared shader maths (density, ground shadow, bolt) | `scripts/map/view3d/cloud_cells.gdshaderinc` |
| Simulation, strike placement, uniforms | `scripts/map/view3d/sky_weather_3d.gd` (`_update_cells`, `_advance_lightning`, `_place_strike`) |
| Volume march, sky beams, bolt | `scripts/map/view3d/sky_weather_3d.gdshader` (`cells_volume`, `cells_sky_rays`, `lightning_bolt`) |
| Ground shadows | `scripts/map/view3d/cloud_shadow_pass.gd` / `.gdshader` |
| God rays cut by cells | `scripts/map/view3d/god_ray_pass.gd` / `.gdshader` |
| 3D Worley noise for cell shapes | `SkyWeatherResources.build_cell_noise_3d` |
| City mounting | `CityMapView._create_sky_passes`, `CityMapView._process` |

`CloudCells.update(clock, cloud_offset, counts)` rebuilds 16 slots (13 cumulus, 3 cumulonimbus) every `SkyWeather3D.advance()`. Counts come from the blended weather profile (`CloudCells.counts_for(coverage, storm)`), so a weather transition fades cells in and out. Cells drift with the shared `cloud_offset` (`METRES_PER_UV` = 5000 world units per offset unit). They tile a periodic square (3.2 km for cumulus, 9.6 km for storm cells). Shaders take the copy nearest the camera and fade cells out before the seam.

`WeatherPresentation.cloud_cells` carries the packed uniforms to the passes; `cell_sun_edge` (how ragged the cover is right around the sun) adds haze to god rays. `celestial_cloud_clear` (water glints, god-ray strength) also multiplies in the cells in front of the sun or moon.

## Saved state

`SkyWeatherState` gains four optional fields (older saves default them): `cloud_cell_clock` (rebuilds the whole cell field together with `cloud_offset` and the profile), `lightning_origin`, `lightning_ground`, `lightning_kind`. See [`SKY_WEATHER_STATE_CONTRACT.md`](../SKY_WEATHER_STATE_CONTRACT.md).

## Quality tiers

Tiers change cost only; cell positions and strike timing are identical.

| Key | Minimum | Recommended |
|---|---|---|
| `cloud_cell_steps` (coarse surface search) | 6 | 12 |
| `cloud_cell_fine_steps` (surface march) | 5 | 10 |
| `cloud_cell_light_samples` | 1 | 2 |
| `cloud_cell_ray_samples` (sky beams) | 0 | 8 |
| `cloud_cell_noise_size` (3D noise edge) | 32 | 48 |

The radiance cubemap pass skips the cells. A 1280x720 street view in the seamless city showed no measurable frame-time difference with cells on or off (26.1-26.5 ms either way, M-series Mac, Compatibility).

## Screen-pass fixes made with this task

The ground shadow pass had two defects that kept it from ever drawing a localised shadow:

- **Compositing**: `blend_mul` multiplied the frame by `ALBEDO`, but the Compatibility 3D buffer stores colour pre-scaled by its HDR luminance multiplier, so `ALBEDO = 1` multiplied every frame by about 0.25 and the old `COMPAT_BLEND_GAIN` still left frames ~40% darker. The pass now mixes black by `ALPHA` (`blend_mix`), which is exact under any multiplier or tonemapper.
- **Draw order**: the pass drew at transparent priority 96, after the water. Water samples the screen texture, and in Compatibility that back-buffer copy leaves `hint_depth_texture` empty (all 0) for every transparent pass drawn after it, so the pass rebuilt no positions on any map with a sea. It now draws first (`RENDER_PRIORITY = -100`). The water surface itself stays unshadowed. Pixels with no depth behind them (sea without a bed mesh) are shaded on the sea plane, faded out between 1.5 and 3 km.

## Verify

```bash
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_cloud_cells
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_cloud_shadow_pass
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_sky_weather
tools/godot_render.sh --script tools/capture_cloud_cells.gd [-- --only=<shot>[,<shot>...]]
```

Captures land in `docs/reports/images/weather/`: `cells_aerial_clear`, `cells_aerial_cloudy`, `cells_topdown_shadow`, `cells_street_cumulus`, `cells_storm_ground_stroke`, `cells_storm_in_cloud`, `cells_sunbeams`. Screen passes composite over the live framebuffer, so captures must render in the root window, not a `SubViewport`.

![Clear day: separate cumulus and their shadows on the town fields](../reports/images/weather/cells_aerial_clear.png)

![A cumulonimbus with a cloud-to-ground stroke from its base](../reports/images/weather/cells_storm_ground_stroke.png)

## Limits

- Rain particles, puddles and roof-rain audio still follow the weather-wide `rain_intensity`, not whether the player stands under a storm cell.
- The water surface is not darkened by cloud shadows (the pass draws before water); only the bed seen through it is. Glints and specular on the sea under a cloud need the water shader to sample `cells_ground_shadow` itself.
- The city god-ray raster leaves terrain out (sampling the relief over the whole city stalls the first frame), and the air slab stops at 32 m, so Upper Town streets on the klint get no street-level beams.
- Cell edges show a fine dither from the deterministic march jitter at close range.
- Thunder audio is not yet timed to strike distance.
