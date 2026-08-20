extends SceneTree
## Fail-closed acceptance evaluator for candidate location activation.
##
## The manifest is evidence, not an activation switch. A map becomes eligible only
## when every independent boundary is explicitly green; omitted fields fail closed.

const DEFAULT_MANIFEST := "res://docs/data/location_activation_manifest.json"
const REQUIRED_SUITES := ["compile", "navigation", "transitions", "patrols"]


static func evaluate_candidate(candidate: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var map_id := String(candidate.get("map_id", "<missing-map-id>"))
	if not candidate.get("implementation_delivered", false):
		errors.append("ENVIRONMENT_NOT_DELIVERED: %s owning implementation row is not delivered" % map_id)

	var composition: Dictionary = candidate.get("composition", {})
	if not composition.get("enforce", false):
		errors.append("COMPOSITION_NOT_ENFORCED: %s realism thresholds cannot be advisory" % map_id)
	if not _status_passes(composition.get("status")):
		errors.append("COMPOSITION_FAILED: %s composition audit is not green" % map_id)

	var suites: Dictionary = candidate.get("focused_suites", {})
	for suite_name in REQUIRED_SUITES:
		if not _status_passes(suites.get(suite_name)):
			errors.append("FOCUSED_SUITE_FAILED: %s %s suite is not green" % [map_id, suite_name])

	var anchors: Dictionary = candidate.get("mandatory_anchors", {})
	if not _status_passes(anchors.get("status")) or not anchors.get("blocked", []).is_empty():
		errors.append(
			"MANDATORY_ANCHOR_BLOCKED: %s has blocked, missing, or unreachable anchors"
			% map_id
		)

	var landmarks: Dictionary = candidate.get("landmarks", {})
	var required_landmarks: Array = landmarks.get("required", [])
	var present_landmarks: Array = landmarks.get("present", [])
	var missing_landmarks := _missing_values(required_landmarks, present_landmarks)
	if not missing_landmarks.is_empty():
		errors.append("LANDMARK_MISSING: %s missing %s" % [map_id, ", ".join(missing_landmarks)])
	var required_affordances: Array = landmarks.get("required_affordances", [])
	var present_affordances: Array = landmarks.get("present_affordances", [])
	var missing_affordances := _missing_values(required_affordances, present_affordances)
	if not missing_affordances.is_empty():
		errors.append("AFFORDANCE_MISSING: %s missing %s" % [map_id, ", ".join(missing_affordances)])

	for seam_value in candidate.get("fortification_seams", []):
		var seam: Dictionary = seam_value
		var seam_id := String(seam.get("id", "<missing-seam-id>"))
		if not seam.get("reciprocal_footprints", false):
			errors.append(
				"FORTIFICATION_SEAM_MISMATCH: %s seam %s footprints are not reciprocal"
				% [map_id, seam_id]
			)
		for phase in ["day", "night"]:
			var capture: Dictionary = seam.get("captures", {}).get(phase, {})
			if not _matched_signed_capture(capture):
				errors.append(
					"SEAM_CAPTURE_MISSING: %s seam %s lacks matched signed %s captures"
					% [map_id, seam_id, phase]
				)

	if candidate.get("urban", false):
		var population: Dictionary = candidate.get("population", {})
		if not _status_passes(population.get("status")):
			errors.append(
				"URBAN_POPULATION_MISSING: %s population acceptance is not green" % map_id
			)
		var profiles_missing: bool = population.get("profile_ids", []).is_empty()
		var activities_missing: bool = population.get("activity_profile_ids", []).is_empty()
		if profiles_missing or activities_missing:
			errors.append(
				"URBAN_POPULATION_MISSING: %s needs authored population and activity profiles"
				% map_id
			)

	var gameplay: Dictionary = candidate.get("gameplay", {})
	if not _status_passes(gameplay.get("status")):
		errors.append(
			"GAMEPLAY_EVIDENCE_MISSING: %s gameplay-loop acceptance is not green" % map_id
		)
	var loops_missing: bool = gameplay.get("loop_ids", []).is_empty()
	var interactions_missing: bool = gameplay.get("interaction_ids", []).is_empty()
	if loops_missing or interactions_missing:
		errors.append(
			"GAMEPLAY_EVIDENCE_MISSING: %s needs representative loops and interactions" % map_id
		)
	return errors


static func evaluate_manifest(manifest: Dictionary) -> Dictionary:
	var results: Dictionary = {}
	for candidate_value in manifest.get("maps", []):
		var candidate: Dictionary = candidate_value
		var map_id := String(candidate.get("map_id", ""))
		var errors := evaluate_candidate(candidate)
		results[map_id] = {
			"verdict": "GREEN" if errors.is_empty() else "RED",
			"errors": errors,
			"first_bad_boundary": "" if errors.is_empty() else _error_code(errors[0]),
		}
	return results


static func _status_passes(value: Variant) -> bool:
	return String(value).to_upper() in ["PASS", "GREEN", "ACCEPTED"]


static func _missing_values(required: Array, present: Array) -> Array[String]:
	var missing: Array[String] = []
	for value in required:
		if value not in present:
			missing.append(String(value))
	return missing


static func _matched_signed_capture(capture: Dictionary) -> bool:
	return (
		not String(capture.get("district_a", "")).is_empty()
		and not String(capture.get("district_b", "")).is_empty()
		and not String(capture.get("framing_key", "")).is_empty()
		and capture.get("signed", false)
	)


static func _error_code(error: String) -> String:
	return error.get_slice(":", 0)


func _init() -> void:
	var manifest_path := DEFAULT_MANIFEST
	var requested_map := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--manifest="):
			manifest_path = argument.trim_prefix("--manifest=")
		elif argument.begins_with("--map="):
			requested_map = argument.trim_prefix("--map=")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not parsed is Dictionary:
		printerr("ERROR: invalid location activation manifest: %s" % manifest_path)
		quit(1)
		return
	var results := evaluate_manifest(parsed)
	if not requested_map.is_empty() and not results.has(requested_map):
		printerr("ERROR: unknown activation candidate: %s" % requested_map)
		quit(1)
		return
	var red_count := 0
	for map_id in results:
		if not requested_map.is_empty() and map_id != requested_map:
			continue
		var result: Dictionary = results[map_id]
		print("%s %s first_bad_boundary=%s" % [result["verdict"], map_id, result["first_bad_boundary"]])
		for error in result["errors"]:
			print("  %s" % error)
		if result["verdict"] == "RED":
			red_count += 1
	# Inventory mode documents current verdicts and succeeds. Selecting a candidate
	# is the promotion gate and therefore fails while that candidate is red.
	quit(1 if not requested_map.is_empty() and red_count > 0 else 0)
