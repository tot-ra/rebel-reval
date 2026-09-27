extends "res://tests/godot/test_case.gd"

## Not in the default suite. The harness loads this probe at startup to prove
## that an assertion after `await` is counted as FAIL. `--filter=` can run it
## alone; that invocation must exit 1.


func test_awaited_assertion_fails() -> void:
	await (Engine.get_main_loop() as SceneTree).process_frame
	assert_true(false, "awaited failure must be counted")
