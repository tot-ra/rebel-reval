extends SceneTree

## Review plates for the duel layer (R-1489, ADR 0041 section 5): an outdoor Lower Town street
## before and during a spirit duel on the same map and camera. Props, carts and loose items vanish,
## terrain and building shells stay, the world goes indigo and only the two fighters glow.
## GPU run:
##   tools/godot_render.sh --resolution 1280x720 --script tools/capture_spirit_duel_layer.gd -- \
##     --out=res://docs/reports/images/spirit_duel_layer [--map=smithy_courtyard]

const Registry := preload("res://scripts/map/map_audit_registry.gd")
const Builder := preload("res://scripts/map/map_builder.gd")
const View := preload("res://scripts/map/view3d/map_view_3d.gd")
const Bridge := preload("res://scripts/map/view3d/map_view_bridge.gd")
const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")
const Sight := preload("res://scripts/combat/spirit_sight.gd")
const RIG_SCENE := preload("res://assets/characters/shared/shared_character_rig.tscn")
const PLATE := Vector2i(1280, 720)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Duel layer plates need tools/godot_render.sh (GPU renderer)")
		quit(2)
		return
	var out := "res://build/spirit_duel_layer"
	var map_id := "smithy_courtyard"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--map="):
			map_id = arg.trim_prefix("--map=")
	var definition: MapDefinition = Registry.by_id().get(map_id)
	if definition == null:
		push_error("No capture map found: %s" % map_id)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var view := View.create(definition, Builder.build(definition), View.TIME_DAY)
	root.add_child(view)
	view.set_weather_time_scale(0.0)
	view.set_process(false)
	var sky := view.sky_weather()
	sky.auto_weather = false
	sky.set_weather(SkyWeather.WEATHER_CLEAR)
	var sight := Sight.new()
	sight.follow_session = false
	sight.state = GameState.new()
	sight.environment_override = view.environment_node().environment
	sight.sun_override = view.get("_sun")
	root.add_child(sight)
	# The fighters stand at the player spawn, facing each other along the street.
	var spawn := Bridge.logic_to_world(definition.player_spawn, definition.cell_size)
	var hero := _fighter(view, "PlayerRig", spawn + Vector3(-1.4, 0.0, 0.0), 90.0)
	var opponent := _fighter(view, "PorterRig", spawn + Vector3(1.4, 0.0, 0.0), -90.0)
	var camera := Camera3D.new()
	view.add_child(camera)
	camera.fov = 45.0
	camera.look_at_from_position(spawn + Vector3(0.0, 7.0, 10.0), spawn + Vector3(0.0, 1.0, 0.0))
	camera.current = true
	await _settle()
	await _save(out + "/outdoor_before.png")
	# Duels start from spirit sight (ADR 0041 section 1): sight first, then the arena.
	sight.state.spirit_sight = true
	sight.blend = 1.0
	var arena := SpiritArena3D.new()
	var keep: Array[Node3D] = [hero, opponent]
	arena.open(view, spawn, keep, false, 4.0)
	await _settle()
	await _save(out + "/outdoor_duel.png")
	print("HIDDEN ", arena.hidden_nodes().size())
	arena.close()
	await _settle()
	await _save(out + "/outdoor_back_in_sight.png")
	sight.leave_immediately()
	quit()


func _fighter(parent: Node3D, label: String, at: Vector3, yaw_deg: float) -> Node3D:
	var rig := RIG_SCENE.instantiate() as Node3D
	rig.name = label
	parent.add_child(rig)
	rig.position = at
	rig.rotation_degrees.y = yaw_deg
	return rig


func _settle() -> void:
	for _frame in range(30):
		await process_frame


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.get_size() != PLATE:
		image.resize(PLATE.x, PLATE.y, Image.INTERPOLATE_LANCZOS)
	image.save_png(ProjectSettings.globalize_path(path))
	print("CAPTURED ", path)
