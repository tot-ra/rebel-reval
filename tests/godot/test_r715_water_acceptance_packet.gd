extends "res://tests/godot/test_case.gd"

## R-756 structural packet checks intentionally avoid preloading the capture helper.
## The current checkout has a pre-existing SkyWeather3D parser cascade; the real
## renderer runner remains separately executable once that dependency is cleared.

const CAPTURE_SOURCE := "res://tools/capture_r715_water_acceptance.gd"
const MANIFEST_PATH := "res://docs/reports/images/r715_water/capture_manifest.json"
const EXPECTED_MAPS: Dictionary = {
	"smithy_courtyard": ["water"],
	"lower_town_slice": ["water"],
	"south_quarter": ["water"],
	"viru_gate_foreland": ["river_water"],
	"reval_harbor_north": ["shallow_water", "deep_water"],
	"reval_harbor_east": ["shallow_water", "deep_water"],
	"prototype.paldiski_coastal_outpost": ["shallow_water", "deep_water"],
	"prototype.sacred_grove": ["shallow_water"],
	"prototype.saaremaa": ["shallow_water", "deep_water"],
	"prototype.swedish_arrival": ["shallow_water", "deep_water"],
	"world.sacred_grove": ["shallow_water"],
	"world.padise": ["water", "river_water", "shallow_water"],
	"world.saaremaa": ["shallow_water", "deep_water"],
}
const EXPECTED_SCENARIOS: Array[String] = ["clear", "overcast", "rain", "storm", "post_rain"]
const EXPECTED_TIMES: Array[String] = ["day", "night"]
const REQUIRED_CHECKS: Array[String] = [
	"reflection_continuity",
	"wave_readability",
	"shoreline_grounding",
	"underwater_depth",
	"night_readability",
	"parity",
]


func _source() -> String:
	return FileAccess.get_file_as_string(CAPTURE_SOURCE)


func _manifest() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	return parsed as Dictionary if parsed is Dictionary else {}


func test_capture_source_declares_fixed_real_renderer_policy() -> void:
	var source := _source()
	assert_true(source.contains('const CAPTURE_ID := "r715-water-acceptance-v1"'))
	assert_true(source.contains('const VIEWPORT_SIZE := Vector2i(1280, 720)'))
	assert_true(source.contains('const OUTPUT_DIR := "res://docs/reports/images/r715_water"'))
	assert_true(source.contains('DisplayServer.get_name() == "headless"'))
	assert_true(source.contains("real renderer/Metal"))
	assert_true(source.contains("one matrix plate per process"))
	assert_true(source.contains("captured_pending_review"))
	assert_true(source.contains("human visual review is still required"))


func test_manifest_declares_complete_unique_map_scenario_time_matrix() -> void:
	assert_true(FileAccess.file_exists(MANIFEST_PATH), "R-756 manifest must be committed")
	if not FileAccess.file_exists(MANIFEST_PATH):
		return
	var manifest := _manifest()
	assert_false(manifest.is_empty(), "R-756 manifest must decode as an object")
	if manifest.is_empty():
		return
	assert_eq(manifest.get("schema_version"), 1)
	assert_eq(manifest.get("capture_id"), "r715-water-acceptance-v1")
	assert_eq(manifest.get("renderer_expected"), "metal")
	_assert_viewport(manifest.get("viewport", {}))
	assert_eq(manifest.get("quality"), "recommended")
	assert_eq(manifest.get("required_visual_checks"), REQUIRED_CHECKS)
	var maps: Array = manifest.get("maps", [])
	assert_eq(maps.size(), EXPECTED_MAPS.size())
	for map_record: Dictionary in maps:
		var map_id := String(map_record.get("map_id", ""))
		assert_true(EXPECTED_MAPS.has(map_id), "unexpected water map %s" % map_id)
		assert_eq(map_record.get("water_terrain_ids", []), EXPECTED_MAPS.get(map_id, []))
		assert_eq(map_record.get("status"), "blocked")

	var plates: Array = manifest.get("plates", [])
	assert_eq(
		plates.size(),
		EXPECTED_MAPS.size() * EXPECTED_SCENARIOS.size() * EXPECTED_TIMES.size()
	)
	var identities: Dictionary = {}
	for plate: Dictionary in plates:
		var plate_id := String(plate.get("plate_id", ""))
		assert_true(not plate_id.is_empty(), "each plate needs a stable ID")
		assert_false(identities.has(plate_id), "duplicate plate ID: %s" % plate_id)
		identities[plate_id] = true
		_assert_viewport(plate.get("viewport", {}))
		assert_eq(plate.get("renderer_expected"), "metal")
		assert_eq(plate.get("quality"), "recommended")
		assert_eq(
			plate.get("water_terrain_ids", []),
			EXPECTED_MAPS.get(plate.get("map_id", ""), [])
		)
		assert_eq(plate.get("visual_checks", {}).keys(), REQUIRED_CHECKS)
		var status := String(plate.get("status", ""))
		assert_true(
			["blocked", "captured_pending_review", "accepted"].has(status),
			"unknown plate status: %s" % status
		)
		if status == "blocked":
			assert_true(String(plate.get("annotation", "")).contains("Not captured"))
			assert_true(
				plate.get("blockers", []) is Array
				and not plate.get("blockers", []).is_empty()
			)
			assert_eq(plate.get("sha256"), "")
		else:
			_assert_captured_plate(plate)
	for map_id in EXPECTED_MAPS:
		for scenario_id in EXPECTED_SCENARIOS:
			for time_of_day in EXPECTED_TIMES:
				var plate_id := "%s/%s/%s" % [map_id, scenario_id, time_of_day]
				assert_true(identities.has(plate_id), "manifest missing %s" % plate_id)


func _assert_viewport(viewport: Variant) -> void:
	assert_true(viewport is Dictionary, "viewport metadata must be an object")
	if not viewport is Dictionary:
		return
	var values: Dictionary = viewport
	assert_eq(int(values.get("width", 0)), 1280)
	assert_eq(int(values.get("height", 0)), 720)


func _assert_captured_plate(plate: Dictionary) -> void:
	var output := String(plate.get("output", ""))
	assert_true(output.begins_with("res://"), "captured output must be a project path")
	var path := output.trim_prefix("res://")
	assert_true(FileAccess.file_exists(path), "captured plate must exist: %s" % output)
	if not FileAccess.file_exists(path):
		return
	var image := Image.load_from_file(path)
	assert_true(image != null, "captured plate must decode: %s" % output)
	if image == null:
		return
	assert_eq(image.get_size(), Vector2i(1280, 720))
	var has_non_zero_pixel := false
	for byte_value: int in image.get_data():
		if byte_value != 0:
			has_non_zero_pixel = true
			break
	assert_true(has_non_zero_pixel, "captured plate must not be blank: %s" % output)
	assert_eq(plate.get("sha256"), _sha256_file(path))
	assert_true(
		String(plate.get("annotation", "")).contains("human visual review")
	)


func _sha256_file(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	while not file.eof_reached():
		hashing.update(file.get_buffer(1024 * 1024))
	return hashing.finish().hex_encode()


func test_manifest_preserves_water_context_and_external_handoffs() -> void:
	var manifest := _manifest()
	assert_eq(manifest.get("capture_status"), "blocked")
	assert_eq(
		manifest.get("external_handoffs", {}).get("r529_monastery_east_ditch"),
		"blocked_external_owner"
	)
	assert_eq(
		manifest.get("external_handoffs", {}).get("r713_sky_weather_continuity"),
		"blocked_external_evidence"
	)
	assert_true(manifest.get("blockers", []).size() >= 3)
	for map_record: Dictionary in manifest.get("maps", []):
		assert_true(map_record.get("water_context", []) is Array)
		assert_true(not map_record.get("water_context", []).is_empty())
	for plate: Dictionary in manifest.get("plates", []):
		assert_eq(
			plate.get("scenario_id"),
			String(plate.get("plate_id")).split("/")[1]
		)
		assert_true(plate.get("water_context", []) is Array)
		assert_true(not plate.get("water_context", []).is_empty())


func test_capture_source_contains_fail_closed_image_and_annotation_guards() -> void:
	var source := _source()
	for required_guard in [
		"func _image_is_blank(",
		"image.get_size() != VIEWPORT_SIZE",
		"plate[\"status\"] = \"captured_pending_review\"",
		"plate[\"sha256\"] = _sha256_file",
		"visual_checks",
		"human visual review is still required",
	]:
		assert_true(
			source.contains(required_guard),
			"capture source must retain %s" % required_guard
		)
	assert_false(
		source.contains('status\"] = "accepted"'),
		"capture runner cannot self-approve visual review"
	)


func test_invalid_captured_plate_is_rejected_by_packet_contract() -> void:
	var source := _source()
	# The source-level contract must validate all file integrity dimensions before
	# promoting a plate from its blocked state. This guards against a future runner
	# turning a missing or blank PNG into accepted evidence.
	assert_true(source.contains("if texture == null:"))
	assert_true(
		source.contains("if image == null or image.get_size() != VIEWPORT_SIZE:")
	)
	assert_true(source.contains("if _image_is_blank(image):"))
	assert_true(source.contains("return await _capture_failure(viewport"))
	assert_true(
		source.contains(
			'plate["annotation"] = "Real-renderer PNG captured; human visual review is still required."'
		)
	)
