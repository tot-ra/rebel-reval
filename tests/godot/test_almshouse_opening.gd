extends "res://tests/godot/test_case.gd"

## ADR 0033 / ADR 0034: New Game opens on the historical prologue cutscene, which chains
## into the almshouse; the sequence reaches the forge.

const OPENING_SCENE := preload("res://scenes/prologue/almshouse_opening.tscn")
const CUTSCENE_SCENE := "res://scenes/cutscene/prologue_opening.tscn"
const ALMSHOUSE_SCENE := "res://scenes/prologue/almshouse_opening.tscn"


func _opening() -> AlmshouseOpening:
	SessionState.state.set_flag(&"flag.prologue.apprenticed", false)
	var opening := OPENING_SCENE.instantiate() as AlmshouseOpening
	opening.auto_continue = false
	(Engine.get_main_loop() as SceneTree).root.add_child(opening)
	return opening


func test_start_label_routes_new_game_to_the_opening_cutscene() -> void:
	var script: GDScript = load("res://scenes/intro/start_label.gd")
	assert_eq(script.get_script_constant_map()["OPENING_SCENE"], CUTSCENE_SCENE)
	assert_true(ResourceLoader.exists(CUTSCENE_SCENE))


func test_the_opening_cutscene_chains_into_the_almshouse() -> void:
	# The chain lives in the record, not in code, so assert the record points at the scene.
	var record := SessionState.content_db.get_cutscene(&"cutscene.prologue.conquest")
	assert_false(record.is_empty(), "conquest cutscene is loaded in the session")
	var next_target: Dictionary = record.get("next", {})
	assert_eq(String(next_target.get("kind", "")), "scene_file")
	assert_eq(String(next_target.get("scene_path", "")), ALMSHOUSE_SCENE)
	assert_true(ResourceLoader.exists(ALMSHOUSE_SCENE))


func test_the_prologue_content_is_loaded_in_the_session() -> void:
	for dialogue_id: StringName in [
		AlmshouseOpening.CONFRONTATION, AlmshouseOpening.KALEV_ARRIVES
	]:
		assert_false(SessionState.content_db.get_dialogue(dialogue_id).is_empty(), String(dialogue_id))


func test_the_opening_runs_title_spell_duel_and_kalev_then_finishes() -> void:
	var opening := _opening()
	var done := [false]
	opening.finished.connect(func() -> void: done[0] = true)
	assert_eq(opening.stage, AlmshouseOpening.STAGE_TITLE)
	assert_true(opening.begin_duel())
	assert_eq(opening.stage, AlmshouseOpening.STAGE_CONFRONTATION)
	assert_true(SessionState.state.has_magic_grant(&"spell.pagan.fireball"), "first spells granted")
	var duel := opening.host().duel
	duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_eq(duel.phase, SpiritDuel.PHASE_ANSWER, "phase before answering")
	# Every reply is a cast: the spell lands pressure on the porter and spends willpower.
	var willpower_before := SessionState.state.get_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER)
	assert_true(duel.answer("fire_hands"), "cast fireball")
	assert_true(duel.opponent.health < SpiritDuel.PRESSURE_MAX - 18.0, "spell + reply hurt him")
	assert_true(SessionState.state.get_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER) < willpower_before)  # gdlint: ignore=max-line-length
	duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_true(duel.answer("still_duty"), "cast earth tremor")
	duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_true(duel.answer("still_mercy"), "final cast")
	assert_eq(duel.last_outcome["resolution_node_id"], "resolved_spared")
	opening.host().close()
	assert_eq(opening.stage, AlmshouseOpening.STAGE_KALEV)
	var runner := opening.dialogue_runner()
	var ui := opening.dialogue_ui()
	var guard := 0
	while not runner.is_waiting_for_choice() and guard < 20:
		ui.click_continue_for_test()
		guard += 1
	assert_true(runner.is_waiting_for_choice(), "Kalev asks a question")
	ui.select_choice_for_test("yes")
	guard = 0
	while runner.is_active() and guard < 20:
		ui.click_continue_for_test()
		guard += 1
	assert_true(done[0])
	assert_eq(opening.stage, AlmshouseOpening.STAGE_DONE)
	assert_true(SessionState.state.get_flag(&"flag.prologue.apprenticed"))
	assert_false(SessionState.state.in_spirit_world)
	opening.free()


func test_a_spell_reply_without_willpower_is_refused_and_leaves_the_choice_open() -> void:
	var opening := _opening()
	opening.begin_duel()
	var duel := opening.host().duel
	SessionState.state.set_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER, 0)
	duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_false(duel.answer("fire_hands"))
	assert_eq(duel.last_cast_failure, MagicResolver.FAILURE_INSUFFICIENT_WILLPOWER)
	assert_eq(duel.phase, SpiritDuel.PHASE_ANSWER)
	opening.free()


func test_escape_on_the_title_card_skips_to_the_forge() -> void:
	var opening := _opening()
	var done := [false]
	opening.finished.connect(func() -> void: done[0] = true)
	opening.skip()
	assert_true(done[0])
	assert_true(SessionState.state.get_flag(&"flag.prologue.apprenticed"))
	opening.free()


func test_skip_during_the_duel_goes_straight_to_the_forge() -> void:
	var opening := _opening()
	var done := [false]
	opening.finished.connect(func() -> void: done[0] = true)
	assert_true(opening.begin_duel())
	opening.skip()
	assert_eq(opening.stage, AlmshouseOpening.STAGE_DONE)
	assert_true(done[0])
	assert_true(SessionState.state.get_flag(&"flag.prologue.apprenticed"))
	opening.queue_free()
