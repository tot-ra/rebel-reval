extends Node

## In-game HUD and Escape-menu plates from the real scenes (R-1698). Run as the
## main scene so autoloads resolve:
##   tools/godot_render.sh res://tools/capture_hud_gameplay_host.tscn
## WHY a host: SceneTree --script entries cannot compile scripts that name
## autoloads (UserSettings, SessionState) as identifiers.

const OUTPUT_DIR := "res://docs/reports/images/hud_menus"
const MAIN_MENU_PATH := "res://scenes/menu/main_menu.tscn"
const SETTLE_FRAMES := 90


func _ready() -> void:
	var tree := get_tree()
	if get_parent() != tree.root:
		reparent(tree.root)
	if tree.current_scene == self:
		tree.current_scene = null
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	SessionState.state = GameState.new()
	SessionState.content_db.load_from_directories(SessionState.DEMO_CONTENT_DIRS)
	SessionState.state.bag.set_content_db(SessionState.content_db)
	SessionState.state.bag.try_add(&"item.forge_hammer")
	SessionState.state.equip_from_bag(&"right_hand", &"item.forge_hammer")
	if not await _change_to(MAIN_MENU_PATH):
		return _fail("main menu did not load")
	await _capture("game_main_menu")
	if not await _goto(&"reval_city", &"kalev_smithy"):
		return _fail("seamless city did not load")
	var player := get_tree().get_first_node_in_group(CrowdYield.PLAYER_GROUP)
	if player == null:
		return _fail("city player missing")
	# Partial vitals so the bars read as bars, not as full plates.
	player.set(&"health", 64.0)
	player.set(&"stamina", 38.0)
	await _settle(SETTLE_FRAMES)
	await _capture("game_hud_city")
	var settings := player.get_node_or_null("GameSettingsController")
	if settings == null:
		return _fail("GameSettingsController missing")
	settings.call("open")
	await _settle(8)
	await _capture("game_escape_menu")
	get_tree().quit(0)


func _goto(scene_id: StringName, spawn_id: StringName) -> bool:
	if not DoorNavigator.has_active_scene(scene_id) or not DoorNavigator.has_spawn(scene_id, spawn_id):
		return false
	DoorNavigator.pending_spawn_scene_id = scene_id
	DoorNavigator.pending_spawn_id = spawn_id
	DoorNavigator.spawn_door_tag = null
	return await _change_to(DoorNavigator.get_scene_path(scene_id))


func _change_to(path: String) -> bool:
	if get_tree().change_scene_to_file(path) != OK:
		return false
	for _i in 300:
		var scene := get_tree().current_scene
		if scene != null and String(scene.scene_file_path) == path:
			await _settle(SETTLE_FRAMES)
			return true
		await get_tree().process_frame
	return false


func _capture(stem: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUTPUT_DIR, stem]
	image.save_png(ProjectSettings.globalize_path(path))
	print("UI_GAME_CAPTURE ", stem, " ", image.get_size())


func _settle(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


func _fail(reason: String) -> void:
	push_error("HUD gameplay capture failed: %s" % reason)
	get_tree().quit(1)
