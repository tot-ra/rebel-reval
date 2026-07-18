extends "res://tests/godot/test_case.gd"


func test_version_one_migrates_without_guessing_world_state() -> void:
	var store := MapStableStateStore.new()
	var legacy := {"version": 1, "phase": "phase.prologue_day", "custom": {"keep": true}}
	assert_true(store.load_payload(legacy).is_empty())
	var saved := store.save_payload()
	assert_eq(saved["save_version"], MapStableStateStore.CURRENT_SAVE_VERSION)
	assert_eq(saved["phase"], "phase.prologue_day")
	assert_eq(saved["custom"], {"keep": true})
	assert_eq(saved["world_state"], {})


func test_entity_survives_unload_reload_and_repartition_without_chunk_identity() -> void:
	var store := MapStableStateStore.new()
	var snapshot := {
		"archetype": "char.example",
		"global_cell": [-1, 33],
		"sub_cell": [0.75, 0.25],
		"state": {"alive": true, "future_field": "retained"},
		"chunk": [-1, 1],
	}
	assert_true(store.record_entity(&"loc.lower_town_slice", &"char.example", snapshot))
	store.set_location_metadata(&"loc.lower_town_slice", "fingerprint-a", 1)
	var first_text := store.canonical_text()
	var payload := store.save_payload()
	var record: Dictionary = payload["world_state"]["loc.lower_town_slice"]["entities"]["char.example"]
	assert_false(record.has("chunk"))

	var restored := MapStableStateStore.new()
	assert_true(restored.load_payload(payload, [&"char.example"], {"loc.lower_town_slice": "fingerprint-a"}).is_empty())
	assert_eq(restored.entity_state(&"loc.lower_town_slice", &"char.example"), record)
	assert_eq(restored.canonical_text(), first_text)
	# Repartitioning changes derived ownership only. The serialized payload stays exact.
	var definition := _definition()
	var index_16 := MapChunkRuntimeIndex.build(definition, 16)
	var index_32 := MapChunkRuntimeIndex.build(definition, 32)
	assert_ne(index_16.owner_for(&"building.crossing"), index_32.owner_for(&"building.crossing"))
	assert_eq(restored.canonical_text(), first_text)


func test_object_delta_merges_updates_and_retains_unknown_fields() -> void:
	var store := MapStableStateStore.new()
	assert_true(store.record_object_delta(&"loc.test", &"gate.main", {"opened": false, "mod_field": {"keep": 7}}))
	assert_true(store.record_object_delta(&"loc.test", &"gate.main", {"opened": true}))
	assert_eq(store.object_delta(&"loc.test", &"gate.main"), {"opened": true, "mod_field": {"keep": 7}})


func test_unknown_archetype_and_fingerprint_mismatch_are_diagnostic_errors() -> void:
	var payload := {
		"save_version": 2,
		"world_state": {
			"loc.test": {
				"map_fingerprint": "old",
				"entities": {
					"char.missing": {
						"archetype": "char.missing",
						"global_cell": [1, 2],
						"sub_cell": [0.0, 0.5],
					}
				},
			}
		},
	}
	var store := MapStableStateStore.new()
	var errors := store.load_payload(payload, [&"char.known"], {"loc.test": "current"})
	assert_eq(errors.size(), 2)
	assert_true(errors[0].contains("fingerprint mismatch"))
	assert_true(errors[1].contains("unknown archetype"))


func test_chunk_index_uses_compiled_stable_ids_and_half_open_bounds() -> void:
	var index := MapChunkRuntimeIndex.build(_definition(), 32)
	var record := index.record(&"building.crossing")
	assert_eq(record["handle"], {"location_id": "loc.chunk_test", "object_id": "building.crossing"})
	assert_eq(record["owner_chunk"], Vector2i(0, 0))
	assert_eq(record["consumer_chunks"], [Vector2i(0, 0), Vector2i(1, 0)])
	assert_false(record["handle"].has("chunk"))


func _definition() -> MapDefinition:
	var definition := MapDefinition.new()
	definition.map_id = &"chunk_test"
	definition.location = &"loc.chunk_test"
	definition.cell_size = 32
	definition.fingerprint = "canonical-fingerprint"
	definition.buildings = [
		{"id": &"building.crossing", "kind": &"house", "footprint": Rect2(31 * 32, 2 * 32, 2 * 32, 2 * 32)},
	]
	return definition
