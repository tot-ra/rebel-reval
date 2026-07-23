extends SceneTree

## P0-053 evidence capture: renders the playable slice maps through the 3D
## orthographic view layer and saves day/night PNGs under
## docs/reports/images/view3d/. Requires a rendering-capable run (no
## --headless): godot --path . --script tools/capture_map_view_3d.gd

const Registry := preload("res://scripts/map/map_audit_registry.gd")
const OUTPUT_DIR := "res://docs/reports/images/view3d"
const MAP_IDS: Array[String] = ["kalev_smithy", "lower_town_slice"]
const VIEWPORT_SIZE := Vector2i(1280, 720)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var definitions := Registry.by_id()
	for map_id in MAP_IDS:
		if not definitions.has(map_id):
			push_error("Unknown map id in 3D view capture: %s" % map_id)
			quit(1)
			return
		for time_of_day in MapView3D.ALL_TIMES:
			var error := await _capture(definitions[map_id], time_of_day)
			if error != OK:
				quit(1)
				return
	quit(0)


func _capture(definition: MapDefinition, time_of_day: StringName) -> Error:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var view := MapView3D.create(definition, MapBuilder.build(definition), time_of_day)
	viewport.add_child(view)

	for frame in 4:
		await process_frame
	var image := viewport.get_texture().get_image()
	var output := "%s/%s_%s.png" % [OUTPUT_DIR, definition.map_id, time_of_day]
	var error := image.save_png(ProjectSettings.globalize_path(output))
	if error != OK:
		push_error("Could not save 3D view capture %s: %s" % [output, error_string(error)])
	else:
		print("3D view capture: %s" % output)
	viewport.queue_free()
	await process_frame
	return error
