extends SceneTree

## ADR 0021 wade / swim / dive evidence on Kalamaja (reval_harbor_east). Runs the real
## harbor scene, then drives the player with actual input actions from the beach into
## the sea, so the plates show what a player sees, not a staged rig.
##
## Requires a rendering-capable run (never --headless):
##   tools/godot_render.sh --script tools/capture_swim.gd -- --out=build/swim
##   tools/godot_render.sh --rendering-method mobile --rendering-driver metal \
##     --script tools/capture_swim.gd -- --out=build/swim_metal --camera=top_down
##
## Options: --out=<dir under the project>  --camera=third_person|top_down
##          --zoom=<view steps>  --x=<start cell x>  --weather=<clear|rain|storm...>
##
## Output: <out>/swim_<step>.png plus a printed line per step with medium, depth, submersion.

const SCENE_PATH := "res://scenes/harbor/harbor_east.tscn"
const VIEWPORT_SIZE := Vector2i(1280, 720)
const CELL := 32.0
const SETTLE_FRAMES := 40
const STEP_TIMEOUT_FRAMES := 900

var _out := "build/swim"
var _camera := "third_person"
var _start_x := 100.5
var _zoom := 0.0
var _rotate := 0.0
var _weather := ""
var _north_key: StringName = &"ui_up"
var _south_key: StringName = &"ui_down"
var _scene: Node
var _player: CharacterBody2D


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.trim_prefix("--out=")
		elif argument.begins_with("--camera="):
			_camera = argument.trim_prefix("--camera=")
		elif argument.begins_with("--x="):
			_start_x = float(argument.trim_prefix("--x="))
		elif argument.begins_with("--rotate="):
			_rotate = float(argument.trim_prefix("--rotate="))
		elif argument.begins_with("--zoom="):
			_zoom = float(argument.trim_prefix("--zoom="))
		elif argument.begins_with("--weather="):
			_weather = argument.trim_prefix("--weather=")
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("capture_swim needs a real renderer; run through tools/godot_render.sh")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + _out))
	root.size = VIEWPORT_SIZE
	_scene = (load(SCENE_PATH) as PackedScene).instantiate()
	root.add_child(_scene)
	await _frames(SETTLE_FRAMES)
	_player = _scene.get("player") as CharacterBody2D
	var runtime: Node = _scene.get("_view_runtime")
	if _player == null or runtime == null:
		push_error("harbor scene did not expose player/runtime")
		quit(1)
		return
	if not _weather.is_empty():
		# Hold the requested weather for the whole run (rain rings, lens drops).
		var sky: Object = runtime.get("view").call(&"sky_weather")
		sky.set("auto_weather", false)
		sky.call(&"set_weather", StringName(_weather))
		sky.call(&"advance", SkyWeather3D.TRANSITION_SECONDS)
	if _camera == "top_down":
		runtime.call(&"set_camera_mode", 2) # CameraMode.TOP_DOWN
	if _zoom != 0.0:
		runtime.call(&"zoom_view_steps", _zoom)
	_player.global_position = Vector2(_start_x * CELL, 38.5 * CELL)
	await _frames(SETTLE_FRAMES)
	_face_camera_north(runtime)
	await _frames(SETTLE_FRAMES)
	if _rotate != 0.0:
		# Orbit after the walk direction is fixed: keys still walk north only if the
		# camera is not rotated, so this option is for side-view plates of a held pose.
		runtime.call(&"rotate_view_degrees", _rotate)
		await _frames(SETTLE_FRAMES)
		_pick_walk_keys()
	await _snap("00_beach")
	# Walk north (away from the beach) with real input. Steps trigger on cell row.
	Input.action_press(_north_key)
	for step: Array in [
		["01_ankle", 35.6], ["02_knee", 34.2], ["03_hip", 30.0], ["04_shelf", 24.6],
	]:
		await _walk_until(float(step[1]))
		await _snap(String(step[0]))
	await _walk_until(21.0)
	await _snap("05_swim_stroke")
	await _frames(8)
	await _snap("05b_swim_stroke")
	Input.action_release(_north_key)
	await _frames(60)
	await _snap("06_tread")
	Input.action_press(&"player_dive")
	for step: Array in [["07_dive_start", 0.6], ["08_dive_deep", 1.8]]:
		await _dive_until(float(step[1]))
		await _snap(String(step[0]))
	Input.action_press(_north_key)
	await _frames(45)
	await _snap("09_dive_swim")
	Input.action_release(_north_key)
	Input.action_release(&"player_dive")
	await _frames(40)
	await _snap("10_ascending")
	await _frames(70)
	await _snap("11_surfaced")
	Input.action_press(_south_key)
	await _walk_until(31.0, true)
	await _snap("12_returning")
	await _walk_until(38.0, true)
	Input.action_release(_south_key)
	await _frames(30)
	await _snap("13_back_on_beach")
	print("SWIM_CAPTURED out=%s" % _out)
	quit(0)


## Rotates the orbit camera until the up key walks toward the sea (logic -Y), so the
## route is a straight line into the water instead of along the shore.
func _face_camera_north(runtime: Node) -> void:
	for attempt in 4:
		var direction: Vector2 = _player.call(&"movement_direction_for_screen_input", Vector2(0, -1))
		var error := direction.angle_to(Vector2.UP)
		print("SWIM_CAMERA up-key direction=%s error_deg=%.1f" % [direction, rad_to_deg(error)])
		if absf(error) < deg_to_rad(3.0):
			return
		runtime.call(&"rotate_view_degrees", rad_to_deg(error))
		await _frames(6)


## After orbiting the camera, walk with whichever arrow key now heads north (logic -Y).
func _pick_walk_keys() -> void:
	var best := 2.0
	for pair: Array in [
		[&"ui_up", Vector2(0, -1)], [&"ui_down", Vector2(0, 1)],
		[&"ui_left", Vector2(-1, 0)], [&"ui_right", Vector2(1, 0)],
	]:
		var direction: Vector2 = _player.call(&"movement_direction_for_screen_input", pair[1])
		var error := absf(direction.angle_to(Vector2.UP))
		if error < best:
			best = error
			_north_key = pair[0]
	var opposite := {
		&"ui_up": &"ui_down", &"ui_down": &"ui_up",
		&"ui_left": &"ui_right", &"ui_right": &"ui_left",
	}
	_south_key = opposite[_north_key]
	print("SWIM_KEYS north=%s south=%s error_deg=%.1f" % [_north_key, _south_key, rad_to_deg(best)])


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _walk_until(cell_y: float, southward: bool = false) -> void:
	for i in STEP_TIMEOUT_FRAMES:
		await physics_frame
		var y := _player.global_position.y / CELL
		if (y > cell_y) if southward else (y < cell_y):
			return
	push_warning("walk timeout at row %.1f" % cell_y)
	for index in _player.get_slide_collision_count():
		var hit := _player.get_slide_collision(index)
		var collider := hit.get_collider() as Node
		print(
			"SWIM_BLOCKED by %s (%s) layer=%d at %s" % [
				collider.name,
				collider.get_parent().name,
				collider.get("collision_layer"),
				hit.get_position() / CELL,
			]
		)


func _dive_until(submersion: float) -> void:
	for i in STEP_TIMEOUT_FRAMES:
		await physics_frame
		if float(_player.call(&"swim_submersion")) >= submersion:
			return
	push_warning("dive timeout at %.1f" % submersion)


func _camera_info() -> String:
	var runtime: Node = _scene.get("_view_runtime")
	var view: Node = runtime.get("view")
	var camera: Camera3D = runtime.get("_camera_controller").get("camera")
	var pass_node: Object = view.call(&"underwater_pass")
	var camera_xz := Vector2(camera.global_position.x, camera.global_position.z)
	var surface := float(view.call(&"water_surface_height_at", camera_xz))
	return "cam_y=%.2f surface=%.2f uw_state=%s" % [
		camera.global_position.y, surface, str(pass_node.get("state")) if pass_node != null else "none"
	]


func _snap(label: String) -> void:
	# Freeze the walk while the frame is written so the route stays a clean line.
	var held: Array[StringName] = []
	for action: StringName in [_north_key, _south_key, &"player_dive"]:
		if Input.is_action_pressed(action):
			held.append(action)
			Input.action_release(action)
	await _frames(4)
	var image := root.get_texture().get_image()
	var path := "res://%s/swim_%s.png" % [_out, label]
	image.save_png(ProjectSettings.globalize_path(path))
	for action: StringName in held:
		Input.action_press(action)
	print(
		"SWIM_STEP %s medium=%d depth=%.2f submersion=%.2f breath=%.2f cell=(%.1f,%.1f) %s" % [
			label,
			int(_player.call(&"water_medium")),
			float(_player.call(&"water_depth")),
			float(_player.call(&"swim_submersion")),
			float(_player.call(&"breath_fraction")),
			_player.global_position.x / CELL,
			_player.global_position.y / CELL,
			_camera_info(),
		]
	)
