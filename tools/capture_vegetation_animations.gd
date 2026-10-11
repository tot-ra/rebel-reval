extends SceneTree

## Animated evidence for docs/SYSTEMS/LIVING_VEGETATION.md: frame sequences that
## tools/build_vegetation_animations.sh turns into looping GIFs.
##
## Run: tools/godot_render.sh --script tools/capture_vegetation_animations.gd
##   [-- --only=storm,meadow,seasons]
## Frames go to build/veg_anim/<sequence>/NNN.png.
##
## Shader TIME cannot be pinned, so the wind sequences duplicate each material
## and swap TIME for a capture_time uniform (the R-1433 storm-capture trick):
## every frame is then a pure function of the frame index, not of how fast the
## minimized window happens to redraw.
## - storm: city spruce, oak and birch (real city wood + near crown) while the
##   wind ramps from calm to a storm gust and back.
## - meadow: city grass blades in front of a birch line, one gust front rolling
##   through the grass and then the crowns.
## - seasons: birch, oak, maple, apple and spruce on the 1st and 15th of every
##   month from April 1343 to March 1344 (VegetationPhenology, fruit included).

const WindMaterials := preload("res://scripts/map/view3d/map_view_wind_materials.gd")

const FRAMES_DIR := "res://build/veg_anim/"
const FPS := 12.0
const WIND := Vector2(1.0, 0.0)
const SUMMER := {"day": 15, "month": 7, "year": 1343}

var viewport: SubViewport
var _frozen: Array[ShaderMaterial] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var only := PackedStringArray()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",")
	if only.is_empty() or only.has("storm"):
		await storm()
	if only.is_empty() or only.has("meadow"):
		await meadow()
	if only.is_empty() or only.has("seasons"):
		await seasons()
	quit(0)


func storm() -> void:
	var stage := _begin(Vector2i(960, 540), Color("8d9ea8"))
	_ground(stage, Color("4f5634"))
	var row: Array[StringName] = [&"spruce", &"oak", &"birch"]
	for i in row.size():
		_city_tree(stage, row[i], Vector3((i - 1) * 10.0, 0.0, 0.0), 1.0)
	var camera := Camera3D.new()
	camera.fov = 40.0
	camera.position = Vector3(0.0, 5.5, 29.0)
	stage.add_child(camera)
	camera.look_at(Vector3(0.0, 5.0, 0.0))
	camera.current = true
	var frames := 72
	for frame in frames:
		# Calm -> storm -> calm over six seconds, so the bend is read against rest.
		var ramp := sin(PI * float(frame) / float(frames - 1))
		await _frame("storm", frame, float(frame) / FPS, lerpf(0.04, 0.85, ramp))
	_end()


func meadow() -> void:
	var stage := _begin(Vector2i(960, 480), Color("8e9ba3"))
	_ground(stage, Color("4a4f30"))
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for i in 16000:
		var x := MapViewMeshBuilderMath.hash01(i, 3, 991) * 34.0 - 12.0
		var z := MapViewMeshBuilderMath.hash01(i, 7, 997) * 16.0 - 12.0
		var scale := 0.7 + MapViewMeshBuilderMath.hash01(i, 11, 1009) * 0.6
		transforms.append(
			Transform3D(Basis(Vector3.UP, float(i)).scaled(Vector3.ONE * scale), Vector3(x, 0.0, z))
		)
		colors.append(Color.WHITE)
	var grass := MapViewMeshBuilderPrimitives.multi_mesh(
		"Meadow",
		MapViewFoliageMeshes.grass_blade_clump_mesh(),
		transforms,
		colors,
		_freeze(MapViewMaterials.grass_blade_tier(true)),
		Vector3.ZERO
	)
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.add_child(grass)
	for i in 4:
		_city_tree(stage, &"birch", Vector3(19.0 + i * 3.2, 0.0, -10.0 + (i % 2) * 2.5), 0.75)
	var camera := Camera3D.new()
	camera.fov = 55.0
	camera.position = Vector3(9.0, 1.7, 7.5)
	stage.add_child(camera)
	camera.look_at(Vector3(12.0, 1.4, -6.0))
	camera.current = true
	for frame in 60:
		await _frame("meadow", frame, float(frame) / FPS, 0.8)
	_end()


func seasons() -> void:
	var stage := _begin(Vector2i(1200, 470), Color("7f97a6"))
	var species: Array[StringName] = [&"birch", &"oak", &"maple", &"apple", &"spruce"]
	var dates: Array[Dictionary] = []
	for i in 12:
		var month := (i + 3) % 12 + 1
		var year := 1343 if month >= 4 else 1344
		for day in [1, 15]:
			dates.append({"day": day, "month": month, "year": year})
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.9
	camera.position = Vector3(0.0, 0.35, 24.0)
	stage.add_child(camera)
	camera.current = true
	var label := Label3D.new()
	label.font_size = 40
	label.pixel_size = 0.008
	label.outline_size = 8
	label.outline_modulate = Color("202527")
	label.no_depth_test = true
	label.position = Vector3(0.0, 2.75, 1.0)
	stage.add_child(label)
	MapViewMaterials.apply_world_wind(WIND, 0.0)
	for frame in dates.size():
		var trees := Node3D.new()
		stage.add_child(trees)
		for i in species.size():
			trees.add_child(_season_tree(species[i], dates[frame], Vector3((i - 2) * 3.6, 0.0, 0.0)))
		label.text = GameCalendar.format_date(dates[frame])
		await _settle()
		_save("seasons", frame)
		trees.queue_free()
	_end()


## City-scale wood and near crown, materials frozen to capture_time.
func _city_tree(stage: Node3D, species: StringName, at: Vector3, size: float) -> void:
	var scale := CityVegetationBuilder.species_scale(species, 1.0) * size
	var meshes: Array[Mesh] = [
		MapViewTreeMeshes.city_wood_mesh(
			species, scale, CityVegetationBuilder.trunk_factor(species, scale)
		),
		MapViewTreeMeshes.city_canopy_near_mesh(species, scale),
	]
	var materials: Array[ShaderMaterial] = [
		MapViewMaterials.bark_plate_wind(MapViewTreeSpecies.bark_plate_for(species), species),
		MapViewMaterials.canopy_for_species(species),
	]
	for i in 2:
		var material := _freeze(materials[i])
		if i == 1:
			# Full summer crown: the shared material carries whatever date was published last.
			WindMaterials._apply_season_to(material, species, SUMMER)
		var instance := MeshInstance3D.new()
		instance.mesh = meshes[i]
		instance.material_override = material
		instance.scale = Vector3.ONE * scale
		instance.position = at
		instance.extra_cull_margin = 12.0
		stage.add_child(instance)


## District crown with its season applied; same normalization as
## tools/capture_living_vegetation.gd (largest crown axis to a common size).
func _season_tree(species: StringName, date: Dictionary, at: Vector3) -> Node3D:
	var tree := Node3D.new()
	var scale_vec := MapViewTreeSpecies.instance_scale(MapViewTreeSpecies.SIZE_MEDIUM, 0.5)
	var canopy_mesh := MapViewMeshBuilderPrimitives.tree_canopy_mesh(species)
	var wood := MeshInstance3D.new()
	wood.mesh = MapViewMeshBuilderPrimitives.tree_wood_mesh(species)
	wood.material_override = MapViewMaterials.bark(MapViewTreeSpecies.bark_kind_for(species))
	wood.scale = scale_vec
	tree.add_child(wood)
	var material := MapViewMaterials.canopy_for_species(species).duplicate() as ShaderMaterial
	WindMaterials._apply_season_to(material, species, date)
	var canopy := MeshInstance3D.new()
	canopy.mesh = canopy_mesh
	canopy.material_override = material
	canopy.scale = scale_vec
	tree.add_child(canopy)
	var fruit_mesh := MapViewMeshBuilderPrimitives.tree_fruit_mesh(species)
	if fruit_mesh != null and bool(VegetationPhenology.state_for(species, date)["fruit_visible"]):
		var fruit := MeshInstance3D.new()
		fruit.mesh = fruit_mesh
		fruit.material_override = MapViewMaterials.tree_fruit()
		fruit.scale = scale_vec
		tree.add_child(fruit)
	var bounds := canopy_mesh.get_aabb()
	var largest_axis := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z)) * scale_vec.y
	var visual_scale := 3.3 / maxf(largest_axis, 0.01)
	tree.scale = Vector3.ONE * visual_scale
	tree.position = at + Vector3(0.0, -1.4 - bounds.position.y * visual_scale * scale_vec.y, 0.0)
	return tree


## Duplicates a material with TIME replaced by a settable capture_time uniform.
func _freeze(source: ShaderMaterial) -> ShaderMaterial:
	var material := source.duplicate() as ShaderMaterial
	var code := source.shader.code
	var declaration_end := code.find(";") + 1
	code = (
		code.substr(0, declaration_end)
		+ "\nuniform float capture_time = 0.0;"
		+ code.substr(declaration_end).replace("TIME", "capture_time")
	)
	var shader := Shader.new()
	shader.code = code
	material.shader = shader
	_frozen.append(material)
	return material


func _frame(sequence: String, frame: int, time: float, strength: float) -> void:
	MapViewMaterials.apply_world_wind(WIND, strength)
	for material in _frozen:
		material.set_shader_parameter("capture_time", time)
	await _settle()
	_save(sequence, frame)


func _begin(size: Vector2i, sky: Color) -> Node3D:
	viewport = SubViewport.new()
	viewport.size = size
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c4d0d4")
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0, -32.0, 0.0)
	sun.light_color = Color("fff0d4")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	stage.add_child(sun)
	return stage


func _ground(stage: Node3D, color: Color) -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120.0, 60.0)
	ground.mesh = plane
	var earth := StandardMaterial3D.new()
	earth.albedo_color = color
	earth.roughness = 1.0
	ground.material_override = earth
	ground.position = Vector3(4.0, -0.02, 0.0)
	stage.add_child(ground)


func _settle() -> void:
	for _i in 4:
		await process_frame
	await RenderingServer.frame_post_draw


func _save(sequence: String, frame: int) -> void:
	var dir := ProjectSettings.globalize_path(FRAMES_DIR).path_join(sequence)
	DirAccess.make_dir_recursive_absolute(dir)
	var image := viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	var path := dir.path_join("%03d.png" % frame)
	if image.save_png(path) != OK:
		push_error("Vegetation animation frame failed: %s" % path)
		quit(1)


func _end() -> void:
	_frozen.clear()
	viewport.queue_free()
