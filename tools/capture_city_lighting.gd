extends Node

## Before/after plates for the city lighting pass (R-1748, docs/SYSTEMS/POST_PROCESS.md):
## stands Kalev on Raekoja plats and in the forge street, pins a clear sky at 10h,
## at 18h and in the "after rain" state (clear sky, standing puddles, rain just
## stopped), and saves the third-person and painted-iso gameplay frames.
## Host scene so autoloads resolve:
##   tools/godot_render.sh --resolution 1600x900 res://tools/capture_city_lighting.tscn \
##     -- --tag=after [--states=h10,h18,after_rain] [--ao=0]
## Output: build/city_lighting/<state>_<spot>_<mode>_<tag>.jpg
## Night states: --states=h22,h23,dec_h17,dec_h20,dec_h23

const SCENE := preload("res://scenes/world/reval_city/reval_city.tscn")
const OUTPUT_DIR := "res://build/city_lighting"

## [id, hour, puddle wetness]. after_rain keeps the 10h sun so it pairs with h10.
const STATES := [
	["h10", 10.0, 0.0],
	["h18", 18.0, 0.0],
	["after_rain", 10.0, 0.85],
	# Night plates (R-NIGHT lighting): 22h is after the nine o'clock bell, 23h is deep night.
	["h22", 22.0, 0.0],
	["h23", 23.0, 0.0],
	# Winter plates: dark from 16h, so the households' evening lights, the watch's
	# lanterns and the moonlit snow all show (docs/SYSTEMS/NIGHT_LIGHTING.md).
	["dec_h17", 17.0, 0.0, {"year": 1343, "month": 12, "day": 15}],
	["dec_h20", 20.0, 0.0, {"year": 1343, "month": 12, "day": 15}],
	["dec_h23", 23.0, 0.0, {"year": 1343, "month": 12, "day": 15}],
]
## The slice's spring date, restored for states without their own.
const DEFAULT_DATE := {"year": 1343, "month": 4, "day": 23}

var city: Node
var _tag := "now"


func _ready() -> void:
	call_deferred("_run")


func _arg(prefix: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.trim_prefix(prefix)
	return fallback


## Holds the clock on `hour` while streaming, the follow glide and shadows settle.
func _settle(hour: float, frames: int) -> void:
	var runtime: MapViewRuntime = city.runtime
	for _i in frames:
		runtime.cycle_progress = hour / 24.0
		await get_tree().process_frame


func _forge_street(plan: CityPlan) -> Vector2:
	var hearth := CityTravel.spawn_position(plan, "kalev_smithy")
	var view: CityMapView = city.view
	for radius: float in [6.0, 8.0, 10.0, 12.0, 15.0, 18.0]:
		for step in 16:
			var angle := TAU * float(step) / 16.0
			var p := hearth + Vector2(cos(angle), sin(angle)) * radius
			if plan.site_at(p) != null:
				continue
			if not view.is_point_inside_occluder(Vector3(p.x, plan.ground_height(p) + 1.0, p.y)):
				return p
	return hearth


func _pin_weather(puddles: float) -> void:
	var sky: SkyWeather3D = city.world.sky_weather
	sky.auto_weather = false
	sky.time_scale = 0.0
	sky.set_weather(SkyWeather3D.WEATHER_CLEAR)
	sky.advance(SkyWeather3D.TRANSITION_SECONDS + 1.0)
	sky._puddle_wetness = puddles
	sky._ground_dryness = 0.0
	# A shower that just ended: the rainbow and wet-air rules see recent rain.
	sky._seconds_since_rain = 120.0 if puddles > 0.0 else SkyWeather3D.LAST_RAIN_NEVER


func _shot(at: Vector2, spot: String, state: Array) -> void:
	var runtime: MapViewRuntime = city.runtime
	city.player.global_position = CityPlan.to_logic(at)
	city.view.set_calendar_date(state[3] if state.size() > 3 else DEFAULT_DATE)
	for mode: Array in [
		[MapViewRuntimeCamera.CameraMode.THIRD_PERSON, "third"],
		[MapViewRuntimeCamera.CameraMode.PAINTED_ISO, "iso"],
	]:
		runtime.set_camera_mode(mode[0])
		_pin_weather(float(state[2]))
		await _settle(float(state[1]), 150)
		await RenderingServer.frame_post_draw
		var path := ProjectSettings.globalize_path(
			"%s/%s_%s_%s_%s.jpg" % [OUTPUT_DIR, state[0], spot, mode[1], _tag]
		)
		get_viewport().get_texture().get_image().save_jpg(path, 0.9)
		print("saved ", path)
		var env: Environment = city.world.environment
		print(
			"  env: exposure %.3f ambient %.3f %s sun %.3f fog %.4f bright %.3f" % [
				env.tonemap_exposure, env.ambient_light_energy, env.ambient_light_color,
				city.world.sun.light_energy, env.fog_density, env.adjustment_brightness
			]
		)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_tag = _arg("--tag=", "now")
	var only := _arg("--states=", "").split(",", false)
	city = SCENE.instantiate()
	add_child(city)
	await get_tree().process_frame
	await get_tree().process_frame
	# --ao=0 hides the screen-space AO pass for an in-build before/after.
	if _arg("--ao=", "1") == "0" and city.view.has_method(&"set_ambient_occlusion_enabled"):
		city.view.set_ambient_occlusion_enabled(false)
	await _settle(10.0, 120)
	var plan: CityPlan = city.plan
	var forum := CityTravel.spawn_position(plan, "poi.forum")
	var forge := _forge_street(plan)
	for state: Array in STATES:
		if not only.is_empty() and not String(state[0]) in only:
			continue
		await _shot(forum, "forum", state)
		await _shot(forge, "forge", state)
		# Night states also visit the Viru gate, where the night watch stands with lanterns.
		if float(state[1]) >= 17.0:
			await _shot(CityTravel.spawn_position(plan, "gate.viru"), "viru_gate", state)
	get_tree().quit(0)
