extends SceneTree

## ADR 0045 autumn leaf-fall plate in the real city: drops the camera among the
## city's trees on an October date with a stiff wind and saves a frame.
##   tools/godot_render.sh --script tools/capture_city_leaves.gd -- --date=1343-10-20 --wind=0.7
## `--pitch=-0.8` tilts the camera down onto the leaf litter (default 0.1).
## Output: build/season/leaves_<date>_<wind>[_p<pitch>].png

const OUTPUT_DIR := "res://build/season"
const VIEWPORT_SIZE := Vector2i(1600, 900)

var _date := {"year": 1343, "month": 10, "day": 20}
var _tag := "1343-10-20"
var _wind := 0.7
var _pitch := 0.1


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--date="):
			var parts := arg.substr(7).split("-")
			_date = {"year": int(parts[0]), "month": int(parts[1]), "day": int(parts[2])}
			_tag = arg.substr(7)
		elif arg.begins_with("--wind="):
			_wind = float(arg.substr(7))
		elif arg.begins_with("--pitch="):
			_pitch = float(arg.substr(8))
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Leaf plates need a real renderer (tools/godot_render.sh)")
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
	var lod := world.get_node("Vegetation/TreeLod")
	var leaves := CityLeafFall.new()
	viewport.add_child(leaves)
	leaves.configure(lod)
	# The spot with the most deciduous trees within 30 m.
	var best := Vector3.ZERO
	var best_count := 0
	for y in range(-300, 600, 20):
		for x in range(-300, 600, 20):
			var probe := Vector3(x, 0.0, y)
			var count := 0
			for tree: Array in lod.trees_near(probe, 30.0):
				if not VegetationPhenology.is_evergreen(tree[0]):
					count += 1
			if count > best_count:
				best_count = count
				best = probe
	print("leaf spot ", best, " deciduous trees ", best_count)
	var ground := plan.ground_height(Vector2(best.x, best.z))
	var eye := Vector3(best.x, ground + 2.2, best.z)
	camera.look_at_from_position(eye, eye + Vector3(1, _pitch, 0.6), Vector3.UP)
	camera.fov = 70.0
	var wind := Vector2(0.8, 0.6)
	MapViewMaterials.apply_world_wind(wind, _wind)
	world.apply_time(0.45)
	# Frames outrun the clock in a minimized window: simulate 10 s of fall up front.
	for i in 4:
		leaves.update_leaves(eye, _date, wind, _wind, 1.0, -camera.global_transform.basis.z)
		await process_frame
	leaves.preprocess = 10.0
	leaves.restart()
	for i in 30:
		lod.update_for(eye)
		leaves.update_leaves(eye, _date, wind, _wind, 1.0 / 30.0, -camera.global_transform.basis.z)
		await process_frame
	await RenderingServer.frame_post_draw
	var suffix := "" if is_equal_approx(_pitch, 0.1) else "_p%s" % str(_pitch)
	var path := "%s/leaves_%s_%s%s.png" % [OUTPUT_DIR, _tag, str(_wind), suffix]
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("leaf plate: ", path, " shedding ", leaves.shedding)
	quit(0)
