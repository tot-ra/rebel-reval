extends "res://tests/godot/test_case.gd"

## ADR 0038 / SA3D-3 (R-1388): in the real-time 3D arena the slot keys are word spells cast at any
## time. A word speaks the topic line for its element in a bubble over the hero, flies as a bolt
## in the element colour, and either answers the matching reply or lands as a free strike with
## the topic multiplier; free strikes cost willpower, every slot has a cooldown, and the compact
## cast bar replaces the reply cards. The opponent's blows fly the same way at their floor zone.

const CONFRONT := &"dialogue.prologue.porter_confrontation"
const CONTENT_DIRS: Array[String] = [
	"res://content/prologue",
	"res://content/examples/valid",
	"res://content/examples/support",
]
const SLOT_SHAME := 1
const SLOT_FAITH := 4

var _state: GameState
var _db: ContentDB
var _root: Node3D
var _hero: Node3D
var _host: SpiritArenaHost


func before_each() -> void:
	super.before_each()
	await _tree().process_frame
	_state = GameState.new()
	_db = ContentDB.new()
	assert_true(_db.load_from_directories(CONTENT_DIRS))
	for grant_id: StringName in AlmshouseOpening.STARTER_GRANTS:
		MagicResolver.apply_grant_operation(_state, _db, grant_id)
	_state.set_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER, 8)
	_root = Node3D.new()
	_tree().root.add_child(_root)
	_hero = Node3D.new()
	_root.add_child(_hero)
	var opponent := Node3D.new()
	_root.add_child(opponent)
	opponent.position = Vector3(0, 0, -5)
	_host = SpiritArenaHost.new()
	_tree().root.add_child(_host)
	assert_true(_host.attach_arena(_root, Vector3.ZERO, [_hero, opponent], true, _hero, opponent))
	assert_true(_host.open_scripted(_db, _state, CONFRONT))


func after_each() -> void:
	if is_instance_valid(_host):
		_host.close()
		_host.free()
	_root.free()
	_tree().paused = false
	super.after_each()


func test_slots_follow_the_topic_and_the_cast_bar_replaces_the_cards() -> void:
	assert_eq(_host.words.elements, [&"fear", &"shame", &"duty", &"love", &"faith"])
	assert_true(_host.cast_bar().visible)
	assert_eq(_host.cast_bar().slots.size(), 5)
	assert_eq(_host.cast_bar().slots[1]["element"], "shame")
	_to_answer()
	assert_true(_host.cards().is_empty(), "no reply cards in the 3D arena")
	var answers: Array = _host.cast_bar().slots.map(
		func(slot: Dictionary) -> bool: return slot["answers"]
	)
	assert_eq(answers, [true, true, false, true, false], "fear, shame and love answer the accusation")


func test_free_strike_speaks_the_topic_line_and_lands_with_the_topic_multiplier() -> void:
	assert_eq(_host.duel.phase, SpiritDuel.PHASE_TELEGRAPH, "a word is cast while a blow winds up")
	assert_true(_host.cast_word(SLOT_FAITH))
	assert_eq(_willpower(), 8 - SpiritWordSpells.WORD_COST)
	var expected := _host.duel.topic_line_for(&"faith", _host.duel.topic()["tags"])
	assert_eq(_host.cast_caption(), String(expected["text"]))
	assert_eq(_host.bubble_text(&"hero"), String(expected["text"]))
	assert_eq(_host.word_bolt_count(), 1)
	assert_eq(_host.duel.opponent.health, SpiritDuel.PRESSURE_MAX, "pressure waits for the bolt")
	_host._process(0.6)
	assert_eq(_host.word_bolt_count(), 0)
	assert_almost_eq(
		SpiritDuel.PRESSURE_MAX - _host.duel.opponent.health,
		SpiritWordSpells.WORD_DAMAGE * SpiritDuel.TOPIC_ON,
		0.001
	)


func test_slot_key_casts_a_word() -> void:
	Input.action_press(&"spellforge_element_5")
	_host._process(0.0)
	Input.action_release(&"spellforge_element_5")
	assert_eq(_host.word_bolt_count(), 1)
	assert_eq(_willpower(), 8 - SpiritWordSpells.WORD_COST)


func test_cooldown_blocks_the_slot_then_clears() -> void:
	assert_true(_host.cast_word(SLOT_FAITH))
	assert_false(_host.cast_word(SLOT_FAITH))
	assert_eq(_hint(), SpiritWordSpells.REASON_COOLDOWN)
	assert_almost_eq(_host.cast_bar().slots[SLOT_FAITH]["cooldown"], 1.0, 0.001)
	assert_true(_host.cast_word(3), "other slots are not on cooldown")
	_host._process(SpiritWordSpells.COOLDOWN_SEC)
	assert_eq(_host.words.cooldown_fraction(SLOT_FAITH), 0.0)
	assert_true(_host.cast_word(SLOT_FAITH))


func test_free_strike_needs_willpower() -> void:
	_state.set_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER, 0)
	assert_false(_host.cast_word(SLOT_FAITH))
	assert_true(_hint().begins_with("Not enough willpower"))
	_host._process(0.0)
	assert_true(_host.cast_bar().slots[SLOT_FAITH]["blocked"])
	assert_eq(_host.word_bolt_count(), 0)


func test_a_matching_word_answers_the_reply_without_willpower() -> void:
	_to_answer()
	_state.set_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER, 0)
	assert_true(_host.cast_word(SLOT_SHAME), "an answering word never stalls on willpower")
	assert_ne(_host.duel.phase, SpiritDuel.PHASE_ANSWER, "shame spoke the fire_hands reply")
	assert_eq(_willpower(), 0)
	# fire_hands names `bread`; the first shame line with the best overlap is spoken.
	assert_eq(_host.cast_caption(), String(_host.duel.topic_line_for(&"shame", ["bread"])["text"]))
	assert_true(_host.cast_caption().contains("bread"))
	assert_eq(_host.words.bolts[0]["damage"], 0.0, "the reply already dealt its pressure")


func test_a_word_without_a_matching_reply_does_not_move_the_dialogue() -> void:
	_to_answer()
	assert_true(_host.cast_word(SLOT_FAITH))
	assert_eq(_host.duel.phase, SpiritDuel.PHASE_ANSWER)


func test_opponent_blow_flies_at_its_zone_and_is_spoken_in_a_bubble() -> void:
	var bolt := _host.incoming_bolt()
	assert_true(bolt != null, "the opening blow is thrown")
	assert_eq(bolt.element, &"shame")
	assert_eq(bolt.color, SpiritSpellCard.ELEMENT_COLORS["shame"])
	assert_true(_host.bubble_text(&"opponent").contains("A loaf is missing"))
	_host._process(SpiritDuel.TELEGRAPH_SEC * 0.5)
	assert_almost_eq(bolt.global_position.z, lerpf(-5.0, 0.0, 0.5), 0.05, "halfway at half wind-up")
	# Out of the zone at impact: the blow misses and its bolt is gone.
	_hero.global_position = Vector3(6, 0, 0)
	_host._process(SpiritDuel.TELEGRAPH_SEC)
	assert_eq(_host.duel.hero.health, SpiritDuel.COMPOSURE_MAX)
	assert_true(_host.incoming_bolt() == null)


func test_retry_drops_words_still_in_flight() -> void:
	_host.duel.hero.health = 1.0
	assert_true(_host.cast_word(SLOT_FAITH))
	_host.duel.tick(SpiritDuel.TELEGRAPH_SEC)
	assert_eq(_host.duel.phase, SpiritDuel.PHASE_LOST, "the blow broke the last composure")
	assert_eq(_host.word_bolt_count(), 1, "the word is still in flight")
	var retry := _host.find_children("*", "Button", true, false)
	assert_eq(retry.size(), 1)
	(retry[0] as Button).pressed.emit()
	assert_eq(_host.word_bolt_count(), 0)
	_host._process(1.0)
	assert_eq(_host.duel.opponent.health, SpiritDuel.PRESSURE_MAX, "no old word lands on the retry")


func test_words_are_deterministic() -> void:
	var first := _run_sequence()
	_host.close()
	_state.set_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER, 8)
	_hero.global_position = Vector3.ZERO
	var opponent := _root.get_child(1) as Node3D
	opponent.global_position = Vector3(0, 0, -5)
	assert_true(_host.attach_arena(_root, Vector3.ZERO, [_hero, opponent], true, _hero, opponent))
	assert_true(_host.open_scripted(_db, _state, CONFRONT))
	assert_eq(_run_sequence(), first)


func _run_sequence() -> Array:
	var trace: Array = []
	for slot: int in [SLOT_FAITH, 3, 2]:
		_host.cast_word(slot)
		_host._process(0.4)
		trace.append([_host.duel.opponent.health, _host.duel.hero.health, _willpower()])
	return trace


## Let the opening blow land (the hero stands in it) so the accusation's replies open.
func _to_answer() -> void:
	_host._process(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_eq(_host.duel.phase, SpiritDuel.PHASE_ANSWER)


func _willpower() -> int:
	return _state.get_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER)


func _hint() -> String:
	return (_host.find_child("Hint", true, false) as Label).text


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree
