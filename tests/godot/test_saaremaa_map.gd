extends "res://tests/godot/test_case.gd"

const RRMAP_PATH := "res://content/maps/world_saaremaa.rrmap"
const ORIGINAL_AREA_CELLS := 50 * 28


func test_saaremaa_is_a_fourfold_island_location_with_authored_surroundings() -> void:
	var definition := _definition()
	if definition == null:
		return
	assert_eq(definition.size_cells, Vector2i(104, 60))
	assert_true(
		definition.size_cells.x * definition.size_cells.y >= ORIGINAL_AREA_CELLS * 4,
		"Saaremaa must remain at least four times the original 50 x 28 placeholder area"
	)
	assert_eq(definition.surroundings_sides.get(&"north"), &"water")
	assert_eq(definition.surroundings_sides.get(&"east"), &"water")
	assert_eq(definition.surroundings_sides.get(&"west"), &"water")
	assert_eq(definition.surroundings_sides.get(&"south"), &"woodland")


func test_saaremaa_keeps_kaali_and_campaign_zones_distinct() -> void:
	var definition := _definition()
	if definition == null:
		return
	for anchor_id: StringName in [
		&"landmark_ferry_landing",
		&"landmark_fisher_hamlet",
		&"landmark_muster_camp",
		&"landmark_burned_manor",
		&"landmark_kaali_crater",
		&"landmark_kaali_lake",
		&"landmark_strait_landing",
	]:
		assert_true(MapVerification.has_anchor(definition, anchor_id), "Missing Saaremaa anchor %s" % anchor_id)
	var building_ids := _record_ids(definition.buildings)
	for building_id: StringName in [
		&"fisher_cottage_west",
		&"camp_field_forge",
		&"burned_manor_hall",
		&"kaali_bank_south",
	]:
		assert_true(building_ids.has(building_id), "Missing Saaremaa structure %s" % building_id)
	var prop_ids := _record_ids(definition.props)
	for prop_id: StringName in [
		&"moored_boat_ferry",
		&"pasture_sheep_a",
		&"camp_iron_scrap",
		&"kaali_offering_stone",
	]:
		assert_true(prop_ids.has(prop_id), "Missing Saaremaa story prop %s" % prop_id)


func test_saaremaa_routes_connect_both_ferries_kaali_and_poide_road() -> void:
	var definition := _definition()
	if definition == null:
		return
	var grid := MapBuilder.build(definition)
	for anchor_id: StringName in [&"landmark_kaali_crater", &"landmark_muster_camp", &"landmark_burned_manor"]:
		assert_true(
			MapVerification.route_exists(
				definition,
				grid,
				definition.player_spawn,
				MapVerification.anchor_position(definition, anchor_id)
			),
			"Inspection spawn must reach %s" % anchor_id
		)
	for transition_id: StringName in [&"ferry_to_reval", &"ferry_to_parnu", &"road_to_poide"]:
		var transition := _transition(definition, transition_id)
		assert_false(transition.is_empty(), "Missing Saaremaa transition %s" % transition_id)
		if transition.is_empty():
			continue
		assert_true(MapVerification.spawn_clears_transition_trigger(transition))
		assert_true(
			MapVerification.route_exists_exact(definition, grid, definition.player_spawn, transition["rect"].get_center()),
			"Inspection spawn must reach %s" % transition_id
		)


func _definition() -> MapDefinition:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return null
	var definition: MapDefinition = parsed.definition
	assert_true(definition.validate().is_empty(), str(definition.validate()))
	return definition


func _record_ids(records: Array[Dictionary]) -> Dictionary:
	var ids: Dictionary = {}
	for record: Dictionary in records:
		ids[record.get("id", &"")] = true
	return ids


func _transition(definition: MapDefinition, transition_id: StringName) -> Dictionary:
	for transition: Dictionary in definition.transitions:
		if transition.get("id") == transition_id:
			return transition
	return {}
