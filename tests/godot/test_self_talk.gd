extends "res://tests/godot/test_case.gd"

## ADR 0033 / SD-09: talking to himself buffs the hero and is seen by witnesses.


func test_buff_cooldown_and_untouched_state_without_witnesses() -> void:
	var talk := SelfTalk.new()
	var vitals := CombatVitals.new()
	var state := GameState.new()
	var result := talk.perform(state, vitals, [])
	assert_true(result["ok"])
	assert_eq(result["reactions"], [])
	assert_almost_eq(vitals.modifiers.reduce_incoming_damage(10.0), 8.0, 0.001)
	assert_eq(state.get_pressure(GameState.PRESSURE_SUSPICION), 0)
	var again := talk.perform(state, vitals, [])
	assert_false(again["ok"])
	assert_eq(again["reason"], "cooldown")
	talk.tick(SelfTalk.COOLDOWN_SEC + 0.1)
	assert_true(talk.perform(state, vitals, [])["ok"])


func test_faction_rules_decide_the_reaction() -> void:
	var talk := SelfTalk.new()
	var state := GameState.new()
	var result := talk.perform(
		state,
		null,
		[
			{"id": "order_guard", "faction": "livonian_order"},
			{"id": "cloak_boy", "faction": "black_cloaks"},
			{"id": "baker", "faction": ""},
			{"id": "pirate", "faction": "vitalienbruder"},
		]
	)
	var by_witness: Dictionary = {}
	for reaction: Dictionary in result["reactions"]:
		by_witness[reaction["witness"]] = reaction["reaction"]
	assert_eq(
		by_witness,
		{
			"order_guard": "suspicion",
			"cloak_boy": "awe",
			"baker": "unease",
			"pirate": "amusement"
		}
	)
	assert_eq(state.get_faction_standing(&"livonian_order"), -1)
	assert_eq(state.get_faction_standing(&"black_cloaks"), 1)
	assert_eq(state.get_faction_standing(&"vitalienbruder"), 0)
	# livonian_order (+1) and the unaffiliated baker (+1) raise city suspicion.
	assert_eq(state.get_pressure(GameState.PRESSURE_SUSPICION), 2)


func test_each_witness_reacts_once_per_save() -> void:
	var talk := SelfTalk.new()
	var state := GameState.new()
	var witness := {"id": "order_guard", "faction": "livonian_order"}
	assert_eq(talk.perform(state, null, [witness])["reactions"].size(), 1)
	talk.tick(SelfTalk.COOLDOWN_SEC + 0.1)
	assert_eq(talk.perform(state, null, [witness])["reactions"].size(), 0)
	assert_eq(state.get_faction_standing(&"livonian_order"), -1)
	var restored := GameState.new()
	assert_eq(restored.load_payload(state.save_payload()), [])
	var other := SelfTalk.new()
	assert_eq(other.perform(restored, null, [witness])["reactions"].size(), 0)
	assert_eq(restored.get_faction_standing(&"livonian_order"), -1)


func test_suspicion_is_capped() -> void:
	var talk := SelfTalk.new()
	var state := GameState.new()
	var crowd: Array = []
	for i in 6:
		crowd.append({"id": "townsman_%d" % i, "faction": ""})
	talk.perform(state, null, crowd)
	assert_eq(state.get_pressure(GameState.PRESSURE_SUSPICION), GameState.PRESSURE_MAX)


func test_witnesses_are_found_by_distance_and_group() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var near := NPC.new()
	near.name = "Neighbour"
	near.witness_faction = &"hanseatic"
	tree.root.add_child(near)
	near.global_position = Vector2(100.0, 0.0)
	var far := NPC.new()
	far.name = "Stranger"
	tree.root.add_child(far)
	far.global_position = Vector2(5000.0, 0.0)
	var found := SelfTalk.witnesses_near(tree, Vector2.ZERO)
	assert_eq(found, [{"id": "neighbour", "faction": "hanseatic"}])
	near.free()
	far.free()


func test_the_action_is_bound_for_keyboard_and_gamepad() -> void:
	assert_true(InputMap.has_action(&"player_self_talk"))
	var kinds: Array[String] = []
	for event in InputMap.action_get_events(&"player_self_talk"):
		kinds.append(event.get_class())
	assert_true(kinds.has("InputEventKey"))
	assert_true(kinds.has("InputEventJoypadMotion"))
	var defaults := InputBindingSettings.default_settings()
	assert_true(defaults.events_for(&"player_self_talk", InputBindingSettings.DEVICE_GAMEPAD).size() > 0)
	assert_true(defaults.events_for(&"player_self_talk", InputBindingSettings.DEVICE_KEYBOARD_MOUSE).size() > 0)
