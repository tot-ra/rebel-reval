# Night sky: stars and the Milky Way over Reval

Status: implemented (tasks **R-1443**, **R-2037**)

Scope: the naked-eye star field and the Milky Way on the 3D sky dome (`SkyWeather3D`), as seen from Reval (59.437 N) in 1343. Used by every `MapView3D` map and the seamless city.

Out of scope: stars fainter than magnitude 5 (the catalog stops there), planets, aurora, meteors, and changes to the water's star reflection (it still samples the star map texel directly).

## What the player sees

- **Round stars.** Every catalog star is a small round point about one screen pixel wide at any resolution or zoom. Brighter stars are a little larger and brighter (magnitude via Pogson's law), and each keeps its real colour from its B-V index: blue-white Vega and Rigel, orange Arcturus, red Betelgeuse. Earlier builds drew stars as nearest-filtered texels, which showed as small squares, with a '+' cross around bright stars.
- **Twinkling.** Stars flicker smoothly at a few hertz, each with its own rhythm. Near the zenith the flicker is faint; toward the horizon, where the light crosses more air, it grows strong, and bright low stars also flash red and blue (chromatic scintillation).
- **Milky Way.** A soft, lumpy band of light with brighter star clouds, a split dark lane (the Great Rift) from Cygnus toward Aquila, a bright region in Cygnus and a faint, narrow anticentre in Auriga. Its intensity is tuned to 55% of the previous baseline so it reads as unresolved starlight rather than a bright nebula over Estonia. Its position comes from the real galactic frame, precessed to 1343, so it matches the view from Tallinn: on spring nights (the slice's April dates) it lies low along the northern horizon through Cassiopeia and Perseus; on late-summer and autumn nights it arches overhead through Cygnus. The bright galactic centre in Sagittarius never rises clear of the southern horizon at this latitude.
- **When it shows.** The Milky Way needs real darkness: it fades in only once the sun is about 7-16 degrees below the horizon, so it is faint in May and absent in Reval's white nights of June and July. A risen bright moon washes it out (up to 85% at full moon), clouds hide it with the stars, and it disappears into haze in the lowest degrees of sky.
- **Seasons.** The star field drifts about 0.986 degrees per calendar day, so the same clock time shows different constellations through the year: Orion in winter evenings, the Summer Triangle overhead in August. The visible night floor also follows the existing solar declination: darkest in winter, brighter through summer, and especially blue around the Estonian white nights. The presentation gain ranges from 0.72 in winter to 1.18 in summer; it does not change the radiance cubemap, water reflections, ambient or gameplay lighting.
- **Twilight blue.** Between the horizon and -18 degrees the dome keeps a deep-blue glow (`TWILIGHT_TOP`, `TWILIGHT_HORIZON` in `sky_weather_3d.gdshader`), graded by season so Reval's long summer twilight stays lighter than winter's dark nights; details in [Regional sites](./REGIONAL_SITES.md).

## Runtime entry points

| Piece | File | Role |
|-------|------|------|
| Star and Milky Way shading | `scripts/map/view3d/sky_stars.gdshaderinc` | `star_field()` draws a Gaussian point-spread disk for each star-map texel near the ray (wider search near the celestial pole), with scintillation from `star_twinkle_time`; `milky_way()` and `milky_way_visibility()` shade the band in galactic coordinates |
| Sky dome | `scripts/map/view3d/sky_weather_3d.gdshader` | includes the file above; adds stars and Milky Way outside the radiance-cubemap pass, under the clouds; seasonally grades only the visible night floor |
| Star map bake | `SkyWeatherResources.bake_stars()` | one texel per Hipparcos star (mag <= 5, precessed to 1343), colour times luminance |
| Galactic frame | `SkyWeatherResources.galactic_frame()` | J2000 galactic pole and centre precessed to 1343, pushed as `galactic_pole` / `galactic_center` |
| Sidereal time | `SkyAstronomy.sidereal_angle_for_progress(progress, date)` | midnight sidereal angle of 23 April 1343 plus the daily sidereal excess; the dome and the water's star reflection use the same angle |
| Twinkle clock | `SkyWeather3D._process()` | real-time seconds (wrapped at one hour) pushed as `star_twinkle_time` |
| Seasonal night floor | `SkyAstronomy.seasonal_night_brightness(date)` → `SkyWeather3D.apply_sky_state()` | normalizes the campaign solar declination to a 0..1 winter-to-summer presentation gain |

Tuning uniforms: `star_gain` (star brightness), `milky_way_strength` (band brightness, default 0.55), and `seasonal_night_brightness` (seasonal visible-dome gain, 0 winter to 1 summer).

## Data and state

Reads the committed Hipparcos catalog (`EstoniaStarCatalog`, BSD-3 attribution in `scripts/map/view3d/third_party/`) and the campaign calendar date. The twinkle clock is presentation only: it runs even when the weather clock is paused, and it is never saved. Nothing in this feature touches save data; star positions follow from the saved date and clock.

## Verify

- `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_sky_night_seasonality` covers winter/equinox/summer night brightness; `--filter=test_sky_astronomy` covers the shared solar model.
- `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_sky_weather_3d` covers the visible-dome season gate, the restrained Milky Way gain, and existing sky behavior.
- `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_sky_sidereal_drift`
- `tools/godot_render.sh --script tools/capture_night_sky.gd` writes [night_sky.png](../reports/images/night_sky/night_sky.png) with April and August Milky Way views plus matching December winter / June white-night views, and [night_sky_twinkle.png](../reports/images/night_sky/night_sky_twinkle.png) (one field 0.35 s apart). Flags after `--` (`--no-stars`, `--no-star-points`, `--no-milky-way`, `--milky-way=<strength>`) write suffixed A/B sheets.

## Limits

- The Milky Way is a procedural model (Gaussian band with bulge, Cygnus and Cassiopeia brightening, Great Rift lane, mottling from the cloud noise textures), placed by the real galactic frame. Individual dark nebulae and star clouds are not mapped from survey data.
- The catalog stops at magnitude 5, about 1600 stars; a truly dark 1343 sky shows roughly three times as many to the naked eye.
- The radiance cubemap omits stars and the Milky Way, so they do not add to night ambient light.
- Stars are not dimmed by moonlight; only the Milky Way is.
- Seasonal brightness is an art-directed 0.72..1.18 multiplier over normalized solar declination, not a measured historical sky-radiance model. It grades the camera-visible floor only; the radiance cubemap, water reflections, ambient and gameplay lighting remain unchanged.
- Before R-1443 the star map was filled with `Color.TRANSPARENT` (white with zero alpha), so every empty texel added a uniform white haze to the night dome and the water's star reflection. Nights are now darker and clearer than older captures show.
