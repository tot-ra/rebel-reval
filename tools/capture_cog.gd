extends SceneTree

## Review plates for the Hanseatic cog (docs/SYSTEMS/SHIPS.md): hull and rig from
## outside, the deck from above, the stern cabin, the hold well, the forecastle
## store and the sail in two winds. Needs a renderer:
##   tools/godot_render.sh --script tools/capture_cog.gd [-- --tag=now] [--only=side,deck]
## Output: build/cog/<shot>_<tag>.png

const OUTPUT_DIR := "res://build/cog"
const VIEWPORT_SIZE := Vector2i(1600, 900)

var _tag := "now"
var _only := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			_tag = arg.substr(6)
		elif arg.begins_with("--only="):
			_only = arg.substr(7)
	call_deferred("_run")


## name, eye, look, fov, sail_set, wind (toward, strength), cog yaw (radians, 0 = bow +X)
func _shots() -> Array[Dictionary]:
	return [
		{
			"name": "side",
			"eye": Vector3(-6.0, 4.5, 38.0),
			"look": Vector3(1.0, 5.0, 0.0),
			"fov": 45.0,
			"set": false
		},
		{
			"name": "bow_quarter",
			"eye": Vector3(26.0, 6.0, 20.0),
			"look": Vector3(0.0, 4.0, 0.0),
			"fov": 50.0,
			"set": false
		},
		{
			"name": "stern",
			"eye": Vector3(-24.0, 5.0, 8.0),
			"look": Vector3(-8.0, 2.5, 0.0),
			"fov": 55.0,
			"set": false
		},
		{
			"name": "waterline_close",
			"eye": Vector3(-1.0, 1.2, 14.0),
			"look": Vector3(0.0, 1.8, 3.5),
			"fov": 55.0,
			"set": false
		},
		{
			"name": "deck_top",
			"eye": Vector3(0.5, 22.0, 3.0),
			"look": Vector3(0.5, 2.0, 0.0),
			"fov": 55.0,
			"set": false
		},
		{
			"name": "deck_walk",
			"eye": Vector3(-3.4, 4.0, 0.0),
			"look": Vector3(5.0, 3.0, 0.0),
			"fov": 70.0,
			"set": false
		},
		{
			"name": "cabin",
			"eye": Vector3(-5.2, 3.8, 0.6),
			"look": Vector3(-8.4, 3.0, -0.6),
			"fov": 75.0,
			"set": false
		},
		{
			"name": "well",
			"eye": Vector3(-3.9, 4.0, 0.0),
			"look": Vector3(0.3, -0.6, 0.0),
			"fov": 75.0,
			"set": false
		},
		{
			"name": "store",
			"eye": Vector3(6.0, 3.9, 0.3),
			"look": Vector3(9.0, 2.6, -0.4),
			"fov": 75.0,
			"set": false
		},
		{
			"name": "rudder",
			"eye": Vector3(-14.0, 3.0, 3.0),
			"look": Vector3(-9.0, 1.2, 0.0),
			"fov": 55.0,
			"set": false
		},
		{
			"name": "ratlines",
			"eye": Vector3(-8.0, 6.0, -9.0),
			"look": Vector3(1.5, 8.5, -2.0),
			"fov": 55.0,
			"set": false
		},
		{
			"name": "sail_profile_aft",
			"eye": Vector3(2.5, 8.0, 45.0),
			"look": Vector3(2.5, 8.0, 0.0),
			"fov": 40.0,
			"set": true,
			"wind": Vector2(1, 0),
			"strength": 0.6
		},
		{
			"name": "sail_profile_head",
			"eye": Vector3(2.5, 8.0, 45.0),
			"look": Vector3(2.5, 8.0, 0.0),
			"fov": 40.0,
			"set": true,
			"wind": Vector2(-1, 0),
			"strength": 0.6
		},
		{
			"name": "sail_set_aft",
			"eye": Vector3(-14.0, 8.0, 14.0),
			"look": Vector3(2.5, 8.0, 0.0),
			"fov": 60.0,
			"set": true,
			"wind": Vector2(1, 0),
			"strength": 0.6
		},
		{
			"name": "sail_set_head",
			"eye": Vector3(24.0, 8.0, 22.0),
			"look": Vector3(2.5, 8.0, 0.0),
			"fov": 60.0,
			"set": true,
			"wind": Vector2(-1, 0),
			"strength": 0.6
		},
		{
			"name": "sail_set_beam",
			"eye": Vector3(-12.0, 9.0, 18.0),
			"look": Vector3(2.5, 8.0, 0.0),
			"fov": 60.0,
			"set": true,
			"wind": Vector2(0, 1),
			"strength": 0.6
		},
	]


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.74, 0.86)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.66, 0.72)
	env.ambient_light_energy = 0.9
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	sun.shadow_enabled = true
	sun.light_energy = 1.25
	viewport.add_child(sun)
	var sea := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	sea.mesh = plane
	var sea_mat := StandardMaterial3D.new()
	sea_mat.albedo_color = Color(0.1, 0.28, 0.34)
	sea.material_override = sea_mat
	viewport.add_child(sea)
	var camera := Camera3D.new()
	camera.far = 400.0
	viewport.add_child(camera)
	camera.current = true
	var cog: Node3D = null
	var cog_set := false
	for shot in _shots():
		if not _only.is_empty() and not shot["name"] in _only.split(","):
			continue
		var want_set: bool = shot["set"]
		if cog == null or cog_set != want_set:
			if cog != null:
				cog.queue_free()
			cog = CogModel.build(FactionHeraldry.HANSEATIC, want_set, not want_set)
			viewport.add_child(cog)
			cog_set = want_set
		var w: Vector2 = shot.get("wind", Vector2(-1, 0))
		MapViewMaterials.apply_world_wind(w, float(shot.get("strength", 0.35)))
		camera.fov = shot["fov"]
		camera.look_at_from_position(shot["eye"], shot["look"], Vector3.UP)
		for i in 30:
			await process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		var path := "%s/%s_%s.png" % [OUTPUT_DIR, shot["name"], _tag]
		image.save_png(ProjectSettings.globalize_path(path))
		print("captured ", path)
	quit()
