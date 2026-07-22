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
## identities readable.
const SUN_NIGHT_COLOR := Color8(142, 162, 210)
const SUN_NIGHT_ENERGY := 0.42
const AMBIENT_NIGHT_COLOR := Color8(52, 66, 100)
const AMBIENT_NIGHT_ENERGY := 0.5
const BACKGROUND_NIGHT_COLOR := Color8(12, 14, 22)

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
const FOG_POTENTIAL_MIN := 0.6
const FOG_POTENTIAL_FULL := 0.85


## Applies one complete celestial/weather lighting state and reports whether it
## belongs to the discrete night bucket used by chimney and window presentation.
static func apply_cycle_progress(
	progress: float,
	sun: DirectionalLight3D,
	environment: Environment,
	sky_weather: SkyWeather3D,
	interior_top_down: bool
) -> bool:
	var sun_direction := SkyWeather3D.solar_direction(progress, sky_weather.calendar_date)
	var day_blend := SkyWeather3D.daylight_blend(progress, sky_weather.calendar_date)
	var moon_direction := SkyWeather3D.lunar_direction(progress, sky_weather.calendar_date)
	var sun_elevation := SkyWeather3D.solar_elevation_degrees(
		progress,
		sky_weather.calendar_date
	)
	# DirectionalLight3D emits along local -Z. Twilight therefore hands the light
	# direction smoothly from the date-driven moon to the moving sun.
	var sun_light_weight := smoothstep(-6.0, 0.0, sun_elevation)
	var light_direction := moon_direction.slerp(sun_direction, sun_light_weight).normalized()
	sun.basis = Basis.looking_at(-light_direction, Vector3.UP)

	# Update the sky before reading its modifiers so lighting and the dome always
	# represent the same cycle point.
	sky_weather.apply_sky_state(progress, day_blend, sun_direction)
	var weather := sky_weather.lighting_modifiers()
	var sun_color := SUN_NIGHT_COLOR.lerp(SUN_DAY_COLOR, day_blend)
	sun_color = sun_color.lerp(SUNSET_LIGHT_COLOR, weather["sunset_tint"])
	sun_color = sun_color.lerp(OVERCAST_LIGHT_COLOR, weather["overcast"])
	sun.light_color = sun_color

	var moonlight := SkyWeather3D.moonlight_strength(progress, sky_weather.calendar_date)
	var celestial_energy := lerpf(SUN_NIGHT_ENERGY * moonlight, SUN_DAY_ENERGY, day_blend)
	var lightning := float(weather.get("lightning", 0.0))
	sun.light_energy = celestial_energy * weather["sun_energy"] + lightning * LIGHTNING_SUN_ENERGY
	# Grey overcast diffuses hard shadows; clear skies retain their crisp baseline.
	sun.shadow_opacity = clampf(1.0 - float(weather["overcast"]) * 0.85, 0.12, 1.0)

	var ambient := AMBIENT_NIGHT_COLOR.lerp(AMBIENT_DAY_COLOR, day_blend)
	ambient = ambient.lerp(OVERCAST_LIGHT_COLOR, weather["overcast"] * 0.5)
	ambient = ambient.lerp(LIGHTNING_LIGHT_COLOR, lightning * 0.7)
	environment.ambient_light_color = ambient
	environment.ambient_light_energy = (
		lerpf(AMBIENT_NIGHT_ENERGY, AMBIENT_DAY_ENERGY, day_blend) * weather["ambient_energy"]
		+ lightning * LIGHTNING_AMBIENT_ENERGY
	)
	environment.background_color = BACKGROUND_NIGHT_COLOR.lerp(BACKGROUND_DAY_COLOR, day_blend)
	sync_background(environment, interior_top_down)
	apply_ground_mist(environment, sky_weather, progress, interior_top_down)

	# Water specular follows the visible sun disk rather than civil-twilight light,
	# preventing a sun glint after the disk has set.
	MapViewMaterials.apply_water_lighting(
		SkyWeather3D.sun_disk_visibility(sun_direction),
		day_blend
	)
	var cloud_occlusion := 1.0 - sky_weather.cloud_coverage()
	var sun_reflection_color := SUN_DAY_COLOR.lerp(SUNSET_LIGHT_COLOR, weather["sunset_tint"])
	MapViewMaterials.apply_water_sky_reflection(
		sky_weather.star_map_texture(),
		sun_direction,
		moon_direction,
		SkyWeather3D.sun_disk_visibility(sun_direction) * cloud_occlusion,
		moonlight * cloud_occlusion,
		pow(1.0 - day_blend, 3.0) * cloud_occlusion,
		deg_to_rad(SkyWeather3D.OBSERVER_LATITUDE_DEGREES),
		SkyWeather3D.sidereal_angle_for_progress(progress),
		sun_reflection_color
	)
	return day_blend < 0.5


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
## indoors. The date-based potential keeps fog occasional rather than universal.
static func apply_ground_mist(
	environment: Environment,
	sky_weather: SkyWeather3D,
	progress: float,
	interior_top_down: bool
) -> void:
	if environment == null:
		return
	if interior_top_down:
		environment.fog_enabled = false
		return
	var hour := DayNightCycle.progress_to_hour(progress)
	var sunrise := float(SkyWeather3D.sunrise_sunset_hours(sky_weather.calendar_date)["sunrise"])
	var mist := morning_mist_factor(hour, sunrise)
	mist *= smoothstep(
		FOG_POTENTIAL_MIN,
		FOG_POTENTIAL_FULL,
		SkyWeather3D.morning_fog_potential(sky_weather.calendar_date)
	)
	mist *= clampf(1.0 - sky_weather.wind_strength() * 0.7, 0.0, 1.0)
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
