extends "res://tests/godot/test_case.gd"

const Underwater := preload("res://scripts/map/view3d/underwater_pass.gd")
const Bubbles := preload("res://scripts/map/view3d/water_bubbles.gd")


func _stream_world() -> CityWorld3D:
	var world := CityWorld3D.new()
	world.plan = CityPlan.load_default()
	var hj: Dictionary = world.plan.data["harjapea"]
	var trace := CityPlan.points(hj["points"])
	var halves := world._stream_wet_halves(trace, hj["widths"], hj["surfaces"])
	world._stream_water(trace, halves, hj["surfaces"])
	world.stream_segment_count = world.moat_water.size()
	world.stream_material = world._stream_material()
	return world


func test_city_medium_uses_local_elevation_and_rejects_dry_ribbon() -> void:
	var world := _stream_world()
	var pool := Vector2(617.64, 294.69)
	var probe := world.water_medium_at(pool)
	assert_false(probe.is_empty())
	assert_false(probe["sea"])
	assert_true(float(probe["surface_y"]) > 1.0, "raised stream is not sea-level water")
	assert_eq(probe["material"], world.stream_material)
	assert_true(world.water_medium_at(pool + Vector2(25, 0)).is_empty(), "bank is air")
	world.free()


func test_city_camera_enters_stream_and_leaves_without_stale_sea_fft() -> void:
	var world := _stream_world()
	var view := CityMapView.new()
	view.plan = world.plan
	view.world = world
	view.add_child(world)
	view._camera = Camera3D.new()
	view._camera.near = 0.025
	view.add_child(view._camera)
	view._sky_weather = SkyWeather3D.new()
	view.add_child(view._sky_weather)
	view.set_process(false)
	Engine.get_main_loop().root.add_child(view)
	view._create_city_underwater_pass()
	var pool := Vector2(617.64, 294.69)
	var y := world.water_surface_at(pool)
	view._camera.position = Vector3(pool.x, y - 0.4, pool.y)
	var effect := view.underwater_pass()
	effect.update(0.2)
	assert_eq(effect.state, Underwater.STATE_UNDER)
	assert_true(effect.is_pass_visible())
	assert_eq(effect.pass_material().get_shader_parameter("use_fft"), false)
	assert_eq(effect.pass_material().get_shader_parameter("metres_per_unit"), 1.0)
	var extinction: Vector3 = effect.pass_material().get_shader_parameter("extinction_per_m")
	assert_true(extinction.z > extinction.y and extinction.y > extinction.x)
	assert_true(extinction.y > 1.0, "humic stream is optically denser than the sea")
	view._camera.position.y = y + 0.5
	effect.update(0.2)
	assert_eq(effect.state, Underwater.STATE_AIR)
	assert_true(effect.wet_lens_remaining > 0.0)
	effect.update(Underwater.WET_LENS_SECONDS + 0.1)
	assert_false(effect.is_pass_visible(), "dry camera has no overlay draw")
	view.inside_building = 0
	assert_true(view._underwater_probe(pool).is_empty())
	view.free()


func test_stream_underwater_lighting_tracks_night_without_an_ocean_visit() -> void:
	var world := _stream_world()
	var effect := Underwater.new()
	Engine.get_main_loop().root.add_child(effect)
	effect.configure(null, Callable(), &"minimum")
	var sea := MapViewMaterials.water_surface(MapTypes.TERRAIN_SHALLOW_WATER)
	MapViewMaterials.apply_water_lighting(0.0, 0.0)
	effect.advance(
		0.2, 1.0, {"surface_y": 5.0, "material": world.stream_material, "lighting_material": sea}
	)
	assert_eq(effect.pass_material().get_shader_parameter("day_blend"), 0.0)
	MapViewMaterials.apply_water_lighting(1.0, 1.0)
	effect.advance(
		0.2, 1.0, {"surface_y": 5.0, "material": world.stream_material, "lighting_material": sea}
	)
	assert_eq(effect.pass_material().get_shader_parameter("day_blend"), 1.0)
	effect.free()
	world.free()


func test_camera_classification_follows_wave_probe_and_has_hysteresis() -> void:
	var probe := {"surface_y": 0.0, "camera_surface_y": 0.5}
	assert_almost_eq(Underwater._camera_depth_from(probe, 0.4), 0.1, 0.00001)
	assert_eq(Underwater.classify(0.04, 0.04, Underwater.STATE_UNDER, 0.01), Underwater.STATE_UNDER)
	assert_eq(Underwater.classify(-0.04, 0.04, Underwater.STATE_AIR, 0.01), Underwater.STATE_AIR)


func test_bubbles_are_bounded_pop_at_surface_and_stop_on_exit() -> void:
	var bubbles := Bubbles.new()
	Engine.get_main_loop().root.add_child(bubbles)
	bubbles.start(Transform3D.IDENTITY)
	bubbles.advance(0.3, 0.0, true)
	assert_true(bubbles.visible)
	assert_true(bubbles._batch.multimesh.visible_instance_count <= Bubbles.COUNT)
	for i in Bubbles.COUNT:
		var start := Bubbles.bubble_position(i, Transform3D.IDENTITY, 0.0)
		var risen := Bubbles.bubble_position(i, Transform3D.IDENTITY, 0.3)
		assert_true(risen.y > start.y, "air rises")
		assert_true(risen.y < 0.0, "initial burst stays under the surface")
	bubbles.advance(0.1, 0.0, false)
	assert_false(bubbles.visible)
	bubbles.advance(5.0, 0.0, true)
	assert_false(bubbles.visible, "no perpetual underwater bubble noise")
	bubbles.free()


func test_fish_stay_above_bed_below_surface_and_use_one_draw_per_school() -> void:
	var plan := CityPlan.load_default()
	var centre: Dictionary = CityFish.school_centres(plan)[0]
	var fish := CityFish.create(plan, null)
	Engine.get_main_loop().root.add_child(fish)
	var vertices: PackedVector3Array = fish._fish_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for species: StringName in [&"herring", &"perch"]:
		centre["species"] = species
		var school := fish._spawn(centre)
		assert_true(school["node"] is MultiMeshInstance3D)
		for step in 20:
			fish._time = float(step) * 3.0
			fish._animate(school)
			for f: Dictionary in school["fish"]:
				var pose := CityFish.fish_transform(plan, school, f, fish._time)
				for vertex in vertices:
					for swing: float in [-1.0, 1.0]:
						var animated := vertex
						animated.z += swing * smoothstep(0.15, 0.75, -vertex.x) * 0.12
						var p := pose * animated
						assert_true(p.y <= -0.049, "%s fin stays submerged" % species)
						assert_true(p.y >= plan.ground_height(Vector2(p.x, p.z)) + 0.035)
	fish.free()


func test_rain_stops_but_remaining_puddles_keep_weather_wind() -> void:
	MapViewMaterials.apply_sea_weather(0.8, 1.0, Vector2.LEFT)
	var puddle := MapViewMaterials.WATER_MATERIALS.puddle_surface()
	assert_eq(puddle.get_shader_parameter("rain_intensity"), 1.0)
	MapViewMaterials.apply_sea_weather(0.8, 0.0, Vector2.LEFT)
	assert_eq(puddle.get_shader_parameter("rain_intensity"), 0.0)
	MapViewMaterials.apply_world_wind(Vector2.LEFT, 0.8)
	assert_eq(WindField.current().direction, Vector2.LEFT)
	assert_almost_eq(WindField.current().strength, 0.8, 0.0001)
	MapViewMaterials.apply_world_wind(WindField.DEFAULT_DIRECTION, WindField.DEFAULT_STRENGTH)
