extends "res://tests/godot/test_case.gd"

const EndingModelScript := preload("res://scripts/quest/act3_ending_model.gd")


func test_manifest_and_matrix_are_complete() -> void:
	var manifest_result: Dictionary = EndingModelScript.validate_manifest()
	assert_true(manifest_result["valid"], str(manifest_result["errors"]))
	var matrix_result: Dictionary = EndingModelScript.validate_matrix()
	assert_true(matrix_result["valid"], str(matrix_result["errors"]))
	assert_eq(int(matrix_result["choice_count"]), 3)
	assert_eq(int(matrix_result["character_count"]), 7)
	assert_eq(int(matrix_result["faction_count"]), 8)
	assert_eq(int(matrix_result["district_count"]), 2)


func test_each_choice_records_the_1346_sale_and_all_epilogues() -> void:
	for choice: StringName in EndingModelScript.FINAL_CHOICES:
		var ending: Dictionary = EndingModelScript.build_ending_for_choice(choice)
		var validation: Dictionary = EndingModelScript.validate_ending(ending)
		assert_true(validation["valid"], "%s: %s" % [String(choice), str(validation["errors"])])
		assert_eq(int(ending["sale_year"]), 1346)
		assert_eq(String(ending["sale_event"]), "event.sale_estonia_1346")
		assert_eq((ending["characters"] as Dictionary).size(), 7)
		assert_eq((ending["factions"] as Dictionary).size(), 8)
		assert_eq((ending["districts"] as Dictionary).size(), 2)
		assert_false(ending.has("morality"))
		assert_false(ending.has("morality_score"))


func test_unrelated_component_rows_cannot_be_mixed_between_choices() -> void:
	var rebuild := EndingModelScript.build_ending_for_choice(EndingModelScript.CHOICE_REBUILD)
	var occupation := EndingModelScript.build_ending_for_choice(EndingModelScript.CHOICE_SERVE_ORDER)
	var mixed := rebuild.duplicate(true)
	mixed["final_choice"] = String(EndingModelScript.CHOICE_SERVE_ORDER)
	mixed["ending_family"] = occupation["ending_family"]
	mixed["forge"] = occupation["forge"]
	var validation: Dictionary = EndingModelScript.validate_ending(mixed)
	assert_false(validation["valid"])
	assert_true(str(validation["errors"]).contains("characters.char.kalev"))


func test_unknown_choice_and_forbidden_aggregate_are_rejected() -> void:
	assert_eq(EndingModelScript.build_ending_for_choice(&"choice.unknown"), {})
	var ending := EndingModelScript.build_ending_for_choice(EndingModelScript.CHOICE_HIDE_HAMMER)
	ending["morality_score"] = 1
	var validation: Dictionary = EndingModelScript.validate_ending(ending)
	assert_false(validation["valid"])
	assert_true(str(validation["errors"]).contains("morality_score"))
