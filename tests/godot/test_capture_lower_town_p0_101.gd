extends "res://tests/godot/test_case.gd"

## R-560 / P0-101f: dedicated Lower Town gameplay-scale route capture contract.
## This test validates the deterministic packet definition; image rendering is
## intentionally exercised by the separate non-headless capture command.

const CaptureScript := preload("res://tools/capture_lower_town_p0_101.gd")
const LowerTownSlice := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")
const MapVerification := preload("res://scripts/map/map_verification.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")
const CharacterScale := preload("res://assets/characters/shared/character_scale.gd")


func test_capture_targets_production_lower_town_and_authored_route_anchors() -> void:
	var definition := LowerTownSlice.create()
	assert_eq(definition.map_id, StringName(CaptureScript.MAP_ID))
	assert_true(definition.active, "P0-101 capture must use the active production slice")
	assert_eq(CaptureScript.PRESETS.size(), 4, "route packet must stay bounded and reviewable")

	for preset: Dictionary in CaptureScript.PRESETS:
		var from_anchor: StringName = preset["from_anchor"]
		var to_anchor: StringName = preset["to_anchor"]
		assert_true(
			MapVerification.has_anchor(definition, from_anchor),
			"missing production route anchor %s" % from_anchor
		)
		assert_true(
			MapVerification.has_anchor(definition, to_anchor),
			"missing production route anchor %s" % to_anchor
		)
		assert_ne(preset["id"], "smithy_courtyard", "retired authoring spike must not return")
		assert_ne(preset["id"], "whole_map", "whole-map smoke is not a route preset")


func test_presets_are_deterministic_anchor_midpoint_crops() -> void:
	var definition := LowerTownSlice.create()
	var expected_ids := [
		"street_start_to_smithy_door",
		"smithy_door_to_brewery_door",
		"brewery_door_to_checkpoint_west",
		"checkpoint_west_to_checkpoint_east",
	]
	for index in CaptureScript.PRESETS.size():
		var preset: Dictionary = CaptureScript.PRESETS[index]
		assert_eq(preset["id"], expected_ids[index])
		var from_position := MapVerification.anchor_position(definition, preset["from_anchor"])
		var to_position := MapVerification.anchor_position(definition, preset["to_anchor"])
		var midpoint := (from_position + to_position) * 0.5
		var metadata := CaptureScript._preset_metadata(definition, preset)
		assert_eq(metadata["focus_logic_cell"], [midpoint.x, midpoint.y])
		assert_eq(metadata["focus_height"], CaptureScript.FOCUS_HEIGHT)
		assert_eq(metadata["orthographic_size"], CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE)
		assert_eq(metadata["camera_pitch_degrees"], MapView3D.CAMERA_PITCH_DEGREES)
		assert_eq(metadata["camera_yaw_degrees"], MapView3D.CAMERA_YAW_DEGREES)


func test_capture_packet_enforces_gameplay_scale_and_matched_day_night_output_contract() -> void:
	assert_eq(CaptureScript.OUTPUT_DIR, "res://docs/reports/images/lower_town_p0_101")
	assert_eq(CaptureScript.VIEWPORT_SIZE, Vector2i(1280, 720))
	assert_eq(CaptureScript.RENDERER, "gl_compatibility")
	assert_eq(CaptureScript.ORTHOGRAPHIC_SIZE, CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE)
	assert_eq(CaptureScript.PRESETS.size() * MapView3D.ALL_TIMES.size(), 8)
	assert_eq(MapView3D.ALL_TIMES, [MapView3D.TIME_DAY, MapView3D.TIME_NIGHT])
	assert_true(
		CaptureScript.MANIFEST_PATH.begins_with(CaptureScript.OUTPUT_DIR + "/"),
		"metadata must stay beside the dedicated P0-101 plates"
	)
	assert_ne(
		CaptureScript.OUTPUT_DIR,
		"res://docs/reports/images/view3d",
		"whole-map smoke output must not be reused as acceptance evidence"
	)
	assert_ne(
		CaptureScript.OUTPUT_DIR,
		"res://docs/reports/images/adr0018_calibration",
		"ADR-0018 calibration output must not be reused as acceptance evidence"
	)


func test_existing_capture_packet_outputs_are_present_and_non_blank() -> void:
	var output_dir := ProjectSettings.globalize_path(CaptureScript.OUTPUT_DIR)
	if not DirAccess.dir_exists_absolute(output_dir):
		return
	var manifest_path := ProjectSettings.globalize_path(CaptureScript.MANIFEST_PATH)
	assert_true(FileAccess.file_exists(manifest_path), "capture manifest must accompany generated plates")
	for preset: Dictionary in CaptureScript.PRESETS:
		for time_of_day in MapView3D.ALL_TIMES:
			var output_path := "%s/%s_%s.png" % [output_dir, preset["id"], time_of_day]
			assert_true(FileAccess.file_exists(output_path), "missing P0-101 plate: %s" % output_path)
			var image := Image.load_from_file(output_path)
			assert_true(image != null, "plate must decode: %s" % output_path)
			if image == null:
				continue
			assert_eq(image.get_size(), CaptureScript.VIEWPORT_SIZE, "plate dimensions: %s" % output_path)
			assert_ne(image.get_data().size(), 0, "plate must contain pixels: %s" % output_path)
