extends "res://tests/godot/test_case.gd"

const MapBuilder := preload("res://scripts/map/map_builder.gd")
const TerrainBuilder := preload("res://scripts/map/view3d/map_view_mesh_builder_terrain.gd")
const WaterBuilder := preload("res://scripts/map/view3d/map_view_mesh_builder_terrain_water.gd")
const Shoreline := preload("res://scripts/map/view3d/map_view_shoreline_3d.gd")


func test_empty_contour_is_a_safe_dry_field() -> void:
	var grid := MapTerrainGrid.new()
	grid.initialize_chunks(Vector2i.ZERO, MapTypes.DEFAULT_CELL_SIZE, 41)
	var contour := WaterBuilder.bake_water_contour(grid, MapTypes.TERRAIN_WATER)
	var field := {"water_contours": {MapTypes.TERRAIN_WATER: contour}}

	assert_eq(
		WaterBuilder.water_coverage_at(field, Vector2.ZERO, MapTypes.TERRAIN_WATER),
		0.0,
		"an empty contour must not index a missing sample",
	)


func test_water_mesh_is_deterministic_and_keeps_gameplay_grid_unchanged() -> void:
	var definition := _water_definition()
	var grid := MapBuilder.build(definition)
	var fingerprint_before := grid.fingerprint()
	var first := TerrainBuilder.build_terrain(definition, grid)
	var second := TerrainBuilder.build_terrain(definition, grid)
	var first_water := first.get_node_or_null("Terrain_water") as MeshInstance3D
	var second_water := second.get_node_or_null("Terrain_water") as MeshInstance3D

	assert_true(first_water != null, "an authored water family must produce a visible surface")
	assert_true(second_water != null, "rebuilding the same water family must remain visible")
	if first_water != null and second_water != null:
		var first_mesh := first_water.mesh as ArrayMesh
		var second_mesh := second_water.mesh as ArrayMesh
		assert_true(first_mesh != null, "water surface must commit an ArrayMesh")
		assert_true(second_mesh != null, "repeat water surface must commit an ArrayMesh")
		if first_mesh != null and second_mesh != null:
			var first_arrays := first_mesh.surface_get_arrays(0)
			var second_arrays := second_mesh.surface_get_arrays(0)
			var first_vertices := first_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var second_vertices := second_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var first_colors := first_arrays[Mesh.ARRAY_COLOR] as PackedColorArray
			var second_colors := second_arrays[Mesh.ARRAY_COLOR] as PackedColorArray
			assert_eq(first_vertices, second_vertices, "water vertices must be seed-stable")
			assert_eq(first_colors, second_colors, "water shoreline coverage must be seed-stable")
			assert_true(first_vertices.size() > 0, "water surface must contain triangles")
			var shoreline_vertices := 0
			for color in first_colors:
				if is_zero_approx(color.r):
					shoreline_vertices += 1
			assert_true(
				shoreline_vertices > 0,
				"clipped water contour must expose shoreline vertices for foam",
			)
			for vertex in first_vertices:
				assert_true(
					is_equal_approx(
						vertex.y,
						-MapViewMeshBuilderConfig.WATER_RECESS
							+ MapViewMeshBuilderConfig.WATER_SURFACE_LIFT,
					),
					"water vertices must keep the shared recessed surface height",
				)

	assert_eq(
		grid.fingerprint(),
		fingerprint_before,
		"water view geometry must not mutate gameplay terrain",
	)
	first.free()
	second.free()


func test_shoreline_details_require_water_adjacency() -> void:
	var dry_definition := _water_definition()
	dry_definition.base_terrain = MapTypes.TERRAIN_COAST_SAND
	dry_definition.zones = []
	var dry_grid := MapBuilder.build(dry_definition)
	var dry_details := Shoreline.build(dry_definition, dry_grid)
	assert_false(
		dry_details.has_node("CoastalRocks"),
		"coastal rocks must not appear without an adjacent water cell",
	)
	dry_details.free()

	var shore_definition := _water_definition()
	shore_definition.base_terrain = MapTypes.TERRAIN_GRASS
	shore_definition.zones = [
		{"rect": Rect2i(1, 0, 1, 6), "terrain": MapTypes.TERRAIN_COAST_SAND},
		{"rect": Rect2i(2, 0, 4, 6), "terrain": MapTypes.TERRAIN_DEEP_WATER},
	]
	shore_definition.seed = 2
	var shore_grid := MapBuilder.build(shore_definition)
	var details := Shoreline.build(shore_definition, shore_grid)
	var rocks := details.get_node_or_null("CoastalRocks") as MultiMeshInstance3D
	assert_true(rocks != null, "water-facing coast sand must receive shoreline detail")
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	Shoreline.collect_rock_instances(
		shore_definition,
		shore_grid,
		Rect2i(Vector2i.ZERO, shore_grid.size_cells),
		transforms,
		colors,
	)
	assert_eq(
		transforms.size(),
		rocks.multimesh.instance_count if rocks != null else 0,
		"authored shoreline rocks must match the committed multimesh count",
	)
	for transform in transforms:
		var origin := transform.origin
		assert_true(
			origin.x >= 1.0 and origin.x < 3.0,
			"rocks must stay within the authored shore-to-water boundary: %s" % origin,
		)
		assert_true(
			origin.z >= 0.0 and origin.z < 6.0,
			"rocks must stay inside the authored shore",
		)
	details.free()


func _water_definition() -> MapDefinition:
	var definition := MapDefinition.new()
	definition.map_id = &"test_r715_water_surface_geometry"
	definition.size_cells = Vector2i(8, 6)
	definition.base_terrain = MapTypes.TERRAIN_GRASS
	definition.seed = 41
	definition.player_spawn = Vector2(0.5, 0.5)
	definition.location = &"test"
	definition.scope = &"prototype"
	definition.palette = &"spring"
	definition.fingerprint = "test-r715-water-surface-geometry"
	definition.zones = [
		{"rect": Rect2i(3, 1, 2, 4), "terrain": MapTypes.TERRAIN_WATER},
	]
	return definition
