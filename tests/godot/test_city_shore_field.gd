extends "res://tests/godot/test_case.gd"

## The city's shore field and spray (docs/SYSTEMS/CITY_SEA.md): the sea shader only
## draws surf where a shore distance field is bound, so the bake must find the
## waterline, mark gentle shore as beach and keep one continuous 3D water surface.

const ShoreField := preload("res://scripts/city/city_shore_field.gd")
const Surface := preload("res://scripts/city/city_water_surface.gd")


func _bake() -> Array:
	var plan := CityPlan.load_default()
	return [plan, ShoreField.bake(plan)]


func test_bake_finds_waterline_and_beach() -> void:
	var baked := _bake()
	var shore: Dictionary = baked[1]
	assert_true(shore["texture"] is Texture2D, "field texture is built")
	var contour: PackedVector2Array = shore["contour"]
	assert_true(contour.size() > 200, "the coast yields waterline segments")
	var distance: PackedFloat32Array = shore["distance"]
	var water := 0
	var land := 0
	var beach := 0.0
	var near := 0
	for index in distance.size():
		if distance[index] > 0.0:
			water += 1
		else:
			land += 1
		if absf(distance[index]) < ShoreField.MAX_DISTANCE:
			near += 1
			beach += (shore["beach"] as PackedFloat32Array)[index]
	assert_true(water > 0 and land > 0, "both sea and land are present")
	assert_true(near > 0 and beach / float(near) > 0.2, "gentle shore is flagged as beach")


func test_exact_zero_height_nodes_keep_a_continuous_valid_shore() -> void:
	var plan := CityPlan.new()
	plan._nx = 9
	plan._ny = 9
	plan._origin = Vector2(-8, -8)
	plan.bounds = Rect2(-8, -8, 16, 16)
	for j in 9:
		for i in 9:
			plan._heights.append(float(j - 4) * 0.12)
	var shore := ShoreField.bake(plan)
	for z in [-0.5, -0.01, 0.0, 0.01, 0.5]:
		var field := Surface.field_at(shore, Vector2(0.0, z))
		var direction := Vector2(field.y, field.z) * 2.0 - Vector2.ONE
		assert_true(direction.y > 0.99, "zero-height contour keeps its landward direction")
		assert_true(field.w > 0.99, "zero-height contour keeps its beach type")
		assert_almost_eq(field.x, -z / ShoreField.DISTANCE_SCALE, 0.001)


func test_runup_shares_sea_mesh_with_matching_terrain_triangles() -> void:
	var baked := _bake()
	var plan: CityPlan = baked[0]
	var shore: Dictionary = baked[1]
	var meshes := ShoreField.build_band(plan, shore, CityWorld3D.SEA_SHORE_DEPTH)
	var inland := 0
	for mesh in meshes:
		var arrays := mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var beds: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		assert_eq(vertices.size(), beds.size(), "one signed bed height per water vertex")
		var indices := _indices(arrays)
		assert_true(vertices.size() < indices.size() / 3, "shared vertex shader work is bounded")
		for i in range(0, indices.size(), 291):
			var a := indices[i]
			var b := indices[i + 1]
			var c := indices[i + 2]
			var p := (vertices[a] + vertices[b] + vertices[c]) / 3.0
			var bed := (beds[a].y + beds[b].y + beds[c].y) / 3.0
			# ground_height clamps its last row/column 0.001 cells inward;
			# only triangles touching the plan boundary inherit that tiny bias.
			var edge := p.x > plan.bounds.end.x - 1.0 or p.z > plan.bounds.end.y - 1.0
			var tolerance := 0.004 if edge else 0.0005
			assert_almost_eq(bed, plan.ground_height(Vector2(p.x, p.z)), tolerance, str(p))
			if ShoreField.signed_distance_at(shore, plan, Vector2(p.x, p.z)) < -2.9:
				inland += 1
	assert_true(inland > 0, "unified geometry includes the full run-up, not only the old 1.8 m fringe")
	assert_true(ShoreField.SURFACE_CULL_MARGIN >= 4.0, "shader lift remains in the culling bounds")


func test_surf_and_coarse_sea_have_exclusive_ownership() -> void:
	var baked := _bake()
	var plan: CityPlan = baked[0]
	var shore: Dictionary = baked[1]
	var fine := ShoreField.build_band(plan, shore, CityWorld3D.SEA_SHORE_DEPTH)
	var world := CityWorld3D.new()
	world.plan = plan
	var coarse := world._surface_grid(
		0.0,
		func(p: Vector2) -> float: return -plan.ground_height(p),
		CityWorld3D.SEA_SHORE_DEPTH,
		func(_p: Vector2, corners: Array) -> bool:
			return ShoreField.covers_coarse_cell(shore, plan, corners[0])
	)
	var fine_vertices := {}
	for mesh: ArrayMesh in fine + [coarse]:
		var arrays := mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var beds: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		var indices := _indices(arrays)
		for i in range(0, indices.size(), 3):
			var va := vertices[indices[i]]
			var vb := vertices[indices[i + 1]]
			var vc := vertices[indices[i + 2]]
			var middle := (va + vb + vc) / 3.0
			var owned := ShoreField.in_band(shore, plan, Vector2(middle.x, middle.z))
			assert_eq(owned, mesh != coarse, "exactly one sea mesh owns each surface cell")
			var a := vb - va
			var b := vc - va
			assert_true(a.cross(b).y < 0.0, "all city water triangles have clockwise top faces")
		if mesh != coarse:
			for i in vertices.size():
				fine_vertices[vertices[i]] = beds[i].y
	var stitches := 0
	var coarse_arrays := coarse.surface_get_arrays(0)
	var coarse_vertices: PackedVector3Array = coarse_arrays[Mesh.ARRAY_VERTEX]
	var coarse_beds: PackedVector2Array = coarse_arrays[Mesh.ARRAY_TEX_UV2]
	for i in coarse_vertices.size():
		var v := coarse_vertices[i]
		var local := Vector2(v.x, v.z) - plan.bounds.position
		var fx := fposmod(local.x, ShoreField.COARSE_STEP)
		var fz := fposmod(local.y, ShoreField.COARSE_STEP)
		if (
			(is_zero_approx(fx) and not is_zero_approx(fz))
			or (is_zero_approx(fz) and not is_zero_approx(fx))
		):
			if (
				not plan.bounds.has_point(Vector2(v.x, v.z))
				or plan.ground_height(Vector2(v.x, v.z)) >= -0.1
			):
				continue  # Outside the authored band or concealed under dry ground.
			assert_true(
				fine_vertices.has(v), "every intermediate coarse-edge vertex is shared with surf"
			)
			if fine_vertices.has(v):
				assert_almost_eq(coarse_beds[i].y, fine_vertices[v], 0.00001,
					"joined edges have identical bed height, hence identical shader lift")
			stitches += 1
	assert_true(stitches > 0, "LOD transition has stitched edges")
	world.free()


func test_camera_shore_lift_is_bounded_dynamic_and_dies_offshore() -> void:
	var material := MapViewMaterials.water_surface(MapTypes.TERRAIN_SHALLOW_WATER)
	MapViewMaterials.apply_sea_weather(0.9, 0.3)
	MapViewMaterials.apply_surf_gain(2.0, 1.8, 1.3, 3.0, 2.2)
	var highest := 0.0
	var lowest := 10.0
	for i in 100:
		var time := float(i) * 0.1
		var y := Surface.shore_lift(Vector2.ZERO, Vector4(3.0, 1.0, 0.5, 1.0), time, material)
		highest = maxf(highest, y)
		lowest = minf(lowest, y)
		assert_true(y >= 0.0 and y < 2.0)
		assert_almost_eq(
			Surface.shore_lift(Vector2.ZERO, Vector4(8, 1, 0.5, 1), time, material), 0.0, 0.0001
		)
	assert_true(
		highest > 0.2 and lowest < 0.001, "shore crest crosses the camera during a wave cycle"
	)


func test_shore_crest_phase_stays_continuous_around_bends() -> void:
	var material := MapViewMaterials.water_surface(MapTypes.TERRAIN_SHALLOW_WATER)
	MapViewMaterials.apply_sea_weather(0.9, 0.0)
	MapViewMaterials.apply_surf_gain(2.0, 1.8, 1.3, 3.0, 2.2)
	var p := Vector2(620.0, 340.0)
	for i in 180:
		var t := float(i) * 0.05
		var reference := Surface.shore_lift(p, Vector4(3.0, 1.0, 0.5, 1.0), t, material)
		# Same depth and beach, with the nearest contour turning through a corner.
		for angle in [0.05, 0.3, 1.2]:
			var direction := Vector2.RIGHT.rotated(angle)
			var field := Vector4(3.0, direction.x * 0.5 + 0.5, direction.y * 0.5 + 0.5, 1.0)
			assert_almost_eq(Surface.shore_lift(p, field, t, material), reference, 0.00001)
			var neighbour := Surface.shore_lift(p + Vector2(0.01, 0.01), field, t, material)
			assert_true(absf(neighbour - reference) < 0.01, "no phase islands at shore bends")


func test_true_wet_ground_cannot_be_cut_by_the_shore_field_zero() -> void:
	MapViewMaterials.apply_sea_weather(0.9, 0.0)
	MapViewMaterials.apply_surf_gain(2.0, 1.8, 1.3, 3.0, 2.2)
	var mat := MapViewMaterials.water_surface(MapTypes.TERRAIN_SHALLOW_WATER).duplicate()
	mat.set_shader_parameter("tide_height", 0.0)
	var highest := 0.0
	var lowest := 10.0
	for i in 180:
		var time := float(i) * 0.05
		for field_distance in [-0.2, 0.0, 0.2]:
			var wet := Surface.runup_profile(Vector2(620, 340),
				Vector4(field_distance, 1, 0.5, 1), time, mat, -0.01, 0.0)
			assert_eq(wet["coverage"], 1.0, "filtered field disagreement cannot expose a sea/shore gap")
			assert_true(float(wet["height"]) >= 0.0)
		var land := Surface.runup_profile(Vector2(620, 340), Vector4(-0.45, 1, 0.5, 1),
			time, mat, 0.12, 0.0)
		if float(land["coverage"]) > 0.5:
			highest = maxf(highest, float(land["height"]) - 0.12)
		lowest = minf(lowest, float(land["coverage"]))
	assert_true(highest > 0.15, "run-up has a raised 3D bore, not a ground decal")
	assert_eq(lowest, 0.0, "backwash exposes dry ground again")


func test_mixed_beach_runup_never_sinks_below_its_terrain_floor() -> void:
	MapViewMaterials.apply_sea_weather(0.7, 0.0)
	MapViewMaterials.apply_surf_gain(2.0, 1.8, 1.3, 3.0, 2.2)
	var mat := MapViewMaterials.water_surface(MapTypes.TERRAIN_SHALLOW_WATER)
	var covered := 0
	for i in 90:
		for beach in [0.39, 0.46, 0.55, 0.63, 1.0]:
			for bed in [-0.05, 0.05, 0.12, 0.5, 1.0]:
				var sample := Surface.runup_profile(Vector2(620, 340),
					Vector4(-0.45, 1, 0.5, beach), float(i) * 0.1, mat, bed, 0.0)
				# Dry corners matter too: a triangle can straddle the moving front.
				assert_true(float(sample["height"]) >= bed + 0.0179,
					"all run-up vertices stay above sand even at partial beach weights")
				covered += int(float(sample["coverage"]) > 0.5)
	assert_true(covered > 100, "the mixed-beach cases include visible wet water")


func _indices(arrays: Array) -> PackedInt32Array:
	if arrays[Mesh.ARRAY_INDEX] != null:
		return arrays[Mesh.ARRAY_INDEX]
	return PackedInt32Array(range((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()))
