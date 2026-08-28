extends "res://tests/godot/test_case.gd"

const CaptureScript := preload("res://tools/capture_rentenitorn_presentation.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")
const CharacterScale := preload("res://assets/characters/shared/character_scale.gd")


func test_rentenitorn_manifest_has_matched_interior_and_exterior_plates() -> void:
	var manifest_path := ProjectSettings.globalize_path(CaptureScript.MANIFEST_PATH)
	assert_true(FileAccess.file_exists(manifest_path), "R-785 capture manifest must exist")
	if not FileAccess.file_exists(manifest_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	assert_true(parsed is Dictionary, "R-785 capture manifest must be a JSON object")
	if not parsed is Dictionary:
		return
	var manifest: Dictionary = parsed
	assert_eq(manifest.get("task", ""), "R-785 / P4-027d")
	assert_eq(manifest.get("renderer", ""), "gl_compatibility")
	assert_eq(manifest.get("render_driver", ""), "opengl3")
	var viewport_px: Array = manifest.get("viewport_px", [])
	assert_eq(viewport_px.size(), 2)
	if viewport_px.size() == 2:
		assert_eq(int(viewport_px[0]), CaptureScript.VIEWPORT_SIZE.x)
		assert_eq(int(viewport_px[1]), CaptureScript.VIEWPORT_SIZE.y)
	var camera: Dictionary = manifest.get("camera", {})
	assert_eq(camera.get("projection", ""), "orthographic")
	assert_eq(float(camera.get("orthographic_size", 0.0)), CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE)
	assert_eq(float(camera.get("pitch_degrees", 0.0)), MapView3D.CAMERA_PITCH_DEGREES)
	assert_eq(float(camera.get("yaw_degrees", 0.0)), MapView3D.CAMERA_YAW_DEGREES)
	var maps: Dictionary = manifest.get("maps", {})
	assert_true(maps.has("rentenitorn_interior"), "interior map metadata must be present")
	assert_true(maps.has("north_quarter"), "exterior map metadata must be present")
	assert_false(bool(maps["rentenitorn_interior"].get("active", true)))
	assert_false(bool(maps["north_quarter"].get("active", true)))

	var plates: Array = manifest.get("plates", [])
	assert_eq(
		plates.size(),
		MapView3D.ALL_TIMES.size() * 3,
		"three matched views need day/night plates"
	)
	var framing_by_view: Dictionary = {}
	var times_by_view: Dictionary = {}
	for plate: Dictionary in plates:
		var view_id := String(plate.get("view_id", ""))
		var time_of_day := String(plate.get("time_of_day", ""))
		assert_true(
			time_of_day in ["day", "night"],
			"R-785 plate must identify day or night"
		)
		assert_true(
			FileAccess.file_exists(ProjectSettings.globalize_path(plate.get("output", ""))),
			"R-785 plate output must exist: %s" % plate.get("output", "")
		)
		assert_true(plate.get("stable_ids", []).size() > 0, "stable IDs must be recorded")
		if not framing_by_view.has(view_id):
			framing_by_view[view_id] = plate.get("framing_key", "")
			times_by_view[view_id] = {}
		assert_eq(
			plate.get("framing_key", ""),
			framing_by_view[view_id],
			"day/night framing must match for %s" % view_id
		)
		times_by_view[view_id][time_of_day] = true
	assert_eq(framing_by_view.size(), 3, "interior, approach, and door views are required")
	for view_id in times_by_view:
		assert_eq(times_by_view[view_id].size(), 2, "matched day/night pair missing for %s" % view_id)


func test_rentenitorn_plates_are_gameplay_scale_and_non_blank() -> void:
	var manifest_path := ProjectSettings.globalize_path(CaptureScript.MANIFEST_PATH)
	if not FileAccess.file_exists(manifest_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not parsed is Dictionary:
		return
	for plate: Dictionary in (parsed as Dictionary).get("plates", []):
		var output_path := ProjectSettings.globalize_path(plate.get("output", ""))
		var image := Image.load_from_file(output_path)
		assert_true(image != null, "R-785 plate must decode: %s" % output_path)
		if image == null:
			continue
		assert_eq(image.get_size(), CaptureScript.VIEWPORT_SIZE)
		var non_zero := false
		for byte_value: int in image.get_data():
			if byte_value != 0:
				non_zero = true
				break
		assert_true(non_zero, "R-785 plate must be non-blank: %s" % output_path)
