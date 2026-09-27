extends SceneTree

## R-285 / P4-023b evidence capture: day/night gameplay-scale shots of the
## Monastery District ordinary-fabric pass (Pikk/Lai strip plots, the
## north-east service lane, and the Vene edge beside the open precinct).
## Needs a real renderer, minimized through the wrapper:
##   tools/godot_render.sh --script tools/capture_monastery_fabric.gd

const MonasteryQuarterDefinition := preload(
	"res://scripts/map/definitions/prototypes/monastery_quarter_definition.gd"
)
const OUTPUT_DIR := "res://docs/reports/images/monastery_fabric"
const VIEWPORT_SIZE := Vector2i(1280, 720)
# Shot name -> [focus cell, camera offset in world units (1 unit = 1 cell)].
const SHOTS := {
	"pikk_north": [Vector2(96, 16), Vector3(26, 22, 30)],
	"service_lane": [Vector2(188, 14), Vector3(-18, 22, 32)],
	"vene_edge": [Vector2(150, 96), Vector3(-24, 24, -26)],
	"precinct_and_frontage": [Vector2(70, 40), Vector3(40, 46, 52)],
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var definition: MapDefinition = MonasteryQuarterDefinition.create()
	for time_of_day in MapView3D.ALL_TIMES:
		for shot_name in SHOTS:
			var error := await _capture(definition, time_of_day, shot_name)
			if error != OK:
				quit(1)
				return
	quit(0)


func _capture(definition: MapDefinition, time_of_day: StringName, shot_name: String) -> Error:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var view := MapView3D.create(definition, MapBuilder.build(definition), time_of_day)
	viewport.add_child(view)
	var shot: Array = SHOTS[shot_name]
	var focus_cell: Vector2 = shot[0]
	var focus := Vector3(focus_cell.x, 0.0, focus_cell.y)
	var camera := Camera3D.new()
	camera.fov = 50.0
	camera.far = 600.0
	viewport.add_child(camera)
	camera.position = focus + (shot[1] as Vector3)
	camera.look_at(focus)
	camera.make_current()

	for frame in 8:
		await process_frame
	var image := viewport.get_texture().get_image()
	var output := "%s/r285_%s_%s.png" % [OUTPUT_DIR, shot_name, time_of_day]
	var error := image.save_png(ProjectSettings.globalize_path(output))
	if error != OK:
		push_error("Could not save monastery capture %s: %s" % [output, error_string(error)])
	else:
		print("Monastery fabric capture: %s" % output)
	viewport.queue_free()
	await process_frame
	return error
