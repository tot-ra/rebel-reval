extends "res://tests/godot/test_case.gd"

const HARNESS_PATH := "res://tools/run_godot_tests.gd"
const FAIL_PROBE_PATH := "res://tests/godot/test_harness_await_fail.gd"


func test_harness_awaits_function_state_before_scoring() -> void:
	var source := FileAccess.get_file_as_string(HARNESS_PATH)
	assert_true(source.contains("await _await_function_state"), "harness must await coroutines")
	assert_true(source.contains("EXPECT_FAIL_STEMS"), "fail probe stays out of default discovery")
	assert_true(source.contains("test_harness_await_fail"))


func test_awaited_probe_failure_is_visible_after_function_state() -> void:
	var probe_script := load(FAIL_PROBE_PATH) as Script
	assert_true(probe_script != null, "fail probe must load")
	var probe: Variant = probe_script.new()
	# Why: Object.call() of a coroutine without await errors in a test body.
	# Await the method; the harness still uses call() plus is_valid() polling.
	await probe.test_awaited_assertion_fails()
	var failures: Array = probe.call("_get_failures")
	assert_true(failures.size() >= 1, "awaited assertion must be recorded")
	assert_true(
		String(failures[0]).contains("awaited failure must be counted"),
		"the probe message must survive the await"
	)
