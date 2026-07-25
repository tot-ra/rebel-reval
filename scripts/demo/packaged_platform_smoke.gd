class_name PackagedPlatformSmoke
extends Node

## Opt-in P3-012 platform smoke that runs inside the exported macOS binary.
## Pass `-- --verify-packaged-platform` to exercise install/start/save/load/exit.

const PlatformModel := preload("res://scripts/slice/vertical_slice_platform_model.gd")

const USER_ARGUMENT := PlatformModel.PACKAGED_SMOKE_USER_ARGUMENT
const START_MARKER := "P3-012_PACKAGED_PLATFORM_START"
const PASS_MARKER := "P3-012_PACKAGED_PLATFORM_PASS"
const FAIL_MARKER := "P3-012_PACKAGED_PLATFORM_FAIL"
const SMOKE_FLAG := &"flag.p3_012_platform_smoke"
const SMOKE_SLOT := 7
const SCENE_WAIT_FRAMES := 600
const SETTLE_FRAMES := 12
const MAX_RUNTIME_SECONDS := 60.0

var _finished := false


func _ready() -> void:
	var user_args := OS.get_cmdline_user_args()
	if not is_requested(user_args):
		queue_free()
		return
	call_deferred("_activate")


func _activate() -> void:
	var tree := get_tree()
	if get_parent() != tree.root:
		reparent(tree.root)
	print(START_MARKER)
	tree.create_timer(MAX_RUNTIME_SECONDS).timeout.connect(_on_timeout)
	call_deferred("_run")


static func is_requested(user_args: PackedStringArray) -> bool:
	return user_args.has(USER_ARGUMENT)


func _run() -> void:
	var tree := get_tree()
	await tree.process_frame

	_clear_smoke_slot()

	var menu := tree.current_scene
	if menu == null or menu.scene_file_path != "res://scenes/menu/main_menu.tscn":
		_fail("release app did not start on the authored main menu")
		return

	var start_label := menu.get_node_or_null("Start label") as Control
	if start_label == null:
		_fail("main menu Start control is missing")
		return

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	start_label.gui_input.emit(click)

	var forge: Node = await _wait_for_scene(&"forge")
	if forge == null:
		_fail("Start did not reach forge")
		return

	var saved_phase := SessionState.state.get_phase()
	SessionState.state.set_flag(SMOKE_FLAG, true)
	SessionState.state.player.location_id = &"forge"
	SessionState.state.player.spawn_id = &"smithy_start"
	if not SessionState.save_game(SMOKE_SLOT):
		_fail("packaged save failed")
		return

	DoorNavigator.go_to_scene(&"reval_east", &"forge")
	var east: Node = await _wait_for_scene(&"reval_east")
	if east == null:
		_fail("forge transition did not reach Lower Town before load")
		return

	SessionState.state.set_flag(SMOKE_FLAG, false)
	if not SessionState.load_game(SMOKE_SLOT):
		_fail("packaged load failed")
		return

	if SessionState.state.get_phase() != saved_phase:
		_fail("loaded phase does not match saved phase")
		return
	if not SessionState.state.get_flag(SMOKE_FLAG):
		_fail("loaded smoke flag was not restored")
		return
	if SessionState.state.player.location_id != &"forge":
		_fail("loaded location_id does not match saved forge state")
		return

	DoorNavigator.go_to_scene(SessionState.state.player.location_id, SessionState.state.player.spawn_id)
	forge = await _wait_for_scene(&"forge")
	if forge == null:
		_fail("load resume did not return to forge")
		return

	_finished = true
	print("%s steps=install,start,save,load,exit" % PASS_MARKER)
	tree.quit(0)


func _clear_smoke_slot() -> void:
	var service := SessionState.save_service
	for path in [service.slot_path(SMOKE_SLOT), service.backup_path(SMOKE_SLOT), service.temp_path(SMOKE_SLOT)]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _wait_for_scene(scene_id: StringName) -> Node:
	var expected_path := DoorNavigator.get_scene_path(scene_id)
	if expected_path.is_empty():
		return null
	for _frame in SCENE_WAIT_FRAMES:
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if scene != null and scene.scene_file_path == expected_path:
			for _settle_frame in SETTLE_FRAMES:
				await get_tree().process_frame
			return scene
	return null


func _on_timeout() -> void:
	if not _finished:
		_fail("platform smoke exceeded %.0f seconds" % MAX_RUNTIME_SECONDS)


func _fail(reason: String) -> void:
	if _finished:
		return
	_finished = true
	printerr("%s reason=%s" % [FAIL_MARKER, reason])
	get_tree().quit(1)
