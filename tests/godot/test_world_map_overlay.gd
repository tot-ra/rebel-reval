extends "res://tests/godot/test_case.gd"

## P1-031: world/district map overlay matches the active transition manifest.


class TestReflectionController:
	extends ReflectionController

	var opened := false

	func _ready() -> void:
		pass

	func open() -> void:
		opened = true

	func is_open() -> bool:
		return opened

	func close() -> void:
		opened = false


class TestWorldMapOverlay:
	extends WorldMapOverlay

	func _ready() -> void:
		pass

	func configure(_current_scene_id: StringName = &"", _local_map: MinimapHud = null) -> void:
		pass

	func open() -> void:
		visible = true


# The Lower Town slice factory was retired with the .rrmap city rewrite; the minimap
# only needs any compiled MapDefinition, so use the surviving smithy interior.
const LocalMapDefinition := preload(
	"res://scripts/map/definitions/lower_town/kalev_smithy_definition.gd"
)
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const LocalMapView := preload("res://scripts/ui/world_map_local_view.gd")
const CityMapView := preload("res://scripts/ui/world_map_city_view.gd")


func before_each() -> void:
	DoorNavigator.load_manifest(true)


func test_graph_nodes_match_active_transition_manifest() -> void:
	var scene_ids := WorldMapGraph.active_scene_ids()
	var manifest_ids := DoorNavigator.get_active_scene_ids()
	assert_true(
		scene_ids.size() <= manifest_ids.size(), "district graph is a filter of the active manifest"
	)
	for scene_id in scene_ids:
		assert_true(manifest_ids.has(scene_id), "district nodes must stay in the active manifest")
		assert_false(
			GlobalMapCatalog.is_distant_scene(scene_id),
			"global placeholders stay off the Reval district graph"
		)
	assert_false(scene_ids.has(&"forge"), "the standalone forge is not a travel node")
	assert_false(scene_ids.has(&"reval_city"), "the city is displayed as its places")
	assert_false(scene_ids.has(&"harbor_warehouse"))
	assert_false(scene_ids.has(&"archive_only"))
	assert_false(scene_ids.has(&"world_sacred_grove"))
	assert_true(DoorNavigator.has_active_scene(&"world_sacred_grove"))


func test_graph_connections_stay_within_active_manifest() -> void:
	var active: Dictionary = {}
	for scene_id in DoorNavigator.get_active_scene_ids():
		active[scene_id] = true
	var edges := WorldMapGraph.connections()
	for edge in edges:
		assert_true(active.has(edge.get("from", &"")), "connection source must be active")
		assert_true(active.has(edge.get("to", &"")), "connection destination must be active")


func test_overlay_marks_nearest_place_as_current_on_the_reval_map() -> void:
	var overlay := WorldMapOverlay.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(overlay)
	overlay.configure(CityTravel.CITY_SCENE_ID)
	overlay.open()
	overlay.show_fast_travel()
	overlay._fast_travel_view.configure_city(
		CityTravel.CITY_SCENE_ID,
		{&"city_forum": &"poi.forum", &"city_kalev_smithy": &"kalev_smithy"},
		&"city_forum"
	)

	assert_true(overlay.is_open())
	var current := overlay.get_node_button(&"city_forum")
	assert_true(current != null, "the place the player stands at must render as a node")
	assert_true(current.disabled, "current place stays non-interactive")
	assert_eq(current.focus_mode, Control.FOCUS_NONE)
	assert_false(
		overlay.focus_travel_node(&"city_forum"), "focus API must refuse the current place"
	)
	assert_true(overlay.get_node_button(&"city_kalev_smithy") != null)
	overlay.queue_free()


func test_map_mode_opens_on_local_position_with_fast_travel_as_separate_option() -> void:
	var definition: MapDefinition = LocalMapDefinition.create()
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

	assert_eq(
		overlay.get_mode(), WorldMapOverlay.MODE_LOCAL, "M map mode must open on the local map"
	)
	assert_true(
		overlay.get_local_map_texture().texture != null,
		"local map must reuse compiled minimap data"
	)
	assert_true(
		overlay.get_local_map_marker().visible, "local map must mark the player's current position"
	)
	var local_button := overlay.find_child("LocalMapButton", true, false) as Button
	var travel_button := overlay.find_child("FastTravelButton", true, false) as Button
	var global_button := overlay.find_child("GlobalMapButton", true, false) as Button
	assert_true(local_button != null, "local map must be a visible option")
	assert_true(travel_button != null, "district map must be a visible option")
	assert_true(global_button != null, "estonia map must be a visible option")
	assert_eq(local_button.text, "Local map")
	assert_eq(travel_button.text, "Reval map")
	assert_eq(global_button.text, "Estonia map")
	assert_true(
		overlay.find_child("LocalMapHost", true, false).get_script() == LocalMapView,
		"stable LocalMapHost must delegate rendering to the focused local-map view"
	)
	assert_true(
		overlay.find_child("GraphHost", true, false).get_script() == CityMapView,
		"stable GraphHost must delegate rendering and focus to the Reval map view"
	)
	assert_true(
		overlay.find_child("GlobalMapHost", true, false) != null,
		"stable GlobalMapHost must exist for the Estonia map tab"
	)

	travel_button.pressed.emit()
	assert_eq(overlay.get_mode(), WorldMapOverlay.MODE_FAST_TRAVEL)
	assert_true(
		overlay.get_node_button(&"city_forum") != null,
		"Reval map option must expose the key city places"
	)
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
	assert_eq(overlay.plan_travel_to(&"world_poide").get("spawn_id", &""), &"from_world_saaremaa")
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
		assert_true(
			_has_destination(from_definition, to_id), "%s needs a door to %s" % [from_id, to_id]
		)
		assert_true(
			_has_destination(to_definition, from_id), "%s needs a door to %s" % [to_id, from_id]
		)


func test_every_distant_gate_plans_a_return_into_the_city() -> void:
	for edge in GlobalMapCatalog.connections():
		if edge["to"] != GlobalMapCatalog.REVAL_HUB_ID:
			continue
		var plan := GlobalMapCatalog.plan_travel(edge["from"], GlobalMapCatalog.REVAL_HUB_ID)
		assert_false(plan.is_empty(), "%s -> Reval needs a travel plan" % edge["from"])
		assert_eq(plan.get("scene_id", &""), &"reval_city")
		assert_true(DoorNavigator.has_spawn(plan.get("scene_id", &""), plan.get("spawn_id", &"")))


func _has_destination(definition: MapDefinition, destination_scene_id: StringName) -> bool:
	if definition == null:
		return false
	for transition in definition.transitions:
		if transition.get("destination_scene_id", &"") == destination_scene_id:
			return true
	return false


func test_controller_toggles_with_action_and_quick_access_button() -> void:
	assert_true(
		_action_has_physical_key(&"toggle_world_map", KEY_M), "world map shortcut must remain M"
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


func test_opening_world_map_closes_reflection_overlay() -> void:
	# WHY: every global overlay must leave only one modal surface active.
	var host := Node.new()
	var reflection := TestReflectionController.new()
	reflection.name = "ReflectionController"
	host.add_child(reflection)
	var controller := WorldMapController.new()
	controller.name = "WorldMapController"
	host.add_child(controller)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(host)
	var map_overlay := TestWorldMapOverlay.new()
	map_overlay.visible = false
	controller._overlay = map_overlay

	reflection.open()
	assert_true(reflection.is_open(), "reflection overlay must be open before map takeover")
	controller.open()
	assert_false(
		reflection.is_open(), "opening the world map must close an already-open reflection overlay"
	)
	assert_true(controller.is_open(), "world map must remain open after closing reflection")
	host.queue_free()
	map_overlay.free()


func test_resolve_current_scene_id_from_scene_path() -> void:
	assert_eq(WorldMapGraph.resolve_current_scene_id(null), &"", "missing scenes resolve to empty")
	var forge_scene: Node = load("res://scenes/reval_east/forge/forge.tscn").instantiate()
	assert_eq(
		WorldMapGraph.resolve_current_scene_id(forge_scene),
		&"forge",
		"forge scene path must resolve to the forge transition id"
	)
	forge_scene.free()

	# Regression: distant locations must resolve too, or the way back to Reval is lost.
	for distant_id in [&"world_harju", &"world_padise"]:
		var distant_path := DoorNavigator.get_scene_path(distant_id)
		if distant_path.is_empty() or not DoorNavigator.has_active_scene(distant_id):
			continue
		var distant_scene: Node = load(distant_path).instantiate()
		assert_eq(
			WorldMapGraph.resolve_current_scene_id(distant_scene),
			distant_id,
			"distant scene %s must resolve to its own id" % distant_id
		)
		distant_scene.free()

	var unknown := Node.new()
	assert_eq(
		WorldMapGraph.resolve_current_scene_id(unknown),
		&"",
		"nodes without a scene path stay unresolved"
	)
	unknown.free()

	# Verify the legacy Smithy courtyard arrival now routes directly into the city.
	var routed: Array = CityTravel.redirect(&"forge", &"door_courtyard")
	assert_eq(routed, [CityTravel.CITY_SCENE_ID, &"kalev_smithy"])


func test_click_place_records_city_travel_without_traveling_current() -> void:
	var overlay := WorldMapOverlay.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(overlay)
	overlay.configure(CityTravel.CITY_SCENE_ID)
	overlay.open()
	overlay.show_fast_travel()
	overlay._fast_travel_view.configure_city(
		CityTravel.CITY_SCENE_ID, overlay._travelable, &"city_forum"
	)


func test_legacy_smithy_arrival_routes_to_the_city_spawn() -> void:
	assert_eq(
		CityTravel.redirect(&"forge", &"door_courtyard"),
		[CityTravel.CITY_SCENE_ID, &"kalev_smithy"]
	)
	assert_eq(
		CityTravel.redirect(&"forge", &"smithy_start"), [CityTravel.CITY_SCENE_ID, &"kalev_smithy"]
	)

	var smithy := overlay.get_node_button(&"city_kalev_smithy")
	assert_true(smithy != null)
	assert_false(smithy.disabled, "other places must be clickable")
	assert_eq(smithy.mouse_default_cursor_shape, Control.CURSOR_POINTING_HAND)

	var recorded: Array = []
	overlay.travel_requested.connect(
		func(scene_id: StringName, spawn_id: StringName) -> void:
			recorded.append({"scene_id": scene_id, "spawn_id": spawn_id})
	)
	# Headless runs skip the walking animation, so the click emits at once.
	smithy.pressed.emit()
	assert_eq(recorded.size(), 1, "place click must request travel")
	assert_eq(recorded[0]["scene_id"], CityTravel.CITY_SCENE_ID)
	assert_eq(recorded[0]["spawn_id"], &"kalev_smithy")

	assert_false(overlay.request_travel_to(&"archive_only"), "unknown nodes must not travel")
	overlay.queue_free()


func test_focus_place_ui_accept_records_same_travel_as_click() -> void:
	var overlay := WorldMapOverlay.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(overlay)
	overlay.configure(CityTravel.CITY_SCENE_ID)
	overlay.open()
	overlay.show_fast_travel()
	overlay._fast_travel_view.configure_city(
		CityTravel.CITY_SCENE_ID, overlay._travelable, &"city_forum"
	)

	tree.root.get_viewport().gui_release_focus()
	assert_false(
		overlay.activate_focused_travel(),
		"ui_accept must not travel when focus is not on a place marker"
	)

	var recorded: Array = []
	overlay.travel_requested.connect(
		func(scene_id: StringName, spawn_id: StringName) -> void:
			recorded.append({"scene_id": scene_id, "spawn_id": spawn_id})
	)
	assert_true(
		overlay.focus_travel_node(&"city_kalev_smithy"), "place marker must accept keyboard focus"
	)
	var smithy := overlay.get_node_button(&"city_kalev_smithy")
	assert_eq(tree.root.get_viewport().gui_get_focus_owner(), smithy)

	var accept := InputEventAction.new()
	accept.action = &"ui_accept"
	accept.pressed = true
	overlay._unhandled_input(accept)

	assert_eq(recorded.size(), 1, "ui_accept on a focused place must request travel")
	assert_eq(recorded[0]["scene_id"], CityTravel.CITY_SCENE_ID)
	assert_eq(recorded[0]["spawn_id"], &"kalev_smithy")
	overlay.queue_free()


func _action_has_physical_key(action: StringName, keycode: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == keycode:
			return true
	return false
