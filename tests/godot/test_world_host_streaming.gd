extends "res://tests/godot/test_case.gd"

## WB-08b / R-1043 / R-1054: with the residency flag on, the reval_east launch adapter
## streams reval_outdoor neighbours from the live host player. Walking through
## the Vana turg seam into market_civic_quarter keeps the same Player and camera
## and runs no DoorNavigator scene swap; a forced loader failure reaches
## DoorNavigator with the seam's explicit transition. Flag off nothing attaches.
## Everything here is synchronous (the walk drives the player position and ticks
## the driver) so it is deterministic under the harness. The physical keyboard /
## gamepad / mouse walk over real physics frames, which synchronously mounts a
## whole district mid-walk, is `tools/verify_world_seam_walk.tscn` (exit 0 = pass).

## Loaded at run time, not preloaded: a preload compiles player/door scripts
## before the harness has registered the DoorNavigator/MusicDirector autoloads.
const LOWER_TOWN_SCENE_PATH := "res://scenes/reval_east/reval_east.tscn"
const SEAM_TRANSITION := &"vana_turg_boundary"
const CELL := 32.0


func test_package_bounds_gate_edge_transitions_and_still_seal() -> void:
	var definition := WorldHostStreamingDriver.registry_definition(&"lower_town_slice")
	assert_true(definition != null, "lower_town_slice compiles from the registry")
	var package := MapSceneBootstrap.assemble_location_package(definition)
	var bounds := package.get_node("WorldBounds") as StaticBody2D
	var gate := bounds.get_node_or_null("SeamGate_%s" % SEAM_TRANSITION) as CollisionShape2D
	assert_true(gate != null, "the Vana turg edge transition has its own gate")
	if gate != null:
		assert_eq(gate.get_meta(MapSceneBootstrap.SEAM_GATE_META), SEAM_TRANSITION)
		assert_false(gate.disabled, "gates start sealed")
	assert_eq(bounds.get_node_or_null("SeamGate_forge"), null, "interior doors are not gates")
	# West wall pieces (Boundary2*, west gates) still cover the full map height.
	var world := definition.world_size()
	var covered := 0.0
	for shape: CollisionShape2D in bounds.get_children():
		if shape.position.x < 0.0 and shape.position.y > 0.0 and shape.position.y < world.y:
			covered += (shape.shape as RectangleShape2D).size.y
	assert_almost_eq(covered, world.y, 0.01, "split west wall seals exactly like one wall")
	package.free()


func test_driver_only_attaches_to_a_streaming_host() -> void:
	assert_eq(WorldHostStreamingDriver.attach(null), null)
	var solo := WorldHost.new()
	solo.additive_residency_enabled = true
	(Engine.get_main_loop() as SceneTree).root.add_child(solo)
	var definition := WorldHostStreamingDriver.registry_definition(&"kalev_smithy")
	var player := Node2D.new()
	var camera := Camera3D.new()
	var session := Node.new()
	for node in [player, camera, session]:
		solo.add_child(node)
	assert_true(solo.configure(WorldHost.launch_layout(definition), player, camera, session))
	assert_eq(WorldHostStreamingDriver.attach(solo), null, "an interior solo group never streams")
	solo.free()
	assert_eq(WorldHostStreamingDriver.registry_definition(&"not_registered"), null)


func test_walk_lower_town_into_market_civic_quarter_without_scene_swap() -> void:
	var launched := _launch_lower_town()
	var level: Node = launched["level"]
	var host: WorldHost = launched["host"]
	var driver: WorldHostStreamingDriver = launched["driver"]
	if driver == null:
		_dispose(level, launched)
		return
	var player := host.player_owner as Player
	var camera := host.camera_owner
	var door := _door(host, &"lower_town_slice", SEAM_TRANSITION)
	assert_false(bool(door.get("transition_enabled")), "a streamed door never swaps scenes")
	var changes: Array = []
	host.owning_location_changed.connect(
		func(previous: StringName, current: StringName) -> void: changes.append([previous, current])
	)

	driver.tick()
	assert_eq(
		host.mounted_location_ids(),
		[&"lower_town_slice", &"market_civic_quarter"] as Array[StringName],
		"the seam neighbour is prefetched from the live player position"
	)
	assert_true(host.is_seam_active_between(&"lower_town_slice", &"market_civic_quarter"))
	assert_true(_gate(host, &"lower_town_slice", SEAM_TRANSITION).disabled, "base gate opens")
	assert_true(_gate(host, &"market_civic_quarter", &"to_reval_east").disabled, "far gate opens")
	var market_door := _door(host, &"market_civic_quarter", &"to_reval_east")
	assert_false(bool(market_door.get("transition_enabled")), "the far door never swaps scenes")

	# Walk west across the seam in half-cell steps, ticking like physics frames.
	var start := player.global_position
	var step := Vector2(-0.5 * CELL, 0.0)
	for index in 16:
		player.global_position = start + step * float(index + 1)
		driver.tick()
		assert_eq(host.player_owner, player, "the same Player instance")
	assert_eq(host.owning_location_id(), &"market_civic_quarter", "the walk crosses the seam")
	assert_eq(changes, [[&"lower_town_slice", &"market_civic_quarter"]])
	assert_true(is_instance_valid(player) and player.is_inside_tree())
	assert_eq(host.camera_owner, camera, "the same camera instance")
	assert_eq(host.global_census()["player"], 1)
	assert_eq(host.global_census()["camera"], 1)
	assert_eq(DoorNavigator.pending_spawn_scene_id, &"", "no DoorNavigator scene swap ran")
	assert_eq(level.get_parent(), (Engine.get_main_loop() as SceneTree).root, "level never swapped")
	assert_eq(SessionState.state.player.location_id, &"reval_center", "save scope follows owner")
	assert_eq(SessionState.state.player.spawn_id, &"from_reval_east", "arrival door spawn")
	driver.flush_owner_rebinds()
	var runtime := level.get_node("MapViewRuntime") as MapViewRuntime
	assert_eq(runtime.owning_location_id(), &"market_civic_quarter")
	var market := host.hosted_bootstrap(&"market_civic_quarter")
	var market_def := market.get("definition") as MapDefinition
	var market_grid := market.get("grid") as MapTerrainGrid
	var local := (
		player.global_position
		- host.location_origin_logic_position(&"market_civic_quarter")
	)
	assert_almost_eq(
		player.terrain_speed_multiplier(),
		MapTerrainMovement.speed_multiplier_at(market_def, market_grid, local),
		0.0001,
		"terrain speed samples the market grid in location space"
	)
	assert_eq(
		host.minimap_hud.get_location_label().text,
		"Central District",
		"minimap follows the owning location"
	)
	assert_true(host.pinned_location_ids.is_empty(), "launch location is no longer pinned")
	var click_input := level.find_child("MapClickInput", true, false)
	var inset_from := player.global_position
	player.global_position = Vector2(8.0, start.y)
	player.velocity = Vector2.ZERO
	var clicked := (
		click_input != null
		and bool(click_input.call("try_handle_logic_click", Vector2(-6.0 * CELL, 53.5 * CELL)))
	)
	assert_true(clicked, "a click from the 16 px seam inset starts a path")
	player.global_position = inset_from
	var far := host.update_streaming(Vector2(-100.0 * CELL, 53.0 * CELL))
	assert_eq(host.owning_location_id(), &"market_civic_quarter")
	assert_false((far["evict"] as Array).is_empty(), "the policy evicts Lower Town")
	assert_true(
		(far["evicted"] as Array).has(&"lower_town_slice")
		or not host.mounted_location_ids().has(&"lower_town_slice"),
		"unpinned Lower Town leaves residency when past the band"
	)

	# And back east into Lower Town through the same open seam.
	for index in 16:
		player.global_position = start + step * float(15 - index)
		driver.tick()
	assert_eq(host.owning_location_id(), &"lower_town_slice", "the walk crosses back")
	assert_eq(changes.size(), 2)
	assert_eq(SessionState.state.player.location_id, &"reval_east")
	assert_eq(SessionState.state.player.spawn_id, SEAM_TRANSITION)
	assert_eq(DoorNavigator.pending_spawn_scene_id, &"")
	_dispose(level, launched)


func test_owner_rebind_defers_ambient_and_phase_off_the_crossing_tick() -> void:
	var launched := _launch_lower_town()
	var level: Node = launched["level"]
	var host: WorldHost = launched["host"]
	var driver: WorldHostStreamingDriver = launched["driver"]
	if driver == null:
		_dispose(level, launched)
		return
	var player := host.player_owner as Player
	var start := player.global_position
	var step := Vector2(-0.5 * CELL, 0.0)
	var crossed := false
	for index in 16:
		player.global_position = start + step * float(index + 1)
		driver.tick()
		if host.owning_location_id() == &"market_civic_quarter":
			crossed = true
			break
	assert_true(crossed, "the walk reaches the market seam")
	assert_true(
		driver.has_pending_owner_rebinds(),
		"ambient and phase presenter wait for a later tick"
	)
	assert_true(
		driver.last_owner_rebind_usec <= 4000,
		"crossing-frame rebind stayed under 4 ms (%d us)" % driver.last_owner_rebind_usec
	)
	var runtime := level.get_node("MapViewRuntime") as MapViewRuntime
	assert_eq(runtime.owning_location_id(), &"market_civic_quarter")
	assert_eq(
		host.minimap_hud.get_location_label().text,
		"Central District",
		"minimap label is gameplay truth and switches on the crossing tick"
	)
	var market := host.hosted_bootstrap(&"market_civic_quarter")
	var market_def := market.get("definition") as MapDefinition
	var market_grid := market.get("grid") as MapTerrainGrid
	var local := (
		player.global_position
		- host.location_origin_logic_position(&"market_civic_quarter")
	)
	assert_almost_eq(
		player.terrain_speed_multiplier(),
		MapTerrainMovement.speed_multiplier_at(market_def, market_grid, local),
		0.0001,
		"terrain speed switches on the crossing tick"
	)
	driver.flush_owner_rebinds()
	assert_false(driver.has_pending_owner_rebinds())
	_dispose(level, launched)


func test_forced_loader_failure_reaches_door_navigator() -> void:
	var launched := _launch_lower_town()
	var level: Node = launched["level"]
	var host: WorldHost = launched["host"]
	var driver: WorldHostStreamingDriver = launched["driver"]
	if driver == null:
		_dispose(level, launched)
		return
	host.scene_swap_fallback_enabled = true
	host.location_loader = func(_location_id: StringName) -> bool: return false
	driver.execute_fallback = false
	var requests: Array = []
	host.scene_swap_fallback_requested.connect(
		func(location_id: StringName, request: Dictionary) -> void:
			requests.append([location_id, request])
	)
	driver.tick()
	assert_eq(host.mounted_location_ids(), [&"lower_town_slice"] as Array[StringName])
	assert_true(host.mount_failure_count(&"market_civic_quarter") > 0)
	assert_false(
		_gate(host, &"lower_town_slice", SEAM_TRANSITION).disabled,
		"an unresident neighbour keeps its gate sealed"
	)
	assert_true(requests.is_empty(), "no swap before the player touches the seam door")

	# The player reaches the sealed seam door: the host degrades to the explicit
	# transition and DoorNavigator resolves the door's authored destination.
	var door := _door(host, &"lower_town_slice", SEAM_TRANSITION)
	door.body_entered.emit(host.player_owner)
	assert_eq(requests.size(), 1)
	if requests.size() == 1:
		assert_eq(requests[0][0], &"market_civic_quarter")
		assert_eq(requests[0][1]["transition_id"], SEAM_TRANSITION)
	assert_eq(
		driver.last_fallback,
		{
			"transition_id": SEAM_TRANSITION,
			"scene_id": &"reval_center",
			"spawn_id": &"from_reval_east",
			"started": false,
		}
	)
	assert_eq(host.owning_location_id(), &"lower_town_slice", "never owned by unloaded space")
	assert_eq(DoorNavigator.pending_spawn_scene_id, &"")
	_dispose(level, launched)


## Launch the real reval_east adapter with the flag on, entering at the Vana
## turg seam door so the market neighbour is inside the prefetch band.
func _launch_lower_town() -> Dictionary:
	var previous_flag := bool(ProjectSettings.get_setting(WorldHost.ADDITIVE_RESIDENCY_SETTING, false))
	var player_state: PlayerState = SessionState.state.player
	var launched := {
		"previous_flag": previous_flag,
		"location_id": player_state.location_id,
		"spawn_id": player_state.spawn_id,
	}
	ProjectSettings.set_setting(WorldHost.ADDITIVE_RESIDENCY_SETTING, true)
	DoorNavigator.pending_spawn_scene_id = &"reval_east"
	DoorNavigator.pending_spawn_id = SEAM_TRANSITION
	var level: Node = (load(LOWER_TOWN_SCENE_PATH) as PackedScene).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(level)
	var host := level.get_node_or_null(WorldHost.HOST_NODE_NAME) as WorldHost
	launched["level"] = level
	launched["host"] = host
	var driver: WorldHostStreamingDriver = null
	if host != null:
		driver = host.get_node_or_null(WorldHostStreamingDriver.NODE_NAME) as WorldHostStreamingDriver
	launched["driver"] = driver
	assert_true(driver != null, "the reval_east launch adapter attaches a streaming driver")
	if driver != null:
		assert_eq(host.owning_location_id(), &"lower_town_slice")
		assert_true(host.definition_provider.is_valid(), "registry definitions by default")
	return launched


func _dispose(level: Node, launched: Dictionary) -> void:
	var host := level.get_node_or_null(WorldHost.HOST_NODE_NAME) as WorldHost
	if host != null:
		host.unmount_all()
	if level.get_parent() != null:
		level.get_parent().remove_child(level)
	level.free()
	DoorNavigator.clear_pending_spawn()
	ProjectSettings.set_setting(WorldHost.ADDITIVE_RESIDENCY_SETTING, launched["previous_flag"])
	SessionState.state.player.location_id = launched["location_id"]
	SessionState.state.player.spawn_id = launched["spawn_id"]


func _door(host: WorldHost, location_id: StringName, transition_id: StringName) -> Area2D:
	var root := host.mounted_location_root(location_id, false)
	for node in root.find_children("*", "Area2D", true, false):
		var handle: Variant = node.get_meta(&"stable_handle", {})
		if handle is Dictionary and handle.get("object_id", "") == "transition:%s" % transition_id:
			return node as Area2D
	return null


func _gate(host: WorldHost, location_id: StringName, transition_id: StringName) -> CollisionShape2D:
	var root := host.mounted_location_root(location_id, false)
	for body in root.find_children("WorldBounds", "StaticBody2D", true, false):
		var gate := body.get_node_or_null("SeamGate_%s" % transition_id) as CollisionShape2D
		if gate != null:
			return gate
	return null
