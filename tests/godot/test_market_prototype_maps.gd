extends "res://tests/godot/test_case.gd"

const StOlafsGuildHallDefinition := preload("res://scripts/map/definitions/prototypes/st_olafs_guild_hall_definition.gd")
const MarketCivicQuarterDefinition := preload("res://scripts/map/definitions/prototypes/market_civic_quarter_definition.gd")
const NorthQuarterDefinition := preload("res://scripts/map/definitions/prototypes/north_quarter_definition.gd")
const MonasteryQuarterDefinition := preload("res://scripts/map/definitions/prototypes/monastery_quarter_definition.gd")
const ArchbishopsGardenDefinition := preload("res://scripts/map/definitions/prototypes/archbishops_garden_definition.gd")
const ToompeaQuarterDefinition := preload("res://scripts/map/definitions/prototypes/toompea_quarter_definition.gd")
const SouthQuarterDefinition := preload("res://scripts/map/definitions/prototypes/south_quarter_definition.gd")
const LowerTownSliceDefinition := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")
const HarborWarehouseDefinition := preload("res://scripts/map/definitions/prototypes/harbor_warehouse_definition.gd")
const RevalHarborNorthDefinition := preload("res://scripts/map/definitions/outdoor/reval_harbor_north_definition.gd")
const RevalHarborEastDefinition := preload("res://scripts/map/definitions/outdoor/reval_harbor_east_definition.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapVerification := preload("res://scripts/map/map_verification.gd")


func test_market_prototypes_validate_and_stay_inactive() -> void:
	for factory in [StOlafsGuildHallDefinition, MarketCivicQuarterDefinition, NorthQuarterDefinition, MonasteryQuarterDefinition, ArchbishopsGardenDefinition, ToompeaQuarterDefinition, SouthQuarterDefinition, HarborWarehouseDefinition]:
		var definition: MapDefinition = factory.create()
		assert_eq(definition.scope, &"prototype")
		assert_false(definition.active)
		assert_true(MapBuilder.validate(definition).is_empty(), factory.resource_path)


func test_central_district_unifies_market_and_historic_street_junction() -> void:
	var definition: MapDefinition = MarketCivicQuarterDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	assert_eq(definition.size_cells, Vector2i(114, 128))
	for anchor_id in [&"town_hall_edge", &"pikk_street_spine", &"vana_turg_neck", &"karja_lane", &"holy_spirit_frontage", &"market_cross", &"weigh_table"]:
		assert_true(MapVerification.has_anchor(definition, anchor_id), "Missing historic anchor %s" % anchor_id)
		assert_true(MapVerification.route_exists_exact(definition, grid, definition.player_spawn, MapVerification.anchor_position(definition, anchor_id)), "Historic market route is blocked at %s" % anchor_id)
	assert_true(_transition_by_id(definition, &"to_market").is_empty(), "market square must not remain a self-transition")


func test_central_district_square_and_edges_do_not_stop_abruptly() -> void:
	var definition: MapDefinition = MarketCivicQuarterDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	var east_transition := _transition_by_id(definition, &"to_reval_east")
	var town_hall_footprint := _building_by_id(definition, &"town_hall_mass")["footprint"] as Rect2
	assert_eq(grid.get_terrain(Vector2i(74, 60)), MapTypes.TERRAIN_COBBLESTONE, "Raekoja plats needs playable cobble into the expanded east side")
	assert_eq(grid.get_terrain(Vector2i(38, 83)), MapTypes.TERRAIN_COBBLESTONE, "Town Hall needs a southern border street")
	assert_true(float(83 * definition.cell_size) > town_hall_footprint.end.y)
	assert_eq(east_transition["rect"].end.x, definition.world_size().x)
	assert_eq(definition.surroundings_sides.get(&"north"), &"town")
	assert_eq(definition.surroundings_sides.get(&"east"), &"town")


func test_central_district_has_unique_period_building_models() -> void:
	var definition: MapDefinition = MarketCivicQuarterDefinition.create()
	var expected := {
		&"town_hall_mass": &"town_hall_1343",
		&"church_silhouette": &"holy_spirit_chapel_1343",
		&"merchant_gabled_house": &"stepped_gable_merchant",
	}
	for building_id in expected:
		var building := _building_by_id(definition, building_id)
		assert_eq(building.get("primitive", &""), expected[building_id])
		var node := MapViewMeshBuilder.build_building(building, definition.cell_size)
		match building_id:
			&"town_hall_mass":
				var town_hall_footprint := building["footprint"] as Rect2
				assert_true(town_hall_footprint.size.x < 30.0 * definition.cell_size, "Town Hall footprint should not read as an overlong block")
				assert_true(node.has_node("ArcadePier00"))
				assert_true(node.has_node("TownHallGableStep00_E"))
				assert_true(node.has_node("TownHallMarketStoop"))
			&"church_silhouette":
				assert_true(node.has_node("Lancet00"))
				assert_true(node.has_node("SanctusCoteRoof"))
			&"merchant_gabled_house": assert_true(node.has_node("GableStep00"))
		node.free()


func test_market_civic_quarter_edges_are_reciprocal_with_adjacent_districts() -> void:
	var center := MarketCivicQuarterDefinition.create()
	var east := LowerTownSliceDefinition.create()
	var north := NorthQuarterDefinition.create()
	var monastery := MonasteryQuarterDefinition.create()
	var toompea := ToompeaQuarterDefinition.create()
	var garden := ArchbishopsGardenDefinition.create()
	var south := SouthQuarterDefinition.create()
	_assert_transition_pair(center, &"to_reval_east", east, &"vana_turg_boundary")
	_assert_transition_pair(center, &"to_reval_north", monastery, &"to_reval_center")
	_assert_transition_pair(center, &"to_reval_toompea", toompea, &"to_reval_center")
	_assert_transition_pair(center, &"to_reval_south", south, &"to_reval_center")
	_assert_transition_pair(east, &"to_reval_south", south, &"to_reval_east")
	_assert_transition_pair(toompea, &"to_archbishops_garden", garden, &"to_reval_toompea")
	_assert_transition_pair(center, &"to_archbishops_garden", garden, &"to_reval_center")
	_assert_transition_pair(garden, &"to_reval_south", south, &"to_archbishops_garden")
	_assert_transition_pair(toompea, &"to_reval_north", monastery, &"to_reval_toompea")
	_assert_transition_pair(monastery, &"to_reval_north", north, &"to_monastery")
	_assert_transition_pair(east, &"vene_district_boundary", monastery, &"to_reval_east")
	_assert_edge(center, &"to_reval_east", &"east")
	_assert_edge(center, &"to_reval_north", &"north")
	_assert_edge(center, &"to_reval_toompea", &"west")
	_assert_edge(center, &"to_reval_south", &"south")
	_assert_edge(toompea, &"to_reval_center", &"east")
	_assert_edge(toompea, &"to_reval_north", &"east")
	_assert_edge(toompea, &"to_archbishops_garden", &"south")
	_assert_edge(garden, &"to_reval_toompea", &"north")
	_assert_edge(garden, &"to_reval_center", &"east")
	_assert_edge(garden, &"to_reval_south", &"south")
	_assert_edge(south, &"to_reval_center", &"north")
	_assert_edge(south, &"to_reval_east", &"north")
	_assert_edge(south, &"to_archbishops_garden", &"north")
	_assert_edge(east, &"to_reval_south", &"south")
	assert_true(_transition_by_id(east, &"karja_road_boundary").is_empty())


func test_north_quarter_edges_are_reciprocal_with_adjacent_districts() -> void:
	var north := NorthQuarterDefinition.create()
	var monastery := MonasteryQuarterDefinition.create()
	var center := MarketCivicQuarterDefinition.create()
	var east := LowerTownSliceDefinition.create()
	var harbor_north := RevalHarborNorthDefinition.create()
	var harbor_east := RevalHarborEastDefinition.create()
	_assert_transition_pair(center, &"to_reval_north", monastery, &"to_reval_center")
	_assert_transition_pair(east, &"vene_district_boundary", monastery, &"to_reval_east")
	_assert_transition_pair(north, &"to_monastery", monastery, &"to_reval_north")
	_assert_transition_pair(harbor_north, &"to_reval_north", north, &"to_reval_harbor")
	_assert_transition_pair(harbor_north, &"to_harbor_east", harbor_east, &"to_harbor_north")
	_assert_edge(north, &"to_reval_harbor", &"north")
	_assert_edge(north, &"to_monastery", &"south")
	_assert_edge(monastery, &"to_reval_north", &"north")
	_assert_edge(monastery, &"to_reval_center", &"south")
	_assert_edge(monastery, &"to_reval_east", &"south")
	_assert_edge(harbor_north, &"to_reval_north", &"south")
	_assert_edge(harbor_north, &"to_harbor_east", &"east")
	_assert_edge(harbor_east, &"to_harbor_north", &"west")


func test_city_fortifications_wrap_only_outer_district_edges() -> void:
	var center := MarketCivicQuarterDefinition.create()
	var east := LowerTownSliceDefinition.create()
	var north := NorthQuarterDefinition.create()
	var toompea := ToompeaQuarterDefinition.create()
	var garden := ArchbishopsGardenDefinition.create()
	var south := SouthQuarterDefinition.create()
	# The wall is distributed across the city's exterior maps. Shared district
	# seams remain streets, so crossing the Lower Town never requires a gate.
	assert_false(_building_by_id(east, &"city_wall_north").is_empty())
	assert_false(_building_by_id(north, &"city_wall_north_west").is_empty())
	assert_false(_building_by_id(toompea, &"city_wall_north_west").is_empty())
	assert_false(_building_by_id(south, &"city_wall_south_west").is_empty())
	assert_true(_building_by_id(center, &"city_wall_north").is_empty())
	assert_true(_transition_by_id(east, &"karja_road_boundary").is_empty())


func test_south_quarter_garden_gate_and_outer_wall_read_as_authored_edges() -> void:
	var south := SouthQuarterDefinition.create()
	var garden_gate := _transition_by_id(south, &"to_archbishops_garden")
	var gate_landmark := _landmark_by_id(south, &"garden_descent_gate")
	assert_false(garden_gate.is_empty(), "Knights District needs a guarded Archbishop's Garden descent")
	assert_false(gate_landmark.is_empty())
	assert_eq(garden_gate.get("view_landmark_id", &""), &"garden_descent_gate")
	assert_true((gate_landmark["rect"] as Rect2).encloses(garden_gate["rect"]))
	for tower_id in [&"garden_gate_west_tower", &"garden_gate_east_tower", &"south_wall_tower_southwest", &"south_wall_tower_southeast"]:
		assert_true(bool(_building_by_id(south, tower_id).get("tower", false)), "%s must be circular" % tower_id)
	assert_eq(south.surroundings_sides.get(&"south"), &"woodland")


func test_east_and_south_quarter_wall_preview_edges_align() -> void:
	var east := LowerTownSliceDefinition.create()
	var south := SouthQuarterDefinition.create()
	var east_transition := _transition_by_id(east, &"to_reval_south")
	var south_transition := _transition_by_id(south, &"to_reval_east")
	var east_wall := _building_by_id(east, &"city_wall_south_continuation")
	var south_wall := _building_by_id(south, &"city_wall_east_north_a")
	var offset_cells := _preview_offset(east, south, east_transition, south_transition, &"south")
	var preview_wall_x := (south_wall["footprint"] as Rect2).position.x / float(south.cell_size) + offset_cells.x
	var east_wall_x := (east_wall["footprint"] as Rect2).position.x / float(east.cell_size)
	assert_true(absf(preview_wall_x - east_wall_x) <= 1.0, "Knights District preview wall must continue Workers' District wall")


func test_south_quarter_outer_wall_has_landscape_continuation() -> void:
	var south := SouthQuarterDefinition.create()
	var view := MapView3D.create(south, MapBuilder.build(south))
	assert_true(view.has_node("Surroundings/WoodlandApron_south"), "outer wall needs view-only terrain beyond max zoom")
	assert_false(view.has_node("Surroundings/TownApron_south"), "outer wall must not read as houses outside the fortification")
	assert_true(view.has_node("Surroundings/Trunks"), "outer wall landscape needs non-flat tree silhouettes")
	view.free()


func test_guild_hall_assembly_nav_and_anchors() -> void:
	var definition: MapDefinition = StOlafsGuildHallDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	assert_true(MapVerification.has_anchor(definition, &"dais"))
	assert_true(MapVerification.route_exists(definition, grid, definition.player_spawn, MapVerification.anchor_position(definition, &"dais")))
	assert_true(MapVerification.collision_parity(definition))


func _assert_transition_pair(from_definition: MapDefinition, from_id: StringName, to_definition: MapDefinition, to_id: StringName) -> void:
	var outgoing := _transition_by_id(from_definition, from_id)
	var returning := _transition_by_id(to_definition, to_id)
	assert_false(outgoing.is_empty(), "%s is missing transition %s" % [from_definition.map_id, from_id])
	assert_false(returning.is_empty(), "%s is missing transition %s" % [to_definition.map_id, to_id])
	if outgoing.is_empty() or returning.is_empty(): return
	assert_eq(outgoing["destination_spawn_id"], returning["spawn_id"])
	assert_eq(outgoing["spawn_id"], returning["destination_spawn_id"])


func _assert_edge(definition: MapDefinition, transition_id: StringName, edge: StringName) -> void:
	var transition := _transition_by_id(definition, transition_id)
	assert_false(transition.is_empty())
	if transition.is_empty(): return
	var rect: Rect2 = transition["rect"]
	var bounds := _play_bounds(definition)
	match edge:
		&"north": assert_eq(rect.position.y, bounds.position.y)
		&"east": assert_eq(rect.end.x, bounds.end.x)
		&"south": assert_eq(rect.end.y, bounds.end.y)
		&"west": assert_eq(rect.position.x, bounds.position.x)


func _play_bounds(definition: MapDefinition) -> Rect2:
	if definition.camera_bounds.size.x > 0.0 and definition.camera_bounds.size.y > 0.0:
		return definition.camera_bounds
	return Rect2(Vector2.ZERO, definition.world_size())


func _preview_offset(
	definition: MapDefinition,
	neighbor: MapDefinition,
	transition: Dictionary,
	reciprocal: Dictionary,
	side: StringName
) -> Vector2:
	var scale := 1.0 / float(definition.cell_size)
	var current_center: Vector2 = transition["rect"].get_center() * scale
	var neighbor_center: Vector2 = reciprocal["rect"].get_center() * scale
	match side:
		&"west":
			return Vector2(-neighbor.size_cells.x, current_center.y - neighbor_center.y)
		&"east":
			return Vector2(definition.size_cells.x, current_center.y - neighbor_center.y)
		&"north":
			return Vector2(current_center.x - neighbor_center.x, -neighbor.size_cells.y)
		_:
			return Vector2(current_center.x - neighbor_center.x, definition.size_cells.y)


func _transition_by_id(definition: MapDefinition, transition_id: StringName) -> Dictionary:
	for transition in definition.transitions:
		if transition["id"] == transition_id: return transition
	return {}


func _building_by_id(definition: MapDefinition, building_id: StringName) -> Dictionary:
	for building in definition.buildings:
		if building["id"] == building_id: return building
	return {}


func _landmark_by_id(definition: MapDefinition, landmark_id: StringName) -> Dictionary:
	for landmark in definition.view_landmarks:
		if landmark["id"] == landmark_id: return landmark
	return {}
