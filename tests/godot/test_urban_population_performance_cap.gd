extends "res://tests/godot/test_case.gd"

## R-420: published Lower Town population scenarios must remain within the
## authored renderer capacity and each profile's actor cap.
## WHY: the R-419 evidence manifest is the shipped crowd-density contract;
## this test prevents a future profile or capture update from silently
## exceeding the MultiMesh capacity while keeping logical profile data intact.

const ProfileScript := preload("res://scripts/world/urban_population_profile.gd")
const CrowdRenderer := preload("res://scripts/map/view3d/map_view_crowd_renderer.gd")
const POPULATION_MANIFEST_PATH := "res://docs/reports/population_clusters_r419.json"
const EXPECTED_MAP_ID := "lower_town_slice"
const EXPECTED_RENDERER_CAPACITY := 64


func test_r419_scenarios_fit_renderer_and_profile_caps() -> void:
	var manifest := _load_manifest()
	assert_eq(manifest.get("map_id"), EXPECTED_MAP_ID)
	assert_eq(manifest.get("source"), "res://content/maps/lower_town_slice.rrmap")
	var renderer_capacity := int(manifest.get("capacity", -1))
	assert_eq(renderer_capacity, EXPECTED_RENDERER_CAPACITY)

	var scenarios: Array = manifest.get("scenarios", [])
	assert_eq(scenarios.size(), 3, "R-419 must keep day, market-day, and night scenarios")
	for raw_scenario: Variant in scenarios:
		assert_true(raw_scenario is Dictionary, "each population scenario must be an object")
		if not raw_scenario is Dictionary:
			continue
		var scenario: Dictionary = raw_scenario
		var profile_id := StringName(String(scenario.get("profile_id", "")))
		var phase_id := StringName(String(scenario.get("phase_id", "")))
		var date_value: Variant = scenario.get("date", {})
		assert_true(date_value is Dictionary, "%s date must be an object" % String(profile_id))
		var date: Dictionary = date_value as Dictionary
		var profile := ProfileScript.resolve(profile_id, phase_id, date, int(scenario.get("seed", 0)))
		var active_count := int(scenario.get("active_count", -1))

		assert_eq(profile["profile_id"], profile_id, "%s profile must resolve canonically" % String(profile_id))
		assert_eq(profile["civilian_count"], int(scenario.get("civilian_count", -1)))
		assert_eq(profile["watch_count"], int(scenario.get("watch_count", -1)))
		assert_eq(profile["total_count"], active_count, "%s active count must match its profile" % String(profile_id))
		assert_true(
			active_count <= int(profile["actor_cap"]),
			"profile %s exceeds its authored actor cap" % String(profile_id),
		)
		assert_true(
			active_count <= renderer_capacity,
			"profile %s exceeds the renderer capacity" % String(profile_id),
		)


func test_renderer_capacity_accepts_the_largest_published_scenario() -> void:
	var manifest := _load_manifest()
	var renderer := CrowdRenderer.new()
	renderer.configure(int(manifest.get("capacity", -1)), 2024)
	assert_eq(renderer.capacity(), EXPECTED_RENDERER_CAPACITY)

	var largest_active_count := 0
	for raw_scenario: Variant in manifest.get("scenarios", []):
		if raw_scenario is Dictionary:
			largest_active_count = maxi(largest_active_count, int((raw_scenario as Dictionary).get("active_count", 0)))
	assert_eq(largest_active_count, 33, "market day is the largest published crowd")
	for actor_index in largest_active_count:
		renderer.set_actor_position(actor_index, Vector3(float(actor_index), 0.0, 0.0))

	assert_eq(renderer.active_count(), largest_active_count)
	assert_true(renderer.active_count() <= renderer.capacity())
	renderer.queue_free()


func _load_manifest() -> Dictionary:
	var source := FileAccess.get_file_as_string(POPULATION_MANIFEST_PATH)
	assert_false(source.is_empty(), "R-419 population manifest must be present")
	var parsed: Variant = JSON.parse_string(source)
	assert_true(parsed is Dictionary, "R-419 population manifest must contain a JSON object")
	if not parsed is Dictionary:
		return {}
	return parsed as Dictionary
