extends SceneTree

## Reproducible tree reference sheets from procedural geometry only (no map
## scatter or gameplay placement). Three sheets:
##   1. the P0-103 / P0-114 catalog sheet (every species, silhouette distance)
##   2. VEGR-6 (R-1324) silhouettes of the Weber-Penn species at true relative height
##   3. VEGR-6 close-ups of the same species, where crown clusters and the
##      branch structure under them have to be readable
##
## Run with a rendering-capable Godot process (no --headless):
## tools/godot_render.sh --script tools/capture_tree_reference_sheet.gd

const TreeSpecies := preload("res://scripts/map/view3d/map_view_tree_species.gd")
const TreeSkeleton := preload("res://scripts/map/view3d/tree_skeleton_weber_penn.gd")

const CATALOG_OUTPUT := "res://docs/reports/images/fauna/p0_103_tree_reference_sheet.png"
const SILHOUETTE_OUTPUT := "res://docs/reports/images/vegetation/r1324_tree_silhouettes_after.png"
const WOOD_OUTPUT := "res://docs/reports/images/vegetation/tree_wood_branch_flow.png"
const CLOSEUP_OUTPUT := "res://docs/reports/images/vegetation/r1324_tree_closeups_after.png"
## Species shown on the Weber-Penn sheets. Every species now has a preset.
const PRESET_SPECIES: Array[StringName] = TreeSpecies.ALL_SPECIES
## Bare-wood sheet: the branch architecture that tells the species apart
## (forks, multi-stem stools, scaffold limbs, ascending vs drooping shoots).
const WOOD_SPECIES: Array[StringName] = [
	&"pine", &"oak", &"apple", &"pear", &"ash", &"elm", &"willow", &"hazel", &"blackthorn",
]


var _wood_only := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# Catalog sheet: every species normalised to the same display height, so the
	# comparison is of shape, not of size.
	var failed := await _capture(
		CATALOG_OUTPUT,
		TreeSpecies.ALL_SPECIES,
		5,
		Vector2i(2000, 1500),
		Vector2(3.4, 4.6),
		21.0,
		0.0
	)
	# VEGR-6 silhouettes: true relative heights (a pine towers over a juniper).
	failed = (
		await _capture(
			SILHOUETTE_OUTPUT,
			PRESET_SPECIES,
			5,
			Vector2i(2000, 1700),
			Vector2(3.4, 5.0),
			23.4,
			1.0
		)
		or failed
	)
	# VEGR-6 close-ups: the crown fills the cell, clusters and limbs readable.
	failed = (
		await _capture(
			CLOSEUP_OUTPUT,
			PRESET_SPECIES,
			5,
			Vector2i(2300, 2000),
			Vector2(4.6, 5.0),
			23.0,
			0.0
		)
		or failed
	)
	# Bare wood: limb curvature and the collars where branches leave the parent.
	_wood_only = true
	failed = (
		await _capture(
			WOOD_OUTPUT,
			WOOD_SPECIES,
			3,
			Vector2i(1800, 1800),
			Vector2(4.6, 5.0),
			16.4,
			0.0
		)
		or failed
	)
	quit(1 if failed else 0)


## `natural_scale` 0 normalises every tree to one display height (shape
## comparison), 1 keeps the species' own proportions (size comparison).
func _capture(
	output: String,
	species_list: Array,
	columns: int,
	viewport_size: Vector2i,
	cell: Vector2,
	camera_size: float,
	natural_scale: float
) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(_build_stage())

	var rows := int(ceil(float(species_list.size()) / float(columns)))
	var tallest := 0.0
	for species: StringName in species_list:
		tallest = maxf(tallest, _display_height(species))
	for index in species_list.size():
		var species: StringName = species_list[index]
		var column := index % columns
		var row := index / columns
		var origin := Vector3(
			(float(column) - float(columns - 1) * 0.5) * cell.x,
			# Leaves room under the bottom row for its labels.
			(float(rows - 1) * 0.5 - float(row)) * cell.y - cell.y * 0.12,
			0.0
		)
		# Normalised sheets give every tree the same drawn height; natural sheets
		# scale the whole row against the tallest species in the list.
		var target := lerpf(cell.y * 0.78, cell.y * 0.86 * _display_height(species) / tallest,
			natural_scale)
		viewport.add_child(_tree_entry(species, origin, target))

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = camera_size
	camera.position = Vector3(0.0, 0.0, 24.0)
	viewport.add_child(camera)
	camera.current = true
	camera.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)

	for _frame in 10:
		await process_frame
	var error := viewport.get_texture().get_image().save_png(
		ProjectSettings.globalize_path(output)
	)
	viewport.queue_free()
	if error != OK:
		push_error("Could not save tree sheet %s: %s" % [output, error_string(error)])
		return true
	print("Tree reference sheet: %s" % output)
	return false


## Drawn height of a species before sheet scaling, in shared-mesh units.
func _display_height(species: StringName) -> float:
	var bounds := MapViewMeshBuilderPrimitives.tree_canopy_mesh(species).get_aabb()
	return maxf(bounds.end.y * TreeSpecies.instance_scale(TreeSpecies.SIZE_MEDIUM, 0.5).y, 0.01)


func _tree_entry(species: StringName, origin: Vector3, display_target: float) -> Node3D:
	var root_3d := Node3D.new()
	root_3d.name = String(species).to_pascal_case()

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
	canopy.visible = not _wood_only
	canopy.name = "Canopy"
	canopy.mesh = canopy_mesh
	canopy.material_override = MapViewMaterials.canopy(TreeSpecies.canopy_material_kind(species))
	canopy.scale = scale_vec
	root_3d.add_child(canopy)

	var fruit_mesh := MapViewMeshBuilderPrimitives.tree_fruit_mesh(species)
	if fruit_mesh != null:
		var fruit := MeshInstance3D.new()
		fruit.name = "Fruit"
		fruit.visible = not _wood_only
		fruit.mesh = fruit_mesh
		# Vertex-coloured fruit material; without it the fruit drew as grey diamonds.
		fruit.material_override = MapViewMaterials.tree_fruit()
		fruit.scale = scale_vec
		root_3d.add_child(fruit)

	# Scale the whole tree to the cell, then stand it on the cell's baseline.
	# (The old sheet overwrote position.y here, which stacked every row on one line.)
	var bounds := canopy_mesh.get_aabb().merge(wood_mesh.get_aabb())
	var drawn_height := maxf(bounds.end.y * scale_vec.y, 0.01)
	var visual_scale := display_target / drawn_height
	root_3d.scale = Vector3.ONE * visual_scale
	root_3d.position = origin + Vector3.UP * (-bounds.position.y * scale_vec.y * visual_scale)

	var label := Label3D.new()
	label.name = "Label"
	label.text = "tree.%s" % species
	label.font_size = 30
	label.modulate = Color("e9e2d2") if TreeSkeleton.has_preset(species) else Color("9aa39f")
	label.outline_size = 5
	label.outline_modulate = Color("202527")
	# Label sits just under the trunk base, in sheet space (undo the tree scale).
	label.scale = Vector3.ONE / visual_scale
	label.position = Vector3(0.0, -0.3 / visual_scale, 0.12 / visual_scale)
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
