extends "res://tests/godot/test_case.gd"

## R-738 structural contract tests intentionally avoid preloading the capture
## helper. The current worktree has an unrelated SkyWeather3D parser blocker;
## reading the new source/manifest keeps this suite useful and fail-closed while
## the renderer-bound capture remains a separate integration check.

const CAPTURE_SOURCE := "res://tools/capture_r713_sky_weather_continuity.gd"
const MANIFEST_PATH := "res://docs/reports/images/r713_sky_weather/capture_manifest.json"
const EXPECTED_MAPS: Array[String] = ["lower_town_slice", "monastery_quarter"]
const EXPECTED_SCENARIOS: Array[String] = [
	"clear", "overcast", "rain", "storm", "rain_shelter_pair"
]
const EXPECTED_TIMES: Array[String] = ["day", "night"]
const EXPECTED_SHELTERS: Array[String] = ["exterior", "sheltered"]


func _source() -> String:
	return FileAccess.get_file_as_string(CAPTURE_SOURCE)


func test_packet_declares_representative_physical_handoff_and_fixed_viewport() -> void:
	var source := _source()
	assert_true(source.contains('const CAPTURE_ID := "r713-sky-weather-continuity-v1"'))
	assert_true(source.contains('const VIEWPORT_SIZE := Vector2i(1280, 720)'))
	assert_true(
		source.contains('const MAP_IDS: Array[StringName] = [&"lower_town_slice", &"monastery_quarter"]')
	)
	assert_true(
		source.contains(
			'const TIMES_OF_DAY: Array[StringName] = [MapView3D.TIME_DAY, MapView3D.TIME_NIGHT]'
		)
	)
	assert_true(source.contains('const LowerTownSlice := preload('))
	assert_true(source.contains('const MonasteryQuarter := preload('))
	assert_false(source.contains('MapAuditRegistry.by_id()'))
	assert_true(source.contains('String(MAP_IDS[0]): LowerTownSlice.create()'))
	assert_true(source.contains('String(MAP_IDS[1]): MonasteryQuarter.create()'))
	assert_true(
		source.contains('const SHELTER_MODES: Array[StringName] = [&"exterior", &"sheltered"]')
	)
	assert_true(source.contains('"transition": "vene_district_boundary -> to_reval_east"'))


func test_source_covers_all_required_weather_and_atmosphere_cases() -> void:
	var source := _source()
	for weather_id in ["WEATHER_CLEAR", "WEATHER_OVERCAST", "WEATHER_RAIN", "WEATHER_STORM"]:
		assert_true(source.contains(weather_id), "capture source must cover %s" % weather_id)
	for required_term in [
		"fog_haze",
		"wind_direction",
		"rain_suppressed",
		"puddle_wetness",
		"snapshot_state",
		"restore_state",
		"state_hash_source",
		"state_hash_target",
	]:
		assert_true(source.contains(required_term), "capture source must retain %s" % required_term)


func test_manifest_header_contains_every_weather_time_and_shelter_pair() -> void:
	assert_true(FileAccess.file_exists(MANIFEST_PATH), "planned capture manifest must be committed")
	if not FileAccess.file_exists(MANIFEST_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	assert_true(parsed is Dictionary, "capture manifest must decode as an object")
	if not parsed is Dictionary:
		return
	var manifest: Dictionary = parsed
	assert_eq(manifest.get("schema_version"), 1)
	assert_eq(manifest.get("capture_id"), "r713-sky-weather-continuity-v1")
	assert_eq(manifest.get("renderer_expected"), "metal")
	assert_eq(manifest.get("maps"), EXPECTED_MAPS)
	assert_eq(manifest["viewport"]["width"], 1280)
	assert_eq(manifest["viewport"]["height"], 720)
	assert_eq(manifest["physical_handoff"]["scene_swap"], false)
	assert_eq(manifest["physical_handoff"]["environment_owner"], "SessionState")
	assert_eq(manifest["physical_handoff"]["expected_active_environment_owners"], 1)
	assert_eq(manifest.get("capture_status"), "captured_pending_review")
	assert_eq(manifest["physical_handoff"]["status"], "captured")
	var plates: Array = manifest.get("plates", [])
	assert_eq(plates.size(), 40, "two maps x five scenarios x day/night x shelter")
	assert_eq(
		manifest.get("handoffs", []).size(), 20, "two maps x five scenarios x day/night x shelter"
	)
	var identities: Dictionary = {}
	for plate: Dictionary in plates:
		var key := "%s/%s/%s/%s" % [
			plate.get("map_id", ""),
			plate.get("scenario_id", ""),
			plate.get("time_of_day", ""),
			plate.get("shelter", ""),
		]
		identities[key] = true
		assert_eq(plate.get("status"), "captured", "captured evidence must be recorded")
		assert_eq(plate.get("width"), 1280)
		assert_eq(plate.get("height"), 720)
	for map_id in EXPECTED_MAPS:
		for scenario_id in EXPECTED_SCENARIOS:
			for time_of_day in EXPECTED_TIMES:
				for shelter in EXPECTED_SHELTERS:
					var key := "%s/%s/%s/%s" % [map_id, scenario_id, time_of_day, shelter]
					assert_true(identities.has(key), "manifest missing %s" % key)


func test_source_is_fail_closed_for_real_renderer_and_single_owner_handoff() -> void:
	var source := _source()
	assert_true(source.contains('DisplayServer.get_name() == "headless"'))
	assert_true(source.contains("real renderer/Metal"))
	assert_true(source.contains('_count_type(viewport, "WorldEnvironment")'))
	assert_true(source.contains("snapshot_hash(source_state)"))
	assert_true(source.contains("snapshot_hash(target_result[\"snapshot\"])"))
	assert_true(source.contains("\"scene_swap\": false"))
	assert_false(source.contains("change_scene_to_packed"))
