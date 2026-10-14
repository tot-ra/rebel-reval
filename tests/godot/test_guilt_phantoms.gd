extends "res://tests/godot/test_case.gd"

## SW-2 (R-1349): guilt phantoms in the Hingepuu - one per school with guilt, stats by tier,
## a won duel absolves, a lost one keeps the tier, victories survive a save.

const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const Hub := preload("res://scripts/reflection/hingepuu_hub.gd")
const CONTENT_DIRS: Array[String] = [
	"res://content/dialogue",
	"res://content/examples/support",
]

var _root: Node


func before_each() -> void:
	super.before_each()
	_root = Node.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(_root)


func after_each() -> void:
	_root.queue_free()
	super.after_each()


func _ledger(church: int, folk: int, civic: int) -> GuiltLedger:
	var ledger := GuiltLedger.new()
	assert_true(
		ledger.from_dict(
			{"levels": {"guilt.church": church, "guilt.folk": folk, "guilt.civic": civic}}
		).is_empty()
	)
	return ledger


func _won(broken: bool, node_id: String = "resolved_faced") -> Dictionary:
	return {"result": "won", "resolution_node_id": node_id, "broken": broken}


func test_no_guilt_means_no_phantoms() -> void:
	assert_true(GuiltPhantoms.phantoms_for(GuiltLedger.new()).is_empty())
	assert_true(GuiltPhantoms.phantoms_for(null).is_empty())


func test_one_phantom_per_school_with_tier_stats() -> void:
	# Levels 2 / 4 / 7 are tiers 1 / 2 / 3.
	var phantoms := GuiltPhantoms.phantoms_for(_ledger(2, 4, 7))
	assert_eq(phantoms.size(), 3)
	var expected := [
		[&"guilt.church", 1, 40.0, 1.0, &"dialogue.spirit.phantom.church", "minor"],
		[&"guilt.folk", 2, 60.0, 1.15, &"dialogue.spirit.phantom.folk", "heavy"],
		[&"guilt.civic", 3, 85.0, 1.3, &"dialogue.spirit.phantom.civic", "crushing"],
	]
	for index in expected.size():
		var row: Array = expected[index]
		var phantom: Dictionary = phantoms[index]
		assert_eq(phantom["school"], row[0])
		assert_eq(phantom["tier"], row[1])
		assert_eq(phantom["pressure_max"], row[2])
		assert_eq(phantom["blow_factor"], row[3])
		assert_eq(phantom["dialogue_id"], row[4])
		assert_eq(phantom["tier_word"], row[5])
		assert_false(String(phantom["name"]).is_empty())


func test_only_schools_with_guilt_spawn() -> void:
	var phantoms := GuiltPhantoms.phantoms_for(_ledger(0, 1, 0))
	assert_eq(phantoms.size(), 1)
	assert_eq(phantoms[0]["id"], &"phantom.guilt.folk")


func test_every_tier_of_every_school_scales_up() -> void:
	for school in GuiltLedger.SCHOOLS:
		var last_pressure := 0.0
		var last_blow := 0.0
		for level in [1, 3, 6]:
			var ledger := GuiltLedger.new()
			ledger.from_dict({"levels": {String(school): level}})
			var phantom: Dictionary = GuiltPhantoms.phantoms_for(ledger)[0]
			assert_eq(phantom["school"], school)
			assert_true(float(phantom["pressure_max"]) > last_pressure, String(school))
			assert_true(float(phantom["blow_factor"]) >= last_blow, String(school))
			last_pressure = float(phantom["pressure_max"])
			last_blow = float(phantom["blow_factor"])


func test_won_duel_lifts_tier_plus_one() -> void:
	var ledger := _ledger(4, 0, 0)
	assert_eq(GuiltPhantoms.apply_outcome(ledger, &"guilt.church", _won(false)), 3)
	assert_eq(ledger.level(&"guilt.church"), 1)
	assert_eq(ledger.phantom_victories(&"guilt.church"), 1)


func test_broken_phantom_clears_the_school() -> void:
	var ledger := _ledger(0, 8, 2)
	assert_eq(GuiltPhantoms.apply_outcome(ledger, &"guilt.folk", _won(true, "resolved_named")), 8)
	assert_eq(ledger.level(&"guilt.folk"), 0)
	assert_eq(ledger.level(&"guilt.civic"), 2)


func test_loss_or_turning_away_keeps_the_tier() -> void:
	var ledger := _ledger(0, 0, 5)
	var tier := ledger.debuff_tier(&"guilt.civic")
	for outcome in [
		{"result": "lost", "resolution_node_id": "", "broken": false},
		{"result": "idle", "resolution_node_id": "", "broken": false},
		_won(false, GuiltPhantoms.RESOLUTION_TURNED_AWAY),
		{},
	]:
		assert_eq(GuiltPhantoms.apply_outcome(ledger, &"guilt.civic", outcome), 0)
	assert_eq(ledger.level(&"guilt.civic"), 5)
	assert_eq(ledger.debuff_tier(&"guilt.civic"), tier)
	assert_eq(ledger.phantom_victories(&"guilt.civic"), 0)


func test_repeated_victories_use_their_own_rites() -> void:
	var ledger := _ledger(10, 0, 0)
	# 10 -> 6 is still tier 3 (crushing), so the second victory lifts four again.
	assert_eq(GuiltPhantoms.apply_outcome(ledger, &"guilt.church", _won(false)), 4)
	assert_eq(GuiltPhantoms.apply_outcome(ledger, &"guilt.church", _won(false)), 4)
	assert_eq(ledger.level(&"guilt.church"), 2)
	assert_eq(ledger.phantom_victories(&"guilt.church"), 2)
	var rites: Dictionary = ledger.to_dict()["absolutions"]
	assert_true(rites.has(&"rite.phantom.church.1"))
	assert_true(rites.has(&"rite.phantom.church.2"))


func test_victories_survive_a_save_round_trip() -> void:
	var state := GameState.new()
	state.guilt.from_dict({"levels": {"guilt.folk": 6}})
	GuiltPhantoms.apply_outcome(state.guilt, &"guilt.folk", _won(false))
	var loaded := GameState.new()
	assert_true(loaded.load_payload(state.save_payload()).is_empty())
	assert_eq(loaded.guilt.level(&"guilt.folk"), 2)
	assert_eq(loaded.guilt.phantom_victories(&"guilt.folk"), 1)
	# The next victory numbers on from the saved count.
	GuiltPhantoms.apply_outcome(loaded.guilt, &"guilt.folk", _won(false))
	assert_true((loaded.guilt.to_dict()["absolutions"] as Dictionary).has(&"rite.phantom.folk.2"))


func test_old_guilt_without_victories_still_loads() -> void:
	var ledger := GuiltLedger.new()
	var errors := ledger.from_dict(
		{"version": 1, "levels": {"guilt.church": 3}, "acts": {}, "absolutions": {}}
	)
	assert_true(errors.is_empty())
	assert_eq(ledger.phantom_victories(&"guilt.church"), 0)
	assert_false(ledger.from_dict({"phantom_victories": 3}).is_empty())


func test_duel_scales_default_to_neutral() -> void:
	var duel := SpiritDuel.new()
	assert_eq(duel.opponent_pressure_scale, 1.0)
	assert_eq(duel.opponent_blow_scale, 1.0)


func test_phantom_dialogues_are_duels_with_scaled_stats() -> void:
	var db := ContentDB.new()
	assert_true(db.load_from_directories(CONTENT_DIRS))
	var phantoms := GuiltPhantoms.phantoms_for(_ledger(1, 3, 6))
	for phantom in phantoms:
		var dialogue := db.get_dialogue(phantom["dialogue_id"])
		assert_false((dialogue.get("duel", {}) as Dictionary).is_empty(), String(phantom["id"]))
		assert_true(
			(dialogue["duel"]["resolution_node_ids"] as Array).has(GuiltPhantoms.RESOLUTION_TURNED_AWAY)
		)
		var runner := RunnerScript.new()
		_root.add_child(runner)
		var duel := SpiritDuel.new()
		GuiltPhantoms.configure_duel(duel, phantom)
		var state := GameState.new()
		assert_true(duel.begin(runner, db, state, phantom["dialogue_id"]), String(phantom["id"]))
		# A neutral soul keeps pool_factor at 1, so the pool is the tier's pressure.
		assert_almost_eq(duel.opponent.max_health, float(phantom["pressure_max"]), 0.001)
		assert_eq(duel.phase, SpiritDuel.PHASE_TELEGRAPH)
		duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
		# The opening blow is an attack (20) scaled by the tier.
		assert_almost_eq(
			duel.hero.health,
			SpiritDuel.COMPOSURE_MAX - 20.0 * float(phantom["blow_factor"]),
			0.001
		)
		duel.close()


func test_hub_shows_phantoms_and_requests_a_duel_near_one() -> void:
	var state := GameState.new()
	state.guilt.from_dict({"levels": {"guilt.church": 3}})
	var actor := Node2D.new()
	_root.add_child(actor)
	var hub := Hub.new() as HingepuuHub
	_root.add_child(hub)
	assert_true(hub.enter(state, actor))
	assert_eq(hub.phantoms().size(), 1)
	var requested: Array = []
	hub.phantom_duel_requested.connect(func(phantom: Dictionary) -> void: requested.append(phantom))
	assert_false(hub.request_phantom_duel())
	var spot := HingepuuHub.phantom_spot(hub.phantoms()[0])
	hub.set_actor_position(spot)
	assert_eq(hub.phantom_near(spot)["school"], &"guilt.church")
	assert_true(hub.request_phantom_duel())
	assert_eq(requested.size(), 1)
	assert_eq(requested[0]["tier"], 2)
	# No second duel while one is open; closing re-reads the ledger.
	hub.set_duel_open(true)
	assert_false(hub.request_phantom_duel())
	GuiltPhantoms.apply_outcome(state.guilt, &"guilt.church", _won(true))
	hub.set_duel_open(false)
	assert_true(hub.phantoms().is_empty())
	assert_true(hub.leave())


func test_controller_opens_the_arena_and_applies_the_outcome() -> void:
	var state := GameState.new()
	state.guilt.from_dict({"levels": {"guilt.civic": 4}})
	var db := ContentDB.new()
	assert_true(db.load_from_directories(CONTENT_DIRS))
	var actor := Node2D.new()
	_root.add_child(actor)
	var controller := ReflectionController.new()
	controller.content_db = db
	actor.add_child(controller)
	controller._bind_state(state)
	assert_true(controller.enter_hingepuu())
	var phantom: Dictionary = controller.get_hingepuu().phantoms()[0]
	assert_true(controller.face_phantom(phantom))
	var host := controller.phantom_duel_host()
	assert_true(host != null and host.is_open())
	assert_true(controller.get_hingepuu().is_duel_open())
	assert_almost_eq(host.duel.opponent.max_health, 60.0, 0.001)
	assert_false(controller.face_phantom(phantom))
	# Abandoning the duel lifts nothing and leaves the sight it switched on.
	host.close()
	assert_eq(controller.last_phantom_absolution, 0)
	assert_eq(state.guilt.level(&"guilt.civic"), 4)
	assert_false(state.spirit_sight)
	assert_true(controller.phantom_duel_host() == null)
	assert_false(controller.get_hingepuu().is_duel_open())
	# Play the civic duel to the end with the countering replies: a won duel lifts guilt.
	assert_true(controller.face_phantom(phantom))
	host = controller.phantom_duel_host()
	var replies := {"rises": "stand", "tallies": "pay_work", "sneers": "answer_for_it"}
	var steps := 0
	while not host.duel.is_over() and steps < 20:
		steps += 1
		if host.duel.phase == SpiritDuel.PHASE_TELEGRAPH:
			host.duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
		elif host.duel.phase == SpiritDuel.PHASE_ANSWER:
			var choice_ids: Array = host.duel.current_choices().map(
				func(choice: Variant) -> String: return String((choice as Dictionary).get("id", ""))
			)
			var pick := ""
			for reply: String in replies.values():
				if choice_ids.has(reply):
					pick = reply
			assert_true(host.duel.answer(pick), "reply %s in %s" % [pick, str(choice_ids)])
		else:
			host.duel.acknowledge()
	assert_eq(host.duel.phase, SpiritDuel.PHASE_WON)
	host.close()
	assert_true(controller.last_phantom_absolution >= 3)
	assert_true(state.guilt.level(&"guilt.civic") <= 1)
	assert_eq(state.guilt.phantom_victories(&"guilt.civic"), 1)
	assert_false((Engine.get_main_loop() as SceneTree).paused)
	controller.leave_hingepuu()
