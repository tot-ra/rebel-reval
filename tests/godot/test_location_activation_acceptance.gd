extends "res://tests/godot/test_case.gd"

const Gate := preload("res://tools/verify_location_activation.gd")


func test_complete_delivered_candidate_passes() -> void:
	assert_true(Gate.evaluate_candidate(_green_candidate()).is_empty())


func test_advisory_composition_fails_closed() -> void:
	var candidate := _green_candidate()
	candidate["composition"]["enforce"] = false
	_assert_code(candidate, "COMPOSITION_NOT_ENFORCED")


func test_blocked_mandatory_anchor_fails() -> void:
	var candidate := _green_candidate()
	candidate["mandatory_anchors"] = {"status": "FAIL", "blocked": ["world.harju:spawn.main"]}
	_assert_code(candidate, "MANDATORY_ANCHOR_BLOCKED")


func test_missing_landmark_and_gate_affordance_fail() -> void:
	var candidate := _green_candidate()
	candidate["landmarks"]["present"] = []
	candidate["landmarks"]["present_affordances"] = []
	_assert_code(candidate, "LANDMARK_MISSING")
	_assert_code(candidate, "AFFORDANCE_MISSING")


func test_fortification_seam_requires_reciprocal_footprints_and_signed_pairs() -> void:
	var candidate := _green_candidate()
	candidate["fortification_seams"][0]["reciprocal_footprints"] = false
	candidate["fortification_seams"][0]["captures"]["night"]["signed"] = false
	_assert_code(candidate, "FORTIFICATION_SEAM_MISMATCH")
	_assert_code(candidate, "SEAM_CAPTURE_MISSING")


func test_urban_candidate_requires_population_and_activity_profiles() -> void:
	var candidate := _green_candidate()
	candidate["population"]["activity_profile_ids"] = []
	_assert_code(candidate, "URBAN_POPULATION_MISSING")


func test_map_only_inspection_cannot_replace_gameplay_evidence() -> void:
	var candidate := _green_candidate()
	candidate["gameplay"] = {"status": "PASS", "loop_ids": [], "interaction_ids": []}
	_assert_code(candidate, "GAMEPLAY_EVIDENCE_MISSING")


func test_manifest_records_per_map_verdict_and_first_bad_boundary() -> void:
	var green := _green_candidate()
	var red := _green_candidate()
	red["map_id"] = "blocked_map"
	red["implementation_delivered"] = false
	var results := Gate.evaluate_manifest({"maps": [green, red]})
	assert_eq(results["fixture_city"]["verdict"], "GREEN")
	assert_eq(results["fixture_city"]["first_bad_boundary"], "")
	assert_eq(results["blocked_map"]["verdict"], "RED")
	assert_eq(results["blocked_map"]["first_bad_boundary"], "ENVIRONMENT_NOT_DELIVERED")


func _assert_code(candidate: Dictionary, code: String) -> void:
	var errors := Gate.evaluate_candidate(candidate)
	assert_true(
		errors.any(func(error): return String(error).begins_with(code + ":")),
		"Expected %s in %s" % [code, errors]
	)


func _green_candidate() -> Dictionary:
	return {
		"map_id": "fixture_city",
		"implementation_delivered": true,
		"urban": true,
		"composition": {"enforce": true, "status": "PASS"},
		"focused_suites": {
			"compile": "PASS",
			"navigation": "PASS",
			"transitions": "PASS",
			"patrols": "PASS",
		},
		"mandatory_anchors": {"status": "PASS", "blocked": []},
		"landmarks": {
			"required": ["gate_arch"],
			"present": ["gate_arch"],
			"required_affordances": ["gate_arch/GateDoor0"],
			"present_affordances": ["gate_arch/GateDoor0"],
		},
		"fortification_seams": [
			{
				"id": "fixture_seam",
				"reciprocal_footprints": true,
				"captures": {
					"day": {
						"district_a": "a_day.png",
						"district_b": "b_day.png",
						"framing_key": "fixture_day",
						"signed": true,
					},
					"night": {
						"district_a": "a_night.png",
						"district_b": "b_night.png",
						"framing_key": "fixture_night",
						"signed": true,
					},
				},
			}
		],
		"population": {
			"status": "PASS",
			"profile_ids": ["day", "night"],
			"activity_profile_ids": ["market", "watch"],
		},
		"gameplay": {
			"status": "PASS",
			"loop_ids": ["route_loop"],
			"interaction_ids": ["door", "vendor"],
		},
	}
