extends "res://tests/godot/test_case.gd"

## P1-031: world/district map overlay matches the active transition manifest.
const LowerTownSlice := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")


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
	overlay.show_fast_travel()

	assert_true(overlay.is_open())
	assert_eq(overlay.get_current_scene_id(), &"reval_east")
	var scene_ids := overlay.get_scene_ids()
	assert_eq(scene_ids, DoorNavigator.get_active_scene_ids())
	var current := overlay.get_node_button(&"reval_east")
	assert_true(current != null, "current scene must render as a node")
	assert_eq(current.modulate, Color(1.0, 0.86, 0.42, 1.0))
	var subtitle := overlay.find_child("Subtitle", true, false) as Label
	assert_true(subtitle != null)
	assert_true(
		subtitle.text.contains(LocationHud.display_name_for_scene(&"reval_east")),
		"subtitle must use the currently curated scene display name"
	)
	overlay.queue_free()
func test_map_mode_opens_on_local_position_with_fast_travel_as_separate_option() -> void:
	var definition: MapDefinition = LowerTownSlice.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	var player := Node2D.new()
	player.name = "Player"
	player.global_position = definition.player_spawn
	var local_map := MinimapHud.new()
	var overlay := WorldMapOverlay.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(player)
	tree.root.add_child(local_map)
	local_map.configure(definition, grid, player)
	tree.root.add_child(overlay)
	overlay.configure(&"reval_east", local_map)
	overlay.open()

	assert_eq(overlay.get_mode(), WorldMapOverlay.MODE_LOCAL, "M map mode must open on the local map")
	assert_true(overlay.get_local_map_texture().texture != null, "local map must reuse compiled minimap data")
	assert_true(overlay.get_local_map_marker().visible, "local map must mark the player's current position")
	var local_button := overlay.find_child("LocalMapButton", true, false) as Button
	var travel_button := overlay.find_child("FastTravelButton", true, false) as Button
	assert_true(local_button != null, "local map must be a visible option")
	assert_true(travel_button != null, "fast travel must be an extra visible option")
	assert_eq(local_button.text, "Local map")
	assert_eq(travel_button.text, "Fast travel")

	travel_button.pressed.emit()
	assert_eq(overlay.get_mode(), WorldMapOverlay.MODE_FAST_TRAVEL)
	assert_true(overlay.get_node_button(&"forge") != null, "fast-travel option must expose the existing district graph")
	local_button.pressed.emit()
	assert_eq(overlay.get_mode(), WorldMapOverlay.MODE_LOCAL)

	overlay.free()
	local_map.free()
	player.free()

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
	assert_true(button != null, "quick access must expose Map [M]")
	assert_eq(button.text, "Map [M]")
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


func test_travel_spawn_resolves_edge_for_reval_east_and_forge() -> void:
	var east_to_forge := WorldMapGraph.resolve_travel_spawn(&"reval_east", &"forge")
	assert_eq(east_to_forge, &"door_courtyard")
	assert_true(
		DoorNavigator.has_spawn(&"forge", east_to_forge),
		"reval_east -> forge spawn must be registered in the active manifest"
	)

	var forge_to_east := WorldMapGraph.resolve_travel_spawn(&"forge", &"reval_east")
	assert_eq(forge_to_east, &"forge")
	assert_true(
		DoorNavigator.has_spawn(&"reval_east", forge_to_east),
		"forge -> reval_east spawn must be registered in the active manifest"
	)

	assert_true(
		WorldMapGraph.resolve_travel_spawn(&"reval_east", &"archive_only").is_empty(),
		"unknown destinations must not resolve a travel spawn"
	)
	assert_true(
		WorldMapGraph.resolve_travel_spawn(&"reval_east", &"reval_east").is_empty(),
		"current scene must not resolve travel to itself"
	)
	assert_true(
		WorldMapGraph.plan_travel(&"reval_east", &"st_olafs_guild_hall").is_empty(),
		"disconnected active scenes must not travel"
	)


func test_click_neighbor_records_go_to_scene_without_traveling_current() -> void:
	var overlay := WorldMapOverlay.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(overlay)
	overlay.configure(&"reval_east")
	overlay.open()
	overlay.show_fast_travel()

	var current := overlay.get_node_button(&"reval_east")
	assert_true(current != null)
	assert_true(current.disabled, "current-scene node stays non-interactive")
	assert_eq(current.mouse_filter, Control.MOUSE_FILTER_IGNORE)

	var forge_button := overlay.get_node_button(&"forge")
	assert_true(forge_button != null)
	assert_false(forge_button.disabled, "forge neighbor must be clickable from reval_east")

	var recorded: Array = []
	overlay.travel_requested.connect(
		func(scene_id: StringName, spawn_id: StringName) -> void:
			recorded.append({"scene_id": scene_id, "spawn_id": spawn_id})
	)
	forge_button.pressed.emit()
	assert_eq(recorded.size(), 1, "neighbor click must request travel")
	assert_eq(recorded[0]["scene_id"], &"forge")
	assert_eq(recorded[0]["spawn_id"], &"door_courtyard")
	assert_true(DoorNavigator.has_spawn(&"forge", recorded[0]["spawn_id"]))

	assert_false(
		overlay.request_travel_to(&"reval_east"),
		"current scene must not travel"
	)
	assert_false(
		overlay.request_travel_to(&"archive_only"),
		"unknown nodes must not travel"
	)
	assert_false(
		overlay.request_travel_to(&"st_olafs_guild_hall"),
		"disconnected nodes must not travel from reval_east"
	)
	assert_eq(recorded.size(), 1, "rejected destinations must not emit travel")

	var controller := WorldMapController.new()
	controller.name = "WorldMapController"
	tree.root.add_child(controller)
	controller.get_overlay().configure(&"reval_east")
	var plan := controller.travel_to_scene(&"forge", false)
	assert_eq(plan.get("scene_id", &""), &"forge")
	assert_eq(plan.get("spawn_id", &""), &"door_courtyard")
	assert_eq(controller.last_travel_request.get("scene_id", &""), &"forge")
	assert_eq(controller.last_travel_request.get("spawn_id", &""), &"door_courtyard")
	assert_true(
		DoorNavigator.has_spawn(
			controller.last_travel_request["scene_id"],
			controller.last_travel_request["spawn_id"]
		),
		"recorded go_to_scene args must use an active manifest spawn"
	)
	assert_true(
		controller.travel_to_scene(&"archive_only", false).is_empty(),
		"controller must refuse unknown destinations"
	)

	overlay.queue_free()
	controller.queue_free()


func test_focus_neighbor_ui_accept_records_same_travel_as_click() -> void:
	var overlay := WorldMapOverlay.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(overlay)
	overlay.configure(&"reval_east")
	overlay.open()
	overlay.show_fast_travel()

	var current := overlay.get_node_button(&"reval_east")
	assert_true(current != null)
	assert_eq(current.focus_mode, Control.FOCUS_NONE, "current-scene node must stay out of the focus ring")
	assert_true(current.disabled, "current-scene node stays non-interactive")
	assert_false(
		overlay.focus_travel_node(&"reval_east"),
		"focus API must refuse the current scene"
	)

	# WHY: open() seeds focus on the first travelable neighbor; clear it before
	# asserting that ui_accept without a travelable focus owner is a no-op.
	tree.root.get_viewport().gui_release_focus()
	assert_false(
		overlay.activate_focused_travel(),
		"ui_accept must not travel when focus is not on a travelable neighbor"
	)

	var recorded: Array = []
	overlay.travel_requested.connect(
		func(scene_id: StringName, spawn_id: StringName) -> void:
			recorded.append({"scene_id": scene_id, "spawn_id": spawn_id})
	)

	assert_true(
		overlay.focus_travel_node(&"forge"),
		"forge neighbor must accept keyboard/gamepad focus from reval_east"
	)
	var forge_button := overlay.get_node_button(&"forge")
	assert_true(forge_button != null)
	assert_eq(tree.root.get_viewport().gui_get_focus_owner(), forge_button)
	assert_true(forge_button.has_focus(), "focused neighbor must own GUI focus")
	var focus_style := forge_button.get_theme_stylebox("focus") as StyleBoxFlat
	var normal_style := forge_button.get_theme_stylebox("normal") as StyleBox
	assert_true(focus_style != null, "focused neighbor must expose an explicit focus style")
	assert_ne(
		focus_style,
		normal_style,
		"focused neighbor style must differ from an unfocused travelable node"
	)
	assert_eq(focus_style.border_color, WorldMapOverlay.TRAVEL_FOCUS_COLOR)
	assert_eq(focus_style.border_width_left, 4, "focus ring must remain visibly thick")
	assert_eq(
		current.modulate,
		Color(1.0, 0.86, 0.42, 1.0),
		"travel focus must not change the current-scene highlight"
	)

	var accept := InputEventAction.new()
	accept.action = &"ui_accept"
	accept.pressed = true
	overlay._unhandled_input(accept)

	assert_eq(recorded.size(), 1, "ui_accept on a focused neighbor must request travel")
	assert_eq(recorded[0]["scene_id"], &"forge")
	assert_eq(recorded[0]["spawn_id"], &"door_courtyard")
	assert_true(
		DoorNavigator.has_spawn(&"forge", recorded[0]["spawn_id"]),
		"focused ui_accept must use the same active manifest spawn as mouse click"
	)

	overlay.queue_free()


func _action_has_physical_key(action: StringName, keycode: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == keycode:
			return true
	return false
