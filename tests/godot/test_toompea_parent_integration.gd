extends "res://tests/godot/test_case.gd"

const ArchbishopsGardenDefinition := preload(
	"res://scripts/map/definitions/prototypes/archbishops_garden_definition.gd"
)
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapCatalog := preload("res://scripts/map/map_catalog.gd")
const MapVerification := preload("res://scripts/map/map_verification.gd")
const ToompeaQuarterDefinition := preload(
	"res://scripts/map/definitions/prototypes/toompea_quarter_definition.gd"
)


func test_toompea_parent_package_preserves_inactive_plateau_and_garden_seam() -> void:
	var packages: Array[MapDefinition] = [
		ToompeaQuarterDefinition.create(),
		ArchbishopsGardenDefinition.create(),
	]
	var expected_ids: Array[StringName] = [&"toompea_quarter", &"archbishops_garden"]
	for package_index in packages.size():
		var definition: MapDefinition = packages[package_index]
		assert_eq(definition.map_id, expected_ids[package_index])
		assert_eq(definition.scope, &"prototype")
		assert_false(definition.active, "%s must remain inactive" % definition.map_id)
		assert_eq(
			definition.ground_elevation,
			2.8,
			"%s must use the shared plateau datum" % definition.map_id
		)
		assert_true(
			MapBuilder.validate(definition).is_empty(),
			"%s must remain a valid compiled map package" % definition.map_id
		)

	assert_false(MapCatalog.is_active("reval_toompea"))
	assert_false(MapCatalog.is_active("reval_archbishops_garden"))
	var toompea := packages[0]
	var garden := packages[1]
	var to_garden := _transition_by_id(toompea, &"to_archbishops_garden")
	var to_toompea := _transition_by_id(garden, &"to_reval_toompea")
	assert_eq(to_garden.get("destination_scene_id"), &"reval_archbishops_garden")
	assert_eq(to_garden.get("destination_spawn_id"), &"from_reval_toompea")
	assert_eq(to_garden.get("spawn_id"), &"from_archbishops_garden")
	assert_eq(to_toompea.get("destination_scene_id"), &"reval_toompea")
	assert_eq(to_toompea.get("destination_spawn_id"), &"from_archbishops_garden")
	assert_eq(to_toompea.get("spawn_id"), &"from_reval_toompea")
	assert_true(MapVerification.spawn_clears_transition_trigger(to_garden))
	assert_true(MapVerification.spawn_clears_transition_trigger(to_toompea))


func _transition_by_id(definition: MapDefinition, transition_id: StringName) -> Dictionary:
	for transition in definition.transitions:
		if transition.get("id") == transition_id:
			return transition
	return {}
