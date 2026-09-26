extends "res://tests/godot/test_case.gd"

## R-955 / CO-08: wind heading, Beaufort Hs ladder, whitecap onset, fetch shelter.

const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")
const SkyWeatherState := preload("res://scripts/map/view3d/sky_weather_state.gd")
const WaterMaterials := preload("res://scripts/map/view3d/map_view_water_materials.gd")
const BoatFloat := preload("res://scripts/map/view3d/boat_float_3d.gd")

const NOON := 0.25


func test_wind_direction_is_not_the_cloud_drift_constant() -> void:
	var cloudy := SkyWeather.wind_direction_at(SkyWeather.WEATHER_CLOUDY, NOON)
	var storm := SkyWeather.wind_direction_at(SkyWeather.WEATHER_STORM, NOON)
	var rain := SkyWeather.wind_direction_at(SkyWeather.WEATHER_RAIN, NOON)
	var clear := SkyWeather.wind_direction_at(SkyWeather.WEATHER_CLEAR, NOON)
	assert_true(
		clear.is_equal_approx(SkyWeather.CLOUD_DRIFT_PER_SECOND.normalized()),
		"clear noon keeps the historical harbour bearing"
	)
	assert_true(cloudy.distance_to(clear) > 0.3, "cloudy must veer off the constant")
	assert_true(storm.distance_to(clear) > 0.3, "storm must veer off the constant")
	assert_true(rain.distance_to(storm) > 0.3, "rain and storm use different quarters")


func test_wind_direction_veers_over_the_day_and_stays_deterministic() -> void:
	var dawn := SkyWeather.wind_direction_at(SkyWeather.WEATHER_CLEAR, 0.0)
	var noon := SkyWeather.wind_direction_at(SkyWeather.WEATHER_CLEAR, NOON)
	var dusk := SkyWeather.wind_direction_at(SkyWeather.WEATHER_CLEAR, 0.5)
	assert_true(dawn.distance_to(noon) > 0.15, "midnight veers off noon")
	assert_true(dusk.distance_to(noon) > 0.15, "dusk veers off noon")
	assert_true(
		dawn.is_equal_approx(SkyWeather.wind_direction_at(SkyWeather.WEATHER_CLEAR, 0.0)),
		"heading is a pure function of weather and clock"
	)


func test_presenter_matches_static_heading_and_survives_restore() -> void:
	var sky := SkyWeather.new()
	sky.auto_weather = false
	sky.set_weather(SkyWeather.WEATHER_STORM)
	sky.advance(SkyWeather.TRANSITION_SECONDS)
	var live := sky.presentation_snapshot(0.42, 0.7)
	var expected := SkyWeather.wind_direction_at(SkyWeather.WEATHER_STORM, 0.42)
	assert_true(live.wind_direction.is_equal_approx(expected), "snapshot uses the live heading")
	var state := sky.snapshot_state(0.42, 3)
	var restored := SkyWeather.new()
	assert_true(restored.restore_state(state), "weather snapshot must apply")
	var again := restored.presentation_snapshot(0.42, 0.7)
	assert_true(
		again.wind_direction.is_equal_approx(live.wind_direction),
		"save/load must reconstruct the same heading"
	)
	sky.free()
	restored.free()


func test_cloud_drift_follows_the_live_heading() -> void:
	var sky := SkyWeather.new()
	sky.auto_weather = false
	sky.set_weather(SkyWeather.WEATHER_RAIN)
	sky.advance(SkyWeather.TRANSITION_SECONDS)
	var before_state := sky.snapshot_state(NOON) as SkyWeatherState
	var before := before_state.cloud_offset
	sky.advance(1.0)
	var after_state := sky.snapshot_state(NOON) as SkyWeatherState
	var after := after_state.cloud_offset
	var delta := (after - before).normalized()
	assert_true(
		delta.dot(sky.wind_direction_xz()) > 0.99,
		"cloud banks drift down the same heading as the sea"
	)
	sky.free()


func test_beaufort_hs_is_monotonic_and_matches_documented_knots() -> void:
	var previous_hs := -1.0
	var previous_force := -1.0
	for row: Dictionary in WaterMaterials.BEAUFORT_LADDER:
		var rung := WaterMaterials.beaufort_at(float(row["sea_state"]))
		assert_almost_eq(float(rung["hs_m"]), float(row["hs_m"]), 0.001, String(row["label"]))
		assert_true(float(rung["hs_m"]) >= previous_hs, "Hs must not fall as force rises")
		assert_true(float(rung["beaufort"]) >= previous_force, "Beaufort must not fall")
		previous_hs = float(rung["hs_m"])
		previous_force = float(rung["beaufort"])
	assert_almost_eq(WaterMaterials.significant_wave_height_m(0.20, 0.0), 0.16, 0.001)
	assert_almost_eq(WaterMaterials.significant_wave_height_m(0.52, 0.0), 1.36, 0.001)
	assert_almost_eq(WaterMaterials.significant_wave_height_m(0.70, 0.22), 3.01, 0.02)
	assert_almost_eq(WaterMaterials.significant_wave_height_m(0.92, 1.0), 3.48, 0.02)


func test_whitecap_onset_starts_at_force_four() -> void:
	var calm := WaterMaterials.fft_sea_state(0.20, 0.0)
	var breeze := WaterMaterials.fft_sea_state(0.35, 0.0)
	var cloudy := WaterMaterials.fft_sea_state(0.52, 0.0)
	assert_almost_eq(float(calm["whitecap_onset"]), 0.0, 0.001, "force 2 has no whitecaps")
	assert_almost_eq(float(breeze["whitecap_onset"]), 0.0, 0.001, "force 3 has no whitecaps")
	assert_almost_eq(float(cloudy["whitecap_onset"]), 1.0, 0.001, "force 4 opens whitecaps")
	assert_eq(WaterMaterials.WHITECAP_ONSET_BEAUFORT, 4)


func test_hull_motion_reads_the_shared_ladder() -> void:
	var calm := WaterMaterials.hull_motion_scale(0.20, 0.0)
	var rain := WaterMaterials.hull_motion_scale(0.92, 1.0)
	assert_almost_eq(calm, 0.55, 0.01, "calm Hs maps to the historical floor")
	assert_almost_eq(rain, 1.45, 0.01, "rain Hs maps to the historical ceiling")
	assert_true(calm < rain, "hulls move more in a higher sea")


func test_fetch_shelter_cuts_lee_amplitude() -> void:
	var open := OceanFftSampler.fetch_shelter_scale(20.0, 20.0)
	var lee := OceanFftSampler.fetch_shelter_scale(20.0, -2.0)
	var basin := OceanFftSampler.fetch_shelter_scale(0.4, 20.0)
	assert_almost_eq(open, 1.0, 0.001, "open fetch stays full")
	assert_true(lee < 0.5, "upwind land shelters the sea")
	assert_true(basin < 0.5, "a tight basin is calmer than open water")
	assert_true(lee < open and basin < open)


func test_fft_hull_lee_is_calmer_than_open_water() -> void:
	assert_true(OceanFftSampler.ensure_loaded(), "FFT atlas must decode")
	OceanFftSampler.reset_sea_state()
	OceanFftSampler.set_time_override(4.0)
	var open := BoatFloat.sample_fft_hull_attitude(
		Vector2(40.0, 40.0),
		4.0,
		1.4,
		0.45,
		Basis.IDENTITY,
		OceanFftSampler.PHYSICAL_SURFACE,
		1,
		Callable(),
		func(_p: Vector2) -> float: return 20.0
	)
	var origin := Vector2(40.0, 40.0)
	var lee := BoatFloat.sample_fft_hull_attitude(
		origin,
		4.0,
		1.4,
		0.45,
		Basis.IDENTITY,
		OceanFftSampler.PHYSICAL_SURFACE,
		1,
		Callable(),
		func(p: Vector2) -> float:
			var wind_axis: Vector2 = OceanFftSampler.sea_state()["wind_axis"]
			var probe := origin - wind_axis * OceanFftSampler.FETCH_PROBE_UNITS
			return -4.0 if p.distance_to(probe) < 3.0 else 20.0
	)
	assert_true(
		absf(lee.x) < absf(open.x) + 0.00001,
		"a quay to windward must cut heave"
	)
	OceanFftSampler.clear_time_override()
	OceanFftSampler.reset_sea_state()
