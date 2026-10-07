extends SceneTree

## Evidence plates for the hoist rope pendulum shader (R-1200).
## Close-up: three 2.4 m ropes with hooks under one beam in light, moderate and
## strong wind, two plates 0.7 s apart so the swing shows. Then the
## merchant_stone production house with its live hoist rope at street distance.
##   tools/godot_render.sh --script tools/capture_hoist_rope.gd

const OUTPUT_DIR := "res://docs/reports/images/hoist_rope"
const VIEWPORT_SIZE := Vector2i(1440, 810)
const WIND_DIRECTION := Vector2(0.9285, 0.3714)
const WINDS: Array[float] = [0.1, 0.5, 0.95]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	_add_environment(stage)

	var beam := MeshInstance3D.new()
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(5.6, 0.2, 0.24)
	beam.mesh = beam_mesh
	beam.material_override = MapViewMaterials.hewn_timber(true, 1)
	beam.position = Vector3(0.0, 3.1, 0.0)
	stage.add_child(beam)
	for index in WINDS.size():
		var rope := MapViewHoistRope.create(2.4)
		for surface in 2:
			var material := rope.get_surface_override_material(surface).duplicate() as ShaderMaterial
			material.set_shader_parameter("wind_direction", WIND_DIRECTION)
			material.set_shader_parameter("wind_strength", WINDS[index])
			rope.set_surface_override_material(surface, material)
		rope.position = Vector3(-2.0 + index * 2.0, 3.0, 0.0)
		stage.add_child(rope)

	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.fov = 40.0
	camera.position = Vector3(0.8, 2.3, 5.4)
	camera.look_at(Vector3(0.3, 1.8, 0.0), Vector3.UP)
	camera.current = true

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for plate in ["a", "b"]:
		for _frame in 12:
			await process_frame
		await create_timer(0.7).timeout
		if not _save(viewport, "hoist_rope_%s" % plate):
			return

	# Street view of a production kit house: the rope hangs from the gable beam.
	stage.queue_free()
	var street := Node3D.new()
	viewport.add_child(street)
	_add_environment(street)
	MapViewMaterials.apply_world_wind(WIND_DIRECTION, 0.6)
	var building := {
		"id": &"merchant_stone_hoist_capture",
		"kind": MapTypes.BUILDING_KIND_HOUSE,
		"house_tier": &"merchant_stone",
		"footprint": Rect2(0.0, 0.0, 9.0 * 32.0, 10.0 * 32.0),
		"wall_height": 144.0,
		"door_side": &"south",
	}
	var house := MapViewMeshBuilder.build_building(building, MapTypes.DEFAULT_CELL_SIZE)
	street.add_child(house)
	var rope_node := house.get_node_or_null(MapViewHoistRope.NODE_NAME) as Node3D
	var target := (
		rope_node.position - Vector3(0.0, 1.4, 0.0)
		if rope_node != null
		else Vector3(0.0, 7.0, 4.0)
	)
	var street_camera := Camera3D.new()
	street.add_child(street_camera)
	street_camera.fov = 40.0
	street_camera.position = target + Vector3(5.5, -1.0, 8.0)
	street_camera.look_at(target, Vector3.UP)
	street_camera.current = true
	for _frame in 12:
		await process_frame
	await create_timer(0.3).timeout
	if not _save(viewport, "hoist_rope_house"):
		return
	quit(0)


func _add_environment(stage: Node3D) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.58, 0.68, 0.80)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.70, 0.74, 0.80)
	environment.ambient_light_energy = 0.4
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40.0, -30.0, 0.0)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	stage.add_child(sun)


func _save(viewport: SubViewport, plate: String) -> bool:
	var image := viewport.get_texture().get_image()
	var path := "%s/%s.png" % [OUTPUT_DIR, plate]
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("Could not save %s: %s" % [path, error_string(error)])
		quit(1)
		return false
	print("Hoist rope plate: %s" % path)
	return true
