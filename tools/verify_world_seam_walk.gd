extends Node

## WB-08b (R-1043) physical seam walk over real physics frames, which the
## headless test harness cannot do (it never awaits a test coroutine). Run as a
## main scene so autoloads resolve:
##   godot --headless --path . res://tools/verify_world_seam_walk.tscn
## With the residency flag forced on for this process only, it launches the real
## reval_east adapter at the Vana turg seam and checks:
##   keyboard  - hold ui_left until market_civic_quarter owns the player;
##   gamepad   - hold D-pad right until lower_town_slice owns it again;
##   mouse     - MapClickInput logic click on a market point from a settled
##               on-mesh start, walked by nav across the seam NavigationLink2D;
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
const MOVE_ACTIONS: Array[StringName] = [&"ui_left", &"ui_right", &"ui_up", &"ui_down"]
## On-mesh, east of the 16 px seam inset. (8, spawn.y) sat off-mesh so two
## physics frames pushed the body onto different closest points (R-1074).
const MOUSE_START_INSET := 24.0
const SETTLE_FRAMES := 30

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
		"task": "R-1054",
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
	var before := player.global_position
	for action in WEST_ACTIONS:
		Input.action_press(action)
	await _until(func() -> bool: return host.owning_location_id() == MARKET)
	_release_movement()
	print("keyboard %s -> %s" % [before, player.global_position])
	_check("keyboard crosses into the market", host.owning_location_id() == MARKET)
	_check("keyboard: player west of the seam", player.global_position.x < 0.0)
	var market := host.hosted_bootstrap(MARKET)
	var market_def := market.get("definition") as MapDefinition
	var market_grid := market.get("grid") as MapTerrainGrid
	var local := player.global_position - host.location_origin_logic_position(MARKET)
	_check(
		"terrain speed matches the market grid",
		is_equal_approx(
			player.terrain_speed_multiplier(),
			MapTerrainMovement.speed_multiplier_at(market_def, market_grid, local)
		)
	)
	_check(
		"minimap shows the owning location",
		host.minimap_hud != null
		and host.minimap_hud.get_location_label().text == "Central District"
	)
	_same_globals("keyboard", host, player, camera)

	before = player.global_position
	_tilt_stick(EAST_STICK_AXES, 1.0)
	await _until(func() -> bool: return host.owning_location_id() == LOWER_TOWN)
	# A 0.0 stick event is not enough: leftover ui_right/ui_down still drive
	# ScreenDirectionInput and cancel the click path (R-1074).
	_release_movement()
	print("gamepad %s -> %s" % [before, player.global_position])
	_check("gamepad: player east of the seam", player.global_position.x > 0.0)
	_check("gamepad crosses back into Lower Town", host.owning_location_id() == LOWER_TOWN)
	_same_globals("gamepad", host, player, camera)

	var click_input := level.find_child("MapClickInput", true, false)
	var target := Vector2(-6.0 * CELL, 53.5 * CELL)
	await _settle_mouse_start(player)
	before = player.global_position
	print(
		"mouse start=%s axis=%s vel=%s"
		% [before, ScreenDirectionInput.read_axis(), player.velocity]
	)
	var clicked := click_input != null and bool(click_input.call("try_handle_logic_click", target))
	print("mouse click_input=%s clicked=%s" % [click_input, clicked])
	_check("mouse click from the seam inset is accepted", clicked)
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
	_release_movement()
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


func _release_movement() -> void:
	for action in MOVE_ACTIONS:
		Input.action_release(action)
	_tilt_stick(EAST_STICK_AXES, 0.0)


func _cancel_navigation(player: Player) -> void:
	if player.navigation_agent != null:
		player.navigation_agent.set_target_position(player.global_position)
	player.velocity = Vector2.ZERO


func _clamp_to_host_nav(player: Player, point: Vector2) -> Vector2:
	if player.navigation_agent == null:
		return point
	var map_rid: RID = player.navigation_agent.get_navigation_map()
	if not map_rid.is_valid():
		return point
	# Headless launches can query before the first nav iteration.
	if NavigationServer2D.map_get_iteration_id(map_rid) == 0:
		return point
	return NavigationServer2D.map_get_closest_point(map_rid, point)


func _settle_mouse_start(player: Player) -> void:
	# WHY: the gamepad stick maps to ui_right/ui_down. If those stay pressed,
	# Player._physics_process cancels click-to-move and walks east. The old
	# (8, original spawn Y) pose sat in the 16 px off-mesh inset, so two
	# frames resolved collision onto different closest points.
	_release_movement()
	_cancel_navigation(player)
	for _frame in SETTLE_FRAMES:
		await _frames(1)
		_release_movement()
		if (
			ScreenDirectionInput.read_axis().is_zero_approx()
			and player.velocity.is_zero_approx()
		):
			break
	# Keep the aperture Y from the gamepad return; only pin X onto the mesh.
	var desired := Vector2(MOUSE_START_INSET, player.global_position.y)
	player.global_position = _clamp_to_host_nav(player, desired)
	_cancel_navigation(player)
	var last := player.global_position
	for _frame in SETTLE_FRAMES:
		await _frames(1)
		_release_movement()
		player.velocity = Vector2.ZERO
		var now := player.global_position
		if now.distance_to(last) < 0.25:
			player.global_position = _clamp_to_host_nav(player, now)
			if player.global_position.distance_to(last) < 0.25:
				break
		last = player.global_position


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
