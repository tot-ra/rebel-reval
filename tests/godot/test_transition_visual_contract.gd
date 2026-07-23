extends "res://tests/godot/test_case.gd"

const Registry := preload("res://scripts/map/map_audit_registry.gd")
const INTERIOR_WALL_DOORS := {
	&"kalev_smithy": [&"door_courtyard"],
}


func test_functional_transitions_never_render_freestanding_doors() -> void:
	for definition in Registry.all():
		for transition in definition.transitions:
			if String(transition.get("destination_scene_id", "")).is_empty():
				continue
			var visual: StringName = transition.get("transition_visual", MapTypes.TRANSITION_VISUAL_DOOR)
			var context := "%s.%s" % [definition.map_id, transition.get("id", &"")]
			match visual:
				MapTypes.TRANSITION_VISUAL_GROUND:
					assert_true(bool(transition.get("highlight_area", false)), "%s needs a readable ground cue" % context)
				MapTypes.TRANSITION_VISUAL_DOOR:
					assert_true(_door_has_structural_context(definition, transition), "%s must attach to a facade, wall opening, or gate landmark" % context)
				_:
					fail("%s must use a contextual door or ground cue" % context)


func _door_has_structural_context(definition: MapDefinition, transition: Dictionary) -> bool:
	var building_id := StringName(String(transition.get("building_id", "")))
	if not building_id.is_empty():
		var building := MapBuildingEntrance.find_building(definition, transition)
		return not building.is_empty() and MapBuildingEntrance.approach_aligns_with_facade(building, transition, definition.cell_size)
	if MapViewMeshBuilder.transition_uses_landmark_visual(definition, transition):
		return true
	# Interior wall openings intentionally render their own framed door. Keep the
	# exceptions explicit so a new outdoor transition cannot inherit this escape.
	return transition.get("id", &"") in INTERIOR_WALL_DOORS.get(definition.map_id, [])
