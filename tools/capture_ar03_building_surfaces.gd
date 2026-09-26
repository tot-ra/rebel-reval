extends SceneTree

## AR-03 (R-961) building surface evidence.
##
## WHY: AR-03 is a pure surface change (albedo + normal + ORM library and an
## anti-tiling detail blend), so review needs (1) a material line-up where every
## wall/roof family sits under the same light and (2) matched gameplay-scale
## street plates that can be captured before and after the change.
##
## Requires a rendering-capable run (no --headless):
##   tools/godot_render.sh --script tools/capture_ar03_building_surfaces.gd -- --label after
##   tools/godot_render.sh --script tools/capture_ar03_building_surfaces.gd \
##     -- --label after_no_antitiling --no-anti-tiling
## Add `--rendering-method gl_compatibility --rendering-driver opengl3` before
## `--script` for the Compatibility renderer.

const LowerTownSlice := preload(
	"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
)
const NorthQuarter := preload(
	"res://scripts/map/definitions/prototypes/north_quarter_definition.gd"
)
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")
const BuildingMaterials := preload("res://scripts/map/view3d/map_view_building_materials.gd")

const OUTPUT_DIR := "res://docs/reports/images"
const VIEWPORT_SIZE := Vector2i(1280, 720)
const WARMUP_FRAMES := 16

const WALL_FAMILIES: Array[StringName] = [
	&"limestone", &"plaster", &"timber", &"smoked_plaster", &"brick", &"plank", &"log",
]
const ROOF_FAMILIES: Array[StringName] = [&"tile", &"shingle", &"thatch", &"straw"]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var label := _arg_value(args, "--label", "after")
	# `before` runs execute against the pre-AR-03 script, which has no toggle.
	if args.has("--no-anti-tiling") and _has_static(BuildingMaterials, "set_anti_tiling_enabled"):
		var script: Script = BuildingMaterials
		script.call("set_anti_tiling_enabled", false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var error := await _capture_lineup(label)
	for map_entry in [
		{"id": "lower_town_slice", "definition": LowerTownSlice.create()},
		{"id": "north_quarter", "definition": NorthQuarter.create()},
	]:
		if error != OK:
			break
		var definition: MapDefinition = map_entry["definition"]
		var grid := MapBuilder.build(definition)
		for time in [MapView3D.TIME_DAY, MapView3D.TIME_NIGHT]:
			for pose in _street_poses(definition):
				error = await _capture_map(definition, grid, map_entry["id"], pose, time, label)
				if error != OK:
					break
	print("AR-03 captures (%s) written under %s" % [label, OUTPUT_DIR])
	quit(0 if error == OK else 1)


static func _has_static(script: Script, method: String) -> bool:
	for entry in script.get_script_method_list():
		if String(entry.get("name", "")) == method:
			return true
	return false


static func _arg_value(args: Array, flag: String, fallback: String) -> String:
	var index := args.find(flag)
	if index >= 0 and index + 1 < args.size():
		return String(args[index + 1])
	return fallback


## Street, gameplay-pitch and wide elevated poses aimed at an authored house
## that is built from procedural boxes (no house_tier), because tiered houses
## are kit GLBs whose surfaces AR-03 only re-roughens.
static func _street_poses(definition: MapDefinition) -> Array[Dictionary]:
	var focus := Vector3.ZERO
	var fallback := Vector3.ZERO
	for building in definition.buildings:
		var footprint: Rect2 = building.get("footprint", Rect2())
		var centre := footprint.get_center() / float(definition.cell_size)
		if fallback == Vector3.ZERO and building.has("wall_material"):
			fallback = Vector3(centre.x, 0.0, centre.y)
		if building.has("wall_material") and not building.has("house_tier"):
			focus = Vector3(centre.x, 0.0, centre.y)
			break
	if focus == Vector3.ZERO:
		focus = fallback
	return [
		{
			"id": "street",
			"eye": focus + Vector3(-3.0, 2.0, 11.0),
			"target": focus + Vector3(0.0, 2.2, 0.0),
			"fov": 58.0,
		},
		{"id": "gameplay", "eye": focus + Vector3(0.0, 20.0, 17.0), "target": focus, "fov": 45.0},
		{"id": "wide", "eye": focus + Vector3(-6.0, 38.0, 34.0), "target": focus, "fov": 50.0},
	]


func _capture_lineup(label: String) -> Error:
	var viewport := _viewport()
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.55, 0.6, 0.66)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.5, 0.52, 0.56)
	environment.environment.ambient_light_energy = 0.6
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	world.add_child(sun)
	sun.look_at_from_position(Vector3(4.0, 8.0, 10.0), Vector3.ZERO, Vector3.UP)
	var size := Vector3(3.0, 3.0, 0.2)
	var families: Array = []
	for family in WALL_FAMILIES:
		families.append({"family": family, "roof": false})
	for family in ROOF_FAMILIES:
		families.append({"family": family, "roof": true})
	var columns := 6
	for index in families.size():
		var entry: Dictionary = families[index]
		var slab := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = size
		slab.mesh = box
		var family: StringName = entry["family"]
		if entry["roof"]:
			var roof := MapViewMaterials.roof_surface_for_building(
				StringName("lineup.%s" % family), family, Color8(112, 83, 56)
			).duplicate() as StandardMaterial3D
			# Roofs carry world-unit densities for gabled meshes; convert them to the
			# BoxMesh 3 x 2 atlas so the slab shows the same cover scale.
			roof.uv1_scale = roof.uv1_scale * Vector3(3.0 * size.x, 2.0 * size.y, 1.0)
			slab.material_override = roof
		else:
			slab.material_override = MapViewMaterials.wall_surface_for_building(
				StringName("lineup.%s" % family), family, Color8(180, 157, 119), size
			)
		slab.position = Vector3(
			(index % columns - (columns - 1) * 0.5) * 3.4, 1.8 - float(index / columns) * 3.8, 0.0
		)
		world.add_child(slab)
		var tag := Label3D.new()
		tag.text = String(family)
		tag.font_size = 48
		tag.position = slab.position + Vector3(0.0, -1.75, 0.2)
		world.add_child(tag)
	var camera := Camera3D.new()
	camera.fov = 50.0
	world.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 0.0, 19.0), Vector3(0.0, 0.0, 0.0), Vector3.UP)
	camera.current = true
	return await _save(viewport, "%s/ar03_material_lineup_%s.png" % [OUTPUT_DIR, label])


func _capture_map(
	definition: MapDefinition,
	grid: Variant,
	map_id: String,
	pose: Dictionary,
	time: StringName,
	label: String
) -> Error:
	var viewport := _viewport()
	var view := MapView3D.create(definition, grid, time)
	viewport.add_child(view)
	var camera := Camera3D.new()
	camera.fov = float(pose["fov"])
	camera.near = 0.05
	camera.far = 400.0
	view.add_child(camera)
	camera.global_position = pose["eye"]
	camera.look_at(pose["target"], Vector3.UP)
	camera.current = true
	var output := "%s/ar03_%s_%s_%s_%s.png" % [OUTPUT_DIR, map_id, pose["id"], time, label]
	return await _save(viewport, output)


func _viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	return viewport


func _save(viewport: SubViewport, output: String) -> Error:
	for _frame in WARMUP_FRAMES:
		await process_frame
	var texture := viewport.get_texture()
	var error := ERR_CANT_CREATE
	if texture != null:
		error = texture.get_image().save_png(ProjectSettings.globalize_path(output))
	if error != OK:
		push_error("AR-03 capture failed for %s" % output)
	else:
		print("AR-03 capture: %s" % output)
	viewport.queue_free()
	await process_frame
	return error
