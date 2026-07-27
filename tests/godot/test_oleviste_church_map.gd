extends "res://tests/godot/test_case.gd"

const OlevisteChurchDefinition := preload(
	"res://scripts/map/definitions/prototypes/oleviste_church_definition.gd"
)
const MonasteryQuarterDefinition := preload(
	"res://scripts/map/definitions/prototypes/monastery_quarter_definition.gd"
)


func test_oleviste_church_is_inactive_prototype_interior() -> void:
	var definition: MapDefinition = OlevisteChurchDefinition.create()
	assert_eq(definition.map_id, &"oleviste_church")
	assert_eq(definition.scope, &"prototype")
	assert_false(definition.active)
	assert_eq(definition.size_cells, Vector2i(36, 24))


func test_oleviste_church_has_required_anchors_and_routes() -> void:
	var definition: MapDefinition = OlevisteChurchDefinition.create()
	var grid := MapBuilder.build(definition)
	for anchor_id in [
		&"inspection_spawn",
		&"altar_front",
		&"nave_center",
		&"south_entry",
	]:
		assert_true(MapVerification.has_anchor(definition, anchor_id), "Missing anchor %s" % anchor_id)
		assert_true(
			MapVerification.route_exists_exact(
				definition,
				grid,
				definition.player_spawn,
				MapVerification.anchor_position(definition, anchor_id)
			),
			"Route blocked at %s" % anchor_id
		)


func test_oleviste_church_returns_to_monastery_district() -> void:
	var interior: MapDefinition = OlevisteChurchDefinition.create()
	var return_door := _transition_by_id(interior, &"to_reval_monastery")
	assert_false(return_door.is_empty(), "St. Olaf interior must expose a return transition")
	assert_eq(return_door.get("destination_scene_id"), &"reval_monastery")
	assert_eq(return_door.get("destination_spawn_id"), &"to_oleviste_church")
	assert_eq(return_door.get("spawn_id"), &"from_reval_monastery")


func test_monastery_quarter_opens_oleviste_church_interior() -> void:
	var exterior: MapDefinition = MonasteryQuarterDefinition.create()
	var entry := _transition_by_id(exterior, &"to_oleviste_church")
	assert_false(entry.is_empty(), "Monastery District must expose a St. Olaf threshold door")
	assert_eq(entry.get("destination_scene_id"), &"oleviste_church")
	assert_eq(entry.get("destination_spawn_id"), &"from_reval_monastery")
	assert_eq(entry.get("spawn_id"), &"to_oleviste_church")
	assert_eq(entry.get("building_id"), &"st_olaf_silhouette")


func _transition_by_id(definition: MapDefinition, transition_id: StringName) -> Dictionary:
	for transition in definition.transitions:
		if transition.get("id", &"") == transition_id:
			return transition
	return {}
