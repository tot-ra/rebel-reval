extends SceneTree

## River-current capture: renders the Pirita on viru_gate_foreland at several
## wall-clock moments so surface motion can be compared frame to frame.
##
## Two framings, because the two things the current has to show are separate:
## `reach` is a close straight stretch, where the ripple, sheen and foam travel
## must read downstream; `bend` sits on a meander, where the R-1160 follow-up has
## to turn that travel with the channel instead of running it across the banks.
##
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
const SHOT_INTERVAL_MSEC := 1200
## Mid-channel cells and the orthogonal camera height, in cells (the view camera
## is orthogonal, so zoom is camera.size; moving it along its axis changes
## nothing). The default size frames the whole 168x120 map, where a surface
## current is a few pixels wide; the Pirita channel itself is 19 cells.
const FRAMINGS: Array[Dictionary] = [
	{"name": "reach", "cell": Vector2(86.0, 54.0), "size": 26.0},
	{"name": "bend", "cell": Vector2(84.0, 92.0), "size": 50.0},
]


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
	# The weather clock would drift wind and sea state between shots, which would
	# muddle what the frame-to-frame difference proves; only the current moves.
	view.set_weather_time_scale(0.0)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for framing in FRAMINGS:
		var cell: Vector2 = framing["cell"]
		var focus := view.world_position(cell * float(definition.cell_size), 0.0)
		camera.size = float(framing["size"])
		camera.position = focus + camera.transform.basis.z * MapView3D.CAMERA_DISTANCE
		for _frame in WARMUP_FRAMES:
			await process_frame
		for shot in SHOT_COUNT:
			var image := viewport.get_texture().get_image()
			image.save_png(
				ProjectSettings.globalize_path(
					"%s/river_%s_%d.png" % [OUTPUT_DIR, framing["name"], shot]
				)
			)
			var until := Time.get_ticks_msec() + SHOT_INTERVAL_MSEC
			while Time.get_ticks_msec() < until:
				await process_frame
	quit(0)
