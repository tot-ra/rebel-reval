extends "res://tests/godot/test_case.gd"

const PrologueControllerScript := preload("res://scripts/forge/forge_prologue_controller.gd")
const FORGE_SCENE := preload("res://scenes/reval_east/forge/forge.tscn")

const QUEST_ID := &"quest.makers_mark"
const COMMISSION_ID := &"commission.watch_buckle_repair"
const RECORD_HONEST := &"forged.watch_buckle_repair.honest_work"
const FLAG_WAKE_UP_MONOLOGUE_SEEN := &"flag.wake_up_monologue_seen"


func test_wake_up_monologue_only_starts_on_first_smithy_entry() -> void:
	_prepare_prologue_state()
	var first_forge := FORGE_SCENE.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(first_forge)
	await _settle_frames(2)

	var first_runner := _find_prologue_controller(first_forge).get_dialogue_runner()
	assert_true(first_runner.is_active(), "new game must start the wake-up monologue")
	assert_true(SessionState.state.get_flag(FLAG_WAKE_UP_MONOLOGUE_SEEN))
	first_forge.free()

	var returning_forge := FORGE_SCENE.instantiate()
	tree.root.add_child(returning_forge)
	await _settle_frames(2)

	var returning_runner := _find_prologue_controller(returning_forge).get_dialogue_runner()
	assert_false(
		returning_runner.is_active(),
		"returning from the city must not replay the wake-up monologue"
	)
	returning_forge.free()


func test_prologue_starts_henning_visit_on_commission_resolution() -> void:
	_prepare_prologue_state()
	var forge := FORGE_SCENE.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(forge)
	await _settle_frames(2)

	var henning := forge.get_node("Actors/Henning") as SmithyHenning
	assert_true(henning != null)
	assert_false(henning.visible)

	SessionState.state.add_forged_record(
		ForgedRecord.new(RECORD_HONEST, COMMISSION_ID, &"item.watch_buckle", &"honest_work")
	)
	await _settle_frames(2)

	assert_true(henning.is_visit_active())
	assert_true(henning.visible)

	forge.queue_free()


func test_henning_visit_resumes_after_arrival_dialogue() -> void:
	_prepare_prologue_state()
	var forge := FORGE_SCENE.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(forge)
	await _settle_frames(2)

	var controller := _find_prologue_controller(forge)
	var henning := forge.get_node("Actors/Henning") as SmithyHenning
	SessionState.state.add_forged_record(
		ForgedRecord.new(RECORD_HONEST, COMMISSION_ID, &"item.watch_buckle", &"honest_work")
	)
	await _settle_frames(2)

	var runner: DialogueRunner = controller.get_dialogue_runner()
	assert_true(runner.is_active())
	runner.advance_for_test()
	assert_true(runner.select_choice("ask_where_found"))
	runner.advance_for_test()
	await _settle_frames(1)

	assert_false(runner.is_active())
	assert_true(henning.is_visit_active())

	forge.queue_free()


func _prepare_prologue_state() -> void:
	SessionState.state = GameState.new()
	SessionState.content_db.load_from_directories(SessionState.DEMO_CONTENT_DIRS)
	SessionState.state.bag.set_content_db(SessionState.content_db)
	SessionState.state.set_phase(GameState.PHASE_PROLOGUE_DAY)
	if Engine.get_main_loop().root.get_node_or_null("PhaseDirector") != null:
		PhaseDirector.rebind_session_state()


func _find_prologue_controller(forge: Node) -> ForgePrologueController:
	return forge.get_node_or_null("ForgePrologueController") as ForgePrologueController


func _settle_frames(count: int) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for _i in count:
		await tree.process_frame
