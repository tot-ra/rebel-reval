extends "res://tests/godot/test_case.gd"

const CaptureScript := preload("res://tools/capture_st_olaf_r281.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")


func test_st_olaf_r281_manifest_has_matched_day_night_stable_id_plates() -> void:
	var manifest_path := ProjectSettings.globalize_path(CaptureScript.MANIFEST_PATH)
	assert_true(FileAccess.file_exists(manifest_path), "R-281 capture manifest must exist")
	if not FileAccess.file_exists(manifest_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	assert_true(parsed is Dictionary, "R-281 capture manifest must be JSON object")
	if not parsed is Dictionary:
		return
	var manifest: Dictionary = parsed
	assert_eq(manifest.get("map_id", ""), CaptureScript.MAP_ID)
	assert_eq(manifest.get("stable_ids", []), [CaptureScript.LANDMARK_ID, CaptureScript.FRONTAGE_ID])
	var viewport_px: Array = manifest.get("viewport_px", [])
	assert_eq(viewport_px.size(), 2)
	if viewport_px.size() == 2:
		assert_eq(int(viewport_px[0]), CaptureScript.VIEWPORT_SIZE.x)
		assert_eq(int(viewport_px[1]), CaptureScript.VIEWPORT_SIZE.y)
	var plates: Array = manifest.get("plates", [])
	assert_eq(plates.size(), MapView3D.ALL_TIMES.size(), "R-281 needs one plate per lighting state")
	var framing_keys := {}
	for plate: Dictionary in plates:
		assert_eq(plate.get("stable_id", ""), CaptureScript.LANDMARK_ID)
		assert_eq(plate.get("frontage_id", ""), CaptureScript.FRONTAGE_ID)
		assert_true(plate.get("time_of_day", "") in ["day", "night"])
		assert_eq(plate.get("camera_intent", ""), "gameplay-scale St Olaf landmark approach")
		assert_true(FileAccess.file_exists(ProjectSettings.globalize_path(plate.get("output", ""))))
		framing_keys[plate.get("framing_key", "")] = true
	assert_eq(framing_keys.size(), 1, "day/night plates must share one framing key")


func test_st_olaf_r281_plates_are_gameplay_scale_and_non_blank() -> void:
	var output_dir := ProjectSettings.globalize_path(CaptureScript.OUTPUT_DIR)
	for time_of_day in ["day", "night"]:
		var output_path := "%s/st_olaf_%s.png" % [output_dir, time_of_day]
		assert_true(FileAccess.file_exists(output_path), "missing R-281 plate: %s" % output_path)
		if not FileAccess.file_exists(output_path):
			continue
		var image := Image.load_from_file(output_path)
		assert_true(image != null, "R-281 plate must decode: %s" % output_path)
		if image == null:
			continue
		assert_eq(image.get_size(), CaptureScript.VIEWPORT_SIZE)
		var non_zero := false
		for byte_value: int in image.get_data():
			if byte_value != 0:
				non_zero = true
				break
		assert_true(non_zero, "R-281 plate must be non-blank: %s" % output_path)
