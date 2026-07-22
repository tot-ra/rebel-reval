extends "res://tests/godot/test_case.gd"

const LowerTownSliceDefinition := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapTypes := preload("res://scripts/map/map_types.gd")
const MapVerification := preload("res://scripts/map/map_verification.gd")
const MapParitySnapshot := preload("res://scripts/map/map_parity_snapshot.gd")
const PLAYER_SCENE := preload("res://player.tscn")
const PARITY_FIXTURE_PATH := "res://tests/fixtures/maps/lower_town_slice.parity.json"


func test_lower_town_slice_validates() -> void:
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	assert_eq(definition.size_cells, Vector2i(152, 128))
	assert_eq(definition.camera_bounds, definition.cell_rect_to_world_rect(Rect2i(0, 0, 152, 128)))
	var errors: Array[String] = MapBuilder.validate(definition)
	assert_true(errors.is_empty(), str(errors))


func test_lower_town_slice_matches_canonical_parity_fixture() -> void:
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	var fixture := FileAccess.get_file_as_string(PARITY_FIXTURE_PATH)
	assert_false(fixture.is_empty(), "Missing parity fixture: %s" % PARITY_FIXTURE_PATH)
	var actual := MapParitySnapshot.serialize(definition, grid)
	assert_true(
		actual == fixture,
		"lower_town_slice gameplay data changed; regenerate only after reviewing the canonical diff (%s)" % MapParitySnapshot.first_difference(fixture, actual)
	)


func test_parity_serializer_normalizes_dictionary_order_and_floats() -> void:
	var first := {
		"z": -0.0,
		"nested": {"b": Vector2(1.25, 2.0), "a": Color(0.1, 0.2, 0.3, 1.0)},
	}
	var second := {
		"nested": {"a": Color(0.10000000001, 0.2, 0.3, 1), "b": Vector2(1.25, 2)},
		"z": 0.0,
	}
	assert_eq(MapParitySnapshot.serialize_value(first), MapParitySnapshot.serialize_value(second))


func test_parity_snapshot_normalizes_stable_id_collection_order() -> void:
	var first: MapDefinition = LowerTownSliceDefinition.create()
	var second: MapDefinition = LowerTownSliceDefinition.create()
	second.buildings.reverse()
	second.props.reverse()
	second.interaction_anchors.reverse()
	second.transitions.reverse()
	second.view_landmarks.reverse()
	assert_eq(
		MapParitySnapshot.serialize(first, MapBuilder.build(first)),
		MapParitySnapshot.serialize(second, MapBuilder.build(second))
	)


func test_lower_town_required_route_endpoints_reachable() -> void:
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	var start := MapVerification.anchor_position(definition, &"street_start")
	var checks: Array[StringName] = [
		&"smithy_door",
		&"brewery_door",
		&"checkpoint_west",
		&"checkpoint_east",
		&"katariina_kaik",
		&"monastery_gate",
		&"karja_gate_south",
		&"vene_street_north",
	]
	for anchor_id in checks:
		assert_true(
			MapVerification.route_exists(definition, grid, start, MapVerification.anchor_position(definition, anchor_id)),
			"Missing route to %s" % String(anchor_id)
		)


func test_smithy_entrance_is_attached_to_kalev_south_facade() -> void:
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	var transition: Dictionary = {}
	var smithy: Dictionary = {}
	for candidate in definition.transitions:
		if candidate.get("id") == &"smithy_door_transition":
			transition = candidate
	for candidate in definition.buildings:
		if candidate.get("id") == &"kalev_smithy":
			smithy = candidate
	assert_eq(transition.get("building_id"), &"kalev_smithy")
	assert_eq(MapBuildingEntrance.attachment_side(smithy, transition), &"south")
	assert_eq(MapBuildingEntrance.facade_position(smithy, transition), Vector2(2848, 2240))
	assert_true(MapBuildingEntrance.approach_aligns_with_facade(smithy, transition, definition.cell_size))


func test_city_wall_blocks_except_viru_gate() -> void:
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	# Wall cells north of the gate and along the south-east bend must block.
	# The south-west edge is a district seam to the Knights District, not the
	# city's exterior wall.
	assert_true(not MapVerification.is_walkable_cell(definition, grid, Vector2i(111, 22)), "north wall must block")
	assert_true(not MapVerification.is_walkable_cell(definition, grid, Vector2i(90, 95)), "south-east bend must block")
	assert_true(not MapVerification.is_walkable_cell(definition, grid, Vector2i(73, 122)), "south-west bend must block")
	# The moat outside the wall blocks except at the gate causeway.
	assert_true(not MapVerification.is_walkable_cell(definition, grid, Vector2i(123, 22)), "moat must block")
	assert_true(MapVerification.is_walkable_cell(definition, grid, Vector2i(123, 54)), "causeway must stay open")
	# The gate passage itself stays open from Viru street to the east road.
	var inside := definition.cell_rect_center(Rect2i(104, 54, 1, 1))
	var outside := definition.cell_rect_center(Rect2i(140, 54, 1, 1))
	var region := MapNavBuilder.create_navigation_region(definition, grid)
	assert_true(
		MapVerification.route_exists_exact(definition, grid, inside, outside),
		"Viru street must pass through the gate to the east road"
	)
	assert_true(
		_navigation_points_connected(region.navigation_polygon, inside, outside),
		"merged water obstructions must keep Viru causeway connected in the baked navigation mesh"
	)
	region.free()


func test_south_quarter_seam_stays_inside_the_city_wall() -> void:
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	assert_true(MapVerification.is_walkable_cell(definition, grid, Vector2i(62, 124)), "Karja/Vaike-Karja seam must stay walkable")
	assert_true(MapVerification.is_walkable_cell(definition, grid, Vector2i(65, 127)), "knights-district transition must be street terrain")
	var inside := definition.cell_rect_center(Rect2i(64, 116, 1, 1))
	var outside := definition.cell_rect_center(Rect2i(64, 127, 1, 1))
	var region := MapNavBuilder.create_navigation_region(definition, grid)
	assert_true(
		MapVerification.route_exists_exact(definition, grid, inside, outside),
		"Karja/Vaike-Karja must continue from Workers' District into Knights District inside the walls"
	)
	assert_true(
		_navigation_points_connected(region.navigation_polygon, inside, outside),
		"district seam must stay connected in the baked navigation mesh"
	)
	region.free()


func test_worker_district_ends_at_the_knights_district_seam() -> void:
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	assert_true(not MapVerification.is_walkable_cell(definition, grid, Vector2i(73, 124)), "southern wall continuation must block the district edge")
	var found := false
	for building in definition.buildings:
		if building["id"] != &"city_wall_south_continuation":
			continue
		found = true
		assert_eq(building["footprint"], definition.cell_rect_to_world_rect(Rect2i(73, 121, 4, 7)))
	assert_true(found, "Workers' District needs a continuation wall toward Knights District")


func test_navigation_region_builds_despite_overlapping_wall_footprints() -> void:
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	var region := MapNavBuilder.create_navigation_region(definition, grid)
	assert_true(
		region.navigation_polygon.get_polygon_count() > 0,
		"nav region must produce polygons even with overlapping tower/wall footprints"
	)
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	var collision := player.get_node("CollisionShape2D") as CollisionShape2D
	var capsule := collision.shape as CapsuleShape2D
	assert_eq(
		region.navigation_polygon.agent_radius,
		capsule.radius,
		"click navigation must preserve clearance for the player's physics capsule"
	)
	player.free()
	region.free()


func test_water_cells_are_not_navigable() -> void:
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	var moat_cell := Vector2i(123, 22)
	assert_true(MapTypes.WATER_TERRAINS.has(grid.get_terrain(moat_cell)), "test cell must be water")
	var fingerprint_before := definition.fingerprint
	var grid_fingerprint_before := grid.fingerprint()
	var region := MapNavBuilder.create_navigation_region(definition, grid)
	assert_eq(definition.fingerprint, fingerprint_before, "navigation geometry must not mutate the terrain fingerprint")
	assert_eq(grid.fingerprint(), grid_fingerprint_before, "navigation geometry must not mutate terrain cells")
	var nav_point := definition.cell_rect_center(Rect2i(moat_cell, Vector2i.ONE))
	var vertices := region.navigation_polygon.get_vertices()
	for polygon_index in region.navigation_polygon.get_polygon_count():
		var indices: PackedInt32Array = region.navigation_polygon.get_polygon(polygon_index)
		var poly := PackedVector2Array()
		for vertex_index in indices:
			poly.append(vertices[vertex_index])
		assert_false(
			Geometry2D.is_point_in_polygon(nav_point, poly),
			"water cells must not be inside navigation polygons"
		)
	region.free()


func test_boundary_exits_connect_to_registered_destinations() -> void:
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	var transition_by_id: Dictionary = {}
	for transition in definition.transitions:
		transition_by_id[transition["id"]] = transition
	for transition_id: StringName in [
		&"vana_turg_boundary",
		&"vene_district_boundary",
		&"viru_road_boundary",
		&"to_reval_south",
	]:
		assert_true(transition_by_id.has(transition_id), "missing boundary transition %s" % transition_id)
		var transition: Dictionary = transition_by_id[transition_id]
		assert_eq(transition.get("transition_visual"), MapTypes.TRANSITION_VISUAL_GROUND)
		assert_true(bool(transition.get("highlight_area", false)), "%s needs a ground cue" % transition_id)
		assert_true(String(transition.get("view_landmark_id", "")).is_empty(), "%s must not invent masonry" % transition_id)
		assert_false(
			String(transition.get("destination_scene_id", "")).is_empty(),
			"%s must route to a registered destination" % transition_id
		)
		assert_false(
			String(transition.get("destination_spawn_id", "")).is_empty(),
			"%s must target a stable destination spawn" % transition_id
		)
	# Karja Gate remains the exterior city gate. District travel uses the internal
	# south-west lane and must never be wired through the gate or moat.
	assert_false(transition_by_id.has(&"karja_road_boundary"), "Karja Gate must not be a district shortcut")
	var south: Dictionary = transition_by_id[&"to_reval_south"]
	assert_eq(south.get("transition_visual"), MapTypes.TRANSITION_VISUAL_GROUND)
	assert_true(bool(south.get("highlight_area", false)))
	assert_eq(south.get("spawn_id"), &"from_reval_south")
	assert_eq(south.get("destination_scene_id"), &"reval_south")
	assert_eq(south.get("destination_spawn_id"), &"from_reval_east")


func test_courtyard_anvil_does_not_cover_smithy_door() -> void:
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	var anvil_position := Vector2.ZERO
	for prop in definition.props:
		if prop["id"] == &"courtyard_anvil":
			anvil_position = prop["position"]
	var door_position := MapVerification.anchor_position(definition, &"smithy_door")
	assert_true(
		anvil_position.distance_to(door_position) > float(definition.cell_size * 2),
		"courtyard anvil must remain visually separate from the smithy door"
	)


func test_smithy_exit_opens_into_a_readable_courtyard() -> void:
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	var door := MapVerification.anchor_position(definition, &"smithy_door")
	var spawn := door + Vector2(0, 48)
	assert_true(MapVerification.is_walkable_point(definition, grid, spawn), "smithy exit spawn must be walkable")
	# The old layout put the wall bend within roughly three cells of the player.
	# Keep a broad walkable apron so the default camera shows courtyard and street context.
	for cell in [
		Vector2i(103, 56), Vector2i(105, 56), Vector2i(107, 56), Vector2i(109, 56),
		Vector2i(103, 58), Vector2i(105, 58), Vector2i(107, 58), Vector2i(109, 58),
	]:
		assert_true(MapVerification.is_walkable_cell(definition, grid, cell), "smithy courtyard must stay open at %s" % cell)
	var nearest_wall_distance_cells := INF
	for building in definition.buildings:
		if building.get("kind", &"") != MapTypes.BUILDING_KIND_WALL:
			continue
		var distance_px: float = building["footprint"].get_center().distance_to(spawn)
		nearest_wall_distance_cells = minf(nearest_wall_distance_cells, distance_px / definition.cell_size)
	assert_true(nearest_wall_distance_cells >= 7.0, "city wall must not dominate the smithy exit view")


func test_viru_gate_arch_matches_collision_jamb_span() -> void:
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	var arch: Dictionary = {}
	var north_jamb: Dictionary = {}
	var south_jamb: Dictionary = {}
	for landmark in definition.view_landmarks:
		if landmark.get("id") == &"viru_gate_arch":
			arch = landmark
	for building in definition.buildings:
		match building.get("id"):
			&"viru_gate_north_jamb": north_jamb = building
			&"viru_gate_south_jamb": south_jamb = building
	assert_false(arch.is_empty())
	assert_false(north_jamb.is_empty())
	assert_false(south_jamb.is_empty())
	if arch.is_empty() or north_jamb.is_empty() or south_jamb.is_empty():
		return
	# The gate arch is view-only. Its longitudinal span must stay over both
	# collision jambs without visually claiming the open smithy apron to the west.
	var arch_rect: Rect2 = arch["rect"]
	assert_eq(arch_rect.position.x, (south_jamb["footprint"] as Rect2).position.x)
	assert_eq(arch_rect.end.x, (south_jamb["footprint"] as Rect2).end.x)
	assert_true((north_jamb["footprint"] as Rect2).encloses(Rect2(arch_rect.position.x, (north_jamb["footprint"] as Rect2).position.y, arch_rect.size.x, (north_jamb["footprint"] as Rect2).size.y)))


func _navigation_points_connected(nav_polygon: NavigationPolygon, start: Vector2, target: Vector2) -> bool:
	var vertices := nav_polygon.get_vertices()
	var start_polygon := -1
	var target_polygon := -1
	var adjacency: Dictionary = {}
	var edge_owners: Dictionary = {}
	for polygon_index in nav_polygon.get_polygon_count():
		adjacency[polygon_index] = {}
		var indices := nav_polygon.get_polygon(polygon_index)
		var outline := PackedVector2Array()
		for vertex_index in indices:
			outline.append(vertices[vertex_index])
		if Geometry2D.is_point_in_polygon(start, outline):
			start_polygon = polygon_index
		if Geometry2D.is_point_in_polygon(target, outline):
			target_polygon = polygon_index
		for edge_index in indices.size():
			var first := int(indices[edge_index])
			var second := int(indices[(edge_index + 1) % indices.size()])
			var edge := Vector2i(mini(first, second), maxi(first, second))
			if edge_owners.has(edge):
				var neighbor := int(edge_owners[edge])
				adjacency[polygon_index][neighbor] = true
				adjacency[neighbor][polygon_index] = true
			else:
				edge_owners[edge] = polygon_index
	if start_polygon < 0 or target_polygon < 0:
		return false

	var pending: Array[int] = [start_polygon]
	var visited := {start_polygon: true}
	while not pending.is_empty():
		var current: int = pending.pop_front()
		if current == target_polygon:
			return true
		for neighbor: int in adjacency[current]:
			if not visited.has(neighbor):
				visited[neighbor] = true
				pending.append(neighbor)
	return false
