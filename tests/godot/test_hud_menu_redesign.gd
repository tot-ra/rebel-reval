extends "res://tests/godot/test_case.gd"

const Vitals := preload("res://scripts/ui/player_vitals_hud.gd")
const Settings := preload("res://scripts/ui/game_settings_overlay.gd")

class VitalsOwner:
	extends Node
	var health := 72.0
	var max_health := 100.0
	var stamina := 46.0
	var max_stamina := 100.0


func test_vitals_follow_damage_recovery_restore_and_zero_maximum() -> void:
	var owner := VitalsOwner.new()
	var hud := Vitals.new()
	owner.add_child(hud)
	_tree().root.add_child(owner)
	assert_eq(hud._health.ratio, 0.72)
	assert_eq(hud._stamina.ratio, 0.46)
	owner.health = 20
	owner.stamina = 0
	hud._process(0)
	assert_eq(hud._health.ratio, 0.2)
	assert_eq(hud._stamina.ratio, 0.0)
	owner.health = 100
	owner.stamina = 100
	hud._process(0)
	assert_eq(hud._health.ratio, 1.0)
	hud.set_vitals(150, 100, -20, 0)
	assert_eq(hud._health.ratio, 1.0)
	assert_eq(hud._stamina.ratio, 0.0)
	assert_eq(hud._health_label.text, "HEALTH   100 / 100")
	owner.free()


func test_health_trail_holds_then_drains_and_snaps_on_healing() -> void:
	var owner := VitalsOwner.new()
	var hud := Vitals.new()
	hud.follow_settings = false
	owner.add_child(hud)
	_tree().root.add_child(owner)
	assert_eq(hud._health.trail_ratio, 0.72, "No trail before any damage")
	owner.health = 40
	hud._process(0.1)
	assert_eq(hud._health.ratio, 0.4)
	assert_eq(hud._health.trail_ratio, 0.72, "Trail holds the pre-hit value")
	owner.health = 30
	hud._process(0.1)
	assert_eq(hud._health.trail_ratio, 0.72, "A second hit extends the same trail")
	hud._process(Vitals.TRAIL_HOLD)
	assert_true(hud._health.trail_ratio < 0.72 and hud._health.trail_ratio > 0.3,
		"Trail drains gradually after the hold")
	for _i in 20:
		hud._process(0.1)
	assert_eq(hud._health.trail_ratio, 0.3, "Trail ends at the current health")
	owner.health = 20
	hud._process(0.0)
	owner.health = 90
	hud._process(0.0)
	assert_eq(hud._health.trail_ratio, 0.9, "Healing clears the trail at once")
	hud.reduced_motion = true
	owner.health = 50
	hud._process(0.0)
	hud._process(Vitals.TRAIL_HOLD + 0.01)
	assert_eq(hud._health.trail_ratio, 0.5, "Reduced motion clears the trail without a drain")
	owner.free()


func test_vitals_fade_out_at_rest_and_return_on_change() -> void:
	var owner := VitalsOwner.new()
	owner.health = 100
	owner.stamina = 100
	var hud := Vitals.new()
	hud.follow_settings = false
	owner.add_child(hud)
	_tree().root.add_child(owner)
	var root := hud.get_node("VitalsRoot") as Control
	hud._process(Vitals.FADE_DELAY - 0.5)
	assert_eq(root.modulate.a, 1.0, "Stays visible before the delay")
	hud._process(0.5)
	assert_true(root.modulate.a > 0.0 and root.modulate.a < 1.0, "Fades gradually")
	hud._process(Vitals.FADE_OUT_SECONDS)
	assert_eq(root.modulate.a, 0.0)
	owner.stamina = 90
	hud._process(Vitals.FADE_IN_SECONDS)
	assert_eq(root.modulate.a, 1.0, "Any spend brings the block straight back")
	owner.stamina = 100
	hud._process(Vitals.FADE_DELAY - 0.5)
	owner.health = 99
	hud._process(1.0)
	assert_eq(root.modulate.a, 1.0, "Damage restarts the idle timer")
	hud.reduced_motion = true
	owner.health = 100
	hud._process(Vitals.FADE_DELAY)
	hud._process(0.01)
	assert_eq(root.modulate.a, 0.0, "Reduced motion hides without an alpha ramp")
	owner.health = 10
	hud._process(0.0)
	assert_eq(root.modulate.a, 1.0, "Reduced motion shows again at once")
	owner.free()


func test_player_scene_mounts_hud_and_hides_legacy_bars() -> void:
	# Inspect the packed state without loading a live gameplay scene or saves.
	var scene := load("res://player.tscn") as PackedScene
	var state := scene.get_state()
	var mounted := false
	for index in state.get_node_count():
		var node_name := state.get_node_name(index)
		if node_name == &"PlayerVitalsHud":
			mounted = true
		if node_name in [&"HealthRing", &"StaminaBar"]:
			var hidden := false
			for property in state.get_node_property_count(index):
				if state.get_node_property_name(index, property) == &"visible":
					hidden = not bool(state.get_node_property_value(index, property))
			assert_true(hidden, "Legacy player bars must stay hidden")
	assert_true(mounted)


func test_menu_and_hud_fit_supported_viewports_and_focus() -> void:
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		var viewport := SubViewport.new()
		viewport.size = dimensions
		_tree().root.add_child(viewport)
		var hud := Vitals.new()
		viewport.add_child(hud)
		var menu := Settings.new()
		viewport.add_child(menu)
		menu.open()
		await _tree().process_frame
		await _tree().process_frame
		var panel := menu.find_child("SettingsPanel", true, false) as Control
		assert_true(panel.size.x > 560, "Settings should no longer be a narrow column")
		assert_true(panel.get_global_rect().end.x <= dimensions.x)
		assert_true(panel.get_global_rect().end.y <= dimensions.y)
		var vitals_root := hud.get_node("VitalsRoot") as Control
		assert_eq(vitals_root.get_global_rect().end.y, float(dimensions.y) - Vitals.MARGIN)
		assert_eq(vitals_root.position.x, Vitals.MARGIN)
		assert_eq(vitals_root.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		assert_true(menu._close_button.has_focus(), "Resume must have initial keyboard/pad focus")
		assert_eq(menu._close_button.get_node(menu._close_button.focus_neighbor_right),
			menu._graphics_quality_option)
		var cancel := InputEventAction.new()
		cancel.action = &"ui_cancel"
		cancel.pressed = true
		menu._unhandled_input(cancel)
		assert_false(menu.is_open())
		assert_false(menu.is_in_group(&"modal_input_overlay"))
		viewport.free()


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree
