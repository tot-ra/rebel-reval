extends SceneTree

## R-1120 review plates for the St Olaf 1343 exterior (`st_olaf_1343` renderer).
## Two sets:
## - studio: the church node alone (MapViewMeshBuilder.build_building) under a
##   plain sun and sky from four perspective angles, so massing, the unfinished
##   west tower, openings and wear can be judged without neighbours in the way;
## - in-map: monastery_quarter through the production MapView3D at the gameplay
##   orthographic camera, day and night.
## Requires a renderer (not --headless):
##   tools/godot_render.sh --script tools/capture_st_olaf_1343.gd

const MonasteryQuarterDefinition := preload(
	"res://scripts/map/definitions/prototypes/monastery_quarter_definition.gd"
)
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")
const MapViewBridge := preload("res://scripts/map/view3d/map_view_bridge.gd")
const CharacterScale := preload("res://assets/characters/shared/character_scale.gd")

const OUTPUT_DIR := "res://docs/reports/images/st_olaf_1343"
const LANDMARK_ID := &"st_olaf_silhouette"
const VIEWPORT_SIZE := Vector2i(1280, 720)
const WARMUP_FRAMES := 12
## Studio shots: [name, eye offset from the church centre in metres, look height].
## The long axis runs along X with the west tower at -X; the door faces +Z.
const SHOTS := [
	["south_west", Vector3(-24.0, 9.0, 26.0), 7.0],
	["south_east", Vector3(26.0, 6.0, 20.0), 7.0],
	["north_east", Vector3(24.0, 12.0, -24.0), 7.0],
	["north_west", Vector3(-26.0, 4.0, -18.0), 9.0],
	["street_south", Vector3(-2.0, 1.7, 14.0), 6.0],
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var definition: MapDefinition = MonasteryQuarterDefinition.create()
	var building := {}
	for candidate in definition.buildings:
		if candidate.get("id", &"") == LANDMARK_ID:
			building = candidate
	if building.is_empty():
		push_error("capture cannot find %s" % LANDMARK_ID)
		quit(1)
		return
	for shot: Array in SHOTS:
		if await _studio(building, definition.cell_size, shot) != OK:
			quit(1)
			return
	var center := MapViewBridge.logic_to_world(
		(building["footprint"] as Rect2).get_center(), definition.cell_size
	)
	for time_of_day: StringName in MapView3D.ALL_TIMES:
		if await _in_map(definition, time_of_day, center) != OK:
			quit(1)
			return
	quit(0)


func _studio(building: Dictionary, cell_size: int, shot: Array) -> int:
	var viewport := _viewport()
	var stage := Node3D.new()
	viewport.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_SKY
	environment.environment.sky = Sky.new()
	environment.environment.sky.sky_material = ProceduralSkyMaterial.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-38.0, -30.0, 0.0)
	stage.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120.0, 120.0)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.36, 0.33, 0.28)
	ground.material_override = ground_material
	stage.add_child(ground)
	var node := MapViewMeshBuilder.build_building(building, cell_size)
	stage.add_child(node)
	var center := node.position
	var camera := Camera3D.new()
	camera.fov = 50.0
	camera.far = 400.0
	stage.add_child(camera)
	camera.global_position = center + (shot[1] as Vector3)
	camera.look_at(center + Vector3(0.0, float(shot[2]), 0.0), Vector3.UP)
	camera.current = true
	return await _save(viewport, "studio_%s" % shot[0])


func _in_map(definition: MapDefinition, time_of_day: StringName, center: Vector3) -> int:
	var viewport := _viewport()
	var view := MapView3D.create(definition, MapBuilder.build(definition), time_of_day)
	view.activate_all_chunks()
	viewport.add_child(view)
	var camera := view.view_camera()
	camera.size = CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE
	camera.global_position = center + camera.global_transform.basis.z * MapView3D.CAMERA_DISTANCE
	camera.look_at(center, Vector3.UP)
	var error := await _save(viewport, "map_%s" % time_of_day)
	if is_instance_valid(view):
		MapView3D._strip_geometry_materials(view)
	return error


func _viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	return viewport


func _save(viewport: SubViewport, plate: String) -> int:
	for _frame in WARMUP_FRAMES:
		await process_frame
	var path := "%s/%s.png" % [OUTPUT_DIR, plate]
	var error := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("St Olaf 1343 plate: %s (%s)" % [path, error_string(error)])
	viewport.queue_free()
	await process_frame
	return error
