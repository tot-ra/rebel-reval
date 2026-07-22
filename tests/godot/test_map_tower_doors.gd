extends "res://tests/godot/test_case.gd"

const LowerTownSlice := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")
const NorthQuarter := preload("res://scripts/map/definitions/prototypes/north_quarter_definition.gd")
const MonasteryQuarter := preload("res://scripts/map/definitions/prototypes/monastery_quarter_definition.gd")
const ArchbishopsGarden := preload("res://scripts/map/definitions/prototypes/archbishops_garden_definition.gd")
const ToompeaQuarter := preload("res://scripts/map/definitions/prototypes/toompea_quarter_definition.gd")
const SouthQuarter := preload("res://scripts/map/definitions/prototypes/south_quarter_definition.gd")
const FortificationRegistry := preload("res://scripts/map/reval_fortification_registry.gd")

const EXPECTED_COMPLETED_LOWER_TOWN_SIDES := {
	&"north_quarter": {
		&"coast_gate_west_tower": &"south",
		&"merchant_wall_tower_northwest": &"south",
	},
	&"monastery_quarter": {
		&"monastery_wall_tower_northwest": &"east",
		&"monastery_wall_tower_west_mid": &"east",
	},
}

const EXPECTED_UPPER_TOWN_SIDES := {
	&"archbishops_garden": {
		&"garden_wall_tower_northwest": &"east", &"garden_wall_tower_west_bend": &"east",
		&"garden_wall_tower_southwest": &"east", &"center_gate_north_tower": &"west",
		&"center_gate_south_tower": &"west", &"garden_wall_tower_south_mid": &"north",
	},
	&"toompea_quarter": {
		&"pikk_jalg_gate_tower": &"west", &"pikk_jalg_gate_east_tower": &"west",
		&"toompea_garden_gate_west_tower": &"north", &"toompea_garden_gate_east_tower": &"north",
		&"castle_keep_tower": &"south",
	},
}

const SIDE_DIRECTIONS := {
	&"north": Vector3(0.0, 0.0, -1.0),
	&"south": Vector3(0.0, 0.0, 1.0),
	&"east": Vector3(1.0, 0.0, 0.0),
	&"west": Vector3(-1.0, 0.0, 0.0),
}


func test_1343_lower_town_uses_the_conservative_four_tower_registry() -> void:
	var definitions := _definitions_by_id()
	assert_eq(FortificationRegistry.SNAPSHOT_YEAR, 1343)
	assert_eq(FortificationRegistry.completed_tower_count(), 4)
	assert_eq(FortificationRegistry.COMPLETED_TOWERS_1343.size(), 4)
	assert_eq(FortificationRegistry.CONSTRUCTION_CANDIDATES_1343.size(), 5)

	var seen_historical_ids: Dictionary = {}
	for record in FortificationRegistry.COMPLETED_TOWERS_1343:
		var historical_id: StringName = record["historical_id"]
		assert_false(seen_historical_ids.has(historical_id), "duplicate historical tower id %s" % historical_id)
		seen_historical_ids[historical_id] = true
		var definition := definitions.get(record["map_id"]) as MapDefinition
		assert_true(definition != null, "unknown tower map %s" % record["map_id"])
		if definition == null:
			continue
		var tower := _building_by_id(definition, record["building_id"])
		assert_true(bool(tower.get("tower", false)), "%s must be completed in 1343" % record["name"])

	assert_true(seen_historical_ids.has(&"nunnatorn"))
	assert_true(seen_historical_ids.has(&"kuldjala"))
	assert_true(seen_historical_ids.has(&"rentenitorn"))
	assert_true(seen_historical_ids.has(&"great_coastal_gate"))


func test_lower_town_maps_do_not_invent_later_completed_towers() -> void:
	var completed_count := 0
	for definition in _lower_town_definitions():
		var expected: Dictionary = EXPECTED_COMPLETED_LOWER_TOWN_SIDES.get(definition.map_id, {})
		var seen_ids: Dictionary = {}
		for building in definition.buildings:
			if not bool(building.get("tower", false)):
				continue
			completed_count += 1
			var tower_id: StringName = building["id"]
			assert_true(expected.has(tower_id), "%s/%s is not in the conservative 1343 registry" % [definition.map_id, tower_id])
			seen_ids[tower_id] = true
		assert_eq(seen_ids.size(), expected.size(), "%s completed tower list drifted" % definition.map_id)
	assert_eq(completed_count, 4)


func test_every_completed_tower_has_one_visible_door_on_its_authored_interior_side() -> void:
	for definition in _all_definitions():
		var expected: Dictionary = EXPECTED_COMPLETED_LOWER_TOWN_SIDES.get(definition.map_id, {})
		if EXPECTED_UPPER_TOWN_SIDES.has(definition.map_id):
			expected = EXPECTED_UPPER_TOWN_SIDES[definition.map_id]
		for tower_id: StringName in expected:
			var building := _building_by_id(definition, tower_id)
			var side: StringName = building.get("door_side", &"")
			assert_eq(side, expected[tower_id], "%s/%s door must face inward" % [definition.map_id, tower_id])

			var node := MapViewMeshBuilderBuildings.build_building(building, definition.cell_size)
			assert_true(node.has_node("TowerDoor"), "%s/%s needs a visible ground-level door" % [definition.map_id, tower_id])
			assert_true(node.has_node("TowerDoorFrame-1") and node.has_node("TowerDoorFrame1"), "%s/%s door needs a stone frame" % [definition.map_id, tower_id])
			assert_true(node.has_node("TowerDoorStrap0") and node.has_node("TowerDoorLatch"), "%s/%s door needs readable iron hardware" % [definition.map_id, tower_id])
			var door := node.get_node("TowerDoor") as Node3D
			assert_true(door.position.dot(SIDE_DIRECTIONS[side]) > 0.0, "%s/%s door mesh is on the wrong side" % [definition.map_id, tower_id])
			node.free()


func test_tower_false_keeps_round_drum_with_cone_roof_without_door() -> void:
	# tower=false marks an incomplete 1343 position. The Tallinn plan is still
	# circular via round_tower and wears the conical red-tile roof; only door
	# and arrow-slit fighting-stage dressing stay suppressed.
	var definition: MapDefinition = LowerTownSlice.create()
	var construction_position := _building_by_id(definition, &"foregate_tower_north")
	assert_true(construction_position.has("tower"))
	assert_false(bool(construction_position["tower"]))
	assert_true(bool(construction_position.get("round_tower", false)))
	var node := MapViewMeshBuilderBuildings.build_building(construction_position, definition.cell_size)
	assert_true((node.get_node("Walls") as MeshInstance3D).mesh is CylinderMesh)
	assert_true(node.has_node("TowerRoof"), "circular drums need the conical red-tile roof")
	assert_false(node.has_node("TowerDoor"), "incomplete towers must not invent ground doors")
	assert_false(node.has_node("SlitFrame0"), "incomplete towers must not invent arrow slits")
	node.free()


func test_authored_step_seals_cover_known_city_wall_holes() -> void:
	var required := {
		&"lower_town_slice": [&"wall_seal_viru_south_join"],
		&"north_quarter": [&"city_wall_northwest_return", &"city_wall_northeast_return"],
		&"south_quarter": [&"city_wall_south_west_gate_join", &"city_wall_south_east_step_join", &"city_wall_southeast_bend_join"],
	}
	var definitions := _definitions_by_id()
	for map_id: StringName in required:
		var definition := definitions[map_id] as MapDefinition
		for building_id: StringName in required[map_id]:
			assert_false(_building_by_id(definition, building_id).is_empty(), "%s is missing wall seal %s" % [map_id, building_id])


func test_round_tower_validation_requires_an_explicit_cardinal_door_side() -> void:
	var definition: MapDefinition = NorthQuarter.create()
	for building in definition.buildings:
		if bool(building.get("tower", false)):
			building.erase("door_side")
			break
	var errors := definition.validate()
	assert_true(_contains(errors, "tower requires door_side"), "completed towers without an interior side must be rejected")


func _definitions_by_id() -> Dictionary:
	var definitions: Dictionary = {}
	for definition in _all_definitions():
		definitions[definition.map_id] = definition
	return definitions


func _lower_town_definitions() -> Array[MapDefinition]:
	return [LowerTownSlice.create(), NorthQuarter.create(), MonasteryQuarter.create(), SouthQuarter.create()]


func _all_definitions() -> Array[MapDefinition]:
	return [
		LowerTownSlice.create(), NorthQuarter.create(), MonasteryQuarter.create(),
		ArchbishopsGarden.create(), ToompeaQuarter.create(), SouthQuarter.create(),
	]


func _building_by_id(definition: MapDefinition, building_id: StringName) -> Dictionary:
	for building in definition.buildings:
		if building["id"] == building_id:
			return building
	return {}


func _contains(errors: Array[String], expected: String) -> bool:
	for error in errors:
		if error.contains(expected):
			return true
	return false
