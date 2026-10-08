# Night sky: stars and the Milky Way over Reval

Status: implemented (task **R-1443**)

Scope: the naked-eye star field and the Milky Way on the 3D sky dome (`SkyWeather3D`), as seen from Reval (59.437 N) in 1343. Used by every `MapView3D` map and the seamless city.

Out of scope: stars fainter than magnitude 5 (the catalog stops there), planets, aurora, meteors, and changes to the water's star reflection (it still samples the star map texel directly).

## What the player sees

- **Round stars.** Every catalog star is a small round point about one screen pixel wide at any resolution or zoom. Brighter stars are a little larger and brighter (magnitude via Pogson's law), and each keeps its real colour from its B-V index: blue-white Vega and Rigel, orange Arcturus, red Betelgeuse. Earlier builds drew stars as nearest-filtered texels, which showed as small squares, with a '+' cross around bright stars.
- **Twinkling.** Stars flicker smoothly at a few hertz, each with its own rhythm. Near the zenith the flicker is faint; toward the horizon, where the light crosses more air, it grows strong, and bright low stars also flash red and blue (chromatic scintillation).
- **Milky Way.** A soft, lumpy band of light with brighter star clouds, a split dark lane (the Great Rift) from Cygnus toward Aquila, a bright region in Cygnus and a faint, narrow anticentre in Auriga. Its position comes from the real galactic frame, precessed to 1343, so it matches the view from Tallinn: on spring nights (the slice's April dates) it lies low along the northern horizon through Cassiopeia and Perseus; on late-summer and autumn nights it arches overhead through Cygnus. The bright galactic centre in Sagittarius never rises clear of the southern horizon at this latitude.
- **When it shows.** The Milky Way needs real darkness: it fades in only once the sun is about 7-16 degrees below the horizon, so it is faint in May and absent in Reval's white nights of June and July. A risen bright moon washes it out (up to 85% at full moon), clouds hide it with the stars, and it disappears into haze in the lowest degrees of sky.
- **Seasons.** The star field drifts about 0.986 degrees per calendar day, so the same clock time shows different constellations through the year: Orion in winter evenings, the Summer Triangle overhead in August.

## Runtime entry points

| Piece | File | Role |
|-------|------|------|
| Star and Milky Way shading | `scripts/map/view3d/sky_stars.gdshaderinc` | `star_field()` draws a Gaussian point-spread disk for each star-map texel near the ray (wider search near the celestial pole), with scintillation from `star_twinkle_time`; `milky_way()` and `milky_way_visibility()` shade the band in galactic coordinates |
| Sky dome | `scripts/map/view3d/sky_weather_3d.gdshader` | includes the file above; adds stars and Milky Way outside the radiance-cubemap pass, under the clouds |
| Star map bake | `SkyWeatherResources.bake_stars()` | one texel per Hipparcos star (mag <= 5, precessed to 1343), colour times luminance |
| Galactic frame | `SkyWeatherResources.galactic_frame()` | J2000 galactic pole and centre precessed to 1343, pushed as `galactic_pole` / `galactic_center` |
| Sidereal time | `SkyAstronomy.sidereal_angle_for_progress(progress, date)` | midnight sidereal angle of 23 April 1343 plus the daily sidereal excess; the dome and the water's star reflection use the same angle |
| Twinkle clock | `SkyWeather3D._process()` | real-time seconds (wrapped at one hour) pushed as `star_twinkle_time` |

Tuning uniforms: `star_gain` (star brightness), `milky_way_strength` (band brightness).

## Data and state

Reads the committed Hipparcos catalog (`EstoniaStarCatalog`, BSD-3 attribution in `scripts/map/view3d/third_party/`) and the campaign calendar date. The twinkle clock is presentation only: it runs even when the weather clock is paused, and it is never saved. Nothing in this feature touches save data; star positions follow from the saved date and clock.

## Verify

- `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_sky_weather_3d` (`test_bright_stars_bake_to_a_single_texel`, `test_milky_way_frame_is_precessed_and_orthogonal`, `test_shader_draws_round_twinkling_stars_and_milky_way`)
- `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_sky_sidereal_drift`
- `tools/godot_render.sh --script tools/capture_night_sky.gd` writes [night_sky.png](../reports/images/night_sky/night_sky.png) (April north horizon, August south-east, zoom on Cygnus) and [night_sky_twinkle.png](../reports/images/night_sky/night_sky_twinkle.png) (one field 0.35 s apart). Flags after `--` (`--no-stars`, `--no-star-points`, `--no-milky-way`, `--milky-way=<strength>`) write suffixed A/B sheets.

## Limits

- The Milky Way is a procedural model (Gaussian band with bulge, Cygnus and Cassiopeia brightening, Great Rift lane, mottling from the cloud noise textures), placed by the real galactic frame. Individual dark nebulae and star clouds are not mapped from survey data.
- The catalog stops at magnitude 5, about 1600 stars; a truly dark 1343 sky shows roughly three times as many to the naked eye.
- The radiance cubemap omits stars and the Milky Way, so they do not add to night ambient light.
- Stars are not dimmed by moonlight; only the Milky Way is.
- The art-graded night sky (`night_top_color`, exposure) stays fairly bright blue for readability, which keeps the Milky Way subtle.
- Before R-1443 the star map was filled with `Color.TRANSPARENT` (white with zero alpha), so every empty texel added a uniform white haze to the night dome and the water's star reflection. Nights are now darker and clearer than older captures show.
