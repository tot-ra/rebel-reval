extends "res://tests/godot/test_case.gd"

const BoatFloat := preload("res://scripts/map/view3d/boat_float_3d.gd")
const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")


func test_boat_props_attach_float_controllers() -> void:
	var fishing := MapViewMeshBuilder.build_prop(
		{
			"id": &"float_fishing",
			"kind": MapTypes.PROP_KIND_FISHING_BOAT,
			"position": Vector2.ZERO,
		},
		MapTypes.DEFAULT_CELL_SIZE
	)
	var merchant := MapViewMeshBuilder.build_prop(
		{
			"id": &"float_merchant",
			"kind": MapTypes.PROP_KIND_MERCHANT_BOAT,
			"position": Vector2.ZERO,
		},
		MapTypes.DEFAULT_CELL_SIZE
	)
	assert_true(fishing.has_node("BoatFloat"), "fishing boats must ride the harbor wave field")
	assert_true(merchant.has_node("BoatFloat"), "merchant cogs must ride the harbor wave field")
	fishing.free()
	merchant.free()


func test_wave_sample_is_finite_and_varies_across_the_harbor() -> void:
	var near := BoatFloat.sample_wave(Vector2(12.0, 4.0), 1.5)
	var far := BoatFloat.sample_wave(Vector2(40.0, 18.0), 1.5)
	assert_true(is_finite(near.x) and is_finite(near.y) and is_finite(near.z), "wave sample must stay finite")
	assert_true(near.distance_to(far) > 0.01, "distinct berths must not share one locked wave phase")


func test_float_motion_moves_hull_off_rest_pose() -> void:
	var boat := Node3D.new()
	boat.position = Vector3(8.0, 0.1, 3.0)
	var floater: BoatFloat = BoatFloat.new()
	floater.configure(boat, 1.0, 42)
	boat.add_child(floater)
	var rest_position := boat.position
	var rest_basis := boat.basis
	floater._process(0.016)
	var moved := (
		not boat.position.is_equal_approx(rest_position)
		or not boat.basis.is_equal_approx(rest_basis)
	)
	assert_true(moved, "floating hulls must leave their authored rest pose each frame")
	boat.free()


func test_rain_raises_wind_above_clear_breeze() -> void:
	var sky: SkyWeather = SkyWeather.new()
	sky.auto_weather = false
	var clear_wind := sky.wind_strength()
	sky.set_weather(SkyWeather.WEATHER_RAIN)
	sky.advance(SkyWeather.TRANSITION_SECONDS)
	assert_true(sky.wind_strength() > clear_wind + 0.4, "storm wind must exceed the clear harbor breeze")
	sky.free()


func test_sea_weather_scales_water_wave_height() -> void:
	var clear_height := float(
		MapViewMaterials.water_surface(MapTypes.TERRAIN_DEEP_WATER).get_shader_parameter("wave_height")
	)
	MapViewMaterials.apply_sea_weather(0.22, 0.0)
	var calm := float(
		MapViewMaterials.water_surface(MapTypes.TERRAIN_DEEP_WATER).get_shader_parameter("wave_height")
	)
	MapViewMaterials.apply_sea_weather(0.92, 1.0)
	var storm := float(
		MapViewMaterials.water_surface(MapTypes.TERRAIN_DEEP_WATER).get_shader_parameter("wave_height")
	)
	assert_true(storm > calm, "rain and wind must raise the animated water surface")
	assert_true(calm > 0.0 and clear_height > 0.0, "water waves must stay active in calm weather")
	# Restore a near-clear sea state so later mesh tests keep stable uniforms.
	MapViewMaterials.apply_sea_weather(0.22, 0.0)
