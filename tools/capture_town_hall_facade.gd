extends SceneTree

## Design-review capture for the Town Hall facade and its arcade gallery.
## Saves one PNG per camera under docs/reports/images/view3d/town_hall_review/.
## Requires a rendering-capable run (no --headless):
## godot --path . --script tools/capture_town_hall_facade.gd

const OUTPUT_DIR := "res://docs/reports/images/view3d/town_hall_review"
const VIEWPORT_SIZE := Vector2i(1280, 720)

## Building town_hall_mass sits at cells x 26..52, y 69..76 (1 cell = 1 world unit).
const FACADE_CENTER := Vector3(39.0, 2.0, 69.0)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
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
		"front": [Vector3(39.0, 4.5, 55.0), FACADE_CENTER],
		"angle": [Vector3(28.0, 5.5, 57.0), FACADE_CENTER],
		"close": [Vector3(45.0, 2.4, 63.5), FACADE_CENTER],
		"eye": [Vector3(36.0, 1.7, 66.6), FACADE_CENTER],
		"portal": [Vector3(39.0, 1.7, 65.2), Vector3(39.0, 1.5, 71.5)],
		"dimetric": [Vector3(30.0, 12.0, 58.0), Vector3(39.0, 2.0, 70.0)],
		"rear": [Vector3(44.0, 4.0, 84.0), Vector3(39.0, 2.0, 76.0)],
		"side": [Vector3(58.0, 4.0, 62.0), Vector3(50.0, 2.5, 72.0)],
	}
	for shot_name in shots:
		camera.position = shots[shot_name][0]
		camera.look_at(shots[shot_name][1], Vector3.UP)
		for frame in 8:
			await process_frame
		var image := viewport.get_texture().get_image()
		var output := "%s/town_hall_%s.png" % [OUTPUT_DIR, shot_name]
		var error := image.save_png(ProjectSettings.globalize_path(output))
		if error != OK:
			push_error("Could not save capture %s: %s" % [output, error_string(error)])
			quit(1)
			return
		print("capture: %s" % output)
	quit(0)
