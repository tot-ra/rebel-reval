extends "res://tests/godot/test_case.gd"

const StOlafsGuildHallDefinition := preload("res://scripts/map/definitions/prototypes/st_olafs_guild_hall_definition.gd")
const MarketCivicQuarterDefinition := preload("res://scripts/map/definitions/prototypes/market_civic_quarter_definition.gd")
const NorthQuarterDefinition := preload("res://scripts/map/definitions/prototypes/north_quarter_definition.gd")
const ToompeaQuarterDefinition := preload("res://scripts/map/definitions/prototypes/toompea_quarter_definition.gd")
const SouthQuarterDefinition := preload("res://scripts/map/definitions/prototypes/south_quarter_definition.gd")
const LowerTownSliceDefinition := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")
const HarborWarehouseDefinition := preload("res://scripts/map/definitions/prototypes/harbor_warehouse_definition.gd")
const RevalHarborDefinition := preload("res://scripts/map/definitions/outdoor/reval_harbor_definition.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapVerification := preload("res://scripts/map/map_verification.gd")


func test_market_prototypes_validate_and_stay_inactive() -> void:
	for factory in [StOlafsGuildHallDefinition, MarketCivicQuarterDefinition, NorthQuarterDefinition, ToompeaQuarterDefinition, SouthQuarterDefinition, HarborWarehouseDefinition]:
		var definition: MapDefinition = factory.create()
		assert_eq(definition.scope, &"prototype")
		assert_false(definition.active)
		assert_true(MapBuilder.validate(definition).is_empty(), factory.resource_path)


func test_central_district_unifies_market_and_historic_street_junction() -> void:
	var definition: MapDefinition = MarketCivicQuarterDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	assert_eq(definition.size_cells, Vector2i(80, 48))
	for anchor_id in [&"town_hall_edge", &"pikk_street_spine", &"vana_turg_neck", &"karja_lane", &"holy_spirit_frontage", &"market_cross", &"weigh_table"]:
		assert_true(MapVerification.has_anchor(definition, anchor_id), "Missing historic anchor %s" % anchor_id)
		assert_true(MapVerification.route_exists_exact(definition, grid, definition.player_spawn, MapVerification.anchor_position(definition, anchor_id)), "Historic market route is blocked at %s" % anchor_id)
	assert_true(_transition_by_id(definition, &"to_market").is_empty(), "market square must not remain a self-transition")


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
			&"town_hall_mass": assert_true(node.has_node("ArcadePier00"))
			&"church_silhouette":
				assert_true(node.has_node("Lancet00"))
				assert_true(node.has_node("SanctusCoteRoof"))
			&"merchant_gabled_house": assert_true(node.has_node("GableStep00"))
		node.free()


func test_market_civic_quarter_edges_are_reciprocal_with_adjacent_districts() -> void:
	var center := MarketCivicQuarterDefinition.create()
	var east := LowerTownSliceDefinition.create()
	var north := NorthQuarterDefinition.create()
	var toompea := ToompeaQuarterDefinition.create()
	var south := SouthQuarterDefinition.create()
	_assert_transition_pair(center, &"to_reval_east", east, &"vana_turg_boundary")
	_assert_transition_pair(center, &"to_reval_north", north, &"to_reval_center")
	_assert_transition_pair(center, &"to_reval_toompea", toompea, &"to_reval_center")
	_assert_transition_pair(center, &"to_reval_south", south, &"to_reval_center")
	_assert_transition_pair(east, &"to_reval_south", south, &"to_reval_east")
	_assert_transition_pair(toompea, &"to_reval_south", south, &"to_reval_toompea")
	_assert_transition_pair(toompea, &"to_reval_north", north, &"to_reval_toompea")
	_assert_edge(center, &"to_reval_east", &"east")
	_assert_edge(center, &"to_reval_north", &"north")
	_assert_edge(center, &"to_reval_toompea", &"west")
	_assert_edge(center, &"to_reval_south", &"south")
	_assert_edge(toompea, &"to_reval_center", &"east")
	_assert_edge(toompea, &"to_reval_north", &"north")
	_assert_edge(toompea, &"to_reval_south", &"south")
	_assert_edge(south, &"to_reval_center", &"north")
	_assert_edge(south, &"to_reval_east", &"east")
	_assert_edge(south, &"to_reval_toompea", &"west")
	_assert_edge(east, &"to_reval_south", &"west")
	assert_true(_transition_by_id(east, &"karja_road_boundary").is_empty())


func test_north_quarter_edges_are_reciprocal_with_adjacent_districts() -> void:
	var north := NorthQuarterDefinition.create()
	var center := MarketCivicQuarterDefinition.create()
	var east := LowerTownSliceDefinition.create()
	var harbor := RevalHarborDefinition.create()
	_assert_transition_pair(center, &"to_reval_north", north, &"to_reval_center")
	_assert_transition_pair(east, &"vene_district_boundary", north, &"to_reval_east")
	_assert_transition_pair(harbor, &"to_reval_north", north, &"to_reval_harbor")
	_assert_edge(north, &"to_reval_harbor", &"north")
	_assert_edge(north, &"to_reval_center", &"south")
	_assert_edge(north, &"to_reval_east", &"south")
	_assert_edge(harbor, &"to_reval_north", &"south")


func test_city_fortifications_wrap_only_outer_district_edges() -> void:
	var center := MarketCivicQuarterDefinition.create()
	var east := LowerTownSliceDefinition.create()
	var north := NorthQuarterDefinition.create()
	var toompea := ToompeaQuarterDefinition.create()
	var south := SouthQuarterDefinition.create()
	# The wall is distributed across the city's exterior maps. Shared district
	# seams remain streets, so crossing the Lower Town never requires a gate.
	assert_false(_building_by_id(east, &"city_wall_north").is_empty())
	assert_false(_building_by_id(north, &"city_wall_north_west").is_empty())
	assert_false(_building_by_id(toompea, &"city_wall_north_west").is_empty())
	assert_false(_building_by_id(south, &"city_wall_south_west").is_empty())
	assert_true(_building_by_id(center, &"city_wall_north").is_empty())
	assert_true(_transition_by_id(east, &"karja_road_boundary").is_empty())


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
	match edge:
		&"north": assert_eq(rect.position.y, 0.0)
		&"east": assert_eq(rect.end.x, definition.world_size().x)
		&"south": assert_eq(rect.end.y, definition.world_size().y)
		&"west": assert_eq(rect.position.x, 0.0)


func _transition_by_id(definition: MapDefinition, transition_id: StringName) -> Dictionary:
	for transition in definition.transitions:
		if transition["id"] == transition_id: return transition
	return {}


func _building_by_id(definition: MapDefinition, building_id: StringName) -> Dictionary:
	for building in definition.buildings:
		if building["id"] == building_id: return building
	return {}
