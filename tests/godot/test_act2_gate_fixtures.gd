extends "res://tests/godot/test_case.gd"

## Runtime load gate for the P5-010 authored Act 2 save corpus.
## Branch reachability remains covered by the generated package suites; this
## test proves the published fixtures hydrate through SaveEnvelope as well.

func test_every_act2_gate_fixture_loads_and_preserves_branch_identity() -> void:
	var manifest := _load_json_dictionary("res://docs/data/act2_gate_manifest.json")
	var fixtures: Variant = manifest.get("fixtures", [])
	assert_true(fixtures is Array)
	assert_eq((fixtures as Array).size(), 20)
	for entry: Variant in fixtures as Array:
		assert_true(entry is Dictionary)
		var row := entry as Dictionary
		var fixture_id := String(row.get("id", ""))
		var path := SaveEnvelope.released_fixture_path(String(row.get("path", "")))
		var result := SaveEnvelope.parse_file(path)
		assert_true(result["ok"], "%s must load: %s" % [fixture_id, ", ".join(result["errors"])])
		if not result["ok"]:
			continue
		var state := result["state"] as GameState
		assert_eq(String(state.get_phase()), String(row.get("expected_phase", "")))
		assert_eq(
			String(state.get_quest_state(StringName(row.get("expected_quest_id", "")))),
			String(row.get("expected_quest_state", "")),
		)
		for flag_name: Variant in (row.get("expected_flags", {}) as Dictionary).keys():
			assert_true(state.get_flag(StringName(flag_name)))
		for event_id: Variant in row.get("expected_ledger_events", []):
			assert_true(state.has_faction_event(StringName(event_id)))


func _load_json_dictionary(path: String) -> Dictionary:
	var source := FileAccess.get_file_as_string(path)
	if source.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(source)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}
