extends SceneTree

## River-current capture: renders the Pirita mid-reach on viru_gate_foreland at
## several wall-clock moments so surface motion can be compared frame to frame.
## Run with a real renderer, never --headless:
##   tools/godot_render.sh --rendering-method mobile --rendering-driver metal \
##     --script tools/capture_river_flow.gd

const MapAuditRegistry := preload("res://scripts/map/map_audit_registry.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")

const OUTPUT_DIR := "res://build/river_flow"
const VIEWPORT_SIZE := Vector2i(1280, 720)
const WARMUP_FRAMES := 16
const SHOT_COUNT := 3
const SHOT_INTERVAL_MSEC := 1500
const FOCUS_CELL := Vector2(77.0, 62.0)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var definition: MapDefinition = MapAuditRegistry.by_id()["viru_gate_foreland"]
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var view := MapView3D.create(definition, MapBuilder.build(definition), MapView3D.TIME_DAY)
	viewport.add_child(view)
	var camera := view.view_camera()
	camera.current = true
	var focus := view.world_position(FOCUS_CELL * float(definition.cell_size), 0.0)
	camera.position = focus + camera.transform.basis.z * (MapView3D.CAMERA_DISTANCE * 0.45)
	camera.look_at(focus, Vector3.UP)
	view.set_weather_time_scale(0.0)
	for _frame in WARMUP_FRAMES:
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for shot in SHOT_COUNT:
		var image := viewport.get_texture().get_image()
		image.save_png(ProjectSettings.globalize_path("%s/river_%d.png" % [OUTPUT_DIR, shot]))
		var until := Time.get_ticks_msec() + SHOT_INTERVAL_MSEC
		while Time.get_ticks_msec() < until:
			await process_frame
	quit(0)
