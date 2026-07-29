extends "res://tests/godot/test_case.gd"

const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const PresenterScript := preload("res://tests/godot/dialogue_test_presenter.gd")
const DIALOGUE_ID := &"dialogue.test_runner.intro"
const CONTENT_DIRS: Array[String] = [
	"res://content/examples/valid",
	"res://content/examples/support",
]

var _combat_save_results: Array[bool] = []
var _combat_resolved_count := 0
var _dialogue_save_results: Array[bool] = []
var _test_root := ""


func before_each() -> void:
	_combat_save_results.clear()
	_combat_resolved_count = 0
	_dialogue_save_results.clear()
	_test_root = "user://test_save_signals/%d_%d" % [
		OS.get_process_id(),
		Time.get_ticks_usec(),
	]


func after_each() -> void:
	_cleanup_temp_dir()


func test_repeated_combat_signals_can_save_without_interrupting_resolution() -> void:
	var state := GameState.new()
	var service := _service("combat_signals")
	var vitals := CombatVitals.new()
	vitals.configure(100.0, 100.0, 100.0, 100.0)
	vitals.health_changed.connect(
		Callable(self, "_save_from_combat_signal").bind(service, state)
	)
	vitals.hit_resolved.connect(_on_combat_hit_resolved)

	for swing_id in range(1, 21):
		vitals.tick(1.0)
		vitals.resolve_hit(2.0, CombatDefensePose.open(), swing_id)

	assert_eq(_combat_save_results.size(), 20)
	assert_false(_combat_save_results.has(false))
	assert_eq(_combat_resolved_count, 20, "save callbacks must not interrupt combat signals")
	var loaded := service.load_game()
	assert_true(loaded["ok"], ", ".join(loaded["errors"]))
	var loaded_state := loaded["state"] as GameState
	assert_true(is_equal_approx(loaded_state.player.health, 60.0))
	assert_true(loaded_state.get_flag(&"flag.save_during_combat"))


func test_dialogue_started_and_finished_signals_can_save_active_state() -> void:
	var root := Node.new()
	_tree().root.add_child(root)
	var db := ContentDB.new()
	assert_true(db.load_from_directories(CONTENT_DIRS))
	var state := GameState.new()
	var service := _service("dialogue_signals")
	var runner = RunnerScript.new()
	root.add_child(runner)
	runner.configure(db, state, PresenterScript.new())
	runner.started.connect(
		Callable(self, "_save_from_dialogue_started").bind(service, state, runner)
	)
	runner.finished.connect(
		Callable(self, "_save_from_dialogue_finished").bind(service, state)
	)

	assert_true(runner.start(DIALOGUE_ID))
	assert_true(runner.is_active())
	runner.advance_for_test()
	assert_true(runner.select_choice("trust_mart"))
	runner.advance_for_test()

	assert_false(runner.is_active())
	assert_eq(_dialogue_save_results, [true, true])
	var loaded := service.load_game()
	assert_true(loaded["ok"], ", ".join(loaded["errors"]))
	var loaded_state := loaded["state"] as GameState
	assert_true(loaded_state.get_flag(&"flag.save_during_dialogue_started"))
	assert_true(loaded_state.get_flag(&"flag.save_during_dialogue_finished"))
	root.free()


func _save_from_combat_signal(
	current: float,
	maximum: float,
	service: SaveService,
	state: GameState
) -> void:
	state.player.health = current
	state.player.max_health = maximum
	state.set_flag(&"flag.save_during_combat", true)
	_combat_save_results.append(service.save_game(state))


func _on_combat_hit_resolved(_result: CombatHitResult) -> void:
	_combat_resolved_count += 1


func _save_from_dialogue_started(
	_dialogue_id: StringName,
	service: SaveService,
	state: GameState,
	runner: DialogueRunner
) -> void:
	assert_true(runner.is_active(), "dialogue must remain active while started is emitted")
	state.set_flag(&"flag.save_during_dialogue_started", true)
	_dialogue_save_results.append(service.save_game(state))


func _save_from_dialogue_finished(
	_dialogue_id: StringName,
	service: SaveService,
	state: GameState
) -> void:
	state.set_flag(&"flag.save_during_dialogue_finished", true)
	_dialogue_save_results.append(service.save_game(state))


func _service(label: String) -> SaveService:
	var service := SaveService.new()
	service.save_directory = "%s/%s_%d" % [
		_test_root,
		label,
		Time.get_ticks_usec(),
	]
	return service


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _cleanup_temp_dir() -> void:
	if _test_root.is_empty():
		return
	_remove_tree(_test_root)


func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		DirAccess.remove_absolute(path)
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var child := path.path_join(entry)
			if DirAccess.dir_exists_absolute(child):
				_remove_tree(child)
			else:
				DirAccess.remove_absolute(child)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)
