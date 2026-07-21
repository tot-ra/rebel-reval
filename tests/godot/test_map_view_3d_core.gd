extends "res://tests/godot/map_view_3d_test_base.gd"

## P0-052: core bridge, rendering parity, terrain density, materials, and occlusion.


func test_bridge_maps_logic_axes_to_world_axes() -> void:
	var world := MapViewBridge.logic_to_world(Vector2(96.0, 64.0), 32)
	assert_eq(world, Vector3(3.0, 0.0, 2.0), "logic (x, y) must map to world (x, 0, z)")
	var logic := MapViewBridge.world_to_logic(world, 32)
	assert_eq(logic, Vector2(96.0, 64.0), "bridge round trip must be exact")
	assert_eq(
		MapViewBridge.logic_to_world(Vector2(96.0, 64.0), 32),
		MapViewBridge.logic_to_world(Vector2(96.0, 64.0), 32),
		"bridge must be deterministic"
	)
	assert_eq(MapViewBridge.cell_center_to_world(Vector2i(0, 0), 32), Vector3(0.5, 0.0, 0.5))


func test_actor_sync_matches_anchors_within_one_cell() -> void:
	for definition in _view_definitions():
		var grid := MapBuilder.build(definition)
		var view := MapView3D.create(definition, grid)
		var actor := Node3D.new()
		for anchor in definition.interaction_anchors:
			var anchor_position: Vector2 = anchor["position"]
			view.sync_actor(actor, anchor_position)
			var logic_back := MapViewBridge.world_to_logic(actor.position, definition.cell_size)
			assert_true(
				logic_back.distance_to(anchor_position) < float(definition.cell_size),
				"%s: synced actor must sit within one logic cell of anchor %s"
					% [definition.map_id, anchor["id"]]
			)
			var marker := view.get_node("Anchors/%s" % String(anchor["id"])) as Marker3D
			assert_true(marker != null, "%s: anchor marker missing for %s" % [definition.map_id, anchor["id"]])
			assert_true(
				marker.position.distance_to(actor.position) < 1.0,
				"%s: anchor marker and synced actor must agree within one cell" % definition.map_id
			)
		actor.free()
		view.free()


func test_gameplay_view_keeps_western_lower_town_frontage_resident() -> void:
	var definition := LowerTownSlice.create()
	var view := MapView3D.create(definition, MapBuilder.build(definition))
	var streamer := view.object_streamer()
	assert_true(
		streamer.loaded_instance(&"west_lane_house") != null,
		"the western frontage visible from the start camera must not stream out"
	)
	assert_true(
		streamer.loaded_instance(&"hedge_house") != null,
		"the south-west frontage visible from the start camera must not stream out"
	)
	view.free()


func test_view_renders_definitions_without_touching_logic_results() -> void:
	for definition in _view_definitions():
		var grid := MapBuilder.build(definition)
		var fingerprint_before := grid.fingerprint()
		var definition_fingerprint_before := definition.fingerprint
		var blocked_before := MapVerification.blocked_cells(definition).hash()

		var view := MapView3D.create(definition, grid)
		view.activate_all_chunks()

		var terrain := view.get_node("Terrain")
		var water_layers := 0
		var dry_used := false
		for terrain_id in grid.used_terrain_ids():
			if MapViewMaterials.WATER_TERRAINS.has(terrain_id):
				water_layers += 1
			else:
				dry_used = true
		var expected_terrain_children := water_layers + (1 if dry_used else 0)
		assert_eq(
			terrain.get_child_count(),
			expected_terrain_children,
			"%s: dry terrain uses one blended ground mesh plus one mesh per water family" % definition.map_id
		)
		assert_eq(
			view.get_node("Buildings").get_child_count(),
			definition.buildings.size(),
			"%s: one building node per definition building" % definition.map_id
		)
		assert_eq(
			view.get_node("Props").get_child_count(),
			definition.props.size(),
			"%s: one prop node per definition prop" % definition.map_id
		)
		var functional_transition_count := 0
		var highlighted_transition_count := 0
		var visible_door_count := 0
		for transition in definition.transitions:
			if not String(transition.get("destination_scene_id", "")).is_empty():
				functional_transition_count += 1
				if transition.get("transition_visual", MapTypes.TRANSITION_VISUAL_DOOR) == MapTypes.TRANSITION_VISUAL_DOOR \
						and not MapViewMeshBuilder.transition_uses_landmark_visual(definition, transition):
					visible_door_count += 1
			if bool(transition.get("highlight_area", false)):
				highlighted_transition_count += 1
		assert_eq(
			view.get_node("Doors").get_child_count(),
			visible_door_count,
			"%s: framed doors only where no gate arch landmark owns the threshold" % definition.map_id
		)
		assert_eq(
			view.get_node("TransitionMarkers").get_child_count(),
			highlighted_transition_count,
			"%s: every highlighted transition needs one visible ground marker" % definition.map_id
		)

		var camera := view.view_camera()
		assert_eq(camera.projection, Camera3D.PROJECTION_ORTHOGONAL, "camera must be orthographic")
		assert_true(
			camera.rotation_degrees.is_equal_approx(Vector3(-30.0, 45.0, 0.0)),
			"%s: camera must keep the fixed dimetric framing" % definition.map_id
		)

		var sun := view.sun_light()
		assert_true(sun is DirectionalLight3D, "sun must be a DirectionalLight3D")
		assert_true(sun.shadow_enabled, "sun must cast real shadows")
		assert_eq(
			sun.directional_shadow_mode,
			DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS,
			"%s: sun must use four cascades for gameplay shadow detail" % definition.map_id
		)
		assert_true(
			sun.directional_shadow_max_distance < MapView3D.CAMERA_FAR,
			"%s: shadow distance must stay tighter than the camera far plane" % definition.map_id
		)
		assert_true(sun.directional_shadow_blend_splits, "sun must blend cascade splits")
		assert_eq(sun.shadow_blur, 0.0, "sun must not add extra shadow blur")
		assert_eq(sun.light_angular_distance, 0.0, "sun must use hard shadows")

		assert_eq(grid.fingerprint(), fingerprint_before, "%s: grid fingerprint must be unchanged" % definition.map_id)
		assert_eq(definition.fingerprint, definition_fingerprint_before, "%s: definition fingerprint must be unchanged" % definition.map_id)
		assert_eq(
			MapVerification.blocked_cells(definition).hash(),
			blocked_before,
			"%s: collision cells must be unchanged" % definition.map_id
		)
		assert_true(MapVerification.collision_parity(definition), "%s: 2D collision parity must still hold" % definition.map_id)
		assert_true(definition.validate().is_empty(), "%s: definition must still validate" % definition.map_id)
		view.free()


func test_terrain_uses_blended_ground_mesh() -> void:
	var definition := LowerTownSlice.create()
	var view := MapView3D.create(definition, MapBuilder.build(definition))
	var ground := view.get_node("Terrain/Terrain_Ground") as MeshInstance3D
	assert_true(ground != null, "outdoor maps need a unified blended ground mesh")
	assert_true(ground.material_override is ShaderMaterial, "ground must use the terrain splat shader")
	view.free()


func test_terrain_uses_dense_subcell_geometry() -> void:
	var definition := LowerTownSlice.create()
	var grid := MapBuilder.build(definition)
	var view := MapView3D.create(definition, grid)
	var vertex_count := 0
	for terrain_mesh: MeshInstance3D in view.get_node("Terrain").get_children():
		var mesh := terrain_mesh.mesh as ArrayMesh
		for surface_index in mesh.get_surface_count():
			var index_count := mesh.surface_get_array_index_len(surface_index)
			vertex_count += index_count if index_count > 0 else mesh.surface_get_array_len(surface_index)
	var minimum_dense_budget := (
		grid.size_cells.x
		* grid.size_cells.y
		* (MapViewMeshBuilder.TERRAIN_SUBDIVISIONS * MapViewMeshBuilder.TERRAIN_SUBDIVISIONS - 1)
		* 6
	)
	assert_true(vertex_count >= minimum_dense_budget, "terrain must retain at least eight visual patches per logic cell")
	view.free()



func test_water_contour_cuts_square_corners_diagonally() -> void:
	var definition := MapDefinition.new()
	definition.map_id = &"test_water_contour"
	definition.size_cells = Vector2i(3, 3)
	definition.base_terrain = MapTypes.TERRAIN_GRASS
	definition.player_spawn = Vector2(16.0, 16.0)
	definition.location = &"test"
	definition.scope = &"prototype"
	definition.palette = &"spring"
	definition.fingerprint = "test-water-contour"
	definition.zones = [{"rect": Rect2i(1, 1, 1, 1), "terrain": MapTypes.TERRAIN_WATER}]
	var grid := MapBuilder.build(definition)
	# Water contour helpers live on the terrain-water module after the mesh-builder split.
	var water_builder := preload("res://scripts/map/view3d/map_view_mesh_builder_terrain_water.gd")
	var field := {"water_contours": {MapTypes.TERRAIN_WATER: water_builder.bake_water_contour(grid, MapTypes.TERRAIN_WATER)}}
	assert_true(
		water_builder.water_coverage_at(field, Vector2(1.5, 1.5), MapTypes.TERRAIN_WATER) > 0.0,
		"water center must contribute to the broad visual contour"
	)
	assert_true(
		water_builder.water_coverage_at(field, Vector2(1.0, 1.0), MapTypes.TERRAIN_WATER)
		< water_builder.water_coverage_at(field, Vector2(1.5, 1.5), MapTypes.TERRAIN_WATER),
		"the visual water contour must round a square cell corner"
	)
	var terrain := MapViewMeshBuilder.build_terrain(definition, grid)
	assert_true(terrain.has_node("Terrain_water"), "contoured water must still produce an animated surface")
	assert_true(terrain.has_node("Terrain_Ground"), "clipped shoreline needs a recessed ground bed under its cut corners")
	var water_mesh := terrain.get_node("Terrain_water") as MeshInstance3D
	var water_arrays := (water_mesh.mesh as ArrayMesh).surface_get_arrays(0)
	var water_colors := water_arrays[Mesh.ARRAY_COLOR] as PackedColorArray
	assert_true(not water_colors.is_empty(), "water vertices must carry shoreline distance")
	var has_shore_vertex := false
	var has_interior_vertex := false
	for color in water_colors:
		has_shore_vertex = has_shore_vertex or color.r <= 0.01
		has_interior_vertex = has_interior_vertex or color.r > 0.01
	assert_true(has_shore_vertex, "clipped contour vertices must identify the shoreline for foam")
	assert_true(has_interior_vertex, "water vertices inside the contour must fade foam away from shore")
	terrain.free()


func test_ground_mesh_reuses_indexed_subcell_vertices() -> void:
	var definition := MapDefinition.new()
	definition.map_id = &"test_indexed_ground"
	definition.size_cells = Vector2i(4, 3)
	definition.base_terrain = MapTypes.TERRAIN_GRASS
	definition.player_spawn = Vector2(16.0, 16.0)
	definition.location = &"test"
	definition.scope = &"prototype"
	definition.palette = &"spring"
	definition.fingerprint = "test-indexed-ground"
	var grid := MapBuilder.build(definition)
	var terrain := MapViewMeshBuilder.build_terrain(definition, grid)
	var ground := terrain.get_node("Terrain_Ground") as MeshInstance3D
	var mesh := ground.mesh as ArrayMesh
	var subdivisions := MapViewMeshBuilder.TERRAIN_SUBDIVISIONS
	var expected_vertices := (
		(grid.size_cells.x * subdivisions + 1)
		* (grid.size_cells.y * subdivisions + 1)
	)
	var expected_indices := grid.size_cells.x * grid.size_cells.y * subdivisions * subdivisions * 6
	assert_eq(mesh.surface_get_array_len(0), expected_vertices, "ground must store each shared grid vertex once")
	assert_eq(mesh.surface_get_array_index_len(0), expected_indices, "ground must retain every dense terrain triangle")
	assert_true(expected_vertices * 3 < expected_indices, "indexed storage must avoid the old duplicated-vertex cost")
	terrain.free()


func test_height_field_cache_distinguishes_same_map_id_grid_rebuilds() -> void:
	var first := _flat_terrain_definition(&"test_height_cache_rebuild", Vector2i(4, 3))
	var first_terrain := MapViewMeshBuilder.build_terrain(first, MapBuilder.build(first))
	first_terrain.free()

	var second := _flat_terrain_definition(&"test_height_cache_rebuild", Vector2i(7, 5))
	var second_grid := MapBuilder.build(second)
	var second_terrain := MapViewMeshBuilder.build_terrain(second, second_grid)
	var ground := second_terrain.get_node("Terrain_Ground") as MeshInstance3D
	var mesh := ground.mesh as ArrayMesh
	var subdivisions := MapViewMeshBuilder.TERRAIN_SUBDIVISIONS
	var expected_vertices := (
		(second_grid.size_cells.x * subdivisions + 1)
		* (second_grid.size_cells.y * subdivisions + 1)
	)
	assert_eq(
		mesh.surface_get_array_len(0),
		expected_vertices,
		"same-map-id terrain rebuilds must not reuse a stale baked vertex field"
	)
	assert_true(
		MapViewMeshBuilder.ground_height(second, Vector2(6.5, 4.5)) != 0.0,
		"actor terrain sampling must resolve the rebuilt field for the current definition"
	)
	second_terrain.free()


func test_empty_terrain_grid_skips_ground_mesh_without_index_errors() -> void:
	var definition := _flat_terrain_definition(&"test_empty_terrain_grid", Vector2i(4, 3))
	var terrain := MapViewMeshBuilder.build_terrain(definition, MapTerrainGrid.new())
	assert_eq(terrain.get_child_count(), 0, "empty terrain grids must not produce geometry")
	terrain.free()


func test_authored_ground_elevation_creates_a_tapered_plateau() -> void:
	var definition := _flat_terrain_definition(&"test_elevated_plateau", Vector2i(24, 24))
	definition.ground_elevation = 3.0
	var terrain := MapViewMeshBuilder.build_terrain(definition, MapBuilder.build(definition))
	var center_height := MapViewMeshBuilder.ground_height(definition, Vector2(12.0, 12.0))
	var edge_height := MapViewMeshBuilder.ground_height(definition, Vector2(0.0, 12.0))
	assert_true(center_height > 2.5, "authored elevation must lift the map interior")
	assert_true(absf(edge_height) < 0.1, "elevation must taper at map boundaries for connected approaches")
	terrain.free()


func _flat_terrain_definition(map_id: StringName, size_cells: Vector2i) -> MapDefinition:
	var definition := MapDefinition.new()
	definition.map_id = map_id
	definition.size_cells = size_cells
	definition.base_terrain = MapTypes.TERRAIN_GRASS
	definition.player_spawn = Vector2(16.0, 16.0)
	definition.location = &"test"
	definition.scope = &"prototype"
	definition.palette = &"spring"
	definition.seed = 8101
	definition.fingerprint = "test-height-cache-%s" % size_cells
	return definition


func test_lower_town_water_contour_smooths_multiple_authored_cells() -> void:
	var definition := LowerTownSlice.create()
	var grid := MapBuilder.build(definition)
	var water_builder := preload("res://scripts/map/view3d/map_view_mesh_builder_terrain_water.gd")
	var contour := water_builder.bake_water_contour(grid, MapTypes.TERRAIN_WATER)
	assert_true(float(contour["max_coverage"]) >= MapViewMeshBuilderConfig.WATER_CONTOUR_THRESHOLD)
	var field := {"water_contours": {MapTypes.TERRAIN_WATER: contour}}

	var changed_cells := 0
	for y in grid.size_cells.y:
		for x in grid.size_cells.x:
			var authored_water := grid.get_terrain(Vector2i(x, y)) == MapTypes.TERRAIN_WATER
			var visible_water := water_builder.water_coverage_at(
				field, Vector2(x, y) + Vector2(0.5, 0.5), MapTypes.TERRAIN_WATER
			) >= MapViewMeshBuilderConfig.WATER_CONTOUR_THRESHOLD
			if authored_water != visible_water:
				changed_cells += 1
	assert_true(changed_cells >= 12, "Lower Town river smoothing must visibly reshape several full cells")


func test_water_material_uses_depth_aware_optics() -> void:
	var material := MapViewMaterials.water_surface(MapTypes.TERRAIN_WATER)
	assert_true(material is ShaderMaterial, "water must use the animated spatial shader")
	var source := material.shader.code
	assert_true("hint_screen_texture" in source, "water must refract the rendered river bed")
	assert_true("hint_depth_texture" in source, "water must derive absorption from scene depth")
	assert_true("INV_PROJECTION_MATRIX" in source, "water depth must be reconstructed in view space")
	assert_true("shore_factor" in source, "water must consume the baked shoreline distance")
	assert_true("fresnel" in source, "water needs angle-dependent reflection")
	assert_true("sun_visibility" in source, "water specular must gate on the sky sun disk")
	assert_true("day_blend" in source, "water sky reflection must follow day/night")
	assert_true("warp_position" in source, "water waves must warp their phase to avoid repeating bands")
	assert_true("amplitude_variation" in source, "water needs spatially varied wave strength")
	assert_true("TANGENT" not in source, "procedural water has no tangent basis to perturb safely")
	assert_true(float(material.get_shader_parameter("wave_height")) > 0.0)
	assert_true(float(material.get_shader_parameter("wave_chaos")) > 0.0)
	assert_true(float(material.get_shader_parameter("depth_absorption")) > 0.0)

func test_placeholder_materials_cover_every_terrain() -> void:
	for terrain_id in MapTypes.ALL_TERRAINS:
		var material := MapViewMaterials.terrain(terrain_id, MapTypes.DEFAULT_SEED)
		assert_ne(material.albedo_color, Color.MAGENTA, "%s: terrain needs a placeholder material" % terrain_id)
		assert_true(material.albedo_texture != null, "%s: placeholder material needs procedural detail" % terrain_id)


func test_occlusion_query_flags_actors_behind_masses_only() -> void:
	var definition := LowerTownSlice.create()
	var view := MapView3D.create(definition, MapBuilder.build(definition))
	var toward_camera: Vector3 = view.view_camera().transform.basis.z * MapView3D.CAMERA_DISTANCE
	var away := Vector3(toward_camera.x, 0.0, toward_camera.z).normalized()
	var scale := MapViewBridge.world_scale(definition.cell_size)

	var wall: Dictionary = {}
	for building in definition.buildings:
		if building["id"] == &"city_wall_north":
			wall = building
	assert_false(wall.is_empty(), "Lower Town slice must keep its north wall")
	var footprint: Rect2 = wall["footprint"]
	var center := footprint.get_center() * scale
	var half_depth := footprint.size * scale * 0.5
	var hidden := Vector3(center.x, 0.0, center.y) - away * (maxf(half_depth.x, half_depth.y) + 1.0)
	assert_true(
		view.is_segment_occluded(hidden + Vector3.UP, hidden + Vector3.UP + toward_camera),
		"an actor tucked behind the town wall must read as occluded"
	)

	var world_units := Vector2(definition.size_cells)
	var open := Vector3(world_units.x, 0.0, world_units.y) + away * 4.0
	assert_false(
		view.is_segment_occluded(open + Vector3.UP, open + Vector3.UP + toward_camera),
		"an actor on the camera side of every mass must not read as occluded"
	)
	view.free()
