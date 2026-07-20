extends "res://tests/godot/test_case.gd"

## P1-031: world/district map overlay matches the active transition manifest.


func before_each() -> void:
	DoorNavigator.load_manifest(true)


func test_graph_nodes_match_active_transition_manifest() -> void:
	var scene_ids := WorldMapGraph.active_scene_ids()
	var manifest_ids := DoorNavigator.get_active_scene_ids()
	assert_eq(scene_ids.size(), manifest_ids.size())
	for index in scene_ids.size():
		assert_eq(scene_ids[index], manifest_ids[index])
	assert_array_contains(scene_ids, &"forge")
	assert_array_contains(scene_ids, &"reval_east")
	assert_false(scene_ids.has(&"harbor_warehouse"), "retired scenes must not appear on the district map")
	assert_false(scene_ids.has(&"archive_only"), "unknown scenes must not appear on the district map")


func test_graph_connections_stay_within_active_manifest() -> void:
	var active: Dictionary = {}
	for scene_id in DoorNavigator.get_active_scene_ids():
		active[scene_id] = true
	var edges := WorldMapGraph.connections()
	assert_true(edges.size() > 0, "authored districts must expose at least one connection")
	var found_forge_edge := false
	for edge in edges:
		var from_id: StringName = edge.get("from", &"")
		var to_id: StringName = edge.get("to", &"")
		assert_true(active.has(from_id), "connection source must be an active manifest scene")
		assert_true(active.has(to_id), "connection destination must be an active manifest scene")
		if (
			(from_id == &"forge" and to_id == &"reval_east")
			or (from_id == &"reval_east" and to_id == &"forge")
		):
			found_forge_edge = true
	assert_true(found_forge_edge, "forge courtyard door must link the smithy to Lower Town")


func test_overlay_highlights_current_scene_and_lists_manifest_nodes() -> void:
	var overlay := WorldMapOverlay.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(overlay)
	overlay.configure(&"reval_east")
	overlay.open()

	assert_true(overlay.is_open())
	assert_eq(overlay.get_current_scene_id(), &"reval_east")
	var scene_ids := overlay.get_scene_ids()
	assert_eq(scene_ids, DoorNavigator.get_active_scene_ids())
	var current := overlay.get_node_button(&"reval_east")
	assert_true(current != null, "current scene must render as a node")
	assert_eq(current.modulate, Color(1.0, 0.86, 0.42, 1.0))
	var subtitle := overlay.find_child("Subtitle", true, false) as Label
	assert_true(subtitle != null)
	assert_true(subtitle.text.contains("Eastern District"))
	overlay.queue_free()


func test_controller_toggles_with_action_and_quick_access_button() -> void:
	assert_true(
		_action_has_physical_key(&"toggle_world_map", KEY_M),
		"world map shortcut must remain M"
	)

	var host := Node.new()
	var controller := WorldMapController.new()
	controller.name = "WorldMapController"
	host.add_child(controller)
	var menu := QuickAccessMenu.new()
	menu.name = "QuickAccessMenu"
	host.add_child(menu)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(host)

	var button := menu.find_child("WorldMapButton", true, false) as Button
	assert_true(button != null, "quick access must expose Districts [M]")
	assert_eq(button.text, "Districts [M]")
	assert_false(button.disabled)

	button.pressed.emit()
	assert_true(controller.is_open(), "mouse quick-access must open the district map")
	button.pressed.emit()
	assert_false(controller.is_open(), "second mouse press must close the district map")

	controller.toggle()
	assert_true(controller.is_open())
	controller.toggle()
	assert_false(controller.is_open())
	host.queue_free()


func test_resolve_current_scene_id_from_scene_path() -> void:
	assert_eq(
		WorldMapGraph.resolve_current_scene_id(null),
		&"",
		"missing scenes resolve to empty"
	)
	var forge_scene: Node = load("res://scenes/reval_east/forge/forge.tscn").instantiate()
	assert_eq(
		WorldMapGraph.resolve_current_scene_id(forge_scene),
		&"forge",
		"forge scene path must resolve to the forge transition id"
	)
	forge_scene.free()

	var unknown := Node.new()
	assert_eq(
		WorldMapGraph.resolve_current_scene_id(unknown),
		&"",
		"nodes without a scene path stay unresolved"
	)
	unknown.free()


func _action_has_physical_key(action: StringName, keycode: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == keycode:
			return true
	return false
