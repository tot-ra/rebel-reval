extends Node

## R-2150 review plates: open boats afloat off the fish landing in a rough sea.
## The sea must never show inside a hull (CityShips hull mask + sea ride) and
## the strake seams must not show water through the planking.
## Runs as a main scene: CityWorld3D names the DoorNavigator autoload, which
## does not compile under --script.
##   tools/godot_render.sh res://tools/capture_city_open_boats.tscn
##   [-- --out=res://build/open_boats] [-- --no-mask]

const VIEWPORT_SIZE := Vector2i(1600, 900)
const DAY_PROGRESS := 0.42
const WIND := 0.85
## Ocean seconds between the wave plates of one view.
const WAVE_STEPS: Array[float] = [0.0, 1.3, 2.9]
const SETTLE_FRAMES := 40

var _out := "res://build/open_boats"
## --no-mask: comparison plates with the hull sea mask cleared after CityShips.
var _no_mask := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg == "--no-mask":
			_no_mask = true
	# Runs after CityShips._process, so --no-mask wins over its mask push.
	process_priority = 100
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var plan := CityPlan.load_default()
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var world := CityWorld3D.create(plan)
	viewport.add_child(world)
	var camera := Camera3D.new()
	camera.far = 6000.0
	viewport.add_child(camera)
	camera.current = true
	world.setup_lighting(camera)
	world.apply_time(DAY_PROGRESS)
	var wind_dir := Vector2(0.4, -0.9)
	MapViewMaterials.apply_sea_weather(WIND, 0.0, wind_dir)
	MapViewMaterials.apply_world_wind(wind_dir, WIND)
	world.set_wind(wind_dir)
	var boat: Node3D = null
	for child in world.ships.get_children():
		if child.name.begins_with("Boat_") and child.position.y < 0.3:
			boat = child
			break
	if boat == null:
		push_error("no afloat open boat in CityShips")
		get_tree().quit(1)
		return
	var views := {
		"above": [Vector3(4.5, 5.0, 5.5), 50.0, Vector3(0, 0.4, 0)],
		"low": [Vector3(6.0, 1.6, 4.0), 45.0, Vector3(0, 0.3, 0)],
		"seams": [Vector3(0.6, 2.2, -0.2), 60.0, Vector3(0.6, 0.3, 1.0)],
	}
	MapViewRuntimeEnvironment.set_ocean_time(10.0)
	for view: String in views:
		var v: Array = views[view]
		camera.fov = v[1]
		for step in WAVE_STEPS.size():
			# Start early enough that the ride smoothing settles before the plate.
			MapViewRuntimeEnvironment.set_ocean_time(10.0 + WAVE_STEPS[step] - SETTLE_FRAMES / 60.0)
			for i in SETTLE_FRAMES:
				MapViewRuntimeEnvironment.advance_ocean_time(1.0 / 60.0)
				var base := boat.global_position
				var basis := boat.global_transform.basis
				camera.look_at_from_position(
					base + basis * (v[0] as Vector3), base + basis * (v[2] as Vector3), Vector3.UP
				)
				await get_tree().process_frame
			var tag := "_nomask" if _no_mask else ""
			var path := "%s/open_boat_%s_%d%s.png" % [_out, view, step, tag]
			viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
			var sea := CityShips.CityWaterSurfaceScript.sea_height(
				world, Vector2(boat.position.x, boat.position.z)
			)
			print("plate: %s heave=%.3f sea_at_centre=%.3f" % [path, boat.position.y, sea])
	# Cost of one ride update (four sea samples) for the perf budget.
	var hull: Dictionary = {}
	for h: Dictionary in world.ships._hulls:
		if h["node"] == boat:
			hull = h
	var t0 := Time.get_ticks_usec()
	for i in 50:
		world.ships._sample_ride(hull, boat, 0.0)
	print("ride_sea_usec_per_hull: %.1f" % ((Time.get_ticks_usec() - t0) / 50.0))
	get_tree().quit(0)


func _process(_delta: float) -> void:
	if _no_mask:
		CityShips._set_hull_masks(
			PackedVector4Array(), PackedVector4Array(), PackedVector4Array()
		)
