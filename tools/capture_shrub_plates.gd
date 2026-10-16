extends SceneTree

## Plates for the dedicated cane shrubs (R-2125): a species lineup in June and a
## four-season plate (spring, summer, autumn, winter) of three species, drawn
## exactly as CityVegetationBuilder.build_bushes draws them (cane mesh with the
## proxy species' canopy material, plus the dated flower and fruit meshes).
##
## Needs a renderer:
##   tools/godot_render.sh --script tools/capture_shrub_plates.gd
## Output: docs/reports/images/vegetation/shrubs_lineup.jpg and
## shrubs_season_<spring|summer|autumn|winter>.jpg (1600x700).

const BushMeshes := preload("res://scripts/map/view3d/map_view_bush_meshes.gd")
const OUTPUT_DIR := "res://docs/reports/images/vegetation"
const SIZE := Vector2i(1600, 700)
const LINEUP: Array[StringName] = [
	&"dog_rose", &"raspberry", &"elder", &"guelder_rose", &"willow_shrub",
	&"alder_shrub", &"spindle", &"sea_buckthorn", &"juniper_shrub",
]
const SEASON_SPECIES: Array[StringName] = [&"elder", &"guelder_rose", &"sea_buckthorn"]
const SEASONS := {
	"spring": {"day": 20, "month": 4, "year": 1343},
	"summer": {"day": 15, "month": 6, "year": 1343},
	"autumn": {"day": 5, "month": 10, "year": 1343},
	"winter": {"day": 15, "month": 1, "year": 1343},
}
const LINEUP_DATE := {"day": 25, "month": 8, "year": 1343}


func _initialize() -> void:
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
	camera.fov = 30.0
	camera.far = 200.0
	viewport.add_child(camera)
	camera.current = true
	await _shoot(viewport, camera, LINEUP, LINEUP_DATE, "shrubs_lineup", 2.8)
	for season: String in SEASONS:
		await _shoot(
			viewport, camera, SEASON_SPECIES, SEASONS[season], "shrubs_season_%s" % season, 3.0
		)
	quit(0)


func _shoot(
	viewport: SubViewport, camera: Camera3D, species_list: Array[StringName], date: Dictionary,
	id: String, spacing: float
) -> void:
	MapViewMaterials.apply_vegetation_season(date)
	var holder := Node3D.new()
	viewport.add_child(holder)
	var width := spacing * float(species_list.size() - 1)
	for i in species_list.size():
		var species := species_list[i]
		var size_m: Vector2 = CityVegetationBuilder.BUSH_SIZE_M[species]
		var shrub := Node3D.new()
		shrub.position = Vector3(float(i) * spacing - width * 0.5, 0.0, 0.0)
		holder.add_child(shrub)
		var leaves := MeshInstance3D.new()
		leaves.mesh = BushMeshes.city_mesh_for(species, size_m)
		leaves.material_override = MapViewMaterials.canopy_for_species(BushMeshes.city_leaf_proxy(species))
		shrub.add_child(leaves)
		for kind: StringName in [&"flower", &"fruit"]:
			if BushMeshes.has_adornment(species, kind):
				var extra := MeshInstance3D.new()
				extra.mesh = BushMeshes.city_adornment_mesh(species, size_m, kind)
				extra.material_override = BushMeshes.adornment_material(species, kind)
				shrub.add_child(extra)
	camera.look_at_from_position(
		Vector3(0.0, 1.9, (width * 0.5 + spacing * 0.7) / 0.6), Vector3(0.0, 1.0, 0.0), Vector3.UP
	)
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var path := "%s/%s.jpg" % [OUTPUT_DIR, id]
	viewport.get_texture().get_image().save_jpg(ProjectSettings.globalize_path(path), 0.88)
	print("captured %s" % path)
	holder.queue_free()


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
