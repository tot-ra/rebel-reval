extends SceneTree

## One portrait per plant model for the flora catalogue cards (R-1808,
## docs/FLORA/README.md): every tree species, every district plant and crop
## model and every city wild-plant model, each alone on a turf disc under the
## same soft studio light, in a three-quarter view framed to its bounds.
## Shrubs have no model of their own (city shrubs borrow tree meshes or the
## two cane models, district shrubs are not drawn), so their cards link the
## tree portraits and the vegetation plates instead.
##
## Needs a renderer:
##   tools/godot_render.sh --script tools/capture_flora_cards.gd \
##     [-- --only=trees|plants|forbs|grain]
## Output: docs/FLORA/images/<trees|herbs|crops>/<id>.jpg (900x900).

const TreeSpecies := preload("res://scripts/map/view3d/map_view_tree_species.gd")
const PlantSpecies := preload("res://scripts/map/view3d/map_view_plant_species.gd")
const PlantMeshes := preload("res://scripts/map/view3d/map_view_plant_meshes.gd")
const ForbMeshes := preload("res://scripts/city/city_forb_meshes.gd")
const GrainMeshes := preload("res://scripts/city/city_grain_meshes.gd")

const OUTPUT_DIR := "res://docs/FLORA/images"
const SIZE := Vector2i(900, 900)
const FOV := 32.0

var _only := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			_only = arg.substr(7)
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(_stage())
	var camera := Camera3D.new()
	camera.fov = FOV
	camera.far = 400.0
	viewport.add_child(camera)
	camera.current = true
	var failed := false
	if _only in ["", "trees"]:
		for species: StringName in TreeSpecies.ALL_SPECIES:
			failed = await _shoot(viewport, camera, _tree(species), "trees", String(species)) or failed
	if _only in ["", "plants"]:
		for species: StringName in PlantSpecies.ALL_SPECIES:
			# Forb species of blueprint maps draw the city models: shot below.
			if PlantSpecies.uses_forb_model(species):
				continue
			var plant := MeshInstance3D.new()
			plant.mesh = PlantMeshes.mesh_for(species)
			plant.material_override = MapViewMaterials.grass_blades()
			# Crops have their own catalogue list (variant crop.<species>).
			var group := "crops" if PlantSpecies.is_known_variant(StringName("crop." + species)) \
				else "herbs"
			failed = await _shoot(viewport, camera, plant, group, String(species)) or failed
	if _only in ["", "forbs"]:
		for kind: StringName in ForbMeshes.ALL_KINDS:
			var forb := MeshInstance3D.new()
			forb.mesh = ForbMeshes.mesh_for(kind)
			forb.material_override = CityForbs.material_unfaded()
			failed = await _shoot(viewport, camera, forb, "herbs", String(kind)) or failed
	if _only in ["", "grain"]:
		# City cereal clumps (R-2112): a small ripe stand, saved as <crop>_grain.
		for crop: StringName in GrainMeshes.ALL_CROPS:
			failed = await _shoot(viewport, camera, _grain_stand(crop), "crops", "%s_grain" % crop) or failed
	quit(1 if failed else 0)


## Three by three ripe CityGrainMeshes clumps on the field row grid.
func _grain_stand(crop: StringName) -> Node3D:
	var stand := Node3D.new()
	for i in 9:
		var clump := MeshInstance3D.new()
		clump.mesh = GrainMeshes.mesh_for(crop, GrainMeshes.STAGE_RIPE)
		clump.material_override = GrainMeshes.material(false)
		clump.position = Vector3(float(i % 3) * 0.55, 0.0, float(i / 3) * 0.8)
		clump.rotation.y = float(i) * 2.4
		stand.add_child(clump)
	return stand


## A tree as the district maps draw it (medium size): wood, crown, fruit.
func _tree(species: StringName) -> Node3D:
	var tree := Node3D.new()
	var scale := TreeSpecies.instance_scale(TreeSpecies.SIZE_MEDIUM, 0.5)
	var parts := [
		[MapViewMeshBuilderPrimitives.tree_wood_mesh(species),
			MapViewMaterials.bark(TreeSpecies.bark_kind_for(species))],
		[MapViewMeshBuilderPrimitives.tree_canopy_mesh(species),
			MapViewMaterials.canopy(TreeSpecies.canopy_material_kind(species))],
		[MapViewMeshBuilderPrimitives.tree_fruit_mesh(species), MapViewMaterials.tree_fruit()],
	]
	for part: Array in parts:
		if part[0] == null:
			continue
		var mesh := MeshInstance3D.new()
		mesh.mesh = part[0]
		mesh.material_override = part[1]
		mesh.scale = scale
		tree.add_child(mesh)
	return tree


## Frames `subject` from a three-quarter view a little above it and saves
## <group>/<id>.jpg. Returns true on failure.
func _shoot(
	viewport: SubViewport, camera: Camera3D, subject: Node3D, group: String, id: String
) -> bool:
	viewport.add_child(subject)
	var bounds := _bounds(subject)
	var centre := bounds.get_center()
	var reach := maxf(bounds.size.y, maxf(bounds.size.x, bounds.size.z)) * 0.62
	var distance := reach / tan(deg_to_rad(FOV * 0.5))
	var direction := Vector3(0.55, 0.42, 1.0).normalized()
	camera.look_at_from_position(centre + direction * distance, centre, Vector3.UP)
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var dir := "%s/%s" % [OUTPUT_DIR, group]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var path := "%s/%s.jpg" % [dir, id]
	var image := viewport.get_texture().get_image()
	var error := image.save_jpg(ProjectSettings.globalize_path(path), 0.86)
	subject.queue_free()
	if error != OK:
		push_error("could not save %s: %s" % [path, error_string(error)])
		return true
	print("captured %s" % path)
	return false


func _bounds(node: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for child in [node] + node.get_children():
		var mesh := child as MeshInstance3D
		if mesh == null or mesh.mesh == null:
			continue
		var box := mesh.transform * mesh.mesh.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out


func _stage() -> Node3D:
	var stage := Node3D.new()
	var environment := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, -35.0, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	stage.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80.0, 80.0)
	ground.mesh = plane
	var turf := StandardMaterial3D.new()
	turf.albedo_color = Color(0.30, 0.34, 0.17)
	turf.roughness = 1.0
	ground.material_override = turf
	stage.add_child(ground)
	return stage
