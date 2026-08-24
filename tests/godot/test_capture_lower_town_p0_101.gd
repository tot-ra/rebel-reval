extends "res://tests/godot/test_case.gd"

## R-560 / P0-101f: dedicated Lower Town gameplay-scale route capture contract.
## This test validates the deterministic packet definition; image rendering is
## intentionally exercised by the separate non-headless capture command.

const CaptureScript := preload("res://tools/capture_lower_town_p0_101.gd")
const LowerTownSlice := preload(
	"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
)
const MapVerification := preload("res://scripts/map/map_verification.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")
const CharacterScale := preload("res://assets/characters/shared/character_scale.gd")


func test_capture_targets_production_lower_town_and_authored_route_anchors() -> void:
	var definition := LowerTownSlice.create()
	assert_eq(definition.map_id, StringName(CaptureScript.MAP_ID))
	assert_true(definition.active, "P0-101 capture must use the active production slice")
	assert_eq(
		CaptureScript.PRESETS.size(),
		5,
		"sector packet must cover all required Lower Town zones"
	)
	var required_sectors := {
		"market_primary_spine": ["vene_street_north", "checkpoint_west"],
		"merchant_craft_lane": ["checkpoint_west", "brewery_door"],
		"service_yard": ["brewery_door", "smithy_door"],
		"eastern_artisan_wet_margin": ["checkpoint_east", "karja_gate_south"],
		"landmark_approaches": ["checkpoint_west", "checkpoint_east"],
	}
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
		var sector_id: String = preset["sector_id"]
		assert_true(required_sectors.has(sector_id), "unexpected sector %s" % sector_id)
		assert_eq(preset["interaction_targets"], required_sectors[sector_id])
		assert_eq(preset["interaction_targets"].size(), 2)
		assert_ne(preset["id"], "smithy_courtyard", "retired authoring spike must not return")
		assert_ne(preset["id"], "whole_map", "whole-map smoke is not a sector preset")


func test_presets_are_deterministic_anchor_midpoint_crops() -> void:
	var definition := LowerTownSlice.create()
	var expected_ids := [
		"market_primary_spine",
		"merchant_craft_lane",
		"service_yard",
		"eastern_artisan_wet_margin",
		"landmark_approaches",
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
	assert_eq(CaptureScript.PRESETS.size() * MapView3D.ALL_TIMES.size(), 10)
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


func test_existing_manifest_records_sector_and_interaction_metadata() -> void:
	var manifest_path := ProjectSettings.globalize_path(CaptureScript.MANIFEST_PATH)
	assert_true(
		FileAccess.file_exists(manifest_path),
		"capture manifest must accompany generated plates"
	)
	if not FileAccess.file_exists(manifest_path):
		return
	var manifest_variant: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	assert_true(manifest_variant is Dictionary, "capture manifest must decode as an object")
	if not manifest_variant is Dictionary:
		return
	var manifest: Dictionary = manifest_variant
	var plates: Array = manifest.get("plates", [])
	assert_eq(plates.size(), CaptureScript.PRESETS.size() * MapView3D.ALL_TIMES.size())
	for preset: Dictionary in CaptureScript.PRESETS:
		var preset_id := String(preset["id"])
		for time_of_day in MapView3D.ALL_TIMES:
			var matching_plates := plates.filter(func(plate: Dictionary) -> bool:
				return (
					String(plate.get("preset_id", "")) == preset_id
					and String(plate.get("time_of_day", "")) == String(time_of_day)
				)
			)
			assert_eq(
				matching_plates.size(),
				1,
				"manifest must contain one plate for %s/%s" % [preset_id, time_of_day]
			)
			if matching_plates.is_empty():
				continue

			var plate: Dictionary = matching_plates[0]
			assert_eq(plate["sector_id"], preset["sector_id"])
			assert_eq(plate["coverage"], preset["coverage"])
			assert_eq(plate["camera_intent"], preset["camera_intent"])
			assert_eq(plate["interaction_targets"], preset["interaction_targets"])
			assert_eq(plate["from_anchor"], String(preset["from_anchor"]))
			assert_eq(plate["to_anchor"], String(preset["to_anchor"]))
			var candidates: Array = plate.get("stable_id_candidates", [])
			assert_true(
				candidates is Array,
				"each plate must link to objective authored stable-ID candidates"
			)
			var candidate_ids: Array[String] = []
			for candidate: Dictionary in candidates:
				assert_true(["building", "view_landmark"].has(candidate.get("kind", "")))
				candidate_ids.append(String(candidate.get("id", "")))
			assert_eq(candidate_ids, candidate_ids.duplicate())
			var sorted_ids := candidate_ids.duplicate()
			sorted_ids.sort()
			assert_eq(candidate_ids, sorted_ids)



func test_existing_manifest_records_current_source_and_explicit_observation_coverage() -> void:
	var manifest_path := ProjectSettings.globalize_path(CaptureScript.MANIFEST_PATH)
	if not FileAccess.file_exists(manifest_path):
		return
	var manifest_variant: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	assert_true(manifest_variant is Dictionary, "capture manifest must decode as an object")
	if not manifest_variant is Dictionary:
		return
	var manifest: Dictionary = manifest_variant
	assert_eq(manifest.get("map_source_sha256", ""), CaptureScript._source_sha256())
	var coverage: Array = manifest.get("stable_id_observation_coverage", [])
	assert_eq(coverage.size(), CaptureScript.PRESETS.size())
	for entry: Dictionary in coverage:
		assert_true(CaptureScript.PRESETS.any(func(preset: Dictionary) -> bool:
			return String(preset["id"]) == String(entry.get("preset_id", ""))
		))
		for time_of_day in MapView3D.ALL_TIMES:
			var observation: Dictionary = entry.get(String(time_of_day), {})
			assert_eq(observation.get("status", ""), "not_reviewed")
			assert_true(observation.get("stable_ids", []) is Array)

func test_existing_capture_packet_outputs_are_present_and_non_blank() -> void:
	var output_dir := ProjectSettings.globalize_path(CaptureScript.OUTPUT_DIR)
	if not DirAccess.dir_exists_absolute(output_dir):
		return
	var manifest_path := ProjectSettings.globalize_path(CaptureScript.MANIFEST_PATH)
	assert_true(
		FileAccess.file_exists(manifest_path),
		"capture manifest must accompany generated plates"
	)
	for preset: Dictionary in CaptureScript.PRESETS:
		for time_of_day in MapView3D.ALL_TIMES:
			var output_path := "%s/%s_%s.png" % [output_dir, preset["id"], time_of_day]
			assert_true(FileAccess.file_exists(output_path), "missing P0-101 plate: %s" % output_path)
			var image := Image.load_from_file(output_path)
			assert_true(image != null, "plate must decode: %s" % output_path)
			if image == null:
				continue
			assert_eq(image.get_size(), CaptureScript.VIEWPORT_SIZE, "plate dimensions: %s" % output_path)
			var pixel_data := image.get_data()
			var has_non_zero_pixel := false
			for byte_value: int in pixel_data:
				if byte_value != 0:
					has_non_zero_pixel = true
					break
			assert_true(has_non_zero_pixel, "plate must contain non-zero pixel data: %s" % output_path)
