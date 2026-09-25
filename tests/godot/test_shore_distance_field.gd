extends "res://tests/godot/test_case.gd"

## WS-08: runtime shore distance field and generated beach swash sheet.

const MapBuilder := preload("res://scripts/map/map_builder.gd")
const TerrainBuilder := preload("res://scripts/map/view3d/map_view_mesh_builder_terrain.gd")
const WaterBuilder := preload("res://scripts/map/view3d/map_view_mesh_builder_terrain_water.gd")
const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")

## Beach column and quay column, both well away from the quay corner and map edges.
const BEACH_X := 5.5
const QUAY_X := 15.5
const CELL_TOLERANCE := 0.1


func after_each() -> void:
	MapViewMaterials.set_shore_swash_quality_tier(SkyWeather.QUALITY_RECOMMENDED)
	MapViewMaterials.apply_shore_field(null, Vector2.ZERO, Vector2.ONE)


func test_signed_distance_matches_the_water_contour() -> void:
	var grid := MapBuilder.build(_shore_definition())
	var field := _contour_field(grid)
	var shore := WaterBuilder.bake_shore_field(field, grid)
	assert_false(shore.is_empty(), "sea water must produce a shore field")
	if shore.is_empty():
		return
	var waterline := _contour_y(field, BEACH_X)
	for offset in [0.5, 1.0, 2.5, 5.0]:
		assert_almost_eq(
			WaterBuilder.shore_distance_at(shore, Vector2(BEACH_X, waterline - offset)),
			offset,
			CELL_TOLERANCE,
			"water side is positive and Euclidean (%.1f cells offshore)" % offset,
		)
		assert_almost_eq(
			WaterBuilder.shore_distance_at(shore, Vector2(BEACH_X, waterline + offset)),
			-offset,
			CELL_TOLERANCE,
			"land side is negative and Euclidean (%.1f cells inland)" % offset,
		)
	assert_almost_eq(
		WaterBuilder.shore_distance_at(shore, Vector2(BEACH_X, 19.5)),
		-WaterBuilder.SHORE_FIELD_MAX_DISTANCE,
		0.001,
		"distance clamps at the field limit",
	)
	var texture := shore["texture"] as Texture2D
	assert_true(texture != null, "the field is uploaded as a texture")
	if texture != null:
		assert_eq(
			texture.get_image().get_format(),
			Image.FORMAT_RGBAH,
			"the field stays a filterable half-float texture on Compatibility",
		)
		assert_eq(
			Vector2i(texture.get_width(), texture.get_height()),
			grid.size_cells * WaterBuilder.SHORE_FIELD_TEXELS_PER_CELL,
			"the field has four texels per cell",
		)


func test_direction_points_to_land() -> void:
	var grid := MapBuilder.build(_shore_definition())
	var shore := WaterBuilder.bake_shore_field(_contour_field(grid), grid)
	for sample in [Vector2(BEACH_X, 6.5), Vector2(BEACH_X, 12.5), Vector2(QUAY_X, 8.5)]:
		var direction := WaterBuilder.shore_direction_at(shore, sample)
		assert_almost_eq(direction.length(), 1.0, 0.01, "direction is a unit vector at %s" % sample)
		assert_true(
			direction.dot(Vector2.DOWN) > 0.95,
			"direction at %s points towards the land at +z, got %s" % [sample, direction],
		)
	# Around the (blur-rounded) quay corner the direction is still the negative
	# distance gradient: one step along it moves that far closer to land.
	for sample in [Vector2(16.3, 7.5), Vector2(20.5, 4.0), Vector2(17.0, 5.0), Vector2(9.0, 7.0)]:
		var towards := WaterBuilder.shore_direction_at(shore, sample)
		var here := WaterBuilder.shore_distance_at(shore, sample)
		var stepped := WaterBuilder.shore_distance_at(shore, sample + towards * 0.3)
		assert_almost_eq(
			here - stepped, 0.3, 0.05, "direction at %s follows the distance gradient" % sample
		)


func test_shore_type_is_beach_on_sand_and_hard_on_stone() -> void:
	var grid := MapBuilder.build(_shore_definition())
	var field := _contour_field(grid)
	var shore := WaterBuilder.bake_shore_field(field, grid)
	var beach_line := _contour_y(field, BEACH_X)
	var quay_line := _contour_y(field, QUAY_X)
	for offset in [-1.5, -0.5, 0.5, 1.5]:
		assert_almost_eq(
			WaterBuilder.shore_type_at(shore, Vector2(BEACH_X, beach_line + offset)),
			1.0,
			0.001,
			"coast sand against the sea is a beach",
		)
		assert_almost_eq(
			WaterBuilder.shore_type_at(shore, Vector2(QUAY_X, quay_line + offset)),
			0.0,
			0.001,
			"stone against the sea is a hard edge",
		)
	assert_almost_eq(
		WaterBuilder.shore_type_at(shore, Vector2(21.0, 4.5)),
		0.0,
		0.001,
		"water off the quay corner is a hard edge",
	)


func test_field_is_deterministic() -> void:
	var grid := MapBuilder.build(_shore_definition())
	var first := WaterBuilder.bake_shore_field(_contour_field(grid), grid)
	var second := WaterBuilder.bake_shore_field(_contour_field(grid), grid)
	assert_eq(first["distance"], second["distance"], "distances are seed-stable")
	assert_eq(first["direction"], second["direction"], "directions are seed-stable")
	assert_eq(first["type"], second["type"], "shore types are seed-stable")
	assert_eq(
		(first["texture"] as Texture2D).get_image().get_data(),
		(second["texture"] as Texture2D).get_image().get_data(),
		"the uploaded texture is byte-identical",
	)


func test_swash_period_wraps_seamlessly_with_ocean_time() -> void:
	var code := FileAccess.get_file_as_string("res://scripts/map/view3d/shore_swash.gdshaderinc")
	assert_true(
		code.contains(
			"SHORE_OCEAN_TIME_WRAP = %.1f;" % MapViewRuntimeEnvironment.OCEAN_TIME_WRAP_SECONDS
		),
		"the swash period is derived from the live ocean_time wrap",
	)
	var waves := RegEx.create_from_string("SHORE_WAVES_PER_WRAP = (\\d+)\\.0;").search(code)
	assert_true(waves != null, "the wave count per wrap is declared")
	if waves != null:
		var count := int(waves.get_string(1))
		var set_size := RegEx.create_from_string("SHORE_SET_WAVES = (\\d+)\\.0;").search(code)
		assert_true(set_size != null, "the set size is declared")
		if set_size != null:
			assert_eq(count % int(set_size.get_string(1)), 0, "the wrap holds whole wave sets")
		assert_almost_eq(
			MapViewRuntimeEnvironment.OCEAN_TIME_WRAP_SECONDS / float(count),
			9.0,
			0.05,
			"the quantised period stays at Tidewater's 9 s",
		)


func test_rivers_and_dry_maps_have_no_field() -> void:
	var definition := _shore_definition()
	definition.zones = [{"rect": Rect2i(0, 0, 24, 10), "terrain": MapTypes.TERRAIN_RIVER_WATER}]
	var grid := MapBuilder.build(definition)
	assert_true(
		WaterBuilder.bake_shore_field(_contour_field(grid), grid).is_empty(),
		"rivers keep their bank treatment and get no swash field",
	)


func test_sheet_covers_only_beach_without_collision() -> void:
	var definition := _shore_definition()
	var grid := MapBuilder.build(definition)
	var fingerprint_before := grid.fingerprint()
	var root := TerrainBuilder.build_terrain(definition, grid)
	var sheet := root.get_node_or_null("ShoreSwashSheet") as MeshInstance3D
	assert_true(sheet != null, "a beach produces a swash sheet")
	if sheet != null:
		var material := sheet.material_override as ShaderMaterial
		assert_true(material != null, "the sheet uses the water shader")
		if material != null:
			assert_true(
				bool(material.get_shader_parameter("swash_sheet")),
				"the sheet material runs the swash-sheet branch",
			)
		assert_eq(sheet.get_child_count(), 0, "the sheet has no collision or other children")
		assert_eq(
			sheet.cast_shadow,
			GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
			"the film does not cast shadows",
		)
		var field := TerrainBuilder.ensure_height_field(definition, grid)
		var shore: Dictionary = field["shore_field"]
		var arrays := (sheet.mesh as ArrayMesh).surface_get_arrays(0)
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		assert_true(vertices.size() > 0, "the sheet has triangles")
		var column: Array[float] = []
		var off_beach := 0
		var too_far := 0
		for vertex in vertices:
			var xz := Vector2(vertex.x, vertex.z)
			if vertex.x > 12.75 or vertex.x < -0.01:
				off_beach += 1
			var land := -WaterBuilder.shore_distance_at(shore, xz)
			if land > WaterBuilder.SHORE_SHEET_REACH + 0.6:
				too_far += 1
			if absf(vertex.x - BEACH_X) < 0.3 and land >= 0.0:
				column.append(land)
		assert_eq(off_beach, 0, "the quay (hard edge) gets no sheet")
		assert_eq(too_far, 0, "the sheet stays within its inland reach")
		# At least 12 rows across the 3-unit reach: no across-shore gap wider than 0.25.
		column.sort()
		var widest := 0.0
		for index in range(1, column.size()):
			widest = maxf(widest, column[index] - column[index - 1])
		assert_true(column.size() > 0, "the beach column is covered")
		if not column.is_empty():
			assert_true(
				column[column.size() - 1] >= WaterBuilder.SHORE_SHEET_REACH - 0.25,
				"the sheet reaches the full run-up band",
			)
		assert_true(
			widest <= 0.25,
			"the sheet has at least 12 rows across shore (widest gap %.3f)" % widest,
		)
	assert_eq(_count_collision(root), 0, "shore swash adds no collision to the terrain")
	assert_eq(grid.fingerprint(), fingerprint_before, "gameplay terrain is unchanged")
	root.free()


func test_minimum_tier_drops_the_sheet_but_keeps_the_field() -> void:
	MapViewMaterials.set_shore_swash_quality_tier(SkyWeather.QUALITY_MINIMUM)
	var definition := _shore_definition()
	definition.fingerprint = "test-ws08-shore-minimum"
	var grid := MapBuilder.build(definition)
	var root := TerrainBuilder.build_terrain(definition, grid)
	assert_true(
		root.get_node_or_null("ShoreSwashSheet") == null,
		"minimum tier builds no swash sheet mesh",
	)
	var water := MapViewMaterials.water_surface(MapTypes.TERRAIN_SHALLOW_WATER)
	assert_almost_eq(
		float(water.get_shader_parameter("shore_field_valid")),
		1.0,
		0.001,
		"bore foam and wet sand still receive the field on minimum tier",
	)
	root.free()


func test_shore_field_binding_and_family_strength() -> void:
	var definition := _shore_definition()
	definition.fingerprint = "test-ws08-shore-binding"
	var grid := MapBuilder.build(definition)
	var root := TerrainBuilder.build_terrain(definition, grid)
	var ground := MapViewMaterials.blended_ground(definition.seed)
	assert_almost_eq(
		float(ground.get_shader_parameter("shore_field_valid")),
		1.0,
		0.001,
		"the terrain wet-sand pass receives the same field",
	)
	assert_eq(
		ground.get_shader_parameter("shore_field"),
		MapViewMaterials.water_surface(MapTypes.TERRAIN_SHALLOW_WATER).get_shader_parameter(
			"shore_field"
		),
		"water and sand sample one field texture",
	)
	assert_almost_eq(
		float(
			MapViewMaterials.water_surface(MapTypes.TERRAIN_RIVER_WATER).get_shader_parameter(
				"shore_strength"
			)
		),
		0.0,
		0.001,
		"rivers get no swash",
	)
	MapViewMaterials.apply_sea_weather(1.0, 0.0)
	var sheet := root.get_node("ShoreSwashSheet") as MeshInstance3D
	var sheet_material := sheet.material_override as ShaderMaterial
	assert_almost_eq(
		float(sheet_material.get_shader_parameter("shore_sea_state")),
		1.0,
		0.001,
		"storm sea state reaches the sheet",
	)
	assert_almost_eq(
		float(sheet_material.get_shader_parameter("wave_speed")),
		float(
			MapViewMaterials.water_surface(MapTypes.TERRAIN_SHALLOW_WATER).get_shader_parameter(
				"wave_speed"
			)
		),
		0.0001,
		"the sheet mirrors its source water family on each weather sync",
	)
	assert_true(
		bool(sheet_material.get_shader_parameter("swash_sheet")),
		"the mirror never copies swash_sheet back to false",
	)
	# A map without a sea shoreline switches every swash path off again.
	MapViewMaterials.apply_shore_field(null, Vector2.ZERO, Vector2.ONE)
	assert_almost_eq(
		float(ground.get_shader_parameter("shore_field_valid")),
		0.0,
		0.001,
		"a null field turns wet sand off",
	)
	MapViewMaterials.apply_sea_weather(0.35, 0.0)
	root.free()


## 24 x 20: sea in the north half; coast sand beach west of x = 12 and a stone quay
## east of it, whose corner juts four cells into the water at x >= 18.
func _shore_definition() -> MapDefinition:
	var definition := MapDefinition.new()
	definition.map_id = &"test_ws08_shore_distance_field"
	definition.size_cells = Vector2i(24, 20)
	definition.base_terrain = MapTypes.TERRAIN_COAST_SAND
	definition.seed = 43
	definition.player_spawn = Vector2(4.5, 16.5)
	definition.location = &"test"
	definition.scope = &"prototype"
	definition.palette = &"spring"
	definition.fingerprint = "test-ws08-shore-distance-field"
	definition.zones = [
		{"rect": Rect2i(0, 0, 24, 10), "terrain": MapTypes.TERRAIN_SHALLOW_WATER},
		{"rect": Rect2i(12, 10, 12, 10), "terrain": MapTypes.TERRAIN_STONE},
		{"rect": Rect2i(18, 6, 6, 4), "terrain": MapTypes.TERRAIN_STONE},
	]
	return definition


func _contour_field(grid: MapTerrainGrid) -> Dictionary:
	var contours := {}
	for terrain_id in grid.used_terrain_ids():
		if MapTypes.WATER_TERRAINS.has(terrain_id):
			contours[terrain_id] = WaterBuilder.bake_water_contour(grid, terrain_id)
	return {"water_contours": contours}


## Bisects the combined water contour along a column: the reference the field must match.
func _contour_y(field: Dictionary, x: float) -> float:
	var wet := 2.0
	var dry := 18.0
	var threshold := MapViewMeshBuilderConfig.WATER_CONTOUR_THRESHOLD
	for _step in 40:
		var middle := (wet + dry) * 0.5
		if WaterBuilder.combined_water_coverage_at(field, Vector2(x, middle)) >= threshold:
			wet = middle
		else:
			dry = middle
	return (wet + dry) * 0.5


func _count_collision(node: Node) -> int:
	var count := 1 if node is CollisionObject3D or node is CollisionShape3D else 0
	for child in node.get_children():
		count += _count_collision(child)
	return count
