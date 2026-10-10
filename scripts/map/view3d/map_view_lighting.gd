class_name MapViewLighting
extends RefCounted

## Deterministic outdoor lighting and atmosphere for MapView3D. This module owns
## the visual day/night response so the view node can focus on scene assembly,
## streaming, actor projection, and occlusion while retaining its public API.

const DayNightCycle := preload("res://scripts/global/day_night_cycle.gd")

const SUN_DAY_COLOR := Color8(255, 243, 222)
## Exposure pass (brightness tour): AgX compresses highlights hard, so 1.2 sun and
## 0.85 fill left noon streets at ~50/255 mean luma with near-black shadow sides.
## Daylight RPG references (KCD2, Witcher 3) sit near 100-130 with readable shade.
const SUN_DAY_ENERGY := 2.2
const AMBIENT_DAY_COLOR := Color8(168, 178, 189)
const AMBIENT_DAY_ENERGY := 1.7
## Outdoor shade is lit by the sky and by sunlit ground and walls. Pure sky hue
## painted every shadowed facade blue; a warm limestone/earth bounce at similar
## luminance keeps the shade neutral and the albedo readable.
const AMBIENT_GROUND_BOUNCE_COLOR := Color8(190, 178, 156)
const AMBIENT_GROUND_BOUNCE_WEIGHT := 0.4
const BACKGROUND_DAY_COLOR := Color8(31, 30, 28)

## Top-down interior gameplay hides the ceiling; a flat black clear color keeps
## the room readable instead of letting the outdoor sky dome show through.
const BACKGROUND_INTERIOR_TOP_DOWN_COLOR := Color.BLACK

## Night fill is deliberately subdued: practical lights should dominate walls,
## actors and diffuse white foam. The directional component also follows lunar
## photometry/cloud visibility, rather than illuminating a moonless sky.
const SUN_NIGHT_COLOR := Color8(142, 162, 210)
const SUN_NIGHT_ENERGY := 0.28
## A small ambient floor retains silhouettes without day-bright whitecaps.
const AMBIENT_NIGHT_COLOR := Color8(76, 94, 138)
const AMBIENT_NIGHT_ENERGY := 0.45
const BACKGROUND_NIGHT_COLOR := Color8(14, 18, 28)
## Under a roofed room shell the fill is daylight bounced off limewash, timber
## and clay, not open sky: warm it instead of letting sky-blue fill tint every
## plastered wall and iron tool indoors.
const INTERIOR_DAY_BOUNCE_COLOR := Color8(190, 172, 150)
const INTERIOR_NIGHT_BOUNCE_COLOR := Color8(84, 78, 76)
const INTERIOR_BOUNCE_WEIGHT := 0.85
## The exposure pass doubled outdoor fill; rooms are lit through a door and
## small windows, so keep roofed interiors near the earlier fill and let hearth
## and candle light stay the accent.
const INTERIOR_AMBIENT_ENERGY_SCALE := 0.6

## Golden-hour and weather tints blended over the day/night baseline.
const SUNSET_LIGHT_COLOR := Color8(255, 148, 64)
const OVERCAST_LIGHT_COLOR := Color8(172, 182, 196)
const LIGHTNING_LIGHT_COLOR := Color8(206, 220, 255)
const LIGHTNING_SUN_ENERGY := 1.6
const LIGHTNING_AMBIENT_ENERGY := 0.9

## WS-11 art-direction tints. Physics is the base: AtmosphereCpu evaluates the sun colour,
## the skylight hue and the horizon hue from the same WS-09 LUTs that draw the WS-10 dome,
## so walls, shadows, mist and the sea agree with the sky. A tint multiplies that physical
## colour; white means "physical as is". The legacy SUN_DAY_COLOR, SUNSET_LIGHT_COLOR,
## AMBIENT_DAY_COLOR and FOG_MORNING_COLOR remain the fallback when the LUTs are missing and
## stay until the WS-11 capture review accepts the physical look. The overcast and lightning
## lerps still apply on top: weather stays authoritative.
const SUN_ART_TINT := Color.WHITE
const AMBIENT_ART_TINT := Color.WHITE
const FOG_ART_TINT := Color.WHITE
## Physical sun energy relative to noon, clamped so a horizon sun still models form.
const PHYSICAL_SUN_ENERGY_MIN := 0.15
## Civil twilight still has a bright sky, but daylight_blend is a -6..+6
## smoothstep so -3 deg is already ~0.16 and the ground goes night-black.
## Ambient and post-grade ease out to the horizon blend and leave night (<= -6)
## and day (>= 0) on the current day_blend path. 0.7 (was 0.5) with the TWILIGHT_FILL_CURVE
## tail keeps the ground legible at -6..-12 deg, where a late-spring night at 59 N
## still has a lit sky (hinterland site plates showed pitch-black land under it).
const CIVIL_TWILIGHT_HORIZON_BLEND := 0.7
const TWILIGHT_FILL_CURVE := 0.5
## Mie forward scatter of the fog around the sun: thin in clear dawn air, stronger in haze.
const FOG_SUN_SCATTER_CLEAR := 0.2
const FOG_SUN_SCATTER_HAZY := 0.35

## Morning ground mist uses basic height-biased fog because the GL Compatibility
## renderer has no volumetric fog. Night uses a darker moonlit haze: the pale
## morning colour ignored day_blend and painted harbours as a flat light sheet
## from FOG_HOURS_BEFORE_SUNRISE through first light.
const FOG_NIGHT_COLOR := Color8(30, 38, 56)
const FOG_MORNING_COLOR := Color8(200, 210, 220)
## Distance fog stays a light veil. Peak cover comes from height fog at the
## waterline; 1.1 made Godot's 1-exp(-height*density) ~0.98 and hid the harbour.
const FOG_MAX_DENSITY := 0.010
const FOG_HEIGHT := 3.5
const FOG_MAX_HEIGHT_DENSITY := 0.20
## Peak waterline cover from height fog: 1-exp(-FOG_HEIGHT*FOG_MAX_HEIGHT_DENSITY).
const FOG_WATERLINE_COVER_MIN := 0.25
const FOG_WATERLINE_COVER_MAX := 0.55
const FOG_HOURS_BEFORE_SUNRISE := 3.0
const FOG_HOURS_AFTER_SUNRISE := 2.5
## Raising the onset from 0.6 to 0.8 cuts eligible mornings from roughly two in
## five to one in five while preserving the strongest deterministic fog days.
## Evening mist (R-1165): builds from just before sunset, holds through the first
## hours of night and thins out before the small hours. Weaker than dawn mist because
## the sea is warmer than the air by then, so it veils the glitter path less.
const EVENING_FOG_HOURS_BEFORE_SUNSET := 0.5
const EVENING_FOG_HOURS_RISE := 2.0
const EVENING_FOG_HOURS_HOLD := 2.0
const EVENING_FOG_HOURS_FADE := 2.0
const EVENING_FOG_STRENGTH := 0.8
const FOG_POTENTIAL_MIN := 0.8
const FOG_POTENTIAL_FULL := 0.95
## Mist and rain haze also scatter the direct beam that paints the sun/moon glitter
## path on water. Without this the glint stayed a full mirror through dawn mist.
## Vertical optical depth at peak mist / full rain; the slant path multiplies it by
## the air mass 1/sin(elevation), clamped so a horizon light keeps a finite path.
const GLINT_MIST_OPTICAL_DEPTH := 0.30
const GLINT_RAIN_OPTICAL_DEPTH := 0.50
const GLINT_HAZE_MAX_AIR_MASS := 12.0
## Aerial perspective for distant land and sea: a faint always-on distance veil in the
## horizon hue, thicker in damp air and in summer heat. Perspective cameras only; the
## orthographic gameplay lens would read the same fog as a flat wash.
const HORIZON_HAZE_DENSITY := 0.0011
const HORIZON_HAZE_BASE := 0.3
const HORIZON_HAZE_DAMP_WEIGHT := 0.35
const HORIZON_HAZE_HEAT_WEIGHT := 0.35
## Heat shimmer needs a high sun. Sine of the elevation: ~0.67 at the April noon the
## campaign opens in (no shimmer), ~0.77 in late May, ~0.81 at midsummer (full).
const HEAT_SUN_MIN := 0.7
const HEAT_SUN_FULL := 0.8
## Stars reflect from the whole dome; their haze path uses this mean elevation.
const GLINT_STAR_MEAN_ELEVATION_SIN := 0.5

## ADR 0018 saturated HDR-range post-grade. AgX compresses scene-referred values
## for the current SDR output; this does not claim HDR10 or wide-gamut delivery.
## Visual calibration tuned day exposure/glow so windows keep texture through AgX
## and night fill/chroma so local color remains readable outside emissive pools.
const TONEMAP_MODE := Environment.TONE_MAPPER_AGX
## Exposure pass: 1.20 saturation and 1.12 contrast pushed shade toward black and
## read as stylised; a natural daylight grade keeps colour through the midtones.
const GRADE_DAY_EXPOSURE := 1.05
## ADR 0022: naturalistic (KCD2-like) grade; colour comes from albedo and light, not a boost.
const GRADE_DAY_SATURATION := 0.98
const GRADE_DAY_CONTRAST := 1.04
const GRADE_DAY_BRIGHTNESS := 1.04
## Low-sun exposure lift (see low_sun_exposure_factor): none at 35 deg and above,
## full between the horizon and 8 deg.
const LOW_SUN_EXPOSURE_BOOST := 0.3
const LOW_SUN_EXPOSURE_FULL_ELEVATION := 8.0
const LOW_SUN_EXPOSURE_NONE_ELEVATION := 35.0
const GRADE_NIGHT_EXPOSURE := 0.94
const GRADE_NIGHT_SATURATION := 0.95
const GRADE_NIGHT_CONTRAST := 1.02
const GRADE_NIGHT_BRIGHTNESS := 0.92
const GLOW_HDR_THRESHOLD := 1.05
const GLOW_INTENSITY_DAY := 0.2
const GLOW_INTENSITY_NIGHT := 0.48
const GLOW_BLOOM := 0.10
const GLOW_STRENGTH := 1.0
const GLOW_MIX := 0.05


## One-time WorldEnvironment setup: tonemap, glow, and color-adjustment toggles.
static func configure_post_process(environment: Environment) -> void:
	if environment == null:
		return
	environment.tonemap_mode = TONEMAP_MODE
	environment.adjustment_enabled = true
	environment.glow_enabled = true
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	environment.glow_hdr_threshold = GLOW_HDR_THRESHOLD
	environment.glow_bloom = GLOW_BLOOM
	environment.glow_strength = GLOW_STRENGTH
	environment.glow_mix = GLOW_MIX
	environment.set("glow_levels/1", true)
	environment.set("glow_levels/2", true)
	environment.set("glow_levels/3", true)
	environment.set("glow_levels/4", false)
	environment.set("glow_levels/5", false)
	environment.set("glow_levels/6", false)
	environment.set("glow_levels/7", false)


## Cycle-driven saturated Baltic grade: rich day masters and colorful darker nights.
static func apply_post_grade(environment: Environment, day_blend: float) -> void:
	if environment == null:
		return
	var blend := clampf(day_blend, 0.0, 1.0)
	environment.tonemap_exposure = lerpf(GRADE_NIGHT_EXPOSURE, GRADE_DAY_EXPOSURE, blend)
	environment.adjustment_saturation = lerpf(GRADE_NIGHT_SATURATION, GRADE_DAY_SATURATION, blend)
	environment.adjustment_contrast = lerpf(GRADE_NIGHT_CONTRAST, GRADE_DAY_CONTRAST, blend)
	environment.adjustment_brightness = lerpf(GRADE_NIGHT_BRIGHTNESS, GRADE_DAY_BRIGHTNESS, blend)
	environment.glow_intensity = lerpf(GLOW_INTENSITY_NIGHT, GLOW_INTENSITY_DAY, blend)


## Proxy for regression tests: exposure * brightness must drop at least 20% at night.
static func post_grade_luminance_proxy(day_blend: float) -> float:
	var blend := clampf(day_blend, 0.0, 1.0)
	return (
		lerpf(GRADE_NIGHT_EXPOSURE, GRADE_DAY_EXPOSURE, blend)
		* lerpf(GRADE_NIGHT_BRIGHTNESS, GRADE_DAY_BRIGHTNESS, blend)
	)


## Applies one complete celestial/weather lighting state and reports whether it
## belongs to the discrete night bucket used by chimney and window presentation.
## `enclosed_interior` gates outdoor atmosphere (morning mist) the same way rain
## particles are suppressed under a roofed room shell.
static func apply_cycle_progress(
	progress: float,
	sun: DirectionalLight3D,
	environment: Environment,
	sky_weather: SkyWeather3D,
	interior_top_down: bool,
	enclosed_interior: bool = false
) -> bool:
	var sun_direction := SkyWeather3D.solar_direction(progress, sky_weather.calendar_date)
	var day_blend := SkyWeather3D.daylight_blend(progress, sky_weather.calendar_date)

	# Update the sky before taking the shared presentation snapshot so lighting,
	# fog, wet ground, wind, and water all consume the same transition sample.
	sky_weather.apply_sky_state(progress, day_blend, sun_direction)
	var presentation := sky_weather.presentation_snapshot(progress, day_blend)
	# Never rotate a specular source between two celestial bodies: that creates
	# a moving reflection of a light that does not exist. Both energies reach
	# zero at the handoff; twilight illumination belongs to the sky fill.
	var sun_light_weight := 1.0 if presentation.sun_direction.y >= 0.0 else 0.0
	var light_direction := (
		presentation.sun_direction if sun_light_weight > 0.0 else presentation.moon_direction
	)
	sun.basis = Basis.looking_at(-light_direction, Vector3.UP)
	sun.light_color = sun_light_color(presentation, sun_light_weight)
	sun.light_energy = sun_light_energy(presentation)
	# Grey overcast diffuses hard shadows; clear skies retain their crisp baseline.
	sun.shadow_opacity = 1.0 - smoothstep(0.45, 0.96, presentation.cloud_coverage) * 0.97

	# Directional sun is already gone below the horizon; lift only sky fill so
	# the harbour stays readable under the still-bright twilight dome.
	var fill_blend := twilight_fill_blend(
		presentation.day_blend, presentation.sun_direction
	)
	var day_ambient := ambient_day_color(presentation).lerp(
		AMBIENT_GROUND_BOUNCE_COLOR, AMBIENT_GROUND_BOUNCE_WEIGHT
	)
	var ambient := AMBIENT_NIGHT_COLOR.lerp(day_ambient, fill_blend)
	ambient = ambient.lerp(OVERCAST_LIGHT_COLOR, presentation.overcast * 0.5)
	if enclosed_interior:
		ambient = ambient.lerp(
			INTERIOR_NIGHT_BOUNCE_COLOR.lerp(INTERIOR_DAY_BOUNCE_COLOR, fill_blend),
			INTERIOR_BOUNCE_WEIGHT
		)
	ambient = ambient.lerp(LIGHTNING_LIGHT_COLOR, presentation.lightning * 0.7)
	environment.ambient_light_color = ambient
	# Indoors there is no sky to mirror: sky reflections turned wrought iron and
	# wet quench water sky-blue. Fire, candles and window spots still give highlights.
	environment.reflected_light_source = (
		Environment.REFLECTION_SOURCE_DISABLED if enclosed_interior
		else Environment.REFLECTION_SOURCE_BG
	)
	environment.ambient_light_energy = (
		lerpf(AMBIENT_NIGHT_ENERGY, AMBIENT_DAY_ENERGY, fill_blend)
		* presentation.ambient_energy
		+ presentation.lightning * LIGHTNING_AMBIENT_ENERGY
	)
	if enclosed_interior:
		environment.ambient_light_energy *= INTERIOR_AMBIENT_ENERGY_SCALE
	environment.background_color = BACKGROUND_NIGHT_COLOR.lerp(
		BACKGROUND_DAY_COLOR, presentation.day_blend
	)
	sync_background(environment, interior_top_down)
	var horizon_haze := 0.0
	if not enclosed_interior and sky_weather.view_is_perspective():
		horizon_haze = horizon_haze_amount(presentation)
	apply_ground_mist(environment, presentation, enclosed_interior, horizon_haze)

	# Water specular follows the visible sun disk rather than civil-twilight light,
	# preventing a sun glint after the disk has set.
	MapViewMaterials.apply_water_lighting(
		direct_sun_visibility(presentation.sun_direction), presentation.day_blend
	)
	MapViewMaterials.apply_coastal_tide(presentation.tide_level)
	# Glints answer to clouds (cloud_clear) and to the same mist/rain haze that
	# apply_ground_mist puts in the Environment, so dawn mist dims the glitter path.
	var mist := ground_mist_amount(presentation, enclosed_interior)
	var rain_haze := ground_rain_haze(presentation, enclosed_interior)
	MapViewMaterials.apply_water_sky_reflection(
		presentation.star_map,
		presentation.sun_direction,
		presentation.moon_direction,
		direct_sun_visibility(presentation.sun_direction) * presentation.sun_cloud_clear
			* glint_haze_transmittance(presentation.sun_direction.y, mist, rain_haze),
		presentation.moon_visibility
			* glint_haze_transmittance(presentation.moon_direction.y, mist, rain_haze),
		presentation.star_visibility
			* glint_haze_transmittance(GLINT_STAR_MEAN_ELEVATION_SIN, mist, rain_haze),
		deg_to_rad(SkyAstronomy.observer_latitude_degrees),
		presentation.sidereal_angle,
		presentation.sun_reflection_color,
		presentation.sunset_factor,
		water_cloud_darken(presentation),
		presentation.sky_lut,
		presentation.sky_lut_size,
		presentation.sky_exposure,
		presentation.sky_tint
	)
	# R-1518: calm water mirrors the post-rain bow. Interiors see no sky.
	MapViewMaterials.apply_water_rainbow(
		0.0 if enclosed_interior else presentation.rainbow_strength,
		presentation.rainbow_curtain,
		0.85,
		presentation.rainbow_secondary
	)
	apply_post_grade_snapshot(environment, presentation)
	return presentation.day_blend < 0.5


## Directional light colour. Physical path: the AtmosphereCpu sun (the same transmittance
## that colours the WS-10 sun disk) hands off to the moon colour over the same -6..0 degree
## `sun_light_weight` that turns the light direction, so at 2 degrees the walls take the
## disk's orange instead of a day_blend mix with moonlight. Overcast still lerps on top.
static func sun_light_color(
	presentation: SkyWeather3D.WeatherPresentation, sun_light_weight: float
) -> Color:
	var color: Color
	if presentation.atmosphere_available:
		color = SUN_NIGHT_COLOR.lerp(
			presentation.physical_sun_color * SUN_ART_TINT, clampf(sun_light_weight, 0.0, 1.0)
		)
	else:
		color = SUN_NIGHT_COLOR.lerp(SUN_DAY_COLOR, presentation.day_blend)
		color = color.lerp(SUNSET_LIGHT_COLOR, presentation.sunset_tint)
	return color.lerp(OVERCAST_LIGHT_COLOR, presentation.overcast)


## Directional light energy. The physical path scales the day energy by the sun's
## transmitted luminance and drops SUNSET_ENERGY_DIM, which that physics replaces.
static func sun_light_energy(presentation: SkyWeather3D.WeatherPresentation) -> float:
	var day_energy := SUN_DAY_ENERGY
	var weather_energy := presentation.sun_energy
	if presentation.atmosphere_available:
		day_energy *= clampf(presentation.physical_sun_energy, PHYSICAL_SUN_ENERGY_MIN, 1.0)
		weather_energy = presentation.weather_sun_energy
	var celestial_energy := day_energy * direct_sun_visibility(presentation.sun_direction)
	if presentation.sun_direction.y < 0.0:
		celestial_energy = SUN_NIGHT_ENERGY * presentation.moon_visibility * moon_handoff(
			presentation.sun_direction
		)
	return celestial_energy * weather_energy + presentation.lightning * LIGHTNING_SUN_ENERGY


## Day side of the ambient blend: the physical skylight hue (bluish at noon, violet at
## dusk) at the calibrated AMBIENT_DAY_COLOR luminance, so exposure stays where the grade
## was tuned and only the colour becomes physical.
static func ambient_day_color(presentation: SkyWeather3D.WeatherPresentation) -> Color:
	if not presentation.atmosphere_available:
		return AMBIENT_DAY_COLOR
	return physical_hue(presentation.sky_irradiance, AMBIENT_DAY_COLOR) * AMBIENT_ART_TINT


## Rescales a linear physical colour to `reference`'s linear luminance and returns it
## sRGB-encoded for a Godot Color property. Falls back to `reference` without energy.
static func physical_hue(linear_color: Color, reference: Color) -> Color:
	var target := AtmosphereCpu.luminance(reference.srgb_to_linear())
	var scaled := AtmosphereCpu.with_luminance(linear_color, target, Color(-1.0, 0.0, 0.0))
	if scaled.r < 0.0:
		return reference
	return scaled.linear_to_srgb()

## Active SkyWeather3D profile `darken`. Presentation does not carry a blended
## value (WS-11 kept this lookup), so lighting reads the named preset. Overcast is
## 0.72; leaving this at 0 kept every water `cloud_darken` term dead.
static func water_cloud_darken(presentation: SkyWeather3D.WeatherPresentation) -> float:
	if presentation == null:
		return 0.0
	var profile: Variant = SkyWeather3D.PROFILES.get(presentation.weather)
	if typeof(profile) != TYPE_DICTIONARY:
		return 0.0
	return clampf(float((profile as Dictionary).get("darken", 0.0)), 0.0, 1.0)


static func sun_elevation_degrees(sun_direction: Vector3) -> float:
	return rad_to_deg(asin(clampf(sun_direction.y, -1.0, 1.0)))


## Direct solar lighting ends at the water horizon, not at civil twilight.
static func direct_sun_visibility(direction: Vector3) -> float:
	return smoothstep(0.0, 0.05, direction.y)


## Leave a dark handoff interval instead of sweeping a phantom light across water.
static func moon_handoff(direction: Vector3) -> float:
	return 1.0 - smoothstep(-6.0, -1.0, sun_elevation_degrees(direction))


## Carry the sky fill through civil and nautical twilight to astronomical night.
## The same -18..0 degree ramp is used by the dome and reflected sky floor.
static func twilight_fill_blend(day_blend: float, sun_direction: Vector3) -> float:
	var twilight := pow(smoothstep(sin(deg_to_rad(-18.0)), 0.0, sun_direction.y), TWILIGHT_FILL_CURVE)
	# Crossfade (not maxf): a plateau at the civil-twilight cap let the sunset colour shift
	# make the fill dip as the sun rose through the horizon.
	var day := clampf(day_blend, 0.0, 1.0)
	return lerpf(CIVIL_TWILIGHT_HORIZON_BLEND * twilight, 1.0, day)


## energy * sRGB luminance of the applied ambient colour. Tests use this so a
## twilight harbour stays above midnight and below noon without new lights.
static func ambient_readability(environment: Environment) -> float:
	if environment == null:
		return 0.0
	var color := environment.ambient_light_color
	var luma := color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
	return environment.ambient_light_energy * luma


static func apply_post_grade_snapshot(
	environment: Environment, presentation: SkyWeather3D.WeatherPresentation
) -> void:
	if presentation == null:
		return
	apply_post_grade(
		environment, twilight_fill_blend(presentation.day_blend, presentation.sun_direction)
	)
	environment.tonemap_exposure *= low_sun_exposure_factor(presentation.sun_direction)
	# Wet air reduces distant contrast; retain local material color and exposure.
	environment.adjustment_saturation -= presentation.overcast * 0.12
	environment.adjustment_contrast -= presentation.overcast * 0.07


## Stand-in for eye adaptation, which GL Compatibility lacks. A low sun throws
## long shadows over most streets and the dimetric camera sees the shade sides,
## so a fixed exposure turned late afternoon into night. The lift peaks near the
## horizon and fades out below it, so twilight and night keep their grade.
static func low_sun_exposure_factor(sun_direction: Vector3) -> float:
	var elevation := sun_elevation_degrees(sun_direction)
	var low_sun := 1.0 - smoothstep(
		LOW_SUN_EXPOSURE_FULL_ELEVATION, LOW_SUN_EXPOSURE_NONE_ELEVATION, elevation
	)
	var above_horizon := smoothstep(-3.0, 3.0, elevation)
	return 1.0 + LOW_SUN_EXPOSURE_BOOST * low_sun * above_horizon


## Enclosed top-down interiors use a black void below the hidden ceiling;
## outdoor and first-person views retain the weather sky.
static func sync_background(environment: Environment, interior_top_down: bool) -> void:
	if environment == null:
		return
	if interior_top_down:
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = BACKGROUND_INTERIOR_TOP_DOWN_COLOR
	else:
		environment.background_mode = Environment.BG_SKY


## Low morning mist peaks at first light, disperses in wind, and stays disabled
## in enclosed interiors (any camera mode under a roofed room shell). The
## date-based potential keeps fog occasional rather than universal outdoors.
static func apply_ground_mist(
	environment: Environment,
	presentation: SkyWeather3D.WeatherPresentation,
	enclosed_interior: bool,
	horizon_haze: float = 0.0
) -> void:
	if environment == null or presentation == null:
		return
	if enclosed_interior:
		environment.fog_enabled = false
		return
	var mist := ground_mist_amount(presentation, false)
	var rain_haze := ground_rain_haze(presentation, false)
	var distance_haze := clampf(horizon_haze, 0.0, 1.0)
	if mist <= 0.001 and rain_haze <= 0.001 and distance_haze <= 0.001:
		environment.fog_enabled = false
		return
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	var physical_fog := Color(0.0, 0.0, 0.0, 0.0)
	environment.fog_sun_scatter = FOG_SUN_SCATTER_CLEAR
	if presentation.atmosphere_available:
		# Mist and haze take the hue of the horizon the dome actually draws (LUT plus its
		# night floor); the sun-side glow comes from Godot's fog sun scatter, which already
		# uses the (physical) directional colour.
		physical_fog = (
			physical_hue(presentation.horizon_display_color, FOG_MORNING_COLOR) * FOG_ART_TINT
		)
		environment.fog_sun_scatter = lerpf(
			FOG_SUN_SCATTER_CLEAR, FOG_SUN_SCATTER_HAZY, clampf(mist + rain_haze, 0.0, 1.0)
		)
	environment.fog_light_color = ground_mist_light_color(
		presentation.day_blend, mist, rain_haze, physical_fog
	)
	environment.fog_sky_affect = 0.08
	environment.fog_aerial_perspective = 0.0
	environment.fog_density = (
		FOG_MAX_DENSITY * mist + 0.0035 * rain_haze + HORIZON_HAZE_DENSITY * distance_haze
	)
	environment.fog_height = FOG_HEIGHT
	environment.fog_height_density = FOG_MAX_HEIGHT_DENSITY * mist * (1.0 - rain_haze)


## 0..1 how damp the air is, from the same weather signals as the sky: overcast deck,
## falling rain and standing puddles (wet ground keeps giving moisture back after rain).
static func air_dampness(presentation: SkyWeather3D.WeatherPresentation) -> float:
	if presentation == null:
		return 0.0
	return clampf(
		presentation.overcast * 0.5
		+ presentation.rain_intensity * 0.45
		+ presentation.puddle_wetness * 0.65,
		0.0,
		1.0
	)


## 0..1 hot-weather shimmer: a high summer sun, little cloud, calm and dry air.
static func heat_amount(presentation: SkyWeather3D.WeatherPresentation) -> float:
	if presentation == null:
		return 0.0
	var heat := smoothstep(HEAT_SUN_MIN, HEAT_SUN_FULL, presentation.sun_direction.y)
	heat *= 1.0 - clampf(presentation.cloud_coverage * 1.3, 0.0, 1.0)
	heat *= 1.0 - clampf(presentation.wind_strength * 0.8, 0.0, 1.0)
	heat *= 1.0 - clampf(presentation.rain_intensity * 2.0, 0.0, 1.0)
	return heat


## 0..1 distance haze for perspective cameras, limited by the fog quality tier.
static func horizon_haze_amount(presentation: SkyWeather3D.WeatherPresentation) -> float:
	if presentation == null:
		return 0.0
	var haze := (
		HORIZON_HAZE_BASE
		+ HORIZON_HAZE_DAMP_WEIGHT * air_dampness(presentation)
		+ HORIZON_HAZE_HEAT_WEIGHT * heat_amount(presentation)
	)
	return clampf(haze, 0.0, 1.0) * clampf(presentation.fog_quality, 0.0, 1.0)


## 0..1 morning ground mist for this presentation: the dawn envelope scaled by the
## date's fog potential, dispersed by wind and limited by the fog quality tier.
static func ground_mist_amount(
	presentation: SkyWeather3D.WeatherPresentation, enclosed_interior: bool
) -> float:
	if presentation == null or enclosed_interior:
		return 0.0
	var hour := DayNightCycle.progress_to_hour(presentation.cycle_progress)
	var mist := morning_mist_factor(hour, presentation.sunrise_hour)
	mist *= smoothstep(FOG_POTENTIAL_MIN, FOG_POTENTIAL_FULL, presentation.fog_potential)
	var evening := evening_mist_factor(hour, presentation.sunset_hour)
	evening *= smoothstep(FOG_POTENTIAL_MIN, FOG_POTENTIAL_FULL, presentation.evening_fog_potential)
	mist = maxf(mist, evening * EVENING_FOG_STRENGTH)
	mist *= clampf(1.0 - presentation.wind_strength * 0.7, 0.0, 1.0)
	return mist * clampf(presentation.fog_quality, 0.0, 1.0)


## Rain adds atmospheric extinction even at noon. Calm, dry days stay haze-free,
## and shelter still excludes outdoor atmosphere.
static func ground_rain_haze(
	presentation: SkyWeather3D.WeatherPresentation, enclosed_interior: bool
) -> float:
	if presentation == null or enclosed_interior:
		return 0.0
	return presentation.rain_intensity * presentation.fog_quality


## Beer-Lambert transmittance of the direct sun/moon beam through mist and rain
## haze, used to gate water glints. `elevation_sin` is the light direction's y:
## a low sun crosses far more of the ground-mist layer than a high one.
static func glint_haze_transmittance(elevation_sin: float, mist: float, rain_haze: float) -> float:
	var depth := (
		GLINT_MIST_OPTICAL_DEPTH * clampf(mist, 0.0, 1.0)
		+ GLINT_RAIN_OPTICAL_DEPTH * clampf(rain_haze, 0.0, 1.0)
	)
	if depth <= 0.0:
		return 1.0
	var air_mass := 1.0 / maxf(elevation_sin, 1.0 / GLINT_HAZE_MAX_AIR_MASS)
	return exp(-depth * air_mass)


## Dry morning mist follows day_blend so night haze stays darker than night
## ambient. Rain-only haze keeps the previous pale-to-rain lerp (mist == 0).
## `physical_day_fog` (WS-11, alpha > 0 when set) replaces FOG_MORNING_COLOR as the day
## colour; the rain lerp stays on top so rain still reads as today's rain.
static func ground_mist_light_color(
	day_blend: float, mist: float, rain_haze: float, physical_day_fog: Color = Color(0, 0, 0, 0)
) -> Color:
	var blend := clampf(day_blend, 0.0, 1.0)
	var rain_color := Color8(34, 42, 58).lerp(Color8(145, 157, 168), blend)
	var day_fog := FOG_MORNING_COLOR if physical_day_fog.a <= 0.0 else physical_day_fog
	var dry_fog := day_fog
	if mist > 0.001:
		dry_fog = FOG_NIGHT_COLOR.lerp(day_fog, blend)
	return dry_fog.lerp(rain_color, clampf(rain_haze, 0.0, 1.0))


## Mist rises during the pre-dawn window and burns off after sunrise.
static func morning_mist_factor(hour: float, sunrise: float) -> float:
	var start := sunrise - FOG_HOURS_BEFORE_SUNRISE
	var stop := sunrise + FOG_HOURS_AFTER_SUNRISE
	if hour <= start or hour >= stop:
		return 0.0
	if hour < sunrise:
		return smoothstep(start, sunrise, hour)
	return 1.0 - smoothstep(sunrise, stop, hour)


## Evening mist gathers around sunset and thins before the small hours. Hours past
## midnight are read as 24+ so the envelope survives the day wrap.
static func evening_mist_factor(hour: float, sunset: float) -> float:
	var start := sunset - EVENING_FOG_HOURS_BEFORE_SUNSET
	var peak := start + EVENING_FOG_HOURS_RISE
	var hold_end := peak + EVENING_FOG_HOURS_HOLD
	var stop := hold_end + EVENING_FOG_HOURS_FADE
	var h := hour + 24.0 if hour < start - 12.0 else hour
	if h <= start or h >= stop:
		return 0.0
	if h < peak:
		return smoothstep(start, peak, h)
	if h <= hold_end:
		return 1.0
	return 1.0 - smoothstep(hold_end, stop, h)


## Godot exponential height fog at y=0 is 1-exp(-(fog_height-y)*height_density).
## Tests use this so peak dawn mist stays a veil instead of a solid sheet.
static func waterline_height_fog_cover(mist: float) -> float:
	var density := FOG_MAX_HEIGHT_DENSITY * clampf(mist, 0.0, 1.0)
	return 1.0 - exp(-FOG_HEIGHT * density)
