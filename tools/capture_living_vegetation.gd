extends SceneTree

## R-1187 living vegetation plate: species rows x campaign-date columns, so the
## seasonal crown (bud-burst, summer, autumn, bare) can be reviewed at a glance.
## Each cell duplicates the species canopy material because season uniforms are
## shared per species at runtime. Needs a real renderer (no --headless):
## tools/godot_render.sh --script tools/capture_living_vegetation.gd

const WindMaterials := preload("res://scripts/map/view3d/map_view_wind_materials.gd")

const OUTPUT := "res://docs/reports/images/vegetation/r1187_living_vegetation_seasons.png"
const VIEWPORT_SIZE := Vector2i(2000, 1500)
const SPECIES: Array[StringName] = [&"birch", &"oak", &"maple", &"apple", &"spruce"]
const DATES: Array[Dictionary] = [
	{"day": 21, "month": 4, "year": 1343},
	{"day": 20, "month": 5, "year": 1343},
	{"day": 15, "month": 7, "year": 1343},
	{"day": 5, "month": 10, "year": 1343},
	{"day": 15, "month": 1, "year": 1343},
]
const CELL_SIZE := Vector2(3.6, 3.9)
const DISPLAY_TARGET := 3.3


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
	for row in SPECIES.size():
		for column in DATES.size():
			var origin := Vector3(
				(float(column) - float(DATES.size() - 1) * 0.5) * CELL_SIZE.x,
				(float(SPECIES.size() - 1) * 0.5 - float(row)) * CELL_SIZE.y,
				0.0
			)
			viewport.add_child(_tree_entry(SPECIES[row], DATES[column], origin))
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 20.5
	camera.position = Vector3(0.0, 0.6, 24.0)
	viewport.add_child(camera)
	camera.current = true
	camera.look_at(Vector3(0.0, 0.4, 0.0), Vector3.UP)
	for _frame in 12:
		await process_frame
	var error := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT))
	if error != OK:
		push_error("Could not save %s: %s" % [OUTPUT, error_string(error)])
		quit(1)
		return
	print("R-1187 living vegetation plate: %s" % OUTPUT)
	viewport.queue_free()
	quit(0)


func _tree_entry(species: StringName, date: Dictionary, origin: Vector3) -> Node3D:
	var root_3d := Node3D.new()
	root_3d.position = origin
	var scale_vec := MapViewTreeSpecies.instance_scale(MapViewTreeSpecies.SIZE_MEDIUM, 0.5)
	var canopy_mesh := MapViewMeshBuilderPrimitives.tree_canopy_mesh(species)
	var trunk := MeshInstance3D.new()
	trunk.mesh = MapViewMeshBuilderPrimitives.tree_wood_mesh(species)
	trunk.material_override = MapViewMaterials.bark(MapViewTreeSpecies.bark_kind_for(species))
	trunk.scale = scale_vec
	root_3d.add_child(trunk)
	var material := MapViewMaterials.canopy_for_species(species).duplicate() as ShaderMaterial
	WindMaterials._apply_season_to(material, species, date)
	var canopy := MeshInstance3D.new()
	canopy.mesh = canopy_mesh
	canopy.material_override = material
	canopy.scale = scale_vec
	root_3d.add_child(canopy)
	var fruit_mesh := MapViewMeshBuilderPrimitives.tree_fruit_mesh(species)
	if fruit_mesh != null and bool(VegetationPhenology.state_for(species, date)["fruit_visible"]):
		var fruit := MeshInstance3D.new()
		fruit.mesh = fruit_mesh
		fruit.material_override = MapViewMaterials.tree_fruit()
		fruit.scale = scale_vec
		root_3d.add_child(fruit)
	var bounds := canopy_mesh.get_aabb()
	var largest_axis := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z)) * scale_vec.y
	var visual_scale := DISPLAY_TARGET / maxf(largest_axis, 0.01)
	root_3d.scale = Vector3.ONE * visual_scale
	root_3d.position.y += -1.4 - bounds.position.y * visual_scale * scale_vec.y
	var label := Label3D.new()
	label.text = "%s  %s" % [species, GameCalendar.format_date(date)]
	label.font_size = 28
	label.modulate = Color("e9e2d2")
	label.outline_size = 5
	label.outline_modulate = Color("202527")
	label.position = Vector3(0.0, -0.3, 0.12)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	root_3d.add_child(label)
	return root_3d


func _build_stage() -> Node3D:
	var stage := Node3D.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("7f97a6")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d2dbd8")
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42.0, -32.0, 0.0)
	key.light_color = Color("ffe8c8")
	key.light_energy = 1.3
	key.shadow_enabled = true
	stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(18.0, 152.0, 0.0)
	fill.light_color = Color("9eb8c4")
	fill.light_energy = 0.4
	stage.add_child(fill)
	return stage
