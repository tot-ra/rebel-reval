extends "res://tests/godot/test_case.gd"

## ADR 0045 snowfall: precipitation turns to snow by date, snow does not fill
## puddles, and the emitter picks fine / flakes / heavy from intensity and wind.

const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")
const Snowfall := preload("res://scripts/map/view3d/snowfall_3d.gd")
const JANUARY := {"day": 15, "month": 1, "year": 1343}


func _raining_sky(date: Dictionary) -> Node:
	var sky = SkyWeather.new()
	sky.auto_weather = false
	sky.set_calendar_date(date)
	sky.set_weather(SkyWeather.WEATHER_RAIN)
	sky.advance(SkyWeather.TRANSITION_SECONDS + 1.0)
	return sky


func test_winter_precipitation_is_snow() -> void:
	var sky := _raining_sky(JANUARY)
	assert_true(sky.precipitation_snow_share() > 0.9)
	assert_true(sky.snow_emitter_visible(), "winter rain state must snow")
	sky.rain_suppressed = true
	assert_false(sky.snow_emitter_visible(), "a roofed interior must not snow indoors")
	sky.free()


func test_spring_precipitation_is_rain() -> void:
	var sky := _raining_sky(GameCalendar.DEFAULT_DATE)
	assert_almost_eq(sky.precipitation_snow_share(), 0.0, 0.001)
	assert_false(sky.snow_emitter_visible())
	sky.free()


func test_snow_does_not_fill_puddles() -> void:
	var sky := _raining_sky(JANUARY)
	sky.advance(120.0)
	assert_eq(sky.puddle_wetness(), 0.0, "snow lies on the ground instead of pooling")
	sky.free()


func test_kind_follows_intensity_and_wind() -> void:
	assert_eq(Snowfall.kind_for(0.2, 0.1), Snowfall.KIND_FINE)
	assert_eq(Snowfall.kind_for(0.5, 0.2), Snowfall.KIND_FLAKES)
	assert_eq(Snowfall.kind_for(0.9, 0.5), Snowfall.KIND_HEAVY)
	assert_eq(Snowfall.kind_for(0.3, 0.8), Snowfall.KIND_HEAVY, "a gale makes it a blizzard")


func test_emitter_changes_look_and_stays_in_budget() -> void:
	var snow := Snowfall.new()
	snow.configure(700)
	snow.update_snowfall(0.2, 0.1, Vector2.ZERO, 1.0)
	assert_eq(snow.kind, Snowfall.KIND_FINE)
	var fine_lifetime: float = snow.lifetime
	snow.update_snowfall(0.95, 0.6, Vector2(0.3, 0.0), 1.0)
	assert_eq(snow.kind, Snowfall.KIND_HEAVY)
	assert_true(snow.lifetime < fine_lifetime, "heavy snow falls faster, so lives shorter")
	assert_true(snow.amount_ratio <= 1.0 and snow.amount == 700)
	snow.free()
