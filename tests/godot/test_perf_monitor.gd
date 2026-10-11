extends "res://tests/godot/test_case.gd"

const PerfMonitorScript := preload("res://scripts/debug/perf_monitor.gd")
const PerfProbeScript := preload("res://scripts/debug/perf_probe.gd")


func after_each() -> void:
	PerfProbeScript.enabled = false
	PerfProbeScript.take_frame()
	super.after_each()


func test_probe_costs_nothing_while_closed() -> void:
	PerfProbeScript.enabled = false
	var started: int = PerfProbeScript.start()
	assert_eq(started, 0, "a closed overlay must not read the clock")
	PerfProbeScript.stop(&"closed_scope", started)
	assert_true(PerfProbeScript.take_frame().is_empty(), "nothing recorded while closed")


func test_probe_accumulates_and_resets() -> void:
	PerfProbeScript.enabled = true
	var started: int = PerfProbeScript.start()
	assert_true(started > 0, "an open overlay starts a scope")
	OS.delay_usec(300)
	PerfProbeScript.stop(&"work", started)
	PerfProbeScript.stop(&"work", PerfProbeScript.start())
	var frame: Dictionary = PerfProbeScript.take_frame()
	assert_true(int(frame.get(&"work", 0)) >= 300, "scope time is summed per frame")
	assert_true(PerfProbeScript.take_frame().is_empty(), "take_frame resets the counters")


func test_f3_cycles_modes_and_switches_the_probe() -> void:
	var monitor := PerfMonitorScript.new()
	_tree().root.add_child(monitor)
	assert_eq(monitor.mode, PerfMonitorScript.OFF, "starts hidden")
	_press(monitor, KEY_F3)
	assert_eq(monitor.mode, PerfMonitorScript.COMPACT)
	assert_true(monitor.visible)
	assert_false(PerfProbeScript.enabled, "compact does not probe systems")
	_press(monitor, KEY_F3)
	assert_eq(monitor.mode, PerfMonitorScript.FULL)
	assert_true(PerfProbeScript.enabled, "full probes systems")
	_press(monitor, KEY_F3)
	assert_eq(monitor.mode, PerfMonitorScript.OFF)
	assert_false(monitor.visible)
	assert_false(PerfProbeScript.enabled)
	monitor.free()


func test_panel_text_covers_every_section() -> void:
	var monitor := PerfMonitorScript.new()
	_tree().root.add_child(monitor)
	monitor.mode = PerfMonitorScript.FULL
	monitor._apply_mode()
	var text: String = monitor._compose()
	for needle in ["FPS", "render CPU", "CPU systems", "Memory", "Layers", "quality"]:
		assert_true(text.contains(needle), "panel shows %s" % needle)
	monitor.mode = PerfMonitorScript.OFF
	monitor._apply_mode()
	monitor.free()


func test_layer_toggle_is_remembered_and_cleared_on_close() -> void:
	var monitor := PerfMonitorScript.new()
	_tree().root.add_child(monitor)
	monitor.mode = PerfMonitorScript.FULL
	monitor._apply_mode()
	monitor.toggle_layer("grass")
	assert_true(bool(monitor._layer_off.get("grass", false)))
	monitor.toggle_layer("grass")
	assert_false(bool(monitor._layer_off.get("grass", false)))
	monitor.toggle_layer("trees")
	monitor.mode = PerfMonitorScript.OFF
	monitor._apply_mode()
	assert_true(monitor._layer_off.is_empty(), "closing the overlay restores every layer")
	monitor.free()


func _press(monitor: Node, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	monitor._input(event)


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func test_number_keys_toggle_layers_by_physical_key_with_option_held() -> void:
	var monitor := PerfMonitorScript.new()
	_tree().root.add_child(monitor)
	monitor.mode = PerfMonitorScript.FULL
	monitor._apply_mode()
	# macOS: Option+1 reports a symbol keycode, the physical key stays KEY_1.
	var event := InputEventKey.new()
	event.keycode = KEY_EXCLAM
	event.physical_keycode = KEY_1
	event.alt_pressed = true
	event.pressed = true
	monitor._input(event)
	assert_true(bool(monitor._layer_off.get("grass", false)), "Alt+1 switches the first layer")
	monitor.mode = PerfMonitorScript.OFF
	monitor._apply_mode()
	monitor.free()
