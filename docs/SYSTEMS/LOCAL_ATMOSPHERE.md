# Local fog banks, horizon haze and heat mirage

Status: implemented (task **R-1430**)

Scope: three presentation-only layers on top of the sky/weather system, mounted in both `MapView3D` maps and the seamless city (`CityMapView`). They read the shared `WeatherPresentation` snapshot and the `CloudCells` simulated clock and never write gameplay state or saves.

1. **Local fog banks**: patches of ground fog that gather near water, only in damp, calm air, lit by their own light.
2. **Horizon haze**: a faint distance veil for far land and sea, perspective cameras only.
3. **Heat mirage**: wavering pale streaks above the far horizon on hot, calm, clear summer middays.

Out of scope: volumetric fog (the GL Compatibility renderer has none), fog that blocks line of sight or AI vision, fog lit by street lamps and torches, a screen-space refraction shimmer (screen reads are unreliable in this pipeline), a persisted fog state.

## What the player sees

- **Fog banks** appear on the shore, on a pier or on the meadow beside the sea, the moat or the stream. They are *not* everywhere: a bank needs damp air, water within 44 world units, and a drifting noise patch, so most of the shore stays clear. Banks fade in over about 4 s, drift with the wind, and fade out when the air dries.
- **Weather drives density**: dawn radiation mist (the date-based `morning_fog_potential`), an overcast deck, falling rain and standing puddles (wet ground keeps giving moisture back after the rain stops) all raise it. Wind disperses it, and a high clear sun burns the damp share off by about half. Storm weather with strong wind clears it.
- **Own lighting**: each puff is shaded on the side facing the sun (or the moon at night), brightens at its thin edges when the camera looks toward the light (forward scatter), takes its ambient hue from the horizon the dome draws, and flashes with lightning. Fog never glows at night.
- **Horizon haze**: in third and first person the distant city, hinterland and sea blend toward the horizon colour. It thickens in damp air and in summer heat. The orthographic gameplay lens gets none (it would read as a flat wash).
- **Heat mirage**: when the sun is high (sine of elevation above 0.7, so mid-May to late July around noon), the sky is mostly clear and the air is calm and dry, pale streaks shimmer just above the horizon line. The campaign's April opening never shows it.

Plates: [overview contacts before/after](../reports/images/weather/fog_contacts_before_after.png), [overcast overview](../reports/images/weather/local_fog_overview.png), [overcast shore](../reports/images/weather/local_fog_overcast_shore.png), [after rain, low sun](../reports/images/weather/local_fog_after_rain_lowsun.png), [midsummer mirage](../reports/images/weather/horizon_mirage_midsummer.png).

## Runtime entry points

| Piece | File |
|---|---|
| Owner node, one per exterior view | `scripts/map/view3d/local_atmosphere.gd` (`LocalAtmosphere`) |
| Fog bank pool, scoring, light parameters | `scripts/map/view3d/local_fog_banks.gd` (`LocalFogBanks`) |
| Puff shader (camera-facing ellipse, own lighting, soft surface contacts) | `scripts/map/view3d/local_fog_puff.gdshader` |
| Heat mirage ring and shader | `scripts/map/view3d/horizon_mirage.gd` (`HorizonMirage`), `horizon_mirage.gdshader` |
| Damp air, heat and horizon haze maths; distance fog | `scripts/map/view3d/map_view_lighting.gd` (`air_dampness`, `heat_amount`, `horizon_haze_amount`, `apply_ground_mist(..., horizon_haze)`) |
| Perspective check | `SkyWeather3D.view_is_perspective()` |
| Mounting | `MapView3D._create_local_atmosphere` (view-effects stage and `_process`), `CityMapView._create_city_atmosphere` and `_process` |

How a bank is chosen (`LocalFogBanks`): the world is cut into 16-unit cells around a focus point (20 units ahead of a perspective camera, the view-ray ground hit for the orthographic one). Each cell scores `density(weather) * water_affinity * patch_mask`. Water affinity is measured once per cell from 25 water probes (centre plus three rings of eight) through the view's `water_surface_height_at` and then cached; at most 3 cells are measured per frame. The best cells, biased toward the player, claim one of 14 pooled `GPUParticles3D` emitters (12 soft puffs each); the `fog_quality` tier scales the pool (9 on minimum). Only the current camera halo is cached, stale queued probes are evicted, and invisible emitters stop simulating. Each viewport owns its own layer; hosted neighbors within one viewport share the first layer. Patches drift on `SkyWeather3D.cloud_cell_clock()`, so a load or map swap shows the same pattern at the same simulated time.

## Data and stable IDs

No content IDs, no JSON, no saves. All tunables are constants at the top of `local_fog_banks.gd`, `horizon_mirage.gd` and `map_view_lighting.gd` (`HORIZON_HAZE_*`, `HEAT_SUN_*`). The shared `fog_quality` field of `QUALITY_TIERS` limits fog and mirage strength.

## Verify

- `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_local_fog_banks` (density, water affinity, patch locality, light parameters, heat, haze fog, bank claim and fade, no-water case, bounded travel cache, roof suppression, active-camera projection switching, independent viewports).
- Regression: `--filter=test_weather_realism`, `--filter=test_map_view_lighting`.
- Plates: `tools/godot_render.sh --script tools/capture_local_fog.gd` writes `build/local_fog/*.png`, including `fog_overcast_overview` (30 degrees) and `fog_overcast_steep` (75 degrees).
- Isolated surface-contact proof: `tools/godot_render.sh --script tools/capture_fog_contacts.gd`. If `build/scratch/local_fog_puff_before.gdshader` exists it renders old/fixed side by side, otherwise both columns use the current shader. Red tint highlights the contact; a sloped ground plane and screen-reading water strip exercise the render order.

## Limits

- Puffs face the full camera basis, so overview and steep top-down views do not collapse them into lines. Elliptical silhouettes, world-height fade and a 2.5-unit opaque-depth contact fade remove straight card cuts at terrain and walls. Fog draws at priority -90 (after cloud shadows at -100, before screen-reading water at 0); Compatibility otherwise loses the depth buffer after the water back-buffer copy. Transparent water does not contribute contact depth.
- Fog height follows the ground at each cell centre; on steep slopes a puff can float or sink a little.
- Banks only gather around water the view can probe. A map with no water gets no banks (the mirage still mounts outdoors).
- The mirage does not warp the scene behind it; it is an additive-looking veil. Heat is inferred from solar elevation and weather, not from a temperature simulation.
- Sun/moon/lightning lighting is approximate; practical lights do not illuminate puffs.
- Hosted district neighbors share the first exterior layer, which probes only that map; water available exclusively in another mounted map may need a new owner before banks appear.
- Independent human or agent visual sign-off is still pending; the attempted reviewer returned no result.
