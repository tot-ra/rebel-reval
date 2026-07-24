extends SceneTree

## Reproducible P0-103 / P0-114 tree silhouette sheet. Renders every catalog species
## from procedural geometry only (no map scatter or gameplay placement).
## Run with a rendering-capable Godot process (no --headless):
## /Applications/Godot.app/Contents/MacOS/Godot --path . \
##   --script tools/capture_tree_reference_sheet.gd

const TreeSpecies := preload("res://scripts/map/view3d/map_view_tree_species.gd")

const OUTPUT := "res://docs/reports/images/fauna/p0_103_tree_reference_sheet.png"
const VIEWPORT_SIZE := Vector2i(2000, 1400)
const COLUMNS := 5
const CELL_SIZE := Vector2(3.2, 4.2)
const DISPLAY_TARGET := 3.6


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

	for index in TreeSpecies.ALL_SPECIES.size():
		var species: StringName = TreeSpecies.ALL_SPECIES[index]
		var column := index % COLUMNS
		var row := index / COLUMNS
		var origin := Vector3(
			(float(column) - float(COLUMNS - 1) * 0.5) * CELL_SIZE.x,
			(float((TreeSpecies.ALL_SPECIES.size() - 1) / COLUMNS) * 0.5 - float(row)) * CELL_SIZE.y,
			0.0
		)
		viewport.add_child(_tree_entry(species, origin))

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 16.5
	camera.position = Vector3(0.0, 1.2, 24.0)
	viewport.add_child(camera)
	camera.current = true
	camera.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)

	for _frame in 10:
		await process_frame
	var error := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT))
	if error != OK:
		push_error("Could not save tree reference sheet %s: %s" % [OUTPUT, error_string(error)])
		quit(1)
		return
	print("P0-103 tree reference sheet: %s" % OUTPUT)
	viewport.queue_free()
	quit(0)


func _tree_entry(species: StringName, origin: Vector3) -> Node3D:
	var root_3d := Node3D.new()
	root_3d.name = String(species).to_pascal_case()
	root_3d.position = origin

	var scale_vec := TreeSpecies.instance_scale(TreeSpecies.SIZE_MEDIUM, 0.5)
	var wood_mesh := MapViewMeshBuilderPrimitives.tree_wood_mesh(species)
	var canopy_mesh := MapViewMeshBuilderPrimitives.tree_canopy_mesh(species)

	var trunk := MeshInstance3D.new()
	trunk.name = "Trunk"
	trunk.mesh = wood_mesh
	trunk.material_override = MapViewMaterials.bark(TreeSpecies.bark_kind_for(species))
	trunk.scale = scale_vec
	root_3d.add_child(trunk)

	var canopy := MeshInstance3D.new()
	canopy.name = "Canopy"
	canopy.mesh = canopy_mesh
	canopy.material_override = MapViewMaterials.canopy(TreeSpecies.canopy_material_kind(species))
	canopy.scale = scale_vec
	root_3d.add_child(canopy)

	var fruit_mesh := MapViewMeshBuilderPrimitives.tree_fruit_mesh(species)
	if fruit_mesh != null:
		var fruit := MeshInstance3D.new()
		fruit.name = "Fruit"
		fruit.mesh = fruit_mesh
		fruit.scale = scale_vec
		root_3d.add_child(fruit)

	var bounds := canopy_mesh.get_aabb()
	var largest_axis := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z)) * scale_vec.y
	var visual_scale := DISPLAY_TARGET / maxf(largest_axis, 0.01)
	root_3d.scale = Vector3.ONE * visual_scale
	root_3d.position.y = 0.2 - bounds.position.y * visual_scale * scale_vec.y

	var label := Label3D.new()
	label.name = "Label"
	label.text = "tree.%s" % species
	label.font_size = 32
	label.modulate = Color("e9e2d2")
	label.outline_size = 5
	label.outline_modulate = Color("202527")
	label.position = Vector3(0.0, -0.35, 0.12)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	root_3d.add_child(label)
	return root_3d


func _build_stage() -> Node3D:
	var stage := Node3D.new()
	stage.name = "ReferenceStage"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("1e2628")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d2dbd8")
	environment.ambient_light_energy = 0.58
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	key.light_color = Color("ffe8c8")
	key.light_energy = 1.28
	key.shadow_enabled = true
	stage.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(18.0, 152.0, 0.0)
	fill.light_color = Color("9eb8c4")
	fill.light_energy = 0.42
	stage.add_child(fill)
	return stage
