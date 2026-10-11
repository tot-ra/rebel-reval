extends SceneTree

## Review plates for the hay stack (docs/SYSTEMS/FARMLAND.md): the three sizes beside
## a 1.8 m figure, and the flank yielding under a pushing actor. Needs a renderer:
##   tools/godot_render.sh --script tools/capture_hay_stack.gd [-- --tag=now]
## Output: build/hay/hay_<shot>_<tag>.png

const OUTPUT_DIR := "res://build/hay"
const VIEWPORT_SIZE := Vector2i(1400, 800)

var _tag := "now"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			_tag = arg.substr(6)
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	var soil := StandardMaterial3D.new()
	soil.albedo_color = Color(0.36, 0.42, 0.2)
	ground.material_override = soil
	world.add_child(ground)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -35, 0)
	sun.shadow_enabled = true
	world.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.74, 0.86)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.72, 0.78)
	world.add_child(env)
	var sizes := [
		MapViewHayMeshes.SIZE_SMALL, MapViewHayMeshes.SIZE_MEDIUM, MapViewHayMeshes.SIZE_TALL
	]
	var ricks: Array[Node3D] = []
	for i in sizes.size():
		var at := Vector3(-6 + i * 6.0, 0, 0)
		ricks.append(
			MapViewHayMeshes.add_rick(world, "Rick%d" % i, i * 5 + 1, at, Vector3.ONE, sizes[i])
		)
		var figure := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.height = 1.8
		capsule.radius = 0.25
		figure.mesh = capsule
		figure.position = Vector3(-6 + i * 6.0 + 2.6, 0.9, 1.2)
		world.add_child(figure)
	var camera := Camera3D.new()
	camera.far = 200.0
	world.add_child(camera)
	camera.current = true
	camera.position = Vector3(0, 2.2, 13)
	camera.look_at(Vector3(0, 1.4, 0))
	await _shot(viewport, "sizes")
	camera.position = Vector3(3.5, 1.6, 5.5)
	camera.look_at(Vector3(0, 1.4, 0))
	await _shot(viewport, "close")
	# Actor presses on the medium rick's -x flank: it yields and leans away.
	var rick := ricks[1]
	var r := (rick as HayRickReaction).collision_radius
	HayRickReaction.set_actor(Vector2(rick.global_position.x - r - 0.3, 0.0), Vector2(1.5, 0.0))
	for i in 40:
		await process_frame
	camera.position = Vector3(0, 1.8, 9.0)
	camera.look_at(Vector3(-1.0, 1.4, 0))
	await _shot(viewport, "pushed")
	# A gale: the wind field is global, so the same stacks now shed and carry strands.
	HayRickReaction.clear_actor()
	WindField.publish(WindField.params_for(Vector2(1.0, 0.3), 0.9))
	camera.position = Vector3(0, 2.4, 11.0)
	camera.look_at(Vector3(0, 1.4, 0))
	await _wait_seconds(5.0)
	await _shot(viewport, "gale")
	await _wait_seconds(1.3)
	await _shot(viewport, "gale2")
	quit()


func _wait_seconds(seconds: float) -> void:
	await create_timer(seconds).timeout


func _shot(viewport: SubViewport, shot: String) -> void:
	for i in 6:
		await process_frame
	var image := viewport.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("%s/hay_%s_%s.png" % [OUTPUT_DIR, shot, _tag]))
