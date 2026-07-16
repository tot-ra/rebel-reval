extends SceneTree

const TEST_SCRIPT := preload("res://tests/godot/test_character_rig.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var test_case = TEST_SCRIPT.new()
	var tests: Array[StringName] = []
	for method: Dictionary in test_case.get_method_list():
		var method_name := StringName(method.get("name", ""))
		if String(method_name).begins_with("test_") and method.get("args", []).is_empty():
			tests.append(method_name)
	tests.sort()
	for test_name: StringName in tests:
		test_case.call(test_name)
		await process_frame
	var failures: Array[String] = test_case._get_failures()
	if not failures.is_empty():
		for failure: String in failures:
			push_error("P0-037: %s" % failure)
		quit(1)
		return
	print("P0-037 character rig: %d contract tests passed." % tests.size())
	quit(0)

