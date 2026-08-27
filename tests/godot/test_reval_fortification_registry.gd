extends "res://tests/godot/test_case.gd"

## R-288: the dated registry is the boundary between completed towers,
## reversible construction positions, and later exclusions. Keep this contract
## separate from renderer tests so a map-ID drift fails before visual capture.

const LowerTownSlice := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")
const NorthQuarter := preload("res://scripts/map/definitions/prototypes/north_quarter_definition.gd")
const MonasteryQuarter := preload("res://scripts/map/definitions/prototypes/monastery_quarter_definition.gd")
const SouthQuarter := preload("res://scripts/map/definitions/prototypes/south_quarter_definition.gd")
const FortificationRegistry := preload("res://scripts/map/reval_fortification_registry.gd")

const EXPECTED_COMPLETED := {
	&"nunnatorn": [&"monastery_quarter", &"monastery_wall_tower_northwest", &"east"],
	&"kuldjala": [&"monastery_quarter", &"monastery_wall_tower_west_mid", &"east"],
	&"rentenitorn": [&"north_quarter", &"merchant_wall_tower_northwest", &"south"],
	&"great_coastal_gate": [&"north_quarter", &"coast_gate_west_tower", &"south"],
}

const EXPECTED_CONSTRUCTION := {
	&"sand_gate": [&"lower_town_slice", &"wall_tower_northeast"],
	&"viru_gate": [&"lower_town_slice", &"viru_gate_north_tower"],
	&"hinke": [&"lower_town_slice", &"hinke_tower"],
	&"cattle_gate": [&"south_quarter", &"karja_gate_west_tower"],
	&"harju_gate": [&"south_quarter", &"south_wall_tower_join"],
}

const EXPECTED_EXCLUDED := [
	&"saunatorn",
	&"nunnadetagune",
	&"loewenschede",
	&"koismae",
	&"epping",
	&"neitsitorn",
	&"kiek_in_de_kok",
	&"fat_margaret",
]


func test_registry_binds_every_1343_position_to_the_current_map() -> void:
	var definitions := {
		&"lower_town_slice": LowerTownSlice.create(),
		&"north_quarter": NorthQuarter.create(),
		&"monastery_quarter": MonasteryQuarter.create(),
		&"south_quarter": SouthQuarter.create(),
	}
	assert_eq(FortificationRegistry.SNAPSHOT_YEAR, 1343)
	assert_eq(FortificationRegistry.COMPLETED_TOWERS_1343.size(), EXPECTED_COMPLETED.size())
	assert_eq(FortificationRegistry.CONSTRUCTION_CANDIDATES_1343.size(), EXPECTED_CONSTRUCTION.size())
	assert_eq(FortificationRegistry.POST_1343_EXCLUSIONS.size(), EXPECTED_EXCLUDED.size())

	var completed_ids: Dictionary = {}
	for record in FortificationRegistry.COMPLETED_TOWERS_1343:
		var historical_id: StringName = record["historical_id"]
		completed_ids[historical_id] = true
		assert_true(EXPECTED_COMPLETED.has(historical_id), "unexpected completed registry ID %s" % historical_id)
		var expected: Array = EXPECTED_COMPLETED[historical_id]
		_assert_record_binding(record, definitions, expected, true)
		assert_eq(record.get("state"), &"completed_1343")
		assert_eq(record.get("visual_treatment"), &"completed_tower")
		assert_eq(record.get("collision_policy"), &"sealed_wall_with_inward_door")
		assert_false(String(record.get("evidence", "")).is_empty())

	assert_eq(completed_ids.size(), EXPECTED_COMPLETED.size())

	var construction_ids: Dictionary = {}
	for record in FortificationRegistry.CONSTRUCTION_CANDIDATES_1343:
		var historical_id: StringName = record["historical_id"]
		construction_ids[historical_id] = true
		assert_true(EXPECTED_CONSTRUCTION.has(historical_id), "unexpected construction registry ID %s" % historical_id)
		var expected: Array = EXPECTED_CONSTRUCTION[historical_id]
		_assert_record_binding(record, definitions, expected, false)
		assert_eq(record.get("state"), &"construction_candidate_1343")
		assert_eq(record.get("visual_treatment"), &"reversible_construction_mockup")
		assert_eq(record.get("collision_policy"), &"sealed_wall_no_breach")
		assert_false(String(record.get("evidence", "")).is_empty())

	assert_eq(construction_ids.size(), EXPECTED_CONSTRUCTION.size())


func test_registry_classes_are_fail_closed_and_later_ids_have_no_map_binding() -> void:
	var completed_ids: Dictionary = {}
	for record in FortificationRegistry.COMPLETED_TOWERS_1343:
		completed_ids[record["historical_id"]] = true
	var construction_ids: Dictionary = {}
	for record in FortificationRegistry.CONSTRUCTION_CANDIDATES_1343:
		construction_ids[record["historical_id"]] = true

	for record in FortificationRegistry.POST_1343_EXCLUSIONS:
		var historical_id: StringName = record["historical_id"]
		assert_false(completed_ids.has(historical_id), "%s leaked into completed towers" % historical_id)
		assert_false(construction_ids.has(historical_id), "%s leaked into construction candidates" % historical_id)
		assert_false(record.has("map_id"), "%s must not acquire a dated map binding" % historical_id)
		assert_false(record.has("building_id"), "%s must not acquire a stable tower position" % historical_id)
		assert_false(String(record.get("earliest_state", "")).is_empty())


func _assert_record_binding(
		record: Dictionary, definitions: Dictionary, expected: Array, completed: bool
) -> void:
	var definition := definitions.get(expected[0]) as MapDefinition
	assert_true(definition != null, "registry references unknown map %s" % expected[0])
	if definition == null:
		return
	assert_eq(record.get("map_id"), expected[0])
	assert_eq(record.get("building_id"), expected[1])
	var building := _building_by_id(definition, expected[1])
	assert_false(building.is_empty(), "registry building ID is not authored: %s" % expected[1])
	assert_eq(building.get("kind"), &"wall")
	assert_eq(bool(building.get("tower", false)), completed)
	if completed:
		assert_eq(record.get("door_side"), expected[2])
		assert_eq(building.get("door_side"), expected[2])
	else:
		assert_false(building.has("door_side"), "construction position must not invent an inward door")


func _building_by_id(definition: MapDefinition, building_id: StringName) -> Dictionary:
	for building in definition.buildings:
		if building.get("id", &"") == building_id:
			return building
	return {}
