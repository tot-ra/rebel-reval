extends "res://tests/godot/test_case.gd"

## R-1886 stance, R-1887 talk to anyone, R-1889 spirit duel with anyone (ADR 0047).

const PLAYER_SCENE := preload("res://player.tscn")


## A resident's logic body: records being held for talk.
class FakePerson:
	extends CharacterBody2D
	var held := false
	var toward: Node2D

	func hold_for_talk(target: Node2D) -> void:
		held = true
		toward = target

	func release_talk() -> void:
		held = false


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _stage() -> Dictionary:
	restore_demo_session()
	SessionState.state.spirit_sight = false
	var root := Node.new()
	_tree().root.add_child(root)
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.global_position = Vector3(0, 6, 8)
	camera.current = true
	var player := PLAYER_SCENE.instantiate() as Player
	root.add_child(player)
	player.global_position = Vector2.ZERO
	var person := FakePerson.new()
	root.add_child(person)
	# 2 m away on the logic plane (32 px per metre).
	person.global_position = Vector2(64, 0)
	var rig := Node3D.new()
	world.add_child(rig)
	rig.global_position = Vector3(2, 0, 0)
	var body := MeshInstance3D.new()
	body.mesh = CapsuleMesh.new()
	rig.add_child(body)
	body.position = Vector3.UP
	return {"root": root, "world": world, "player": player, "person": person, "rig": rig}


func _who() -> Dictionary:
	return {
		"name": "Rein Niklase poeg",
		"title": "Fisherman",
		"side": "I keep to my own household and my trade.",
	}


func _conversation(stage: Dictionary) -> CharacterConversation:
	var conversation := CharacterConversation.new()
	(stage["root"] as Node).add_child(conversation)
	conversation.setup(stage["player"], stage["world"], stage["person"], stage["rig"], _who())
	return conversation


func _continue_until_choice(conversation: CharacterConversation) -> void:
	var guard := 0
	while not conversation.runner.is_waiting_for_choice() and guard < 10:
		conversation.ui.click_continue_for_test()
		guard += 1


func test_stance_starts_peaceful_and_toggles() -> void:
	var player := PLAYER_SCENE.instantiate() as Player
	_tree().root.add_child(player)
	assert_false(player.weapon_drawn, "peaceful by default")
	var seen: Array = []
	player.weapon_drawn_changed.connect(func(drawn: bool) -> void: seen.append(drawn))
	player.toggle_weapon_drawn()
	assert_true(player.weapon_drawn)
	player.toggle_weapon_drawn()
	assert_false(player.weapon_drawn)
	assert_eq(seen, [true, false])
	assert_true(InputMap.has_action(&"player_draw_weapon"), "G draws the weapon")
	player.free()


func test_hover_tag_tells_what_a_click_does() -> void:
	var stage := _stage()
	var player: Player = stage["player"]
	var person: Node2D = stage["person"]
	assert_eq(CharacterConversation.tag_text("Rein", player, person), "Rein\nE  Talk")
	player.set_weapon_drawn(true)
	assert_eq(CharacterConversation.tag_text("Rein", player, person), "Rein\nLMB  Strike")
	person.global_position = Vector2(32 * 10, 0)
	var far := CharacterConversation.tag_text("Rein", player, person)
	assert_eq(far, "Rein", "out of reach: name only")
	(stage["root"] as Node).free()


func test_talk_holds_the_person_and_speaks_with_their_name() -> void:
	var stage := _stage()
	var player: Player = stage["player"]
	player.set_weapon_drawn(true)
	var conversation := _conversation(stage)
	assert_true(conversation.begin_talk())
	assert_true(CharacterConversation.active(_tree()) == conversation)
	assert_false(player.weapon_drawn, "talking sheathes the weapon")
	assert_true((stage["person"] as FakePerson).held, "the person stops for the talk")
	assert_true(player.is_movement_input_blocked(), "the hero stands while talking")
	var speaker := conversation.ui.get_speaker_label_text()
	assert_eq(speaker, "Rein Niklase poeg", "the placeholder speaks with their name")
	var shot := conversation.shot
	assert_true(shot != null and shot.camera != null, "the conversation is framed")
	_continue_until_choice(conversation)
	conversation.ui.select_choice_for_test("who")
	assert_eq(conversation.runner.get_current_node_id(), "who_answer")
	var outcome: Array = []
	conversation.ended.connect(func(o: StringName) -> void: outcome.append(o))
	_continue_until_choice(conversation)
	conversation.ui.select_choice_for_test("bye")
	var guard := 0
	while conversation.runner != null and conversation.runner.is_active() and guard < 10:
		conversation.ui.click_continue_for_test()
		guard += 1
	assert_eq(outcome, [CharacterConversation.OUTCOME_TALK])
	assert_false((stage["person"] as FakePerson).held, "the person goes back to the day")
	assert_true(CharacterConversation.active(_tree()) == null)
	(stage["root"] as Node).free()


func test_who_are_you_fills_the_tokens() -> void:
	var stage := _stage()
	var conversation := _conversation(stage)
	var tokens := conversation.tokens()
	assert_eq(tokens["interlocutor_title"], "fisherman", "the title reads mid-sentence")
	assert_true(conversation.begin_talk())
	_continue_until_choice(conversation)
	conversation.ui.select_choice_for_test("who")
	conversation.ui.request_continue()
	assert_true(
		conversation.ui.get_visible_line_text().begins_with("Rein Niklase poeg, fisherman.")
		or conversation.runner.get_current_node_id() == "who_answer",
		"who_answer speaks the person's name and trade"
	)
	conversation.queue_free()
	(stage["root"] as Node).free()


func test_inner_eye_rises_to_the_play_view_and_opens_a_spirit_duel() -> void:
	var stage := _stage()
	var conversation := _conversation(stage)
	assert_true(conversation.begin_talk())
	_continue_until_choice(conversation)
	conversation.ui.select_choice_for_test(CharacterConversation.INNER_EYE_CHOICE)
	var guard := 0
	while conversation.runner != null and conversation.runner.is_active() and guard < 10:
		conversation.ui.click_continue_for_test()
		guard += 1
	assert_eq(conversation.stage, CharacterConversation.STAGE_RISING, "the camera rises first")
	assert_true(conversation.shot.is_releasing())
	# Finish the crane now instead of waiting for the tween.
	conversation.shot.release()
	assert_eq(conversation.stage, CharacterConversation.STAGE_DUEL)
	assert_true(conversation.host != null and conversation.host.is_open(), "the duel is open")
	assert_true(SessionState.state.spirit_sight, "a duel is fought in spirit sight")
	assert_true((stage["person"] as FakePerson).held, "the person stays for the duel")
	var outcome: Array = []
	conversation.ended.connect(func(o: StringName) -> void: outcome.append(o))
	conversation.host.close()
	assert_eq(outcome, [CharacterConversation.OUTCOME_DUEL])
	assert_false((stage["person"] as FakePerson).held)
	SessionState.state.spirit_sight = false
	(stage["root"] as Node).free()


func test_in_spirit_sight_a_click_opens_the_duel_directly() -> void:
	var stage := _stage()
	SessionState.state.spirit_sight = true
	var player: Player = stage["player"]
	assert_true(player.is_spirit_sight_active() or SessionState.state.spirit_sight)
	assert_eq(CharacterConversation.action_hint(player), "E  Spirit duel")
	var conversation := _conversation(stage)
	assert_true(conversation.begin_duel())
	assert_true(conversation.host.is_open())
	assert_true(conversation.ui == null, "no small talk in sight")
	conversation.host.close()
	SessionState.state.spirit_sight = false
	(stage["root"] as Node).free()
