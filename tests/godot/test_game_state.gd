extends "res://tests/godot/test_case.gd"

const FACT_SEIZED_SPEARHEAD := &"fact.seized_spearhead_seen"
const REL_HENNING_TRUST := &"rel.henning_trust"

const COMMISSION_WATCH_BUCKLE := &"commission.watch_buckle_repair"
const ITEM_WATCH_BUCKLE := &"item.watch_buckle"
const MOD_HONEST_WORK := &"honest_work"
const RECORD_WATCH_BUCKLE_HONEST := &"forged.watch_buckle_repair.honest_work"


func test_default_state_and_version() -> void:
	var state := GameState.new()

	assert_eq(state.get_version(), GameState.CURRENT_VERSION)
	assert_eq(state.get_phase(), GameState.PHASE_PROLOGUE_DAY)
	assert_eq(state.get_pressure(GameState.PRESSURE_SUSPICION), 0)
	assert_eq(state.get_pressure(GameState.PRESSURE_SOLIDARITY), 0)
	assert_eq(state.get_pressure(GameState.PRESSURE_SCARCITY), 0)
	assert_eq(state.player.health, 100.0)
	assert_eq(state.player.max_health, 100.0)
	assert_eq(state.player.stamina, 100.0)
	assert_eq(state.player.max_stamina, 100.0)
	assert_eq(state.player.location_id, PlayerState.DEFAULT_LOCATION_ID)
	assert_eq(state.player.spawn_id, PlayerState.DEFAULT_SPAWN_ID)


func test_fresh_instances_are_isolated() -> void:
	var left := GameState.new()
	var right := GameState.new()

	left.set_fact(FACT_SEIZED_SPEARHEAD, true)
	left.set_relationship(REL_HENNING_TRUST, 2)
	left.adjust_pressure(GameState.PRESSURE_SUSPICION, 1)
	left.player.health = 42.0

	assert_false(right.get_fact(FACT_SEIZED_SPEARHEAD))
	assert_eq(right.get_relationship(REL_HENNING_TRUST), 0)
	assert_eq(right.get_pressure(GameState.PRESSURE_SUSPICION), 0)
	assert_eq(right.player.health, 100.0)


func test_facts_default_false_and_can_be_set() -> void:
	var state := GameState.new()

	assert_false(state.get_fact(FACT_SEIZED_SPEARHEAD))
	state.set_fact(FACT_SEIZED_SPEARHEAD, true)
	assert_true(state.get_fact(FACT_SEIZED_SPEARHEAD))
	state.set_fact(FACT_SEIZED_SPEARHEAD, false)
	assert_false(state.get_fact(FACT_SEIZED_SPEARHEAD))


func test_relationships_clamp_between_bounds() -> void:
	var state := GameState.new()

	assert_eq(state.get_relationship(REL_HENNING_TRUST), 0)
	state.adjust_relationship(REL_HENNING_TRUST, 1)
	assert_eq(state.get_relationship(REL_HENNING_TRUST), 1)
	state.set_relationship(REL_HENNING_TRUST, 99)
	assert_eq(state.get_relationship(REL_HENNING_TRUST), 3)
	state.set_relationship(REL_HENNING_TRUST, -99)
	assert_eq(state.get_relationship(REL_HENNING_TRUST), -3)


func test_pressures_clamp_between_bounds() -> void:
	var state := GameState.new()

	state.adjust_pressure(GameState.PRESSURE_SUSPICION, 1)
	assert_eq(state.get_pressure(GameState.PRESSURE_SUSPICION), 1)
	state.set_pressure(GameState.PRESSURE_SOLIDARITY, 9)
	assert_eq(state.get_pressure(GameState.PRESSURE_SOLIDARITY), 3)
	state.adjust_pressure(GameState.PRESSURE_SCARCITY, -9)
	assert_eq(state.get_pressure(GameState.PRESSURE_SCARCITY), 0)


func test_phase_can_be_updated() -> void:
	var state := GameState.new()
	var next_phase := &"phase.investigation_night"

	state.set_phase(next_phase)
	assert_eq(state.get_phase(), next_phase)


func test_player_state_is_typed_and_mutable() -> void:
	var state := GameState.new()

	state.player.health = 75.0
	state.player.max_health = 90.0
	state.player.stamina = 60.0
	state.player.max_stamina = 80.0
	state.player.location_id = &"reval_east"
	state.player.spawn_id = &"courtyard"

	assert_eq(state.player.health, 75.0)
	assert_eq(state.player.max_health, 90.0)
	assert_eq(state.player.stamina, 60.0)
	assert_eq(state.player.max_stamina, 80.0)
	assert_eq(state.player.location_id, &"reval_east")
	assert_eq(state.player.spawn_id, &"courtyard")


func test_forged_records_store_and_reject_duplicates() -> void:
	var state := GameState.new()
	var record := ForgedRecord.new(
		RECORD_WATCH_BUCKLE_HONEST,
		COMMISSION_WATCH_BUCKLE,
		ITEM_WATCH_BUCKLE,
		MOD_HONEST_WORK
	)

	assert_true(state.add_forged_record(record))
	assert_false(state.add_forged_record(record))
	assert_true(state.has_forged_record(RECORD_WATCH_BUCKLE_HONEST))

	var stored := state.get_forged_record(RECORD_WATCH_BUCKLE_HONEST)
	assert_eq(stored.record_id, RECORD_WATCH_BUCKLE_HONEST)
	assert_eq(stored.commission_id, COMMISSION_WATCH_BUCKLE)
	assert_eq(stored.item_id, ITEM_WATCH_BUCKLE)
	assert_eq(stored.modification_id, MOD_HONEST_WORK)


func test_forged_records_reject_empty_record_id() -> void:
	var state := GameState.new()
	var empty_record := ForgedRecord.new(
		&"",
		COMMISSION_WATCH_BUCKLE,
		ITEM_WATCH_BUCKLE,
		MOD_HONEST_WORK
	)

	assert_false(state.add_forged_record(empty_record))
	assert_false(state.has_forged_record(&""))
	assert_eq(state.get_forged_records().size(), 0)

func test_forged_records_list_is_sorted_and_isolated() -> void:
	var state := GameState.new()
	var second_record := ForgedRecord.new(
		&"forged.watch_buckle_repair.subtle_defect",
		COMMISSION_WATCH_BUCKLE,
		ITEM_WATCH_BUCKLE,
		&"subtle_defect"
	)
	var first_record := ForgedRecord.new(
		RECORD_WATCH_BUCKLE_HONEST,
		COMMISSION_WATCH_BUCKLE,
		ITEM_WATCH_BUCKLE,
		MOD_HONEST_WORK
	)

	state.add_forged_record(second_record)
	state.add_forged_record(first_record)

	var records := state.get_forged_records()
	assert_eq(records.size(), 2)
	assert_eq(records[0].record_id, RECORD_WATCH_BUCKLE_HONEST)
	assert_eq(records[1].record_id, second_record.record_id)

	var other_state := GameState.new()
	assert_eq(other_state.get_forged_records().size(), 0)
