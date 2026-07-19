extends SceneTree

const TARGETS := [
	"res://tests/godot/test_map_view_3d_mesh.gd",
	"res://tests/godot/test_map_camera_modes.gd",
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures := 0
	for path in TARGETS:
		failures += _run_test_file(path)
	if failures == 0:
		print("Focused tests: PASS")
		quit(0)
	else:
		push_error("Focused tests: %d failure(s)" % failures)
		quit(1)

func _run_test_file(path: String) -> int:
	var script := load(path) as Script
	var instance = script.new()
	var failures := 0
	for method_name in script.get_script_method_list():
		if not String(method_name["name"]).begins_with("test_"):
			continue
		print("RUN %s::%s" % [path, method_name["name"]])
		instance.call(method_name["name"])
		print("  PASS %s" % method_name["name"])
	if instance.has_method("free"):
		instance.free()
	return failures
