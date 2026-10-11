extends SceneTree

## ADR 0045 plate: footprints in settled snow. Builds the city in January, walks
## the trail window along a path over a meadow (the same call the player's feet
## make) and frames the prints low and from above. Needs a renderer:
##   tools/godot_render.sh --script tools/capture_snow_prints.gd [-- --date=1343-01-15]
## Output: build/season/snow_prints_<shot>_<date>.png

const OUTPUT_DIR := "res://build/season"
const VIEWPORT_SIZE := Vector2i(1600, 900)

var _date := {"year": 1343, "month": 1, "day": 15}
var _tag := "1343-01-15"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--date="):
			var parts := arg.substr(7).split("-")
			_date = {"year": int(parts[0]), "month": int(parts[1]), "day": int(parts[2])}
			_tag = arg.substr(7)
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Snow print plates need a real renderer (tools/godot_render.sh)")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var plan := CityPlan.load_default()
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := CityWorld3D.create(plan)
	viewport.add_child(world)
	var camera := Camera3D.new()
	camera.far = 4000.0
	camera.near = 0.05
	viewport.add_child(camera)
	camera.current = true
	world.setup_lighting(camera)
	MapViewMaterials.apply_vegetation_season(_date)
	world.apply_season(_date)
	# An open meadow spot near the pasture the grass plates use.
	var focus := Vector2.ZERO
	var best := INF
	for f in CityFarmland.features_for(plan):
		if f["kind"] == &"pasture" and (f["centre"] as Vector2).length() < best:
			best = (f["centre"] as Vector2).length()
			focus = f["centre"]
	var start := focus + Vector2(-8.0, 0.0)
	world.trail.update_for(start, 0.016)
	var pos := start
	for i in 70:
		pos += Vector2(0.26, 0.05)
		world.trail.update_for(pos, 0.016)
	var mid := start.lerp(pos, 0.5)
	var g := plan.ground_height(mid)
	var shots := [
		["low", Vector3(mid.x - 2.2, g + 0.55, mid.y - 1.6), Vector3(mid.x + 0.5, g, mid.y), 60.0],
		["high", Vector3(mid.x - 3.0, g + 3.2, mid.y - 2.2), Vector3(mid.x + 0.8, g, mid.y), 55.0],
	]
	for shot: Array in shots:
		camera.fov = shot[3]
		camera.look_at_from_position(shot[1], shot[2], Vector3.UP)
		world.apply_time(0.45)
		for i in 40:
			world.grass.update_for(mid)
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/snow_prints_%s_%s.png" % [OUTPUT_DIR, shot[0], _tag]
		viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		print("snow print plate: ", path)
	quit(0)
