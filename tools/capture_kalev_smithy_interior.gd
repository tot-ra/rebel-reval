extends SceneTree

## Review captures for the authored Kalev smithy interior (R-SMITHY-INTERIOR).
## Renders the gameplay top-down frame plus close perspective shots of the forge
## bay, living bay, partition, and ceiling in day and night light.
##   tools/godot_render.sh --script tools/capture_kalev_smithy_interior.gd [-- --out=res://build/x]

const Registry := preload("res://scripts/map/map_audit_registry.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")
const DEFAULT_OUTPUT_DIR := "res://docs/reports/images/kalev_smithy_interior"
const MAP_ID := "kalev_smithy"
const VIEWPORT_SIZE := Vector2i(1280, 720)
## World units equal rrmap cells: forge bay x 15..25, living bay x 1..13,
## north wall z 0, courtyard door (12..14, 13).
const SHOTS: Array[Dictionary] = [
	{"id": "forge_bay", "eye": Vector3(15.8, 1.65, 11.6), "target": Vector3(20.5, 1.1, 2.0)},
	{"id": "forge_close", "eye": Vector3(17.2, 1.55, 7.2), "target": Vector3(20.5, 1.0, 1.6)},
	{"id": "tool_wall", "eye": Vector3(17.0, 1.6, 8.0), "target": Vector3(24.5, 1.4, 4.0)},
	{"id": "forge_to_door", "eye": Vector3(22.2, 1.65, 5.6), "target": Vector3(13.0, 1.0, 12.5)},
	{"id": "living", "eye": Vector3(13.2, 1.65, 11.6), "target": Vector3(4.0, 1.1, 3.0)},
	{"id": "living_to_forge", "eye": Vector3(2.0, 1.65, 6.5), "target": Vector3(20.0, 1.2, 4.0)},
	{"id": "ceiling", "eye": Vector3(9.0, 1.6, 7.5), "target": Vector3(15.0, 3.8, 5.0)},
	{"id": "third_person", "eye": Vector3(16.4, 3.2, 11.8), "target": Vector3(19.5, 0.6, 4.5)},
	{"id": "hearth_close", "eye": Vector3(21.2, 1.7, 5.4), "target": Vector3(20.3, 1.2, 1.8)},
	{"id": "anvil_close", "eye": Vector3(18.2, 1.45, 8.1), "target": Vector3(19.5, 0.65, 6.5)},
	{"id": "bellows_close", "eye": Vector3(15.6, 1.5, 4.6), "target": Vector3(17.9, 0.75, 2.4)},
	{"id": "bellows_side", "eye": Vector3(17.6, 1.25, 4.6), "target": Vector3(17.9, 0.7, 2.3)},
	{"id": "tool_wall_close", "eye": Vector3(22.6, 1.65, 4.6), "target": Vector3(25.0, 1.5, 3.0)},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_dir := DEFAULT_OUTPUT_DIR
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var definition: MapDefinition = Registry.by_id()[MAP_ID]
	for time_of_day in [MapView3D.TIME_DAY, MapView3D.TIME_NIGHT]:
		if await _capture_time(definition, time_of_day, output_dir) != OK:
			quit(1)
			return
	quit(0)


func _capture_time(definition: MapDefinition, time_of_day: StringName, output_dir: String) -> Error:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var view := MapView3D.create(definition, MapBuilder.build(definition), time_of_day)
	viewport.add_child(view)
	for _frame in 8:
		await process_frame
	var error := _save(viewport, "%s/overview_%s.jpg" % [output_dir, time_of_day])
	# Gameplay-scale orthographic crops of each bay at the shipped dimetric angle.
	var ortho := view.view_camera()
	for crop in [
		["topdown_forge", Vector3(19.5, 0.8, 7.0)], ["topdown_living", Vector3(7.0, 0.8, 7.0)]
	]:
		ortho.size = 11.0
		ortho.global_position = crop[1] + ortho.global_transform.basis.z * MapView3D.CAMERA_DISTANCE
		for _frame in 4:
			await process_frame
		_save(viewport, "%s/%s_%s.jpg" % [output_dir, crop[0], time_of_day])
	view.set_close_camera_mode(true)
	var camera := Camera3D.new()
	camera.fov = 70.0
	camera.near = 0.05
	viewport.add_child(camera)
	camera.make_current()
	for shot in SHOTS:
		camera.position = shot["eye"]
		camera.look_at(shot["target"], Vector3.UP)
		for _frame in 5:
			await process_frame
		var shot_error := _save(viewport, "%s/%s_%s.jpg" % [output_dir, shot["id"], time_of_day])
		if shot_error != OK:
			error = shot_error
	viewport.queue_free()
	await process_frame
	return error


func _save(viewport: SubViewport, output: String) -> Error:
	var image := viewport.get_texture().get_image()
	# JPEG keeps the committed evidence set small; review runs can use --out=.
	var error := image.save_jpg(ProjectSettings.globalize_path(output), 0.86)
	if error != OK:
		push_error("Could not save smithy capture %s: %s" % [output, error_string(error)])
	else:
		print("Smithy capture: %s" % output)
	return error
