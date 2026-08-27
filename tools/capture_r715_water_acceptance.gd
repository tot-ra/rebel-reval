extends SceneTree

## R-756 fixed-setting water acceptance capture.
##
## This runner deliberately captures exactly one matrix plate per process. Run it
## with a display-capable renderer (Metal on macOS), never with --headless:
##   /Applications/Godot.app/Contents/MacOS/Godot --path . \
##     --rendering-method mobile --rendering-driver metal \
##     --script tools/capture_r715_water_acceptance.gd -- \
##     --map=reval_harbor_north --scenario=storm --time=night
##
## The manifest starts fail-closed with all plates blocked. A successful real
## renderer run changes only the selected plate to captured_pending_review;
## human visual review is still required before any plate can be accepted.

const MapAuditRegistry := preload("res://scripts/map/map_audit_registry.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapTypesContract := preload("res://scripts/map/map_types.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")
const SkyWeather3D := preload("res://scripts/map/view3d/sky_weather_3d.gd")

const CAPTURE_ID := "r715-water-acceptance-v1"
const OUTPUT_DIR := "res://docs/reports/images/r715_water"
const MANIFEST_PATH := OUTPUT_DIR + "/capture_manifest.json"
const VIEWPORT_SIZE := Vector2i(1280, 720)
const WARMUP_FRAMES := 16
const REQUIRED_SCENARIOS: Array[StringName] = [
	&"clear",
	&"overcast",
	&"rain",
	&"storm",
	&"post_rain",
]
const REQUIRED_TIMES: Array[StringName] = [MapView3D.TIME_DAY, MapView3D.TIME_NIGHT]
const REQUIRED_VISUAL_CHECKS: Array[String] = [
	"reflection_continuity",
	"wave_readability",
	"shoreline_grounding",
	"underwater_depth",
	"night_readability",
	"parity",
]

var _selection: Dictionary = {}
var _manifest: Dictionary = {}
var _definitions: Dictionary = {}


func _initialize() -> void:
	_selection = _capture_selection_from_args(OS.get_cmdline_user_args())
	if int(_selection["error"]) != OK:
		push_error(String(_selection["error_message"]))
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error(
			"R-756 requires a real renderer/Metal for water PNG readback; "
			+ "headless capture is deliberately rejected"
		)
		quit(2)
		return

	_manifest = _load_manifest()
	if _manifest.is_empty():
		quit(1)
		return
	_definitions = MapAuditRegistry.by_id()
	var map_id := String(_selection["map_id"])
	if not _definitions.has(map_id):
		push_error("R-756 water map is missing from MapAuditRegistry: %s" % map_id)
		quit(1)
		return

	var plate := _find_plate(
		map_id, String(_selection["scenario_id"]), String(_selection["time_of_day"])
	)
	if plate.is_empty():
		push_error("R-756 manifest has no selected plate")
		quit(1)
		return

	var result := await _capture_plate(_definitions[map_id], plate)
	if not bool(result.get("ok", false)):
		quit(1)
		return
	if _write_manifest() != OK:
		quit(1)
		return
	print("R715_WATER_PLATE_CAPTURED plate=%s" % plate["plate_id"])
	quit(0)


static func _capture_selection_from_args(args: Array) -> Dictionary:
	var selection := {
		"map_id": "",
		"scenario_id": "",
		"time_of_day": "",
		"error": OK,
		"error_message": "",
	}
	for raw_argument in args:
		var argument := String(raw_argument)
		if argument.begins_with("--map="):
			selection["map_id"] = argument.trim_prefix("--map=")
		elif argument.begins_with("--scenario="):
			selection["scenario_id"] = argument.trim_prefix("--scenario=")
		elif argument.begins_with("--time="):
			selection["time_of_day"] = argument.trim_prefix("--time=")
		else:
			selection["error"] = ERR_INVALID_PARAMETER
			selection["error_message"] = "Unknown R-756 capture argument: %s" % argument
			return selection
	if String(selection["map_id"]).is_empty():
		selection["error"] = ERR_INVALID_PARAMETER
		selection["error_message"] = "R-756 requires --map=<map_id>"
	elif not REQUIRED_SCENARIOS.has(StringName(selection["scenario_id"])):
		selection["error"] = ERR_INVALID_PARAMETER
		selection["error_message"] = "R-756 unknown --scenario: %s" % selection["scenario_id"]
	elif not REQUIRED_TIMES.has(StringName(selection["time_of_day"])):
		selection["error"] = ERR_INVALID_PARAMETER
		selection["error_message"] = "R-756 --time must be day or night"
	return selection


func _capture_plate(definition: MapDefinition, plate: Dictionary) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.name = "R756_%s" % String(plate["plate_id"]).replace("/", "_")
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)

	var grid := MapBuilder.build(definition)
	var time_of_day := StringName(plate["time_of_day"])
	var view := MapView3D.create(definition, grid, time_of_day)
	viewport.add_child(view)
	var camera := view.view_camera()
	camera.current = true
	var focus_cell := _first_water_cell(grid)
	var focus := view.world_position(Vector2(focus_cell) + Vector2(0.5, 0.5), 0.0)
	camera.position = focus + camera.transform.basis.z * MapView3D.CAMERA_DISTANCE
	camera.look_at(focus, Vector3.UP)

	var sky := view.sky_weather()
	if sky == null:
		return await _capture_failure(viewport, "R-756 map view has no SkyWeather3D")
	view.set_time_of_day(time_of_day)
	view.set_weather_time_scale(0.0)
	sky.auto_weather = false
	_prepare_weather(sky, StringName(plate["scenario_id"]))
	view.apply_cycle_progress(view.cycle_progress)
	for _frame in WARMUP_FRAMES:
		await process_frame

	var texture := viewport.get_texture()
	if texture == null:
		return await _capture_failure(viewport, "R-756 viewport has no texture")
	var image := texture.get_image()
	if image == null or image.get_size() != VIEWPORT_SIZE:
		return await _capture_failure(viewport, "R-756 PNG dimensions are not 1280x720")
	if _image_is_blank(image):
		return await _capture_failure(viewport, "R-756 water capture is blank")

	var output := String(plate["output"])
	var error := image.save_png(ProjectSettings.globalize_path(output))
	if error != OK:
		return await _capture_failure(
			viewport, "Could not save R-756 evidence: %s" % error_string(error)
		)
	_update_plate(
		plate,
		image,
		sky.presentation_snapshot(view.cycle_progress, _day_blend(time_of_day))
	)
	MapView3D._strip_geometry_materials(view)
	viewport.queue_free()
	await process_frame
	return {"ok": true}


func _prepare_weather(sky: SkyWeather3D, scenario_id: StringName) -> void:
	if scenario_id == &"post_rain":
		sky.set_weather(SkyWeather3D.WEATHER_RAIN)
		sky.advance(SkyWeather3D.TRANSITION_SECONDS)
		sky.set_weather(SkyWeather3D.WEATHER_CLEAR)
		sky.advance(SkyWeather3D.TRANSITION_SECONDS)
		return
	var weather_by_scenario := {
		&"clear": SkyWeather3D.WEATHER_CLEAR,
		&"overcast": SkyWeather3D.WEATHER_OVERCAST,
		&"rain": SkyWeather3D.WEATHER_RAIN,
		&"storm": SkyWeather3D.WEATHER_STORM,
	}
	sky.set_weather(weather_by_scenario[scenario_id])
	sky.advance(SkyWeather3D.TRANSITION_SECONDS)


func _update_plate(plate: Dictionary, image: Image, presentation: Variant) -> void:
	plate["status"] = "captured_pending_review"
	plate["renderer_observed"] = DisplayServer.get_name()
	plate["hardware_host"] = "%s/%s" % [OS.get_name(), Engine.get_architecture_name()]
	plate["sha256"] = _sha256_file(String(plate["output"]))
	plate["width"] = image.get_width()
	plate["height"] = image.get_height()
	plate["visual_checks"] = {}
	for check in REQUIRED_VISUAL_CHECKS:
		plate["visual_checks"][check] = "not_reviewed"
	plate["annotation"] = "Real-renderer PNG captured; human visual review is still required."
	plate["blockers"] = ["human visual review not performed"]
	plate["presentation"] = {
		"weather": String(presentation.weather),
		"wind_direction": [presentation.wind_direction.x, presentation.wind_direction.y],
		"wind_strength": presentation.wind_strength,
		"rain_intensity": presentation.rain_intensity,
		"puddle_wetness": presentation.puddle_wetness,
		"tide_level": presentation.tide_level,
		"sun_visibility": presentation.sun_visibility,
		"moon_visibility": presentation.moon_visibility,
		"star_visibility": presentation.star_visibility,
		"rain_suppressed": presentation.rain_suppressed,
	}
	_manifest["capture_status"] = "captured_pending_review"
	_manifest["commit"] = _git_head()
	_manifest["renderer_observed"] = DisplayServer.get_name()
	_manifest["hardware_host"] = "%s/%s" % [OS.get_name(), Engine.get_architecture_name()]


func _find_plate(map_id: String, scenario_id: String, time_of_day: String) -> Dictionary:
	for candidate: Dictionary in _manifest.get("plates", []):
		if (
			String(candidate.get("map_id", "")) == map_id
			and String(candidate.get("scenario_id", "")) == scenario_id
			and String(candidate.get("time_of_day", "")) == time_of_day
		):
			return candidate
	return {}


func _first_water_cell(grid: MapTerrainGrid) -> Vector2i:
	for y in grid.size_cells.y:
		for x in grid.size_cells.x:
			var cell := Vector2i(x, y)
			if MapTypesContract.WATER_TERRAINS.has(grid.get_terrain(cell)):
				return cell
	return Vector2i(grid.size_cells.x / 2, grid.size_cells.y / 2)


func _day_blend(time_of_day: StringName) -> float:
	return 1.0 if time_of_day == MapView3D.TIME_DAY else 0.0


func _image_is_blank(image: Image) -> bool:
	for byte_value: int in image.get_data():
		if byte_value != 0:
			return false
	return true


func _capture_failure(viewport: SubViewport, message: String) -> Dictionary:
	push_error(message)
	viewport.queue_free()
	await process_frame
	return {"ok": false}


func _load_manifest() -> Dictionary:
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		push_error("Cannot read R-756 manifest: %s" % MANIFEST_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Invalid R-756 manifest JSON")
		return {}
	return parsed


func _sha256_file(resource_path: String) -> String:
	var file := FileAccess.open(ProjectSettings.globalize_path(resource_path), FileAccess.READ)
	if file == null:
		return ""
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	while not file.eof_reached():
		hashing.update(file.get_buffer(1024 * 1024))
	return hashing.finish().hex_encode()


func _git_head() -> String:
	var output: Array[String] = []
	if OS.execute(
		"git", PackedStringArray(["rev-parse", "HEAD"]), output, true
	) == 0 and not output.is_empty():
		return output[0].strip_edges()
	return "unknown"


func _write_manifest() -> Error:
	var file := FileAccess.open(ProjectSettings.globalize_path(MANIFEST_PATH), FileAccess.WRITE)
	if file == null:
		push_error("Could not open R-756 manifest for writing: %s" % MANIFEST_PATH)
		return ERR_CANT_OPEN
	file.store_string(JSON.stringify(_manifest, "\t"))
	return OK
