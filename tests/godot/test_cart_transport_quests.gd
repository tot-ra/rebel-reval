extends "res://tests/godot/test_case.gd"

const QUEST_PATHS: Array[String] = [
	"res://content/examples/valid/quest.harbour_barrel_run.json",
	"res://content/examples/valid/quest.viru_abandoned_cart.json",
	"res://content/examples/valid/quest.osmond_sack_smuggle.json",
]
const DIALOGUE_PATHS: Array[String] = [
	"res://content/examples/support/dialogue.carter.harbour_barrel_run.json",
	"res://content/examples/support/dialogue.carter.viru_abandoned_cart.json",
	"res://content/examples/support/dialogue.carter.osmond_sack_smuggle.json",
]


func test_cart_transport_quest_files_are_readable_and_confidence_labelled() -> void:
	for path in QUEST_PATHS:
		var record := _read_record(path)
		assert_eq(record.get("type", ""), "quest")
		assert_eq(record.get("confidence", ""), "plausible composite")
		assert_true((record.get("source_notes", []) as Array).size() >= 1)
		var text := JSON.stringify(record).to_lower()
		assert_false("radsteuer" in text, "%s must not present Radsteuer as attested" % path)
		assert_false("wheel tax" in text, "%s must not present wheel tax as attested" % path)


func test_cart_transport_beats_keep_distinct_resolution_hooks() -> void:
	var harbour := JSON.stringify(_read_record(QUEST_PATHS[0])).to_lower()
	var viru := JSON.stringify(_read_record(QUEST_PATHS[1])).to_lower()
	var osmond := JSON.stringify(_read_record(QUEST_PATHS[2])).to_lower()
	assert_true("6-10 schilling" in harbour)
	assert_true("curfew" in harbour)
	assert_true("dumping" in viru)
	assert_true("private bribe" in osmond)
	assert_true("municipal axle charge" in osmond)


func test_carter_dialogue_files_are_authored_offline() -> void:
	for path in DIALOGUE_PATHS:
		var record := _read_record(path)
		assert_eq(record.get("type", ""), "dialogue")
		assert_eq(record.get("confidence", ""), "plausible composite")
		var offline: Dictionary = record.get("deterministic_offline", {})
		assert_true(bool(offline.get("authored", false)))
		assert_false(bool(offline.get("runtime_llm_allowed", true)))
		assert_false(bool(offline.get("free_text_input_allowed", true)))


func _read_record(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	assert_true(file != null, "missing cart transport content: %s" % path)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	assert_true(parsed is Dictionary, "cart transport content must be a JSON object: %s" % path)
	if not parsed is Dictionary:
		return {}
	return parsed as Dictionary
