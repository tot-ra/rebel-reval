extends SceneTree

func _initialize() -> void:
	var suite_script := load("res://tests/godot/test_medieval_animal_models.gd") as Script
	if suite_script == null:
		printerr("FAIL: target suite did not load")
		quit(1)
		return
	var suite: RefCounted = suite_script.new()
	var executed := 0
	for method: Dictionary in suite.get_method_list():
		var method_name := StringName(method.get("name", &""))
		if not String(method_name).begins_with("test_"):
			continue
		suite.call("before_each")
		suite.call(method_name)
		var failures: Array = suite.call("_get_failures") as Array
		suite.call("after_each")
		if not failures.is_empty():
			for failure: String in failures:
				printerr("FAIL %s: %s" % [method_name, failure])
			quit(1)
			return
		executed += 1
	print("TARGET_TESTS_PASSED=%d" % executed)
	quit(0)
