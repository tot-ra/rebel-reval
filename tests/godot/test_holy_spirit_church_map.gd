extends "res://tests/godot/test_case.gd"

const HolySpiritChurchDefinition := preload(
	"res://scripts/map/definitions/prototypes/holy_spirit_church_definition.gd"
)
const MarketCivicQuarterDefinition := preload(
	"res://scripts/map/definitions/prototypes/market_civic_quarter_definition.gd"
)


func test_holy_spirit_church_is_inactive_prototype_interior() -> void:
	var definition: MapDefinition = HolySpiritChurchDefinition.create()
	assert_eq(definition.map_id, &"holy_spirit_church")
	assert_eq(definition.scope, &"prototype")
	assert_false(definition.active)
	assert_eq(definition.size_cells, Vector2i(30, 22))


func test_holy_spirit_church_has_required_anchors_and_routes() -> void:
	var definition: MapDefinition = HolySpiritChurchDefinition.create()
	var grid := MapBuilder.build(definition)
	for anchor_id in [
		&"inspection_spawn",
		&"altar_front",
		&"nave_center",
		&"south_entry",
		&"baptismal_font_site",
		&"alms_chest_site",
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


func test_holy_spirit_church_returns_to_central_district() -> void:
	var interior: MapDefinition = HolySpiritChurchDefinition.create()
	var return_door := _transition_by_id(interior, &"to_reval_center")
	assert_false(return_door.is_empty(), "Holy Spirit interior must expose a return transition")
	assert_eq(return_door.get("destination_scene_id"), &"reval_center")
	assert_eq(return_door.get("destination_spawn_id"), &"to_holy_spirit_church")
	assert_eq(return_door.get("spawn_id"), &"from_reval_center")


func test_market_civic_quarter_opens_holy_spirit_church_interior() -> void:
	var exterior: MapDefinition = MarketCivicQuarterDefinition.create()
	var entry := _transition_by_id(exterior, &"to_holy_spirit_church")
	assert_false(entry.is_empty(), "Central District must expose a Holy Spirit chapel door")
	assert_eq(entry.get("destination_scene_id"), &"holy_spirit_church")
	assert_eq(entry.get("destination_spawn_id"), &"from_reval_center")
	assert_eq(entry.get("spawn_id"), &"to_holy_spirit_church")
	assert_eq(entry.get("building_id"), &"church_silhouette")


func _transition_by_id(definition: MapDefinition, transition_id: StringName) -> Dictionary:
	for transition in definition.transitions:
		if transition.get("id", &"") == transition_id:
			return transition
	return {}
