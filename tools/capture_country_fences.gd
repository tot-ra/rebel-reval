extends SceneTree

## Review plate for the country fences (docs/SYSTEMS/FARMLAND.md): wattle, pole and
## dry-stone fences side by side on flat ground. Needs a renderer:
##   tools/godot_render.sh --script tools/capture_country_fences.gd
## Output: build/fences/country_fences.png

const OUTPUT := "res://build/fences/country_fences.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/fences"))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1800, 700)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.6, 0.7, 0.8)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.72, 0.75)
	var we := WorldEnvironment.new()
	we.environment = env
	viewport.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -35, 0)
	viewport.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 30)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.32, 0.4, 0.2)
	ground.material_override = gm
	viewport.add_child(ground)
	# One enclosure per kind, found by scanning ids.
	var wanted := [&"wattle", &"pole", &"stone"]
	var x := -9.0
	for kind: StringName in wanted:
		var id := ""
		for i in 400:
			if CityFences.kind_for("t.%d" % i) == kind:
				id = "t.%d" % i
				break
		var node := Node3D.new()
		node.position = Vector3(x, 0, 0)
		viewport.add_child(node)
		var poly := PackedVector2Array([Vector2(0, 0), Vector2(7, 0), Vector2(7, -4), Vector2(0, -4)])
		CityFences.build(node, id, poly, func(_p: Vector2) -> float: return 0.0, 200.0)
		x += 9.0
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.current = true
	camera.look_at_from_position(Vector3(0, 2.6, 6.5), Vector3(0, 0.5, -1.5), Vector3.UP)
	camera.fov = 70
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT))
	print("captured ", OUTPUT)
	quit(0)
