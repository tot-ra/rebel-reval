extends "res://tests/godot/test_case.gd"

## R-1482 aerial perspective: haze hue and clarity by hour and weather, the widened heat
## gate, distance curves, and when the full-screen pass is allowed to draw.

const Aerial := preload("res://scripts/map/view3d/aerial_perspective_pass.gd")
const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")


func _presentation(sun_y: float = 0.5) -> SkyWeather.WeatherPresentation:
	var p := SkyWeather.WeatherPresentation.new()
	p.sun_direction = Vector3(0.0, sun_y, -sqrt(maxf(1.0 - sun_y * sun_y, 0.0)))
	p.moon_direction = Vector3.DOWN
	p.sun_visibility = 1.0 if sun_y > 0.0 else 0.0
	p.sun_cloud_clear = 1.0
	p.day_blend = 1.0 if sun_y > 0.0 else 0.0
	p.cloud_coverage = 0.3
	p.wind_strength = 0.2
	return p


func _blueness(color: Color) -> float:
	return color.b - color.r


func test_haze_is_blue_at_noon_warm_at_low_sun_and_dark_at_night() -> void:
	var noon := Aerial.haze_color_for(_presentation(0.7))
	assert_true(_blueness(noon) > 0.1, "clear noon air reads blue: %s" % noon)
	var evening := _presentation(0.08)
	evening.sunset_factor = 1.0
	evening.physical_sun_color = Color(1.0, 0.6, 0.3)
	var warm := Aerial.haze_color_for(evening)
	assert_true(_blueness(warm) < _blueness(noon), "golden hour warms the haze: %s" % warm)
	var night := Aerial.haze_color_for(_presentation(-0.3))
	assert_true(night.get_luminance() < noon.get_luminance() * 0.4, "night haze is dark")
	assert_true(Aerial.haze_max_for(_presentation(-0.3)) < Aerial.haze_max_for(_presentation(0.7)))


func test_rain_greys_the_haze() -> void:
	var rain := _presentation(0.5)
	rain.rain_intensity = 1.0
	rain.overcast = 0.75
	var grey := Aerial.haze_color_for(rain)
	assert_true(absf(_blueness(grey)) < 0.1, "rain haze is grey: %s" % grey)


func test_washed_windy_air_is_clearer_than_humid_or_hot_air() -> void:
	var base := Aerial.haze_density_for(_presentation(0.5))
	var washed := _presentation(0.5)
	washed.puddle_wetness = 1.0
	washed.wind_strength = 0.8
	assert_true(Aerial.haze_density_for(washed) < base * 0.8, "after rain the air is crisp")
	var humid := _presentation(0.5)
	humid.overcast = 0.75
	assert_true(Aerial.haze_density_for(humid) > base * 1.3, "damp overcast air is thick")
	var raining := _presentation(0.5)
	raining.rain_intensity = 1.0
	assert_true(Aerial.haze_density_for(raining) > Aerial.haze_density_for(humid))
	var hot := _presentation(0.8)
	assert_true(Aerial.haze_density_for(hot) > base, "hot still air is hazier")


func test_heat_shimmer_on_warm_sunny_middays_only() -> void:
	assert_true(Aerial.heat_amount(_presentation(0.8)) > 0.6, "midsummer noon shimmers")
	assert_true(Aerial.heat_amount(_presentation(0.77)) > 0.4, "a May noon shimmers too")
	assert_true(Aerial.heat_amount(_presentation(0.68)) < 0.05, "April noon is too cold")
	var cloudy := _presentation(0.8)
	cloudy.cloud_coverage = 0.95
	assert_eq(Aerial.heat_amount(cloudy), 0.0, "a full sky stops it")
	var rainy := _presentation(0.8)
	rainy.rain_intensity = 0.6
	assert_eq(Aerial.heat_amount(rainy), 0.0, "rain stops it")
	var wet := _presentation(0.8)
	wet.puddle_wetness = 1.0
	assert_eq(Aerial.heat_amount(wet), 0.0, "wet ground stays cool")
	assert_true(Aerial.shimmer_pixels_for(_presentation(0.8)) > 1.5)


func test_near_stays_sharp_and_far_softens() -> void:
	var density := Aerial.HAZE_DENSITY_CLEAR
	assert_eq(Aerial.haze_factor(10.0, density), 0.0, "the player's street is untinted")
	assert_eq(Aerial.blur_factor(10.0), 0.0, "the player's street is sharp")
	assert_true(Aerial.haze_factor(300.0, density) > 0.1)
	assert_true(Aerial.haze_factor(1000.0, density) > Aerial.haze_factor(300.0, density))
	assert_true(Aerial.haze_factor(100000.0, density) <= Aerial.HAZE_MAX + 1e-5, "capped")
	assert_true(Aerial.blur_factor(200.0) > 0.0)
	assert_almost_eq(Aerial.blur_factor(Aerial.BLUR_FULL), 1.0, 1e-5)


func test_minimum_quality_tier_skips_blur_and_shimmer() -> void:
	var low := _presentation(0.8)
	low.fog_quality = 0.65
	assert_eq(Aerial.blur_pixels_for(low), 0.0)
	assert_eq(Aerial.shimmer_pixels_for(low), 0.0)
	assert_true(Aerial.haze_density_for(low) > 0.0, "haze still draws, scaled down")
	assert_true(Aerial.blur_pixels_for(_presentation(0.5)) > 0.0)


func test_pass_draws_only_for_an_active_perspective_camera_outdoors() -> void:
	assert_false(Aerial.should_create(true))
	var tree := Engine.get_main_loop() as SceneTree
	var camera := Camera3D.new()
	tree.root.add_child(camera)
	camera.make_current()
	var first := Aerial.new()
	tree.root.add_child(first)
	first.configure(camera)
	var second := Aerial.new()
	tree.root.add_child(second)
	second.configure(camera)
	first.update(_presentation(0.5))
	second.update(_presentation(0.5))
	assert_true(first.overlay_visible(), "perspective outdoors draws")
	assert_false(second.overlay_visible(), "a hosted neighbour on the same viewport does not")
	first.update(_presentation(0.5), false)
	assert_false(first.overlay_visible(), "roofed rooms keep the weather outside")
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	first.update(_presentation(0.5))
	assert_false(first.overlay_visible(), "the orthographic overview gets no haze pass")
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	first.suppressed = true
	first.update(_presentation(0.5))
	assert_false(first.overlay_visible(), "review tools can hide it")
	first.free()
	second.free()
	camera.free()
