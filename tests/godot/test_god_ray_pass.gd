extends "res://tests/godot/test_case.gd"

const GodRayPass := preload("res://scripts/map/view3d/god_ray_pass.gd")
const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")


func _presentation(sun_y: float, clear: float, coverage: float) -> SkyWeather.WeatherPresentation:
	var p := SkyWeather.WeatherPresentation.new()
	p.sun_direction = Vector3(0.0, sun_y, -1.0).normalized()
	p.sun_visibility = 1.0 if sun_y > 0.0 else 0.0
	p.sun_cloud_clear = clear
	p.cloud_coverage = coverage
	p.moon_direction = Vector3.DOWN
	return p


func test_low_sun_through_broken_cloud_beats_high_sun_clear_sky() -> void:
	var low := GodRayPass.light_strength(_presentation(0.15, 1.0, 0.5))
	var high := GodRayPass.light_strength(_presentation(0.95, 1.0, 0.0))
	assert_true(low > high, "low sun in broken cloud must show stronger rays than clear noon")


func test_fog_and_rain_haze_raise_the_scatter() -> void:
	var dry := _presentation(0.2, 1.0, 0.0)
	var wet := _presentation(0.2, 1.0, 0.0)
	wet.rain_intensity = 1.0
	assert_true(GodRayPass.haze_amount(wet) > GodRayPass.haze_amount(dry))


func test_no_rays_at_night_without_moon_or_when_sun_is_blocked() -> void:
	var night := _presentation(-0.5, 1.0, 0.5)
	assert_eq(GodRayPass.light_strength(night), 0.0)
	assert_eq(GodRayPass.light_strength(_presentation(0.2, 0.0, 0.5)), 0.0)


func test_moonlight_rays_are_fainter_than_sunlight() -> void:
	var night := _presentation(-0.5, 1.0, 0.5)
	night.lunar_light_strength = 1.0
	night.moon_cloud_clear = 1.0
	night.moon_direction = Vector3(0.0, 0.4, -1.0).normalized()
	var moon := GodRayPass.light_strength(night)
	assert_true(moon > 0.0)
	assert_true(moon < GodRayPass.light_strength(_presentation(0.2, 1.0, 0.5)))
	assert_false(GodRayPass.uses_sun(night))


func test_not_created_indoors() -> void:
	assert_false(GodRayPass.should_create(true))
	assert_true(GodRayPass.should_create(false))
