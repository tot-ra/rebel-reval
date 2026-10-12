extends "res://tests/godot/test_case.gd"

## R-1872: New Game arrives in the city smithy and the porter duel is fought there, in place,
## with the normal city player; composure shows in the vitals HUD, the porter's pressure as his
## overhead bar, and the word slots carry painted sigils.

const VitalsHud := preload("res://scripts/ui/player_vitals_hud.gd")


## Stand-in for the city level: what SmithyOpening reads from it (player, world, plan).
class FakeCity:
	extends Node
	var player: Node2D
	var world: Node3D
	var plan: Variant = null


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


func _city() -> FakeCity:
	SessionState.state.set_flag(&"flag.prologue.apprenticed", false)
	var city := FakeCity.new()
	city.player = Node2D.new()
	city.player.global_position = Vector2(10, 10) * CityPlan.LOGIC_PX_PER_UNIT
	city.add_child(city.player)
	city.world = Node3D.new()
	city.add_child(city.world)
	(Engine.get_main_loop() as SceneTree).root.add_child(city)
	return city


func _consume(city: FakeCity) -> SmithyOpening:
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
	city.free()


func test_word_slots_have_painted_sigils() -> void:
	for element: StringName in SpiritWordSpells.DEFAULT_ELEMENTS:
		var icon: Texture2D = SpiritCastBar.ICONS.get(String(element))
		assert_true(icon != null, String(element))
		assert_true(icon.get_width() >= 128, String(element))
