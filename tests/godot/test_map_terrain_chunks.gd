extends "res://tests/godot/test_case.gd"

const SmithyCourtyardDefinition := preload("res://scripts/map/smithy_courtyard_definition.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapTerrainRenderer := preload("res://scripts/map/map_terrain_renderer.gd")
const MapViewMeshBuilder := preload("res://scripts/map/view3d/map_view_mesh_builder.gd")


func test_chunked_terrain_matches_legacy_full_grid() -> void:
	var definition: MapDefinition = SmithyCourtyardDefinition.create()
	var chunked: MapTerrainGrid = MapBuilder.build(definition)
	var legacy: MapTerrainGrid = MapBuilder.build_legacy(definition)
	assert_eq(chunked.fingerprint(), legacy.fingerprint())
	for y in definition.size_cells.y:
		for x in definition.size_cells.x:
			var cell := Vector2i(x, y)
			assert_eq(chunked.get_terrain(cell), legacy.get_terrain(cell), "terrain parity at %s" % cell)


func test_partial_edge_chunks_and_boundary_cells_use_half_open_bounds() -> void:
	var definition: MapDefinition = SmithyCourtyardDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	assert_eq(grid.chunk_count(), Vector2i(2, 1))
	assert_eq(grid.chunk_bounds(Vector2i.ZERO), Rect2i(0, 0, 32, 28))
	assert_eq(grid.chunk_bounds(Vector2i(1, 0)), Rect2i(32, 0, 18, 28))
	assert_eq(grid.chunk_for_cell(Vector2i(31, 27)), Vector2i.ZERO)
	assert_eq(grid.chunk_for_cell(Vector2i(32, 27)), Vector2i(1, 0))
	assert_eq(grid.chunk_for_cell(Vector2i(49, 27)), Vector2i(1, 0))
	assert_false(grid.get_terrain(Vector2i(49, 27)).is_empty())
	assert_true(grid.get_terrain(Vector2i(50, 27)).is_empty())


func test_ordered_zone_overlays_cross_chunk_boundaries_without_reordering() -> void:
	var definition: MapDefinition = SmithyCourtyardDefinition.create()
	definition.zones.append({"rect": Rect2i(30, 4, 5, 4), "terrain": MapTypes.TERRAIN_DIRT})
	definition.zones.append({"rect": Rect2i(32, 5, 2, 2), "terrain": MapTypes.TERRAIN_WATER})
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	assert_eq(grid.get_terrain(Vector2i(31, 5)), MapTypes.TERRAIN_DIRT)
	assert_eq(grid.get_terrain(Vector2i(32, 5)), MapTypes.TERRAIN_WATER)
	assert_eq(grid.get_terrain(Vector2i(33, 6)), MapTypes.TERRAIN_WATER)
	assert_eq(grid.get_terrain(Vector2i(34, 6)), MapTypes.TERRAIN_DIRT)
	assert_eq(grid.fingerprint(), MapBuilder.build_legacy(definition).fingerprint())


func test_unload_reload_keeps_content_cache_key_and_global_bounds_stable() -> void:
	var grid: MapTerrainGrid = MapBuilder.build(SmithyCourtyardDefinition.create())
	var renderer: MapTerrainRenderer = MapTerrainRenderer.new(grid)
	var coordinates := Vector2i(1, 0)
	var expected_key := grid.chunk_cache_key(coordinates)
	var first := renderer.load_chunk(coordinates)
	assert_eq(first.get_meta(&"chunk_cache_key"), expected_key)
	assert_eq(first.get_meta(&"chunk_bounds_cells"), Rect2i(32, 0, 18, 28))
	assert_true(renderer.unload_chunk(coordinates))
	assert_eq(renderer.loaded_chunk_count(), 0)
	var second := renderer.load_chunk(coordinates)
	assert_ne(second, first)
	assert_eq(second.get_meta(&"chunk_cache_key"), expected_key)
	var rebuilt := MapBuilder.build(SmithyCourtyardDefinition.create())
	assert_eq(grid.chunk_cache_key(coordinates), rebuilt.chunk_cache_key(coordinates))
	renderer.free()


func test_visible_terrain_nodes_stay_within_five_by_five_resident_bound() -> void:
	var definition: MapDefinition = SmithyCourtyardDefinition.create()
	definition.size_cells = Vector2i(256, 256)
	definition.camera_bounds = Rect2(Vector2.ZERO, definition.world_size())
	definition.fingerprint = "terrain-visible-node-bound"
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	var renderer: MapTerrainRenderer = MapTerrainRenderer.new(grid)
	renderer.update_active_chunks(Vector2(4 * 32 * grid.cell_size, 4 * 32 * grid.cell_size))
	assert_eq(renderer.loaded_chunk_count(), 25)
	assert_eq(renderer.get_child_count(), 25)
	assert_eq(renderer.loaded_cell_bounds(), Rect2i(64, 64, 160, 160))
	renderer.set_debug_chunk_bounds(true)
	for child in renderer.get_children():
		assert_true((child as MapTerrainChunkRenderer).debug_bounds_enabled)
		assert_true(child.has_meta(&"chunk_bounds_cells"))
	assert_true(
		renderer.get_child_count() <= 25,
		"terrain residency must not exceed the configured 5x5 ring"
	)
	renderer.free()


func test_follow_updates_resident_chunks_only_after_crossing_boundary() -> void:
	var definition: MapDefinition = SmithyCourtyardDefinition.create()
	definition.size_cells = Vector2i(256, 256)
	definition.camera_bounds = Rect2(Vector2.ZERO, definition.world_size())
	definition.fingerprint = "terrain-follow-boundary"
	var renderer: MapTerrainRenderer = MapTerrainRenderer.new(MapBuilder.build(definition))
	var player := Node2D.new()
	player.position = Vector2(16, 16) * float(definition.cell_size)
	renderer.follow(player, 0)
	assert_eq(renderer.loaded_chunk_coordinates(), [Vector2i.ZERO])
	player.position = Vector2(32, 16) * float(definition.cell_size)
	renderer.update_active_chunks(player.position, 0)
	assert_eq(renderer.loaded_chunk_coordinates(), [Vector2i(1, 0)])
	player.free()
	renderer.free()


func test_blended_ground_mesh_stores_per_vertex_layer_weights() -> void:
	var definition := MapDefinition.new()
	definition.map_id = &"test_paving_fringe"
	definition.size_cells = Vector2i(4, 2)
	definition.base_terrain = MapTypes.TERRAIN_DIRT
	definition.player_spawn = Vector2(8.0, 8.0)
	definition.location = &"test"
	definition.scope = &"prototype"
	definition.palette = &"spring"
	definition.fingerprint = "test-paving-fringe"
	definition.seed = 991
	definition.zones = [{"rect": Rect2i(0, 0, 2, 2), "terrain": MapTypes.TERRAIN_CASTLE_PAVING}]
	var grid := MapBuilder.build(definition)
	var terrain := MapViewMeshBuilder.build_terrain(definition, grid)
	var ground := terrain.get_node_or_null("Terrain_Ground") as MeshInstance3D
	assert_true(ground != null, "paving edge fixture needs the unified ground mesh")
	var arrays := (ground.mesh as ArrayMesh).surface_get_arrays(0)
	var custom := arrays[Mesh.ARRAY_CUSTOM0] as PackedFloat32Array
	var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	var paving_index := float(MapViewMaterials.terrain_blend_index(MapTypes.TERRAIN_CASTLE_PAVING))
	var earth_index := float(MapViewMaterials.terrain_blend_index(MapTypes.TERRAIN_DIRT))
	var found_mixed_triangle := false
	for i in range(0, indices.size(), 3):
		var corner_a := custom[indices[i] * 4]
		var corner_b := custom[indices[i + 1] * 4]
		var corner_c := custom[indices[i + 2] * 4]
		if corner_a != corner_b or corner_a != corner_c:
			found_mixed_triangle = true
			break
	assert_true(
		found_mixed_triangle,
		"paving strokes must assign different primary layer indices to triangle corners"
	)
	assert_true(custom.has(paving_index), "ground mesh must carry paving layer weights")
	assert_true(custom.has(earth_index), "ground mesh must carry earth layer weights")
	terrain.free()
