extends SceneTree

## Day/night readability captures for the smithy domestic-life acceptance pass.
## Requires a rendering-capable Godot run (no --headless):
##   godot --path . --script tools/capture_kalev_smithy_domestic_life.gd

const Registry := preload("res://scripts/map/map_audit_registry.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")
const MapViewBridge := preload("res://scripts/map/view3d/map_view_bridge.gd")
const OUTPUT_DIR := "res://docs/reports/images/kalev_smithy_domestic_life"
const FORGE_EVIDENCE_OUTPUT_DIR := "res://docs/reports/images/p0_102_environment_kit"
const MAP_ID := "kalev_smithy"
const VIEWPORT_SIZE := Vector2i(1280, 720)
## The evidence crop keeps the gameplay orthographic scale while centring the
## complete forge bay: furnace/anvil, player approach, and the courtyard door.
const FORGE_FOCUS_LOGIC := Vector2(17.5, 7.0)
const FORGE_CAMERA_SIZE := 13.5


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var forge_evidence := "--forge-evidence" in OS.get_cmdline_user_args()
	var output_dir := FORGE_EVIDENCE_OUTPUT_DIR if forge_evidence else OUTPUT_DIR
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var definitions := Registry.by_id()
	if not definitions.has(MAP_ID):
		push_error("Unknown map id for domestic-life capture: %s" % MAP_ID)
		quit(1)
		return
	for time_of_day in MapView3D.ALL_TIMES:
		var error := await _capture(definitions[MAP_ID], time_of_day, forge_evidence, output_dir)
		if error != OK:
			quit(1)
			return
	quit(0)


func _capture(
	definition: MapDefinition,
	time_of_day: StringName,
	forge_evidence: bool,
	output_dir: String
) -> Error:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var view := MapView3D.create(definition, MapBuilder.build(definition), time_of_day)
	viewport.add_child(view)
	if forge_evidence:
		_configure_forge_evidence_camera(view, definition)

	for _frame in 6:
		await process_frame
	var image := viewport.get_texture().get_image()
	var prefix: String = "forge" if forge_evidence else String(definition.map_id)
	var output := "%s/%s_%s.png" % [output_dir, prefix, time_of_day]
	var error := image.save_png(ProjectSettings.globalize_path(output))
	if error != OK:
		push_error("Could not save domestic-life capture %s: %s" % [output, error_string(error)])
	else:
		print("Domestic-life capture: %s" % output)
	viewport.queue_free()
	await process_frame
	return error


func _configure_forge_evidence_camera(view: MapView3D, definition: MapDefinition) -> void:
	var camera := view.view_camera()
	if camera == null or camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		push_error("Forge evidence requires MapView3D's orthographic camera")
		return
	camera.size = FORGE_CAMERA_SIZE
	var focus := MapViewBridge.logic_to_world(
		FORGE_FOCUS_LOGIC * float(definition.cell_size),
		definition.cell_size,
		0.8
	)
	# Preserve the shipped dimetric pitch/yaw and move along its own viewing axis;
	# a world-XZ offset would slide an orthographic isometric crop off the map.
	camera.global_position = focus + camera.global_transform.basis.z * MapView3D.CAMERA_DISTANCE
	camera.look_at(focus, Vector3.UP)
