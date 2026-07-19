extends SceneTree

## Temporary evidence capture for the Kalev smithy first-person start view.
## Renders the smithy interior from the player spawn at four yaws and saves
## PNGs. Run: godot --path . --script tools/capture_kalev_smithy_fp.gd

const OUTPUT_DIR := "res://docs/reports/images/view3d/smithy_fp"
const VIEWPORT_SIZE := Vector2i(1280, 720)
const EYE_HEIGHT := 1.65
## 45 first: the gameplay camera starts at MapView3D.CAMERA_YAW_DEGREES, so the
## yaw-45 frame is the player's actual first look.
const YAWS: Array[float] = [45.0, 0.0, 90.0, 180.0, 270.0]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var definition: MapDefinition = KalevSmithyDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)

	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var view := MapView3D.create(definition, grid, MapView3D.TIME_DAY)
	viewport.add_child(view)
	view.set_interior_shell_for_first_person(true)

	var spawn_center := definition.player_spawn
	var scale := MapViewBridge.world_scale(definition.cell_size)
	var eye := Vector3(spawn_center.x * scale, EYE_HEIGHT, spawn_center.y * scale)
	print("spawn logic px: %s -> world eye %s" % [spawn_center, eye])

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 75.0
	camera.near = 0.05
	camera.position = eye
	viewport.add_child(camera)
	camera.make_current()

	for yaw in YAWS:
		camera.rotation_degrees = Vector3(-10.0, yaw, 0.0)
		for frame in 6:
			await process_frame
		var image := viewport.get_texture().get_image()
		var output := "%s/smithy_fp_yaw%03d.png" % [OUTPUT_DIR, int(yaw)]
		var error := image.save_png(ProjectSettings.globalize_path(output))
		if error != OK:
			push_error("Could not save capture %s: %s" % [output, error_string(error)])
			quit(1)
			return
		print("capture: %s" % output)
	quit(0)
