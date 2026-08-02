extends SceneTree

## P0-102m.2 evidence capture for the street/well environment-kit module.
## Requires a rendering-capable run (no --headless):
##   godot --path . --rendering-driver metal --script \
##     tools/capture_street_well_environment_kit.gd
##
## WHY: the acceptance needs a matched gameplay-scale pair for the authored
## cistern street node, rather than relying on a whole-district plate. The map
## and view remain authoritative; this script changes only the evidence camera.

const LowerTownSlice := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")
const MapViewBridge := preload("res://scripts/map/view3d/map_view_bridge.gd")

const OUTPUT_DIR := "res://docs/reports/images/p0_102_environment_kit"
const MAP_ID := "lower_town_slice"
const VIEWPORT_SIZE := Vector2i(1280, 720)
## Focus covers the authored cistern at x=104,y=60, its wash tub at x=102,y=61,
## the wet threshold, and the playable street approach toward street_start.
const STREET_WELL_FOCUS_CELL := Vector2(104.0, 60.5)
const STREET_WELL_FOCUS_HEIGHT := 0.8
const STREET_WELL_CAMERA_SIZE := 17.5


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var definition := LowerTownSlice.create()
	if definition.map_id != StringName(MAP_ID):
		push_error("Unexpected map id for street/well evidence capture: %s" % definition.map_id)
		quit(1)
		return
	for time_of_day in MapView3D.ALL_TIMES:
		var error := await _capture(definition, time_of_day)
		if error != OK:
			quit(1)
			return
	print(
		"P0-102m.2 street/well evidence written: %s/%s_{day,night}.png"
		% [OUTPUT_DIR, "street_well"]
	)
	quit(0)


func _capture(definition: MapDefinition, time_of_day: StringName) -> Error:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var view := MapView3D.create(definition, MapBuilder.build(definition), time_of_day)
	viewport.add_child(view)
	_configure_street_well_camera(view, definition)

	for _frame in 12:
		await process_frame
	var texture := viewport.get_texture()
	if texture == null:
		push_error("Street/well evidence viewport has no texture for %s" % time_of_day)
		viewport.queue_free()
		await process_frame
		return ERR_CANT_CREATE
	var image := texture.get_image()
	var output := "%s/street_well_%s.png" % [OUTPUT_DIR, time_of_day]
	var error := image.save_png(ProjectSettings.globalize_path(output))
	if error != OK:
		push_error("Could not save street/well evidence %s: %s" % [output, error_string(error)])
	else:
		print("Street/well evidence: %s (%dx%d)" % [output, image.get_width(), image.get_height()])
	viewport.queue_free()
	await process_frame
	return error


func _configure_street_well_camera(view: MapView3D, definition: MapDefinition) -> void:
	var camera := view.view_camera()
	if camera == null or camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		push_error("Street/well evidence requires MapView3D's orthographic camera")
		return
	camera.size = STREET_WELL_CAMERA_SIZE
	var focus := MapViewBridge.logic_to_world(
		STREET_WELL_FOCUS_CELL * float(definition.cell_size),
		definition.cell_size,
		STREET_WELL_FOCUS_HEIGHT
	)
	# Preserve the shipped dimetric pitch/yaw and move along its own viewing axis;
	# a world-XZ offset would slide an orthographic isometric crop off the map.
	camera.global_position = focus + camera.global_transform.basis.z * MapView3D.CAMERA_DISTANCE
	camera.look_at(focus, Vector3.UP)
