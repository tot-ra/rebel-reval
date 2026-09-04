extends SceneTree

## Temporary evidence capture for the reworked Saaremaa map. Needs a real
## rendering driver (metal), not --headless.

const OUTPUT := "res://docs/reports/images/view3d/_tmp_harbor_north_day.png"
const VIEWPORT_SIZE := Vector2i(1600, 900)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var parsed := MapRrmapParser.parse_file("res://content/maps/reval_harbor_north.rrmap")
	if not parsed.is_ok():
		for diagnostic in parsed.formatted_diagnostics():
			push_error(diagnostic)
		quit(1)
		return
	var definition: MapDefinition = parsed.definition
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://docs/reports/images/view3d")
	)
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var view := MapView3D.create(definition, MapBuilder.build(definition), &"day")
	viewport.add_child(view)
	for frame in 8:
		await process_frame
	var image := viewport.get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT))
	if error != OK:
		push_error("save failed: %s" % error_string(error))
		quit(1)
		return
	print("CAPTURE %s" % OUTPUT)
	quit(0)
