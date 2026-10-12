extends "res://tests/godot/test_case.gd"

## R-1872: New Game arrives in the city smithy and the porter duel is fought there, in place,
## with the normal city player; composure shows in the vitals HUD, the porter's pressure as his
## overhead bar, and the word slots carry painted sigils.

const VitalsHud := preload("res://scripts/ui/player_vitals_hud.gd")
const ConversationShotScript := preload("res://scripts/prologue/conversation_shot.gd")
const FakeCity := preload("res://tests/godot/fake_smithy_city.gd")


class FakeDuelHost:
	extends Node
	var composure := Vector2(7, 10)

	func hero_composure() -> Vector2:
		return composure


class FakeVitals:
	extends Node
	var health := 80.0
	var max_health := 100.0
	var stamina := 100.0
	var max_stamina := 100.0


func _city() -> Node:
	return FakeCity.make()


func _consume(city: Node) -> SmithyOpening:
	SmithyOpening.pending = true
	var opening := SmithyOpening.consume(city)
	assert_true(opening != null)
	assert_true(opening.begin_duel(), "the duel opens in place")
	return opening


func test_new_game_loads_no_separate_opening_scene() -> void:
	var source := (load("res://scenes/intro/start_label.gd") as GDScript).source_code
	assert_false(source.contains("change_scene_to_file"), "no opening scene of its own")
	assert_true(source.contains("SmithyOpening.start_new_game"))
	SmithyOpening.pending = false
	var city := _city()
	assert_true(SmithyOpening.consume(city) == null, "nothing pending, no opening")
	SmithyOpening.pending = true
	var opening := SmithyOpening.consume(city)
	assert_true(opening != null and opening.get_parent() == city)
	assert_false(SmithyOpening.pending, "consumed once")
	city.free()


func test_the_duel_is_fought_in_the_city_world_with_the_city_player() -> void:
	var city := _city()
	var opening := _consume(city)
	var host := opening.host()
	assert_eq(opening.stage, SmithyOpening.STAGE_CONFRONTATION)
	assert_true(city.world.is_ancestor_of(opening.porter()), "porter stands in the city world")
	assert_true(city.world.is_ancestor_of(host.arena_3d), "arena is a disc in the city")
	assert_true(host.motion != null, "real-time arena: the hero moves as in normal play")
	# Moving the city player moves the duel's hero (logic plane, 32 px per metre).
	city.player.global_position += Vector2(CityPlan.LOGIC_PX_PER_UNIT, 0)
	host._tick_motion(0.0)
	assert_almost_eq(host.motion.hero_position.x, city.player.global_position.x / CityPlan.LOGIC_PX_PER_UNIT, 0.01)  # gdlint: ignore=max-line-length
	assert_true(SessionState.state.has_magic_grant(&"spell.pagan.fireball"), "first spells granted")
	opening.skip()
	city.free()


func test_health_shows_like_normal_play() -> void:
	var city := _city()
	var opening := _consume(city)
	var host := opening.host()
	host._refresh_bars()
	var ring := host.opponent_ring()
	assert_true(ring != null and ring.visible, "porter's pressure is his overhead bar")
	assert_true(opening.porter().is_ancestor_of(ring))
	assert_almost_eq(ring.get_health_ratio(), host.duel.opponent.health / host.duel.opponent.max_health, 0.001)  # gdlint: ignore=max-line-length
	assert_false(host._composure_bar.visible, "no 2D composure bar in the world")
	assert_false(host._pressure_bar.visible, "no 2D pressure bar in the world")
	assert_eq(host.hero_composure(), Vector2(host.duel.hero.health, host.duel.hero.max_health))
	opening.skip()
	assert_eq(host.hero_composure(), Vector2.ZERO, "duel closed: vitals back to health")
	city.free()


func test_vitals_hud_shows_composure_while_a_duel_is_open() -> void:
	var source := FakeVitals.new()
	var hud := VitalsHud.new()
	source.add_child(hud)
	(Engine.get_main_loop() as SceneTree).root.add_child(source)
	hud.follow_settings = false
	hud._process(0.0)
	assert_eq(hud.health_title(), "HEALTH")
	var duel_host := FakeDuelHost.new()
	duel_host.add_to_group(&"spirit_duel_open")
	source.add_child(duel_host)
	hud._process(0.0)
	assert_eq(hud.health_title(), "COMPOSURE")
	assert_eq(hud._health_label.text, "COMPOSURE   7 / 10")
	duel_host.remove_from_group(&"spirit_duel_open")
	hud._process(0.0)
	assert_eq(hud._health_label.text, "HEALTH   80 / 100")
	source.free()


func test_the_won_duel_brings_in_kalev_and_play_continues_in_the_smithy() -> void:
	var city := _city()
	var opening := _consume(city)
	var done := [false]
	opening.finished.connect(func() -> void: done[0] = true)
	var duel := opening.host().duel
	for reply: String in ["fire_hands", "still_duty", "still_mercy"]:
		duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
		assert_true(duel.answer(reply), reply)
	opening.host().close()
	assert_eq(opening.stage, SmithyOpening.STAGE_KALEV)
	assert_true(opening.kalev() != null and city.world.is_ancestor_of(opening.kalev()))
	# R-1877: Kalev's arrival is framed in the same world; the porter is gone at the cut.
	assert_true(opening.porter() == null, "the porter has gone out of the door")
	var shot := opening.shot()
	assert_true(shot != null and shot.camera != null, "a conversation shot frames Kalev")
	assert_true(city.world.is_ancestor_of(shot.camera), "the shot camera lives in the city world")
	var runner := opening.dialogue_runner()
	var ui: Node = opening.get_children().filter(func(n: Node) -> bool: return n is DialogueUI)[0]
	var guard := 0
	while not runner.is_waiting_for_choice() and guard < 20:
		ui.click_continue_for_test()
		guard += 1
	ui.select_choice_for_test("yes")
	guard = 0
	while runner.is_active() and guard < 20:
		ui.click_continue_for_test()
		guard += 1
	assert_true(done[0])
	assert_eq(opening.stage, SmithyOpening.STAGE_DONE)
	assert_true(SessionState.state.get_flag(&"flag.prologue.apprenticed"))
	assert_true(opening.porter() == null, "the porter leaves")
	assert_true(opening.kalev() != null, "Kalev stays in his forge")
	assert_true(opening.shot() == null, "the gameplay camera is handed back")
	city.free()


func test_conversation_shot_frames_both_speakers_at_eye_level() -> void:
	var points: Array[Vector3] = [Vector3(0, 0, 0), Vector3(2.7, 0, 0.6)]
	var framed: Dictionary = ConversationShotScript.compute_shot(
		points, Vector3(1, 1.6, 6), 16.0 / 9.0
	)
	var shot: Transform3D = framed["transform"]
	assert_true(shot.origin.z > 0.0, "the camera takes the side the gameplay camera was on")
	assert_true(absf(shot.origin.y - ConversationShotScript.EYE_HEIGHT) < 0.01, "eye level")
	var camera := Camera3D.new()
	camera.fov = framed["fov"]
	camera.transform = shot
	for point in points:
		var head := point + Vector3.UP * 1.6
		var local := shot.affine_inverse() * head
		assert_true(local.z < 0.0, "speaker in front of the lens")
		var half_v := tan(deg_to_rad(camera.fov) * 0.5)
		assert_true(absf(local.x / -local.z) < half_v * 16.0 / 9.0, "speaker inside the frame")
	camera.free()
	# A small room holds the camera close; the lens widens rather than cropping a speaker.
	var held: Dictionary = ConversationShotScript.compute_shot(
		points, Vector3(1, 1.6, 6), 16.0 / 9.0, Vector3(1.35, 0, 0.3), 1.5
	)
	assert_true(float(held["fov"]) > float(framed["fov"]), "lens widens when the room is tight")


func test_word_slots_have_painted_sigils() -> void:
	for element: StringName in SpiritWordSpells.DEFAULT_ELEMENTS:
		var icon: Texture2D = SpiritCastBar.ICONS.get(String(element))
		assert_true(icon != null, String(element))
		assert_true(icon.get_width() >= 128, String(element))


## Ported from the retired almshouse-hall tests (the duel itself is fought the same way here).
func test_the_prologue_content_is_loaded_in_the_session() -> void:
	for dialogue_id: StringName in [SmithyOpening.CONFRONTATION, SmithyOpening.KALEV_ARRIVES]:
		assert_false(SessionState.content_db.get_dialogue(dialogue_id).is_empty(), String(dialogue_id))
	# R-1763: the still-image vision is gone until its video remake.
	assert_true(SessionState.content_db.get_cutscene(&"cutscene.prologue.conquest").is_empty())


func test_spells_are_the_replies_and_spend_willpower() -> void:
	var city := _city()
	var opening := _consume(city)
	var duel := opening.host().duel
	duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_eq(duel.phase, SpiritDuel.PHASE_ANSWER, "phase before answering")
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
	opening.skip()
	city.free()


func test_a_won_duel_shows_the_banner_and_moves_on_without_a_keypress() -> void:
	var city := _city()
	var opening := _consume(city)
	var host := opening.host()
	var duel := host.duel
	for reply: String in ["fire_hands", "still_duty", "still_mercy"]:
		duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
		assert_true(duel.answer(reply), reply)
	assert_eq(duel.phase, SpiritDuel.PHASE_WON)
	assert_eq(host.end_banner_text(), "The duel is won")
	host._process(SpiritArenaHost.WIN_AUTO_CLOSE_SEC * 0.5)
	assert_true(host.is_open(), "the win holds for a beat")
	assert_eq(opening.stage, SmithyOpening.STAGE_CONFRONTATION)
	host._process(SpiritArenaHost.WIN_AUTO_CLOSE_SEC)
	assert_eq(opening.stage, SmithyOpening.STAGE_KALEV, "closed itself and Kalev walks in")
	opening.skip()
	city.free()


## R-1764: on the porter a word flies at his soul light of its colour, and the duel scores the
## same lights the player sees.
func test_words_aim_at_the_porters_soul_lights() -> void:
	var city := _city()
	var opening := _consume(city)
	var host := opening.host()
	assert_true(host.opponent_aura != null, "the porter's visible aura feeds the duel")
	var view := host.opponent_aura_view
	assert_true(view != null)
	var love := SpiritAuraProfile.LIGHT_IDS.find(SpiritDuel.light_for_element(&"love"))
	assert_true(host.light_target(&"love").is_equal_approx(view.anchors[love]))
	assert_false(host.light_target(&"love").is_equal_approx(host.light_target(&"faith")))
	opening.skip()
	city.free()


func test_a_spell_reply_without_willpower_is_refused_and_leaves_the_choice_open() -> void:
	var city := _city()
	var opening := _consume(city)
	var duel := opening.host().duel
	SessionState.state.set_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER, 0)
	duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_false(duel.answer("fire_hands"))
	assert_eq(duel.last_cast_failure, MagicResolver.FAILURE_INSUFFICIENT_WILLPOWER)
	assert_eq(duel.phase, SpiritDuel.PHASE_ANSWER)
	opening.skip()
	city.free()


func test_skip_during_the_duel_finishes_the_opening() -> void:
	var city := _city()
	var opening := _consume(city)
	var done := [false]
	opening.finished.connect(func() -> void: done[0] = true)
	opening.skip()
	assert_eq(opening.stage, SmithyOpening.STAGE_DONE)
	assert_true(done[0])
	assert_true(SessionState.state.get_flag(&"flag.prologue.apprenticed"))
	city.free()


func test_skip_before_the_duel_opens_still_finishes() -> void:
	var city := _city()
	SmithyOpening.pending = true
	var opening := SmithyOpening.consume(city)
	var done := [false]
	opening.finished.connect(func() -> void: done[0] = true)
	opening.skip()
	assert_true(done[0])
	assert_true(SessionState.state.get_flag(&"flag.prologue.apprenticed"))
	city.free()
