extends SceneTree

const TestCase := preload("res://tests/godot/test_case.gd")
const Tests := preload("res://tests/godot/test_map_composition_audit.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var runner: TestCase = Tests.new()
	var failures := 0
	for method_info in runner.get_method_list():
		var method_name: String = method_info.name
		if not method_name.begins_with("test_"):
			continue
		print("RUN %s" % method_name)
		runner.before_each()
		runner.call(method_name)
		var method_failures: Array = runner._get_failures()
		if method_failures.is_empty():
			print("  PASS %s" % method_name)
		else:
			failures += method_failures.size()
			for message in method_failures:
				print("  FAIL %s: %s" % [method_name, message])
	print("composition audit tests: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
