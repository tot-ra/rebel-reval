extends SceneTree

const TEST_ROOT := "res://tests/godot"
const TEST_PREFIX := "test_"
const TEST_SUFFIX := ".gd"
const TEST_CASE_PATH := "res://tests/godot/test_case.gd"

var _results := {
	"files": 0,
	"tests": 0,
	"failures": 0,
	"errors": 0,
}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var test_files := _discover_tests(TEST_ROOT)
	var filter_value := _argument_value("--filter=")
	if not filter_value.is_empty():
		test_files = test_files.filter(func(path: String) -> bool:
			return filter_value in path
		)
	test_files.sort()
	if test_files.is_empty():
		var filter_suffix := " (filter: %s)" % filter_value if not filter_value.is_empty() else ""
		push_error("No Godot tests found under %s matching %s*%s%s" % [TEST_ROOT, TEST_PREFIX, TEST_SUFFIX, filter_suffix])
		quit(1)
		return

	print("Godot headless tests: discovered %d file(s)." % test_files.size())
	for path in test_files:
		_run_test_file(path)

	print("Godot headless tests: %d file(s), %d test(s), %d failure(s), %d error(s)." % [
		_results["files"],
		_results["tests"],
		_results["failures"],
		_results["errors"],
	])

	if _results["failures"] == 0 and _results["errors"] == 0:
		quit(0)
	else:
		quit(1)

func _discover_tests(root_path: String) -> Array[String]:
	var discovered: Array[String] = []
	var dir := DirAccess.open(root_path)
	if dir == null:
		push_error("Godot test directory is missing: " + root_path)
		return discovered

	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue

		var path := root_path.path_join(entry)
		if dir.current_is_dir():
			discovered.append_array(_discover_tests(path))
		elif path != TEST_CASE_PATH and entry.begins_with(TEST_PREFIX) and entry.ends_with(TEST_SUFFIX):
			discovered.append(path)
		entry = dir.get_next()
	dir.list_dir_end()
	return discovered

func _run_test_file(path: String) -> void:
	var script := load(path) as Script
	if script == null:
		_results["errors"] += 1
		push_error("ERROR %s: could not load script" % path)
		return

	var instance = script.new()
	if instance == null:
		_results["errors"] += 1
		push_error("ERROR %s: could not instantiate script" % path)
		return

	var methods := _discover_test_methods(instance)
	if methods.is_empty():
		_results["errors"] += 1
		push_error("ERROR %s: no methods named %s*" % [path, TEST_PREFIX])
		return

	_results["files"] += 1
	print("RUN %s (%d test(s))" % [path, methods.size()])
	for method_name in methods:
		_run_test_method(path, instance, method_name)

func _discover_test_methods(instance: Object) -> Array[String]:
	var methods: Array[String] = []
	for method in instance.get_method_list():
		var name := String(method.get("name", ""))
		# GDScript reports inherited helper assertions too; only zero-argument
		# methods are runnable tests for this minimal harness.
		if name.begins_with(TEST_PREFIX) and int(method.get("args", []).size()) == 0:
			methods.append(name)
	methods.sort()
	return methods

func _run_test_method(path: String, instance: Object, method_name: String) -> void:
	_results["tests"] += 1
	var before_failures := _get_instance_failures(instance).size()

	if instance.has_method("before_each"):
		instance.call("before_each")
	instance.call(method_name)
	if instance.has_method("after_each"):
		instance.call("after_each")

	var failures := _get_instance_failures(instance)
	var new_failures := failures.slice(before_failures)
	if new_failures.is_empty():
		print("  PASS %s" % method_name)
		return

	_results["failures"] += new_failures.size()
	for failure in new_failures:
		push_error("FAIL %s::%s - %s" % [path, method_name, failure])

func _get_instance_failures(instance: Object) -> Array[String]:
	if instance.has_method("_get_failures"):
		return instance.call("_get_failures")
	return []

func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""
