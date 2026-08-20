extends "res://tests/godot/test_case.gd"

const NunnatornDefinition := preload("res://scripts/map/definitions/prototypes/nunnatorn_interior_definition.gd")
const MonasteryQuarterDefinition := preload("res://scripts/map/definitions/prototypes/monastery_quarter_definition.gd")


func test_nunnatorn_transition_ids_are_reciprocal() -> void:
	var exterior := _transition_by_id(MonasteryQuarterDefinition.create(), &"nunnatorn_enter")
	var interior := _transition_by_id(NunnatornDefinition.create(), &"nunnatorn_exit")
	assert_eq(exterior.get("destination_scene_id"), &"nunnatorn_interior")
	assert_eq(exterior.get("destination_spawn_id"), interior.get("spawn_id"))
	assert_eq(exterior.get("spawn_offset"), Vector2(96.0, 0.0))
	assert_eq(interior.get("destination_scene_id"), &"reval_monastery")
	assert_eq(interior.get("destination_spawn_id"), exterior.get("spawn_id"))
	assert_eq(interior.get("spawn_offset"), Vector2(0.0, -64.0))


func _transition_by_id(definition: MapDefinition, transition_id: StringName) -> Dictionary:
	for transition in definition.transitions:
		if transition.get("id", &"") == transition_id:
			return transition
	return {}
