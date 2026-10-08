extends SceneTree

## Review plates for tall grass and the trail behind a walker (docs/SYSTEMS/SEAMLESS_CITY.md).
## A capsule walks a straight line through the pasture; the grass shader parts round
## it and keeps a lane open behind. Needs a renderer:
##   tools/godot_render.sh --script tools/capture_tall_grass.gd [-- --tag=now]
## Output: build/grass/tall_<shot>_<tag>.png

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
	world.apply_time(0.42)
	print("wildness at focus %.2f, drag %.2f" % [
		world.grass.wildness_at(focus), world.grass.walk_drag_at(focus)])
	var walker := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.7
	walker.mesh = capsule
	world.add_child(walker)
	# Walk 7 m along +X at 1.2 m/s, one step per 0.1 s, then pose a camera behind.
	var pos := focus - Vector2(7.0, 0.0)
	var now := 0.0
	for i in 60:
		pos.x += 0.12
		now += 0.1
		MapViewMaterials.apply_grass_interaction(pos, Vector2(1.2, 0.0), now)
		world.grass.update_for(pos)
		await process_frame
	var g := plan.ground_height(pos)
	walker.position = Vector3(pos.x, g + 0.85, pos.y)
	var specs := [
		["behind", Vector3(-4.5, 1.6, 1.8), 0.4],
		["side", Vector3(-1.5, 1.0, 4.0), 0.5],
	]
	for spec: Array in specs:
		var off: Vector3 = spec[1]
		camera.look_at_from_position(
			Vector3(pos.x + off.x, g + off.y, pos.y + off.z),
			Vector3(pos.x - 1.0, g + float(spec[2]), pos.y), Vector3.UP)
		for i in 20:
			world.grass.update_for(pos)
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/tall_%s_%s.png" % [OUTPUT_DIR, spec[0], _tag]
		viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		print("captured ", path)
	quit(0)
