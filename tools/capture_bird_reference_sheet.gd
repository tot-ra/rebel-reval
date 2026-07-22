extends SceneTree

## Reproducible P0-117 silhouette sheet. This tool renders all catalog birds from
## procedural geometry only; it does not instantiate runtime spawning or flight.
## Run with a rendering-capable Godot process (no --headless):
## /Applications/Godot.app/Contents/MacOS/Godot --path . \
##   --script tools/capture_bird_reference_sheet.gd

const BirdSpecies := preload("res://scripts/map/view3d/map_view_bird_species.gd")
const BirdMeshes := preload("res://scripts/map/view3d/map_view_bird_meshes.gd")

const OUTPUT := "res://docs/reports/images/fauna/p0_117_bird_reference_sheet.png"
const VIEWPORT_SIZE := Vector2i(1800, 1200)
const COLUMNS := 6
const CELL_SIZE := Vector2(2.4, 2.15)
const DISPLAY_TARGET := 1.35


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(_build_stage())

	for index in BirdSpecies.ALL_SPECIES.size():
		var species: StringName = BirdSpecies.ALL_SPECIES[index]
		var column := index % COLUMNS
		var row := index / COLUMNS
		var origin := Vector3(
			(float(column) - float(COLUMNS - 1) * 0.5) * CELL_SIZE.x,
			(float((BirdSpecies.ALL_SPECIES.size() - 1) / COLUMNS) * 0.5 - float(row)) * CELL_SIZE.y,
			0.0
		)
		viewport.add_child(_bird_entry(species, origin))

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12.2
	camera.position = Vector3(0.0, 0.3, 22.0)
	viewport.add_child(camera)
	camera.current = true
	camera.look_at(Vector3(0.0, 0.3, 0.0), Vector3.UP)

	for _frame in 8:
		await process_frame
	var error := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT))
	if error != OK:
		push_error("Could not save bird reference sheet %s: %s" % [OUTPUT, error_string(error)])
		quit(1)
		return
	print("P0-117 bird reference sheet: %s" % OUTPUT)
	viewport.queue_free()
	quit(0)


func _bird_entry(species: StringName, origin: Vector3) -> Node3D:
	var root_3d := Node3D.new()
	root_3d.name = String(species).to_pascal_case()
	root_3d.position = origin

	var mesh := BirdMeshes.mesh_for(species)
	var instance := MeshInstance3D.new()
	instance.name = "Model"
	instance.mesh = mesh
	var bounds := mesh.get_aabb()
	var largest_axis := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	var visual_scale := DISPLAY_TARGET / maxf(largest_axis, 0.01)
	instance.scale = Vector3.ONE * visual_scale
	instance.position = Vector3(0.0, 0.15 - (bounds.position.y + bounds.size.y * 0.5) * visual_scale, 0.0)
	instance.rotation_degrees = Vector3(-10.0, -22.0, 0.0)

	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.82
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	instance.material_override = material
	root_3d.add_child(instance)

	var label := Label3D.new()
	label.name = "Label"
	label.text = String(BirdSpecies.id_for(species))
	label.font_size = 28
	label.modulate = Color("e9e2d2")
	label.outline_size = 5
	label.outline_modulate = Color("202527")
	label.position = Vector3(0.0, -0.82, 0.10)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	root_3d.add_child(label)
	return root_3d


func _build_stage() -> Node3D:
	var stage := Node3D.new()
	stage.name = "ReferenceStage"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("20282b")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d7e0df")
	environment.ambient_light_energy = 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42.0, -34.0, 0.0)
	key.light_color = Color("ffe0b4")
	key.light_energy = 1.35
	key.shadow_enabled = true
	stage.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(22.0, 148.0, 0.0)
	fill.light_color = Color("9bbac8")
	fill.light_energy = 0.48
	stage.add_child(fill)
	return stage
