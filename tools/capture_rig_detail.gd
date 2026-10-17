extends SceneTree

## Review plates for the human rig detail bones (neck, collarbones, upper
## spine; tools/assets/realistic_humans/rig_detail.py): Kalev frozen in a row
## of clips that bend the trunk, raise the arms and drop the head, from the
## front three-quarter and from the side. Run before and after a rebuild with
## different prefixes to compare:
##   tools/godot_render.sh --script tools/capture_rig_detail.gd -- --prefix=after
##   [--scene=res://assets/characters/variants/aita.tscn]

const KALEV_SCENE := preload("res://assets/characters/kalev/kalev.tscn")
const OUTPUT_DIR := "res://docs/reports/images/rig_detail"
const VIEWPORT_SIZE := Vector2i(2400, 900)
const SPACING := 1.15
## [clip, time as a share of its length]
const POSES: Array = [
	["Idle", 0.0],
	["Walking_A", 0.3],
	["Cheer", 0.45],
	["Spellcast_Raise", 0.8],
	["2H_Melee_Attack_Chop", 0.35],
	["PickUp", 0.5],
	["Interact", 0.5],
	["Sit_Floor_Idle", 0.0],
]
const VIEWS: Array[Dictionary] = [
	{"slug": "front", "yaw": 25.0},
	{"slug": "side", "yaw": 90.0},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var prefix := _argument("--prefix=", "after")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(_build_stage())
	var scene: PackedScene = KALEV_SCENE
	var scene_path := _argument("--scene=", "")
	if scene_path != "":
		scene = load(scene_path) as PackedScene
	var rigs: Array[SharedCharacterRig] = []
	for index in POSES.size():
		var rig: SharedCharacterRig = scene.instantiate()
		viewport.add_child(rig)
		rig.position = Vector3((index - (POSES.size() - 1) * 0.5) * SPACING, 0.0, 0.0)
		rigs.append(rig)
	await process_frame
	print("bones: %d" % rigs[0].skeleton().get_bone_count())
	for index in POSES.size():
		_pose(rigs[index], String(POSES[index][0]), float(POSES[index][1]))
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.6
	viewport.add_child(camera)
	camera.current = true
	for view: Dictionary in VIEWS:
		for rig in rigs:
			rig.rotation_degrees = Vector3(0.0, float(view["yaw"]), 0.0)
		camera.position = Vector3(0.0, 0.95, 8.0)
		camera.look_at(Vector3(0.0, 0.95, 0.0), Vector3.UP)
		for _frame in 3:
			await process_frame
		var output := "%s/%s_%s.png" % [OUTPUT_DIR, prefix, view["slug"]]
		viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(output))
		print("Rig detail plate: %s" % output)
	quit(0)


func _pose(rig: SharedCharacterRig, clip: String, share: float) -> void:
	var player := rig.animation_player()
	var found := ""
	for name: StringName in player.get_animation_list():
		if String(name).get_file() == clip or String(name).ends_with("/" + clip):
			found = String(name)
	if found == "":
		push_warning("clip %s not found" % clip)
		return
	player.play(found)
	player.seek(player.get_animation(found).length * share, true)
	player.pause()
	rig.skeleton().force_update_all_bone_transforms()


func _argument(prefix: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return fallback


func _build_stage() -> Node3D:
	var stage := Node3D.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.32, 0.34, 0.36)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.604, 0.678, 0.741)
	environment.ambient_light_energy = 0.5
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40.0, 20.0, 0.0)
	sun.light_color = Color(1.0, 0.9, 0.78)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	stage.add_child(sun)
	return stage
