extends RefCounted

## Shared GameState equality checks for save/reload regression tests.

const FlowModel := preload("res://scripts/slice/vertical_slice_flow_model.gd")
const LOC_SMITHY := &"loc.kalev_smithy"


static func assert_game_states_equal(
	test_case: RefCounted,
	expected: GameState,
	actual: GameState,
	message_prefix: String = ""
) -> void:
	var prefix := message_prefix
	if not prefix.is_empty():
		prefix = "%s: " % prefix
	test_case.assert_eq(actual.get_version(), expected.get_version(), prefix + "version")
	test_case.assert_eq(actual.get_phase(), expected.get_phase(), prefix + "phase")
	test_case.assert_true(
		is_equal_approx(actual.player.health, expected.player.health),
		prefix + "player health"
	)
	test_case.assert_true(
		is_equal_approx(actual.player.stamina, expected.player.stamina),
		prefix + "player stamina"
	)
	test_case.assert_eq(actual.player.location_id, expected.player.location_id, prefix + "location")
	test_case.assert_eq(actual.player.spawn_id, expected.player.spawn_id, prefix + "spawn")
	test_case.assert_eq(
		actual.equipped_item(&"right_hand"),
		expected.equipped_item(&"right_hand"),
		prefix + "right_hand equip"
	)
	test_case.assert_eq(
		actual.equipped_item(&"left_hand"),
		expected.equipped_item(&"left_hand"),
		prefix + "left_hand equip"
	)
	test_case.assert_eq(
		actual.equipped_forge_technique(),
		expected.equipped_forge_technique(),
		prefix + "forge technique"
	)
	test_case.assert_eq(actual.bag.placements.size(), expected.bag.placements.size(), prefix + "bag size")
	test_case.assert_eq(
		actual.get_forged_records().size(),
		expected.get_forged_records().size(),
		prefix + "forged record count"
	)
	for record in expected.get_forged_records():
		test_case.assert_true(
			actual.has_forged_record(record.record_id),
			prefix + "forged record %s" % String(record.record_id)
		)
	test_case.assert_eq(
		actual.get_quest_state(FlowModel.QUEST_MAKERS_MARK),
		expected.get_quest_state(FlowModel.QUEST_MAKERS_MARK),
		prefix + "makers mark quest"
	)
	test_case.assert_eq(
		actual.get_quest_state(FlowModel.QUEST_BITTER_BREW),
		expected.get_quest_state(FlowModel.QUEST_BITTER_BREW),
		prefix + "bitter brew quest"
	)
	test_case.assert_eq(
		MapParitySnapshot.serialize_value(actual.save_map_world_state()),
		MapParitySnapshot.serialize_value(expected.save_map_world_state()),
		prefix + "map world state"
	)
	test_case.assert_eq(
		actual.get_pressure(GameState.PRESSURE_SUSPICION),
		expected.get_pressure(GameState.PRESSURE_SUSPICION),
		prefix + "suspicion pressure"
	)
	test_case.assert_eq(
		actual.get_relationship(&"rel.henning_trust"),
		expected.get_relationship(&"rel.henning_trust"),
		prefix + "henning trust"
	)
	test_case.assert_eq(
		actual.get_location_state(LOC_SMITHY),
		expected.get_location_state(LOC_SMITHY),
		prefix + "smithy location state"
	)
