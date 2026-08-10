extends SceneTree

## Portrait-scale face audit for the generated character head. The gameplay
## camera never gets this close, but facial form, eye construction and the
## hair/beard seams can only be judged at portrait scale - see
## docs/reports/face_realism_research.md. Requires a rendering-capable run
## (no --headless):
##   godot --path . --script tools/capture_face_closeup.gd \
##     [-- --output-dir=PATH --scene=res://path/to/rig.tscn --prefix=face]

const KALEV_SCENE := preload("res://assets/characters/kalev/kalev.tscn")
const DEFAULT_OUTPUT_DIR := "res://docs/reports/images/characters"
const VIEWPORT_SIZE := Vector2i(900, 900)

# Each view frames the head bone: yaw rotates the rig, `size` is the
# orthogonal camera height in metres (the head is roughly 0.25 m tall), and
# `offset` nudges the focus point up (eyes) or down (mouth) from the bone.
const VIEWS: Array[Dictionary] = [
	{"slug": "front", "yaw": 0.0, "size": 0.42, "offset": 0.02, "pitch": 0.0},
	{"slug": "three_quarter", "yaw": 35.0, "size": 0.42, "offset": 0.02, "pitch": 0.0},
	{"slug": "profile", "yaw": 90.0, "size": 0.42, "offset": 0.02, "pitch": 0.0},
	{"slug": "iso", "yaw": 0.0, "size": 0.46, "offset": 0.02, "pitch": -30.0},
	{"slug": "eyes", "yaw": 0.0, "size": 0.20, "offset": 0.06, "pitch": 0.0},
	{"slug": "eyes_angled", "yaw": 28.0, "size": 0.20, "offset": 0.06, "pitch": -12.0},
	{"slug": "mouth", "yaw": 18.0, "size": 0.20, "offset": -0.04, "pitch": -8.0},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_dir := _argument("--output-dir=", DEFAULT_OUTPUT_DIR)
	var prefix := _argument("--prefix=", "face")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))

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
	var rig: SharedCharacterRig = scene.instantiate()
	viewport.add_child(rig)
	rig.play_animation(&"idle", 0.0)
	rig.animation_player().seek(0.0, true)
	rig.animation_player().pause()
	rig.skeleton().force_update_all_bone_transforms()

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	viewport.add_child(camera)
	camera.current = true

	for view: Dictionary in VIEWS:
		rig.rotation_degrees = Vector3(0.0, float(view["yaw"]), 0.0)
		rig.skeleton().force_update_all_bone_transforms()
		await process_frame
		var focus := _head_focus(rig) + Vector3.UP * float(view["offset"])
		camera.size = float(view["size"])
		var pitch := deg_to_rad(float(view["pitch"]))
		var direction := Vector3(0.0, sin(-pitch), cos(pitch)).normalized()
		camera.position = focus + direction * 4.0
		camera.look_at(focus, Vector3.UP)
		for _frame in 2:
			await process_frame
		var output := "%s/%s_%s.png" % [output_dir, prefix, view["slug"]]
		var error := viewport.get_texture().get_image().save_png(
			ProjectSettings.globalize_path(output)
		)
		if error != OK:
			push_error("Could not save face close-up %s: %s" % [output, error_string(error)])
			quit(1)
			return
		print("Face close-up: %s" % output)

	viewport.queue_free()
	quit(0)


## World position of the head bone, so framing follows spec head scale and
## stature instead of a hard-coded height.
func _head_focus(rig: SharedCharacterRig) -> Vector3:
	var skeleton := rig.skeleton()
	var bone := skeleton.find_bone("head")
	if bone < 0:
		return rig.global_position + Vector3.UP * 1.7
	var head := skeleton.global_transform * skeleton.get_bone_global_pose(bone).origin
	# The bone sits at the base of the skull; the face centre is above it.
	return head + Vector3.UP * 0.09


func _build_stage() -> Node3D:
	var stage := Node3D.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.035, 0.047, 0.047)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.604, 0.678, 0.741)
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_color = Color(1.0, 0.86, 0.68)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	stage.add_child(sun)
	return stage


func _argument(prefix: String, fallback: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return fallback
