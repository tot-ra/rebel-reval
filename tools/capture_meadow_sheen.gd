extends SceneTree

## Review plate for the flat grass ground sheen (docs/SYSTEMS/SEAMLESS_CITY.md).
## Low sun over a pasture from a gameplay-height camera. Needs a renderer:
##   tools/godot_render.sh --script tools/capture_meadow_sheen.gd [-- --tag=now]
## Output: build/grass/meadow_<shot>_<tag>.png

const OUTPUT_DIR := "res://build/grass"
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
	viewport.size = Vector2i(1600, 900)
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
	for spec: Array in [["high", 0.45, 14.0], ["low", 0.30, 14.0]]:
		world.apply_time(float(spec[1]))
		camera.look_at_from_position(
			Vector3(focus.x - 12.0, g + float(spec[2]), focus.y + 12.0),
			Vector3(focus.x, g, focus.y), Vector3.UP)
		for i in 30:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/meadow_%s_%s.png" % [OUTPUT_DIR, spec[0], _tag]
		viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		print("captured ", path)
	quit(0)
