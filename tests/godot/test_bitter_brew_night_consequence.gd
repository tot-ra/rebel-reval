extends "res://tests/godot/test_case.gd"

const VALID_DIR := "res://content/examples/valid"
const SUPPORT_DIR := "res://content/examples/support"
const LOWER_TOWN_SCENE := preload("res://scenes/reval_east/reval_east.tscn")
const LOWER_TOWN_DEFINITION := preload(
	"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
)
const PLAYER_SCENE := preload("res://player.tscn")
const NightConsequenceScript := preload(
	"res://scripts/investigation/bitter_brew_night_consequence.gd"
)

const QUEST_ID := &"quest.bitter_brew"
const ENCOUNTER_ID := &"encounter.watch_checkpoint"
const COMMISSION_ID := &"commission.bitter_brew"

const RECORD_HONEST := &"forged.bitter_brew.honest_work"
const RECORD_SUBTLE := &"forged.bitter_brew.subtle_defect"
const RECORD_SECRET := &"forged.bitter_brew.secret_feature"


func test_forged_record_gates_non_combat_routes() -> void:
	var consequence := _make_consequence()
	_prepare_night_state(RECORD_HONEST)
	consequence.arm_encounter_for_test()
	assert_true(consequence.is_outcome_available(EncounterOutcome.KIND_SURRENDER))
	assert_false(consequence.is_outcome_available(EncounterOutcome.KIND_BYPASS))
	assert_false(consequence.is_outcome_available(EncounterOutcome.KIND_ESCAPE))

	_prepare_night_state(RECORD_SUBTLE)
	consequence.arm_encounter_for_test()
	assert_true(consequence.is_outcome_available(EncounterOutcome.KIND_BYPASS))
	assert_false(consequence.is_outcome_available(EncounterOutcome.KIND_ESCAPE))

	_prepare_night_state(RECORD_SECRET)
	consequence.arm_encounter_for_test()
	assert_true(consequence.is_outcome_available(EncounterOutcome.KIND_ESCAPE))
	assert_false(consequence.is_outcome_available(EncounterOutcome.KIND_BYPASS))
	_free_consequence(consequence)


func test_each_authored_route_reaches_valid_aftermath() -> void:
	_assert_route_resolves(RECORD_SUBTLE, EncounterOutcome.KIND_BYPASS, &"night_bypassed")
	_assert_route_resolves(RECORD_SECRET, EncounterOutcome.KIND_ESCAPE, &"night_escaped")
	_assert_route_resolves(RECORD_HONEST, EncounterOutcome.KIND_SURRENDER, &"night_surrendered")
	_assert_route_resolves(RECORD_HONEST, EncounterOutcome.KIND_KILL, &"night_fought")


func test_lower_town_offers_checkpoint_only_during_investigation_night() -> void:
	_prepare_night_state(RECORD_HONEST)
	var east := await _spawn_lower_town()
	var consequence := _find_night_consequence(east)
	assert_true(consequence != null)
	var checkpoint: Interactable = consequence.get_checkpoint_interactable()
	assert_true(checkpoint != null)
	assert_true(checkpoint.is_enabled())

	SessionState.state.set_phase(GameState.PHASE_INVESTIGATION_MORNING)
	await Engine.get_main_loop().process_frame
	assert_false(checkpoint.is_enabled())
	_free_scene(east)


func test_checkpoint_arm_spawns_watch_enemies_and_sets_quest_active() -> void:
	_prepare_night_state(RECORD_HONEST)
	var east := await _spawn_lower_town()
	var consequence := _find_night_consequence(east)
	consequence.arm_encounter_for_test()
	assert_eq(SessionState.state.get_quest_state(QUEST_ID), &"active")
	assert_true(consequence.watchman != null)
	assert_true(consequence.sergeant != null)
	_free_scene(east)


func test_checkpoint_enemies_are_registered_in_the_3d_view_after_spawn() -> void:
	_prepare_night_state(RECORD_HONEST)
	var east := await _spawn_lower_town()
	var consequence := _find_night_consequence(east)
	consequence.arm_encounter_for_test()
	await Engine.get_main_loop().process_frame
	var runtime := east.get_node_or_null("MapViewRuntime") as MapViewRuntime
	assert_true(runtime != null, "Lower Town must install the 3D runtime")
	assert_true(
		runtime.get_actor_rig(consequence.watchman) != null,
		"A night enemy spawned after runtime install must be visible in 3D"
	)
	assert_true(
		runtime.get_actor_rig(consequence.sergeant) != null,
		"Both night enemies must receive shared character rigs"
	)
	_free_scene(east)


func _assert_route_resolves(
	record_id: StringName,
	kind: StringName,
	expected_state: StringName
) -> void:
	var consequence := _make_consequence()
	_prepare_night_state(record_id)
	consequence.arm_encounter_for_test()
	if kind == EncounterOutcome.KIND_KILL:
		for enemy in [consequence.watchman, consequence.sergeant]:
			if enemy != null:
				enemy.get_machine().mark_dead()
	assert_true(consequence.resolve_encounter_outcome(kind))
	assert_eq(SessionState.state.get_quest_state(QUEST_ID), expected_state)
	assert_true(SessionState.state.get_flag(&"flag.watch_checkpoint_resolved"))
	_free_consequence(consequence)


func _make_consequence() -> Node:
	var host := Node2D.new()
	host.name = "NightConsequenceTestHost"
	var actors := Node2D.new()
	actors.name = "Actors"
	host.add_child(actors)
	var player := PLAYER_SCENE.instantiate() as Player
	actors.add_child(player)
	var definition: MapDefinition = LOWER_TOWN_DEFINITION.create()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(host)
	var consequence := NightConsequenceScript.new()
	host.add_child(consequence)
	consequence.setup(host, definition, player, null, actors)
	return consequence


func _free_consequence(consequence: Node) -> void:
	if consequence == null or not is_instance_valid(consequence):
		return
	var host := consequence.get_parent()
	consequence.queue_free()
	if host != null and is_instance_valid(host):
		host.queue_free()


func _prepare_night_state(record_id: StringName) -> void:
	if not SessionState.content_db.is_loaded():
		assert_true(SessionState.content_db.load_from_directories(SessionState.DEMO_CONTENT_DIRS))
	SessionState.state = GameState.new()
	SessionState.state.bag.set_content_db(SessionState.content_db)
	SessionState.state.set_phase(GameState.PHASE_INVESTIGATION_NIGHT)
	SessionState.state.set_quest_state(QUEST_ID, &"investigation_ready")
	SessionState.state.set_flag(&"flag.watch_checkpoint_resolved", false)
	SessionState.state.add_forged_record(
		ForgedRecord.new(
			record_id,
			COMMISSION_ID,
			&"item.bitter_brew_work",
			StringName(String(record_id).get_slice(".", 2))
		)
	)


func _spawn_lower_town() -> Node:
	var east: Node = LOWER_TOWN_SCENE.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(east)
	await east.ready
	return east


func _find_night_consequence(east: Node) -> Node:
	return east.get_node_or_null("BitterBrewNightConsequence")


func _free_scene(east: Node) -> void:
	if east != null and is_instance_valid(east):
		east.queue_free()
