extends "res://tests/godot/test_case.gd"

## P0-053: slice view3d evidence captures must target production playable maps,
## not the retired smithy_courtyard authoring spike.

const CaptureScript := preload("res://tools/capture_map_view_3d.gd")
const Registry := preload("res://scripts/map/map_audit_registry.gd")


func test_capture_targets_playable_slice_maps_only() -> void:
	var definitions := Registry.by_id()
	for map_id in CaptureScript.MAP_IDS:
		assert_true(
			definitions.has(map_id),
			"capture list must resolve through the audit registry: %s" % map_id
		)
		var definition: MapDefinition = definitions[map_id]
		assert_true(
			definition.active,
			"%s must stay an active playable slice map" % map_id
		)
		assert_ne(
			map_id,
			&"smithy_courtyard",
			"P0-053 evidence must not use the developer-only courtyard spike"
		)


func test_capture_outputs_exist_for_every_time_of_day() -> void:
	var output_dir := ProjectSettings.globalize_path(CaptureScript.OUTPUT_DIR)
	for map_id in CaptureScript.MAP_IDS:
		for time_of_day in MapView3D.ALL_TIMES:
			var output_path := "%s/%s_%s.png" % [output_dir, map_id, time_of_day]
			assert_true(
				FileAccess.file_exists(output_path),
				"missing P0-053 view3d capture: %s" % output_path
			)
