class_name PlantMaterial
extends RefCounted
## R-2131: sole writer of the plant_weather_g / plant_season_g shader globals read
## by plant_common.gdshaderinc. Globals, not per-material uniforms, so every plant
## shader follows the weather without a fan-out and without new samplers.

const WEATHER_GLOBAL := &"plant_weather_g"
const SEASON_GLOBAL := &"plant_season_g"

static var _weather := Vector4.ZERO
static var _season := Vector4.ZERO


## wetness: rain and puddles, frost: freezing air or dew, snow: lying snow cover,
## drought: dry-summer wilting. All 0..1; quantised to keep the writes rare.
static func set_weather(wetness: float, frost: float, snow: float, drought: float) -> void:
	var value := Vector4(
		snappedf(clampf(wetness, 0.0, 1.0), 0.02),
		snappedf(clampf(frost, 0.0, 1.0), 0.02),
		snappedf(clampf(snow, 0.0, 1.0), 0.02),
		snappedf(clampf(drought, 0.0, 1.0), 0.02)
	)
	if value.is_equal_approx(_weather):
		return
	_weather = value
	RenderingServer.global_shader_parameter_set(WEATHER_GLOBAL, value)


## Autumn progress 0..1 from the date's season weights; winter stays browned off.
static func set_season(date: Dictionary) -> void:
	var weights := SeasonState.season_weights(SeasonState.day_of_year_for(date))
	var autumn := clampf(
		float(weights[SeasonState.AUTUMN]) + float(weights[SeasonState.WINTER]), 0.0, 1.0
	)
	var value := Vector4(autumn, 0.0, 0.0, 0.0)
	if value.is_equal_approx(_season):
		return
	_season = value
	RenderingServer.global_shader_parameter_set(SEASON_GLOBAL, value)
