extends SceneTree

## ADR 0045 review plates of the water and the moat through the year. Builds the
## city, pushes a campaign date through CityWorld3D.apply_season and frames the
## moat from the bank and from above. Needs a renderer:
##   tools/godot_render.sh --script tools/capture_city_season.gd -- --date=1343-01-15
## Output: build/season/moat_<shot>_<date>.png

const OUTPUT_DIR := "res://build/season"
const VIEWPORT_SIZE := Vector2i(1600, 900)
const DAY_PROGRESS := 0.45

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
		push_error("Season plates need a real renderer (tools/godot_render.sh)")
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
	viewport.add_child(camera)
	camera.current = true
	world.setup_lighting(camera)
	MapViewMaterials.apply_vegetation_season(_date)
	world.apply_season(_date)
	# A moat record well past the stream segments, then frame it.
	var index := clampi(world.stream_segment_count + 6, 0, world.moat_water.size() - 1)
	var rec: Array = world.moat_water[index]
	var mid: Vector2 = (rec[0] as Vector2).lerp(rec[1], 0.5)
	var surface := float(rec[2])
	var shots := [
		[
			"bank", Vector3(mid.x + 7.0, surface + 1.8, mid.y + 7.0),
			Vector3(mid.x, surface, mid.y), 60.0
		],
		[
			"high", Vector3(mid.x + 9.0, surface + 14.0, mid.y + 11.0),
			Vector3(mid.x, surface, mid.y), 55.0
		],
	]
	for shot: Array in shots:
		camera.fov = shot[3]
		camera.look_at_from_position(shot[1], shot[2], Vector3.UP)
		world.apply_time(DAY_PROGRESS)
		for i in 30:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/moat_%s_%s.png" % [OUTPUT_DIR, shot[0], _tag]
		viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		print("season plate: ", path)
	quit(0)
