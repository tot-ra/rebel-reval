extends SceneTree

## Engine review plates for realistic (MPFB) characters, ADR 0022. GPU run:
## tools/godot_render.sh --resolution 1280x1280 \
##   --script tools/capture_realistic_character.gd -- \
##   --scene=res://assets/characters/kalev/kalev.tscn \
##   --out=res://build/realistic_captures/kalev \
##   [--wearables=res://a.tres,res://b.tres] [--prop=res://path/to/weapon.glb]

const SHOTS: Array[Dictionary] = [
	{
		"slug": "front",
		"animation": &"idle",
		"time": 0.4,
		"yaw": 0.0,
		"distance": 4.4,
		"height": 1.05
	},
	{
		"slug": "three_quarter",
		"animation": &"idle",
		"time": 0.4,
		"yaw": 35.0,
		"distance": 4.4,
		"height": 1.05
	},
	{
		"slug": "back",
		"animation": &"idle",
		"time": 0.4,
		"yaw": 180.0,
		"distance": 4.4,
		"height": 1.05
	},
	{
		"slug": "portrait",
		"animation": &"idle",
		"time": 0.4,
		"yaw": 18.0,
		"distance": 1.15,
		"height": 1.86
	},
	{
		"slug": "portrait_profile",
		"animation": &"idle",
		"time": 0.4,
		"yaw": 85.0,
		"distance": 1.15,
		"height": 1.86
	},
	{
		"slug": "crown",
		"animation": &"idle",
		"time": 0.4,
		"yaw": 20.0,
		"distance": 0.55,
		"height": 1.98,
		"lift": 0.75
	},
	{
		"slug": "walk",
		"animation": &"walk",
		"time": 0.25,
		"yaw": 30.0,
		"distance": 4.4,
		"height": 1.05
	},
	{"slug": "run", "animation": &"run", "time": 0.3, "yaw": 60.0, "distance": 4.4, "height": 1.05},
	{
		"slug": "attack",
		"animation": &"hammer_attack",
		"time": 0.34,
		"yaw": 30.0,
		"distance": 4.4,
		"height": 1.1
	},
]

var _rig: SharedCharacterRig
var _camera: Camera3D


func _initialize() -> void:
	call_deferred("_run")


func _arg(name: String, fallback: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--%s=" % name):
			return argument.trim_prefix("--%s=" % name)
	return fallback


func _run() -> void:
	root.size = Vector2i(1280, 1280)
	var output := _arg("out", "res://build/realistic_captures/kalev")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var stage := _stage()
	root.add_child(stage)
	_rig = (
		(load(_arg("scene", "res://assets/characters/realistic/kalev/kalev.tscn")) as PackedScene)
		. instantiate()
	)
	stage.add_child(_rig)
	await process_frame
	if not _arg("wearables", "").is_empty():
		# Outfit plates start from the bare body, not the scene's default outfit.
		for slot: String in CharacterWardrobe.SLOTS:
			_rig.unequip_wearable(StringName(slot))
	for path: String in _arg("wearables", "").split(",", false):
		var wearable := load(path) as CharacterWearable
		if wearable == null or not _rig.equip_wearable(wearable):
			push_error("could not equip %s" % path)
	var prop := _arg("prop", "")
	if not prop.is_empty():
		_rig.equip(&"right_hand", load(prop) as PackedScene)
	for shot: Dictionary in SHOTS:
		await _shot(shot, output)
	quit()


func _stage() -> Node3D:
	var stage := Node3D.new()
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.36, 0.38, 0.41)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.58, 0.62)
	env.environment.ambient_light_energy = 0.55
	env.environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	stage.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, -35, 0)
	key.light_energy = 2.2
	key.shadow_enabled = true
	stage.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-30, 150, 0)
	rim.light_energy = 0.9
	stage.add_child(rim)
	var floor := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.6
	disc.bottom_radius = 1.6
	disc.height = 0.04
	floor.mesh = disc
	floor.position.y = -0.02
	stage.add_child(floor)
	_camera = Camera3D.new()
	_camera.fov = 30.0
	stage.add_child(_camera)
	return stage


func _shot(shot: Dictionary, output: String) -> void:
	_rig.play_animation(shot["animation"], 0.0)
	var player := _rig.animation_player()
	player.speed_scale = 0.0
	player.seek(float(shot["time"]) * player.current_animation_length, true)
	var yaw := deg_to_rad(float(shot["yaw"]))
	var target := Vector3(0, float(shot["height"]), 0)
	_camera.position = (
		target
		+ Vector3(sin(yaw), float(shot.get("lift", 0.05)), cos(yaw)) * float(shot["distance"])
	)
	_camera.look_at(target)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [output, shot["slug"]]
	root.get_texture().get_image().save_png(path)
	print("CAPTURED ", path)
