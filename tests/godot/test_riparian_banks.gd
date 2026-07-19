extends "res://tests/godot/map_view_3d_test_base.gd"

const TerrainBuilder := preload("res://scripts/map/view3d/map_view_mesh_builder_terrain.gd")


func test_natural_riverbank_adds_sand_and_mud_without_changing_grid() -> void:
	var definition := _shore_definition(MapTypes.TERRAIN_GRASS)
	var grid := MapBuilder.build(definition)
	var fingerprint_before := grid.fingerprint()
	var field := TerrainBuilder.ensure_height_field(definition, grid)
	var samples := _shore_samples(field, grid)

	assert_true(samples.has("sand"), "a natural river edge needs a sandy transition band")
	assert_true(samples.has("mud"), "a natural river edge needs wet mud at the waterline")
	assert_eq(grid.fingerprint(), fingerprint_before, "visual shoreline bands must not alter gameplay terrain")


func test_hard_quay_does_not_receive_natural_bank() -> void:
	var definition := _shore_definition(MapTypes.TERRAIN_COBBLESTONE)
	var grid := MapBuilder.build(definition)
	var field := TerrainBuilder.ensure_height_field(definition, grid)
	var found_shore_blend := false
	for y in grid.size_cells.y:
		for x in grid.size_cells.x:
			for patch_y in MapViewMeshBuilderConfig.TERRAIN_SUBDIVISIONS:
				for patch_x in MapViewMeshBuilderConfig.TERRAIN_SUBDIVISIONS:
					var sample := Vector2(x, y) + Vector2(patch_x, patch_y) / float(MapViewMeshBuilderConfig.TERRAIN_SUBDIVISIONS)
					found_shore_blend = found_shore_blend or not TerrainBuilder.shore_blend_at(field, grid, sample, definition.seed).is_empty()
	assert_false(found_shore_blend, "stone quay edges must retain their authored hard surface")


func test_natural_bank_scatter_builds_cattail_clusters() -> void:
	var definition := _shore_definition(MapTypes.TERRAIN_GRASS)
	definition.seed = _seed_with_cattails(definition)
	var grid := MapBuilder.build(definition)
	var scatter := MapViewMeshBuilder.build_scatter(definition, grid)
	var cattails := scatter.get_node_or_null("BankCattails") as MultiMeshInstance3D

	assert_true(cattails != null, "natural riverbanks should grow view-only cattail clusters")
	if cattails != null:
		assert_true(cattails.multimesh.instance_count > 0, "cattail layer needs visible instances")
		assert_true(cattails.multimesh.mesh is ArrayMesh, "cattails need generated leaf and seed-head geometry")
		var arrays := (cattails.multimesh.mesh as ArrayMesh).surface_get_arrays(0)
		var colors := arrays[Mesh.ARRAY_COLOR] as PackedColorArray
		assert_true(not colors.is_empty(), "cattail mesh needs per-vertex foliage and seed-head colors")
	scatter.free()


func _shore_definition(base_terrain: StringName) -> MapDefinition:
	var definition := MapDefinition.new()
	definition.map_id = &"test_riparian_bank_%s" % String(base_terrain)
	definition.size_cells = Vector2i(18, 12)
	definition.base_terrain = base_terrain
	definition.seed = 317
	definition.player_spawn = Vector2(16.0, 16.0)
	definition.location = &"test"
	definition.scope = &"prototype"
	definition.palette = &"spring"
	definition.fingerprint = "test-riparian-bank-%s" % String(base_terrain)
	definition.zones = [{"rect": Rect2i(6, 0, 6, 12), "terrain": MapTypes.TERRAIN_WATER}]
	return definition


func _shore_samples(field: Dictionary, grid: MapTerrainGrid) -> Dictionary:
	var found := {}
	for y in grid.size_cells.y:
		for x in grid.size_cells.x:
			for patch_y in MapViewMeshBuilderConfig.TERRAIN_SUBDIVISIONS:
				for patch_x in MapViewMeshBuilderConfig.TERRAIN_SUBDIVISIONS:
					var sample := Vector2(x, y) + Vector2(patch_x, patch_y) / float(MapViewMeshBuilderConfig.TERRAIN_SUBDIVISIONS)
					var blend := TerrainBuilder.shore_blend_at(field, grid, sample, 317)
					if blend.is_empty():
						continue
					if blend["primary"] == MapTypes.TERRAIN_MUD:
						found["mud"] = true
					if blend["primary"] == MapTypes.TERRAIN_SAND or blend["secondary"] == MapTypes.TERRAIN_SAND:
						found["sand"] = true
	return found


func _seed_with_cattails(definition: MapDefinition) -> int:
	var grid := MapBuilder.build(definition)
	for candidate_seed in range(1, 1000):
		definition.seed = candidate_seed
		MapViewMeshBuilderTerrain._height_fields.erase(String(definition.map_id))
		var field := TerrainBuilder.ensure_height_field(definition, grid)
		for y in grid.size_cells.y:
			for x in grid.size_cells.x:
				if (
					TerrainBuilder.is_natural_shore_cell(field, grid, Vector2i(x, y))
					and MapViewMeshBuilderPrimitives.hash01(x, y, candidate_seed + 2879)
					< MapViewMeshBuilderConfig.SHORE_CATTAIL_CHANCE
				):
					return candidate_seed
	return definition.seed
