class_name MapViewLighting
extends RefCounted

## Deterministic outdoor lighting and atmosphere for MapView3D. This module owns
## the visual day/night response so the view node can focus on scene assembly,
## streaming, actor projection, and occlusion while retaining its public API.

const DayNightCycle := preload("res://scripts/global/day_night_cycle.gd")

const SUN_DAY_COLOR := Color8(255, 243, 222)
const SUN_DAY_ENERGY := 1.2
const AMBIENT_DAY_COLOR := Color8(168, 178, 189)
const AMBIENT_DAY_ENERGY := 0.85
const BACKGROUND_DAY_COLOR := Color8(31, 30, 28)

## Top-down interior gameplay hides the ceiling; a flat black clear color keeps
## the room readable instead of letting the outdoor sky dome show through.
const BACKGROUND_INTERIOR_TOP_DOWN_COLOR := Color.BLACK

## Night stays at least 20% darker than day while ambient light keeps terrain
## identities readable. Calibration after ADR 0018 raised fill so indigo ambient
## and local albedo survive outside fire/window pools instead of crushing to black.
const SUN_NIGHT_COLOR := Color8(142, 162, 210)
const SUN_NIGHT_ENERGY := 0.72
const AMBIENT_NIGHT_COLOR := Color8(58, 74, 112)
const AMBIENT_NIGHT_ENERGY := 0.92
const BACKGROUND_NIGHT_COLOR := Color8(14, 18, 28)

## Golden-hour and weather tints blended over the day/night baseline.
const SUNSET_LIGHT_COLOR := Color8(255, 148, 64)
const OVERCAST_LIGHT_COLOR := Color8(172, 182, 196)
const LIGHTNING_LIGHT_COLOR := Color8(206, 220, 255)
const LIGHTNING_SUN_ENERGY := 1.6
const LIGHTNING_AMBIENT_ENERGY := 0.9

## Morning ground mist uses basic height-biased fog because the GL Compatibility
## renderer has no volumetric fog.
const FOG_MORNING_COLOR := Color8(200, 210, 220)
const FOG_MAX_DENSITY := 0.018
const FOG_HEIGHT := 3.5
const FOG_MAX_HEIGHT_DENSITY := 1.1
const FOG_HOURS_BEFORE_SUNRISE := 3.0
const FOG_HOURS_AFTER_SUNRISE := 2.5
## Raising the onset from 0.6 to 0.8 cuts eligible mornings from roughly two in
## five to one in five while preserving the strongest deterministic fog days.
const FOG_POTENTIAL_MIN := 0.8
const FOG_POTENTIAL_FULL := 0.95

## ADR 0018 saturated HDR-range post-grade. AgX compresses scene-referred values
## for the current SDR output; this does not claim HDR10 or wide-gamut delivery.
## Visual calibration tuned day exposure/glow so windows keep texture through AgX
## and night fill/chroma so local color remains readable outside emissive pools.
const TONEMAP_MODE := Environment.TONE_MAPPER_AGX
const GRADE_DAY_EXPOSURE := 0.98
const GRADE_DAY_SATURATION := 1.20
const GRADE_DAY_CONTRAST := 1.12
const GRADE_DAY_BRIGHTNESS := 1.03
const GRADE_NIGHT_EXPOSURE := 0.90
const GRADE_NIGHT_SATURATION := 1.14
const GRADE_NIGHT_CONTRAST := 1.08
const GRADE_NIGHT_BRIGHTNESS := 0.89
const GLOW_HDR_THRESHOLD := 1.05
const GLOW_INTENSITY_DAY := 0.32
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
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
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
	# DirectionalLight3D emits along local -Z. Twilight therefore hands the light
	# direction smoothly from the date-driven moon to the moving sun.
	var sun_light_weight := smoothstep(
		-6.0,
		0.0,
		rad_to_deg(asin(clampf(presentation.sun_direction.y, -1.0, 1.0)))
	)
	var light_direction := presentation.moon_direction.slerp(
		presentation.sun_direction, sun_light_weight
	).normalized()
	sun.basis = Basis.looking_at(-light_direction, Vector3.UP)
	var sun_color := SUN_NIGHT_COLOR.lerp(SUN_DAY_COLOR, presentation.day_blend)
	sun_color = sun_color.lerp(SUNSET_LIGHT_COLOR, presentation.sunset_tint)
	sun_color = sun_color.lerp(OVERCAST_LIGHT_COLOR, presentation.overcast)
	sun.light_color = sun_color

	var celestial_energy := lerpf(
		SUN_NIGHT_ENERGY * presentation.lunar_light_strength,
		SUN_DAY_ENERGY,
		presentation.day_blend
	)
	sun.light_energy = (
		celestial_energy * presentation.sun_energy
		+ presentation.lightning * LIGHTNING_SUN_ENERGY
	)
	# Grey overcast diffuses hard shadows; clear skies retain their crisp baseline.
	sun.shadow_opacity = clampf(1.0 - presentation.overcast * 0.85, 0.12, 1.0)

	var ambient := AMBIENT_NIGHT_COLOR.lerp(AMBIENT_DAY_COLOR, presentation.day_blend)
	ambient = ambient.lerp(OVERCAST_LIGHT_COLOR, presentation.overcast * 0.5)
	ambient = ambient.lerp(LIGHTNING_LIGHT_COLOR, presentation.lightning * 0.7)
	environment.ambient_light_color = ambient
	environment.ambient_light_energy = (
		lerpf(AMBIENT_NIGHT_ENERGY, AMBIENT_DAY_ENERGY, presentation.day_blend)
		* presentation.ambient_energy
		+ presentation.lightning * LIGHTNING_AMBIENT_ENERGY
	)
	environment.background_color = BACKGROUND_NIGHT_COLOR.lerp(
		BACKGROUND_DAY_COLOR, presentation.day_blend
	)
	sync_background(environment, interior_top_down)
	apply_ground_mist(environment, presentation, enclosed_interior)

	# Water specular follows the visible sun disk rather than civil-twilight light,
	# preventing a sun glint after the disk has set.
	MapViewMaterials.apply_water_lighting(presentation.sun_visibility, presentation.day_blend)
	MapViewMaterials.apply_coastal_tide(presentation.tide_level)
	MapViewMaterials.apply_water_sky_reflection(
		presentation.star_map,
		presentation.sun_direction,
		presentation.moon_direction,
		presentation.sun_visibility * (1.0 - presentation.cloud_coverage),
		presentation.moon_visibility,
		presentation.star_visibility,
		deg_to_rad(SkyWeather3D.OBSERVER_LATITUDE_DEGREES),
		presentation.sidereal_angle,
		presentation.sun_reflection_color
	)
	apply_post_grade_snapshot(environment, presentation)
	return presentation.day_blend < 0.5


static func apply_post_grade_snapshot(
	environment: Environment, presentation: SkyWeather3D.WeatherPresentation
) -> void:
	if presentation == null:
		return
	apply_post_grade(environment, presentation.day_blend)


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
	enclosed_interior: bool
) -> void:
	if environment == null or presentation == null:
		return
	if enclosed_interior:
		environment.fog_enabled = false
		return
	var hour := DayNightCycle.progress_to_hour(presentation.cycle_progress)
	var mist := morning_mist_factor(hour, presentation.sunrise_hour)
	mist *= smoothstep(
		FOG_POTENTIAL_MIN,
		FOG_POTENTIAL_FULL,
		presentation.fog_potential
	)
	mist *= clampf(1.0 - presentation.wind_strength * 0.7, 0.0, 1.0)
	mist *= clampf(presentation.fog_quality, 0.0, 1.0)
	if mist <= 0.001:
		environment.fog_enabled = false
		return
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	environment.fog_light_color = FOG_MORNING_COLOR
	environment.fog_sun_scatter = 0.2
	environment.fog_sky_affect = 0.08
	environment.fog_aerial_perspective = 0.0
	environment.fog_density = FOG_MAX_DENSITY * mist
	environment.fog_height = FOG_HEIGHT
	environment.fog_height_density = FOG_MAX_HEIGHT_DENSITY * mist


## Mist rises during the pre-dawn window and burns off after sunrise.
static func morning_mist_factor(hour: float, sunrise: float) -> float:
	var start := sunrise - FOG_HOURS_BEFORE_SUNRISE
	var stop := sunrise + FOG_HOURS_AFTER_SUNRISE
	if hour <= start or hour >= stop:
		return 0.0
	if hour < sunrise:
		return smoothstep(start, sunrise, hour)
	return 1.0 - smoothstep(sunrise, stop, hour)
