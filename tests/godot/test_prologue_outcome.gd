extends "res://tests/godot/test_case.gd"

## R-1335: the porter duel's ending matters. Matron Gertrud's first line at the sickbed branches
## on the ending flag (ADR 0052; Kalev's used to), the closing cutscene echoes it, and the shove
## is recorded as guilt. Kalev's first line branches on the calming duel's ending instead.

const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const TestPresenterScript := preload("res://tests/godot/dialogue_test_presenter.gd")
const FakeCity := preload("res://tests/godot/fake_smithy_city.gd")
const CONFRONT := &"dialogue.prologue.porter_confrontation"
const KALEV := &"dialogue.prologue.kalev_arrives"
const CARRIED_IN := &"dialogue.prologue.lambert_carried_in"
const CLOSING := &"cutscene.prologue.taken_in"
const CONTENT_DIRS: Array[String] = [
	"res://content/prologue",
	"res://content/cutscenes",
	"res://content/examples/valid",
	"res://content/examples/support",
]
## Ending flag -> Gertrud's opening node and the closing cutscene's echo line.
const BRANCHES: Dictionary = {
	&"flag.prologue.struck_porter": ["matron_heard_struck", &"l1_struck"],
	&"flag.prologue.broke_porter": ["matron_heard_broke", &"l1_broke"],
	&"flag.prologue.punished_by_porter": ["matron_heard_punished", &"l1_punished"],
	&"flag.prologue.spared_porter": ["matron_vespers", &"l1_spared"],
}
## Calming-duel ending flag -> Kalev's opening node.
const KALEV_BRANCHES: Dictionary = {
	&"flag.prologue.lambert_frightened": "kalev_heard_screaming",
	&"flag.prologue.lambert_calmed": "kalev_found_quiet",
}
const ECHO_LINES: Array[StringName] = [&"l1_struck", &"l1_broke", &"l1_punished", &"l1_spared"]

var _state: GameState
var _db: ContentDB
var _runner: Node


func before_each() -> void:
	super.before_each()
	_state = GameState.new()
	_db = ContentDB.new()
	assert_true(_db.load_from_directories(CONTENT_DIRS))
	_runner = RunnerScript.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(_runner)
	_runner.configure(_db, _state, TestPresenterScript.new())


func after_each() -> void:
	if is_instance_valid(_runner):
		_runner.free()
	super.after_each()


func test_kalev_opens_with_the_default_line_when_no_ending_is_set() -> void:
	assert_true(_runner.start(KALEV))
	assert_eq(_runner.get_current_node_id(), "kalev_kneels")
	assert_true(_runner.start(CARRIED_IN))
	assert_eq(_runner.get_current_node_id(), "matron_vespers")


func test_gertrud_reacts_to_each_porter_ending_then_sets_the_boy_at_the_bed() -> void:
	for flag: StringName in BRANCHES:
		_state = GameState.new()
		_runner.configure(_db, _state, TestPresenterScript.new())
		_state.set_flag(flag, true)
		assert_true(_runner.start(CARRIED_IN), String(flag))
		var start_node := String((BRANCHES[flag] as Array)[0])
		assert_eq(_runner.get_current_node_id(), start_node, String(flag))
		if start_node != "matron_vespers":
			_runner.advance_for_test()
			assert_eq(_runner.get_current_node_id(), "matron_vespers", "reaction leads on")
		var guard := 0
		while not _runner.is_waiting_for_choice() and guard < 8:
			_runner.advance_for_test()
			guard += 1
		assert_eq(_runner.get_current_node_id(), "matron_to_boy", String(flag))
		assert_true(_runner.select_choice("kneel"))


func test_kalev_reacts_to_the_calming_duel_then_reaches_the_mark() -> void:
	for flag: StringName in KALEV_BRANCHES:
		_state = GameState.new()
		_runner.configure(_db, _state, TestPresenterScript.new())
		_state.set_flag(flag, true)
		assert_true(_runner.start(KALEV), String(flag))
		assert_eq(_runner.get_current_node_id(), String(KALEV_BRANCHES[flag]), String(flag))
		_runner.advance_for_test()
		assert_eq(_runner.get_current_node_id(), "kalev_kneels", "reaction leads to the bed")


func test_the_closing_cutscene_echoes_only_the_reached_ending() -> void:
	var record := _db.get_cutscene(CLOSING)
	assert_false(record.is_empty())
	for flag: StringName in BRANCHES:
		var state := GameState.new()
		state.set_flag(flag, true)
		var ids := _first_shot_line_ids(CutsceneSequence.from_record(record, state))
		var expected: StringName = (BRANCHES[flag] as Array)[1]
		for echo_id in ECHO_LINES:
			assert_eq(ids.has(echo_id), echo_id == expected, "%s with %s" % [echo_id, flag])
		assert_true(ids.has(&"l1") and ids.has(&"l2"), "unconditional lines stay")


func test_a_cutscene_without_state_drops_conditional_lines() -> void:
	var ids := _first_shot_line_ids(CutsceneSequence.from_record(_db.get_cutscene(CLOSING)))
	assert_eq(ids, [&"l1", &"l2"] as Array[StringName])


func test_each_duel_ending_sets_exactly_its_flag() -> void:
	var paths: Dictionary = {
		&"flag.prologue.spared_porter": ["still_hunger", "still_duty", "still_mercy"],
		&"flag.prologue.broke_porter": ["fire_hands", "fire_lock", "fire_secret"],
		&"flag.prologue.punished_by_porter": ["ward_rod", "say_nothing"],
		&"flag.prologue.struck_porter": ["shove"],
	}
	for flag: StringName in paths:
		var state := _duel_state()
		var duel := SpiritDuel.new()
		assert_true(duel.begin(_runner, _db, state, CONFRONT))
		for choice_id: String in paths[flag]:
			duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
			assert_true(duel.answer(choice_id), "%s %s" % [flag, choice_id])
		for other: StringName in paths:
			assert_eq(state.get_flag(other), other == flag, "%s after %s" % [other, flag])


func test_the_shove_is_recorded_once_as_guilt_against_an_unarmed_victim() -> void:
	var state := _duel_state()
	var duel := SpiritDuel.new()
	assert_true(duel.begin(_runner, _db, state, CONFRONT))
	duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_true(duel.answer("shove"))
	var applied := SmithyOpening.record_duel_guilt(state)
	assert_eq(applied, GuiltLedger.weights_for(&"act.unarmed_victim", false))
	assert_eq(state.guilt.level(GuiltLedger.SCHOOL_CHURCH), 4)
	assert_eq(state.guilt.level(GuiltLedger.SCHOOL_FOLK), 3)
	assert_eq(state.guilt.level(GuiltLedger.SCHOOL_CIVIC), 3)
	assert_eq(SmithyOpening.record_duel_guilt(state), {}, "recorded once")
	assert_eq(state.guilt.level(GuiltLedger.SCHOOL_CHURCH), 4)
	# The act survives a save round trip, so a reload cannot record it again.
	var saved := state.guilt.to_dict()
	assert_true((saved["acts"] as Dictionary).has(SmithyOpening.PORTER_BLOW_ACT))
	var reloaded := GuiltLedger.new()
	assert_eq(reloaded.from_dict(saved), [] as Array[String])
	assert_eq(reloaded.record_act(SmithyOpening.PORTER_BLOW_ACT, &"act.unarmed_victim"), {})


func test_other_endings_carry_no_guilt() -> void:
	var state := GameState.new()
	for flag: StringName in BRANCHES:
		if flag != SmithyOpening.FLAG_STRUCK_PORTER:
			state.set_flag(flag, true)
	assert_eq(SmithyOpening.record_duel_guilt(state), {})
	assert_eq(SmithyOpening.record_duel_guilt(null), {})
	for school in GuiltLedger.SCHOOLS:
		assert_eq(state.guilt.level(school), 0)


func test_the_opening_records_the_shove_when_the_duel_closes() -> void:
	SessionState.state.guilt.reset()
	SessionState.state.set_flag(SmithyOpening.FLAG_STRUCK_PORTER, false)
	var city := FakeCity.make()
	var opening := FakeCity.open_duel(city)
	assert_eq(opening.stage, SmithyOpening.STAGE_CONFRONTATION)
	var duel := opening.host().duel
	duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_true(duel.answer("shove"))
	opening.host().close()
	assert_eq(opening.stage, SmithyOpening.STAGE_CARRIED_IN)
	assert_eq(SessionState.state.guilt.level(GuiltLedger.SCHOOL_CHURCH), 4)
	assert_eq(opening.dialogue_runner().get_current_node_id(), "matron_heard_struck")
	opening.skip()
	city.free()


func _duel_state() -> GameState:
	var state := GameState.new()
	for grant_id: StringName in SmithyOpening.STARTER_GRANTS:
		MagicResolver.apply_grant_operation(state, _db, grant_id)
	state.set_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER, 8)
	return state


func _first_shot_line_ids(sequence: CutsceneSequence) -> Array[StringName]:
	var ids: Array[StringName] = []
	assert_true(sequence != null)
	if sequence == null:
		return ids
	for line: CutsceneSequence.Line in sequence.shots[0].lines:
		ids.append(line.id)
	return ids
