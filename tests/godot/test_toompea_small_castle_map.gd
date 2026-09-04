extends "res://tests/godot/test_case.gd"

const Definition := preload(
	"res://scripts/map/definitions/prototypes/toompea_small_castle_definition.gd"
)
const SOURCE_PATH := "res://content/maps/toompea_small_castle.rrmap"

const REQUIRED_ZONES: Array[StringName] = [
	&"sc-forecourt",
	&"sc-gate-tower",
	&"sc-viceroy-audience",
	&"sc-viceroy-private",
	&"sc-castle-chapel",
	&"sc-service-cellar",
	&"ob-courtyard",
	&"ob-east-gate",
]


func test_toompea_small_castle_map() -> void:
	var parsed := MapRrmapParser.parse_file(SOURCE_PATH)
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return

	var definition: MapDefinition = Definition.create()
	assert_eq(definition.map_id, &"toompea_small_castle")
	assert_eq(definition.scope, &"prototype")
	assert_false(definition.active, "Small Castle remains inactive until its packed scene gate")
	assert_eq(definition.size_cells, Vector2i(32, 24))
	assert_true(MapBuilder.validate(definition).is_empty())

	var grid := MapBuilder.build(definition)
	for zone_id in REQUIRED_ZONES:
		assert_true(
			MapVerification.has_anchor(definition, zone_id), "Missing zone anchor %s" % zone_id
		)
		assert_true(
			MapVerification.route_exists_exact(
				definition,
				grid,
				definition.player_spawn,
				MapVerification.anchor_position(definition, zone_id)
			),
			"Zone %s must be reachable from the outer-bailey entry" % zone_id
		)

	var source := FileAccess.get_file_as_string(SOURCE_PATH).to_lower()
	for forbidden in [
		"order_convent", "pikk_hermann", "stür den kerl", "lands krone", "pilsticker"
	]:
		assert_false(
			forbidden in source,
			"Later Order skyline/layout leaked into Small Castle source: %s" % forbidden
		)

	var return_transition := _transition_by_id(definition, &"to_toompea_quarter")
	assert_eq(return_transition.get("destination_scene_id"), &"reval_toompea")
	assert_eq(return_transition.get("destination_spawn_id"), &"from_small_castle")
	assert_eq(return_transition.get("spawn_id"), &"from_small_castle")


func _transition_by_id(definition: MapDefinition, transition_id: StringName) -> Dictionary:
	for transition in definition.transitions:
		if transition.get("id") == transition_id:
			return transition
	return {}
