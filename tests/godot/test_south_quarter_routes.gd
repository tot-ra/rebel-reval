extends "res://tests/godot/test_case.gd"

const SouthQuarterDefinition := preload(
	"res://scripts/map/definitions/prototypes/south_quarter_definition.gd"
)
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapVerification := preload("res://scripts/map/map_verification.gd")

## R-680: keep South Quarter's prototype route seams deterministic while the map
## remains inactive. This fixture checks authored geometry and the shared spawn
## registry together, so a renamed boundary cannot pass as a local map-only test.


func before_each() -> void:
	DoorNavigator.load_manifest(true)


func test_south_quarter_routes_connect_anchors_and_manifest_spawns() -> void:
	var definition: MapDefinition = SouthQuarterDefinition.create()
	var grid := MapBuilder.build(definition)
	assert_false(definition.active, "South Quarter must stay inactive until parent acceptance")
	assert_eq(definition.scope, &"prototype")

	for anchor_id in [&"inspection_spawn", &"rataskaev_well", &"king_street_climb", &"karja_approach"]:
		var anchor_position := MapVerification.anchor_position(definition, anchor_id)
		assert_true(
			MapVerification.has_anchor(definition, anchor_id),
			"Missing South anchor %s" % anchor_id,
		)
		assert_true(
			MapVerification.route_exists_exact(definition, grid, definition.player_spawn, anchor_position),
			"South player spawn must reach %s without snapping" % anchor_id,
		)

	var seams := {
		&"to_reval_center": [&"reval_center", &"to_reval_south"],
		&"to_reval_east": [&"reval_east", &"from_reval_south"],
		&"to_archbishops_garden": [&"reval_archbishops_garden", &"from_reval_south"],
	}
	for transition_id in seams:
		var transition := _record_by_id(definition.transitions, transition_id)
		assert_false(transition.is_empty(), "Missing South transition %s" % transition_id)
		assert_true(
			MapVerification.route_exists_exact(
				definition,
				grid,
				definition.player_spawn,
				transition["rect"].get_center(),
			),
			"South player spawn must reach transition %s" % transition_id,
		)
		assert_true(
			MapVerification.spawn_clears_transition_trigger(transition),
			"South transition %s needs arrival clearance" % transition_id,
		)

		var destination: Array = seams[transition_id]
		var destination_scene: StringName = destination[0]
		var destination_spawn: StringName = destination[1]
		assert_true(
			DoorNavigator.has_active_scene(destination_scene),
			"Destination scene %s must remain registered" % destination_scene,
		)
		assert_true(
			DoorNavigator.has_spawn(destination_scene, destination_spawn),
			"Destination spawn %s/%s must remain registered" % [destination_scene, destination_spawn],
		)


func _record_by_id(records: Array, record_id: StringName) -> Dictionary:
	for record in records:
		if record.get("id", &"") == record_id:
			return record
	return {}
