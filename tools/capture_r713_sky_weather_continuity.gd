extends SceneTree

## R-738 deterministic adjacent-map sky/weather continuity packet.
##
## Run with a real renderer because SubViewport readback is not available on the
## headless dummy renderer:
##   /Applications/Godot.app/Contents/MacOS/Godot --path . \\
##     --rendering-method mobile --rendering-driver metal \\
##     --script tools/capture_r713_sky_weather_continuity.gd
##
## The helper captures one map at a time. This is intentional: the source view is
## freed before the target view is attached, so the packet proves a state handoff
## without creating two active WorldEnvironment owners in one frame.

const MapAuditRegistry := preload("res://scripts/map/map_audit_registry.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")
const SkyWeather3D := preload("res://scripts/map/view3d/sky_weather_3d.gd")

const CAPTURE_ID := "r713-sky-weather-continuity-v1"
const OUTPUT_DIR := "res://docs/reports/images/r713_sky_weather"
const MANIFEST_PATH := OUTPUT_DIR + "/capture_manifest.json"
const VIEWPORT_SIZE := Vector2i(1280, 720)
const WARMUP_FRAMES := 16
const MAP_IDS: Array[StringName] = [&"lower_town_slice", &"monastery_quarter"]
const MAP_FOCUS_CELLS: Dictionary = {
	&"lower_town_slice": Vector2(25.5, 0.75),
	&"monastery_quarter": Vector2(139.5, 103.25),
}
const SHELTER_MODES: Array[StringName] = [&"exterior", &"sheltered"]
const TIMES_OF_DAY: Array[StringName] = [MapView3D.TIME_DAY, MapView3D.TIME_NIGHT]
const SCENARIOS: Array[Dictionary] = [
	{
		"id": "clear",
		"weather": SkyWeather3D.WEATHER_CLEAR,
		"fog_haze": "low clear-air haze",
	},
	{
		"id": "overcast",
		"weather": SkyWeather3D.WEATHER_OVERCAST,
		"fog_haze": "continuous overcast haze",
	},
	{
		"id": "rain",
		"weather": SkyWeather3D.WEATHER_RAIN,
		"fog_haze": "rain curtain and wet-ground haze",
	},
	{
		"id": "storm",
		"weather": SkyWeather3D.WEATHER_STORM,
		"fog_haze": "storm front and distant haze",
	},
	{
		"id": "rain_shelter_pair",
		"weather": SkyWeather3D.WEATHER_RAIN,
		"fog_haze": "rain haze remains outside while shelter suppresses only the emitter",
	},
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
			"R-738 requires a real renderer/Metal for SubViewport PNG readback; "
			+ "headless capture is deliberately rejected"
		)
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_definitions = MapAuditRegistry.by_id()
	for map_id in MAP_IDS:
		if not _definitions.has(String(map_id)):
			push_error("R-738 representative map is missing from MapAuditRegistry: %s" % map_id)
			quit(1)
			return
	_manifest = _manifest_header()
	for scenario: Dictionary in SCENARIOS:
		if not _selection_matches_scenario(scenario):
			continue
		for time_of_day in TIMES_OF_DAY:
			if not _selection["time_of_day"].is_empty() and String(time_of_day) != _selection["time_of_day"]:
				continue
			for shelter in SHELTER_MODES:
				if not _selection["shelter"].is_empty() and String(shelter) != _selection["shelter"]:
					continue
				var result := await _capture_handoff(scenario, time_of_day, shelter)
				if not bool(result.get("ok", false)):
					quit(1)
					return
	_manifest["capture_status"] = "captured_pending_review"
	_manifest["commit"] = _git_head()
	_manifest["hardware_host"] = "%s/%s" % [OS.get_name(), Engine.get_architecture_name()]
	_manifest["renderer_observed"] = DisplayServer.get_name()
	if _write_manifest() != OK:
		quit(1)
		return
	print("R713_SKY_WEATHER_CONTINUITY_CAPTURED dir=%s" % OUTPUT_DIR)
	quit(0)


static func _capture_selection_from_args(args: Array) -> Dictionary:
	var selection := {
		"map_id": "",
		"scenario_id": "",
		"time_of_day": "",
		"shelter": "",
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
		elif argument.begins_with("--shelter="):
			selection["shelter"] = argument.trim_prefix("--shelter=")
		else:
			selection["error"] = ERR_INVALID_PARAMETER
			selection["error_message"] = "Unknown R-738 capture argument: %s" % argument
			return selection
	if not String(selection["map_id"]).is_empty() and not MAP_IDS.has(StringName(selection["map_id"])):
		selection["error"] = ERR_INVALID_PARAMETER
		selection["error_message"] = "Unknown R-738 map: %s" % selection["map_id"]
	elif not String(selection["scenario_id"]).is_empty() and not _has_scenario(String(selection["scenario_id"])):
		selection["error"] = ERR_INVALID_PARAMETER
		selection["error_message"] = "Unknown R-738 scenario: %s" % selection["scenario_id"]
	elif not String(selection["time_of_day"]).is_empty() and not ["day", "night"].has(selection["time_of_day"]):
		selection["error"] = ERR_INVALID_PARAMETER
		selection["error_message"] = "R-738 --time must be day or night"
	elif not String(selection["shelter"]).is_empty() and not ["exterior", "sheltered"].has(selection["shelter"]):
		selection["error"] = ERR_INVALID_PARAMETER
		selection["error_message"] = "R-738 --shelter must be exterior or sheltered"
	return selection


static func _has_scenario(scenario_id: String) -> bool:
	for scenario: Dictionary in SCENARIOS:
		if String(scenario["id"]) == scenario_id:
			return true
	return false


func _selection_matches_scenario(scenario: Dictionary) -> bool:
	return (
		String(_selection["scenario_id"]).is_empty()
		or String(scenario["id"]) == String(_selection["scenario_id"])
	)


func _manifest_header() -> Dictionary:
	var plates: Array[Dictionary] = []
	for map_id in MAP_IDS:
		for scenario: Dictionary in SCENARIOS:
			for time_of_day in TIMES_OF_DAY:
				for shelter in SHELTER_MODES:
					plates.append({
						"map_id": String(map_id),
						"scenario_id": String(scenario["id"]),
						"weather": String(scenario["weather"]),
						"time_of_day": String(time_of_day),
						"shelter": String(shelter),
						"output": _output_path(map_id, scenario, time_of_day, shelter),
						"status": "missing",
						"sha256": "",
						"width": VIEWPORT_SIZE.x,
						"height": VIEWPORT_SIZE.y,
					})
	return {
		"schema_version": 1,
		"capture_id": CAPTURE_ID,
		"capture_status": "blocked",
		"commit": _git_head(),
		"engine": Engine.get_version_info().get("string", "Godot 4.7"),
		"renderer_expected": "metal",
		"renderer_observed": "not_run",
		"hardware_host": "not_measured",
		"viewport": {"width": VIEWPORT_SIZE.x, "height": VIEWPORT_SIZE.y},
		"maps": [String(MAP_IDS[0]), String(MAP_IDS[1])],
		"world_group_id": "reval_contiguous_outdoor",
		"physical_handoff": {
			"source_map": String(MAP_IDS[0]),
			"target_map": String(MAP_IDS[1]),
			"transition": "vene_district_boundary -> to_reval_east",
			"scene_swap": false,
			"environment_owner": "SessionState",
			"expected_active_environment_owners": 1,
			"status": "not_run",
		},
		"expected_invariants": [
			"day/night keeps one sun and one cloud front at the handoff",
			"clear/overcast/rain/storm preserve weather identity and transition progress",
			"wind direction is the shared normalized cloud/water direction",
			"fog/haze and exposure do not reset at the handoff",
			"sheltered interior/exterior pairs suppress only visible rain emission",
			"there is no duplicate environment owner or scene-swap flash",
		],
		"plates": plates,
		"handoffs": [],
		"blockers": [
			"real renderer/Metal capture and human visual review are required before acceptance"
		],
	}


func _capture_handoff(scenario: Dictionary, time_of_day: StringName, shelter: StringName) -> Dictionary:
	var source_id := MAP_IDS[0]
	var target_id := MAP_IDS[1]
	var source_result := await _capture_plate(
		source_id, scenario, time_of_day, shelter, {}, "source"
	)
	if not bool(source_result.get("ok", false)):
		return source_result
	var source_state: Dictionary = source_result["snapshot"]
	var target_result := await _capture_plate(
		target_id, scenario, time_of_day, shelter, source_state, "target"
	)
	if not bool(target_result.get("ok", false)):
		return target_result
	var owner_count := int(source_result["environment_owner_count"])
	var target_owner_count := int(target_result["environment_owner_count"])
	var state_hash_source := snapshot_hash(source_state)
	var state_hash_target := snapshot_hash(target_result["snapshot"])
	_manifest["handoffs"].append({
		"source_map": String(source_id),
		"target_map": String(target_id),
		"scenario_id": String(scenario["id"]),
		"weather": String(scenario["weather"]),
		"time_of_day": String(time_of_day),
		"shelter": String(shelter),
		"state_hash_source": state_hash_source,
		"state_hash_target": state_hash_target,
		"environment_owner_count_source": owner_count,
		"environment_owner_count_target": target_owner_count,
		"scene_swap": false,
		"status": "captured" if state_hash_source == state_hash_target and owner_count == 1 and target_owner_count == 1 else "failed",
	})
	if state_hash_source != state_hash_target:
		push_error("R-738 weather snapshot changed during handoff for %s/%s/%s" % [scenario["id"], time_of_day, shelter])
		return {"ok": false}
	if owner_count != 1 or target_owner_count != 1:
		push_error("R-738 expected one active environment owner per handoff side")
		return {"ok": false}
	_manifest["physical_handoff"]["status"] = "captured"
	_manifest["physical_handoff"]["state_hash"] = state_hash_source
	return {"ok": true}


func _capture_plate(
	map_id: StringName,
	scenario: Dictionary,
	time_of_day: StringName,
	shelter: StringName,
	handoff_state: Dictionary,
	side: String
) -> Dictionary:
	var definition: MapDefinition = _definitions[String(map_id)]
	var viewport := SubViewport.new()
	viewport.name = "R713_%s_%s" % [String(map_id), side]
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)
	var view := MapView3D.create(definition, MapBuilder.build(definition), time_of_day)
	viewport.add_child(view)
	var camera := view.view_camera()
	camera.current = true
	camera.position = view.world_position(MAP_FOCUS_CELLS[map_id], 0.8) + camera.transform.basis.z * MapView3D.CAMERA_DISTANCE
	camera.look_at(view.world_position(MAP_FOCUS_CELLS[map_id], 0.8), Vector3.UP)
	var sky := view.sky_weather()
	if sky == null:
		push_error("R-738 map view has no SkyWeather3D: %s" % map_id)
		viewport.queue_free()
		await process_frame
		return {"ok": false}
	view.set_time_of_day(time_of_day)
	view.set_weather_rain_suppressed(shelter == &"sheltered")
	if handoff_state.is_empty():
		sky.auto_weather = false
		sky.set_weather(scenario["weather"])
		sky.advance(SkyWeather3D.TRANSITION_SECONDS)
	else:
		if not sky.restore_state(handoff_state):
			push_error("R-738 target presenter rejected source weather snapshot")
			viewport.queue_free()
			await process_frame
			return {"ok": false}
	view.set_weather_time_scale(0.0)
	view.apply_cycle_progress(view.cycle_progress)
	var snapshot: Dictionary = sky.snapshot_state(view.cycle_progress, 0).to_dict()
	var presentation = sky.presentation_snapshot(view.cycle_progress, 1.0)
	for _frame in WARMUP_FRAMES:
		await process_frame
	var texture := viewport.get_texture()
	if texture == null:
		push_error("R-738 viewport has no texture for %s" % map_id)
		viewport.queue_free()
		await process_frame
		return {"ok": false}
	var image := texture.get_image()
	if image == null or image.get_size() != VIEWPORT_SIZE:
		push_error("R-738 PNG dimensions are not %dx%d for %s" % [VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, map_id])
		viewport.queue_free()
		await process_frame
		return {"ok": false}
	var output := _output_path(map_id, scenario, time_of_day, shelter)
	var error := image.save_png(ProjectSettings.globalize_path(output))
	if error != OK:
		push_error("Could not save R-738 evidence %s: %s" % [output, error_string(error)])
		viewport.queue_free()
		await process_frame
		return {"ok": false}
	_update_plate(map_id, scenario, time_of_day, shelter, output, image, presentation)
	var owner_count := _count_type(viewport, "WorldEnvironment")
	viewport.queue_free()
	await process_frame
	return {
		"ok": true,
		"snapshot": snapshot,
		"environment_owner_count": owner_count,
	}


func _update_plate(
	map_id: StringName,
	scenario: Dictionary,
	time_of_day: StringName,
	shelter: StringName,
	output: String,
	image: Image,
	presentation: SkyWeather3D.WeatherPresentation
) -> void:
	var relative_output := output.trim_prefix("res://")
	var checksum := _sha256_file(output)
	for plate: Dictionary in _manifest["plates"]:
		if (
			plate["map_id"] == String(map_id)
			and plate["scenario_id"] == String(scenario["id"])
			and plate["time_of_day"] == String(time_of_day)
			and plate["shelter"] == String(shelter)
		):
			plate["output"] = relative_output
			plate["status"] = "captured"
			plate["sha256"] = checksum
			plate["width"] = image.get_width()
			plate["height"] = image.get_height()
			plate["presentation"] = {
				"weather": String(presentation.weather),
				"wind_direction": [presentation.wind_direction.x, presentation.wind_direction.y],
				"wind_strength": presentation.wind_strength,
				"rain_intensity": presentation.rain_intensity,
				"puddle_wetness": presentation.puddle_wetness,
				"overcast": presentation.overcast,
				"sun_energy": presentation.sun_energy,
				"ambient_energy": presentation.ambient_energy,
				"rain_suppressed": presentation.rain_suppressed,
			}
			return


func _output_path(
	map_id: StringName, scenario: Dictionary, time_of_day: StringName, shelter: StringName
) -> String:
	return "%s/%s_%s_%s_%s.png" % [
		OUTPUT_DIR,
		String(map_id),
		String(scenario["id"]),
		String(time_of_day),
		String(shelter),
	]


func _count_type(node: Node, type_name: String) -> int:
	var count := 0
	if node.get_class() == type_name:
		count += 1
	for child in node.get_children():
		count += _count_type(child, type_name)
	return count


static func snapshot_hash(snapshot: Dictionary) -> String:
	return JSON.stringify(snapshot).sha256_text()


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
	if OS.execute("git", PackedStringArray(["rev-parse", "HEAD"]), output, true) == 0 and not output.is_empty():
		return output[0].strip_edges()
	return "unknown"


func _write_manifest() -> Error:
	var file := FileAccess.open(ProjectSettings.globalize_path(MANIFEST_PATH), FileAccess.WRITE)
	if file == null:
		push_error("Could not open R-738 manifest for writing: %s" % MANIFEST_PATH)
		return ERR_CANT_OPEN
	file.store_string(JSON.stringify(_manifest, "\t"))
	return OK
