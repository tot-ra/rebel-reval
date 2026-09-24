extends RefCounted

const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")
const WaterMaterials := preload("res://scripts/map/view3d/map_view_water_materials.gd")


## Mirrors the lighting-path water fan-out so R-715 tests can drive cached water
## uniforms from one WeatherPresentation without duplicating call order drift.
static func apply_weather_presentation(
	presentation: SkyWeather.WeatherPresentation, wave_profiles: Dictionary
) -> void:
	if presentation == null:
		return
	WaterMaterials.apply_sea_weather(
		presentation.wind_strength,
		presentation.rain_intensity,
		wave_profiles,
		presentation.wind_direction,
	)
	WaterMaterials.apply_water_lighting(
		presentation.sun_visibility, presentation.day_blend, wave_profiles
	)
	WaterMaterials.apply_coastal_tide(presentation.tide_level, wave_profiles)
	WaterMaterials.apply_water_sky_reflection(
		presentation.star_map,
		presentation.sun_direction,
		presentation.moon_direction,
		presentation.sun_visibility * (1.0 - presentation.cloud_coverage),
		presentation.moon_visibility,
		presentation.star_visibility,
		deg_to_rad(SkyWeather.OBSERVER_LATITUDE_DEGREES),
		presentation.sidereal_angle,
		presentation.sun_reflection_color,
		wave_profiles
	)
