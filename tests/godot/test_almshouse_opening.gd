extends "res://tests/godot/test_case.gd"

## ADR 0033: New Game opens in the almshouse (the conquest vision was removed, R-1763);
## the sequence reaches the forge.

const OPENING_SCENE := preload("res://scenes/prologue/almshouse_opening.tscn")
const ALMSHOUSE_SCENE := "res://scenes/prologue/almshouse_opening.tscn"


func _opening() -> AlmshouseOpening:
	SessionState.state.set_flag(&"flag.prologue.apprenticed", false)
	var opening := OPENING_SCENE.instantiate() as AlmshouseOpening
	opening.auto_continue = false
	(Engine.get_main_loop() as SceneTree).root.add_child(opening)
	return opening


func test_start_label_routes_new_game_straight_to_the_almshouse() -> void:
	var script: GDScript = load("res://scenes/intro/start_label.gd")
	assert_eq(script.get_script_constant_map()["OPENING_SCENE"], ALMSHOUSE_SCENE)
	assert_true(ResourceLoader.exists(ALMSHOUSE_SCENE))
	# R-1763: the still-image vision is gone until its video remake.
	assert_true(SessionState.content_db.get_cutscene(&"cutscene.prologue.conquest").is_empty())


func test_the_prologue_content_is_loaded_in_the_session() -> void:
	for dialogue_id: StringName in [
		AlmshouseOpening.CONFRONTATION, AlmshouseOpening.KALEV_ARRIVES
	]:
		assert_false(SessionState.content_db.get_dialogue(dialogue_id).is_empty(), String(dialogue_id))


func test_the_opening_runs_title_spell_duel_and_kalev_then_finishes() -> void:
	var opening := _opening()
	var done := [false]
	opening.finished.connect(func() -> void: done[0] = true)
	assert_eq(opening.stage, AlmshouseOpening.STAGE_CONFRONTATION)
	assert_true(opening.begin_duel()) # Already running; preserves callers that request it.
	assert_eq(opening.stage, AlmshouseOpening.STAGE_CONFRONTATION)
	assert_true(SessionState.state.has_magic_grant(&"spell.pagan.fireball"), "first spells granted")
	var duel := opening.host().duel
	duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_eq(duel.phase, SpiritDuel.PHASE_ANSWER, "phase before answering")
	# Every reply is a cast: the spell lands pressure on the porter and spends willpower.
	var willpower_before := SessionState.state.get_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER)
	assert_true(duel.answer("fire_hands"), "cast fireball")
	# R-1764: the porter's own soul lights size his pressure pool, so compare with his maximum.
	assert_true(duel.opponent.health < duel.opponent.max_health - 18.0, "spell + reply hurt him")
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



## R-1764: the won duel shows a clear banner and hands over to Kalev on its own.
func test_a_won_duel_shows_the_banner_and_moves_on_without_a_keypress() -> void:
	var opening := _opening()
	opening.begin_duel()
	var host := opening.host()
	var duel := host.duel
	for reply: String in ["fire_hands", "still_duty", "still_mercy"]:
		duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
		assert_true(duel.answer(reply), reply)
	assert_eq(duel.phase, SpiritDuel.PHASE_WON)
	assert_eq(host.end_banner_text(), "The duel is won")
	host._process(SpiritArenaHost.WIN_AUTO_CLOSE_SEC * 0.5)
	assert_true(host.is_open(), "the win holds for a beat")
	assert_eq(opening.stage, AlmshouseOpening.STAGE_CONFRONTATION)
	host._process(SpiritArenaHost.WIN_AUTO_CLOSE_SEC)
	assert_eq(opening.stage, AlmshouseOpening.STAGE_KALEV, "closed itself and Kalev walks in")
	opening.free()


## R-1764: on the staged porter a word flies at his soul light of its colour, and the duel
## scores the same lights the player sees.
func test_words_aim_at_the_porters_soul_lights() -> void:
	var opening := _opening()
	opening.begin_duel()
	var host := opening.host()
	assert_true(host.opponent_aura != null, "the porter's visible aura feeds the duel")
	var view := host.opponent_aura_view
	assert_true(view != null)
	var love := SpiritAuraProfile.LIGHT_IDS.find(SpiritDuel.light_for_element(&"love"))
	assert_true(host.light_target(&"love").is_equal_approx(view.anchors[love]))
	assert_false(host.light_target(&"love").is_equal_approx(host.light_target(&"faith")))
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


func test_escape_during_the_duel_skips_to_the_forge() -> void:
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
