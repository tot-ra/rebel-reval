extends "res://tests/godot/test_case.gd"

const KalevSmithy := preload("res://scripts/map/definitions/lower_town/kalev_smithy_definition.gd")


func after_each() -> void:
	DoorNavigator.clear_pending_spawn()


func test_place_player_keeps_courtyard_door_spawn_after_pending_clears() -> void:
	# Regression: scenes used to treat cleared pending_spawn_id as "use player_spawn",
	# which teleported forge arrivals from door_courtyard to the far smithy_start cell.
	DoorNavigator.load_manifest(true)
	var definition: MapDefinition = KalevSmithy.create()
	var root := Node2D.new()
	var actors := Node2D.new()
	var player := Node2D.new()
	player.name = "Player"
	actors.add_child(player)
	root.add_child(actors)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(root)

	MapSceneBootstrap.assemble(root, definition, actors)
	DoorNavigator.pending_spawn_scene_id = &"forge"
	DoorNavigator.pending_spawn_id = &"door_courtyard"

	var on_spawn := func(position: Vector2, _direction: String) -> void:
		player.global_position = position
	DoorNavigator.on_trigger_player_spawn.connect(on_spawn)

	# Scenes call the autoload helper (not MapSceneBootstrap.place_player via class_name).
	var used_door := DoorNavigator.place_player(root, player, definition.player_spawn)
	assert_true(used_door, "courtyard arrival must resolve through the door spawn")
	assert_true(DoorNavigator.pending_spawn_id.is_empty(), "successful door spawn clears pending IDs")
	assert_ne(
		player.global_position,
		definition.player_spawn,
		"door arrival must not fall back to the far authored player_spawn"
	)

	var door := DoorNavigator.get_spawn_node(root, &"forge", &"door_courtyard")
	assert_true(door != null and door.spawn != null, "forge must expose door_courtyard")
	assert_eq(player.global_position, door.spawn.global_position)

	DoorNavigator.on_trigger_player_spawn.disconnect(on_spawn)
	root.free()


func test_place_player_falls_back_to_authored_spawn_without_pending() -> void:
	DoorNavigator.load_manifest(true)
	DoorNavigator.clear_pending_spawn()
	var definition: MapDefinition = KalevSmithy.create()
	var root := Node2D.new()
	var actors := Node2D.new()
	var player := Node2D.new()
	player.name = "Player"
	player.global_position = Vector2(-1000, -1000)
	actors.add_child(player)
	root.add_child(actors)

	var used_door := DoorNavigator.place_player(root, player, definition.player_spawn)
	assert_false(used_door, "cold start without pending spawn must use authored spawn")
	assert_eq(player.global_position, definition.player_spawn)
	root.free()


func test_map_scene_bootstrap_place_player_delegates_to_door_navigator() -> void:
	DoorNavigator.load_manifest(true)
	DoorNavigator.clear_pending_spawn()
	var definition: MapDefinition = KalevSmithy.create()
	var player := Node2D.new()
	player.global_position = Vector2(-1000, -1000)
	var used_door := MapSceneBootstrap.place_player(Node2D.new(), player, definition)
	assert_false(used_door)
	assert_eq(player.global_position, definition.player_spawn)
	player.free()
