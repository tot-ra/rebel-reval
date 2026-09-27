extends Node

## WB-08b (R-1043) physical seam walk over real physics frames, which the
## headless test harness cannot do (it never awaits a test coroutine). Run as a
## main scene so autoloads resolve:
##   godot --headless --path . res://tools/verify_world_seam_walk.tscn
## With the residency flag forced on for this process only, it launches the real
## reval_east adapter at the Vana turg seam and checks:
##   keyboard  - hold ui_left until market_civic_quarter owns the player;
##   gamepad   - hold D-pad right until lower_town_slice owns it again;
##   mouse     - MapClickInput logic click on a market point, walked by nav
##               across the seam NavigationLink2D;
##   fallback  - relaunch with a failing loader; walking into the sealed seam
##               door reaches DoorNavigator with the explicit transition.
## Every walk must keep one Player and camera and never call go_to_scene.
## Writes build/world_seam_walk.json (checks + per-frame times) and exits 0 only
## when every check passes.

const LOWER_TOWN_SCENE_PATH := "res://scenes/reval_east/reval_east.tscn"
const REPORT_PATH := "res://build/world_seam_walk.json"
const SEAM_TRANSITION := &"vana_turg_boundary"
const LOWER_TOWN := &"lower_town_slice"
const MARKET := &"market_civic_quarter"
const MAX_WALK_FRAMES := 600
const CELL := 32.0
const WEST_ACTIONS: Array[StringName] = [&"ui_left", &"ui_up"]
## Gamepad movement is the left stick (InputBindingSettings); right + down is
## logic east, the mirror of the keyboard's west pair.
const EAST_STICK_AXES: Array[int] = [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]

var _checks: Array[Dictionary] = []
var _frame_ms: Array[float] = []
var _last_ticks := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	ProjectSettings.set_setting(WorldHost.ADDITIVE_RESIDENCY_SETTING, true)
	# A direct scene launch skips the menu that installs the gamepad bindings.
	InputBindingSettings.default_settings().apply_to_input_map()
	await _walk_keyboard_gamepad_and_mouse()
	await _walk_into_failed_seam()
	var failed := _checks.filter(func(check: Dictionary) -> bool: return not check["ok"])
	var report := {
		"task": "R-1043",
		"checks": _checks,
		"failed": failed.size(),
		"frame_ms": _frame_ms,
		"frame_ms_max": _frame_ms.max() if not _frame_ms.is_empty() else 0.0,
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	for check in _checks:
		print("%s %s" % ["PASS" if check["ok"] else "FAIL", check["name"]])
	print("world seam walk: %d check(s), %d failure(s)" % [_checks.size(), failed.size()])
	get_tree().quit(0 if failed.is_empty() else 1)


func _walk_keyboard_gamepad_and_mouse() -> void:
	var level := _launch()
	var host := level.get_node_or_null(WorldHost.HOST_NODE_NAME) as WorldHost
	if not _check("host and driver launch", host != null and _driver(host) != null):
		level.queue_free()
		return
	var player := host.player_owner as Player
	var camera := host.camera_owner
	await _frames(3)
	_check("market prefetched at the seam", host.mounted_location_ids().has(MARKET))
	_check("seam active", host.is_seam_active_between(LOWER_TOWN, MARKET))

	# The isometric camera maps screen left to logic (-x, +y) and up to (-x, -y);
	# holding both walks due west through the aperture.
	var start := player.global_position
	var before := start
	for action in WEST_ACTIONS:
		Input.action_press(action)
	await _until(func() -> bool: return host.owning_location_id() == MARKET)
	for action in WEST_ACTIONS:
		Input.action_release(action)
	print("keyboard %s -> %s" % [before, player.global_position])
	_check("keyboard crosses into the market", host.owning_location_id() == MARKET)
	_check("keyboard: player west of the seam", player.global_position.x < 0.0)
	_same_globals("keyboard", host, player, camera)

	before = player.global_position
	_tilt_stick(EAST_STICK_AXES, 1.0)
	await _until(func() -> bool: return host.owning_location_id() == LOWER_TOWN)
	_tilt_stick(EAST_STICK_AXES, 0.0)
	print("gamepad %s -> %s" % [before, player.global_position])
	_check("gamepad: player east of the seam", player.global_position.x > 0.0)
	_check("gamepad crosses back into Lower Town", host.owning_location_id() == LOWER_TOWN)
	_same_globals("gamepad", host, player, camera)

	var click_input := level.find_child("MapClickInput", true, false)
	var target := Vector2(-6.0 * CELL, 53.5 * CELL)
	# Start the click from the seam door spawn on the Lower Town navmesh; the
	# gamepad walk may stop inside the 16 px agent inset, which is off-mesh.
	player.global_position = start
	player.velocity = Vector2.ZERO
	await _frames(2)
	before = player.global_position
	var clicked := click_input != null and bool(click_input.call("try_handle_logic_click", target))
	print("mouse click_input=%s clicked=%s" % [click_input, clicked])
	_check("mouse click accepted on a market point", clicked)
	await _until(func() -> bool: return host.owning_location_id() == MARKET)
	print("mouse %s -> %s" % [before, player.global_position])
	_check("mouse click-to-move crosses into the market", host.owning_location_id() == MARKET)
	_check("mouse: player west of the seam", player.global_position.x < 0.0)
	_same_globals("mouse", host, player, camera)
	host.unmount_all()
	level.queue_free()
	await _frames(2)


func _walk_into_failed_seam() -> void:
	var level := _launch()
	var host := level.get_node_or_null(WorldHost.HOST_NODE_NAME) as WorldHost
	var driver := _driver(host) if host != null else null
	if not _check("fallback host and driver launch", driver != null):
		level.queue_free()
		return
	host.scene_swap_fallback_enabled = true
	host.location_loader = func(_location_id: StringName) -> bool: return false
	driver.execute_fallback = false
	await _frames(3)
	_check("failed neighbour stays unmounted", not host.mounted_location_ids().has(MARKET))
	for action in WEST_ACTIONS:
		Input.action_press(action)
	await _until(func() -> bool: return not driver.last_fallback.is_empty())
	for action in WEST_ACTIONS:
		Input.action_release(action)
	_check(
		"sealed seam door reaches DoorNavigator with the explicit transition",
		driver.last_fallback.get("transition_id") == SEAM_TRANSITION
		and driver.last_fallback.get("scene_id") == &"reval_center"
		and driver.last_fallback.get("spawn_id") == &"from_reval_east"
	)
	_check("player stays in Lower Town", host.owning_location_id() == LOWER_TOWN)
	_check("player never entered unloaded space", host.player_owner.global_position.x > 0.0)
	host.unmount_all()
	level.queue_free()
	await _frames(2)


func _launch() -> Node:
	DoorNavigator.clear_pending_spawn()
	DoorNavigator.pending_spawn_scene_id = &"reval_east"
	DoorNavigator.pending_spawn_id = SEAM_TRANSITION
	var level := (load(LOWER_TOWN_SCENE_PATH) as PackedScene).instantiate()
	get_tree().root.add_child(level)
	return level


func _driver(host: WorldHost) -> WorldHostStreamingDriver:
	return host.get_node_or_null(WorldHostStreamingDriver.NODE_NAME) as WorldHostStreamingDriver


func _same_globals(label: String, host: WorldHost, player: Player, camera: Camera3D) -> void:
	var same_player := host.player_owner == player and player.is_inside_tree()
	_check("%s: same Player instance" % label, same_player)
	_check("%s: same camera instance" % label, host.camera_owner == camera)
	var census := host.global_census()
	_check("%s: one player and camera" % label, census["player"] == 1 and census["camera"] == 1)
	_check("%s: no DoorNavigator scene swap" % label, DoorNavigator.pending_spawn_scene_id.is_empty())


func _tilt_stick(axes: Array[int], value: float) -> void:
	for axis in axes:
		var motion := InputEventJoypadMotion.new()
		motion.axis = axis
		motion.axis_value = value
		Input.parse_input_event(motion)


func _until(done: Callable) -> void:
	for _frame in MAX_WALK_FRAMES:
		await _frames(1)
		if done.call():
			return


func _frames(count: int) -> void:
	for _frame in count:
		await get_tree().physics_frame
		var now := Time.get_ticks_usec()
		if _last_ticks > 0:
			_frame_ms.append(float(now - _last_ticks) / 1000.0)
		_last_ticks = now


func _check(check_name: String, ok: bool) -> bool:
	_checks.append({"name": check_name, "ok": ok})
	return ok
