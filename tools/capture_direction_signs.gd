extends SceneTree

## Focused evidence capture for extramural wooden direction signs on the Lower
## Town slice. Requires a rendering-capable run (no --headless):
## godot --path . --script tools/capture_direction_signs.gd

const LowerTownSliceDefinition := preload(
	"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
)
const OUTPUT_DIR := "res://docs/reports/images/view3d"
const VIEWPORT_SIZE := Vector2i(960, 720)
const FOCUS_SIZE := 18.0
const FOCUS_DISTANCE := 28.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	var view := MapView3D.create(definition, MapBuilder.build(definition), MapView3D.TIME_DAY)
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(view)
	var camera := view.view_camera()

	for index in definition.direction_signs.size():
		var sign: Dictionary = definition.direction_signs[index]
		var focus := view.world_position(sign["position"])
		camera.size = FOCUS_SIZE
		camera.position = focus + camera.transform.basis.z * FOCUS_DISTANCE
		camera.look_at(focus, Vector3.UP)
		for _frame in 4:
			await process_frame
		var slug := String(sign["text"]).strip_edges().replace(" ", "_")
		var output := "%s/direction_sign_%s_day.png" % [OUTPUT_DIR, slug]
		var error := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(output))
		if error != OK:
			push_error("Could not save direction sign capture %s: %s" % [output, error_string(error)])
			quit(1)
			return
		print("Direction sign capture: %s" % output)

	viewport.queue_free()
	quit(0)
