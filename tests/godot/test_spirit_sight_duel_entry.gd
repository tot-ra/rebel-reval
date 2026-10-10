extends "res://tests/godot/test_case.gd"

## SS-7 (R-1490, ADR 0041 sections 1-2): duels start only from spirit sight. Challenge on a
## duel-ready person in sight, the scripted path switches sight on first, and closing a duel
## leaves the hero in sight.

const Sight := preload("res://scripts/combat/spirit_sight.gd")
const Bindings := preload("res://scripts/settings/input_binding_settings.gd")
const INTERACTABLE_SCENE := preload("res://scenes/interaction/interactable.tscn")
const OPENING_SCENE := preload("res://scenes/prologue/almshouse_opening.tscn")
## The prologue duel names the porter and the apprentice; the quarrel he has with the matron
## is observed, never fought, so she offers no challenge.
const PORTER := &"char.almshouse_porter"
const MATRON := &"char.almshouse_matron"
const DUEL_ID := &"dialogue.prologue.porter_confrontation"
const PLAIN_ID := &"dialogue.prologue.kalev_arrives"

var _root: Node3D
var _sight: Node
var _state: GameState
var _db: ContentDB
var _actor: Node2D


func before_each() -> void:
	super.before_each()
	_db = SessionState.content_db
	_state = GameState.new()
	_root = Node3D.new()
	_tree().root.add_child(_root)
	_sight = Sight.new()
	_sight.follow_session = false
	_sight.state = _state
	_sight.content_db = _db
	_sight.environment_override = Environment.new()
	_root.add_child(_sight)
	_actor = Node2D.new()
	_root.add_child(_actor)


func after_each() -> void:
	_tree().paused = false
	_root.free()
	super.after_each()


func test_duel_record_needs_the_hero_as_a_participant() -> void:
	assert_eq(Sight.duel_for(PORTER, _db), DUEL_ID)
	assert_eq(Sight.duel_for(MATRON, _db), &"", "an observed quarrel is not a challenge")
	assert_eq(Sight.duel_for(Sight.HERO_ID, _db), &"", "the hero never challenges himself")
	assert_eq(Sight.duel_for(&"", _db), &"")


func test_challenge_prompt_only_in_spirit_sight() -> void:
	var porter := _person(PORTER)
	var matron := _person(MATRON)
	assert_eq(porter.get_prompt(), "Talk", "physical layer keeps the normal prompt")
	_state.spirit_sight = true
	assert_eq(porter.get_prompt(), Sight.CHALLENGE_PROMPT)
	assert_eq(matron.get_prompt(), "Talk", "no duel record, no challenge")
	var nameless := _person(&"")
	assert_eq(nameless.get_prompt(), "Talk", "a sensor without a person is never a challenge")


func test_interact_in_sight_opens_the_duel_and_keeps_sight() -> void:
	var porter := _person(PORTER)
	var talked := [false]
	porter.set_interact_callback(func(_who: Node) -> void: talked[0] = true)
	_state.spirit_sight = true
	assert_true(porter.interact(_actor))
	var host: SpiritArenaHost = _sight.challenge_host
	assert_true(host != null and host.is_open(), "Challenge opens the duel in place")
	assert_false(talked[0], "the challenge replaces the normal interaction")
	assert_true(_state.spirit_sight)
	_sight.enforce_availability()
	assert_true(_state.spirit_sight, "the duel's pause and modal flags do not cancel sight")
	assert_ne(porter.get_prompt(), Sight.CHALLENGE_PROMPT, "no second challenge while one is open")
	host.close()
	assert_true(host.is_queued_for_deletion())
	assert_true(_sight.challenge_host == null)
	_sight.enforce_availability()
	assert_true(_state.spirit_sight, "after the duel the hero stays in spirit sight")
	assert_eq(porter.get_prompt(), Sight.CHALLENGE_PROMPT, "the person can be challenged again")


func test_interact_outside_sight_is_the_normal_interaction() -> void:
	var porter := _person(PORTER)
	var talked := [false]
	porter.set_interact_callback(func(_who: Node) -> void: talked[0] = true)
	assert_true(porter.interact(_actor))
	assert_true(talked[0])
	assert_true(_sight.challenge_host == null, "no duel from the physical layer")


func test_open_refuses_outside_sight() -> void:
	var host := SpiritArenaHost.new()
	_root.add_child(host)
	assert_false(host.open(_db, _state, DUEL_ID), "a duel starts only from spirit sight")
	assert_false(host.is_open())
	assert_false(_tree().paused, "a refused open freezes nothing")
	_state.spirit_sight = true
	assert_true(host.open(_db, _state, DUEL_ID))
	host.close()


func test_scripted_path_enables_sight_with_the_ripple_then_opens() -> void:
	var host := SpiritArenaHost.new()
	host.freeze_world = false
	_root.add_child(host)
	var sight_on_at_open := [false]
	host.opened.connect(func(_id: StringName) -> void: sight_on_at_open[0] = _state.spirit_sight)
	assert_true(host.open_scripted(_db, _state, DUEL_ID))
	assert_true(sight_on_at_open[0], "sight is on before the arena opens")
	assert_true(_state.spirit_sight)
	assert_true(_state.in_spirit_world)
	assert_true(_sight._tween != null and _sight._tween.is_running(), "the ripple plays")
	host.close()
	_sight.enforce_availability()
	assert_true(_state.spirit_sight, "closing returns to spirit sight, not the physical layer")


func test_scripted_open_of_a_non_duel_changes_nothing() -> void:
	var host := SpiritArenaHost.new()
	_root.add_child(host)
	assert_false(host.open_scripted(_db, _state, PLAIN_ID))
	assert_false(_state.spirit_sight, "the sight it switched on is undone")
	assert_false(host.is_open())


func test_keyboard_and_gamepad_interact_challenge() -> void:
	Bindings.default_settings().apply_to_input_map()
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	key.pressed = true
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	pad.pressed = true
	for event: InputEvent in [key, pad]:
		var porter := _person(PORTER)
		var controller := InteractionController.new()
		controller.actor = _actor
		_root.add_child(controller)
		_state.spirit_sight = true
		controller._update_focus()
		assert_true(controller.get_focused_interactable() == porter)
		controller._unhandled_input(event)
		var host: SpiritArenaHost = _sight.challenge_host
		assert_true(host != null and host.is_open(), "%s challenges" % event.get_class())
		host.close()
		assert_true(_state.spirit_sight)
		porter.free()
		controller.free()


func test_almshouse_porter_duel_passes_through_spirit_sight() -> void:
	# Only the hall's own controller may answer the sight group in this scene.
	_sight.free()
	SessionState.state.set_flag(&"flag.prologue.apprenticed", false)
	SessionState.state.spirit_sight = false
	var opening := OPENING_SCENE.instantiate() as AlmshouseOpening
	opening.auto_continue = false
	_root.add_child(opening)
	assert_true(opening.begin_duel())
	var sight := opening.get_node(^"SpiritSight")
	assert_true(sight != null, "the hall owns a spirit-sight controller for its scripted duel")
	assert_true(SessionState.state.spirit_sight, "the porter duel switches sight on")
	assert_true(opening.host().is_open())
	sight.call(&"enforce_availability")
	assert_true(SessionState.state.spirit_sight, "sight holds through the duel")
	opening.host().close()
	assert_eq(opening.stage, AlmshouseOpening.STAGE_KALEV)
	assert_false(SessionState.state.spirit_sight, "Kalev's dialogue closes sight")
	opening.free()


## A talk sensor for `char_id` placed on the actor, so it is in range and in focus.
func _person(char_id: StringName) -> Interactable:
	var sensor: Interactable = INTERACTABLE_SCENE.instantiate()
	sensor.prompt = "Talk"
	sensor.interaction_kind = InteractionKinds.TALK
	sensor.character_id = char_id
	_root.add_child(sensor)
	return sensor


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree
