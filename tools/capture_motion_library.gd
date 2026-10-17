extends SceneTree

## R-2211 before/after plates: residents and heroes of different builds posed in the same
## clips, plus a pose signature (key-bone positions) so two asset states can be diffed, and
## spawn cost (wall time, static memory). Requires a rendering run:
##   tools/godot_render.sh --script tools/capture_motion_library.gd -- \
##     --out=res://build/motion_library/after
## docs/SYSTEMS/HUMAN_MOTION_LIBRARY.md

const BODIES: Array[String] = [
	"citizen_m_child_average", "citizen_f_adult_thin_b", "citizen_m_adult_average",
	"citizen_m_elder_thin",
	"townswoman", "watchman", "aita", "kalev", "henning", "apprentice",
]
const CLIPS: Array[Dictionary] = [
	{"clip": &"idle", "time": 0.4},
	{"clip": &"walk", "time": 0.3},
	{"clip": &"run", "time": 0.2},
	{"clip": &"hammer_attack", "time": 0.35},
]
const SIGNATURE_BONES: Array[StringName] = [
	&"head", &"hand.l", &"hand.r", &"foot.l", &"foot.r", &"hips"
]
const SPACING := 1.3


func _initialize() -> void:
	call_deferred("_run")


static func _scene_path(body: String) -> String:
	# Kalev's scene is maintained by hand next to his model, every other cast member is generated.
	if body == "kalev":
		return "res://assets/characters/kalev/kalev.tscn"
	return "res://assets/characters/variants/%s.tscn" % body


func _run() -> void:
	var out := "res://build/motion_library/after"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(2600, 760)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.57, 0.6)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.78)
	viewport.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -25, 0)
	viewport.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.6
	camera.position = Vector3(0.0, 0.95, 6.0)
	viewport.add_child(camera)
	camera.current = true

	var started := Time.get_ticks_usec()
	var memory_before := OS.get_static_memory_usage()
	var rigs: Array[SharedCharacterRig] = []
	for i in BODIES.size():
		var rig := (load(_scene_path(BODIES[i])) as PackedScene).instantiate() as SharedCharacterRig
		viewport.add_child(rig)
		rig.position = Vector3((i - (BODIES.size() - 1) * 0.5) * SPACING, 0.0, 0.0)
		rigs.append(rig)
	var spawn_ms := (Time.get_ticks_usec() - started) / 1000.0
	for _frame in 4:
		await process_frame
	var memory_mb := (OS.get_static_memory_usage() - memory_before) / 1048576.0

	var signature := {}
	for clip: Dictionary in CLIPS:
		for rig in rigs:
			rig.play_animation(clip["clip"], 0.0)
			var player := rig.animation_player()
			player.seek(float(clip["time"]), true)
			player.pause()
		for _frame in 3:
			await process_frame
		for i in rigs.size():
			var skeleton := rigs[i].skeleton()
			var bones := {}
			for bone_name in SIGNATURE_BONES:
				var origin := skeleton.get_bone_global_pose(skeleton.find_bone(bone_name)).origin
				bones[String(bone_name)] = [
					snappedf(origin.x, 0.0001), snappedf(origin.y, 0.0001), snappedf(origin.z, 0.0001)
				]
			signature["%s/%s" % [BODIES[i], clip["clip"]]] = bones
		var png := ProjectSettings.globalize_path("%s/%s.png" % [out, clip["clip"]])
		viewport.get_texture().get_image().save_png(png)
	var report := {
		"spawn_ms": snappedf(spawn_ms, 0.1),
		"static_memory_mb": snappedf(memory_mb, 0.1),
		"pose": signature,
	}
	var file := FileAccess.open("%s/report.json" % out, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, " "))
	file.close()
	print("spawn %.0f ms, +%.1f MB static" % [spawn_ms, memory_mb])
	quit(0)
