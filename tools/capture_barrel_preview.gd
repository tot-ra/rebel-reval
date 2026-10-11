extends SceneTree

## Close-up capture of the 3D `barrels` prop (one coopered oak barrel per prop).
## Run without --headless so the GPU renderer is live:
##   tools/godot_render.sh --script tools/capture_barrel_preview.gd
## Writes build/previews/barrel_preview*.png. The row shot places three props
## side by side to show that the map, not the model, controls the barrel count.

const SHOTS := {
	"res://build/previews/barrel_preview.png": [Vector3(1.5, 1.3, 1.5), Vector3(0.0, 0.42, 0.0)],
	"res://build/previews/barrel_preview_top.png": [Vector3(0.25, 1.9, 0.9), Vector3(0.0, 0.5, 0.0)],
}
const ROW_OUTPUT := "res://build/previews/barrel_preview_row.png"
const VIEW_SIZE := Vector2i(1024, 1024)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/previews"))
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)

	var scene := Node3D.new()
	viewport.add_child(scene)
	_add_environment(scene)

	var barrel := _barrel_prop(&"preview_barrel", Vector2.ZERO)
	scene.add_child(barrel)

	var camera := Camera3D.new()
	camera.fov = 40.0
	viewport.add_child(camera)
	camera.make_current()

	for output: String in SHOTS:
		var shot: Array = SHOTS[output]
		camera.look_at_from_position(shot[0], shot[1], Vector3.UP)
		if not await _save(viewport, output):
			return

	# Three independent props, as a map author would place them, under the
	# orthographic gameplay-style camera.
	barrel.position.x = -0.75
	for index in 2:
		var extra := _barrel_prop(StringName("preview_barrel_%d" % index), Vector2.ZERO)
		extra.position.x = 0.75 * index
		scene.add_child(extra)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.6
	camera.look_at_from_position(Vector3(3.0, 3.3, 3.0), Vector3(0.0, 0.4, 0.0), Vector3.UP)
	await _save(viewport, ROW_OUTPUT)
	quit(0)


func _barrel_prop(id: StringName, position: Vector2) -> Node3D:
	return MapViewMeshBuilder.build_prop(
		{"id": id, "kind": MapTypes.PROP_KIND_BARRELS, "position": position},
		MapTypes.DEFAULT_CELL_SIZE
	)


func _save(viewport: SubViewport, output: String) -> bool:
	for _frame in 20:
		await process_frame
	var error := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(output))
	if error != OK:
		push_error("Barrel preview failed: %s" % error_string(error))
		quit(1)
		return false
	print("BARREL_PREVIEW=%s" % output)
	return true


func _add_environment(scene: Node3D) -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color8(96, 100, 104)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color8(180, 184, 190)
	environment.ambient_light_energy = 0.5
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	scene.add_child(world)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(6.0, 6.0)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color8(92, 84, 72)
	ground.material_override = ground_material
	scene.add_child(ground)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	sun.light_color = Color8(255, 236, 208)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	scene.add_child(sun)
