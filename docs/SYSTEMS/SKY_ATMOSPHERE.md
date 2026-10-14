# Sky and atmosphere: clouds, sunbeams, fog and haze

Status: implemented (tasks **R-1400**, **R-1430**, **R-1436**, **R-1444**, **R-1481**, **R-1482**, **R-1493**, **R-1495**, **R-1501**, **R-1507**, **R-1517**, **R-1531**, **R-1532**, **R-1533**, **R-1165**, **R-1766**, **R-1794**, **R-1768**, **R-1873**, **R-1770**)

Scope: everything between the ground and the sky dome in the 3D views (district maps and the seamless city): individual clouds and their shadows, thunderstorms with local rain and lightning, sunbeams, a sun-shower rainbow, ground fog near water, distance haze and blur, and the summer heat mirage. Every layer is presentation only. It reads the shared weather, time of day, season and wind, never changes gameplay, and rebuilds identically from a save.

Out of scope: volumetric fog (the GL Compatibility renderer has none), fog that blocks line of sight or AI vision, clouds that react to terrain, thunder timed to strike distance, hail as a ground or gameplay effect, superior mirages over the cold sea, seasonal weather odds. Stars and the Milky Way are on [`NIGHT_SKY.md`](./NIGHT_SKY.md); puddles, mud and drought on [`WEATHER_GROUND.md`](./WEATHER_GROUND.md); the weather cycle itself and its saved state on [`WORLD_PRESENTATION.md`](./WORLD_PRESENTATION.md) and [`SKY_WEATHER_STATE_CONTRACT.md`](../SKY_WEATHER_STATE_CONTRACT.md).

## One system, several layers

All layers answer the same few questions: what is the weather, where is the sun, how strong is the wind and how damp is the air. That is why a scene stays coherent: an overcast deck dims the cumulus under it, puts out the sunbeams and feeds the ground fog; a hot, still June noon clears the fog, thickens the haze and starts the mirage.

| Layer | What the player sees | Driven by |
|---|---|---|
| Sky dome deck | the continuous far cloud layer and the grey overcast sheet | weather cover |
| Cloud cells | separate cumulus and thunderstorm towers that move with real parallax | weather cover, wind, the cloud clock |
| Cloud shadows | each cloud's own shadow sweeping over streets, fields and the sea | cells and deck, sun direction |
| Storm rain and lightning | a rain curtain under a storm, rain only where you stand under it, lightning only from a grown storm | storm cells, wind |
| Sunbeams | shafts and dark columns fanning from cloud gaps | deck, cells, sun height |
| Fog banks and evening mist | patches of ground fog on shores and meadows by water | damp air, wind, time of day, water nearby |
| Haze and aerial perspective | far land and sea take the colour of the air and soften | damp air, heat, time of day, weather |
| Heat mirage | wavering pale streaks and ground just above the far horizon | high sun, calm dry fair weather |

The order in a day: a damp dawn starts with mist on the water, the sun burns it off by mid-morning, cumulus bubble up, crowd together in the afternoon and may merge into a thunderstorm, the low evening sun throws rays through the broken cloud, and on a still dusk the mist returns.

## Weather and the look of the sky

There are six weather modes, from `cloudless` to `storm`. The cycle is tuned to Tallinn in late April and May, when the campaign starts: over a long run the sky is about 18% cloudless, 31% fair with cumulus (`clear`), 27% cloudy, 12% overcast, 10% rain and 1% storm. A cloudless spell always turns fair first (clouds bubble up before a sky clouds over), fair spells never jump straight to rain, and a passing front can clear straight to a cloudless sky.

![Cloudless weather: plain blue sky over the town](../reports/images/weather/cells_sky_cloudless.png)

![The same view in fair weather: scattered cumulus](../reports/images/weather/cells_sky_clear.png)

## Sky colour grade (R-1770)

AgX desaturates bright values, so a fair-day zenith went pale and sunlit cloud crowns greyed out. `sky_weather_3d.gdshader` now applies a sky-only grade to the visible dome at the end of `sky()`: a cobalt multiplier (`sky_zenith_deepen`, weighted by `sky_zenith_deepen_strength` and fading out below about 0.15 of dome height so the haze stays pale) and a luma-preserving saturation boost (`sky_grade_saturation`, 1.35). Both scale with `day_blend` and switch off under `cloud_darken`, so night, twilight and overcast keep their authored colour. The radiance cubemap pass is skipped, so reflections, ambient light and the global grade (`GRADE_DAY_SATURATION`) are untouched.

![Fair noon sky: cobalt zenith fading to pale haze](../reports/images/weather/sky_grade_noon_clear.png)

Verify: `tools/godot_render.sh --script tools/capture_sky_reference.gd`; street luma with `tools/capture_brightness_tour.gd` (10 shots, summed mean luma 382 before and after, 0.0% change); `test_sky_grade_is_a_sky_only_saturation_term` in `tests/godot/test_map_view_lighting.gd`.

## Fair-weather clouds

A fair day carries about eight separate cumulus, a cloudy one up to twenty. Each one is a real object in the world: it has a position, a base height and a size, rides the wind at its own speed and slightly off the wind's heading, so neighbours overtake, meet and part. Each cloud lives about a minute or a minute and a half of game time: it grows from a small puff, spreads, shrinks while still solid, then breaks up into heaps and fades.

A cumulus is a fused cluster of two or three uneven heaps drawn out along the wind, about twice as long as wide on average, not a round ball. It has a flat grey base, a sunlit cauliflower crown and a soft, gaseous rim that frays into tufts, and a silver lining when it crosses the sun. Cumulus belong to a blue sky: they thin out as an overcast deck closes in and turn rain grey under it.

![A fair cumulus from open ground: lobed and drawn out, not a round ball](../reports/images/weather/cells_field_cumulus.png)

![One cumulus through its life: grown, spread, shrunk while still solid, last remnant](../reports/images/weather/cells_cumulus_life.png)

The rim softness was chosen from four presets (top left: hard cut-out edges before; bottom left: the chosen misty default).

![Fair cumulus under the four rim presets](../reports/images/weather/cells_softness_cumulus.png)

## Cloud shadows

Every cloud throws its own soft-edged shadow on the ground, roofs and sea, offset along the sun, with the cloud's own outline. You can watch one shadow sweep down a street or cross from the shore onto the harbour, where it also puts out the sun glints on the water. A shadow takes away most of the direct sun (up to 85%), and fades out at night and under a full overcast sheet. The continuous dome deck throws its own patchy shadows as well.

![Clear day: separate cumulus and their shadows on the town fields](../reports/images/weather/cells_aerial_clear.png)

![One cloud shadow continuing from the shore fields across the harbour water](../reports/images/weather/cells_harbour_shadow.png)

## Thunderstorms

A thunderstorm is rare and wide. There are two ways to get one:

- **A fair day builds one.** When three or more cumulus drift together inside a convective hotspot (one roughly every 10 km, drifting slowly), the most crowded cloud grows into a storm 2-3 km across and 1-2 km tall. Its base drops and darkens, its heaps fuse into tiers, some grow an anvil, and a rain curtain hangs under it. When the cluster drifts apart, dissolves or leaves the hotspot, the storm sinks back into cumulus. On a fair day a storm is almost never in view; on a cloudy day one is within 5 km about 5% of the time, and never two at once.
- **Storm weather brings its own.** In `storm` weather up to three cumulonimbus towers stand over the land; `rain` weather embeds the same cells in its grey deck.

A grown storm stays visible from about 5 km and fades out by 6 km. It is built from 3-5 stacked tiers with darker gaps between them and a wider shelf at the base, so it reads as depth, not one flat silhouette. Under a closed grey sheet a storm takes the tone of the cloud behind it instead of glowing sunlit white.

![A merged storm from 2 km: wide, flat dark base, rain curtain below](../reports/images/weather/cells_tower_merge.png)

![North, east, south and west from 3 km while a cluster storms: one storm in view, no repeated copies](../reports/images/weather/cells_tower_horizon.png)

![Before (top) and after (bottom) the soft-edge pass: a merged storm from 2.5 km and a storm under the rain sheet](../reports/images/weather/cells_storm_soft_before_after.png)

![Clouds under a clear, cloudy, rain and storm sky](../reports/images/weather/cells_sky_context.png)

### Rain under the storm

Storm rain is local. The falling rain and the drumming on roofs run only while you stand inside the storm's rain shaft; three kilometres away the street is dry and quiet while the curtain still hangs on the horizon. A storm that grew from fair cumulus rains lightly under its own leaning shaft. In `rain` weather the deck rains everywhere.

![Under a storm cell: rain curtain and falling rain](../reports/images/weather/cells_storm_rain_under.png)

![The same view with the storm 3 km away: dry](../reports/images/weather/cells_storm_rain_away.png)

Rain leans with the wind: a cloudy-day breeze slants it about 45 degrees, a gale up to about 55 degrees, and rain curtains under storms lean at half that.

![Rain-front gale from rooftop height across the wind: the streaks lean downwind (streaks thickened for the plate)](../reports/images/weather/cells_rain_slant.png)

### Lightning

Lightning comes only from a grown storm. If there is no storm in the sky, there is no lightning, even when the weather itself is thundery; a storm that grew on a fair day can strike under a blue sky. About 40% of strikes are cloud-to-ground: a hairline jagged channel with two thinner branches from the storm base to the ground, its corona coming from the scene glow. The rest are flashes inside the cloud that light the tower from within. A strike near the camera lights the scene more than a distant one. At night the rain curtains are dark grey smudges that only light up in a flash.

### Sun-shower rainbow

When a low sun slips under a storm's base and lights its falling rain from the side, a rainbow appears on the rain curtain itself, usually one leg or a short arc over the curtain's foot. It is never brighter than the curtain is dense. The ordinary after-rain rainbow is separate and unchanged.

![Sun-shower bow off (left) and on (right) on a storm curtain](../reports/images/weather/cells_shower_bow.png)

## Sunbeams

When the sun stands behind broken cloud, shafts of light fan out from the gaps and dark columns trail from the cloud edges, all converging on the sun. Both the dome deck and the separate clouds cut them, by day and with the sun on the horizon at dawn and dusk, when the rays sweep wide and take the warm glow's colour. Over town and sea the air in a cloud's shadow is darker than sunlit air, and in the streets shafts also start at roof edges. A clear sky has no beams, and a closed grey sheet (overcast, rain) puts them out.

| Without beams | With beams |
|---|---|
| ![Sun behind a cloud edge over the town, before](../reports/images/weather/godrays_aerial_lowsun_before.png) | ![Shafts fan down from the gaps around the hidden sun](../reports/images/weather/godrays_aerial_lowsun_after.png) |
| ![Dawn, sun on the horizon behind cloud, before](../reports/images/weather/godrays_dawn_before.png) | ![Dawn rays rise from the sun on the horizon](../reports/images/weather/godrays_dawn_after.png) |

![A street-level shaft along the lane toward the morning sun](../reports/images/weather/godrays_street_morning_after.png)

![Clear noon control: no beams where there is no cloud to cut them](../reports/images/weather/godrays_noon_clear_after.png)

## Ground fog and evening mist

Fog banks gather on the shore, on a pier or on the meadow beside the sea, the moat or a stream. They are not everywhere: a bank needs damp air, water close by and a drifting patch of thicker air, so most of the shore stays clear. Banks fade in over a few seconds, drift with the wind and fade out when the air dries.

- **What thickens it**: dawn radiation mist (on its own seeded days), an overcast deck, falling rain and standing puddles, which keep giving moisture back after the rain stops.
- **What clears it**: wind, a high clear sun (it burns off about half), a storm wind.
- **Evening mist**: on damp, still dusks a second, weaker mist builds from half an hour before sunset, peaks about two hours later, holds two hours and thins out. It comes on its own occasional days and also dims the sun and moon glitter on the water. There is none in enclosed interiors.
- **Its own light**: each puff is lit on the side facing the sun (or moon), brightens at its thin edges when you look toward the light, takes its ambient colour from the horizon and flashes with lightning. Fog never glows at night, and street lamps and torches do not light it.

![Overcast morning: fog lying over the harbour shore](../reports/images/weather/local_fog_overcast_shore.png)

![After rain with a low sun: wet ground keeps the mist going](../reports/images/weather/local_fog_after_rain_lowsun.png)

![Overview of an overcast shore: fog only in patches near the water](../reports/images/weather/local_fog_overview.png)

## Distance: haze, air colour and blur

In third and first person the far city, hinterland and sea take on the colour of the air and soften with distance, while the street around the player stays sharp. The top-down gameplay camera gets none of this (it would read as a flat wash), and neither do roofed rooms.

- **Colour of the air**: blue by day, warm at golden hour, grey in rain and overcast, dark blue at night. It starts at about 25 m, is about 17% at 300 m and up to 60% far away.
- **How clear the air is**: air washed by rain and swept by wind is the clearest; damp overcast air, hot still air and falling rain thicken it up to about 2.4 times.
- **Blur**: from about 30 m surfaces soften, a few pixels at 500 m, more in thick air. A near roof edge does not bleed into the soft background. On the Mobile and Forward+ renderers a light far depth of field is added on top, still starting beyond the street.
- The sky and its clouds are not blurred. The sea gets only the plain horizon haze.

![Clear April noon (top) and hot June midday (bottom), before (left) and after (right)](../reports/images/weather/aerial_before_after_day.png)

![Evening and rain, before and after](../reports/images/weather/aerial_before_after_weather.png)

![The street and first person stay sharp](../reports/images/weather/aerial_before_after_street.png)

## Sky exposure under the daylight lift

Outdoors by day the whole frame is brightened (the outdoor exposure gain of [city lighting](./POST_PROCESS.md), R-1748), because the city materials read too dark without it. Applied to the sky as well, it clipped the cumulus to flat white and paled the zenith. Since R-1766 the visible sky dome divides that gain back out: the zenith is deep blue again, clouds show their shaded sides and golden-hour clouds keep their colour, while streets, roofs and far land stay exactly as bright as before.

- The compensation is full right down to the horizon (it fades in over the lowest quarter of a degree, R-1794). Two things carry the same factor so no seam shows: the aerial haze colour that far ground fades to (`haze_gain_compensation` in the haze pass, fed from `SkyWeather3D.exposure_gain_compensation()`), and the sea's mirror of the sky (the sky exposure handed to the water reflection).
- The gain, and so the compensation, fades with the daylight through twilight; at night and in roofed rooms there is none and the sky is unchanged.
- Only the visible dome is compensated. The sky light the engine reflects off wet stone, iron and glass keeps the brightness it had, so the city looks the same.

![Before (left) and after (right): noon clear, cloudy afternoon, cloudy golden hour](../reports/images/weather/sky_reference_before_after.png)

## Lit cloud deck

Status: implemented (task **R-1768**). On the recommended tier the continuous dome deck reads as heaped cumulus instead of soft smears: its edges bulge into rounded lobes and bite in between them, sunlit lobe sides are bright, sides turned from the sun and lobes behind a taller heap fall into shade, and the deck seen overhead shows grey cores with bright thin rims. The minimum tier keeps the flat deck unchanged.

- **How**: a 2.5D deck. The deck's bulk is treated as a height field of heaped tops, bumped by lobes from the same cellular shape texture at a finer scale (`sky_cloud_lobes`, `1 - d^2` so lobes have rounded crowns, not cone facets). Shading takes the bump normal (3 height samples) and a two-step height-field march toward the sun (`sky_cloud_lit_share`); edges are bulged or bitten by `sky_cloud_lobe_erode`, centred on the measured lobe mean so cover does not shrink. The deck slab is shallower (`LIT_DECK_SLAB_DEPTH` 0.06 instead of 0.14) because the lighting now carries the volume, and the deck shade side is darker (`LIT_DECK_SHADE`). Lobes fade toward the horizon where one would be smaller than a pixel.
- **Same clouds everywhere**: the ground-shadow pass applies the same lobe erosion (`deck_lobes`, set from `WeatherPresentation.cloud_deck_lobes`), and the CPU mirror that dims sun/moon reflections (`celestial_cloud_clear`) erodes and uses the shallow slab too, so the shadow on the ground has the outline of the deck overhead. Everything is a pure function of the saved cloud offsets; nothing new is saved.
- **Switch**: `cloud_deck_mode` in the sky quality row (`SkyWeather3D.QUALITY_TIERS`, mirrored in `SkyWeatherQuality`): 0 flat on minimum, 1 lit on recommended, 2 slab on high (R-1873, lit deck as its fallback). `cloud_deck_lit()` is true for 1 and 2.
- **Cost**: within noise of the flat deck. 1280x720, Apple M5 Pro, Mobile renderer, wall-clock best of three 200-frame rounds, flat vs lit on the same frames: noon clear 14.07 / 14.67 ms, cloudy afternoon 19.38 / 19.48, steep cloudy view 12.99 / 12.85, golden hour 13.50 / 14.21. Budget was 1.5 ms.
- Verify: `tools/godot_render.sh --script tools/capture_sky_reference.gd -- --ab` writes `sky_reference_<shot>_deck0.png` (flat) and `_deck1.png` (lit) from the same frames; `-- --bench=200 --decks=0,1` prints the frame times (pass `--resolution 1280x720 --disable-vsync` to the wrapper). Tests: `--filter=test_sky_weather_3d,test_cloud_shadow_pass`.

![Flat deck (left) and lit deck (right): noon clear, cloudy afternoon, steep cloudy view, sunset](../reports/images/weather/sky_reference_r1768_before_after.jpg)

## Volumetric cloud slab (high tier)

Status: implemented (task **R-1873**). On the high graphics preset the low cloud deck is a real volume: fair-weather cumulus have flat bases and domed tops, the densest heaps rise as towers above the rest of the deck, thin edges toward the sun let light through, and thick cores go grey from below. Minimum and recommended are unchanged (flat and lit 2.5D deck).

- **What is drawn**: a Nubis/Horizon-style slab between deck altitude 1.0 (the cumulus base, about 1.5 km) and 2.0 over the same curved-Earth shell as the deck (`sky_cloud_layer_distance`, R-1869), so horizon clouds recede exactly like the deck. Coverage at the slab base is the lit deck opacity (bulk, detail erosion, lobes). Each column rises to a height set by its coverage and a coarse "tower" cell pattern from the shape texture (a third of the slab for ordinary heaps, the full slab under a tower cell, higher in storms) and narrows toward its top into a dome. Two octaves of the 3D cell noise erode the edges (more toward the crown). Lighting: 4-step march toward the sun (the first two steps see the billows), Beer with three multiple-scattering octaves, a powder term, a dual-lobe Henyey-Greenstein phase for the silver lining, and height-graded sky light.
- **How it is rendered**: `CloudSlabEffect` (`scripts/map/view3d/cloud_slab_effect.gd`) is a `CompositorEffect` on the camera (pre-opaque). A compute shader (`cloud_slab.glsl`, version `march`) marches 32 steps per texel at half width and half height with a per-frame interleaved-gradient-noise start offset; a second pass (`resolve`) reprojects last frame's result by world direction, clips it to the 3x3 neighbourhood (mean +- 1 sigma) and blends 10% of the new frame, then the result is copied into the history. The sky shader samples the resolved texture (`cloud_slab_tex`, opacity + premultiplied light share) and keeps all its own colouring: golden hour, dusk ramp, haze, cells, cirrus and rain curtains are unchanged.
- **Direction-indexed**: texels are addressed by world direction through the camera basis and tangents (`cloud_slab_world_to_view`, `cloud_slab_tan`, with an 8% margin), which `SkyWeather3D._update_cloud_slab()` hands to the material and, through `RenderingServer.call_on_render_thread`, to the pass in the same order. The dome therefore looks a cloud up where it was rendered regardless of framebuffer orientation, and directions outside the slab texture (the radiance cubemap, reflection views) fall back to the lit deck with a soft edge.
- **Same clouds everywhere**: the slab footprint is the lit deck coverage, so ground shadows (lobed, `deck_lobes`) and the sun/moon reflection dimming keep reading the deck. With the slab active, `celestial_cloud_clear(match_sky_deck = true)` marches the slab on the CPU instead (`_cloud_volume_clear`, 16 steps, no billow erosion). A test checks that straight up the slab is open where the deck is empty and cloudy where it is dense. Nothing new is saved; the slab is a pure function of the saved cloud offsets.
- **Switch and fallback**: `cloud_deck_mode` 2 and `cloud_slab_steps` 32 in the `high` row of `SkyWeather3D.QUALITY_TIERS` (mirrored in `SkyWeatherQuality`); `GraphicsPresets` high uses it. Without a `RenderingDevice` (headless, Compatibility) or before the first slab frame, `cloud_slab_active()` is false and the dome draws the lit deck. Capture tools force a mode with `set_cloud_deck_mode(mode)`.
- **Cost**: 0.41-0.72 ms for the pass alone at 1280x720 (march + resolve at 640x360) on an Apple M5 Pro, Mobile/Metal, measured with `--slab-cost=60` on a local RenderingDevice, best of 60: noon clear 0.41, cloudy afternoon 0.60, steep cloudy view 0.72 (worst case, all sky and cloud), golden hour 0.60-0.66. Budget 2 ms. Where the slab covers the view the dome skips its own 8-step deck march, so the whole-frame wall-clock A/B (`--bench=120 --decks=1,2`, best of three, other sessions on the same GPU) is within noise: lit deck / slab 17.06 / 17.60 ms noon, 24.61 / 26.86 cloudy afternoon, 15.72 / 14.72 steep cloudy, 18.02 / 16.29 sunset, 16.23 / 16.92, 22.24 / 17.16 and 15.51 / 16.26 golden hour. Memory: three RGBA16F targets at half resolution, about 2.6 MiB at 1280x720.
- Verify: `tools/godot_render.sh --script tools/capture_sky_reference.gd -- --ab --decks=1,2` (lit deck vs slab from the same frames; switching to mode 2 waits 40 frames for the history), `-- --bench=120 --decks=1,2` with `--disable-vsync`, and `-- --slab-cost=60` for the isolated pass cost. Tests: `--filter=test_sky_weather_3d,test_cloud_shadow_pass,test_graphics_presets`. After editing `cloud_slab.glsl` run `godot --headless --path . --import`: the compute shader is an imported `RDShaderFile` and stays stale otherwise.

![Lit 2.5D deck (left) and ray-marched slab (right): noon clear, cloudy afternoon, steep cloudy view, sunset](../reports/images/weather/sky_reference_r1873_before_after.jpg)

## Cloud deck perspective

Status: implemented (task **R-1869**). Clouds near the horizon look tens of kilometres away: they shrink, flatten into thin bands and sink into the haze instead of hanging as zenith-sized puffs above the sea.

- **How**: every deck lookup (`sky_cloud_uv` in `scripts/map/view3d/sky_clouds.gdshaderinc`) follows the eye ray to a spherical shell over a curved Earth (`sky_cloud_layer_distance`, radius `SKY_CLOUD_EARTH_RADIUS` = 1600 deck-altitude units). Overhead the distance equals the deck altitude, at the horizon it is `sqrt(2 R altitude)`, about 57x the overhead distance (~85 km for a 1.5 km deck). The old flat-plane ray had a `0.012` floor that stopped at about 9x, so the deck read as a low ceiling. 1600 rather than the true ~4250 keeps the far band resolvable before mipmaps smear it into haze.
- **Same clouds everywhere**: the CPU mirror (`SkyWeather3D._cloud_uv_at`, `CLOUD_EARTH_RADIUS`) uses the same formula, so sun/moon reflection dimming still matches the dome. The ground-shadow pass samples by world position and is unaffected. Nothing is saved.
- Verify: `tools/godot_render.sh --script tools/capture_sky_reference.gd -- --only=aft_side_cloudy` (and `noon_side_clear`); tests `--filter=test_sky_weather_3d,test_cloud_shadow_pass`.

![Before (left) and after (right): noon clear, cloudy afternoon](../reports/images/weather/sky_reference_r1869_before_after.jpg)

## Golden-hour clouds

Status: implemented (task **R-1767**). With the sun about 8-16 degrees up, fair-weather clouds glow warm gold on their crowns with warm grey-brown undersides against a blue sky; they no longer turn pink or lavender. Real sunset (sun below about 4 degrees) keeps the pink and violet palette.

- The old dusk ramp (pink, violet shade, broad sun glow) began at 16 degrees and was already half strength at 8. It now ramps in only below about 6 degrees (`pink_ramp` in `sky_weather_3d.gdshader`).
- Between roughly 8 and 16 degrees a separate golden-hour weight warms the sunlit crowns and tints the cloud shade from the horizon colour of the sky LUT.
- The sun glow band hugs the sun in golden hour (exponent 8) and only widens (exponent 2) at true sunset.
- A narrow forward-scatter (Henyey-Greenstein) lobe lights cloud edges right beside the sun instead of a broad bloom.
- Verify: `tools/godot_render.sh --script tools/capture_sky_reference.gd` plates `gold_070_cloudy`, `gold_074_cloudy`, `gold_077_cloudy` (cycle progress 0.70, 0.74, 0.77; sun about 22, 14, 8 degrees) and `gold_side_cloudy` (0.80, about 4 degrees, still pink). Before/after of the 8 degree plate:

![Sun about 8 degrees up, before: pink and lavender clouds](../reports/images/weather/sky_reference_gold_077_before.png)
![Sun about 8 degrees up, after: warm gold clouds](../reports/images/weather/sky_reference_gold_077_cloudy.png)

## Heat mirage

On hot, calm, dry middays with no more than fair cumulus, pale streaks shimmer just above the horizon and the far ground below it wavers by a few pixels, as if seen through rising hot air. It needs a high sun: strong from May to July around noon, a little in mid-August, almost none in the campaign's April opening. Heat is judged from the sun's height and the weather, not from a temperature simulation.

![Midsummer noon: shimmer above the far horizon](../reports/images/weather/horizon_mirage_midsummer.png)

## Decisions

- **Rain on the ground stays town-wide.** Storm rain falls only where the player stands, but puddles, mud and saved ground water follow the weather-wide rain. A storm drifts over the whole town during one storm, and ground water must not depend on where the player happened to stand when the game was saved.
- **Rain may fly sideways** (user, 2026-10-09). This replaced the earlier rule that rain falls straight down.
- **Storms only in hotspots.** Without them every merged cluster put a storm right next to the player, and several identical storms ringed the horizon.
- **The misty cloud rim** is the default of four tried presets; the others stay in the capture tool.
- **Clouds under the deck are shaded per cloud**, not per sample, so the deck's own shadow edge never cuts through one cloud.
- **`clear` keeps its id and meaning** (fair cumulus) for save compatibility; `cloudless` is the new clear sky.
- **The sky keeps its own exposure** (R-1766). The daylight lift is divided out of the visible dome instead of lowering the lift or re-tuning the sky colours, so the city brightness R-1748 calibrated and the sky colours tuned before it both stay valid. It first faded out toward the horizon, accepting a washed-out low sky to avoid a seam against hazed far ground. R-1794 removed that fade by giving the haze colour and the sea reflection the same factor, so low clouds now keep their shading down to the horizon.
- **Fog colour is not compensated** (R-1794). Scaling `fog_light_color` too exposed the sea's bright horizon reflection as a thin white line and would have dimmed street mist and rain haze. Fog is only 8% on the dome (`fog_sky_affect`), so it leaves no visible seam. Far ground now fades to a slightly darker haze than before; within the 25 m clear radius nothing changes.
- **Pink waits for true sunset** (R-1767). The dusk palette is gated by `pink_ramp` instead of the 16 degree band, and a golden-hour weight carries the 8-16 degree range, so golden hour reads warm rather than rose.
- **One weather chain for the whole campaign**; seasonal odds need a calendar-driven table and are not done.
- **2.5D lit deck, not a ray-marched cloud slab** (R-1768 spike). A Nubis-style prototype (world-space slab 1.2-2.5 km, deck coverage as the weather map eroded by the 3D Worley cell noise, 32 view steps, 4 sun steps) cost about 8.6 ms more than the flat deck on the steep cloudy view at 1280x720, against a 1.5 ms budget. The Godot sky shader has no history buffer, so the low-resolution + temporal reprojection that makes such a slab affordable would need its own compositor pass; the quarter-resolution sky pass alone would still be about 2 ms and flicker with jitter. The 2.5D deck costs no measurable frame time, keeps ground shadows and the CPU mirror in step with one shared function, and needs no new texture. The slab stays the route for a future high tier.
- **The high tier renders the slab in a compositor pass** (R-1873). Quarter of the pixels (half width x half height), 32 jittered steps, history with reprojection and variance clipping, so the cost is a fraction of the R-1768 full-resolution prototype. The pass writes opacity and a light share instead of colour so the dome keeps one palette (golden hour, dusk, haze) for all three deck modes. Texels are indexed by world direction rather than by screen pixel, which removes any dependence on framebuffer y orientation (Metal) and lets the cubemap and reflections fall back cleanly. Metal reports no GPU timestamps, so the cost is measured by rerunning the pass on a local `RenderingDevice` (`--slab-cost`); the in-frame wall-clock A/B is within noise.

## Saved state

The whole cloud field, storms included, rebuilds from the saved weather, cloud drift, wind and cloud clock, plus the last lightning strike. Nothing else is saved: fog, haze, mirage, sunbeams and rainbows are recomputed every frame, and a load or a map change shows the same clouds and fog patches at the same simulated time. A save made in `cloudless` weather and opened by an older build falls back to `clear`.

## Quality and performance

Quality tiers change cost only; cloud positions and lightning timing are identical on every tier. The minimum tier marches clouds more coarsely, draws no sunbeams in the sky, uses fewer fog banks and skips the distance blur and heat shimmer. Measured on an Apple M-series GPU at 1280x720: the clouds cost no measurable frame time in a city street view, the haze and blur pass about 1.3 ms.

## Limits

- Fair cumulus fade out at about 1.2-1.6 km; only storms reach the 5-6 km horizon.
- Storms have no life of their own: they follow their cluster and sink as soon as it drifts apart. Storm rain reads as light rain, not a downpour, and a storm's curtain is faint from a few kilometres.
- Hotspots sit on a regular lattice; storms in neighbouring hotspots grow and sink together.
- Overlapping storms are not depth-sorted and can show ordering artifacts. A storm crown that rises above a closed grey sheet is still drawn, unlit, instead of being hidden by it.
- The lit deck (recommended) is a shaded height field, not a volume: it has no towers rising above the deck, no light passing through thin parts toward the sun beyond the forward-scatter lobe, and near the horizon its lobes fade into the flat deck. The high tier's slab has both, but its surfaces are softer than the lit deck's lobes (half-resolution, bilinear upsampling, temporal blend) and fast camera turns can leave a brief soft trail at cloud edges. Slab towers cast their ground shadow from the deck footprint, not from the tower's height, and the slab is not drawn in the radiance cubemap or in reflections outside the current view (they show the lit deck). On the minimum tier the flat deck can still show cut-out edges next to a soft cloud.
- Sunbeams, the god-ray cloud shade map and the water's deck shadow read the deck without its lobes, so their edges can differ from the lit deck by about one lobe.
- Cloud edges show a fine dither close up.
- Ground shadows do not follow the wind stretch of a cloud. The dome deck is drawn around the camera while its ground shadows are anchored to the world, so the shadows line up with each other but not exactly with the deck right overhead.
- Water dims only its direct sun under cloud; sea shadows are lighter than grass shadows. The FFT sea shows only the separate clouds' shadows, not the deck's (see [city sea](./CITY_SEA.md#perspective-sea-visibility-r-1437)).
- The outdoor rain ambience still hears the town-wide rain, not the local storm rain. Thunder is not timed to strike distance.
- The sun-shower rainbow appears only on storm curtains, not on the dome's distant rain curtains or in water reflections.
- Fog forms only near water the view can probe, so a map with no water has no fog banks. Fog height follows the ground roughly and can float or sink a little on steep slopes. Cloud shadows, sunbeams, fog and water are drawn after the haze pass and are not hazed or blurred by it.
- There is no focus pull: focus stays on the player's surroundings.
- The city sunbeams skip terrain, so roof-edge shafts do not form in Upper Town streets on the klint (cloud shafts still do). The sunbeam pass has no low-quality variant yet.
- Fogged far ground (dawn mist, rain haze, horizon haze in the Environment fog) still carries the daylight lift; only the haze pass and the sea reflection are compensated. The sea's reflection of the sky is now dimmer in the city harbour by the same factor as the dome, so the water matches the sky it mirrors.
- Golden-hour cloud tone is judged from the capture plates only; the near-horizon white haze beside the sun comes from the sky LUT and ground haze, not the cloud shader, and is unchanged.
- Missing plates: no current capture shows a lightning strike or the evening mist. Independent visual sign-off on fog and haze is still pending.

## For developers

The names below are entry points; read the file headers for details. Tunable constants live at the top of each script.

| Area | Files |
|---|---|
| Cloud field (pure, deterministic) | `scripts/map/view3d/cloud_cells.gd`, `cloud_cells.gdshaderinc` |
| Sky, weather cycle, storm rain, lightning | `scripts/map/view3d/sky_weather_3d.gd`, `sky_weather_3d.gdshader`, `sky_clouds.gdshaderinc`, `sky_rainbow.gdshaderinc`, `sky_weather_resources.gd` |
| Volumetric cloud slab (high tier) | `cloud_slab_effect.gd` (CompositorEffect), `cloud_slab.glsl` (march + resolve compute) |
| Cloud shadows on ground and water | `cloud_shadow_pass.gd`/`.gdshader`, `water_cloud_shadow.gdshaderinc`, `scripts/city/city_water_light.gdshaderinc` |
| Sunbeams | `god_ray_pass.gd`/`.gdshader` (plus the dome's own beams in the sky shader) |
| Fog banks, mirage, owner node | `local_atmosphere.gd`, `local_fog_banks.gd`, `local_fog_puff.gdshader`, `horizon_mirage.gd`/`.gdshader` |
| Sky exposure compensation | `sky_exposure_gain_compensation` in `map_view_lighting.gd`, `set_exposure_gain_compensation` in `sky_weather_3d.gd`, `sky_gain_compensation` uniform in `sky_weather_3d.gdshader` |
| Haze, blur, heat shimmer | `aerial_perspective_pass.gd`/`.gdshader`, damp air and heat in `map_view_lighting.gd` |
| Mounting | `MapView3D` (district maps), `CityMapView` (seamless city) |

Screen passes have a fixed draw order because in GL Compatibility the water's screen copy empties the depth texture for everything drawn after it: haze and blur first, then cloud shadows, sunbeams, fog, and water last. Keep new passes in that order.

Tests:

```bash
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_cloud_cells,test_cloud_shadow_pass,test_god_ray_pass
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_sky_weather_3d,test_sky_weather_state,test_weather_realism
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_local_fog_banks,test_aerial_perspective,test_map_view_lighting
```

Plates (render in a minimized window; screen passes need the root window, not a `SubViewport`). Each tool lists its shots and flags in its header.

```bash
tools/godot_render.sh --script tools/capture_cloud_cells.gd [-- --only=<shot>,<shot>]   # clouds, shadows, storms, rain, rainbow
tools/godot_render.sh --script tools/capture_god_rays_city.gd [-- --tag=after]           # sunbeams
tools/godot_render.sh --script tools/capture_local_fog.gd                                 # fog banks, mirage
tools/godot_render.sh --script tools/capture_aerial_perspective.gd -- --tag=after         # haze and blur (--no-pass for before)
tools/godot_render.sh --script tools/capture_weather_realism.gd -- --only=night_storm     # night rain curtains
tools/godot_render.sh --script tools/capture_sky_reference.gd [-- --out=res://build/x]    # sky exposure: noon, cloudy afternoon, golden hour
tools/godot_render.sh --script tools/capture_sky_reference.gd -- --ab                     # R-1768 flat vs lit deck from the same frames
tools/godot_render.sh --script tools/capture_sky_reference.gd -- --ab --decks=1,2          # R-1873 lit deck vs ray-marched slab
```

Plates land in `docs/reports/images/weather/` (`--out=` redirects them), except the fog tool, which writes to `build/local_fog/` (copy the chosen ones over), and the weather-realism tool, which writes to `docs/reports/images/weather_realism/`.

## Wind-combed cirrus (R-1769)

Status: implemented (task **R-1769**). A high streak layer (cirrus fibratus with uncinus hooks) on a plane ~8 km up (5.3 deck altitudes), drawn in `cloud_field` in `scripts/map/view3d/sky_weather_3d.gdshader` after the existing sparse veil.

- **Anisotropy and convergence**: noise is sampled along the upper-wind axis (the sheared `high_wind`, `wind_dir` rotated 34 degrees) at a low frequency and across it at a high one, so streaks are long and thin. World-parallel streaks converge toward a vanishing point at the horizon by perspective alone; a slow cross-wind wobble bends the axis into hooks and tails (uncinus). Large soft patches keep it a few drifts, not a sheet.
- **Independent of cloud cover**: unlike the older 0.11 veil (gated by `cloud_coverage` 0.32-0.70), it shows on a cloudless sky. It fades under storm cells (`local_storm`) and a closing deck (`cloud_coverage` 0.7-0.95).
- **Seeded per day**: `SkyWeather3D.cirrus_amount_for(date)` is a pure hash of `WEATHER_SEED` and the calendar date (never draws from the weather RNG, so the seeded weather chain is unchanged). About 35% of days return 0 (`CIRRUS_NONE_SHARE`), the rest 0.35-1.0. `cirrus_seed_for(date)` shifts the noise domain so each day's streaks differ. Both are pushed as `cirrus_amount` / `cirrus_seed` in `_push_cloud_uniforms`.
- **Lighting**: it takes the sun-lit cloud tone (light 0.97) through the normal cloud colour ramp, so dusk and golden hour tint it like every other cloud. It never enters the ground-shadow pass or the CPU occlusion mirror, so it casts no shadow and does not hide the Moon or stars.
- **Verify**: `tests/godot/test_sky_weather_3d.gd` (`test_cirrus_amount_is_seeded_per_day`); plates `tools/capture_cloud_cells.gd --only=cells_sky_cloudless` and `tools/capture_sky_reference.gd --only=aft_side_clear` (new shot) via `tools/godot_render.sh`. Default date 21 April 1343 rolls 0.61.
- **Limits**: one layer, no animation beyond the shared `cloud_offset` drift; the cubemap radiance pass carries it but the slab tier does not shade it.
