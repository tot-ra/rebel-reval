extends "res://tests/godot/test_case.gd"

const SouthQuarterDefinition := preload("res://scripts/map/definitions/prototypes/south_quarter_definition.gd")


func test_south_quarter_prototype_bounds_and_anchors() -> void:
	var definition: MapDefinition = SouthQuarterDefinition.create()
	assert_eq(definition.size_cells, Vector2i(336, 96))
	assert_true(MapBuilder.validate(definition).is_empty())
	for anchor_id in [&"rataskaev_well", &"karja_approach", &"king_street_climb"]:
		assert_true(MapVerification.has_anchor(definition, anchor_id), "Missing south-quarter anchor %s" % anchor_id)


func test_south_quarter_district_life_dressing() -> void:
	var definition: MapDefinition = SouthQuarterDefinition.create()
	var dressing_kinds := {
		MapTypes.PROP_KIND_WASH_TUB: false,
		MapTypes.PROP_KIND_BARRELS: false,
		MapTypes.PROP_KIND_WEAPON_RACK: false,
		MapTypes.PROP_KIND_BANNER: false,
		MapTypes.PROP_KIND_CHARCOAL_PILE: false,
		MapTypes.PROP_KIND_IRON_SCRAP_PILE: false,
	}
	for prop in definition.props:
		var kind: StringName = prop.get("kind", &"")
		if dressing_kinds.has(kind):
			dressing_kinds[kind] = true
	for dressing_kind in dressing_kinds:
		assert_true(dressing_kinds[dressing_kind], "South quarter needs district-life prop %s" % String(dressing_kind))
	assert_true(
		_prop_near_prop(definition, &"rataskaev_well_wash", &"rataskaev_well_prop", 6),
		"Wash tub must sit beside Rataskaev well"
	)
	assert_true(
		_prop_near_prop(definition, &"rataskaev_well_buckets", &"rataskaev_well_prop", 6),
		"Well buckets must sit beside Rataskaev well"
	)
	assert_true(
		_prop_near_building(definition, &"knights_court_weapon", &"knights_hall", 8),
		"Weapon rack must sit beside knights_hall"
	)
	assert_true(
		_prop_near_building(definition, &"knights_hall_banner", &"knights_hall", 8),
		"Knights' court banner must sit beside knights_hall"
	)
	assert_true(
		_prop_near_building(definition, &"knights_court_barrels", &"knights_hall", 10),
		"Service barrels must sit in the knights' court"
	)
	assert_true(
		_prop_near_building(definition, &"karja_yard_charcoal", &"karja_gate_house_west", 8),
		"Charcoal pile must sit in the Karja gate service yard"
	)
	assert_true(
		_prop_near_building(definition, &"swordsmith_scrap", &"swordsmith_row", 8),
		"Iron scrap must sit beside swordsmith_row"
	)
	var grid := MapBuilder.build(definition)
	for point in (definition.patrols[0]["points"] as Array):
		assert_true(
			MapVerification.is_walkable_point(definition, grid, point),
			"Patrol point %s must stay walkable after south-quarter dressing" % point
		)


func _building_by_id(definition: MapDefinition, building_id: StringName) -> Dictionary:
	for building in definition.buildings:
		if building["id"] == building_id:
			return building
	return {}


func _prop_by_id(definition: MapDefinition, prop_id: StringName) -> Dictionary:
	for prop in definition.props:
		if prop["id"] == prop_id:
			return prop
	return {}


func _prop_near_prop(
	definition: MapDefinition,
	prop_id: StringName,
	other_prop_id: StringName,
	max_distance_cells: int
) -> bool:
	var prop := _prop_by_id(definition, prop_id)
	var other := _prop_by_id(definition, other_prop_id)
	if prop.is_empty() or other.is_empty():
		return false
	var prop_pos: Vector2 = prop.get("position", Vector2.ZERO)
	var other_pos: Vector2 = other.get("position", Vector2.ZERO)
	return prop_pos.distance_to(other_pos) <= float(max_distance_cells * definition.cell_size)


func _prop_near_building(
	definition: MapDefinition,
	prop_id: StringName,
	building_id: StringName,
	max_distance_cells: int
) -> bool:
	var prop := _prop_by_id(definition, prop_id)
	var building := _building_by_id(definition, building_id)
	if prop.is_empty() or building.is_empty():
		return false
	var prop_pos: Vector2 = prop.get("position", Vector2.ZERO)
	var footprint: Rect2 = building["footprint"]
	var closest := Vector2(
		clampf(prop_pos.x, footprint.position.x, footprint.end.x),
		clampf(prop_pos.y, footprint.position.y, footprint.end.y)
	)
	return prop_pos.distance_to(closest) <= float(max_distance_cells * definition.cell_size)
