extends "res://tests/godot/test_case.gd"

## Overhead named-NPC marker (docs/SYSTEMS/NAMED_NPCS.md, task R-1564):
## state -> glyph/visibility, distance fade and scale, suppression in dialogue,
## the settings toggle and the faction tint that never changes the shape.

const NPC := {"id": "char.test", "faction": "faction.hanseatic", "marker": "available"}


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _marker(npc: Dictionary = NPC) -> NamedNpcMarker:
	var marker := NamedNpcMarker.new()
	marker.setup(npc, 1.0)
	return marker


func test_registry_value_maps_to_state() -> void:
	assert_eq(NamedNpcMarker.state_from_registry("available"), NamedNpcMarker.State.AVAILABLE)
	assert_eq(NamedNpcMarker.state_from_registry("none"), NamedNpcMarker.State.NONE)
	assert_eq(NamedNpcMarker.state_from_registry(null), NamedNpcMarker.State.NONE)


func test_shape_carries_the_meaning() -> void:
	assert_eq(NamedNpcMarker.glyph_for(NamedNpcMarker.State.AVAILABLE), "!")
	assert_eq(NamedNpcMarker.glyph_for(NamedNpcMarker.State.QUEST_READY), "?")
	assert_eq(NamedNpcMarker.glyph_for(NamedNpcMarker.State.SPOKEN), "!")
	assert_eq(NamedNpcMarker.glyph_for(NamedNpcMarker.State.NONE), "")
	# Every faction tint keeps the same glyph: colour is decoration only.
	for faction: String in NamedNpcMarker.FACTION_TINT:
		var marker := _marker({"id": "char.x", "faction": faction, "marker": "available"})
		assert_eq(marker._glyph.text, "!", "glyph for %s" % faction)
		marker.free()


func test_tint_differs_by_faction_and_falls_back() -> void:
	assert_true(
		NamedNpcMarker.tint_for("faction.church") != NamedNpcMarker.tint_for("faction.hanseatic")
	)
	assert_eq(NamedNpcMarker.tint_for(null), NamedNpcMarker.DEFAULT_TINT)


func test_distance_fade_and_scale() -> void:
	assert_eq(NamedNpcMarker.distance_alpha(5.0), 1.0)
	assert_eq(NamedNpcMarker.distance_alpha(NamedNpcMarker.FADE_END), 0.0)
	var mid := NamedNpcMarker.distance_alpha(36.0)
	assert_true(mid > 0.0 and mid < 1.0, "half faded at 36 m, got %s" % mid)
	assert_eq(NamedNpcMarker.distance_scale(1.0), 1.0)
	assert_eq(NamedNpcMarker.distance_scale(500.0), NamedNpcMarker.MAX_SCALE)


func test_visibility_rule() -> void:
	var avail := NamedNpcMarker.State.AVAILABLE
	assert_true(NamedNpcMarker.wants_visible(avail, true, false, 10.0))
	assert_false(NamedNpcMarker.wants_visible(avail, true, false, 45.0), "beyond fade range")
	assert_false(NamedNpcMarker.wants_visible(avail, false, false, 10.0), "setting off")
	assert_false(NamedNpcMarker.wants_visible(avail, true, true, 10.0), "dialogue or cutscene")
	assert_false(NamedNpcMarker.wants_visible(NamedNpcMarker.State.NONE, true, false, 10.0))


func test_none_state_stays_hidden_on_the_node() -> void:
	var marker := _marker({"id": "char.y", "faction": null, "marker": "none"})
	marker.update_presence(5.0, false, 0.016)
	assert_false(marker.visible)
	marker.free()


func test_node_hides_in_dialogue_group_and_returns() -> void:
	var marker := _marker()
	marker.update_presence(5.0, false, 0.016)
	assert_true(marker.visible)
	var probe := Node.new()
	probe.add_to_group(&"demo_dialogue_active")
	_tree().root.add_child(probe)
	assert_true(NamedNpcMarker.suppressed_in(_tree()), "dialogue group suppresses")
	probe.remove_from_group(&"demo_dialogue_active")
	probe.free()
	assert_false(NamedNpcMarker.suppressed_in(_tree()))
	marker.free()


func test_setting_toggle_hides_the_marker() -> void:
	var marker := _marker()
	var original: GameplayAccessibilitySettings = UserSettings.gameplay.duplicate_settings()
	var off := original.duplicate_settings()
	off.show_npc_markers = false
	UserSettings.apply_gameplay_accessibility_settings(off, false)
	marker.update_presence(5.0, false, 0.016)
	assert_false(marker.visible, "hidden with the setting off")
	UserSettings.apply_gameplay_accessibility_settings(original, false)
	marker.update_presence(5.0, false, 0.016)
	assert_true(marker.visible, "shown again with the setting on")
	marker.free()


func test_setting_round_trips_and_defaults_on() -> void:
	assert_true(GameplayAccessibilitySettings.default_settings().show_npc_markers)
	var off := GameplayAccessibilitySettings.default_settings()
	off.show_npc_markers = false
	assert_false(GameplayAccessibilitySettings.from_dict(off.to_dict()).show_npc_markers)
	assert_true(GameplayAccessibilitySettings.from_dict({}).show_npc_markers, "old saves default on")
