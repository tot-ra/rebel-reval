extends SceneTree

## Species leaf litter plate: in the real city, frames the foot of the first
## birch, maple, oak and pine that carry litter and saves one frame each, so
## the leaf atlas, the per-species tint and the seasonal fresh share can be
## reviewed (October: fresh yellow/red/tan; July: weathered brown).
##   tools/godot_render.sh --script tools/capture_leaf_litter.gd -- --date=1343-10-20
## Output: build/season/litter_<species>_<date>.png

const SPECIES: Array[StringName] = [&"birch", &"maple", &"oak", &"pine"]

var _date := {"year": 1343, "month": 10, "day": 20}
var _tag := "1343-10-20"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--date="):
			var parts := arg.substr(7).split("-")
			_date = {"year": int(parts[0]), "month": int(parts[1]), "day": int(parts[2])}
			_tag = arg.substr(7)
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Litter plates need a real renderer (tools/godot_render.sh)")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/season"))
	var plan := CityPlan.load_default()
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
	MapViewMaterials.apply_vegetation_season(_date)
	world.apply_season(_date)
	world.apply_time(0.45)
	var lod := world.get_node("Vegetation/TreeLod")
	var done: Array[StringName] = []
	for t: Array in plan.data.get("trees", []):
		var species := StringName(t[2])
		if not species in SPECIES or species in done:
			continue
		var p := Vector2(t[0], t[1])
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(Vector2i(int(p.x * 10.0), int(p.y * 10.0)))
		# Same draws as CityVegetationBuilder.build: yaw, tone, then the litter roll.
		rng.randf()
		rng.randf()
		if rng.randf() >= CityVegetationBuilder.LITTER_SHARE:
			continue
		done.append(species)
		var foot := Vector3(p.x, plan.ground_height(p), p.y)
		var eye := foot + Vector3(2.2, 1.7, 1.6)
		camera.look_at_from_position(eye, foot + Vector3(-0.3, 0.0, -0.3), Vector3.UP)
		camera.fov = 60.0
		for i in 6:
			lod.update_for(eye)
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "res://build/season/litter_%s_%s.png" % [species, _tag]
		viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		print("litter plate ", path)
	quit(0)
