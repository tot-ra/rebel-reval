extends "res://tests/godot/test_case.gd"

## R-1321 (VEGR-2): one shared wind field through global shader parameters.

const WIND_SHADERS := [
	"res://scripts/map/view3d/map_view_grass.gdshader",
	"res://scripts/map/view3d/map_view_canopy.gdshader",
	"res://scripts/map/view3d/map_view_bark_wind.gdshader",
	"res://scripts/map/view3d/map_view_cloth.gdshader",
	"res://scripts/map/view3d/map_view_flag_cloth.gdshader",
	"res://scripts/map/view3d/map_view_hanging_banner_cloth.gdshader",
	"res://scripts/map/view3d/map_view_hoist_rope.gdshader",
	"res://scripts/map/view3d/map_view_fishing_net_wind.gdshader",
]


func after_each() -> void:
	super.after_each()
	MapViewMaterials.apply_world_wind(WindField.DEFAULT_DIRECTION, WindField.DEFAULT_STRENGTH)


func test_same_time_and_weather_give_the_same_bend() -> void:
	var a := WindField.params_for(Vector2(0.6, 0.8), 0.47)
	var b := WindField.params_for(Vector2(0.6, 0.8), 0.47)
	assert_eq(a.to_dict(), b.to_dict(), "weather mapping must be a pure function")
	for i in 32:
		var xz := Vector2(i * 7.3 - 90.0, i * -3.1 + 40.0)
		var t := 12.5 + i * 0.37
		assert_eq(WindField.gust(xz, t, a), WindField.gust(xz, t, b), "gust must be deterministic")
		assert_eq(
			WindField.pressure(xz, t, a), WindField.pressure(xz, t, b), "push must be deterministic"
		)
	# No hidden state: publishing other weather in between changes nothing.
	var before := WindField.pressure(Vector2(5.0, 9.0), 30.0, a)
	WindField.publish(WindField.params_for(Vector2.LEFT, 0.95))
	assert_eq(WindField.pressure(Vector2(5.0, 9.0), 30.0, a), before)


func test_gust_travels_downwind_as_a_front() -> void:
	var params := WindField.params_for(Vector2(1.0, 0.0), 0.5)
	var start := Vector2(10.0, 4.0)
	for dt: float in [0.5, 1.0, 2.5]:
		var downwind := start + params.direction * params.front_speed * dt
		assert_almost_eq(
			WindField.gust(downwind, 20.0 + dt, params),
			WindField.gust(start, 20.0, params),
			0.0005,
			"the state at one point must reach the downwind point %ss later" % dt
		)
	# Neighbouring tufts across the wind see nearly the same phase (a front),
	# while points along the wind are in different phases (a wave).
	var across_delta := absf(
		WindField.gust(start, 3.0, params) - WindField.gust(start + Vector2(0.0, 0.4), 3.0, params)
	)
	assert_true(across_delta < 0.08, "a front must be coherent across the wind: %s" % across_delta)


func test_tree_front_matches_the_meadow_front_on_average() -> void:
	# Crowns use the noise-free front; it must stay in phase with the grass
	# front and carry the same mean, so a gust still reaches the trees.
	var params := WindField.params_for(Vector2(1.0, 0.0), 0.6)
	var full := 0.0
	var coarse := 0.0
	var samples := 400
	for i in samples:
		var xz := Vector2(i * 0.73, i * -1.31)
		full += WindField.gust(xz, i * 0.11, params)
		coarse += WindField.gust_coarse(xz, i * 0.11, params)
	assert_almost_eq(coarse / samples, full / samples, 0.04, "coarse front keeps the mean")
	var start := Vector2(3.0, 1.0)
	assert_almost_eq(
		WindField.gust_coarse(start + params.direction * params.front_speed * 2.0, 12.0, params),
		WindField.gust_coarse(start, 10.0, params),
		0.0005,
		"the crown front travels like the meadow front"
	)


func test_calm_nearly_stops_and_storm_raises_amplitude_and_turbulence() -> void:
	var calm := WindField.params_for(Vector2(1.0, 0.0), 0.04)
	var breeze := WindField.params_for(Vector2(1.0, 0.0), WindField.DEFAULT_STRENGTH)
	var storm := WindField.params_for(Vector2(1.0, 0.0), 0.9)
	assert_true(calm.gust_amplitude < breeze.gust_amplitude)
	assert_true(breeze.gust_amplitude < storm.gust_amplitude)
	assert_true(calm.front_speed < storm.front_speed, "storm fronts must travel faster")
	assert_true(calm.gust_wavelength < storm.gust_wavelength, "storm fronts must be longer")
	assert_true(calm.turbulence < breeze.turbulence and breeze.turbulence < storm.turbulence)
	assert_true(WindField.flutter_scale(storm) > WindField.flutter_scale(calm))
	var calm_range := _bend_range(calm)
	var storm_range := _bend_range(storm)
	assert_true(calm_range < 0.05, "calm air must nearly stop the wave: %s" % calm_range)
	assert_true(storm_range > calm_range * 12.0, "storm gusts must be far stronger")


func test_zero_heading_falls_back_and_strength_is_clamped() -> void:
	var params := WindField.params_for(Vector2.ZERO, 3.0)
	assert_eq(params.direction, WindField.DEFAULT_DIRECTION)
	assert_eq(params.strength, 1.0)
	assert_eq(WindField.params_for(Vector2(0.0, -4.0), -1.0).direction, Vector2(0.0, -1.0))


func test_project_defaults_match_the_default_breeze() -> void:
	# A map that never publishes wind must keep the default look.
	var expected := WindField.params_for(WindField.DEFAULT_DIRECTION, WindField.DEFAULT_STRENGTH)
	var defaults := {
		WindField.GLOBAL_DIRECTION: expected.direction,
		WindField.GLOBAL_STRENGTH: expected.strength,
		WindField.GLOBAL_GUST_AMP: expected.gust_amplitude,
		WindField.GLOBAL_WAVELENGTH: expected.gust_wavelength,
		WindField.GLOBAL_SPEED: expected.front_speed,
		WindField.GLOBAL_TURBULENCE: expected.turbulence,
	}
	for key: StringName in defaults.keys():
		var setting: Variant = ProjectSettings.get_setting("shader_globals/%s" % key)
		assert_true(setting is Dictionary, "%s must be declared in project.godot" % key)
		var value: Variant = (setting as Dictionary)["value"]
		if value is Vector2:
			# The historical heading is unit length to four decimals only.
			assert_true((value as Vector2).distance_to(defaults[key]) < 0.0005, String(key))
		else:
			assert_almost_eq(float(value), float(defaults[key]), 0.0001, String(key))


func test_world_wind_has_a_single_writer() -> void:
	MapViewMaterials.apply_world_wind(Vector2(0.0, 2.0), 0.7)
	assert_eq(WindField.current().direction, Vector2(0.0, 1.0))
	assert_almost_eq(WindField.current().strength, 0.7, 0.0001)
	assert_eq(MapViewMaterials.WIND_MATERIALS.world_wind_direction(), Vector2(0.0, 1.0))
	assert_almost_eq(MapViewMaterials.WIND_MATERIALS.world_wind_strength(), 0.7, 0.0001)
	# A crown material created after the update (streamed chunk) reads the same
	# globals and carries no wind uniform of its own.
	var late := MapViewMaterials.canopy_for_species(&"aspen")
	assert_eq(late.get_shader_parameter("wind_direction"), null)
	assert_eq(late.get_shader_parameter("wind_strength"), null)


func test_every_wind_shader_reads_the_globals_and_compiles() -> void:
	for path: String in WIND_SHADERS:
		var shader := load(path) as Shader
		assert_true(shader != null, path)
		# Tree shaders reach the field through tree_wind.gdshaderinc, which includes it.
		assert_true(
			shader.code.contains("wind_field.gdshaderinc") or shader.code.contains("tree_wind.gdshaderinc"),
			"%s must include the field" % path
		)
		assert_false(
			shader.code.contains("uniform vec2 wind_direction"),
			"%s must not keep a per-material wind heading" % path
		)
		assert_false(
			shader.code.contains("uniform float wind_strength"),
			"%s must not keep a per-material wind strength" % path
		)
		# The dummy renderer still compiles shaders; a failed compile has no uniforms.
		assert_true(shader.get_shader_uniform_list().size() > 0, "%s must compile" % path)
	for material in MapViewMaterials.WIND_MATERIALS.wind_materials():
		assert_true(WIND_SHADERS.has(material.shader.resource_path), material.shader.resource_path)


func _bend_range(params: WindField.Params) -> float:
	var low := INF
	var high := -INF
	for i in 200:
		var bend := params.strength * WindField.pressure(Vector2(i * 1.7, 3.0), i * 0.21, params)
		low = minf(low, bend)
		high = maxf(high, bend)
	return high - low
