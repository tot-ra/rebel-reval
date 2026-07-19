extends "res://tests/godot/test_case.gd"

const MarketSquareDefinition := preload("res://scripts/map/definitions/prototypes/market_square_definition.gd")
const StOlafsGuildHallDefinition := preload("res://scripts/map/definitions/prototypes/st_olafs_guild_hall_definition.gd")
const MarketCivicQuarterDefinition := preload("res://scripts/map/definitions/prototypes/market_civic_quarter_definition.gd")
const NorthQuarterDefinition := preload("res://scripts/map/definitions/prototypes/north_quarter_definition.gd")
const LowerTownSliceDefinition := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")
const HarborWarehouseDefinition := preload("res://scripts/map/definitions/prototypes/harbor_warehouse_definition.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapVerification := preload("res://scripts/map/map_verification.gd")


func test_market_prototypes_validate_and_stay_inactive() -> void:
	for factory in [
		MarketSquareDefinition,
		StOlafsGuildHallDefinition,
		MarketCivicQuarterDefinition,
		NorthQuarterDefinition,
		HarborWarehouseDefinition,
	]:
		var definition: MapDefinition = factory.create()
		assert_eq(definition.scope, &"prototype")
		assert_false(definition.active)
		assert_true(MapBuilder.validate(definition).is_empty(), factory.resource_path)


func test_market_prototype_door_lanes_have_walkable_coverage() -> void:
	var definition: MapDefinition = MarketSquareDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	for y in grid.size_cells.y:
		for x in grid.size_cells.x:
			assert_false(String(grid.get_terrain(Vector2i(x, y))).is_empty())
	assert_true(MapVerification.has_anchor(definition, &"inspection_spawn"))


func test_market_civic_quarter_uses_historic_street_junction() -> void:
	var definition: MapDefinition = MarketCivicQuarterDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	assert_eq(definition.size_cells, Vector2i(64, 36))
	for anchor_id in [
		&"town_hall_edge",
		&"pikk_street_spine",
		&"vana_turg_neck",
		&"karja_lane",
		&"holy_spirit_frontage",
	]:
		assert_true(MapVerification.has_anchor(definition, anchor_id), "Missing historic anchor %s" % anchor_id)
		assert_true(
			MapVerification.route_exists_exact(
				definition,
				grid,
				definition.player_spawn,
				MapVerification.anchor_position(definition, anchor_id)
			),
			"Historic street route is blocked at %s" % anchor_id
		)
	for building_id in [
		&"town_hall_mass",
		&"church_silhouette",
		&"holy_spirit_hospital",
		&"guild_frontage",
	]:
		assert_true(_building_by_id(definition, building_id) != {}, "Missing civic frontage %s" % building_id)


func test_market_civic_quarter_edges_are_reciprocal_with_adjacent_districts() -> void:
	var center := MarketCivicQuarterDefinition.create()
	var east := LowerTownSliceDefinition.create()
	var north := NorthQuarterDefinition.create()
	_assert_transition_pair(center, &"to_reval_east", east, &"vana_turg_boundary")
	_assert_transition_pair(center, &"to_reval_east_south", east, &"karja_road_boundary")
	_assert_transition_pair(center, &"to_reval_north", north, &"to_reval_center")
	_assert_edge(center, &"to_reval_east", &"east")
	_assert_edge(center, &"to_reval_east_south", &"north")
	_assert_edge(center, &"to_reval_north", &"east")


func test_guild_hall_assembly_nav_and_anchors() -> void:
	var definition: MapDefinition = StOlafsGuildHallDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	assert_true(MapVerification.has_anchor(definition, &"dais"))
	assert_true(
		MapVerification.route_exists(
			definition,
			grid,
			definition.player_spawn,
			MapVerification.anchor_position(definition, &"dais")
		)
	)
	assert_true(MapVerification.collision_parity(definition))


func _assert_transition_pair(
	from_definition: MapDefinition,
	from_id: StringName,
	to_definition: MapDefinition,
	to_id: StringName
) -> void:
	var outgoing := _transition_by_id(from_definition, from_id)
	var returning := _transition_by_id(to_definition, to_id)
	assert_false(outgoing.is_empty(), "%s is missing transition %s" % [from_definition.map_id, from_id])
	assert_false(returning.is_empty(), "%s is missing transition %s" % [to_definition.map_id, to_id])
	if outgoing.is_empty() or returning.is_empty():
		return
	assert_eq(outgoing["destination_spawn_id"], returning["spawn_id"])
	assert_eq(outgoing["spawn_id"], returning["destination_spawn_id"])


func _assert_edge(definition: MapDefinition, transition_id: StringName, edge: StringName) -> void:
	var transition := _transition_by_id(definition, transition_id)
	assert_false(transition.is_empty())
	if transition.is_empty():
		return
	var rect: Rect2 = transition["rect"]
	match edge:
		&"north":
			assert_eq(rect.position.y, 0.0)
		&"east":
			assert_eq(rect.end.x, definition.world_size().x)
		&"south":
			assert_eq(rect.end.y, definition.world_size().y)


func _transition_by_id(definition: MapDefinition, transition_id: StringName) -> Dictionary:
	for transition in definition.transitions:
		if transition["id"] == transition_id:
			return transition
	return {}


func _building_by_id(definition: MapDefinition, building_id: StringName) -> Dictionary:
	for building in definition.buildings:
		if building["id"] == building_id:
			return building
	return {}
