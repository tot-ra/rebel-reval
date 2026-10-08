extends SceneTree

## Review plates for the blade-geometry meadow (docs/SYSTEMS/VEGETATION_REALISM.md,
## VEGR-4): eye level, gameplay camera and a close ground shot over the pasture.
## Needs a renderer:
##   tools/godot_render.sh --script tools/capture_city_grass.gd [-- --tag=now]
## Output: build/grass/<shot>_<tag>.png

const OUTPUT_DIR := "res://build/grass"
const VIEWPORT_SIZE := Vector2i(1600, 900)

var _tag := "now"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			_tag = arg.substr(6)
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var plan := CityPlan.load_default()
	var focus := Vector2.ZERO
	var best := INF
	for f in CityFarmland.features_for(plan):
		if f["kind"] == &"pasture" and (f["centre"] as Vector2).length() < best:
			best = (f["centre"] as Vector2).length()
			focus = f["centre"]
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := CityWorld3D.create(plan)
	viewport.add_child(world)
	var camera := Camera3D.new()
	camera.far = 4000.0
	viewport.add_child(camera)
	camera.current = true
	world.setup_lighting(camera)
	var g := plan.ground_height(focus)
	# name, eye offset (x, height above ground, z), look-at height, fov
	var specs := [
		["eye", Vector3(4.0, 1.7, 4.0), 0.3, 65.0],
		["game", Vector3(9.0, 6.0, 9.0), 0.0, 55.0],
		["close", Vector3(1.2, 0.7, 1.2), 0.1, 60.0],
	]
	var shots: Array[Dictionary] = []
	for spec: Array in specs:
		var off: Vector3 = spec[1]
		shots.append({
			"name": spec[0],
			"eye": Vector3(focus.x + off.x, g + off.y, focus.y + off.z),
			"look": Vector3(focus.x, g + float(spec[2]), focus.y),
			"fov": spec[3],
		})
	for shot in shots:
		camera.fov = shot["fov"]
		camera.look_at_from_position(shot["eye"], shot["look"], Vector3.UP)
		world.apply_time(0.42)
		for i in 60:
			world.grass.update_for(Vector2(shot["eye"].x, shot["eye"].z))
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/%s_%s.png" % [OUTPUT_DIR, shot["name"], _tag]
		viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		print("captured %s at %s" % [path, focus])
	quit(0)
