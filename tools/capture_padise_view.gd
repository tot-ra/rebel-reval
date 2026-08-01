extends SceneTree

## Scoped evidence capture for the Padise rework. Parses the .rrmap source
## directly instead of walking MapAuditRegistry so a dirty worktree elsewhere
## cannot abort the run. Requires a rendering-capable process:
##   godot --path . --rendering-driver metal --script tools/capture_padise_view.gd

const MAP_PATH := "res://content/maps/world_padise.rrmap"
const OUTPUT_DIR := "res://docs/reports/images/view3d"
const VIEWPORT_SIZE := Vector2i(1600, 900)

var _zoom := 1.45
var _focus := Vector3.ZERO
var _has_focus := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var parsed := MapRrmapParser.parse_file(MAP_PATH)
	if not parsed.is_ok():
		push_error(str(parsed.formatted_diagnostics()))
		quit(1)
		return
	var definition: MapDefinition = parsed.definition
	var suffix := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--suffix="):
			suffix = argument.trim_prefix("--suffix=")
		elif argument.begins_with("--zoom="):
			_zoom = float(argument.trim_prefix("--zoom="))
		elif argument.begins_with("--focus="):
			var parts := argument.trim_prefix("--focus=").split(",")
			if parts.size() == 2:
				_focus = Vector3(float(parts[0]), 0.0, float(parts[1]))
				_has_focus = true
	for time_of_day in [&"day"]:
		var error := await _capture(definition, time_of_day, suffix)
		if error != OK:
			quit(1)
			return
	quit(0)


func _capture(definition: MapDefinition, time_of_day: StringName, suffix: String) -> Error:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var view := MapView3D.create(definition, MapBuilder.build(definition), time_of_day)
	viewport.add_child(view)

	# The fitted gameplay camera crops a 100x60 map, so evidence plates widen it.
	var camera := view.view_camera()
	if camera != null:
		camera.size *= _zoom
		if _has_focus:
			# Re-aim along the existing isometric axis so close-ups keep the
			# shipped camera angle instead of inventing a new projection.
			camera.position = _focus + camera.transform.basis.z * 80.0
	# Fog of war is a screen-space post-process centred on the player; evidence
	# plates need the whole authored map, so it is hidden for the capture only.
	for child in view.get_children():
		if child is CanvasLayer or String(child.name).to_lower().contains("fog"):
			(child as Node).set("visible", false)
	for frame in 8:
		await process_frame
	var image := viewport.get_texture().get_image()
	var output := "%s/%s_%s%s.png" % [OUTPUT_DIR, definition.map_id, time_of_day, suffix]
	var error := image.save_png(ProjectSettings.globalize_path(output))
	if error != OK:
		push_error("Could not save Padise capture %s: %s" % [output, error_string(error)])
	else:
		print("Padise capture: %s" % output)
	viewport.queue_free()
	await process_frame
	return error
