extends SceneTree

## CO-08 / R-955 sea-state evidence on Harbor North. Real renderer only:
##   tools/godot_render.sh --rendering-method mobile --rendering-driver metal \
##     --script tools/capture_co08_sea_states.gd -- --plate=storm
## Compatibility: --rendering-driver opengl3.
##
## Plates: calm, breeze, gale, storm, opposite, lee.
## Writes docs/reports/images/co08_<renderer>_<plate>.png

const MapAuditRegistry := preload("res://scripts/map/map_audit_registry.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")
const SkyWeather3D := preload("res://scripts/map/view3d/sky_weather_3d.gd")

const OUTPUT_DIR := "res://docs/reports/images"
const PLATE_SIZE := Vector2i(1280, 720)
const WARMUP_FRAMES := 90
const MAP_ID := "reval_harbor_north"
const ORTHO_SIZE := 33.75
const FOCUS := Vector2(80.5, 24.5)
const LEE_FOCUS := Vector2(70.0, 30.0)
const DATE := {"day": 21, "month": 6, "year": 1343}
const PLATES := {
	&"calm": {"weather": SkyWeather3D.WEATHER_CLEAR, "progress": 0.25, "focus": FOCUS},
	&"breeze": {"weather": SkyWeather3D.WEATHER_CLOUDY, "progress": 0.25, "focus": FOCUS},
	&"gale": {"weather": SkyWeather3D.WEATHER_OVERCAST, "progress": 0.25, "focus": FOCUS},
	&"storm": {"weather": SkyWeather3D.WEATHER_STORM, "progress": 0.25, "focus": FOCUS},
	&"opposite": {"weather": SkyWeather3D.WEATHER_RAIN, "progress": 0.0, "focus": FOCUS},
	&"lee": {"weather": SkyWeather3D.WEATHER_STORM, "progress": 0.25, "focus": LEE_FOCUS},
}

var _plate := &"storm"


func _initialize() -> void:
	for raw in OS.get_cmdline_user_args():
		var argument := String(raw)
		if argument.begins_with("--plate="):
			_plate = StringName(argument.trim_prefix("--plate="))
		else:
			push_error("CO-08 capture: unknown argument %s" % argument)
			quit(1)
			return
	if not PLATES.has(_plate):
		push_error("CO-08 capture: unknown plate %s" % _plate)
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("CO-08 capture needs a real renderer")
		quit(2)
		return
	var spec: Dictionary = PLATES[_plate]
	var definition: MapDefinition = MapAuditRegistry.by_id().get(MAP_ID)
	MapViewMaterials.WATER_MATERIALS.force_ocean_fft_support = true
	MapViewMaterials.reset()
	var viewport := SubViewport.new()
	viewport.size = PLATE_SIZE
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var grid := MapBuilder.build(definition)
	var view := MapView3D.create(definition, grid, MapView3D.TIME_DAY)
	viewport.add_child(view)
	var fog := view.find_child("FogOfWar", true, false) as Node3D
	if fog != null:
		fog.visible = false
	var sky := view.sky_weather()
	view.set_calendar_date(DATE)
	view.set_weather_time_scale(0.0)
	sky.auto_weather = false
	sky.set_weather(spec["weather"])
	sky.advance(SkyWeather3D.TRANSITION_SECONDS)
	var progress := float(spec["progress"])
	view.apply_cycle_progress(progress)
	var cell: Vector2 = spec["focus"]
	var target := view.world_position(cell * float(definition.cell_size), 0.0)
	var camera := view.view_camera()
	camera.current = true
	camera.size = ORTHO_SIZE
	camera.position = target + camera.transform.basis.z * MapView3D.CAMERA_DISTANCE
	for _frame in WARMUP_FRAMES:
		MapViewRuntimeEnvironment.set_ocean_time(6.0)
		view.apply_cycle_progress(progress)
		await process_frame
	await process_frame
	var image := viewport.get_texture().get_image()
	var renderer := RenderingServer.get_current_rendering_driver_name()
	var path := "%s/co08_%s_%s.png" % [OUTPUT_DIR, renderer, _plate]
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("CO-08 capture: could not save %s" % path)
		quit(1)
		return
	print(
		"CO08_CAPTURED %s wind=%s hs=%.2f onset=%.2f" % [
			path,
			sky.wind_direction_xz(),
			MapViewMaterials.WATER_MATERIALS.significant_wave_height_m(
				sky.wind_strength(), sky.rain_intensity()
			),
			float(
				MapViewMaterials.WATER_MATERIALS.fft_sea_state(
					sky.wind_strength(), sky.rain_intensity()
				)["whitecap_onset"]
			),
		]
	)
	quit(0)
