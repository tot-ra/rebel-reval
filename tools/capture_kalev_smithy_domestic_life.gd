extends SceneTree

## Day/night readability captures for the smithy domestic-life acceptance pass.
## Requires a rendering-capable Godot run (no --headless):
##   godot --path . --script tools/capture_kalev_smithy_domestic_life.gd

const Registry := preload("res://scripts/map/map_audit_registry.gd")
const OUTPUT_DIR := "res://docs/reports/images/kalev_smithy_domestic_life"
const MAP_ID := "kalev_smithy"
const VIEWPORT_SIZE := Vector2i(1280, 720)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var definitions := Registry.by_id()
	if not definitions.has(MAP_ID):
		push_error("Unknown map id for domestic-life capture: %s" % MAP_ID)
		quit(1)
		return
	for time_of_day in MapView3D.ALL_TIMES:
		var error := await _capture(definitions[MAP_ID], time_of_day)
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

	for _frame in 6:
		await process_frame
	var image := viewport.get_texture().get_image()
	var output := "%s/%s_%s.png" % [OUTPUT_DIR, definition.map_id, time_of_day]
	var error := image.save_png(ProjectSettings.globalize_path(output))
	if error != OK:
		push_error("Could not save domestic-life capture %s: %s" % [output, error_string(error)])
	else:
		print("Domestic-life capture: %s" % output)
	viewport.queue_free()
	await process_frame
	return error
