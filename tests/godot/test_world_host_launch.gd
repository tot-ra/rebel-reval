extends "res://tests/godot/test_case.gd"

## WB-06b / R-1038: with `world_host/additive_residency_enabled` on, scene entry
## points are thin launch adapters. The WorldHost owns the one Player, PlayerRig,
## camera, environment and minimap; MapViewRuntime binds them instead of creating
## its own; the host clock drives the day; DoorNavigator places the host player;
## keyboard, gamepad and click input reach that player. Flag off stays today's path.

## Loaded at run time, not preloaded: a preload compiles player/door scripts
## before the harness has registered the DoorNavigator/MusicDirector autoloads.
const PLAYER_SCENE_PATH := "res://player.tscn"
const LOWER_TOWN_SCENE_PATH := "res://scenes/reval_east/reval_east.tscn"
const FORGE_SCENE_PATH := "res://scenes/reval_east/forge/forge.tscn"
const CELL := 32


func test_launch_is_disabled_by_default() -> void:
	assert_false(WorldHost.launch_enabled(), "scenes keep today's ownership by default")


func test_launch_retires_scene_player_and_owns_one_global_set() -> void:
	var scene := _scene_with_player()
	var scene_player := scene.get_node("Actors/Player")
	var host := WorldHost.launch_scene_location(scene, _map(), scene_player)
	assert_true(host != null, "host launches")
	assert_eq(host.get_parent(), scene)
	assert_false(scene_player.is_inside_tree(), "the .tscn player leaves the tree")
	assert_true(host.player_owner is Player and host.player_owner != scene_player)
	assert_eq(host.mounted_location_ids(), [&"launch_map"] as Array[StringName])
	assert_eq(host.owning_location_id(), &"launch_map")
	assert_eq(host.global_census(), _one_of_each())

	var bootstrap := host.hosted_bootstrap(&"launch_map")
	assert_eq(bootstrap["world_host"], host)
	assert_eq((bootstrap["definition"] as MapDefinition).map_id, &"launch_map")
	assert_true(bootstrap["grid"] is MapTerrainGrid)
	var navigation := bootstrap["navigation"] as NavigationRegion2D
	assert_true(navigation != null, "logic package navigation is exposed")
	assert_eq(navigation.get_navigation_map(), host.navigation_map(), "one host navigation map")
	assert_eq(bootstrap["minimap_hud"], host.minimap_hud)
	assert_false(bootstrap.has("assembled"), "a hosted location draws no flat map")
	_dispose(scene)


func test_launch_layout_uses_manifest_for_outdoor_and_solo_group_for_interior() -> void:
	var outdoor := MapDefinition.new()
	outdoor.map_id = &"lower_town_slice"
	var layout := WorldHost.launch_layout(outdoor)
	assert_true(bool(layout["valid"]))
	assert_true((layout["seams"] as Array).size() > 0, "manifest layout carries seams")

	var solo := WorldHost.launch_layout(_map())
	assert_true(bool(solo["valid"]), str(solo.get("errors", [])))
	assert_eq((solo["locations"] as Array).size(), 1)
	assert_eq(StringName(solo["world_group_id"]), &"launch_map_solo")


func test_hosted_runtime_binds_host_globals_instead_of_creating_them() -> void:
	var scene := _scene_with_player()
	var host := WorldHost.launch_scene_location(scene, _map(), scene.get_node("Actors/Player"))
	var runtime := MapViewRuntime.install_hosted(scene, host, &"launch_map")
	assert_true(runtime != null and runtime.is_hosted())
	assert_eq(runtime.get_parent(), scene, "the runtime is never inside a location package")
	assert_eq(runtime.view, host.hosted_view(&"launch_map"))
	assert_eq(runtime._player, host.player_owner)
	assert_eq(runtime._player_rig, host.player_rig)
	assert_eq(runtime._camera, host.camera_owner)
	assert_eq(runtime.view.view_camera(), host.camera_owner)
	for kind in ["Camera3D", "WorldEnvironment", "DirectionalLight3D"]:
		assert_eq(
			runtime.find_children("*", kind, true, false).size(), 0, "runtime creates no %s" % kind
		)
	assert_eq(host.global_census(), _one_of_each())
	assert_true(host.player_rig.get_node_or_null("ReadabilityFill") != null)
	var click_input := runtime.get_node("MapClickInput")
	assert_eq(click_input.get("_player"), host.player_owner, "mouse routes to the host player")
	_dispose(scene)


func test_host_clock_drives_the_hosted_runtime() -> void:
	var scene := _scene_with_player()
	var host := WorldHost.launch_scene_location(scene, _map(), scene.get_node("Actors/Player"))
	host.set_clock_progress(0.3)
	var runtime := MapViewRuntime.install_hosted(scene, host, &"launch_map")
	assert_almost_eq(runtime.cycle_progress, 0.3, 0.0001, "runtime starts from the host clock")

	runtime._environment.advance_cycle(30.0, Callable(runtime._session, "current_calendar_date"))
	assert_true(host.clock_progress > 0.3, "advancing the runtime advances the host")
	assert_almost_eq(runtime.cycle_progress, host.clock_progress, 0.0001)

	runtime.set_time_of_day(MapView3D.TIME_NIGHT)
	assert_almost_eq(host.clock_progress, 0.0, 0.0001, "a pinned time is published to the host")

	# Save/load: SessionState restores the weather snapshot through the runtime;
	# the host clock must follow or its next tick would rewind the loaded sky.
	var snapshot := runtime.environment_snapshot()
	assert_false(snapshot.is_empty(), "hosted runtime still snapshots the host sky")
	snapshot["cycle_progress"] = 0.8
	snapshot["elapsed_days"] = 4
	assert_true(runtime.restore_environment_snapshot(snapshot))
	assert_almost_eq(host.clock_progress, 0.8, 0.0001, "a loaded save moves the host clock")
	assert_eq(host.clock_completed_days, 4)
	_dispose(scene)


func test_door_navigator_places_the_host_player() -> void:
	var scene := _scene_with_player()
	var host := WorldHost.launch_scene_location(scene, _map(), scene.get_node("Actors/Player"))
	var player := host.player_owner as Player
	DoorNavigator.clear_pending_spawn()
	assert_false(DoorNavigator.place_player(scene, player, Vector2(2.5 * CELL, 2.5 * CELL)))
	assert_eq(player.global_position, Vector2(2.5 * CELL, 2.5 * CELL))
	_dispose(scene)


func test_keyboard_and_gamepad_move_the_host_player() -> void:
	# Why: a scene launched in the harness never runs the menu binding install.
	# Gamepad move is the left stick, not the D-pad (InputBindingSettings).
	var bindings: Variant = load("res://scripts/settings/input_binding_settings.gd")
	bindings.default_settings().apply_to_input_map()
	var scene := _scene_with_player()
	var host := WorldHost.launch_scene_location(scene, _map(), scene.get_node("Actors/Player"))
	MapViewRuntime.install_hosted(scene, host, &"launch_map")
	var player := host.player_owner as Player
	var start := Vector2(3.0 * CELL, 5.0 * CELL)

	player.global_position = start
	Input.action_press(&"ui_right")
	await _physics_frames(6)
	Input.action_release(&"ui_right")
	assert_true(player.global_position.distance_to(start) > 1.0, "keyboard moves the host player")

	player.global_position = start
	player.velocity = Vector2.ZERO
	await _physics_frames(2)
	_tilt_left_stick_x(1.0)
	await _physics_frames(6)
	_tilt_left_stick_x(0.0)
	assert_true(player.global_position.distance_to(start) > 1.0, "gamepad moves the host player")
	_dispose(scene)


## The real launch adapters: menu -> Lower Town -> forge with the flag on.
func test_reval_east_and_forge_launch_through_the_host_when_flag_on() -> void:
	var previous := bool(ProjectSettings.get_setting(WorldHost.ADDITIVE_RESIDENCY_SETTING, false))
	ProjectSettings.set_setting(WorldHost.ADDITIVE_RESIDENCY_SETTING, true)
	for case in [
		{"scene": LOWER_TOWN_SCENE_PATH, "scene_id": &"reval_east", "spawn_id": &"forge"},
		{"scene": FORGE_SCENE_PATH, "scene_id": &"forge", "spawn_id": &"door_courtyard"},
	]:
		DoorNavigator.pending_spawn_scene_id = case["scene_id"]
		DoorNavigator.pending_spawn_id = case["spawn_id"]
		var level: Node = (load(case["scene"]) as PackedScene).instantiate()
		(Engine.get_main_loop() as SceneTree).root.add_child(level)
		var host := level.get_node_or_null(WorldHost.HOST_NODE_NAME) as WorldHost
		var label := String(case["scene_id"])
		assert_true(host != null and host.owns_globals(), "%s launches a host" % label)
		if host == null:
			level.free()
			continue
		assert_eq(host.global_census(), _one_of_each(), "%s has one global set" % label)
		assert_eq(level.get_node_or_null("Actors/Player"), null, "%s .tscn player retired" % label)
		assert_eq(level.get("player"), host.player_owner, "%s script binds the host player" % label)
		var runtime := level.get_node_or_null("MapViewRuntime") as MapViewRuntime
		assert_true(runtime != null and runtime.world_host == host, "%s runtime is hosted" % label)
		var door := DoorNavigator.get_spawn_node(level, case["scene_id"], case["spawn_id"])
		assert_true(door != null, "%s spawn door lives in the logic package" % label)
		if door != null:
			assert_true(
				(host.player_owner as Node2D).global_position.distance_to(door.spawn.global_position)
				< 1.0,
				"%s DoorNavigator placed the host player at the pending spawn" % label
			)
		var cameras := 0
		for camera: Camera3D in level.find_children("*", "Camera3D", true, false):
			if camera.current:
				cameras += 1
		assert_eq(cameras, 1, "%s draws through exactly one current camera" % label)
		level.free()
	DoorNavigator.clear_pending_spawn()
	ProjectSettings.set_setting(WorldHost.ADDITIVE_RESIDENCY_SETTING, previous)


## WB-06d: a quest NPC under the scene Actors node must sit on the mounted
## package origin, not the scene origin. market_civic_quarter is (-114, 0);
## this fixture uses (-10, 4) so the assertion does not depend on the manifest.
func test_hosted_npc_follows_nonzero_package_origin() -> void:
	var scene := _scene_with_player()
	var actors := scene.get_node("Actors") as Node2D
	var npc := Marker2D.new()
	npc.name = "QuestNpc"
	npc.position = Vector2(96, 64)
	actors.add_child(npc)
	var definition := _map()
	var layout := WorldHost.launch_layout(definition)
	assert_true(bool(layout.get("valid", false)), str(layout.get("errors", [])))
	for entry_value in layout["locations"]:
		(entry_value as Dictionary)["origin_cell"] = Vector2i(-10, 4)
	var host := WorldHost.launch_scene_location(
		scene, definition, scene.get_node("Actors/Player"), {"layout": layout}
	)
	assert_true(host != null, "host launches with an overridden origin")
	var origin := host.location_origin_logic_position(&"launch_map")
	assert_eq(origin, Vector2(-10, 4) * float(CELL))
	assert_eq(actors.position, origin, "Actors is the equivalent offset node")
	assert_eq(
		npc.global_position,
		origin + Vector2(96, 64),
		"the NPC shares the package origin"
	)
	var logic_root := host.mounted_location_root(&"launch_map", false) as Node2D
	assert_true(logic_root != null)
	assert_eq(logic_root.position, origin)
	var anchors: Array = host.hosted_bootstrap(&"launch_map").get("anchors", [])
	if not anchors.is_empty():
		var anchor := anchors[0] as Marker2D
		npc.position = actors.to_local(anchor.global_position)
		assert_eq(
			npc.global_position,
			anchor.global_position,
			"an NPC on an anchor cell matches the package anchor"
		)
	_dispose(scene)


func test_remaining_outdoor_scenes_launch_through_the_host_when_flag_on() -> void:
	var previous := bool(ProjectSettings.get_setting(WorldHost.ADDITIVE_RESIDENCY_SETTING, false))
	ProjectSettings.set_setting(WorldHost.ADDITIVE_RESIDENCY_SETTING, true)
	for case in [
		{
			"scene": "res://scenes/reval_center/reval_center.tscn",
			"scene_id": &"reval_center",
			"spawn_id": &"from_reval_east",
		},
		{
			"scene": "res://scenes/reval_monastery/reval_monastery.tscn",
			"scene_id": &"reval_monastery",
			"spawn_id": &"from_reval_north",
		},
		{
			"scene": "res://scenes/reval_north/reval_north.tscn",
			"scene_id": &"reval_north",
			"spawn_id": &"from_monastery",
		},
		{
			"scene": "res://scenes/reval_south/reval_south.tscn",
			"scene_id": &"reval_south",
			"spawn_id": &"from_reval_center",
		},
		{
			"scene": "res://scenes/reval_toompea/reval_toompea.tscn",
			"scene_id": &"reval_toompea",
			"spawn_id": &"from_reval_center",
		},
		{
			"scene": "res://scenes/reval_archbishops_garden/reval_archbishops_garden.tscn",
			"scene_id": &"reval_archbishops_garden",
			"spawn_id": &"from_reval_center",
		},
		{
			"scene": "res://scenes/harbor/harbor_east.tscn",
			"scene_id": &"reval_harbor_east",
			"spawn_id": &"from_harbor_north",
		},
		{
			"scene": "res://scenes/harbor/harbor_north.tscn",
			"scene_id": &"reval_harbor_north",
			"spawn_id": &"from_reval_north",
		},
		{
			"scene": "res://scenes/reval_east/viru_gate_foreland/viru_gate_foreland.tscn",
			"scene_id": &"viru_gate_foreland",
			"spawn_id": &"from_reval_east",
		},
	]:
		DoorNavigator.pending_spawn_scene_id = case["scene_id"]
		DoorNavigator.pending_spawn_id = case["spawn_id"]
		var level: Node = (load(case["scene"]) as PackedScene).instantiate()
		(Engine.get_main_loop() as SceneTree).root.add_child(level)
		var host := level.get_node_or_null(WorldHost.HOST_NODE_NAME) as WorldHost
		var label := String(case["scene_id"])
		assert_true(host != null and host.owns_globals(), "%s launches a host" % label)
		if host == null:
			level.free()
			continue
		assert_eq(host.global_census(), _one_of_each(), "%s has one global set" % label)
		assert_eq(level.get_node_or_null("Actors/Player"), null, "%s .tscn player retired" % label)
		assert_eq(level.get("player"), host.player_owner, "%s script binds the host player" % label)
		var runtime := level.get_node_or_null("MapViewRuntime") as MapViewRuntime
		assert_true(runtime != null and runtime.world_host == host, "%s runtime is hosted" % label)
		var door := DoorNavigator.get_spawn_node(level, case["scene_id"], case["spawn_id"])
		assert_true(door != null, "%s spawn door lives in the logic package" % label)
		if door != null:
			assert_true(
				(host.player_owner as Node2D).global_position.distance_to(door.spawn.global_position)
				< 1.0,
				"%s DoorNavigator placed the host player at the pending spawn" % label
			)
		level.free()
	DoorNavigator.clear_pending_spawn()
	ProjectSettings.set_setting(WorldHost.ADDITIVE_RESIDENCY_SETTING, previous)


func _scene_with_player() -> Node2D:
	var scene := Node2D.new()
	scene.name = "LaunchAdapterUnderTest"
	var actors := Node2D.new()
	actors.name = "Actors"
	scene.add_child(actors)
	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate()
	player.name = "Player"
	actors.add_child(player)
	(Engine.get_main_loop() as SceneTree).root.add_child(scene)
	return scene


func _dispose(scene: Node) -> void:
	var host := scene.get_node_or_null(WorldHost.HOST_NODE_NAME) as WorldHost
	if host != null:
		host.unmount_all()
	if scene.get_parent() != null:
		scene.get_parent().remove_child(scene)
	scene.free()


func _tilt_left_stick_x(value: float) -> void:
	var pad := InputEventJoypadMotion.new()
	pad.axis = JOY_AXIS_LEFT_X
	pad.axis_value = value
	Input.parse_input_event(pad)
	Input.flush_buffered_events()


func _physics_frames(count: int) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for _frame in count:
		await tree.physics_frame


func _one_of_each() -> Dictionary:
	return {
		"player": 1,
		"player_rig": 1,
		"camera": 1,
		"world_environment": 1,
		"sun": 1,
		"sky_weather": 1,
		"hud": 1,
	}


func _map() -> MapDefinition:
	var definition := MapDefinition.new()
	definition.map_id = &"launch_map"
	definition.location = &"loc.launch_map"
	definition.cell_size = MapTypes.DEFAULT_CELL_SIZE
	definition.size_cells = Vector2i(10, 10)
	definition.base_terrain = MapTypes.TERRAIN_GRASS
	definition.player_spawn = Vector2(2 * CELL, 2 * CELL)
	definition.scope = &"production"
	definition.active = true
	definition.palette = &"clean_painted"
	definition.fingerprint = "launch_map-fingerprint"
	return definition
