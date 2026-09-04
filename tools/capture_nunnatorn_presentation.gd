extends SceneTree

## R-628 evidence capture for the developer-only Nunnatorn presentation packet.
## Run with a real renderer, not --headless:
##   godot --path . --rendering-driver opengl3 --script tools/capture_nunnatorn_presentation.gd

const NunnatornDefinition := preload(
	"res://scripts/map/definitions/prototypes/nunnatorn_interior_definition.gd"
)
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")
const MapViewBridge := preload("res://scripts/map/view3d/map_view_bridge.gd")
const Presentation := preload("res://scripts/map/view3d/map_view_nunnatorn_interior.gd")

const OUTPUT_DIR := "res://docs/reports/images/nunnatorn"
const VIEWPORT_SIZE := Vector2i(1280, 720)
const FOCUS_CELL := Vector2(9.0, 9.5)
const FOCUS_HEIGHT := 0.8
const CAMERA_SIZE := 15.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var definition: MapDefinition = NunnatornDefinition.create()
	if definition.map_id != &"nunnatorn_interior":
		push_error("Unexpected Nunnatorn map id: %s" % definition.map_id)
		quit(1)
		return
	for time_of_day in MapView3D.ALL_TIMES:
		var error := await _capture(definition, time_of_day)
		if error != OK:
			quit(1)
			return
	print("R-628 Nunnatorn presentation captures written: %s" % OUTPUT_DIR)
	quit(0)


func _capture(definition: MapDefinition, time_of_day: StringName) -> Error:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var view := MapView3D.create(definition, MapBuilder.build(definition), time_of_day)
	viewport.add_child(view)
	var presentation := Presentation.install(view, definition)
	presentation.apply_cycle_progress(0.5 if time_of_day == MapView3D.TIME_DAY else 0.0)
	_configure_camera(view, definition)

	for _frame in 14:
		await process_frame
	var texture := viewport.get_texture()
	if texture == null:
		push_error("Nunnatorn presentation viewport has no texture for %s" % time_of_day)
		viewport.queue_free()
		await process_frame
		return ERR_CANT_CREATE
	var image := texture.get_image()
	var output := "%s/nunnatorn_%s.png" % [OUTPUT_DIR, time_of_day]
	var error := image.save_png(ProjectSettings.globalize_path(output))
	if error != OK:
		push_error("Could not save Nunnatorn presentation %s: %s" % [output, error_string(error)])
	else:
		print("Nunnatorn presentation: %s (%dx%d)" % [output, image.get_width(), image.get_height()])
	viewport.queue_free()
	await process_frame
	return error


func _configure_camera(view: MapView3D, definition: MapDefinition) -> void:
	var camera := view.view_camera()
	camera.size = CAMERA_SIZE
	var focus := MapViewBridge.logic_to_world(
		FOCUS_CELL * float(definition.cell_size), definition.cell_size, FOCUS_HEIGHT
	)
	camera.global_position = focus + camera.global_transform.basis.z * MapView3D.CAMERA_DISTANCE
	camera.look_at(focus, Vector3.UP)
