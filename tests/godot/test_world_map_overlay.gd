extends "res://tests/godot/test_case.gd"

## P1-031: world/district map overlay matches the active transition manifest.
const LowerTownSlice := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const LocalMapView := preload("res://scripts/ui/world_map_local_view.gd")
const FastTravelView := preload("res://scripts/ui/world_map_fast_travel_view.gd")


func before_each() -> void:
	DoorNavigator.load_manifest(true)


func test_graph_nodes_match_active_transition_manifest() -> void:
	var scene_ids := WorldMapGraph.active_scene_ids()
	var manifest_ids := DoorNavigator.get_active_scene_ids()
	assert_true(scene_ids.size() <= manifest_ids.size(), "district graph is a filter of the active manifest")
	for scene_id in scene_ids:
		assert_true(manifest_ids.has(scene_id), "district nodes must stay in the active manifest")
		assert_false(
			GlobalMapCatalog.is_distant_scene(scene_id),
			"global placeholders must stay off the Reval district graph"
		)
	assert_array_contains(scene_ids, &"forge")
	assert_array_contains(scene_ids, &"reval_east")
	assert_false(scene_ids.has(&"harbor_warehouse"), "retired scenes must not appear on the district map")
	assert_false(scene_ids.has(&"archive_only"), "unknown scenes must not appear on the district map")
	assert_false(scene_ids.has(&"world_sacred_grove"), "distant roads belong on the Estonia map tab")
	assert_true(
		DoorNavigator.has_active_scene(&"world_sacred_grove"),
		"global placeholders remain registered for DoorNavigator travel"
	)


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
	assert_eq(scene_ids, WorldMapGraph.active_scene_ids())
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
	var global_button := overlay.find_child("GlobalMapButton", true, false) as Button
	assert_true(local_button != null, "local map must be a visible option")
	assert_true(travel_button != null, "district map must be a visible option")
	assert_true(global_button != null, "estonia map must be a visible option")
	assert_eq(local_button.text, "Local map")
	assert_eq(travel_button.text, "District map")
	assert_eq(global_button.text, "Estonia map")
	assert_true(
		overlay.find_child("LocalMapHost", true, false).get_script() == LocalMapView,
		"stable LocalMapHost must delegate rendering to the focused local-map view"
	)
	assert_true(
		overlay.find_child("GraphHost", true, false).get_script() == FastTravelView,
		"stable GraphHost must delegate rendering and focus to the fast-travel view"
	)
	assert_true(
		overlay.find_child("GlobalMapHost", true, false) != null,
		"stable GlobalMapHost must exist for the Estonia map tab"
	)

	travel_button.pressed.emit()
	assert_eq(overlay.get_mode(), WorldMapOverlay.MODE_FAST_TRAVEL)
	assert_true(overlay.get_node_button(&"forge") != null, "district option must expose the existing Reval graph")
	global_button.pressed.emit()
	assert_eq(overlay.get_mode(), WorldMapOverlay.MODE_GLOBAL)
	assert_true(
		overlay.get_global_node_button(&"world_sacred_grove") != null,
		"estonia map must expose the sacred grove placeholder"
	)
	assert_true(
		overlay.get_global_node_button(GlobalMapCatalog.REVAL_HUB_ID) != null,
		"estonia map must mark Reval as the hub"
	)
	local_button.pressed.emit()
	assert_eq(overlay.get_mode(), WorldMapOverlay.MODE_LOCAL)

	overlay.free()
	local_map.free()
	player.free()


func test_global_map_plans_distant_travel_and_return_gate() -> void:
	var overlay := WorldMapOverlay.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(overlay)
	overlay.configure(&"reval_east")
	overlay.open()
	overlay.show_global_map()

	assert_array_contains(overlay.get_global_travelable_marker_ids(), &"world_sacred_grove")
	assert_array_contains(overlay.get_global_travelable_marker_ids(), &"world_saaremaa")
	assert_false(
		overlay.get_global_travelable_marker_ids().has(GlobalMapCatalog.REVAL_HUB_ID),
		"Reval hub stays non-travel while already inside the town"
	)

	var recorded: Array = []
	overlay.travel_requested.connect(
		func(scene_id: StringName, spawn_id: StringName) -> void:
			recorded.append({"scene_id": scene_id, "spawn_id": spawn_id})
	)
	assert_true(overlay.request_travel_to(&"world_sacred_grove"))
	assert_eq(recorded.size(), 1)
	assert_eq(recorded[0]["scene_id"], &"world_sacred_grove")
	assert_eq(recorded[0]["spawn_id"], &"from_reval_south")

	overlay.configure(&"world_sacred_grove")
	overlay.show_global_map()
	assert_true(
		overlay.get_global_travelable_marker_ids().has(GlobalMapCatalog.REVAL_HUB_ID),
		"distant placeholders must offer a Reval return marker"
	)
	assert_true(overlay.request_travel_to(GlobalMapCatalog.REVAL_HUB_ID))
	assert_eq(recorded.size(), 2)
	assert_eq(recorded[1]["scene_id"], &"reval_south")
	assert_eq(recorded[1]["spawn_id"], &"from_world_sacred_grove")
	overlay.queue_free()


func test_global_map_follows_authored_roads_between_mockups() -> void:
	var overlay := WorldMapOverlay.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(overlay)
	overlay.configure(&"world_harju")
	overlay.open()
	overlay.show_global_map()

	var neighbors := overlay.get_global_travelable_marker_ids()
	assert_array_contains(neighbors, GlobalMapCatalog.REVAL_HUB_ID)
	assert_array_contains(neighbors, &"world_rebel_kings")
	assert_array_contains(neighbors, &"world_kanavere")
	assert_array_contains(neighbors, &"world_sojamae")
	assert_false(neighbors.has(&"world_paide"), "Paide requires a connecting battlefield road")
	var camp_plan := overlay.plan_travel_to(&"world_rebel_kings")
	assert_eq(camp_plan.get("spawn_id", &""), &"from_world_harju")

	overlay.configure(&"world_saaremaa")
	overlay.show_global_map()
	assert_array_contains(overlay.get_global_travelable_marker_ids(), &"world_poide")
	assert_array_contains(overlay.get_global_travelable_marker_ids(), &"world_parnu")
	assert_eq(
		overlay.plan_travel_to(&"world_poide").get("spawn_id", &""),
		&"from_world_saaremaa"
	)
	overlay.queue_free()


func test_global_catalog_edges_have_reciprocal_doors_and_manifest_spawns() -> void:
	for edge in GlobalMapCatalog.connections():
		var from_id: StringName = edge["from"]
		var to_id: StringName = edge["to"]
		if from_id == GlobalMapCatalog.REVAL_HUB_ID or to_id == GlobalMapCatalog.REVAL_HUB_ID:
			continue
		var forward := GlobalMapCatalog.plan_travel(from_id, to_id)
		var reverse := GlobalMapCatalog.plan_travel(to_id, from_id)
		assert_false(forward.is_empty(), "%s -> %s needs a travel plan" % [from_id, to_id])
		assert_false(reverse.is_empty(), "%s -> %s needs a travel plan" % [to_id, from_id])
		assert_true(DoorNavigator.has_spawn(to_id, forward.get("spawn_id", &"")))
		assert_true(DoorNavigator.has_spawn(from_id, reverse.get("spawn_id", &"")))

		var from_definition := DistantLocationDefinitions.create(from_id)
		var to_definition := DistantLocationDefinitions.create(to_id)
		assert_true(_has_destination(from_definition, to_id))
		assert_true(_has_destination(to_definition, from_id))


func _has_destination(definition: MapDefinition, destination_scene_id: StringName) -> bool:
	if definition == null:
		return false
	for transition in definition.transitions:
		if transition.get("destination_scene_id", &"") == destination_scene_id:
			return true
	return false

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
	var guild_plan := WorldMapGraph.plan_travel(&"reval_east", &"st_olafs_guild_hall")
	if WorldMapGraph.allow_all_active_travel():
		assert_eq(guild_plan.get("scene_id", &""), &"st_olafs_guild_hall")
		assert_false(
			String(guild_plan.get("spawn_id", &"")).is_empty(),
			"debug unlock must resolve a fallback spawn for non-adjacent active scenes"
		)
		assert_true(
			DoorNavigator.has_spawn(&"st_olafs_guild_hall", guild_plan["spawn_id"]),
			"debug fallback spawn must be registered in the active manifest"
		)
	else:
		assert_true(
			guild_plan.is_empty(),
			"release builds must refuse non-adjacent travel"
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
	if WorldMapGraph.allow_all_active_travel():
		assert_true(
			overlay.request_travel_to(&"st_olafs_guild_hall"),
			"debug unlock must allow travel to non-adjacent active scenes"
		)
		assert_eq(recorded.size(), 2, "debug non-adjacent travel must emit once")
		assert_eq(recorded[1]["scene_id"], &"st_olafs_guild_hall")
		assert_true(
			DoorNavigator.has_spawn(&"st_olafs_guild_hall", recorded[1]["spawn_id"]),
			"debug non-adjacent travel must use a registered spawn"
		)
	else:
		assert_false(
			overlay.request_travel_to(&"st_olafs_guild_hall"),
			"release builds must refuse disconnected nodes from reval_east"
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
	if WorldMapGraph.allow_all_active_travel():
		var guild_plan := controller.travel_to_scene(&"st_olafs_guild_hall", false)
		assert_eq(guild_plan.get("scene_id", &""), &"st_olafs_guild_hall")
		assert_true(
			DoorNavigator.has_spawn(guild_plan["scene_id"], guild_plan["spawn_id"]),
			"controller debug unlock must use a registered spawn for non-adjacent hops"
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
