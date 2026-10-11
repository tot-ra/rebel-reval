extends SceneTree

## Review capture of the coastal cargo stacks (barrels) in CityHarbour.
##   tools/godot_render.sh --script tools/capture_city_shore_barrels.gd
##   [-- --out=res://build/shore_barrels]

const VIEWPORT_SIZE := Vector2i(1600, 900)
const DAY_PROGRESS := 0.42

var _out := "res://build/shore_barrels"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var plan := CityPlan.load_default()
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := CityWorld3D.create(plan)
	viewport.add_child(world)
	var camera := Camera3D.new()
	camera.far = 6000.0
	viewport.add_child(camera)
	camera.current = true
	world.setup_lighting(camera)
	world.apply_time(DAY_PROGRESS)
	var stack: Dictionary = {}
	for s: Dictionary in plan.data["harbour"]["stacks"]:
		if s["kind"] == "barrel":
			stack = s
			break
	var p := Vector2(stack["at"][0], stack["at"][1])
	var h := plan.ground_height(p)
	var views := {"game": [Vector3(6.0, 6.0, 8.0), 50.0], "close": [Vector3(2.4, 1.8, 3.0), 55.0]}
	for view: String in views:
		var v: Array = views[view]
		camera.fov = v[1]
		var base := Vector3(p.x, h, p.y)
		camera.look_at_from_position(base + (v[0] as Vector3), base + Vector3(0, 0.4, 0), Vector3.UP)
		for i in 10:
			await process_frame
		var path := "%s/shore_barrels_%s.png" % [_out, view]
		viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		print("captured %s" % path)
	quit(0)
