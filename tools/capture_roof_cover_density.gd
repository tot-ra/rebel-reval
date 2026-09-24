extends SceneTree

## Isolated shingle and thatch roof-cover density evidence.
##
## WHY: production house GLBs hide the procedural Roof node, so a Lower Town
## street plate cannot show world-unit cover scale. These poses build ordinary
## houses without house_tier so the gabled mesh is the visible cover.
##
## Requires a rendering-capable run (no --headless):
##   /Applications/Godot.app/Contents/MacOS/Godot --path . \
##     --rendering-method gl_compatibility --rendering-driver opengl3 \
##     --script tools/capture_roof_cover_density.gd -- --label before

const OUTPUT_DIR := "res://docs/reports/images/roof_cover_density"
const VIEWPORT_SIZE := Vector2i(1280, 720)
const WARMUP_FRAMES := 24
const CELL_SIZE := 32
const HOUSE_FOOTPRINT := Rect2(0.0, 0.0, 256.0, 256.0)

const PRESETS: Array[Dictionary] = [
	{
		"id": "shingle_isolated",
		"family": &"shingle",
		"eye": Vector3(4.0, 8.2, -1.6),
		"target": Vector3(4.0, 5.0, 4.0),
		"fov": 46.0,
	},
	{
		"id": "shingle_isolated_oblique",
		"family": &"shingle",
		"eye": Vector3(9.4, 7.2, 0.8),
		"target": Vector3(4.0, 5.2, 4.0),
		"fov": 48.0,
	},
	{
		"id": "thatch_isolated",
		"family": &"thatch",
		"eye": Vector3(4.0, 8.6, -2.2),
		"target": Vector3(4.0, 5.4, 4.0),
		"fov": 46.0,
	},
	{
		"id": "thatch_isolated_oblique",
		"family": &"thatch",
		"eye": Vector3(9.8, 7.6, 0.4),
		"target": Vector3(4.0, 5.4, 4.0),
		"fov": 48.0,
	},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var label := _label_from_args(OS.get_cmdline_user_args())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for preset: Dictionary in PRESETS:
		var error := await _capture(preset, label)
		if error != OK:
			quit(1)
			return
	print("Roof cover captures (%s) written under %s" % [label, OUTPUT_DIR])
	quit(0)


static func _label_from_args(args: Array) -> String:
	var index := 0
	while index < args.size():
		if String(args[index]) == "--label" and index + 1 < args.size():
			return String(args[index + 1])
		index += 1
	return "after"


func _capture(preset: Dictionary, label: String) -> Error:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)

	var scene := Node3D.new()
	viewport.add_child(scene)
	_add_environment(scene)
	scene.add_child(_build_house(StringName(preset["family"])))

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = float(preset.get("fov", 48.0))
	camera.near = 0.05
	camera.far = 80.0
	scene.add_child(camera)
	camera.global_position = preset["eye"]
	camera.look_at(preset["target"], Vector3.UP)
	camera.current = true

	for _frame in WARMUP_FRAMES:
		await process_frame
	var texture := viewport.get_texture()
	if texture == null:
		push_error("Roof cover viewport has no texture for %s" % preset["id"])
		viewport.queue_free()
		await process_frame
		return ERR_CANT_CREATE
	var image := texture.get_image()
	if _is_blank(image):
		push_error("Roof cover capture is blank for %s" % preset["id"])
		viewport.queue_free()
		await process_frame
		return ERR_CANT_CREATE
	var output := "%s/%s_%s.png" % [OUTPUT_DIR, preset["id"], label]
	var error := image.save_png(ProjectSettings.globalize_path(output))
	if error != OK:
		push_error("Could not save roof cover capture %s: %s" % [output, error_string(error)])
	else:
		print("Roof cover capture: %s" % output)
	viewport.queue_free()
	await process_frame
	return error


func _build_house(family: StringName) -> Node3D:
	var building := {
		"id": StringName("capture.%s_house" % String(family)),
		"kind": MapTypes.BUILDING_KIND_HOUSE,
		"footprint": HOUSE_FOOTPRINT,
		"roof_material": family,
		"roof_color": Color8(111, 96, 69) if family == &"thatch" else Color8(56, 51, 43),
		"wall_material": &"log" if family == &"thatch" else &"plank",
		"wall_color": Color8(99, 89, 74),
		"wall_height": 112.0,
		"door_side": &"south",
	}
	return MapViewMeshBuilder.build_building(building, CELL_SIZE)


func _add_environment(scene: Node3D) -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color8(148, 168, 186)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color8(180, 184, 190)
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	scene.add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	sun.light_color = Color8(255, 236, 208)
	sun.light_energy = 0.95
	scene.add_child(sun)


static func _is_blank(image: Image) -> bool:
	if image == null:
		return true
	var sample := image.get_pixel(image.get_width() / 2, image.get_height() / 2)
	return sample.r + sample.g + sample.b < 0.02
