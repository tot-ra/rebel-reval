extends "res://tests/godot/test_case.gd"

## R-1748: screen-space AO pass for the Mobile renderer (docs/SYSTEMS/POST_PROCESS.md).

const AoPass := preload("res://scripts/map/view3d/ambient_occlusion_pass.gd")
const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")
const GraphicsPresetsScript := preload("res://scripts/settings/graphics_presets.gd")


func _presentation(day_blend: float, overcast: float) -> SkyWeather.WeatherPresentation:
	var p := SkyWeather.WeatherPresentation.new()
	p.day_blend = day_blend
	p.overcast = overcast
	return p


func test_strength_is_softer_in_sun_than_in_diffuse_light_and_lowest_at_night() -> void:
	var night := AoPass.strength_for(_presentation(0.0, 0.0))
	var sunny := AoPass.strength_for(_presentation(1.0, 0.0))
	var overcast := AoPass.strength_for(_presentation(1.0, 1.0))
	assert_true(night > 0.0, "lamplit streets keep some AO")
	assert_true(night < sunny, "night below sunlit day")
	assert_true(sunny < overcast, "direct sun greys corners, so it gets less AO than diffuse light")
	assert_eq(AoPass.strength_for(null), 0.0)


func test_low_quality_turns_the_pass_off_and_mid_turns_it_on() -> void:
	var ao := AoPass.new()
	ao.configure()
	ao.update(_presentation(1.0, 0.0))
	ao.apply_quality(GraphicsPresetsScript.LOW)
	assert_false(ao.is_active(), "low preset has no AO taps")
	ao.apply_quality(GraphicsPresetsScript.MID)
	assert_true(ao.is_active(), "mid preset draws AO")
	ao.set_enabled(false)
	assert_false(ao.is_active(), "capture toggle hides it")
	ao.free()


func test_pass_draws_before_cloud_shadows_and_water() -> void:
	assert_true(AoPass.RENDER_PRIORITY < -100, "before CloudShadowPass and the water's screen copy")
