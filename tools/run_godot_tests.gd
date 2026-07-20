extends SceneTree

const TEST_ROOT := "res://tests/godot"
const TEST_PREFIX := "test_"
const TEST_SUFFIX := ".gd"
const TEST_CASE_PATH := "res://tests/godot/test_case.gd"

class HarnessLogger:
	extends Logger

	var diagnostics: Array[Dictionary] = []

	func _log_message(message: String, error: bool) -> void:
		if error:
			diagnostics.append({
				"code": message,
				"function": "stderr",
				"file": "",
				"line": 0,
				"rationale": "",
			})

	func _log_error(
		function: String,
		file: String,
		line: int,
		code: String,
		rationale: String,
		_editor_notify: bool,
		error_type: int,
		_script_backtraces: Array[ScriptBacktrace]
	) -> void:
		# Warnings remain visible in Godot output, but only actual engine/script
		# errors invalidate a test. Shutdown-only DEF-002 is handled by the shell
		# wrapper because it is emitted after this SceneTree exits.
		if error_type == Logger.ERROR_TYPE_WARNING:
			return
		diagnostics.append({
			"code": code,
			"function": function,
			"file": file,
			"line": line,
			"rationale": rationale,
		})

	func mark() -> int:
		return diagnostics.size()

	func since(mark_value: int) -> Array[Dictionary]:
		return diagnostics.slice(mark_value)


var _results := {
	"files": 0,
	"tests": 0,
	"failures": 0,
	"errors": 0,
}
var _logger := HarnessLogger.new()


func _initialize() -> void:
	OS.add_logger(_logger)
	call_deferred("_run")


func _run() -> void:
	var test_files := _discover_tests(TEST_ROOT)
	var filter_value := _argument_value("--filter=")
	var filters := filter_value.split(",", false)
	if not filters.is_empty():
		test_files = test_files.filter(func(path: String) -> bool:
			for filter_entry in filters:
				if filter_entry in path:
					return true
			return false
		)
	test_files.sort()
	if test_files.is_empty():
		var filter_suffix := " (filter: %s)" % filter_value if not filter_value.is_empty() else ""
		print("HARNESS ERROR: No Godot tests found under %s matching %s*%s%s" % [TEST_ROOT, TEST_PREFIX, TEST_SUFFIX, filter_suffix])
		_finish(1)
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

	_finish(0 if _results["failures"] == 0 and _results["errors"] == 0 else 1)


func _finish(exit_code: int) -> void:
	OS.remove_logger(_logger)
	quit(exit_code)


func _discover_tests(root_path: String) -> Array[String]:
	var discovered: Array[String] = []
	var dir := DirAccess.open(root_path)
	if dir == null:
		print("HARNESS ERROR: Godot test directory is missing: " + root_path)
		_results["errors"] += 1
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
	var diagnostic_mark := _logger.mark()
	var script := load(path) as Script
	var load_diagnostics := _logger.since(diagnostic_mark)
	if script == null or not load_diagnostics.is_empty():
		_results["errors"] += max(1, load_diagnostics.size())
		print("FILE ERROR %s: could not load script cleanly" % path)
		_print_diagnostics(load_diagnostics, "load")
		return

	diagnostic_mark = _logger.mark()
	var instance = script.new()
	var instance_diagnostics := _logger.since(diagnostic_mark)
	if instance == null or not instance_diagnostics.is_empty():
		_results["errors"] += max(1, instance_diagnostics.size())
		print("FILE ERROR %s: could not instantiate script cleanly" % path)
		_print_diagnostics(instance_diagnostics, "instantiate")
		return

	var methods := _discover_test_methods(instance)
	if methods.is_empty():
		_results["errors"] += 1
		print("FILE ERROR %s: no methods named %s*" % [path, TEST_PREFIX])
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
	var method_diagnostics: Array[Dictionary] = []

	if instance.has_method("before_each"):
		method_diagnostics.append_array(_call_and_capture(instance, "before_each", "before_each"))

	# A failed setup makes the test body unsafe to run, but teardown still gets a
	# chance to release anything setup created before it was interrupted.
	if method_diagnostics.is_empty():
		method_diagnostics.append_array(_call_and_capture(instance, method_name, "test"))

	if instance.has_method("after_each"):
		method_diagnostics.append_array(_call_and_capture(instance, "after_each", "after_each"))

	var failures := _get_instance_failures(instance)
	var new_failures := failures.slice(before_failures)
	if method_diagnostics.is_empty() and new_failures.is_empty():
		print("  PASS %s" % method_name)
		return

	if not method_diagnostics.is_empty():
		_results["errors"] += method_diagnostics.size()
		print("  ERROR %s::%s - %d engine/script diagnostic(s) interrupted clean completion" % [
			path,
			method_name,
			method_diagnostics.size(),
		])
		_print_diagnostics(method_diagnostics, "test lifecycle")

	_results["failures"] += new_failures.size()
	for failure in new_failures:
		print("  FAIL %s::%s - %s" % [path, method_name, failure])


func _call_and_capture(instance: Object, method_name: String, phase: String) -> Array[Dictionary]:
	var diagnostic_mark := _logger.mark()
	instance.call(method_name)
	var captured := _logger.since(diagnostic_mark)
	for diagnostic in captured:
		diagnostic["phase"] = phase
	return captured


func _print_diagnostics(diagnostics: Array[Dictionary], default_phase: String) -> void:
	for diagnostic in diagnostics:
		var location := String(diagnostic.get("file", ""))
		var line := int(diagnostic.get("line", 0))
		if line > 0:
			location += ":%d" % line
		var function := String(diagnostic.get("function", ""))
		if not function.is_empty():
			location += " (%s)" % function
		var rationale := String(diagnostic.get("rationale", ""))
		var detail := String(diagnostic.get("code", ""))
		if not rationale.is_empty():
			detail += " - " + rationale
		print("    [%s] %s: %s" % [diagnostic.get("phase", default_phase), location, detail])


func _get_instance_failures(instance: Object) -> Array[String]:
	if instance.has_method("_get_failures"):
		return instance.call("_get_failures")
	return []


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""
