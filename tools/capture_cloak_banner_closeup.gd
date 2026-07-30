extends SceneTree

## Close-up of the smithy Black Cloaks wall banner after the vertical hang fix.
## Uses the smithy definition only (not MapAuditRegistry) so dirty distant maps
## cannot abort the plate.
##   GODOT_BIN=... $GODOT_BIN --path . --script tools/capture_cloak_banner_closeup.gd

const KalevSmithyDefinition := preload("res://scripts/map/definitions/lower_town/kalev_smithy_definition.gd")
const OUTPUT_PATH := "res://docs/reports/images/kalev_smithy_domestic_life/cloak_banner_closeup.png"
const VIEWPORT_SIZE := Vector2i(960, 960)
const SETTLE_FRAMES := 12


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var definition: MapDefinition = KalevSmithyDefinition.create()
	var banner_prop: Dictionary = {}
	for prop in definition.props:
		if prop.get("id", &"") == &"cloak_banner":
			banner_prop = prop
			break
	if banner_prop.is_empty():
		push_error("cloak_banner missing on kalev_smithy")
		quit(1)
		return

	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)

	var stage := Node3D.new()
	viewport.add_child(stage)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.12, 0.11, 0.10)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.68, 0.62)
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)

	var prop_root := MapViewMeshBuilder.build_prop(banner_prop, definition.cell_size, definition)
	# WHY: build_prop places the kit at map cell world coords; the close-up stage
	# needs the mount at the origin so the camera framing stays stable.
	prop_root.position = Vector3.ZERO
	prop_root.rotation = Vector3.ZERO
	stage.add_child(prop_root)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-38.0, 48.0, 0.0)
	light.light_energy = 1.25
	light.shadow_enabled = false
	stage.add_child(light)
	var fill := OmniLight3D.new()
	fill.position = Vector3(1.2, 1.9, 0.4)
	fill.light_energy = 0.7
	fill.omni_range = 6.0
	stage.add_child(fill)

	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 40.0
	# Pull back so the full vertical plate, top rod, and forked-tail swallow read.
	camera.position = Vector3(2.35, 1.70, 0.55)
	camera.look_at(Vector3(0.08, 1.60, 0.0), Vector3.UP)
	camera.current = true

	for _frame in SETTLE_FRAMES:
		await process_frame

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir()))
	var image := viewport.get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if error != OK:
		push_error("Could not save %s: %s" % [OUTPUT_PATH, error_string(error)])
		quit(1)
		return
	print("Cloak banner closeup: %s" % OUTPUT_PATH)
	quit(0)
