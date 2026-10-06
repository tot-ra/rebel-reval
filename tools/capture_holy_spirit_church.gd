extends SceneTree

## Design-review capture for the Holy Spirit chapel and the ground around it
## (dirt close, street cobbles). Saves one PNG per camera.
## Requires a rendering-capable run (no --headless):
## tools/godot_render.sh --script tools/capture_holy_spirit_church.gd -- [out_dir]

const DEFAULT_OUTPUT_DIR := "res://docs/reports/images/view3d/holy_spirit_church"
const VIEWPORT_SIZE := Vector2i(1280, 720)

## Building church_silhouette sits at cells x 45..59, y 3..13 (1 cell = 1 world unit).
const FACADE_CENTER := Vector3(52.0, 3.0, 13.0)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var output_dir: String = args[0] if args.size() > 0 else DEFAULT_OUTPUT_DIR
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var definition: MapDefinition = MarketCivicQuarterDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)

	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var view := MapView3D.create(definition, grid, MapView3D.TIME_DAY)
	viewport.add_child(view)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 55.0
	camera.near = 0.05
	viewport.add_child(camera)
	camera.make_current()

	var shots := {
		"front": [Vector3(52.0, 5.0, 30.0), FACADE_CENTER],
		"angle": [Vector3(38.0, 6.0, 26.0), Vector3(52.0, 3.0, 8.0)],
		"eye": [Vector3(47.0, 1.7, 21.0), Vector3(53.0, 3.0, 12.0)],
		"dimetric": [Vector3(36.0, 16.0, 34.0), Vector3(52.0, 1.0, 14.0)],
		"east": [Vector3(70.0, 5.0, 22.0), Vector3(55.0, 3.0, 8.0)],
		"ground": [Vector3(50.0, 2.2, 24.0), Vector3(52.0, 0.0, 17.0)],
		"cobble": [Vector3(38.0, 1.7, 8.0), Vector3(40.0, 0.0, 14.0)],
		"cobble_low": [Vector3(44.0, 0.9, 20.0), Vector3(40.0, 0.0, 22.5)],
	}
	for shot_name in shots:
		camera.position = shots[shot_name][0]
		camera.look_at(shots[shot_name][1], Vector3.UP)
		for frame in 8:
			await process_frame
		var image := viewport.get_texture().get_image()
		var output := "%s/holy_spirit_%s.png" % [output_dir, shot_name]
		var error := image.save_png(ProjectSettings.globalize_path(output))
		if error != OK:
			push_error("Could not save capture %s: %s" % [output, error_string(error)])
			quit(1)
			return
		print("capture: %s" % output)
	quit(0)
